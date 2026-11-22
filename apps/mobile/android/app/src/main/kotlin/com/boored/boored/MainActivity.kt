package com.boored.boored

import android.content.ClipData
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.media.MediaMetadataRetriever
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
import org.opencv.photo.Photo
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
                "reconstructWhiteboard" -> handleReconstructWhiteboard(call, result)
                "preprocessForOcr" -> handlePreprocessOcr(call, result)
                "openPdf" -> handleOpenPdf(call, result)
                "extractVideoFrames" -> handleExtractVideoFrames(call, result)
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

    private fun handlePreprocessOcr(call: MethodCall, result: MethodChannel.Result) {
        val srcPath = call.argument<String>("srcPath")
        val dstPath = call.argument<String>("dstPath")

        if (srcPath == null || dstPath == null) {
            result.error("INVALID_ARGUMENT", "srcPath and dstPath are required", null)
            return
        }

        scope.launch {
            try {
                val success = preprocessForOcrNative(srcPath, dstPath)
                withContext(Dispatchers.Main) {
                    if (success) {
                        result.success(dstPath)
                    } else {
                        result.error("PREPROCESS_FAILED", "Failed to preprocess image for OCR", null)
                    }
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

    private fun handleExtractVideoFrames(call: MethodCall, result: MethodChannel.Result) {
        val videoPath = call.argument<String>("videoPath")
        val outputDir = call.argument<String>("outputDir")
        val intervalMs = call.argument<Int>("intervalMs") ?: 5000

        if (videoPath == null || outputDir == null) {
            result.error("INVALID_ARGUMENT", "videoPath and outputDir are required", null)
            return
        }

        scope.launch {
            try {
                val data = extractVideoFramesNative(videoPath, outputDir, intervalMs)
                withContext(Dispatchers.Main) {
                    result.success(data)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("EXTRACT_FAILED", e.message, null)
                }
            }
        }
    }

    private fun extractVideoFramesNative(
        videoPath: String,
        outputDir: String,
        intervalMs: Int
    ): Map<String, Any> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(videoPath)

            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val durationMs = durationStr?.toLongOrNull() ?: 0L

            val outDirFile = File(outputDir)
            if (!outDirFile.exists()) outDirFile.mkdirs()

            val framePaths = mutableListOf<String>()
            var timeUs: Long = 0
            val intervalUs = intervalMs.toLong() * 1000L
            val durationUs = durationMs * 1000L
            var frameIndex = 0

            while (timeUs <= durationUs) {
                val bitmap = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                if (bitmap != null) {
                    val frameName = "frame_${frameIndex.toString().padStart(5, '0')}.jpg"
                    val framePath = File(outputDir, frameName).absolutePath
                    FileOutputStream(File(framePath)).use { out ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                    }
                    bitmap.recycle()
                    framePaths.add(framePath)
                    frameIndex++
                }
                timeUs += intervalUs
            }

            return mapOf(
                "framePaths" to framePaths,
                "durationMs" to durationMs.toInt()
            )
        } finally {
            retriever.release()
        }
    }

    private fun handleComposite(call: MethodCall, result: MethodChannel.Result) {
        val currentPath = call.argument<String>("currentPath")
        val cleanBackgroundPath = call.argument<String>("cleanBackgroundPath")
        val dstPath = call.argument<String>("dstPath")
        val rawConfidences = call.argument<List<*>>("maskConfidences")
        val maskWidth = call.argument<Int>("maskWidth")
        val maskHeight = call.argument<Int>("maskHeight")
        val bgRawConfidences = call.argument<List<*>>("bgMaskConfidences")
        val bgMaskWidth = call.argument<Int>("bgMaskWidth")
        val bgMaskHeight = call.argument<Int>("bgMaskHeight")

        if (currentPath == null || cleanBackgroundPath == null || dstPath == null ||
            rawConfidences == null || maskWidth == null || maskHeight == null) {
            result.error("INVALID_ARGUMENT", "All composite arguments are required", null)
            return
        }

        // Safely cast every element — Flutter MethodChannel may send mixed number types
        val maskConfidences = rawConfidences.map { (it as Number).toDouble() }
        val bgMaskConfidences = bgRawConfidences?.map { (it as Number).toDouble() }

        scope.launch {
            try {
                val success = compositeNative(
                    currentPath,
                    cleanBackgroundPath,
                    dstPath,
                    maskConfidences,
                    maskWidth,
                    maskHeight,
                    bgMaskConfidences,
                    bgMaskWidth,
                    bgMaskHeight
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

    private fun handleReconstructWhiteboard(call: MethodCall, result: MethodChannel.Result) {
        val currentPath = call.argument<String>("currentPath")
        val currentMaskBytes = call.argument<ByteArray>("currentMaskBytes")
        val maskWidth = call.argument<Int>("maskWidth")
        val maskHeight = call.argument<Int>("maskHeight")
        val candidatePaths = call.argument<List<String>>("candidatePaths") ?: emptyList()
        val candidateMaskBytes = call.argument<List<ByteArray>>("candidateMaskBytes") ?: emptyList()
        val dstPath = call.argument<String>("dstPath")

        if (currentPath == null || currentMaskBytes == null || dstPath == null ||
            maskWidth == null || maskHeight == null) {
            result.error("INVALID_ARGUMENT", "currentPath, maskBytes, and dstPath are required", null)
            return
        }

        scope.launch {
            try {
                val success = reconstructWhiteboardNative(
                    currentPath,
                    currentMaskBytes,
                    maskWidth,
                    maskHeight,
                    candidatePaths,
                    candidateMaskBytes,
                    dstPath
                )
                withContext(Dispatchers.Main) {
                    if (success) {
                        result.success(dstPath)
                    } else {
                        result.error("RECONSTRUCT_FAILED", "Failed to reconstruct whiteboard", null)
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("OPENCV_ERROR", e.message, null)
                }
            }
        }
    }

    private fun decodeBitmapWithOrientation(path: String): Bitmap? {
        val bitmap = BitmapFactory.decodeFile(path) ?: return null
        return try {
            val exif = ExifInterface(path)
            val orientation = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
                else -> return bitmap
            }
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated != bitmap) {
                bitmap.recycle()
            }
            rotated
        } catch (e: Exception) {
            bitmap
        }
    }

    private fun detectCornersNative(imagePath: String): List<Map<String, Double>> {
        val bitmap = decodeBitmapWithOrientation(imagePath)
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
        val bitmap = decodeBitmapWithOrientation(srcPath) ?: return false
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
        val bitmap = decodeBitmapWithOrientation(srcPath) ?: return false
        val rgba = Mat()
        Utils.bitmapToMat(bitmap, rgba)
        bitmap.recycle()

        val bgr = Mat()
        Imgproc.cvtColor(rgba, bgr, Imgproc.COLOR_RGBA2BGR)
        rgba.release()

        // 1. Bilateral filtering for edge-preserving denoising on 3-channel BGR
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

        val outRgba = Mat()
        Imgproc.cvtColor(sharpened, outRgba, Imgproc.COLOR_BGR2RGBA)

        val outBitmap = Bitmap.createBitmap(outRgba.cols(), outRgba.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(outRgba, outBitmap)

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
        outRgba.release()
        for (p in labPlanes) p.release()

        return true
    }

    private fun detectChangeNative(prevPath: String, currPath: String): Map<String, Any> {
        val prevBmp = decodeBitmapWithOrientation(prevPath)
            ?: return mapOf("eventType" to "NONE", "diffRatio" to 0.0)
        val currBmp = decodeBitmapWithOrientation(currPath)
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
        maskHeight: Int,
        bgMaskConfidences: List<Double>? = null,
        bgMaskWidth: Int? = null,
        bgMaskHeight: Int? = null
    ): Boolean {
        val currBmp = decodeBitmapWithOrientation(currentPath) ?: return false
        val bgBmp = decodeBitmapWithOrientation(cleanBackgroundPath) ?: return false

        val currRgba = Mat()
        val bgRgba = Mat()
        Utils.bitmapToMat(currBmp, currRgba)
        Utils.bitmapToMat(bgBmp, bgRgba)
        currBmp.recycle()
        bgBmp.recycle()

        // Convert both to BGR (3 channels) for uniform processing
        val currMat = Mat()
        val bgMat = Mat()
        Imgproc.cvtColor(currRgba, currMat, Imgproc.COLOR_RGBA2BGR)
        Imgproc.cvtColor(bgRgba, bgMat, Imgproc.COLOR_RGBA2BGR)
        currRgba.release()
        bgRgba.release()

        if (currMat.size() != bgMat.size()) {
            Imgproc.resize(bgMat, bgMat, currMat.size())
        }

        // Helper to build dilated & vertically-closed mask from confidences
        fun buildProcessedMask(confidences: List<Double>, mWidth: Int, mHeight: Int): Mat {
            val maskByteArray = ByteArray(mWidth * mHeight)
            for (i in 0 until minOf(confidences.size, maskByteArray.size)) {
                // Low threshold 0.15 captures legs, waist, arms, loose clothing, hair, gestures
                maskByteArray[i] = if (confidences[i] > 0.15) 255.toByte() else 0.toByte()
            }
            val rawMat = Mat(mHeight, mWidth, CvType.CV_8UC1)
            rawMat.put(0, 0, maskByteArray)

            val fullMat = Mat()
            Imgproc.resize(rawMat, fullMat, currMat.size(), 0.0, 0.0, Imgproc.INTER_LINEAR)
            rawMat.release()

            // Morphological vertical CLOSE to connect torso, legs, and feet
            val closeKernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(25.0, 55.0))
            Imgproc.morphologyEx(fullMat, fullMat, Imgproc.MORPH_CLOSE, closeKernel)
            closeKernel.release()

            // Morphological DILATE to swallow clothing edges, hair, and lecturer shadows on whiteboard
            val dilateKernel = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(29.0, 29.0))
            val dilatedMat = Mat()
            Imgproc.dilate(fullMat, dilatedMat, dilateKernel)
            dilateKernel.release()
            fullMat.release()

            return dilatedMat
        }

        val currMask = buildProcessedMask(maskConfidences, maskWidth, maskHeight)
        val resultMat = Mat()
        val isSameFrame = (currentPath == cleanBackgroundPath)

        val nonZeroCurr = Core.countNonZero(currMask)
        if (nonZeroCurr == 0) {
            currMat.copyTo(resultMat)
        } else if (isSameFrame || bgMaskConfidences == null || bgMaskWidth == null || bgMaskHeight == null) {
            // Whiteboard inpainting: Telea algorithm fills occluded area with whiteboard texture/color
            try {
                Photo.inpaint(currMat, currMask, resultMat, 7.0, Photo.INPAINT_TELEA)
            } catch (e: Exception) {
                currMat.copyTo(resultMat)
            }
        } else {
            val bgMask = buildProcessedMask(bgMaskConfidences, bgMaskWidth, bgMaskHeight)

            // cleanBgMask: Pixels where CURRENT is occluded, but BACKGROUND is clean whiteboard
            val bgInv = Mat()
            Core.bitwise_not(bgMask, bgInv)
            val cleanBgMask = Mat()
            Core.bitwise_and(currMask, bgInv, cleanBgMask)
            bgInv.release()

            // overlapMask: Pixels where BOTH frames had a person (cannot copy from bg!)
            val overlapMask = Mat()
            Core.bitwise_and(currMask, bgMask, overlapMask)
            bgMask.release()

            val nonZeroCleanBg = Core.countNonZero(cleanBgMask)
            val tempBlended = Mat()

            if (nonZeroCleanBg > 0) {
                // Convert cleanBgMask to 3-channel float with soft Gaussian blur for smooth blending
                val maskBgr = Mat()
                Imgproc.cvtColor(cleanBgMask, maskBgr, Imgproc.COLOR_GRAY2BGR)
                val smoothMask = Mat()
                Imgproc.GaussianBlur(maskBgr, smoothMask, Size(17.0, 17.0), 0.0)
                maskBgr.release()

                val mask32F = Mat()
                smoothMask.convertTo(mask32F, CvType.CV_32FC3, 1.0 / 255.0)
                smoothMask.release()

                val curr32F = Mat()
                val bg32F = Mat()
                currMat.convertTo(curr32F, CvType.CV_32FC3)
                bgMat.convertTo(bg32F, CvType.CV_32FC3)

                val onesMat = Mat(mask32F.size(), CvType.CV_32FC3, Scalar(1.0, 1.0, 1.0))
                val invMask = Mat()
                Core.subtract(onesMat, mask32F, invMask)
                onesMat.release()

                val currPart = Mat()
                Core.multiply(curr32F, invMask, currPart)
                invMask.release()
                curr32F.release()

                val bgPart = Mat()
                Core.multiply(bg32F, mask32F, bgPart)
                mask32F.release()
                bg32F.release()

                val blended32F = Mat()
                Core.add(currPart, bgPart, blended32F)
                currPart.release()
                bgPart.release()

                blended32F.convertTo(tempBlended, CvType.CV_8UC3)
                blended32F.release()
            } else {
                currMat.copyTo(tempBlended)
            }
            cleanBgMask.release()

            // If there were overlapping regions where BOTH frames had the person, inpaint those pixels
            if (Core.countNonZero(overlapMask) > 0) {
                try {
                    Photo.inpaint(tempBlended, overlapMask, resultMat, 7.0, Photo.INPAINT_TELEA)
                } catch (e: Exception) {
                    tempBlended.copyTo(resultMat)
                }
            } else {
                tempBlended.copyTo(resultMat)
            }
            tempBlended.release()
            overlapMask.release()
        }

        currMask.release()

        val outRgba = Mat()
        Imgproc.cvtColor(resultMat, outRgba, Imgproc.COLOR_BGR2RGBA)

        val outBitmap = Bitmap.createBitmap(outRgba.cols(), outRgba.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(outRgba, outBitmap)

        val file = File(dstPath)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            outBitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
        }

        outBitmap.recycle()
        currMat.release()
        bgMat.release()
        resultMat.release()
        outRgba.release()

        return true
    }

    private fun reconstructWhiteboardNative(
        currentPath: String,
        currentMaskBytes: ByteArray,
        maskWidth: Int,
        maskHeight: Int,
        candidatePaths: List<String>,
        candidateMaskBytesList: List<ByteArray>,
        dstPath: String
    ): Boolean {
        val currBmp = decodeBitmapWithOrientation(currentPath) ?: return false

        val currRgba = Mat()
        Utils.bitmapToMat(currBmp, currRgba)
        currBmp.recycle()

        val resultMat = Mat()
        Imgproc.cvtColor(currRgba, resultMat, Imgproc.COLOR_RGBA2BGR)
        currRgba.release()

        fun buildMaskFromBytes(bytes: ByteArray, mWidth: Int, mHeight: Int): Mat {
            if (bytes.isEmpty()) {
                return Mat.zeros(resultMat.size(), CvType.CV_8UC1)
            }
            val rawMat = Mat(mHeight, mWidth, CvType.CV_8UC1)
            rawMat.put(0, 0, bytes)

            val fullMat = Mat()
            Imgproc.resize(rawMat, fullMat, resultMat.size(), 0.0, 0.0, Imgproc.INTER_LINEAR)
            rawMat.release()

            val closeKernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(25.0, 55.0))
            Imgproc.morphologyEx(fullMat, fullMat, Imgproc.MORPH_CLOSE, closeKernel)
            closeKernel.release()

            val dilateKernel = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(25.0, 25.0))
            val dilatedMat = Mat()
            Imgproc.dilate(fullMat, dilatedMat, dilateKernel)
            dilateKernel.release()
            fullMat.release()

            return dilatedMat
        }

        var unresolvedMask = buildMaskFromBytes(currentMaskBytes, maskWidth, maskHeight)

        if (Core.countNonZero(unresolvedMask) == 0) {
            unresolvedMask.release()
            return saveMatAsJpeg(resultMat, dstPath)
        }

        for (i in candidatePaths.indices) {
            if (Core.countNonZero(unresolvedMask) == 0) break

            val candPath = candidatePaths[i]
            if (candPath == currentPath) continue

            val candBmp = decodeBitmapWithOrientation(candPath) ?: continue
            val candRgba = Mat()
            Utils.bitmapToMat(candBmp, candRgba)
            candBmp.recycle()

            val candMat = Mat()
            Imgproc.cvtColor(candRgba, candMat, Imgproc.COLOR_RGBA2BGR)
            candRgba.release()

            if (candMat.size() != resultMat.size()) {
                Imgproc.resize(candMat, candMat, resultMat.size())
            }

            val candBytes = if (i < candidateMaskBytesList.size) candidateMaskBytesList[i] else ByteArray(0)
            val candMask = buildMaskFromBytes(candBytes, maskWidth, maskHeight)

            // availableMask = unresolvedMask AND (NOT candMask)
            // Real whiteboard content from candidate at the exact same physical coordinates
            val candInv = Mat()
            Core.bitwise_not(candMask, candInv)
            val availableMask = Mat()
            Core.bitwise_and(unresolvedMask, candInv, availableMask)
            candInv.release()
            candMask.release()

            if (Core.countNonZero(availableMask) > 0) {
                val maskBgr = Mat()
                Imgproc.cvtColor(availableMask, maskBgr, Imgproc.COLOR_GRAY2BGR)
                val smoothMask = Mat()
                Imgproc.GaussianBlur(maskBgr, smoothMask, Size(15.0, 15.0), 0.0)
                maskBgr.release()

                val mask32F = Mat()
                smoothMask.convertTo(mask32F, CvType.CV_32FC3, 1.0 / 255.0)
                smoothMask.release()

                val res32F = Mat()
                val cand32F = Mat()
                resultMat.convertTo(res32F, CvType.CV_32FC3)
                candMat.convertTo(cand32F, CvType.CV_32FC3)

                val onesMat = Mat(mask32F.size(), CvType.CV_32FC3, Scalar(1.0, 1.0, 1.0))
                val invMask = Mat()
                Core.subtract(onesMat, mask32F, invMask)
                onesMat.release()

                val resPart = Mat()
                val candPart = Mat()
                Core.multiply(res32F, invMask, resPart)
                invMask.release()
                res32F.release()

                Core.multiply(cand32F, mask32F, candPart)
                mask32F.release()
                cand32F.release()

                val blended = Mat()
                Core.add(resPart, candPart, blended)
                resPart.release()
                candPart.release()

                blended.convertTo(resultMat, CvType.CV_8UC3)
                blended.release()

                val notAvailable = Mat()
                Core.bitwise_not(availableMask, notAvailable)
                val newUnresolved = Mat()
                Core.bitwise_and(unresolvedMask, notAvailable, newUnresolved)
                unresolvedMask.release()
                unresolvedMask = newUnresolved
                notAvailable.release()
            }

            availableMask.release()
            candMat.release()
        }

        // Only inpaint pixels that were never visible in ANY frame across the sequence
        if (Core.countNonZero(unresolvedMask) > 0) {
            try {
                Photo.inpaint(resultMat, unresolvedMask, resultMat, 7.0, Photo.INPAINT_TELEA)
            } catch (_: Exception) {}
        }
        unresolvedMask.release()

        return saveMatAsJpeg(resultMat, dstPath)
    }

    private fun saveMatAsJpeg(bgrMat: Mat, dstPath: String): Boolean {
        val outRgba = Mat()
        Imgproc.cvtColor(bgrMat, outRgba, Imgproc.COLOR_BGR2RGBA)
        val outBitmap = Bitmap.createBitmap(outRgba.cols(), outRgba.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(outRgba, outBitmap)
        outRgba.release()
        bgrMat.release()

        val file = File(dstPath)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            outBitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
        }
        outBitmap.recycle()
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

    private fun preprocessForOcrNative(srcPath: String, dstPath: String): Boolean {
        val bitmap = decodeBitmapWithOrientation(srcPath) ?: return false
        val srcMat = Mat()
        Utils.bitmapToMat(bitmap, srcMat)
        bitmap.recycle()

        val gray = Mat()
        Imgproc.cvtColor(srcMat, gray, Imgproc.COLOR_BGR2GRAY)
        srcMat.release()

        // 1. CLAHE on grayscale to balance lighting gradients across the whiteboard
        val clahe = Imgproc.createCLAHE(3.0, Size(8.0, 8.0))
        val claheGray = Mat()
        clahe.apply(gray, claheGray)
        gray.release()

        // 2. Adaptive thresholding to yield pure dark text on crisp white background
        val binary = Mat()
        Imgproc.adaptiveThreshold(
            claheGray,
            binary,
            255.0,
            Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C,
            Imgproc.THRESH_BINARY,
            21,
            10.0
        )
        claheGray.release()

        // 3. Light median blur to remove single-pixel speckle noise
        val cleanBinary = Mat()
        Imgproc.medianBlur(binary, cleanBinary, 3)
        binary.release()

        val outBmp = Bitmap.createBitmap(cleanBinary.cols(), cleanBinary.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(cleanBinary, outBmp)
        cleanBinary.release()

        val file = File(dstPath)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            outBmp.compress(Bitmap.CompressFormat.JPEG, 95, out)
        }
        outBmp.recycle()
        return true
    }
}
