package com.example.gdut_class_schedule

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.dynamicanimation.animation.DynamicAnimation
import androidx.dynamicanimation.animation.FloatPropertyCompat
import androidx.dynamicanimation.animation.SpringAnimation
import androidx.dynamicanimation.animation.SpringForce
import kotlin.math.abs
import kotlin.math.roundToInt

class FloatingPetService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var petRoot: FrameLayout
    private lateinit var petParams: WindowManager.LayoutParams
    private var cardView: View? = null
    private var snapAnimation: SpringAnimation? = null
    private var downRawX = 0f
    private var downRawY = 0f
    private var downWindowX = 0
    private var downWindowY = 0
    private var dragged = false
    private var attachedSide = Side.RIGHT
    private var course = PetCourse.todayEmpty()

    private val prefs by lazy {
        getSharedPreferences("nyacourse_floating_pet", Context.MODE_PRIVATE)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        if (!canDrawOverlay()) {
            stopSelf()
            return
        }
        startAsForegroundService()
        createPet()
        startIdleAnimation()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        course = PetCourse.from(intent) ?: course
        if (cardView != null) {
            hideCard()
            showCard()
        }
        if (::petRoot.isInitialized && petRoot.parent == null && canDrawOverlay()) {
            windowManager.addView(petRoot, petParams)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        snapAnimation?.cancel()
        hideCard()
        if (::petRoot.isInitialized && petRoot.parent != null) {
            windowManager.removeView(petRoot)
        }
        super.onDestroy()
    }

    private fun createPet() {
        val size = dp(56)
        attachedSide = Side.valueOf(prefs.getString(KEY_SIDE, Side.RIGHT.name) ?: Side.RIGHT.name)
        petRoot = FrameLayout(this).apply {
            clipChildren = false
            clipToPadding = false
            addView(
                PixelPetView(context).apply {
                    bitmap = BitmapFactory.decodeResource(resources, R.drawable.floating_pet)
                },
                FrameLayout.LayoutParams(size, size, Gravity.CENTER),
            )
            setOnTouchListener(::onPetTouch)
        }

        val metrics = resources.displayMetrics
        val savedY = prefs.getInt(KEY_Y, (metrics.heightPixels * 0.45f).roundToInt())
        val startX = if (attachedSide == Side.LEFT) {
            -size / 2
        } else {
            metrics.widthPixels - size / 2
        }
        petParams = overlayParams(
            width = size,
            height = size,
            x = startX,
            y = savedY.coerceIn(0, metrics.heightPixels - size),
        )
        windowManager.addView(petRoot, petParams)
    }

    private fun onPetTouch(view: View, event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                snapAnimation?.cancel()
                val fullX = visibleXFor(attachedSide)
                animateX(fullX.toFloat(), stiffness = 300f, dampingRatio = 0.6f)
                downRawX = event.rawX
                downRawY = event.rawY
                downWindowX = fullX
                downWindowY = petParams.y
                dragged = false
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - downRawX
                val dy = event.rawY - downRawY
                if (abs(dx) > dp(4) || abs(dy) > dp(4)) {
                    dragged = true
                }
                petParams.x = downWindowX + dx.roundToInt()
                petParams.y = (downWindowY + dy.roundToInt())
                    .coerceIn(0, resources.displayMetrics.heightPixels - petParams.height)
                windowManager.updateViewLayout(petRoot, petParams)
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                prefs.edit().putInt(KEY_Y, petParams.y).apply()
                if (!dragged) {
                    playClickBounce()
                    sendBroadcast(Intent(ACTION_PET_CLICK).setPackage(packageName))
                    toggleCard()
                }
                snapToNearestSide()
                view.performClick()
                return true
            }
            MotionEvent.ACTION_OUTSIDE -> {
                hideCard()
                return false
            }
        }
        return false
    }

    private fun snapToNearestSide() {
        val screenWidth = resources.displayMetrics.widthPixels
        attachedSide = if (petParams.x + petParams.width / 2 < screenWidth / 2) {
            Side.LEFT
        } else {
            Side.RIGHT
        }
        prefs.edit()
            .putString(KEY_SIDE, attachedSide.name)
            .putInt(KEY_Y, petParams.y)
            .apply()
        val target = hiddenXFor(attachedSide)
        animateX(target.toFloat(), stiffness = 300f, dampingRatio = 0.6f)
    }

    private fun animateX(target: Float, stiffness: Float, dampingRatio: Float) {
        snapAnimation?.cancel()
        snapAnimation = SpringAnimation(this, X_PROPERTY, target).apply {
            spring = SpringForce(target).apply {
                this.stiffness = stiffness
                this.dampingRatio = dampingRatio
            }
            start()
        }
    }

    private fun playClickBounce() {
        SpringAnimation(petRoot, DynamicAnimation.SCALE_X, 1f).apply {
            setStartValue(1.16f)
            spring = SpringForce(1f).apply {
                stiffness = 500f
                dampingRatio = 0.4f
            }
            start()
        }
        SpringAnimation(petRoot, DynamicAnimation.SCALE_Y, 1f).apply {
            setStartValue(0.78f)
            spring = SpringForce(1f).apply {
                stiffness = 500f
                dampingRatio = 0.4f
            }
            start()
        }
    }

    private fun startIdleAnimation() {
        petRoot.rotation = 0f
        petRoot.translationY = 0f
    }

    private fun showCard() {
        hideCard()
        val card = createCourseCard()
        val cardWidth = dp(220)
        val margin = dp(8)
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels
        val maxCardHeight = (screenHeight * 0.35f).roundToInt()
        card.measure(
            View.MeasureSpec.makeMeasureSpec(cardWidth, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(maxCardHeight, View.MeasureSpec.AT_MOST),
        )
        val cardHeight = card.measuredHeight.coerceAtMost(maxCardHeight)
        val petX = visibleXFor(attachedSide)
        val x = if (attachedSide == Side.LEFT) {
            (petX + petParams.width + margin).coerceAtMost(screenWidth - cardWidth - margin)
        } else {
            (petX - cardWidth - margin).coerceAtLeast(margin)
        }
        val preferredY = petParams.y
        val y = if (preferredY + cardHeight + margin > screenHeight) {
            petParams.y + petParams.height - cardHeight
        } else {
            preferredY
        }.coerceIn(margin, screenHeight - cardHeight - margin)
        (card as? SpeechBubbleLayout)?.tailCenterY =
            (petParams.y + petParams.height / 2f - y)
                .coerceIn(dp(20).toFloat(), (cardHeight - dp(20)).toFloat())
        windowManager.addView(
            card,
            overlayParams(cardWidth, cardHeight, x, y),
        )
        cardView = card
    }

    private fun toggleCard() {
        if (cardView == null) {
            showCard()
        } else {
            hideCard()
        }
    }

    private fun hideCard() {
        cardView?.let {
            if (it.parent != null) {
                windowManager.removeView(it)
            }
        }
        cardView = null
    }

    private fun createCourseCard(): View {
        val root = SpeechBubbleLayout(this, attachedSide).apply {
            setPadding(
                if (attachedSide == Side.LEFT) dp(20) else dp(12),
                dp(12),
                if (attachedSide == Side.RIGHT) dp(20) else dp(12),
                dp(12),
            )
            elevation = dp(10).toFloat()
            translationZ = dp(10).toFloat()
            setOnTouchListener { _, event ->
                if (event.actionMasked == MotionEvent.ACTION_OUTSIDE) {
                    hideCard()
                }
                false
            }
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        fun text(value: String, size: Float, color: Int, bold: Boolean = false): TextView {
            return TextView(this).apply {
                text = value
                textSize = size
                setTextColor(color)
                maxLines = 2
                if (bold) {
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                }
            }
        }

        val statusColor = Color.argb(180, 24, 34, 46)
        val titleColor = Color.rgb(15, 26, 38)
        val bodyColor = Color.argb(220, 38, 52, 68)
        val accentColor = darkReadableColor(course.themeColor)

        content.addView(text(course.statusText, 13f, statusColor, true))
        if (course.title.isBlank()) {
            if (course.secondaryText.isNotBlank()) {
                content.addView(text(course.secondaryText, 12f, bodyColor))
            } else if (course.statusText.contains("未同步")) {
                content.addView(text("打开 App 同步课表后再查看", 12f, bodyColor))
            }
        } else {
            content.addView(text(course.title, 16f, titleColor, true))
            content.addView(text(course.location, 11.5f, bodyColor))
            content.addView(text(course.timeLabel, 11.5f, bodyColor))
            content.addView(text(course.distanceLabel, 12f, accentColor, true))
            if (course.urgent) {
                content.addView(text("快到上课时间啦", 12f, accentColor, true))
            }
        }
        root.addView(
            content,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        return root
    }

    private fun darkReadableColor(color: Int): Int {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        val luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return if (luminance > 135) Color.rgb(0, 107, 91) else color
    }

    private fun overlayParams(width: Int, height: Int, x: Int, y: Int): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        return WindowManager.LayoutParams(
            width,
            height,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            this.x = x
            this.y = y
        }
    }

    private fun startAsForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    PET_CHANNEL_ID,
                    "悬浮球",
                    NotificationManager.IMPORTANCE_MIN,
                ).apply {
                    setShowBadge(false)
                },
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, PET_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("NyaCourse 悬浮球运行中")
            .setContentText("点击悬浮球查看课程提醒")
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_MIN)
            .build()
        startForeground(PET_NOTIFICATION_ID, notification)
    }

    private fun canDrawOverlay(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
    }

    private fun visibleXFor(side: Side): Int {
        val screenWidth = resources.displayMetrics.widthPixels
        return if (side == Side.LEFT) 0 else screenWidth - petParams.width
    }

    private fun hiddenXFor(side: Side): Int {
        val screenWidth = resources.displayMetrics.widthPixels
        return if (side == Side.LEFT) {
            -petParams.width / 2
        } else {
            screenWidth - petParams.width / 2
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).roundToInt()
    }

    enum class Side { LEFT, RIGHT }

    private data class PetCourse(
        val title: String,
        val statusText: String,
        val secondaryText: String,
        val location: String,
        val timeLabel: String,
        val distanceLabel: String,
        val urgent: Boolean,
        val themeColor: Int,
        val cardBlur: Float,
    ) {
        companion object {
            fun todayEmpty() = PetCourse(
                title = "",
                statusText = "今天没有课程",
                secondaryText = "",
                location = "",
                timeLabel = "",
                distanceLabel = "",
                urgent = false,
                themeColor = Color.rgb(0, 107, 91),
                cardBlur = 20f,
            )

            fun from(intent: Intent?): PetCourse? {
                intent ?: return null
                if (intent.action != ACTION_SHOW && intent.action != ACTION_UPDATE_COURSE) {
                    return null
                }
                val statusText = intent.getStringExtra(EXTRA_STATUS_TEXT).orEmpty()
                    .ifBlank { "今天没有课程" }
                val name = intent.getStringExtra(EXTRA_COURSE_NAME).orEmpty()
                val themeColor = intent.getIntExtra(EXTRA_THEME_COLOR, Color.rgb(0, 107, 91))
                val cardBlur = intent.getFloatExtra(EXTRA_CARD_BLUR, 20f)
                val secondaryText = intent.getStringExtra(EXTRA_SECONDARY_TEXT).orEmpty()
                if (name.isBlank()) {
                    return todayEmpty().copy(
                        statusText = statusText,
                        secondaryText = secondaryText,
                        themeColor = themeColor,
                        cardBlur = cardBlur,
                    )
                }
                val location = intent.getStringExtra(EXTRA_LOCATION).orEmpty()
                val startTime = intent.getStringExtra(EXTRA_START_TIME).orEmpty()
                val minutes = intent.getIntExtra(EXTRA_MINUTES_LEFT, -1)
                val dayLabel = intent.getStringExtra(EXTRA_DAY_LABEL).orEmpty()
                val timeLabel = buildString {
                    if (dayLabel.isNotBlank()) {
                        append(dayLabel)
                        append(" ")
                    }
                    append(if (startTime.isBlank()) "开始时间未公布" else startTime)
                }
                return PetCourse(
                    title = name,
                    statusText = statusText,
                    secondaryText = secondaryText,
                    location = if (location.isBlank()) "地点未公布" else location,
                    timeLabel = timeLabel,
                    distanceLabel = if (minutes >= 0) {
                        "还有 ${formatDistance(minutes)}"
                    } else {
                        ""
                    },
                    urgent = intent.getBooleanExtra(EXTRA_URGENT, false),
                    themeColor = themeColor,
                    cardBlur = cardBlur,
                )
            }
        }
    }

    companion object {
        const val ACTION_SHOW = "com.example.gdut_class_schedule.pet.SHOW"
        const val ACTION_UPDATE_COURSE = "com.example.gdut_class_schedule.pet.UPDATE_COURSE"
        const val ACTION_PET_CLICK = "com.example.gdut_class_schedule.pet.CLICK"
        const val EXTRA_STATUS_TEXT = "statusText"
        const val EXTRA_COURSE_NAME = "courseName"
        const val EXTRA_LOCATION = "location"
        const val EXTRA_START_TIME = "startTime"
        const val EXTRA_MINUTES_LEFT = "minutesLeft"
        const val EXTRA_DAY_LABEL = "dayLabel"
        const val EXTRA_SECONDARY_TEXT = "secondaryText"
        const val EXTRA_URGENT = "urgent"
        const val EXTRA_THEME_COLOR = "themeColorValue"
        const val EXTRA_CARD_BLUR = "cardBlur"
        private const val PET_CHANNEL_ID = "floating_pet"
        private const val PET_NOTIFICATION_ID = 2401
        private const val KEY_Y = "y"
        private const val KEY_SIDE = "side"

        private fun formatDistance(totalMinutes: Int): String {
            if (totalMinutes < 60) {
                return "$totalMinutes 分钟"
            }
            val days = totalMinutes / (24 * 60)
            val hours = (totalMinutes % (24 * 60)) / 60
            val minutes = totalMinutes % 60
            if (days > 0) {
                return if (hours > 0) "$days 天 $hours 小时" else "$days 天"
            }
            return if (minutes > 0) "$hours 小时 $minutes 分钟" else "$hours 小时"
        }

        private val X_PROPERTY = object : FloatPropertyCompat<FloatingPetService>("petX") {
            override fun getValue(service: FloatingPetService): Float = service.petParams.x.toFloat()

            override fun setValue(service: FloatingPetService, value: Float) {
                if (!service::petRoot.isInitialized || service.petRoot.parent == null) {
                    return
                }
                service.petParams.x = value.roundToInt()
                service.windowManager.updateViewLayout(service.petRoot, service.petParams)
            }
        }
    }
}

private class PixelPetView(context: Context) : View(context) {
    var bitmap: Bitmap? = null
        set(value) {
            field = value
            invalidate()
        }

    private val paint = Paint().apply {
        isAntiAlias = false
        isFilterBitmap = false
        isDither = false
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val source = bitmap ?: return
        canvas.drawBitmap(
            source,
            Rect(0, 0, source.width, source.height),
            RectF(0f, 0f, width.toFloat(), height.toFloat()),
            paint,
        )
    }
}

private class SpeechBubbleLayout(
    context: Context,
    private val side: FloatingPetService.Side,
) : FrameLayout(context) {
    var tailCenterY: Float = 0f
        set(value) {
            field = value
            invalidate()
        }

    private val density = resources.displayMetrics.density
    private val cornerRadius = 16f * density
    private val tailWidth = 10f * density
    private val tailHalfHeight = 8f * density
    private val path = Path()

    private val fillPaint = Paint().apply {
        isAntiAlias = true
        color = Color.argb(220, 255, 255, 255)
        style = Paint.Style.FILL
    }

    private val strokePaint = Paint().apply {
        isAntiAlias = true
        color = Color.argb(210, 255, 255, 255)
        style = Paint.Style.STROKE
        strokeWidth = 1f
    }

    init {
        setWillNotDraw(false)
        clipChildren = false
        clipToPadding = false
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f || h <= 0f) {
            super.onDraw(canvas)
            return
        }
        val left = if (side == FloatingPetService.Side.LEFT) tailWidth else 0f
        val right = if (side == FloatingPetService.Side.RIGHT) w - tailWidth else w
        val top = 0f
        val bottom = h
        val centerY = (if (tailCenterY > 0f) tailCenterY else h / 2f)
            .coerceIn(cornerRadius + tailHalfHeight, h - cornerRadius - tailHalfHeight)

        path.reset()
        path.moveTo(left + cornerRadius, top)
        path.lineTo(right - cornerRadius, top)
        path.quadTo(right, top, right, top + cornerRadius)
        if (side == FloatingPetService.Side.LEFT) {
            path.lineTo(right, bottom - cornerRadius)
            path.quadTo(right, bottom, right - cornerRadius, bottom)
            path.lineTo(left + cornerRadius, bottom)
            path.quadTo(left, bottom, left, bottom - cornerRadius)
            path.lineTo(left, centerY + tailHalfHeight)
            path.lineTo(0f, centerY)
            path.lineTo(left, centerY - tailHalfHeight)
            path.lineTo(left, top + cornerRadius)
            path.quadTo(left, top, left + cornerRadius, top)
        } else {
            path.lineTo(right, centerY - tailHalfHeight)
            path.lineTo(w, centerY)
            path.lineTo(right, centerY + tailHalfHeight)
            path.lineTo(right, bottom - cornerRadius)
            path.quadTo(right, bottom, right - cornerRadius, bottom)
            path.lineTo(left + cornerRadius, bottom)
            path.quadTo(left, bottom, left, bottom - cornerRadius)
            path.lineTo(left, top + cornerRadius)
            path.quadTo(left, top, left + cornerRadius, top)
        }
        path.close()
        canvas.drawPath(path, fillPaint)
        canvas.drawPath(path, strokePaint)
        super.onDraw(canvas)
    }
}
