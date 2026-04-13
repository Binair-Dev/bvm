package com.bvm.mobile

import android.os.Build
import android.os.Environment
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class ProcessManager(
    private val filesDir: String,
    private val nativeLibDir: String
) {
    private fun rootfsDir(vmName: String) = "$filesDir/rootfs/$vmName"
    private val tmpDir get() = "$filesDir/tmp"
    private val homeDir get() = "$filesDir/home"
    private val configDir get() = "$filesDir/config"
    private val libDir get() = "$filesDir/lib"

    companion object {
        const val FAKE_KERNEL_RELEASE = "6.17.0-PRoot-Distro"
        const val FAKE_KERNEL_VERSION =
            "#1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000"
    }

    fun getProotPath(): String = "$nativeLibDir/libproot.so"

    private fun prootEnv(): Map<String, String> = mapOf(
        "PROOT_TMP_DIR" to tmpDir,
        "PROOT_LOADER" to "$nativeLibDir/libprootloader.so",
        "PROOT_LOADER_32" to "$nativeLibDir/libprootloader32.so",
        "LD_LIBRARY_PATH" to "$libDir:$nativeLibDir",
    )

    private fun ensureResolvConf(vmName: String) {
        val content = "nameserver 8.8.8.8\nnameserver 8.8.4.4\n"
        try {
            val resolvFile = File(configDir, "resolv.conf")
            if (!resolvFile.exists() || resolvFile.length() == 0L) {
                resolvFile.parentFile?.mkdirs()
                resolvFile.writeText(content)
            }
        } catch (_: Exception) {}
        try {
            val rootfsResolv = File(rootfsDir(vmName), "etc/resolv.conf")
            if (!rootfsResolv.exists() || rootfsResolv.length() == 0L) {
                rootfsResolv.parentFile?.mkdirs()
                rootfsResolv.writeText(content)
            }
        } catch (_: Exception) {}
    }

    private fun commonProotFlags(vmName: String): List<String> {
        ensureResolvConf(vmName)
        val rfs = rootfsDir(vmName)
        val prootPath = getProotPath()
        val procFakes = "$configDir/proc_fakes"
        val sysFakes = "$configDir/sys_fakes"

        return listOf(
            prootPath,
            "--link2symlink",
            "-L",
            "--kill-on-exit",
            "--rootfs=$rfs",
            "--cwd=/root",
            "--bind=/dev",
            "--bind=/dev/urandom:/dev/random",
            "--bind=/proc",
            "--bind=/proc/self/fd:/dev/fd",
            "--bind=/proc/self/fd/0:/dev/stdin",
            "--bind=/proc/self/fd/1:/dev/stdout",
            "--bind=/proc/self/fd/2:/dev/stderr",
            "--bind=/sys",
            "--bind=$procFakes/loadavg:/proc/loadavg",
            "--bind=$procFakes/stat:/proc/stat",
            "--bind=$procFakes/uptime:/proc/uptime",
            "--bind=$procFakes/version:/proc/version",
            "--bind=$procFakes/vmstat:/proc/vmstat",
            "--bind=$procFakes/cap_last_cap:/proc/sys/kernel/cap_last_cap",
            "--bind=$procFakes/max_user_watches:/proc/sys/fs/inotify/max_user_watches",
            "--bind=$procFakes/fips_enabled:/proc/sys/crypto/fips_enabled",
            "--bind=$rfs/tmp:/dev/shm",
            "--bind=$sysFakes/empty:/sys/fs/selinux",
            "--bind=$configDir/resolv.conf:/etc/resolv.conf",
            "--bind=$homeDir:/root/home",
            "--bind=$filesDir/shared/$vmName:/mnt/shared",
        ).let { flags ->
            // Ensure shared directory exists before proot bind
            File("$filesDir/shared/$vmName").mkdirs()
            val hasAccess = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Environment.isExternalStorageManager()
            } else {
                val sdcard = Environment.getExternalStorageDirectory()
                sdcard.exists() && sdcard.canRead()
            }

            if (hasAccess) {
                val storageDir = File("$rfs/storage")
                storageDir.mkdirs()
                val sdcardLink = File("$rfs/sdcard")
                if (!sdcardLink.exists()) {
                    try {
                        Runtime.getRuntime().exec(
                            arrayOf("ln", "-sf", "/storage/emulated/0", "$rfs/sdcard")
                        ).waitFor()
                    } catch (_: Exception) {
                        sdcardLink.mkdirs()
                    }
                }
                flags + listOf(
                    "--bind=/storage:/storage",
                    "--bind=/storage/emulated/0:/sdcard"
                )
            } else {
                flags
            }
        }
    }

    fun buildInstallCommand(command: String, vmName: String = "ubuntu"): List<String> {
        val flags = commonProotFlags(vmName).toMutableList()
        flags.add(1, "--root-id")
        flags.add(2, "--kernel-release=$FAKE_KERNEL_RELEASE")
        flags.addAll(listOf(
            "/usr/bin/env", "-i",
            "HOME=/root",
            "LANG=C.UTF-8",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "TERM=xterm-256color",
            "TMPDIR=/tmp",
            "DEBIAN_FRONTEND=noninteractive",
            "npm_config_cache=/tmp/npm-cache",
            "/bin/bash", "-c",
            command,
        ))
        return flags
    }

    fun buildGatewayCommand(vmName: String = "ubuntu"): List<String> {
        val flags = commonProotFlags(vmName).toMutableList()
        flags.add(1, "--change-id=0:0")
        flags.add(2, "--sysvipc")
        val machine = ArchUtils.getArch()
        val kernelRelease = "\\Linux\\localhost\\$FAKE_KERNEL_RELEASE\\$FAKE_KERNEL_VERSION\\$machine\\localdomain\\-1\\"
        flags.add(3, "--kernel-release=$kernelRelease")
        flags.addAll(listOf(
            "/usr/bin/env", "-i",
            "HOME=/root",
            "USER=root",
            "LANG=C.UTF-8",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "TERM=xterm-256color",
            "TMPDIR=/tmp",
            "/bin/bash", "-l",
        ))
        return flags
    }

    fun runInProotSync(command: String, timeout: Long = 900L, vmName: String = "ubuntu"): String {
        val pb = ProcessBuilder(buildInstallCommand(command, vmName))
        pb.environment().putAll(prootEnv())
        pb.directory(File(filesDir))
        pb.redirectErrorStream(true)
        val process = pb.start()
        val output = StringBuilder()
        BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                output.appendLine(line)
            }
        }
        process.waitFor()
        return output.toString()
    }
}
