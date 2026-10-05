package com.aiandrox.ramen_in_cho

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import java.io.File

/**
 * ほかのアプリの「共有」から写真を受け取る入口。写真を預かって麺印帳の画面を開き、すぐに閉じる。
 * 麺印帳の画面は開いたときに [SharedPhotoInbox] から写真を受け取る。
 */
class ShareReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val photo = sharedPhotoOf(intent)
        if (photo == null) {
            finish()
            return
        }
        // 共有元の読み取りの許可はこの画面の間しか続かないので、閉じる前に手元へ写す。
        Thread {
            runCatching { SharedPhotoInbox.put(receive(photo)) }
                .onFailure { Log.w(TAG, "Shared photo failed", it) }
            runOnUiThread {
                startActivity(
                    Intent(this, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                finish()
            }
        }.start()
    }

    private fun sharedPhotoOf(intent: Intent?): Uri? {
        if (intent?.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("image/") != true) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    // ギャラリーから選んだときと同じ大きさに縮め、撮影日時と撮影場所は残す。
    private fun receive(uri: Uri): String {
        val directory = File(cacheDir, "shared_photos").apply { mkdirs() }
        // 記録画面で使っている途中の写真を消さないよう、1日より前のものだけ片付ける。
        val dayAgo = System.currentTimeMillis() - 24 * 60 * 60 * 1000L
        directory.listFiles()?.filter { it.lastModified() < dayAgo }?.forEach { it.delete() }
        val stamp = System.currentTimeMillis()
        val original = File(directory, "original-$stamp")
        contentResolver.openInputStream(uri)!!.use { input ->
            original.outputStream().use { output -> input.copyTo(output) }
        }
        val resized = File(directory, "shared-$stamp.jpg")
        return runCatching { resize(original, resized) }
            .map {
                original.delete()
                resized.path
            }
            .getOrElse {
                Log.w(TAG, "Shared photo resize failed", it)
                original.path
            }
    }

    private fun resize(source: File, destination: File) {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.path, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_SIZE) sample *= 2
        val decoded = BitmapFactory.decodeFile(
            source.path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: error("decode failed")
        val exif = ExifInterface(source.path)
        val scale = minOf(1f, MAX_SIZE.toFloat() / maxOf(decoded.width, decoded.height))
        val matrix = Matrix().apply {
            postScale(scale, scale)
            postRotate(rotationOf(exif))
        }
        val bitmap = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        destination.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, QUALITY, it) }
        val copied = ExifInterface(destination.path)
        for (tag in KEPT_TAGS) exif.getAttribute(tag)?.let { copied.setAttribute(tag, it) }
        copied.saveAttributes()
    }

    private fun rotationOf(exif: ExifInterface): Float =
        when (exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }

    companion object {
        private const val TAG = "SharedPhoto"
        private const val MAX_SIZE = 2000
        private const val QUALITY = 85
        private val KEPT_TAGS = listOf(
            ExifInterface.TAG_DATETIME_ORIGINAL,
            ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_OFFSET_TIME_DIGITIZED,
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_OFFSET_TIME,
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
        )
    }
}

/** 受け取った写真を、麺印帳の画面が受け取るまで預かる。 */
object SharedPhotoInbox {
    private var pending: String? = null

    @Synchronized
    fun put(path: String) {
        pending = path
    }

    @Synchronized
    fun take(): String? = pending.also { pending = null }
}
