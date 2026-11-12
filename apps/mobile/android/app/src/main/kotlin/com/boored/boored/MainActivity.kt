package com.boored.boored

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.boored.boored/opencv"
    private val scope = CoroutineScope(Dispatchers.Default)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!OpenCVLoader.initDebug()) {
            Log.e("BooredOpenCV", "OpenCV initialization failed.")
        } else {
            Log.d("BooredOpenCV", "OpenCV initialization succeeded.")
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectBoardCorners" -> handleDetectCorners(call, result)
                "warpPerspective" -> handleWarpPerspective(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleDetectCorners(call: MethodCall, result: MethodChannel.Result) {
        val imagePath = call.argument<String>("imagePath")
        if (imagePath == null) {
            result.error("INVALID_ARGUMENT", "imagePath is required", null)
            return
        }

        scope.launch {
            try {
                val corners = detectCornersNative(imagePath)
                withContext(Dispatchers.Main) {
                    result.success(corners)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("OPENCV_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleWarpPerspective(call: MethodCall, result: MethodChannel.Result) {
        val srcPath = call.argument<String>("srcPath")
        val dstPath = call.argument<String>("dstPath")
        val cornersList = call.argument<List<Map<String, Double>>>("corners")

        if (srcPath == null || dstPath == null || cornersList == null || cornersList.size != 4) {
            result.error("INVALID_ARGUMENT", "srcPath, dstPath, and 4 corners are required", null)
            return
        }

        scope.launch {
            try {
                val success = warpPerspectiveNative(srcPath, dstPath, cornersList)
                withContext(Dispatchers.Main) {
                    if (success) {
                        result.success(dstPath)
                    } else {
                        result.error("WARP_FAILED", "Failed to warp image", null)
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("OPENCV_ERROR", e.message, null)
                }
            }
        }
    }

    private fun detectCornersNative(imagePath: String): List<Map<String, Double>> {
        val bitmap = BitmapFactory.decodeFile(imagePath)
            ?: throw IllegalArgumentException("Cannot decode image from $imagePath")

        val originalWidth = bitmap.width.toDouble()
        val originalHeight = bitmap.height.toDouble()

        val mat = Mat()
        Utils.bitmapToMat(bitmap, mat)
        bitmap.recycle()

        val gray = Mat()
        Imgproc.cvtColor(mat, gray, Imgproc.COLOR_BGR2GRAY)
        Imgproc.GaussianBlur(gray, gray, Size(5.0, 5.0), 0.0)

        val edges = Mat()
        Imgproc.Canny(gray, edges, 75.0, 200.0)

        val contours = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(edges, contours, hierarchy, Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)

        contours.sortByDescending { Imgproc.contourArea(it) }

        var foundCorners: Array<Point>? = null

        for (contour in contours.take(10)) {
            val peri = Imgproc.arcLength(MatOfPoint2f(*contour.toArray()), true)
            val approx = MatOfPoint2f()
            Imgproc.approxPolyDP(MatOfPoint2f(*contour.toArray()), approx, 0.02 * peri, true)

            if (approx.total() == 4L) {
                val area = Imgproc.contourArea(approx)
                if (area > (originalWidth * originalHeight * 0.15)) {
                    foundCorners = approx.toArray()
                    break
                }
            }
        }

        mat.release()
        gray.release()
        edges.release()
        hierarchy.release()

        val orderedPoints = if (foundCorners != null && foundCorners.size == 4) {
            orderPoints(foundCorners)
        } else {
            // Fallback default normalized quadrilateral (10% padding)
            arrayOf(
                Point(originalWidth * 0.08, originalHeight * 0.08),
                Point(originalWidth * 0.92, originalHeight * 0.08),
                Point(originalWidth * 0.92, originalHeight * 0.92),
                Point(originalWidth * 0.08, originalHeight * 0.92)
            )
        }

        return orderedPoints.map { pt ->
            mapOf("x" to (pt.x / originalWidth), "y" to (pt.y / originalHeight))
        }
    }

    private fun warpPerspectiveNative(
        srcPath: String,
        dstPath: String,
        cornersNorm: List<Map<String, Double>>
    ): Boolean {
        val bitmap = BitmapFactory.decodeFile(srcPath) ?: return false
        val width = bitmap.width.toDouble()
        val height = bitmap.height.toDouble()

        val srcMat = Mat()
        Utils.bitmapToMat(bitmap, srcMat)
        bitmap.recycle()

        val srcPoints = cornersNorm.map {
            Point(it["x"]!! * width, it["y"]!! * height)
        }.toTypedArray()

        val pTopLeft = srcPoints[0]
        val pTopRight = srcPoints[1]
        val pBottomRight = srcPoints[2]
        val pBottomLeft = srcPoints[3]

        val widthA = distance(pBottomRight, pBottomLeft)
        val widthB = distance(pTopRight, pTopLeft)
        val maxWidth = max(widthA, widthB).toInt()

        val heightA = distance(pTopRight, pBottomRight)
        val heightB = distance(pTopLeft, pBottomLeft)
        val maxHeight = max(heightA, heightB).toInt()

        if (maxWidth <= 0 || maxHeight <= 0) {
            srcMat.release()
            return false
        }

        val srcMat2f = MatOfPoint2f(*srcPoints)
        val dstMat2f = MatOfPoint2f(
            Point(0.0, 0.0),
            Point(maxWidth.toDouble() - 1, 0.0),
            Point(maxWidth.toDouble() - 1, maxHeight.toDouble() - 1),
            Point(0.0, maxHeight.toDouble() - 1)
        )

        val transform = Imgproc.getPerspectiveTransform(srcMat2f, dstMat2f)
        val dstMat = Mat()
        Imgproc.warpPerspective(srcMat, dstMat, transform, Size(maxWidth.toDouble(), maxHeight.toDouble()))

        val outBitmap = Bitmap.createBitmap(maxWidth, maxHeight, Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(dstMat, outBitmap)

        val file = File(dstPath)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            outBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
        }

        outBitmap.recycle()
        srcMat.release()
        dstMat.release()
        transform.release()
        srcMat2f.release()
        dstMat2f.release()

        return true
    }

    private fun distance(p1: Point, p2: Point): Double {
        val dx = p1.x - p2.x
        val dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }

    private fun orderPoints(pts: Array<Point>): Array<Point> {
        val sums = pts.map { it.x + it.y }
        val diffs = pts.map { it.y - it.x }

        val tl = pts[sums.indexOf(sums.minOrNull()!!)]
        val br = pts[sums.indexOf(sums.maxOrNull()!!)]
        val tr = pts[diffs.indexOf(diffs.minOrNull()!!)]
        val bl = pts[diffs.indexOf(diffs.maxOrNull()!!)]

        return arrayOf(tl, tr, br, bl)
    }
}
