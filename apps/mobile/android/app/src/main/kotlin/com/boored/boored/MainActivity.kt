package com.boored.boored

import android.content.ClipData
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
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
                "openPdf" -> handleOpenPdf(call, result)
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

    private fun handleOpenPdf(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath == null) {
            result.error("INVALID_ARGUMENT", "filePath is required", null)
            return
        }

        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                return
            }

            val uri: Uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                clipData = ClipData.newUri(contentResolver, "Whiteboard PDF", uri)
            }

            val chooser = Intent.createChooser(intent, "Open PDF with").apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            Log.e("BooredOpenPdf", "Failed to open PDF", e)
            result.error("OPEN_FAILED", e.message, null)
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

        // Downscale for fast & robust contour detection while preserving aspect ratio
        val targetWidth = 1000.0
        val scale = if (originalWidth > targetWidth) targetWidth / originalWidth else 1.0
        val scaledWidth = (originalWidth * scale).toInt()
        val scaledHeight = (originalHeight * scale).toInt()

        val origMat = Mat()
        Utils.bitmapToMat(bitmap, origMat)
        bitmap.recycle()

        val resizedMat = Mat()
        if (scale < 1.0) {
            Imgproc.resize(origMat, resizedMat, Size(scaledWidth.toDouble(), scaledHeight.toDouble()), 0.0, 0.0, Imgproc.INTER_AREA)
            origMat.release()
        } else {
            origMat.copyTo(resizedMat)
            origMat.release()
        }

        // 1. Grayscale + Blur
        val gray = Mat()
        Imgproc.cvtColor(resizedMat, gray, Imgproc.COLOR_BGR2GRAY)
        Imgproc.GaussianBlur(gray, gray, Size(5.0, 5.0), 0.0)

        // 2. CLAHE contrast enhancement for low-contrast edges
        val clahe = Imgproc.createCLAHE(3.0, Size(8.0, 8.0))
        val contrasted = Mat()
        clahe.apply(gray, contrasted)

        val morphKernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(5.0, 5.0))

        // Strategy A: Canny edge map
        val edgesCanny = Mat()
        Imgproc.Canny(contrasted, edgesCanny, 30.0, 120.0)
        Imgproc.dilate(edgesCanny, edgesCanny, morphKernel)

        // Strategy B: Adaptive Thresholding (robust against shadows & uneven room lighting)
        val adaptiveThresh = Mat()
        Imgproc.adaptiveThreshold(
            gray,
            adaptiveThresh,
            255.0,
            Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C,
            Imgproc.THRESH_BINARY_INV,
            11,
            2.0
        )
        Imgproc.morphologyEx(adaptiveThresh, adaptiveThresh, Imgproc.MORPH_CLOSE, morphKernel)

        // Strategy C: HSV Whiteboard Mask (High Value/Brightness + Low Saturation)
        val hsvMat = Mat()
        Imgproc.cvtColor(resizedMat, hsvMat, Imgproc.COLOR_BGR2HSV)
        val hsvChannels = ArrayList<Mat>()
        Core.split(hsvMat, hsvChannels)
        val satChannel = hsvChannels[1]
        val valChannel = hsvChannels[2]

        val satMask = Mat()
        val valMask = Mat()
        // Whiteboard has low saturation (< 65) and high brightness (> 130)
        Imgproc.threshold(satChannel, satMask, 65.0, 255.0, Imgproc.THRESH_BINARY_INV)
        Imgproc.threshold(valChannel, valMask, 130.0, 255.0, Imgproc.THRESH_BINARY)
        val hsvWhiteboardMask = Mat()
        Core.bitwise_and(satMask, valMask, hsvWhiteboardMask)
        Imgproc.morphologyEx(hsvWhiteboardMask, hsvWhiteboardMask, Imgproc.MORPH_CLOSE, morphKernel)

        val totalArea = scaledWidth * scaledHeight.toDouble()
        var foundCorners: Array<Point>? = null

        // Try candidate maps in order of precision: Canny -> Adaptive -> HSV White Surface
        for (binaryMap in arrayOf(edgesCanny, adaptiveThresh, hsvWhiteboardMask)) {
            val contours = ArrayList<MatOfPoint>()
            val hierarchy = Mat()
            Imgproc.findContours(binaryMap, contours, hierarchy, Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)
            hierarchy.release()

            // Sort largest area first
            contours.sortByDescending { Imgproc.contourArea(it) }

            for (contour in contours.take(15)) {
                val contourArea = Imgproc.contourArea(contour)
                if (contourArea < totalArea * 0.08) continue

                val contour2f = MatOfPoint2f(*contour.toArray())
                val peri = Imgproc.arcLength(contour2f, true)

                // 1. Try Douglas-Peucker polygon approximation with varying epsilons
                for (eps in doubleArrayOf(0.015, 0.02, 0.03, 0.04, 0.05, 0.06, 0.08)) {
                    val approx = MatOfPoint2f()
                    Imgproc.approxPolyDP(contour2f, approx, eps * peri, true)
                    val pts = approx.toArray()

                    if (pts.size == 4 && Imgproc.isContourConvex(MatOfPoint(*pts))) {
                        foundCorners = pts
                        break
                    }
                }
                if (foundCorners != null) break

                // 2. If exactly 4 points weren't found due to minor edge curve, extract extreme corners from Convex Hull
                val hull = MatOfInt()
                Imgproc.convexHull(contour, hull)
                val hullIndices = hull.toArray()
                val contourPts = contour.toArray()
                val hullPts = hullIndices.map { contourPts[it] }

                if (hullPts.size >= 4) {
                    val extremeQuad = extractFourCornersFromPoints(hullPts)
                    if (extremeQuad != null && Imgproc.isContourConvex(MatOfPoint(*extremeQuad))) {
                        val quadArea = Imgproc.contourArea(MatOfPoint(*extremeQuad))
                        if (quadArea >= totalArea * 0.08) {
                            foundCorners = extremeQuad
                            break
                        }
                    }
                }
            }
            if (foundCorners != null) break
        }

        // Cleanup native OpenCV matrices
        resizedMat.release()
        gray.release()
        contrasted.release()
        edgesCanny.release()
        adaptiveThresh.release()
        hsvMat.release()
        satChannel.release()
        valChannel.release()
        satMask.release()
        valMask.release()
        hsvWhiteboardMask.release()
        morphKernel.release()

        val orderedPoints = if (foundCorners != null && foundCorners.size == 4) {
            orderPoints(foundCorners)
        } else {
            // Sensible centered default
            arrayOf(
                Point(scaledWidth * 0.08, scaledHeight * 0.08),
                Point(scaledWidth * 0.92, scaledHeight * 0.08),
                Point(scaledWidth * 0.92, scaledHeight * 0.92),
                Point(scaledWidth * 0.08, scaledHeight * 0.92)
            )
        }

        return orderedPoints.map { pt ->
            mapOf("x" to (pt.x / scaledWidth), "y" to (pt.y / scaledHeight))
        }
    }

    private fun extractFourCornersFromPoints(pts: List<Point>): Array<Point>? {
        if (pts.size < 4) return null
        var tl = pts[0]
        var tr = pts[0]
        var br = pts[0]
        var bl = pts[0]

        var minSum = Double.MAX_VALUE
        var maxSum = -Double.MAX_VALUE
        var minDiff = Double.MAX_VALUE
        var maxDiff = -Double.MAX_VALUE

        for (p in pts) {
            val sum = p.x + p.y
            val diff = p.x - p.y

            if (sum < minSum) {
                minSum = sum
                tl = p
            }
            if (sum > maxSum) {
                maxSum = sum
                br = p
            }
            if (diff > maxDiff) { // top-right has highest (x - y)
                maxDiff = diff
                tr = p
            }
            if (diff < minDiff) { // bottom-left has lowest (x - y)
                minDiff = diff
                bl = p
            }
        }

        // Ensure distinct 4 points
        val distinct = setOf(tl, tr, br, bl)
        if (distinct.size != 4) return null

        return arrayOf(tl, tr, br, bl)
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

        // 1. Bilateral filtering for edge-preserving denoising (removes sensor noise & JPEG artifacts without blurring stroke edges)
        val denoised = Mat()
        Imgproc.bilateralFilter(bgr, denoised, 5, 50.0, 50.0)
        bgr.release()

        // 2. Convert to LAB color space for lighting normalization
        val lab = Mat()
        Imgproc.cvtColor(denoised, lab, Imgproc.COLOR_BGR2Lab)
        val labPlanes = ArrayList<Mat>(3)
        Core.split(lab, labPlanes)

        // Balanced CLAHE on L-channel: 2.2 clip limit, 8x8 grid for consistent contrast
        val clahe = Imgproc.createCLAHE(2.2, Size(8.0, 8.0))
        clahe.apply(labPlanes[0], labPlanes[0])
        Core.merge(labPlanes, lab)
        val enhancedBgr = Mat()
        Imgproc.cvtColor(lab, enhancedBgr, Imgproc.COLOR_Lab2BGR)

        // 3. Crisp stroke sharpening using unsharp masking
        val blurred = Mat()
        Imgproc.GaussianBlur(enhancedBgr, blurred, Size(0.0, 0.0), 2.5)
        val sharpened = Mat()
        Core.addWeighted(enhancedBgr, 1.45, blurred, -0.45, 0.0, sharpened)

        val outBitmap = Bitmap.createBitmap(sharpened.cols(), sharpened.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(sharpened, outBitmap)

        val file = File(dstPath)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            outBitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
        }

        outBitmap.recycle()
        denoised.release()
        lab.release()
        enhancedBgr.release()
        blurred.release()
        sharpened.release()
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

        // Build binary person mask from confidence array with 0.40 threshold
        val maskByteArray = ByteArray(maskWidth * maskHeight)
        for (i in maskConfidences.indices) {
            maskByteArray[i] = if (maskConfidences[i] > 0.40) 255.toByte() else 0.toByte()
        }

        val rawMaskMat = Mat(maskHeight, maskWidth, CvType.CV_8UC1)
        rawMaskMat.put(0, 0, maskByteArray)

        val fullMaskMat = Mat()
        Imgproc.resize(rawMaskMat, fullMaskMat, currMat.size(), 0.0, 0.0, Imgproc.INTER_LINEAR)

        // Morphological dilation to expand boundary slightly (covers clothes fringes, hair, gestures)
        val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(11.0, 11.0))
        val dilatedMask = Mat()
        Imgproc.dilate(fullMaskMat, dilatedMask, kernel)

        // Soft Gaussian blur on the mask for seamless alpha blending without hard cutout edges
        val smoothMask = Mat()
        Imgproc.GaussianBlur(dilatedMask, smoothMask, Size(15.0, 15.0), 0.0)

        // Alpha blend: result = (currMat * (1 - alpha)) + (bgMat * alpha) where alpha is person mask
        val smoothMask32F = Mat()
        smoothMask.convertTo(smoothMask32F, CvType.CV_32FC1, 1.0 / 255.0)

        val smoothMask3Ch = Mat()
        val channels = ArrayList<Mat>(3)
        channels.add(smoothMask32F)
        channels.add(smoothMask32F)
        channels.add(smoothMask32F)
        Core.merge(channels, smoothMask3Ch)

        val curr32F = Mat()
        val bg32F = Mat()
        currMat.convertTo(curr32F, CvType.CV_32FC3)
        bgMat.convertTo(bg32F, CvType.CV_32FC3)

        // currPart = curr32F * (1.0 - mask)
        val invMask = Mat()
        Core.subtract(Scalar.all(1.0), smoothMask3Ch, invMask)
        val currPart = Mat()
        Core.multiply(curr32F, invMask, currPart)

        // bgPart = bg32F * mask
        val bgPart = Mat()
        Core.multiply(bg32F, smoothMask3Ch, bgPart)

        // blended = currPart + bgPart
        val blended32F = Mat()
        Core.add(currPart, bgPart, blended32F)

        val resultMat = Mat()
        blended32F.convertTo(resultMat, CvType.CV_8UC3)

        val outBitmap = Bitmap.createBitmap(resultMat.cols(), resultMat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(resultMat, outBitmap)

        val file = File(dstPath)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            outBitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
        }

        outBitmap.recycle()
        currMat.release()
        bgMat.release()
        rawMaskMat.release()
        fullMaskMat.release()
        kernel.release()
        dilatedMask.release()
        smoothMask.release()
        smoothMask32F.release()
        smoothMask3Ch.release()
        for (ch in channels) ch.release()
        curr32F.release()
        bg32F.release()
        invMask.release()
        currPart.release()
        bgPart.release()
        blended32F.release()
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
