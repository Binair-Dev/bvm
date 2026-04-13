package com.bvm.mobile

import java.io.IOException
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

class PortForwardManager {

    data class ForwardSession(
        val id: String,
        val vmName: String,
        val vmPort: Int,
        val hostPort: Int,
        val bindAddress: String,
        var serverSocket: ServerSocket? = null,
        var activeSockets: MutableList<Socket> = mutableListOf(),
        var errorMessage: String? = null
    )

    private val sessions = ConcurrentHashMap<String, ForwardSession>()

    fun startForward(vmName: String, vmPort: Int, hostPort: Int, bindAddress: String): ForwardSession? {
        val id = UUID.randomUUID().toString()
        val session = ForwardSession(id, vmName, vmPort, hostPort, bindAddress)

        try {
            val inetAddress = if (bindAddress == "0.0.0.0") {
                InetAddress.getByName("0.0.0.0")
            } else {
                InetAddress.getByName("127.0.0.1")
            }

            val serverSocket = ServerSocket(hostPort, 50, inetAddress)
            session.serverSocket = serverSocket
            sessions[id] = session

            thread(name = "bVM-Forward-$hostPort", isDaemon = true) {
                try {
                    while (!serverSocket.isClosed) {
                        val clientSocket = serverSocket.accept()
                        synchronized(session.activeSockets) {
                            session.activeSockets.add(clientSocket)
                        }
                        handleClient(session, clientSocket)
                    }
                } catch (_: IOException) {
                    // socket closed
                } finally {
                    stopForward(id)
                }
            }

            return session
        } catch (e: Exception) {
            session.errorMessage = e.message ?: "Unknown error"
            closeSession(session)
            return null
        }
    }

    private fun handleClient(session: ForwardSession, clientSocket: Socket) {
        thread(name = "bVM-Forward-Client-${session.hostPort}", isDaemon = true) {
            var vmSocket: Socket? = null
            try {
                vmSocket = Socket("127.0.0.1", session.vmPort)
                synchronized(session.activeSockets) {
                    session.activeSockets.add(vmSocket)
                }

                val clientToVm = thread(isDaemon = true) {
                    try {
                        clientSocket.getInputStream().copyTo(vmSocket.getOutputStream())
                    } catch (_: IOException) {}
                }

                val vmToClient = thread(isDaemon = true) {
                    try {
                        vmSocket.getInputStream().copyTo(clientSocket.getOutputStream())
                    } catch (_: IOException) {}
                }

                clientToVm.join()
                vmToClient.join()
            } catch (e: Exception) {
                // connection failed to VM port
            } finally {
                vmSocket?.let { safeClose(it); synchronized(session.activeSockets) { session.activeSockets.remove(it) } }
                safeClose(clientSocket); synchronized(session.activeSockets) { session.activeSockets.remove(clientSocket) }
            }
        }
    }

    fun stopForward(id: String): Boolean {
        val session = sessions.remove(id) ?: return false
        closeSession(session)
        return true
    }

    fun stopAllForwards() {
        sessions.values.toList().forEach { closeSession(it) }
        sessions.clear()
    }

    fun stopForwardsByVm(vmName: String) {
        sessions.values.filter { it.vmName == vmName }.forEach {
            sessions.remove(it.id)
            closeSession(it)
        }
    }

    fun listForwards(): List<ForwardSession> {
        return sessions.values.toList()
    }

    fun getForward(id: String): ForwardSession? {
        return sessions[id]
    }

    private fun closeSession(session: ForwardSession) {
        try { session.serverSocket?.close() } catch (_: Exception) {}
        synchronized(session.activeSockets) {
            session.activeSockets.forEach { safeClose(it) }
            session.activeSockets.clear()
        }
    }

    private fun safeClose(socket: Socket) {
        try { socket.close() } catch (_: Exception) {}
    }
}
