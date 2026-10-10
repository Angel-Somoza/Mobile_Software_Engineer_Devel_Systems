package com.asomoza.qr_scanner.camera

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.asomoza.qr_scanner.QrScanner
import com.asomoza.qr_scanner.scanner.ScanAttempt


internal class QrScannerActivity : ComponentActivity() {

    private lateinit var previewView: PreviewView
    private var attempt : ScanAttempt? = null


    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { grant ->
            if (grant) {
                startCamera()
            } else {
                attempt?.permissionDenied()
                finish()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        attempt = QrScanner.currentAttempt
        if (attempt == null) {
            finish()
            return
        }

        previewView = PreviewView(this)
        setContentView(previewView)
        requestPermission()
    }

    private fun requestPermission() {
        val grant = ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        if (grant) {
            startCamera()
        } else {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    private fun startCamera() {
        val cameraProvider = ProcessCameraProvider.getInstance(this)
        cameraProvider.addListener({
            try {
                val provider = cameraProvider.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                provider.unbindAll()
                provider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, preview)
            }catch (e: Exception){
                finish()
            }
        }, ContextCompat.getMainExecutor(this))
    }
}







