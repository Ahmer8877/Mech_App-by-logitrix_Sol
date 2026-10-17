package com.example.mech_app

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val INCOMING_CALL_CHANNEL_ID = "mechx_incoming_calls_v2"
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createIncomingCallNotificationChannel()
    }

    private fun createIncomingCallNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val soundUri = Uri.parse("android.resource://$packageName/${R.raw.mechx_incoming_ringtone}")
        val channel = NotificationChannel(
            INCOMING_CALL_CHANNEL_ID,
            "Incoming calls",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alerts for incoming MechX voice calls"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 250, 500, 250, 700)
            setSound(
                soundUri,
                android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private val ringtoneChannel = "com.mechx.app/incoming_ringtone"
    private var ringtonePlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ringtoneChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            startIncomingRingtone()
                            result.success(true)
                        } catch (error: Exception) {
                            stopIncomingRingtone()
                            result.error("RINGTONE_START_FAILED", error.message, null)
                        }
                    }
                    "stop" -> {
                        stopIncomingRingtone()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startIncomingRingtone() {
        if (ringtonePlayer?.isPlaying == true) return
        stopIncomingRingtone()
        val player = MediaPlayer()
        player.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
        )
        val ringtone = resources.openRawResourceFd(R.raw.mechx_incoming_ringtone)
        try {
            player.setDataSource(ringtone.fileDescriptor, ringtone.startOffset, ringtone.length)
        } finally {
            ringtone.close()
        }
        player.isLooping = true
        player.prepare()
        player.setOnErrorListener { _, _, _ ->
            stopIncomingRingtone()
            true
        }
        ringtonePlayer = player
        player.start()
    }

    private fun stopIncomingRingtone() {
        val player = ringtonePlayer
        ringtonePlayer = null
        try {
            player?.stop()
        } catch (_: IllegalStateException) {
        }
        try {
            player?.release()
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        stopIncomingRingtone()
        super.onDestroy()
    }
}
