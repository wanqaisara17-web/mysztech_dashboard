package com.example.pos_monitoring_app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.pos_monitoring_app/local_workspace"
    private val preferencesName = "local_workspace"
    private val dataKey = "products_json"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val preferences = getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
                when (call.method) {
                    "loadWorkspace" -> result.success(preferences.getString(dataKey, "[]"))
                    "saveWorkspace" -> {
                        val json = call.argument<String>("json")
                        if (json == null) {
                            result.error("invalid_data", "Workspace data is missing.", null)
                        } else {
                            preferences.edit().putString(dataKey, json).apply()
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
