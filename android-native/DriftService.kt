package com.chronosdrift.visualizer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer

class DriftService : Service() {

    private val serviceJob = Job()
    private val scope = CoroutineScope(Dispatchers.IO + serviceJob)
    private var isRunning = false
    private var socket: DatagramSocket? = null

    companion object {
        private const val TAG = "DriftService"
        private const val CHANNEL_ID = "ChronosDriftChannel"
        private const val NOTIFICATION_ID = 101
        private const val PORT = 9988
        private const val SAMPLE_RATE_MS = 10L
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            val notification = createNotification()
            startForeground(NOTIFICATION_ID, notification)
            startTimestampBroadcasting()
            isRunning = true
        }
        return START_STICKY
    }

    private fun startTimestampBroadcasting() {
        scope.launch {
            try {
                socket = DatagramSocket()
                val broadcastAddress = InetAddress.getByName("255.255.255.255")
                socket?.broadcast = true

                while (isRunning) {
                    // Capture high-precision hardware timestamps
                    // SystemClock.elapsedRealtimeNanos() provides time since boot including sleep
                    // Nanoseconds gives sub-millisecond precision for drift analysis
                    val nanoTime = SystemClock.elapsedRealtimeNanos()
                    val unixTime = System.currentTimeMillis()

                    val buffer = ByteBuffer.allocate(16)
                    buffer.putLong(unixTime)
                    buffer.putLong(nanoTime)

                    val packet = DatagramPacket(
                        buffer.array(),
                        buffer.limit(),
                        broadcastAddress,
                        PORT
                    )

                    socket?.send(packet)
                    delay(SAMPLE_RATE_MS)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Drift broadcast error: ${e.message}")
            } finally {
                socket?.close()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Chronos Drift Background Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Chronos Drift Active")
            .setContentText("Capturing hardware clock drift metrics...")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        isRunning = false
        serviceJob.cancel()
        socket?.close()
        super.onDestroy()
    }
}