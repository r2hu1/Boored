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
import kotlin.math.abs
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
                "enhanceWhiteboard" -> handleEnhance(call, result)
                "detectFrameChange" -> handleDetectChange(call, result)
                "compositeUnoccluded" -> handleComposite(call, result)
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

    private fun handleEnhance(call: MethodCall, result: MethodChannel.Result) {
        val srcPath = call.argument<String>("srcPath")
        val dstPath = call.argument<String>("dstPath")

        if (srcPath == null || dstPath == null) {
            result.error("INVALID_ARGUMENT", "srcPath and dstPath are required", null)
            return
        }

        scope.launch {
            try {
                val success = enhanceWhiteboardNative(srcPath, dstPath)
                withContext(Dispatchers.Main) {
                    if (success) {
                        result.success(dstPath)
                    } else {
                        result.error("ENHANCE_FAILED", "Failed to enhance image", null)
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("OPENCV_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleDetectChange(call: MethodCall, result: MethodChannel.Result) {
        val prevPath = call.argument<String>("prevPath")
        val currPath = call.argument<String>("currPath")

        if (prevPath == null || currPath == null) {
            result.error("INVALID_ARGUMENT", "prevPath and currPath are required", null)
            return
        }

        scope.launch {
            try {
                val changeData = detectChangeNative(prevPath, currPath)
                withContext(Dispatchers.Main) {
                    result.success(changeData)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("OPENCV_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleComposite(call: MethodCall, result: MethodChannel.Result) {
        val currentPath = call.argument<String>("currentPath")
        val cleanBackgroundPath = call.argument<String>("cleanBackgroundPath")
        val dstPath = call.argument<String>("dstPath")
        val maskConfidences = call.argument<List<Double>>("maskConfidences")
        val maskWidth = call.argument<Int>("maskWidth")
        val maskHeight = call.argument<Int>("maskHeight")

        if (currentPath == null || cleanBackgroundPath == null || dstPath == null ||
            maskConfidences == null || maskWidth == null || maskHeight == null) {
            result.error("INVALID_ARGUMENT", "All composite arguments are required", null)
            return
        }

        scope.launch {
            try {
                val success = compositeNative(
                    currentPath,
                    cleanBackgroundPath,
                    dstPath,
                    maskConfidences,
                    maskWidth,
                    maskHeight
                )
                withContext(Dispatchers.Main) {
                    if (success) {
                        result.success(dstPath)
                    } else {
                        result.error("COMPOSITE_FAILED", "Failed to composite frames", null)
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

        // Enhance contrast using CLAHE to separate whiteboard borders under classroom light
        val clahe = Imgproc.createCLAHE(3.0, Size(8.0, 8.0))
        val contrasted = Mat()
        clahe.apply(gray, contrasted)

        // Multiple thresholding stages: Canny + adaptive threshold to detect whiteboard frame edges
        val edges = Mat()
        Imgproc.Canny(contrasted, edges, 30.0, 120.0)
        // Dilate slightly to connect broken board boundary edges
        val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(3.0, 3.0))
        Imgproc.dilate(edges, edges, kernel)

        val contours = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(edges, contours, hierarchy, Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)

        contours.sortByDescending { Imgproc.contourArea(it) }

        var foundCorners: Array<Point>? = null

        for (contour in contours.take(20)) {
            val peri = Imgproc.arcLength(MatOfPoint2f(*contour.toArray()), true)
            for (eps in doubleArrayOf(0.02, 0.03, 0.04, 0.05)) {
                val approx = MatOfPoint2f()
                Imgproc.approxPolyDP(MatOfPoint2f(*contour.toArray()), approx, eps * peri, true)

                if (approx.total() == 4L) {
                    val area = Imgproc.contourArea(approx)
                    // Must be a significant quadrilateral covering >= 10% of frame
                    if (area > (originalWidth * originalHeight * 0.10)) {
                        foundCorners = approx.toArray()
                        break
                    }
                }
            }
            if (foundCorners != null) break
        }

        mat.release()
        gray.release()
        contrasted.release()
        edges.release()
        kernel.release()
        hierarchy.release()

        val orderedPoints = if (foundCorners != null && foundCorners.size == 4) {
            orderPoints(foundCorners)
        } else {
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

    private fun enhanceWhiteboardNative(srcPath: String, dstPath: String): Boolean {
        val bitmap = BitmapFactory.decodeFile(srcPath) ?: return false
        val bgr = Mat()
        Utils.bitmapToMat(bitmap, bgr)
        bitmap.recycle()

        // 1. Convert to LAB color space for lighting normalization
        val lab = Mat()
        Imgproc.cvtColor(bgr, lab, Imgproc.COLOR_BGR2Lab)
        val labPlanes = ArrayList<Mat>(3)
        Core.split(lab, labPlanes)

        // CLAHE (Contrast Limited Adaptive Histogram Equalization) on L-channel
        val clahe = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
        clahe.apply(labPlanes[0], labPlanes[0])
        Core.merge(labPlanes, lab)
        Imgproc.cvtColor(lab, bgr, Imgproc.COLOR_Lab2BGR)

        // 2. Stroke sharpening using unsharp mask
        val blurred = Mat()
        Imgproc.GaussianBlur(bgr, blurred, Size(0.0, 0.0), 3.0)
        Core.addWeighted(bgr, 1.5, blurred, -0.5, 0.0, bgr)

        val outBitmap = Bitmap.createBitmap(bgr.cols(), bgr.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(bgr, outBitmap)

        val file = File(dstPath)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            outBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
        }

        outBitmap.recycle()
        bgr.release()
        lab.release()
        blurred.release()
        for (p in labPlanes) p.release()

        return true
    }

    private fun detectChangeNative(prevPath: String, currPath: String): Map<String, Any> {
        val prevBmp = BitmapFactory.decodeFile(prevPath)
            ?: return mapOf("eventType" to "NONE", "diffRatio" to 0.0)
        val currBmp = BitmapFactory.decodeFile(currPath)
            ?: return mapOf("eventType" to "NONE", "diffRatio" to 0.0)

        val prevMat = Mat()
        val currMat = Mat()
        Utils.bitmapToMat(prevBmp, prevMat)
        Utils.bitmapToMat(currBmp, currMat)
        prevBmp.recycle()
        currBmp.recycle()

        if (prevMat.size() != currMat.size()) {
            Imgproc.resize(currMat, currMat, prevMat.size())
        }

        val prevGray = Mat()
        val currGray = Mat()
        Imgproc.cvtColor(prevMat, prevGray, Imgproc.COLOR_BGR2GRAY)
        Imgproc.cvtColor(currMat, currGray, Imgproc.COLOR_BGR2GRAY)

        val diff = Mat()
        Core.absdiff(prevGray, currGray, diff)

        val thresh = Mat()
        Imgproc.threshold(diff, thresh, 30.0, 255.0, Imgproc.THRESH_BINARY)

        val totalPixels = (thresh.rows() * thresh.cols()).toDouble()
        val changedPixels = Core.countNonZero(thresh).toDouble()
        val diffRatio = changedPixels / totalPixels

        // Determine ADD vs ERASE based on mean brightness shift in changed areas
        var eventType = "NONE"
        if (diffRatio > 0.02) { // More than 2% changed
            val prevMean = Core.mean(prevGray, thresh).`val`[0]
            val currMean = Core.mean(currGray, thresh).`val`[0]

            eventType = if (currMean > prevMean + 5) {
                "ERASE" // Area became significantly brighter (ink wiped off to white board)
            } else {
                "ADD" // New ink written (darker or colored)
            }
        }

        prevMat.release()
        currMat.release()
        prevGray.release()
        currGray.release()
        diff.release()
        thresh.release()

        return mapOf(
            "eventType" to eventType,
            "diffRatio" to diffRatio
        )
    }

    private fun compositeNative(
        currentPath: String,
        cleanBackgroundPath: String,
        dstPath: String,
        maskConfidences: List<Double>,
        maskWidth: Int,
        maskHeight: Int
    ): Boolean {
        val currBmp = BitmapFactory.decodeFile(currentPath) ?: return false
        val bgBmp = BitmapFactory.decodeFile(cleanBackgroundPath) ?: return false

        val currMat = Mat()
        val bgMat = Mat()
        Utils.bitmapToMat(currBmp, currMat)
        Utils.bitmapToMat(bgBmp, bgMat)
        currBmp.recycle()
        bgBmp.recycle()

        if (currMat.size() != bgMat.size()) {
            Imgproc.resize(bgMat, bgMat, currMat.size())
        }

        // Build binary person mask from confidence array
        val maskByteArray = ByteArray(maskWidth * maskHeight)
        for (i in maskConfidences.indices) {
            maskByteArray[i] = if (maskConfidences[i] > 0.65) 255.toByte() else 0.toByte()
        }

        val rawMaskMat = Mat(maskHeight, maskWidth, CvType.CV_8UC1)
        rawMaskMat.put(0, 0, maskByteArray)

        val fullMaskMat = Mat()
        Imgproc.resize(rawMaskMat, fullMaskMat, currMat.size(), 0.0, 0.0, Imgproc.INTER_NEAREST)

        // Composite: where person is detected (mask > 0), use clean background; else current frame
        val resultMat = Mat()
        currMat.copyTo(resultMat)
        bgMat.copyTo(resultMat, fullMaskMat)

        val outBitmap = Bitmap.createBitmap(resultMat.cols(), resultMat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(resultMat, outBitmap)

        val file = File(dstPath)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            outBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
        }

        outBitmap.recycle()
        currMat.release()
        bgMat.release()
        rawMaskMat.release()
        fullMaskMat.release()
        resultMat.release()

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
