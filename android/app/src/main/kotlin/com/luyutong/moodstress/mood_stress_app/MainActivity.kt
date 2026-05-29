package com.luyutong.moodstress.mood_stress_app

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val appIconChannelName = "moodland/app_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appIconChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAlternateIcon" -> {
                        val iconName = call.argument<String>("iconName").orEmpty()
                        setLauncherIcon(iconName == "AppIconNight")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setLauncherIcon(useNightIcon: Boolean) {
        val packageManager = packageManager
        val dayAlias = ComponentName(this, "$packageName.MainActivityDayAlias")
        val nightAlias = ComponentName(this, "$packageName.MainActivityNightAlias")
        val enabled = PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        val disabled = PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        val flags = PackageManager.DONT_KILL_APP

        val enableAlias = if (useNightIcon) nightAlias else dayAlias
        val disableAlias = if (useNightIcon) dayAlias else nightAlias

        packageManager.setComponentEnabledSetting(enableAlias, enabled, flags)
        Handler(Looper.getMainLooper()).postDelayed({
            packageManager.setComponentEnabledSetting(disableAlias, disabled, flags)
        }, 350)
    }
}
