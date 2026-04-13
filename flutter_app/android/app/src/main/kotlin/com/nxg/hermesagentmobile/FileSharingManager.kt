package com.bvm.mobile

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class FileSharingManager(private val context: Context, private val processManager: ProcessManager? = null) {

    data class Progress(val current: Long, val total: Long, val message: String)

    data class FileItem(
        val name: String,
        val path: String,
        val isDirectory: Boolean,
        val size: Long,
        val permissions: String,
        val lastModified: Long
    )

    fun setupSharedDir(vmName: String): File {
        val sharedDir = File(context.filesDir, "shared/$vmName")
        val wasCreated = !sharedDir.exists()
        sharedDir.mkdirs()
        File(sharedDir, "downloads").mkdirs()
        
        // Restart terminal service if it was already running and we just created the dir
        // This ensures the --bind mount is applied to new terminal processes
        if (wasCreated && TerminalSessionService.isRunning) {
            TerminalSessionService.stop(context)
            TerminalSessionService.start(context)
        }
        
        return sharedDir
    }

    fun getSharedDir(vmName: String): File {
        return File(context.filesDir, "shared/$vmName")
    }

    fun listSharedFiles(vmName: String): List<FileItem> {
        val sharedDir = getSharedDir(vmName)
        if (!sharedDir.exists()) return emptyList()

        return sharedDir.listFiles()?.map { file ->
            FileItem(
                name = file.name,
                path = file.absolutePath,
                isDirectory = file.isDirectory,
                size = if (file.isDirectory) 0 else file.length(),
                permissions = getPermissions(file),
                lastModified = file.lastModified()
            )
        }?.sortedWith(compareBy({ !it.isDirectory }, { it.name })) ?: emptyList()
    }

    fun listVmDirectory(
        vmName: String,
        path: String,
        nativeLibDir: String,
        callback: (List<FileItem>?, String?) -> Unit
    ) {
        Thread {
            try {
                val rootfsDir = File(context.filesDir, "rootfs/$vmName")
                val targetPath = if (path.startsWith("/")) path else "/$path"

                // Use ProcessManager if available (has proper env setup)
                val output = if (processManager != null) {
                    processManager.runInProotSync(
                        "/bin/ls -la --group-directories-first \"$targetPath\"",
                        30L,
                        vmName
                    )
                } else {
                    // Fallback with manual proot call
                    val process = ProcessBuilder(
                        "$nativeLibDir/libproot.so",
                        "-r", rootfsDir.absolutePath,
                        "-w", targetPath,
                        "-b", "/proc",
                        "-b", "/dev",
                        "-b", "/sys",
                        "/bin/ls", "-la", "--group-directories-first"
                    ).redirectErrorStream(true).start()
                    process.inputStream.bufferedReader().readText().also {
                        process.waitFor()
                    }
                }

                val files = parseLsOutput(output, targetPath)
                callback(files, null)
            } catch (e: Exception) {
                callback(null, e.message)
            }
        }.start()
    }

    private fun parseLsOutput(output: String, parentPath: String): List<FileItem> {
        val items = mutableListOf<FileItem>()
        val lines = output.lines()

        for (line in lines.drop(1)) { // Skip total line
            val parts = line.trim().split(Regex("\\s+"), limit = 9)
            if (parts.size < 9) continue

            val permissions = parts[0]
            val size = parts[4].toLongOrNull() ?: 0L
            val name = parts[8]
            val lastModified = parseLsDate(parts[5], parts[6], parts[7])

            if (name == "." || name == "..") continue

            val isDirectory = permissions.startsWith("d")
            val fullPath = if (parentPath == "/") "/$name" else "$parentPath/$name"

            items.add(FileItem(
                name = name,
                path = fullPath,
                isDirectory = isDirectory,
                size = size,
                permissions = permissions,
                lastModified = lastModified
            ))
        }

        return items.sortedWith(compareBy({ !it.isDirectory }, { it.name }))
    }

    private fun parseLsDate(month: String, day: String, timeOrYear: String): Long {
        // Simplified - return current time for now
        return System.currentTimeMillis()
    }

    fun copyToShared(vmName: String, sourceUri: Uri, fileName: String): Boolean {
        return try {
            val sharedDir = getSharedDir(vmName)
            val destFile = File(sharedDir, fileName)

            context.contentResolver.openInputStream(sourceUri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    fun downloadFile(
        vmName: String,
        vmPath: String,
        destUri: Uri,
        nativeLibDir: String,
        callback: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                val rootfsDir = File(context.filesDir, "rootfs/$vmName")
                val sourceFile = File(rootfsDir, vmPath.removePrefix("/"))

                if (!sourceFile.exists()) {
                    callback(false, "File not found")
                    return@Thread
                }

                context.contentResolver.openOutputStream(destUri)?.use { output ->
                    FileInputStream(sourceFile).use { input ->
                        input.copyTo(output)
                    }
                } ?: run {
                    callback(false, "Failed to open output stream")
                    return@Thread
                }

                callback(true, null)
            } catch (e: Exception) {
                callback(false, e.message)
            }
        }.start()
    }

    fun downloadDirectory(
        vmName: String,
        vmPath: String,
        destUri: Uri,
        nativeLibDir: String,
        progressCallback: ((Int, String) -> Unit)? = null,
        callback: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                val rootfsDir = File(context.filesDir, "rootfs/$vmName")
                val sourceDir = File(rootfsDir, vmPath.removePrefix("/"))

                if (!sourceDir.exists() || !sourceDir.isDirectory) {
                    callback(false, "Directory not found")
                    return@Thread
                }

                progressCallback?.invoke(0, "Creating archive...")

                // Create zip in cache
                val zipFile = File(context.cacheDir, "${vmName}-${System.currentTimeMillis()}.zip")
                ZipOutputStream(FileOutputStream(zipFile)).use { zos ->
                    zipDirectory(sourceDir, sourceDir, zos, progressCallback)
                }

                progressCallback?.invoke(80, "Saving to device...")

                context.contentResolver.openOutputStream(destUri)?.use { output ->
                    FileInputStream(zipFile).use { input ->
                        input.copyTo(output)
                    }
                } ?: run {
                    zipFile.delete()
                    callback(false, "Failed to open output stream")
                    return@Thread
                }

                zipFile.delete()
                progressCallback?.invoke(100, "Done!")
                callback(true, null)
            } catch (e: Exception) {
                callback(false, e.message)
            }
        }.start()
    }

    private fun zipDirectory(
        rootDir: File,
        currentDir: File,
        zos: ZipOutputStream,
        progressCallback: ((Int, String) -> Unit)?,
        processed: Int = 0
    ): Int {
        var count = processed
        val files = currentDir.listFiles() ?: return count

        for (file in files) {
            val relativePath = rootDir.toURI().relativize(file.toURI()).path
            if (file.isDirectory) {
                zos.putNextEntry(ZipEntry(relativePath + "/"))
                zos.closeEntry()
                count = zipDirectory(rootDir, file, zos, progressCallback, count)
            } else {
                zos.putNextEntry(ZipEntry(relativePath))
                FileInputStream(file).use { fis ->
                    fis.copyTo(zos)
                }
                zos.closeEntry()
                count++
                if (count % 10 == 0) {
                    progressCallback?.invoke(10 + (count * 70 / 100).coerceAtMost(70), "Compressing...")
                }
            }
        }
        return count
    }

    private fun getPermissions(file: File): String {
        return if (file.isDirectory) "drwxrwxrwx" else "-rw-rw-rw-"
    }
}
