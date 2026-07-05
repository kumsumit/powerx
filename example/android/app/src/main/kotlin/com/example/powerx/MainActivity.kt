package com.example.powerx

import android.content.Context
import com.google.android.play.core.splitinstall.SplitInstallManager
import com.google.android.play.core.splitinstall.SplitInstallManagerFactory
import com.google.android.play.core.splitinstall.SplitInstallRequest
import com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
import com.google.android.play.core.splitinstall.model.SplitInstallSessionStatus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val officeEngineModuleName = "office_engine"
    private val channelName = "powerx/office_engine"

    private lateinit var splitInstallManager: SplitInstallManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        splitInstallManager = SplitInstallManagerFactory.create(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler {
            call,
            result ->
            when (call.method) {
                "isInstalled" -> result.success(isOfficeEngineInstalled())
                "ensureInstalled" -> ensureOfficeEngineInstalled(result)
                "convertLegacyPptToPptx" -> {
                    val pptPath = call.argument<String>("pptPath")
                    if (pptPath.isNullOrBlank()) {
                        result.error("invalid_argument", "pptPath is required", null)
                    } else {
                        convertLegacyPptToPptx(this, pptPath, result)
                    }
                }
                "openInOfficeEngine" -> {
                    val documentPath = call.argument<String>("documentPath")
                    if (documentPath.isNullOrBlank()) {
                        result.error("invalid_argument", "documentPath is required", null)
                    } else {
                        openInOfficeEngine(this, documentPath, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isOfficeEngineInstalled(): Boolean {
        return splitInstallManager.installedModules.contains(officeEngineModuleName)
    }

    private fun ensureOfficeEngineInstalled(result: MethodChannel.Result) {
        if (isOfficeEngineInstalled()) {
            result.success(true)
            return
        }

        val request = SplitInstallRequest
            .newBuilder()
            .addModule(officeEngineModuleName)
            .build()

        var completed = false
        lateinit var listener: SplitInstallStateUpdatedListener
        listener = SplitInstallStateUpdatedListener { state ->
            if (!state.moduleNames().contains(officeEngineModuleName) || completed) {
                return@SplitInstallStateUpdatedListener
            }

            when (state.status()) {
                SplitInstallSessionStatus.INSTALLED -> {
                    completed = true
                    splitInstallManager.unregisterListener(listener)
                    result.success(true)
                }
                SplitInstallSessionStatus.FAILED,
                SplitInstallSessionStatus.CANCELED -> {
                    completed = true
                    splitInstallManager.unregisterListener(listener)
                    result.error(
                        "engine_install_failed",
                        "Office Compatibility Engine install failed with status ${state.status()}",
                        state.errorCode(),
                    )
                }
            }
        }

        splitInstallManager.registerListener(listener)
        splitInstallManager.startInstall(request).addOnFailureListener { error ->
            if (!completed) {
                completed = true
                splitInstallManager.unregisterListener(listener)
                result.error(
                    "engine_install_failed",
                    error.message ?: "Office Compatibility Engine install failed",
                    null,
                )
            }
        }
    }

    private fun convertLegacyPptToPptx(
        context: Context,
        pptPath: String,
        result: MethodChannel.Result,
    ) {
        if (!isOfficeEngineInstalled()) {
            result.error(
                "engine_not_installed",
                "Office Compatibility Engine is not installed",
                null,
            )
            return
        }

        try {
            val bridgeClass = Class.forName("com.example.powerx.officeengine.OfficeEngineBridge")
            val method = bridgeClass.getMethod(
                "convertLegacyPptToPptx",
                Context::class.java,
                String::class.java,
            )
            val pptxPath = method.invoke(null, context, pptPath) as? String
            if (pptxPath.isNullOrBlank()) {
                result.error("conversion_failed", "No converted PPTX path was returned", null)
            } else {
                result.success(pptxPath)
            }
        } catch (error: Throwable) {
            result.error(
                "conversion_failed",
                error.cause?.message ?: error.message ?: "Legacy PPT conversion failed",
                null,
            )
        }
    }

    private fun openInOfficeEngine(
        context: Context,
        documentPath: String,
        result: MethodChannel.Result,
    ) {
        if (!isOfficeEngineInstalled()) {
            result.error(
                "engine_not_installed",
                "Office Compatibility Engine is not installed",
                null,
            )
            return
        }

        try {
            val bridgeClass = Class.forName("com.example.powerx.officeengine.OfficeEngineBridge")
            val method = bridgeClass.getMethod(
                "openDocument",
                Context::class.java,
                String::class.java,
            )
            method.invoke(null, context, documentPath)
            result.success(true)
        } catch (error: Throwable) {
            result.error(
                "engine_open_failed",
                error.cause?.message ?: error.message ?: "Office Engine open failed",
                null,
            )
        }
    }
}
