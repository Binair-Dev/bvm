package com.bvm.mobile

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class VmBackupManager(private val context: Context) {

    data class Progress(val current: Long, val total: Long, val message: String)

    fun exportVm(vmName: String, destUri: Uri, progressCallback: ((Progress) -> Unit)? = null, callback: (Boolean, String?) -> Unit) {
        Thread {
            try {
                val rootfsDir = File("${context.filesDir.absolutePath}/rootfs")
                val vmDir = File(rootfsDir, vmName)
                if (!vmDir.exists()) {
                    callback(false, "VM does not exist")
                    return@Thread
                }

                val totalSize = getVmSize(vmName)
                progressCallback?.invoke(Progress(0, totalSize, "Calculating size..."))

                val cacheFile = File(context.cacheDir, "bvm-export-${vmName}-${System.currentTimeMillis()}.tar.gz")

                progressCallback?.invoke(Progress(0, totalSize, "Compressing VM..."))

                val process = ProcessBuilder(
                    "tar", "-czf", cacheFile.absolutePath, "-C", rootfsDir.absolutePath, vmName
                ).redirectErrorStream(true).start()

                val reader = process.inputStream.bufferedReader()
                Thread {
                    reader.use { it.readText() }
                }.start()

                process.waitFor()
                val exitCode = process.exitValue()

                // tar exit code 1 often means "some files differ" (e.g. special files, symlinks)
                // but the archive is still usable. Accept if archive was created.
                if (exitCode != 0 && (!cacheFile.exists() || cacheFile.length() == 0L)) {
                    cacheFile.delete()
                    callback(false, "EXPORT: tar compression failed with code $exitCode")
                    return@Thread
                }

                val compressedSize = cacheFile.length()
                progressCallback?.invoke(Progress(compressedSize / 2, totalSize, "Saving backup..."))

                context.contentResolver.openOutputStream(destUri)?.use { out ->
                    FileInputStream(cacheFile).use { `in` ->
                        val buffer = ByteArray(8192)
                        var bytesCopied = 0L
                        var read: Int
                        while (`in`.read(buffer).also { read = it } != -1) {
                            out.write(buffer, 0, read)
                            bytesCopied += read
                            progressCallback?.invoke(Progress(compressedSize / 2 + bytesCopied / 2, totalSize, "Saving backup..."))
                        }
                    }
                } ?: run {
                    cacheFile.delete()
                    callback(false, "Failed to open output stream")
                    return@Thread
                }

                cacheFile.delete()
                progressCallback?.invoke(Progress(totalSize, totalSize, "Done!"))
                callback(true, null)
            } catch (e: Exception) {
                callback(false, e.message)
            }
        }.start()
    }

    fun importVm(sourceUri: Uri, vmName: String, progressCallback: ((Progress) -> Unit)? = null, callback: (Boolean, String?) -> Unit) {
        Thread {
            try {
                val rootfsDir = File("${context.filesDir.absolutePath}/rootfs")
                rootfsDir.mkdirs()

                val vmDir = File(rootfsDir, vmName)
                if (vmDir.exists()) {
                    callback(false, "VM already exists")
                    return@Thread
                }

                val cacheFile = File(context.cacheDir, "bvm-import-${System.currentTimeMillis()}.tar.gz")
                progressCallback?.invoke(Progress(0, 100, "Reading backup file..."))

                context.contentResolver.openInputStream(sourceUri)?.use { `in` ->
                    FileOutputStream(cacheFile).use { out ->
                        val totalBytes = `in`.available().toLong()
                        val buffer = ByteArray(8192)
                        var bytesRead = 0L
                        var read: Int
                        while (`in`.read(buffer).also { read = it } != -1) {
                            out.write(buffer, 0, read)
                            bytesRead += read
                            val pct = if (totalBytes > 0) (bytesRead * 50 / totalBytes) else 50
                            progressCallback?.invoke(Progress(pct, 100, "Reading backup file..."))
                        }
                    }
                } ?: run {
                    callback(false, "Failed to open input stream")
                    return@Thread
                }

                progressCallback?.invoke(Progress(50, 100, "Extracting VM..."))

                val process = ProcessBuilder(
                    "tar", "-xzf", cacheFile.absolutePath, "-C", rootfsDir.absolutePath
                ).redirectErrorStream(true).start()

                val reader = process.inputStream.bufferedReader()
                Thread {
                    reader.use { it.readText() }
                }.start()

                process.waitFor()
                val exitCode = process.exitValue()
                cacheFile.delete()

                if (exitCode != 0) {
                    callback(false, "IMPORT: tar extraction failed with code $exitCode")
                    return@Thread
                }

                progressCallback?.invoke(Progress(100, 100, "Done!"))
                callback(true, null)
                
                // Setup shared directory symlink for imported VM
                try {
                    FileSharingManager(context).setupSharedDir(vmName)
                } catch (_: Exception) {}
            } catch (e: Exception) {
                callback(false, e.message)
            }
        }.start()
    }

    fun getVmSize(vmName: String): Long {
        val vmDir = File("${context.filesDir.absolutePath}/rootfs", vmName)
        return getFolderSize(vmDir)
    }

    private fun getFolderSize(file: File): Long {
        var size: Long = 0
        if (file.isDirectory) {
            file.listFiles()?.forEach { size += getFolderSize(it) }
        } else {
            size = file.length()
        }
        return size
    }
}
