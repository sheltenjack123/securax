package com.example.my_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.TotalCaptureResult
import android.hardware.Camera
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class CameraService : Service() {
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var bgThread: HandlerThread? = null
    private var bgHandler: Handler? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startBackgroundThread()
        startInForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "CameraService onStartCommand()")
        if (!hasPermission(Manifest.permission.CAMERA)) {
            Log.e(TAG, "Camera permission missing. Evidence capture skipped.")
            stopSelf()
            return START_NOT_STICKY
        }

        captureOnceAndUpload()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        closeCamera()
        stopBackgroundThread()
    }

    private fun startInForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIF_CHANNEL_ID,
                "Securax Security",
                NotificationManager.IMPORTANCE_LOW
            )
            nm.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setContentTitle("Securax")
            .setContentText("Capturing security evidence")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()

        startForeground(NOTIF_ID, notification)
    }

    private fun startBackgroundThread() {
        bgThread = HandlerThread("SecuraxCamera").also { it.start() }
        bgHandler = Handler(bgThread!!.looper)
    }

    private fun stopBackgroundThread() {
        bgThread?.quitSafely()
        bgThread = null
        bgHandler = null
    }

    private fun hasPermission(perm: String): Boolean {
        return ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
    }

    private fun captureOnceAndUpload() {
        val handler = bgHandler ?: run {
            Log.e(TAG, "Background handler missing.")
            stopSelf()
            return
        }

        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = findFrontCameraId(cameraManager)
        if (cameraId == null) {
            Log.e(TAG, "No front camera found.")
            stopSelf()
            return
        }

        try {
            val chars = cameraManager.getCameraCharacteristics(cameraId)
            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val jpegSizes = map?.getOutputSizes(ImageFormat.JPEG)
            val size = jpegSizes?.minByOrNull { it.width * it.height }
            if (size == null) {
                Log.e(TAG, "No JPEG output size available.")
                stopSelf()
                return
            }

            imageReader = ImageReader.newInstance(size.width, size.height, ImageFormat.JPEG, 1)
            imageReader!!.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                val buffer = image.planes[0].buffer
                val bytes = ByteArray(buffer.remaining())
                buffer.get(bytes)
                image.close()

                try {
                    val file = File(evidenceDir(), evidenceFileName("system_password_failed"))
                    FileOutputStream(file).use { it.write(bytes) }
                    pruneEvidence(keep = 10)
                    uploadEvidence(file)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to save/upload image.", e)
                } finally {
                    stopSelf()
                }
            }, handler)

            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    Log.d(TAG, "Camera opened.")
                    cameraDevice = camera
                    createSessionAndCapture()
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                    stopSelf()
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    Log.e(TAG, "Camera onError=$error")
                    camera.close()
                    cameraDevice = null
                    stopSelf()
                }
            }, handler)
        } catch (e: SecurityException) {
            Log.e(TAG, "Camera open SecurityException.", e)
            stopSelf()
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Camera access error.", e)
            stopSelf()
        }
    }

    private fun createSessionAndCapture() {
        val camera = cameraDevice ?: run {
            stopSelf()
            return
        }
        val readerSurface = imageReader?.surface ?: run {
            stopSelf()
            return
        }

        try {
            camera.createCaptureSession(
                listOf(readerSurface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        takePicture()
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        stopSelf()
                    }
                },
                bgHandler
            )
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Failed to create capture session.", e)
            closeCamera()
            captureWithLegacyCameraFallback()
        }
    }

    private fun takePicture() {
        val camera = cameraDevice ?: return
        val session = captureSession ?: return
        val readerSurface = imageReader?.surface ?: return

        try {
            // Some vendors fail STILL_CAPTURE in background service. TEMPLATE_PREVIEW is more compatible.
            val req = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                addTarget(readerSurface)
                set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            }.build()

            session.capture(req, object : CameraCaptureSession.CaptureCallback() {
                override fun onCaptureCompleted(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    result: TotalCaptureResult
                ) {
                    // ImageReader callback does the rest.
                }
            }, bgHandler)
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Capture failed.", e)
            closeCamera()
            captureWithLegacyCameraFallback()
        }
    }

    private fun closeCamera() {
        try { captureSession?.close() } catch (_: Exception) {}
        captureSession = null
        try { cameraDevice?.close() } catch (_: Exception) {}
        cameraDevice = null
        try { imageReader?.close() } catch (_: Exception) {}
        imageReader = null
    }

    private fun captureWithLegacyCameraFallback() {
        val handler = bgHandler ?: run {
            stopSelf()
            return
        }
        handler.post {
            Log.d(TAG, "Falling back to legacy Camera API.")
            var cam: Camera? = null
            try {
                val camId = findLegacyFrontCameraId()
                if (camId == null) {
                    Log.e(TAG, "Legacy camera: no front camera found.")
                    stopSelf()
                    return@post
                }
                cam = Camera.open(camId)

                // Legacy API needs a preview target, even if we never show it.
                val st = SurfaceTexture(0)
                cam.setPreviewTexture(st)
                cam.startPreview()

                cam.takePicture(null, null) { data, camera ->
                    try {
                        val file = File(evidenceDir(), evidenceFileName("system_password_failed"))
                        FileOutputStream(file).use { it.write(data) }
                        pruneEvidence(keep = 10)
                        uploadEvidence(file)
                    } catch (e: Exception) {
                        Log.e(TAG, "Legacy capture/upload failed.", e)
                    } finally {
                        try { camera.stopPreview() } catch (_: Exception) {}
                        try { camera.release() } catch (_: Exception) {}
                        stopSelf()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Legacy camera fallback failed.", e)
                try { cam?.release() } catch (_: Exception) {}
                stopSelf()
            }
        }
    }

    private fun findLegacyFrontCameraId(): Int? {
        return try {
            val count = Camera.getNumberOfCameras()
            val info = Camera.CameraInfo()
            var first: Int? = null
            for (i in 0 until count) {
                Camera.getCameraInfo(i, info)
                if (first == null) first = i
                if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) return i
            }
            first
        } catch (_: Exception) {
            null
        }
    }

    private fun findFrontCameraId(cameraManager: CameraManager): String? {
        return try {
            cameraManager.cameraIdList.firstOrNull { id ->
                val chars = cameraManager.getCameraCharacteristics(id)
                chars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
            } ?: cameraManager.cameraIdList.firstOrNull()
        } catch (e: Exception) {
            null
        }
    }

    private fun uploadEvidence(file: File) {
        // Keep this dependency-free: use HttpURLConnection multipart.
        val baseUrl = readBaseUrl()
        val boundary = "----SecuraxBoundary${System.currentTimeMillis()}"
        val url = URL("${baseUrl}/upload_evidence")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            doInput = true
            useCaches = false
            setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
            connectTimeout = 15000
            readTimeout = 15000
        }

        try {
            Log.d(TAG, "Uploading to $baseUrl")
            conn.outputStream.use { out ->
                fun writeText(name: String, value: String) {
                    out.write("--$boundary\r\n".toByteArray())
                    out.write("Content-Disposition: form-data; name=\"$name\"\r\n\r\n".toByteArray())
                    out.write(value.toByteArray())
                    out.write("\r\n".toByteArray())
                }

                writeText("location", "Unknown Location")
                writeText("device", Build.MODEL ?: "Android")
                writeText("reason", "system_password_failed")

                out.write("--$boundary\r\n".toByteArray())
                out.write(
                    "Content-Disposition: form-data; name=\"photo\"; filename=\"${file.name}\"\r\n".toByteArray()
                )
                out.write("Content-Type: image/jpeg\r\n\r\n".toByteArray())
                file.inputStream().use { it.copyTo(out) }
                out.write("\r\n".toByteArray())
                out.write("--$boundary--\r\n".toByteArray())
            }

            val code = conn.responseCode
            Log.d(TAG, "Upload response code=$code")
            // Drain response streams.
            try { conn.inputStream.use { it.readBytes() } } catch (_: Exception) {}
            try { conn.errorStream?.use { it.readBytes() } } catch (_: Exception) {}
        } catch (e: Exception) {
            Log.e(TAG, "Upload failed.", e)
        } finally {
            conn.disconnect()
        }
    }

    private fun readBaseUrl(): String {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val v = prefs.getString("flutter.backend_base_url", null)
            if (v.isNullOrBlank()) BackendConfig.baseUrl else v
        } catch (_: Exception) {
            BackendConfig.baseUrl
        }
    }

    private fun safeReason(reason: String): String {
        val trimmed = reason.trim()
        if (trimmed.isEmpty()) return "unknown"
        val safe = trimmed.replace(Regex("[^a-zA-Z0-9_-]+"), "_").replace(Regex("_+"), "_")
        return safe.trim('_').ifEmpty { "unknown" }
    }

    private fun evidenceFileName(reason: String): String {
        val ts = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date())
        val suffix = UUID.randomUUID().toString().replace("-", "").take(6)
        return "${ts}_${safeReason(reason)}_${suffix}.jpg"
    }

    private fun evidenceDir(): File {
        val dir = File(filesDir, "evidence_vault")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun pruneEvidence(keep: Int = 10) {
        if (keep <= 0) return
        try {
            val dir = evidenceDir()
            val files = dir.listFiles()?.filter { f ->
                f.isFile && (f.name.endsWith(".jpg", ignoreCase = true) ||
                        f.name.endsWith(".jpeg", ignoreCase = true) ||
                        f.name.endsWith(".png", ignoreCase = true))
            }?.sortedByDescending { it.lastModified() } ?: return

            if (files.size <= keep) return
            for (f in files.drop(keep)) {
                try { f.delete() } catch (_: Exception) {}
            }
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val TAG = "SecuraxCam"
        private const val NOTIF_CHANNEL_ID = "securax_security"
        private const val NOTIF_ID = 1001
    }
}
