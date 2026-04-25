package com.pacewisp.pacewisp

import io.flutter.embedding.android.FlutterFragmentActivity
import android.content.Intent
import android.os.Bundle

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startService(Intent(this, WidgetSyncService::class.java))
    }
}
