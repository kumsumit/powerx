package com.example.powerx.officeengine

import android.content.Context
import android.content.Intent
import android.net.Uri
import java.io.File

object OfficeEngineBridge {
    @JvmStatic
    fun openDocument(context: Context, documentPath: String) {
        val activityClass = Class.forName("org.libreoffice.androidlib.LOActivity")
        val intent = Intent(Intent.ACTION_VIEW)
            .setClass(context, activityClass)
            .setData(Uri.fromFile(File(documentPath)))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)

        context.startActivity(intent)
    }

    @JvmStatic
    fun convertLegacyPptToPptx(context: Context, pptPath: String): String {
        throw UnsupportedOperationException(
            "Native Office Engine conversion bridge is not bundled yet. Build and package Collabora Office, then expose saveAs/export here.",
        )
    }
}
