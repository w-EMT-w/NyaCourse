package com.example.gdut_class_schedule

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Base64
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class MainActivity : FlutterActivity() {
    private var petClickReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gdut_jw")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "fetchSchedule" -> {
                        runGdutRequest(call, result) { client, username, password, termCode ->
                            client.loginAndFetchSchedule(username, password, termCode)
                        }
                    }
                    "fetchGrades" -> {
                        runGdutRequest(call, result) { client, username, password, termCode ->
                            client.loginAndFetchGrades(username, password, termCode)
                        }
                    }
                    "fetchExams" -> {
                        runGdutRequest(call, result) { client, username, password, termCode ->
                            client.loginAndFetchExams(username, password, termCode)
                        }
                    }
                    "scheduleCourseReminders" -> {
                        ensureNotificationPermission()
                        CourseReminderScheduler(this).schedule(
                            reminderMinutes =
                                call.argument<Int>("reminderMinutes") ?: 10,
                            courses = call.argument<List<Map<String, Any?>>>("courses")
                                ?: emptyList(),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gdut_update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> {
                        result.success(canInstallPackages())
                    }
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path").orEmpty()
                        installApk(path, result)
                    }
                    else -> result.notImplemented()
                }
            }

        val petChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gdut_pet")
        registerPetClickReceiver(petChannel)
        petChannel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> {
                        result.success(canDrawPetOverlay())
                    }
                    "openOverlaySettings" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                    "showPet" -> {
                        if (!canDrawPetOverlay()) {
                            result.error("OVERLAY_PERMISSION", "需要开启悬浮窗权限。", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(this, FloatingPetService::class.java).apply {
                            action = FloatingPetService.ACTION_SHOW
                            putExtra(
                                FloatingPetService.EXTRA_STATUS_TEXT,
                                call.argument<String>("statusText").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_COURSE_NAME,
                                call.argument<String>("courseName").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_LOCATION,
                                call.argument<String>("location").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_START_TIME,
                                call.argument<String>("startTime").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_MINUTES_LEFT,
                                call.argument<Int>("minutesLeft") ?: -1,
                            )
                            putExtra(
                                FloatingPetService.EXTRA_DAY_LABEL,
                                call.argument<String>("dayLabel").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_SECONDARY_TEXT,
                                call.argument<String>("secondaryText").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_URGENT,
                                call.argument<Boolean>("urgent") ?: false,
                            )
                            putExtra(
                                FloatingPetService.EXTRA_THEME_COLOR,
                                call.argument<Number>("themeColorValue")?.toInt()
                                    ?: 0xff006b5b.toInt(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_CARD_BLUR,
                                call.argument<Number>("cardBlur")?.toFloat() ?: 20f,
                            )
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "hidePet" -> {
                        stopService(Intent(this, FloatingPetService::class.java))
                        result.success(null)
                    }
                    "updateCourse" -> {
                        val intent = Intent(this, FloatingPetService::class.java).apply {
                            action = FloatingPetService.ACTION_UPDATE_COURSE
                            putExtra(
                                FloatingPetService.EXTRA_STATUS_TEXT,
                                call.argument<String>("statusText").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_COURSE_NAME,
                                call.argument<String>("courseName").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_LOCATION,
                                call.argument<String>("location").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_START_TIME,
                                call.argument<String>("startTime").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_MINUTES_LEFT,
                                call.argument<Int>("minutesLeft") ?: -1,
                            )
                            putExtra(
                                FloatingPetService.EXTRA_DAY_LABEL,
                                call.argument<String>("dayLabel").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_SECONDARY_TEXT,
                                call.argument<String>("secondaryText").orEmpty(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_URGENT,
                                call.argument<Boolean>("urgent") ?: false,
                            )
                            putExtra(
                                FloatingPetService.EXTRA_THEME_COLOR,
                                call.argument<Number>("themeColorValue")?.toInt()
                                    ?: 0xff006b5b.toInt(),
                            )
                            putExtra(
                                FloatingPetService.EXTRA_CARD_BLUR,
                                call.argument<Number>("cardBlur")?.toFloat() ?: 20f,
                            )
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        petClickReceiver?.let { unregisterReceiver(it) }
        petClickReceiver = null
        super.onDestroy()
    }

    private fun registerPetClickReceiver(channel: MethodChannel) {
        petClickReceiver?.let { unregisterReceiver(it) }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == FloatingPetService.ACTION_PET_CLICK) {
                    channel.invokeMethod("petClicked", null)
                }
            }
        }
        petClickReceiver = receiver
        val filter = IntentFilter(FloatingPetService.ACTION_PET_CLICK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
    }

    private fun canDrawPetOverlay(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
        }
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        val apk = File(path)
        if (!apk.exists()) {
            result.error("APK_NOT_FOUND", "安装包不存在", null)
            return
        }
        if (!canInstallPackages()) {
            result.error("INSTALL_PERMISSION", "需要允许安装未知应用", null)
            return
        }
        try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                apk,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: Throwable) {
            result.error("INSTALL_FAILED", error.message ?: "无法打开安装器", null)
        }
    }

    private fun runGdutRequest(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
        block: (GdutNativeClient, String, String, String) -> String,
    ) {
        val username = call.argument<String>("username").orEmpty()
        val password = call.argument<String>("password").orEmpty()
        val termCode = call.argument<String>("termCode").orEmpty()

        Thread {
            try {
                val json = block(GdutNativeClient(), username, password, termCode)
                mainHandler.post { result.success(json) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error("GDUT_AUTH", error.message ?: "认证失败", null)
                }
            }
        }.start()
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
}

class ReminderReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        CourseReminderScheduler.ensureChannel(context)

        val title = intent.getStringExtra("title").orEmpty()
        val time = intent.getStringExtra("time").orEmpty()
        val location = intent.getStringExtra("location").orEmpty()
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CourseReminderScheduler.CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText("$time $location")
            .setStyle(Notification.BigTextStyle().bigText(
                "即将上课：$title\n时间：$time\n地点：$location",
            ))
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_DEFAULT)
            .build()

        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(intent.getIntExtra("id", 0), notification)
    }
}

private class CourseReminderScheduler(private val context: Context) {
    fun schedule(
        reminderMinutes: Int,
        courses: List<Map<String, Any?>>,
    ) {
        ensureChannel(context)
        if (reminderMinutes <= 0) {
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (course in courses.take(300)) {
            val startsAt = (course["startsAt"] as? Number)?.toLong() ?: continue
            val triggerAt = startsAt - reminderMinutes * 60_000L
            if (triggerAt <= System.currentTimeMillis()) {
                continue
            }
            val id = (course["id"] as? Number)?.toInt() ?: triggerAt.hashCode()
            val intent = Intent(context, ReminderReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", course["title"]?.toString().orEmpty())
                putExtra("time", course["time"]?.toString().orEmpty())
                putExtra("location", course["location"]?.toString().orEmpty())
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms()
            ) {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            }
        }
    }

    companion object {
        const val CHANNEL_ID = "course_reminders"

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                return
            }

            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "课前提醒",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            manager.createNotificationChannel(channel)
        }
    }
}

private class GdutNativeClient {
    private val cookies = linkedMapOf<String, StoredCookie>()
    private val random = SecureRandom()

    fun loginAndFetchSchedule(
        username: String,
        password: String,
        termCode: String,
    ): String {
        login(username, password)
        return postJson(
            path = "xsgrkbcx!getDataList.action",
            referer = "$JW_ENTRY/xsgrkbcx!xskbList2.action?xnxqdm=$termCode",
            fields = linkedMapOf(
                "xnxqdm" to termCode,
                "zc" to "",
                "page" to "1",
                "rows" to "500",
                "sort" to "kxh",
                "order" to "asc",
            ),
        )
    }

    fun loginAndFetchGrades(
        username: String,
        password: String,
        termCode: String,
    ): String {
        login(username, password)
        request("GET", "$JW_ENTRY/xskccjxx!xskccjList.action")
        return postJson(
            path = "xskccjxx!getDataList.action",
            referer = "$JW_ENTRY/xskccjxx!xskccjList.action",
            fields = linkedMapOf(
                "xnxqdm" to termCode,
                "page" to "1",
                "rows" to "200",
                "sort" to "xnxqdm",
                "order" to "asc",
            ),
        )
    }

    fun loginAndFetchExams(
        username: String,
        password: String,
        termCode: String,
    ): String {
        login(username, password)
        return postJson(
            path = "xsksap!getDataList.action",
            referer = "$JW_ENTRY/xsksap!ksapList.action",
            fields = linkedMapOf(
                "xnxqdm" to termCode,
                "page" to "1",
                "rows" to "200",
            ),
        )
    }

    private fun login(
        username: String,
        password: String,
    ) {
        if (username.isBlank() || password.isEmpty()) {
            throw IllegalArgumentException("请输入账号和密码。")
        }

        val loginPage = request("GET", AUTH_LOGIN)
        if (loginPage.status >= 500 || loginPage.body.contains("Bad Gateway", ignoreCase = true)) {
            throw IllegalStateException("学校统一认证服务暂时不可用（${loginPage.status}），请稍后再试。")
        }
        val salt = inputValue(loginPage.body, "pwdEncryptSalt")
        val execution = inputValue(loginPage.body, "execution")
        if (salt.isBlank() || execution.isBlank()) {
            throw IllegalStateException("登录页缺少统一认证参数，可能需要验证码或二次认证。")
        }

        val authBody = formBody(
            linkedMapOf(
                "username" to username.trim(),
                "password" to encryptPassword(password, salt),
                "cllt" to "userNameLogin",
                "dllt" to "generalLogin",
                "lt" to "",
                "execution" to execution,
                "_eventId" to "submit",
                "rmShown" to "1",
            ),
        )

        val authResponse = request(
            method = "POST",
            url = AUTH_LOGIN,
            headers = mapOf(
                "Accept" to "*/*",
                "Content-Type" to "application/x-www-form-urlencoded; charset=UTF-8",
                "Origin" to "https://authserver.gdut.edu.cn",
                "Referer" to AUTH_LOGIN,
            ),
            body = authBody,
        )

        val firstLocation = authResponse.location
            ?: throw IllegalStateException(extractLoginError(authResponse.body) ?: "认证失败")

        followRedirects(AUTH_LOGIN, firstLocation)
    }

    private fun postJson(
        path: String,
        referer: String,
        fields: LinkedHashMap<String, String>,
    ): String {
        val response = request(
            method = "POST",
            url = "$JW_ENTRY/$path",
            headers = mapOf(
                "Accept" to "application/json, text/javascript, */*; q=0.01",
                "Content-Type" to "application/x-www-form-urlencoded; charset=UTF-8",
                "X-Requested-With" to "XMLHttpRequest",
                "Referer" to referer,
            ),
            body = formBody(fields),
        )

        if (response.status != 200) {
            throw IllegalStateException("接口返回 ${response.status}。")
        }

        val body = response.body.trimStart()
        if (!body.startsWith("{")) {
            throw IllegalStateException("教务系统返回了网页页面，登录态可能已失效，请重新登录后再刷新。")
        }
        return body
    }

    private fun followRedirects(startUrl: String, firstLocation: String) {
        var currentUrl = startUrl
        var nextLocation: String? = firstLocation

        repeat(12) {
            val target = resolveUrl(currentUrl, nextLocation ?: return)
            val response = request("GET", target)
            currentUrl = target
            nextLocation = response.location
            if (nextLocation == null) {
                return
            }
        }

        throw IllegalStateException("统一认证跳转次数过多，登录流程可能已变化。")
    }

    private fun request(
        method: String,
        url: String,
        headers: Map<String, String> = emptyMap(),
        body: String? = null,
    ): NativeResponse {
        val parsedUrl = URL(url)
        val connection = parsedUrl.openConnection() as HttpURLConnection
        if (connection is HttpsURLConnection) {
            connection.sslSocketFactory = sslSocketFactory
            connection.hostnameVerifier = gdutHostnameVerifier
        }

        connection.instanceFollowRedirects = false
        connection.requestMethod = method
        connection.connectTimeout = 20000
        connection.readTimeout = 30000
        connection.setRequestProperty("User-Agent", USER_AGENT)
        for ((key, value) in headers) {
            connection.setRequestProperty(key, value)
        }

        val cookieHeader = cookieHeader(parsedUrl.host)
        if (cookieHeader.isNotEmpty()) {
            connection.setRequestProperty("Cookie", cookieHeader)
        }

        if (body != null) {
            val bytes = body.toByteArray(Charsets.UTF_8)
            connection.doOutput = true
            connection.setFixedLengthStreamingMode(bytes.size)
            if (!headers.containsKey("Content-Type")) {
                connection.setRequestProperty(
                    "Content-Type",
                    "application/x-www-form-urlencoded; charset=UTF-8",
                )
            }
            connection.outputStream.use { it.write(bytes) }
        }

        val status = connection.responseCode
        saveCookies(parsedUrl.host, connection.headerFields["Set-Cookie"])
        val responseBody = readBody(
            if (status >= 400) connection.errorStream else connection.inputStream,
        )
        val location = connection.getHeaderField("Location")
        connection.disconnect()
        return NativeResponse(status, responseBody, location)
    }

    private fun saveCookies(host: String, values: List<String>?) {
        values ?: return
        for (raw in values) {
            val pair = raw.substringBefore(";")
            val index = pair.indexOf("=")
            if (index <= 0) {
                continue
            }
            val cookie = StoredCookie(
                host = host,
                name = pair.substring(0, index),
                value = pair.substring(index + 1),
            )
            cookies["${cookie.host}|${cookie.name}"] = cookie
        }
    }

    private fun cookieHeader(host: String): String {
        return cookies.values
            .filter { host == it.host || host.endsWith(".${it.host}") }
            .joinToString("; ") { "${it.name}=${it.value}" }
    }

    private fun inputValue(html: String, idOrName: String): String {
        val inputRegex = Regex(
            "<input[^>]*(?:id|name)=[\"']${Regex.escape(idOrName)}[\"'][^>]*>",
            setOf(RegexOption.IGNORE_CASE),
        )
        val input = inputRegex.find(html)?.value ?: return ""
        return Regex("value=[\"']([^\"']*)[\"']", RegexOption.IGNORE_CASE)
            .find(input)
            ?.groupValues
            ?.get(1)
            .orEmpty()
    }

    private fun encryptPassword(password: String, salt: String): String {
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(
            Cipher.ENCRYPT_MODE,
            SecretKeySpec(salt.toByteArray(Charsets.UTF_8), "AES"),
            IvParameterSpec(randomString(16).toByteArray(Charsets.UTF_8)),
        )
        val encrypted = cipher.doFinal(
            "${randomString(64)}$password".toByteArray(Charsets.UTF_8),
        )
        return Base64.encodeToString(encrypted, Base64.NO_WRAP)
    }

    private fun randomString(length: Int): String {
        val builder = StringBuilder(length)
        repeat(length) {
            builder.append(RANDOM_CHARS[random.nextInt(RANDOM_CHARS.length)])
        }
        return builder.toString()
    }

    private fun formBody(fields: LinkedHashMap<String, String>): String {
        return fields.entries.joinToString("&") { (key, value) ->
            "${encode(key)}=${encode(value)}"
        }
    }

    private fun encode(value: String): String {
        return URLEncoder.encode(value, "UTF-8")
    }

    private fun resolveUrl(base: String, location: String): String {
        return URL(URL(base), location).toString()
    }

    private fun extractLoginError(html: String): String? {
        val match = Regex(
            "id=[\"']showErrorTip[\"'][^>]*>(.*?)</",
            setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
        ).find(html)
        val text = match?.groupValues?.get(1)
            ?.replace(Regex("<[^>]+>"), "")
            ?.trim()
        return text?.takeIf { it.isNotEmpty() }
    }

    private fun readBody(stream: InputStream?): String {
        stream ?: return ""
        return BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { reader ->
            reader.readText()
        }
    }

    private data class NativeResponse(
        val status: Int,
        val body: String,
        val location: String?,
    )

    private data class StoredCookie(
        val host: String,
        val name: String,
        val value: String,
    )

    companion object {
        private const val AUTH_LOGIN =
            "https://authserver.gdut.edu.cn/authserver/login?service=https%3A%2F%2Fjxfw.gdut.edu.cn%2Fnew%2FssoLogin"
        private const val JW_ENTRY = "https://jxfw.gdut.edu.cn"
        private const val USER_AGENT =
            "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 GDUTSchedule/0.1"
        private const val RANDOM_CHARS =
            "ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678"

        private val sslSocketFactory by lazy {
            val trustManagers = arrayOf<TrustManager>(
                object : X509TrustManager {
                    override fun checkClientTrusted(
                        chain: Array<out X509Certificate>?,
                        authType: String?,
                    ) = Unit

                    override fun checkServerTrusted(
                        chain: Array<out X509Certificate>?,
                        authType: String?,
                    ) = Unit

                    override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
                },
            )
            SSLContext.getInstance("TLS").apply {
                init(null, trustManagers, SecureRandom())
            }.socketFactory
        }

        private val gdutHostnameVerifier = HostnameVerifier { hostname, session ->
            hostname == "gdut.edu.cn" ||
                hostname.endsWith(".gdut.edu.cn") ||
                HttpsURLConnection.getDefaultHostnameVerifier().verify(hostname, session)
        }
    }
}
