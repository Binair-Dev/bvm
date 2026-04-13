package com.bvm.mobile

import android.content.Context
import android.os.Build
import android.system.Os
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.zip.GZIPInputStream
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream

class BootstrapManager(
    private val context: Context,
    private val filesDir: String,
    private val nativeLibDir: String
) {
    private val rootfsDir get() = "$filesDir/rootfs/ubuntu"
    private val tmpDir get() = "$filesDir/tmp"
    private val homeDir get() = "$filesDir/home"
    private val configDir get() = "$filesDir/config"
    private val libDir get() = "$filesDir/lib"
    private val stateManager = VmStateManager(filesDir)

    fun setupDirectories() {
        listOf(rootfsDir, tmpDir, homeDir, configDir, libDir).forEach {
            File(it).mkdirs()
        }
        setupLibtalloc()
        setupFakeSysdata()
    }

    private fun setupLibtalloc() {
        val source = File("$nativeLibDir/libtalloc.so")
        val target = File("$libDir/libtalloc.so.2")
        if (source.exists() && !target.exists()) {
            source.copyTo(target)
            target.setExecutable(true)
        }
    }

    private fun setupFakeSysdata() {
        val procFakes = File(configDir, "proc_fakes")
        listOf(
            "loadavg", "stat", "uptime", "version", "vmstat",
            "cap_last_cap", "max_user_watches", "fips_enabled"
        ).forEach { name ->
            val f = File(procFakes, name)
            f.parentFile?.mkdirs()
            if (!f.exists()) f.writeText("")
        }
        val sysFakes = File(configDir, "sys_fakes")
        val empty = File(sysFakes, "empty")
        empty.mkdirs()
    }

    fun isBootstrapComplete(): Boolean {
        val rootfs = File(rootfsDir)
        val binBash = File("$rootfsDir/bin/bash")
        return rootfs.exists() && binBash.exists()
    }

    fun getBootstrapStatus(): Map<String, Any> {
        val rootfsExists = File(rootfsDir).exists()
        val binBashExists = File("$rootfsDir/bin/bash").exists()
        return mapOf(
            "rootfsExists" to rootfsExists,
            "binBashExists" to binBashExists,
            "complete" to (rootfsExists && binBashExists)
        )
    }

    fun extractRootfs(tarPath: String) {
        val rootfs = File(rootfsDir)
        if (rootfs.exists()) {
            deleteRecursively(rootfs)
        }
        rootfs.mkdirs()

        val deferredSymlinks = mutableListOf<Pair<String, String>>()
        var entryCount = 0
        var fileCount = 0
        var symlinkCount = 0
        var extractionError: Exception? = null

        try {
            FileInputStream(tarPath).use { fis ->
                BufferedInputStream(fis, 256 * 1024).use { bis ->
                    GZIPInputStream(bis).use { gis ->
                        TarArchiveInputStream(gis).use { tis ->
                            var entry: TarArchiveEntry? = tis.nextEntry
                            while (entry != null) {
                                entryCount++
                                val name = entry.name
                                    .removePrefix("./")
                                    .removePrefix("/")

                                if (name.isEmpty() || name.startsWith("dev/") || name == "dev") {
                                    entry = tis.nextEntry
                                    continue
                                }

                                val outFile = File(rootfsDir, name)

                                when {
                                    entry.isDirectory -> {
                                        outFile.mkdirs()
                                    }
                                    entry.isSymbolicLink -> {
                                        deferredSymlinks.add(
                                            Pair(entry.linkName, outFile.absolutePath)
                                        )
                                        symlinkCount++
                                    }
                                    entry.isLink -> {
                                        val target = entry.linkName
                                            .removePrefix("./")
                                            .removePrefix("/")
                                        val targetFile = File(rootfsDir, target)
                                        outFile.parentFile?.mkdirs()
                                        try {
                                            if (targetFile.exists()) {
                                                targetFile.copyTo(outFile, overwrite = true)
                                                if (targetFile.canExecute()) {
                                                    outFile.setExecutable(true, false)
                                                }
                                                fileCount++
                                            }
                                        } catch (_: Exception) {}
                                    }
                                    else -> {
                                        outFile.parentFile?.mkdirs()
                                        FileOutputStream(outFile).use { fos ->
                                            val buf = ByteArray(65536)
                                            var len: Int
                                            while (tis.read(buf).also { len = it } != -1) {
                                                fos.write(buf, 0, len)
                                            }
                                        }
                                        outFile.setReadable(true, false)
                                        outFile.setWritable(true, false)
                                        val mode = entry.mode
                                        if (mode == 0 || mode and 0b001_001_001 != 0) {
                                            val path = name.lowercase()
                                            if (mode and 0b001_001_001 != 0 ||
                                                path.contains("/bin/") ||
                                                path.contains("/sbin/") ||
                                                path.endsWith(".sh") ||
                                                path.contains("/lib/apt/methods/")) {
                                                outFile.setExecutable(true, false)
                                            }
                                        }
                                        fileCount++
                                    }
                                }
                                entry = tis.nextEntry
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            extractionError = e
        }

        if (entryCount == 0) {
            throw RuntimeException(
                "Extraction failed: tarball appears empty or corrupt. " +
                "Error: ${extractionError?.message ?: "none"}"
            )
        }

        if (extractionError != null && fileCount < 100) {
            throw RuntimeException(
                "Extraction failed after $entryCount entries ($fileCount files): " +
                "${extractionError!!.message}"
            )
        }

        var symlinkErrors = 0
        for ((target, path) in deferredSymlinks) {
            try {
                val file = File(path)
                if (file.exists()) {
                    file.delete()
                }
                Os.symlink(target, path)
            } catch (_: Exception) {
                symlinkErrors++
            }
        }
    }

    fun cloneRootfs(vmName: String): Boolean {
        val base = File(rootfsDir)
        if (!base.exists()) return false
        val dest = File("$filesDir/rootfs/$vmName")
        if (dest.exists()) return false
        dest.mkdirs()
        return try {
            copyDirectory(base, dest)
            // Ensure shared directory exists for bind mount
            File("$filesDir/shared/$vmName").mkdirs()
            true
        } catch (e: Exception) {
            deleteRecursively(dest)
            false
        }
    }

    fun deleteRootfs(vmName: String): Boolean {
        val dest = File("$filesDir/rootfs/$vmName")
        return try {
            if (dest.exists()) deleteRecursively(dest)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun listVms(): List<Map<String, String>> {
        val rootfs = File("$filesDir/rootfs")
        if (!rootfs.exists()) return emptyList()
        return rootfs.listFiles { f -> f.isDirectory && f.name != "ubuntu" }
            ?.sortedBy { it.name }
            ?.map { f ->
                val size = folderSize(f)
                val isRunning = stateManager.isRunning(f.name)
                val autoStart = stateManager.getAutoStart(f.name)
                mapOf(
                    "name" to f.name,
                    "createdAt" to java.util.Date(f.lastModified()).toString(),
                    "distro" to "ubuntu",
                    "size" to formatBytes(size),
                    "isRunning" to isRunning.toString(),
                    "autoStart" to autoStart.toString(),
                )
            } ?: emptyList()
    }

    fun startVm(vmName: String): Boolean {
        val rootfs = File("$filesDir/rootfs/$vmName")
        if (!rootfs.exists()) return false
        stateManager.setRunning(vmName, true)
        return true
    }

    fun stopVm(vmName: String): Boolean {
        return stateManager.stopVm(vmName)
    }

    fun setVmAutoStart(vmName: String, autoStart: Boolean): Boolean {
        val rootfs = File("$filesDir/rootfs/$vmName")
        if (!rootfs.exists()) return false
        stateManager.setAutoStart(vmName, autoStart)
        return true
    }

    private fun copyDirectory(source: File, target: File) {
        source.listFiles()?.forEach { file ->
            val dest = File(target, file.name)
            when {
                file.isDirectory -> {
                    dest.mkdirs()
                    copyDirectory(file, dest)
                }
                else -> {
                    val linkTarget = try {
                        Os.readlink(file.absolutePath)
                    } catch (_: Exception) {
                        null
                    }
                    if (linkTarget != null) {
                        try {
                            Os.symlink(linkTarget, dest.absolutePath)
                        } catch (_: Exception) {
                            file.copyTo(dest, overwrite = true)
                        }
                    } else {
                        file.copyTo(dest, overwrite = true)
                        if (file.canExecute()) {
                            dest.setExecutable(true, false)
                        }
                    }
                }
            }
        }
    }

    private fun deleteRecursively(file: File) {
        file.listFiles()?.forEach {
            if (it.isDirectory) deleteRecursively(it)
            else it.delete()
        }
        file.delete()
    }

    private fun folderSize(dir: File): Long {
        var size = 0L
        dir.listFiles()?.forEach {
            size += if (it.isDirectory) folderSize(it) else it.length()
        }
        return size
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes <= 0) return "0 B"
        val units = arrayOf("B", "KB", "MB", "GB")
        val digitGroups = (Math.log10(bytes.toDouble()) / Math.log10(1024.0)).toInt()
        return String.format("%.2f %s", bytes / Math.pow(1024.0, digitGroups.toDouble()), units[digitGroups])
    }
}
