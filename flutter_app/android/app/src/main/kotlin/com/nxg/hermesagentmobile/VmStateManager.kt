package com.bvm.mobile

import org.json.JSONObject
import java.io.File

class VmStateManager(private val filesDir: String) {

    private fun stateDir(vmName: String): File {
        return File("$filesDir/vm_state/$vmName").apply { mkdirs() }
    }

    private fun stateFile(vmName: String): File {
        return File(stateDir(vmName), "state.json")
    }

    private fun defaultState(): JSONObject {
        return JSONObject().apply {
            put("isRunning", false)
            put("pid", -1)
            put("autoStart", false)
            put("createdAt", System.currentTimeMillis())
        }
    }

    fun getState(vmName: String): JSONObject {
        val file = stateFile(vmName)
        return if (file.exists()) {
            try {
                JSONObject(file.readText())
            } catch (_: Exception) {
                defaultState()
            }
        } else {
            defaultState()
        }
    }

    fun saveState(vmName: String, state: JSONObject) {
        stateFile(vmName).writeText(state.toString(2))
    }

    fun setRunning(vmName: String, isRunning: Boolean, pid: Int = -1) {
        val state = getState(vmName)
        state.put("isRunning", isRunning)
        state.put("pid", pid)
        saveState(vmName, state)
    }

    fun isRunning(vmName: String): Boolean {
        val state = getState(vmName)
        val running = state.optBoolean("isRunning", false)
        val pid = state.optInt("pid", -1)

        // Validate: if a pid is stored, check if the process is actually alive
        return if (running && pid > 0) {
            isProcessAlive(pid)
        } else {
            running
        }
    }

    fun getPid(vmName: String): Int {
        return getState(vmName).optInt("pid", -1)
    }

    fun setAutoStart(vmName: String, autoStart: Boolean) {
        val state = getState(vmName)
        state.put("autoStart", autoStart)
        saveState(vmName, state)
    }

    fun getAutoStart(vmName: String): Boolean {
        return getState(vmName).optBoolean("autoStart", false)
    }

    fun listAutoStartVms(): List<String> {
        val stateRoot = File("$filesDir/vm_state")
        if (!stateRoot.exists()) return emptyList()
        return stateRoot.listFiles { f -> f.isDirectory }?.map { it.name }?.filter {
            getAutoStart(it)
        } ?: emptyList()
    }

    private fun isProcessAlive(pid: Int): Boolean {
        return try {
            android.os.Process.killProcess(pid)
            // If we can send signal 0, process exists
            val process = Runtime.getRuntime().exec(arrayOf("kill", "-0", pid.toString()))
            process.waitFor() == 0
        } catch (_: Exception) {
            false
        }
    }

    fun stopVm(vmName: String): Boolean {
        val state = getState(vmName)
        val pid = state.optInt("pid", -1)
        var stopped = false

        if (pid > 0) {
            stopped = try {
                android.os.Process.killProcess(pid)
                val process = Runtime.getRuntime().exec(arrayOf("kill", "-9", pid.toString()))
                process.waitFor()
                true
            } catch (_: Exception) {
                false
            }
        }

        // Also try to kill any remaining proot processes for this VM
        try {
            val p = Runtime.getRuntime().exec(
                arrayOf("pkill", "-9", "-f", "rootfs/$vmName")
            )
            p.waitFor()
        } catch (_: Exception) {}

        setRunning(vmName, false, -1)
        return stopped || true
    }
}
