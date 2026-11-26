package com.example.pos_monitoring_app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.pos_monitoring_app/local_workspace"
    private val preferencesName = "local_workspace"
    private val dataKey = "products_json"
    private val notificationPreferencesName = "low_stock_notification_state"

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
                    "loadLowStockNotificationState" -> {
                        val account = call.argument<String>("account")
                        val outlet = call.argument<String>("outlet")
                        if (account.isNullOrBlank() || outlet.isNullOrBlank()) {
                            result.error("invalid_scope", "Notification scope is missing.", null)
                        } else {
                            val scopeKey = notificationScopeKey(account, outlet)
                            val json = getSharedPreferences(
                                notificationPreferencesName,
                                Context.MODE_PRIVATE,
                            ).getString(scopeKey, "[]") ?: "[]"
                            val values = JSONArray(json)
                            result.success(List(values.length()) { index -> values.getString(index) })
                        }
                    }
                    "saveLowStockNotificationState" -> {
                        val account = call.argument<String>("account")
                        val outlet = call.argument<String>("outlet")
                        val inventoryIds = call.argument<List<String>>("inventoryIds")
                        if (account.isNullOrBlank() || outlet.isNullOrBlank() || inventoryIds == null) {
                            result.error("invalid_scope", "Notification state is missing.", null)
                        } else {
                            val scopeKey = notificationScopeKey(account, outlet)
                            val json = JSONArray(inventoryIds).toString()
                            getSharedPreferences(
                                notificationPreferencesName,
                                Context.MODE_PRIVATE,
                            ).edit().putString(scopeKey, json).apply()
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun notificationScopeKey(account: String, outlet: String): String {
        val scope = "$account\u0000$outlet".toByteArray(Charsets.UTF_8)
        val digest = MessageDigest.getInstance("SHA-256").digest(scope)
        return "low_stock_" + digest.joinToString("") { byte -> "%02x".format(byte) }
    }
}
