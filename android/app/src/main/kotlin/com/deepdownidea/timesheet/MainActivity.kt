package com.deepdownidea.timesheet

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * System launcher entry point. Must stay `android:exported="true"` for MAIN/LAUNCHER.
 *
 * Other apps can start this activity by component name; strip unexpected URI data so
 * they cannot inject deep-link style payloads. Intent extras are kept for FCM /
 * notification tap handling.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        sanitizeExternalIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        sanitizeExternalIntent(intent)
        setIntent(intent)
        super.onNewIntent(intent)
    }

    private fun sanitizeExternalIntent(incoming: Intent?) {
        if (incoming == null) return
        // No VIEW / deep-link intent-filters are registered on this activity.
        if (incoming.data != null) {
            incoming.data = null
        }
    }
}
