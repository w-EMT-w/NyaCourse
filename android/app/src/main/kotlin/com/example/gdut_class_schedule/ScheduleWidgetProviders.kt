package com.example.gdut_class_schedule

import android.app.PendingIntent
import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Build
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar
import java.util.concurrent.TimeUnit

class ScheduleMediumWidgetProvider : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            WidgetRefreshScheduler.ACTION_REFRESH,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> refreshAllWidgets(context)
            else -> super.onReceive(context, intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = try {
                ScheduleWidgetRenderer.medium(context, widgetData)
            } catch (_: Throwable) {
                ScheduleWidgetRenderer.fallback(context)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
        WidgetRefreshScheduler.schedule(context, widgetData)
    }

    override fun onDisabled(context: Context) {
        WidgetRefreshScheduler.cancel(context)
        super.onDisabled(context)
    }

    private fun refreshAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, ScheduleMediumWidgetProvider::class.java))
        if (ids.isEmpty()) {
            WidgetRefreshScheduler.cancel(context)
            return
        }
        onUpdate(
            context,
            manager,
            ids,
            context.getSharedPreferences(WidgetRefreshScheduler.PREFERENCES, Context.MODE_PRIVATE),
        )
    }
}

private object WidgetRefreshScheduler {
    const val ACTION_REFRESH = "com.example.gdut_class_schedule.action.REFRESH_SCHEDULE_WIDGET"
    const val PREFERENCES = "HomeWidgetPreferences"
    private const val REQUEST_CODE = 2206

    fun schedule(context: Context, data: SharedPreferences) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, ScheduleMediumWidgetProvider::class.java))
        if (ids.isEmpty()) {
            cancel(context)
            return
        }
        val triggerAt = WidgetScheduleSnapshot.nextRefreshAt(data)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = pendingIntent(context)
        alarmManager.cancel(intent)
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms() -> {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, intent)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, intent)
            }
            else -> alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, intent)
        }
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context))
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ScheduleMediumWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
    }
}

private object ScheduleWidgetRenderer {
    fun fallback(context: Context): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_medium).apply {
            setInt(R.id.widget_medium_root, "setBackgroundResource", R.drawable.widget_bg_light)
            setTextViewText(R.id.tv_date_medium, "今天")
            setTextViewText(R.id.tv_empty_medium, "暂无课程安排")
            setTextColor(R.id.tv_date_medium, Color.parseColor("#E6000000"))
            setTextColor(R.id.tv_empty_medium, Color.parseColor("#990F172A"))
            setViewVisibility(R.id.tv_empty_medium, View.VISIBLE)
            setViewVisibility(R.id.row_0, View.GONE)
            setViewVisibility(R.id.row_1, View.GONE)
            setViewVisibility(R.id.row_2, View.GONE)
            setOnClickPendingIntent(R.id.widget_medium_root, launchIntent(context))
        }
    }

    fun medium(context: Context, data: SharedPreferences): RemoteViews {
        val mode = data.safeString("widget_appearance_mode")
        val dark = mode == "dark" || (mode.isBlank() && data.safeBoolean("widget_dark_mode"))
        val paper = mode == "paper"
        val palette = WidgetPalette(dark, paper)
        val nativeSnapshot = WidgetScheduleSnapshot.from(data)
        return RemoteViews(context.packageName, R.layout.widget_medium).apply {
            setInt(
                R.id.widget_medium_root,
                "setBackgroundResource",
                when {
                    dark -> R.drawable.widget_bg_dark
                    paper -> R.drawable.widget_bg_paper
                    else -> R.drawable.widget_bg_light
                },
            )
            setTextViewText(
                R.id.tv_date_medium,
                nativeSnapshot?.dateTitle ?: data.safeString("widget_date_title", "今天"),
            )
            setTextViewText(
                R.id.tv_medium_state,
                nativeSnapshot?.stateLabel ?: data.safeString("widget_state_label", "今日课程"),
            )
            setTextColor(R.id.tv_date_medium, palette.primary)
            setTextColor(R.id.tv_medium_state, palette.muted)
            setImageViewResource(
                R.id.iv_medium_calendar,
                if (dark) R.drawable.ic_widget_calendar_dark else R.drawable.ic_widget_calendar,
            )
            val count = nativeSnapshot?.rows?.size ?: data.safeInt("widget_course_count").coerceIn(0, 3)
            if (nativeSnapshot != null) {
                bindRow(
                    this,
                    nativeSnapshot.rows.getOrNull(0),
                    palette,
                    count,
                    0,
                    R.id.row_0,
                    R.id.dot_0,
                    R.id.time_0,
                    R.id.name_0,
                    R.id.room_0,
                    R.id.period_0,
                    R.id.divider_0,
                )
                bindRow(
                    this,
                    nativeSnapshot.rows.getOrNull(1),
                    palette,
                    count,
                    1,
                    R.id.row_1,
                    R.id.dot_1,
                    R.id.time_1,
                    R.id.name_1,
                    R.id.room_1,
                    R.id.period_1,
                    R.id.divider_1,
                )
                bindRow(
                    this,
                    nativeSnapshot.rows.getOrNull(2),
                    palette,
                    count,
                    2,
                    R.id.row_2,
                    R.id.dot_2,
                    R.id.time_2,
                    R.id.name_2,
                    R.id.room_2,
                    R.id.period_2,
                    R.id.divider_2,
                )
            } else {
                bindRow(
                    this,
                    data,
                    palette,
                    count,
                    0,
                    R.id.row_0,
                    R.id.dot_0,
                    R.id.time_0,
                    R.id.name_0,
                    R.id.room_0,
                    R.id.period_0,
                    R.id.divider_0,
                )
                bindRow(
                    this,
                    data,
                    palette,
                    count,
                    1,
                    R.id.row_1,
                    R.id.dot_1,
                    R.id.time_1,
                    R.id.name_1,
                    R.id.room_1,
                    R.id.period_1,
                    R.id.divider_1,
                )
                bindRow(
                    this,
                    data,
                    palette,
                    count,
                    2,
                    R.id.row_2,
                    R.id.dot_2,
                    R.id.time_2,
                    R.id.name_2,
                    R.id.room_2,
                    R.id.period_2,
                    R.id.divider_2,
                )
            }
            setViewVisibility(R.id.tv_empty_medium, if (count == 0) View.VISIBLE else View.GONE)
            setTextViewText(
                R.id.tv_empty_medium,
                nativeSnapshot?.emptyText ?: data.safeString("widget_subtitle", "暂无课程安排"),
            )
            setTextColor(R.id.tv_empty_medium, palette.secondary)
            setOnClickPendingIntent(R.id.widget_medium_root, launchIntent(context))
        }
    }

    private fun bindRow(
        views: RemoteViews,
        row: WidgetCourseRow?,
        palette: WidgetPalette,
        count: Int,
        index: Int,
        rowId: Int,
        dotId: Int,
        timeId: Int,
        nameId: Int,
        roomId: Int,
        periodId: Int,
        dividerId: Int,
    ) {
        views.setViewVisibility(rowId, if (row == null) View.GONE else View.VISIBLE)
        if (row == null) {
            views.setViewVisibility(dividerId, View.GONE)
            return
        }
        bindRowTexts(
            views = views,
            palette = palette,
            index = index,
            count = count,
            dotId = dotId,
            timeId = timeId,
            nameId = nameId,
            roomId = roomId,
            periodId = periodId,
            dividerId = dividerId,
            name = row.name,
            room = row.room,
            start = row.start,
            period = row.period,
            state = row.state,
            courseColor = row.color,
        )
    }

    private fun bindRow(
        views: RemoteViews,
        data: SharedPreferences,
        palette: WidgetPalette,
        count: Int,
        index: Int,
        rowId: Int,
        dotId: Int,
        timeId: Int,
        nameId: Int,
        roomId: Int,
        periodId: Int,
        dividerId: Int,
    ) {
        val name = data.safeString("widget_course_${index}_name")
        views.setViewVisibility(rowId, if (name.isBlank()) View.GONE else View.VISIBLE)
        if (name.isBlank()) {
            views.setViewVisibility(dividerId, View.GONE)
            return
        }
        val room = data.safeString("widget_course_${index}_location")
        bindRowTexts(
            views = views,
            palette = palette,
            index = index,
            count = count,
            dotId = dotId,
            timeId = timeId,
            nameId = nameId,
            roomId = roomId,
            periodId = periodId,
            dividerId = dividerId,
            name = name,
            room = room,
            start = data.safeString("widget_course_${index}_start"),
            period = data.safeString("widget_course_${index}_time"),
            state = data.safeString("widget_course_${index}_state"),
            courseColor = data.safeInt("widget_course_${index}_color"),
        )
    }

    private fun bindRowTexts(
        views: RemoteViews,
        palette: WidgetPalette,
        index: Int,
        count: Int,
        dotId: Int,
        timeId: Int,
        nameId: Int,
        roomId: Int,
        periodId: Int,
        dividerId: Int,
        name: String,
        room: String,
        start: String,
        period: String,
        state: String,
        courseColor: Int,
    ) {
        val isCurrent = state == "current"
        val isDone = state == "done"
        views.setTextViewText(dotId, "•")
        views.setTextViewText(timeId, start)
        views.setTextViewText(nameId, name)
        views.setTextViewText(roomId, room)
        views.setTextViewText(periodId, period)
        views.setTextViewTextSize(
            nameId,
            TypedValue.COMPLEX_UNIT_SP,
            if (name.length > 8) 13f else 14f,
        )
        views.setTextViewTextSize(
            roomId,
            TypedValue.COMPLEX_UNIT_SP,
            when {
                room.length <= 6 -> 11f
                room.length <= 10 -> 10f
                else -> 9f
            },
        )
        val dotColor = when {
            isCurrent -> palette.current
            isDone -> palette.doneDot
            courseColor != 0 -> courseColor
            else -> palette.dot
        }
        val mainColor = if (isDone) palette.donePrimary else palette.primary
        val subColor = if (isDone) palette.doneSecondary else palette.secondary
        val roomColor = if (isDone) palette.doneMuted else palette.muted
        val periodColor = if (isDone) palette.donePeriod else palette.period
        views.setTextColor(dotId, dotColor)
        views.setTextColor(timeId, subColor)
        views.setTextColor(nameId, mainColor)
        views.setTextColor(roomId, roomColor)
        views.setTextColor(periodId, periodColor)
        views.setViewVisibility(dividerId, if (index < count - 1) View.VISIBLE else View.GONE)
    }

    private fun launchIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(context, 2205, intent, flags)
    }
}

private data class WidgetCourseRow(
    val name: String,
    val room: String,
    val start: String,
    val period: String,
    val state: String,
    val color: Int,
)

private data class NativeCourse(
    val name: String,
    val room: String,
    val dayOfWeek: Int,
    val startSection: Int,
    val endSection: Int,
    val weeks: Set<Int>,
) {
    val startMinute: Int get() = sectionRange(startSection)?.firstMinute ?: 0
    val endMinute: Int get() = sectionRange(endSection)?.secondMinute ?: 0
    val startLabel: String get() = sectionRange(startSection)?.first ?: "--:--"
    val periodLabel: String
        get() {
            val start = sectionRange(startSection)?.first ?: "--:--"
            val end = sectionRange(endSection)?.second ?: "--:--"
            return "$start-$end"
        }
}

private data class WidgetScheduleSnapshot(
    val dateTitle: String,
    val stateLabel: String,
    val emptyText: String,
    val rows: List<WidgetCourseRow>,
) {
    companion object {
        fun nextRefreshAt(data: SharedPreferences): Long {
            val now = Calendar.getInstance()
            val nowMs = now.timeInMillis
            val todayStart = startOfDay(nowMs)
            val tomorrow = Calendar.getInstance().apply {
                timeInMillis = todayStart
                add(Calendar.DAY_OF_MONTH, 1)
            }.timeInMillis
            val json = data.safeString("widget_source_courses_json")
            val termStartMs = data.safeLong("widget_term_start_ms")
            if (json.isBlank() || termStartMs <= 0L) {
                return tomorrow
            }
            val allCourses = runCatching { parseCourses(json) }.getOrNull() ?: return tomorrow
            val currentWeek = currentWeek(todayStart, startOfDay(termStartMs))
            val weekday = ((now.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
            val candidates = mutableListOf(tomorrow)
            allCourses
                .filter { course ->
                    course.dayOfWeek == weekday &&
                        (course.weeks.isEmpty() || course.weeks.contains(currentWeek))
                }
                .forEach { course ->
                    listOf(course.startMinute, course.endMinute).forEach { minute ->
                        val triggerAt = todayStart + TimeUnit.MINUTES.toMillis(minute.toLong())
                        if (triggerAt > nowMs) {
                            candidates.add(triggerAt)
                        }
                    }
                }
            return candidates.minOrNull() ?: tomorrow
        }

        fun from(data: SharedPreferences): WidgetScheduleSnapshot? {
            val json = data.safeString("widget_source_courses_json")
            val termStartMs = data.safeLong("widget_term_start_ms")
            if (json.isBlank() || termStartMs <= 0L) {
                return null
            }
            val allCourses = runCatching { parseCourses(json) }.getOrNull() ?: return null
            val now = Calendar.getInstance()
            val todayStart = startOfDay(now.timeInMillis)
            val currentWeek = currentWeek(todayStart, startOfDay(termStartMs))
            val weekday = ((now.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
            val minuteOfDay = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            val todayCourses = allCourses
                .filter { course ->
                    course.dayOfWeek == weekday &&
                        (course.weeks.isEmpty() || course.weeks.contains(currentWeek))
                }
                .sortedBy { it.startMinute }
            val nextCourse = todayCourses.firstOrNull { it.startMinute > minuteOfDay }
            val hasCurrent = todayCourses.any {
                minuteOfDay >= it.startMinute && minuteOfDay < it.endMinute
            }
            val stateLabel = when {
                todayCourses.isEmpty() -> "今日无课"
                hasCurrent -> "上课中"
                nextCourse != null && todayCourses.any { it.endMinute < minuteOfDay } -> "课间空档"
                nextCourse != null -> "今日有课"
                else -> "已结束"
            }
            val visible = visibleCourseWindow(todayCourses, minuteOfDay)
            return WidgetScheduleSnapshot(
                dateTitle = "今天 · ${weekdayLabel(weekday)}",
                stateLabel = stateLabel,
                emptyText = "暂无课程安排",
                rows = visible.map { course ->
                    WidgetCourseRow(
                        name = course.name,
                        room = compactLocation(course.room),
                        start = course.startLabel,
                        period = course.periodLabel,
                        state = courseState(course, minuteOfDay, nextCourse),
                        color = colorFor(course.name),
                    )
                },
            )
        }

        private fun parseCourses(json: String): List<NativeCourse> {
            val array = JSONArray(json)
            return buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val weeks = mutableSetOf<Int>()
                    val weeksArray = item.optJSONArray("weeks")
                    if (weeksArray != null) {
                        for (weekIndex in 0 until weeksArray.length()) {
                            weeks.add(weeksArray.optInt(weekIndex))
                        }
                    }
                    add(
                        NativeCourse(
                            name = item.optString("name"),
                            room = item.optString("location"),
                            dayOfWeek = item.optInt("dayOfWeek"),
                            startSection = item.optInt("startSection"),
                            endSection = item.optInt("endSection"),
                            weeks = weeks,
                        ),
                    )
                }
            }
        }

        private fun currentWeek(todayStartMs: Long, termStartMs: Long): Int {
            val diffDays = TimeUnit.MILLISECONDS.toDays(todayStartMs - termStartMs)
            if (diffDays < 0) {
                return 1
            }
            return (diffDays / 7 + 1).coerceIn(1, 25).toInt()
        }

        private fun startOfDay(timeMs: Long): Long {
            val calendar = Calendar.getInstance()
            calendar.timeInMillis = timeMs
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            return calendar.timeInMillis
        }

        private fun visibleCourseWindow(courses: List<NativeCourse>, nowMinute: Int): List<NativeCourse> {
            if (courses.size <= 3) {
                return courses
            }
            val firstUsefulIndex = courses.indexOfFirst { it.endMinute > nowMinute }
            if (firstUsefulIndex == -1) {
                return listOf(courses.last())
            }
            val end = (firstUsefulIndex + 3).coerceAtMost(courses.size)
            val window = courses.subList(firstUsefulIndex, end)
            if (window.size == 3 || firstUsefulIndex == 0) {
                return window
            }
            val needed = 3 - window.size
            val start = (firstUsefulIndex - needed).coerceAtLeast(0)
            return courses.subList(start, firstUsefulIndex) + window
        }

        private fun courseState(
            course: NativeCourse,
            nowMinute: Int,
            nextCourse: NativeCourse?,
        ): String {
            if (nowMinute >= course.startMinute && nowMinute < course.endMinute) {
                return "current"
            }
            if (nextCourse == course) {
                return "next"
            }
            if (nowMinute >= course.endMinute) {
                return "done"
            }
            return "upcoming"
        }

        private fun weekdayLabel(day: Int): String {
            return "周${listOf("一", "二", "三", "四", "五", "六", "日")[day - 1]}"
        }

        private fun compactLocation(location: String): String {
            return location
                .trim()
                .replace(Regex("\\s+"), "")
                .replaceFirst(Regex("^教学楼"), "")
                .replaceFirst(Regex("^教学"), "")
        }

        private fun colorFor(name: String): Int {
            val colors = intArrayOf(
                Color.parseColor("#3B8DF6"),
                Color.parseColor("#38C986"),
                Color.parseColor("#FF8A28"),
                Color.parseColor("#9B6CFF"),
                Color.parseColor("#2BB3A3"),
            )
            return colors[(name.hashCode() and Int.MAX_VALUE) % colors.size]
        }
    }
}

private data class SectionRange(
    val first: String,
    val second: String,
) {
    val firstMinute: Int = parseMinute(first)
    val secondMinute: Int = parseMinute(second)
}

private fun sectionRange(section: Int): SectionRange? {
    return when (section) {
        1 -> SectionRange("08:30", "09:15")
        2 -> SectionRange("09:20", "10:05")
        3 -> SectionRange("10:25", "11:10")
        4 -> SectionRange("11:15", "12:00")
        5 -> SectionRange("13:50", "14:35")
        6 -> SectionRange("14:40", "15:25")
        7 -> SectionRange("15:30", "16:15")
        8 -> SectionRange("16:30", "17:15")
        9 -> SectionRange("17:20", "18:05")
        10 -> SectionRange("18:30", "19:15")
        11 -> SectionRange("19:20", "20:05")
        12 -> SectionRange("20:10", "20:55")
        else -> null
    }
}

private fun parseMinute(value: String): Int {
    val parts = value.split(":")
    if (parts.size != 2) {
        return 0
    }
    return (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
}

private fun SharedPreferences.safeString(key: String, fallback: String = ""): String {
    return when (val value = all[key]) {
        is String -> value
        is Number -> value.toString()
        is Boolean -> value.toString()
        else -> fallback
    }
}

private fun SharedPreferences.safeLong(key: String, fallback: Long = 0L): Long {
    return when (val value = all[key]) {
        is Long -> value
        is Int -> value.toLong()
        is Float -> value.toLong()
        is String -> value.toLongOrNull() ?: fallback
        else -> fallback
    }
}

private fun SharedPreferences.safeBoolean(key: String, fallback: Boolean = false): Boolean {
    return when (val value = all[key]) {
        is Boolean -> value
        is String -> value.equals("true", ignoreCase = true)
        is Number -> value.toInt() != 0
        else -> fallback
    }
}

private fun SharedPreferences.safeInt(key: String, fallback: Int = 0): Int {
    return when (val value = all[key]) {
        is Int -> value
        is Long -> value.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()
        is Float -> value.toInt()
        is String -> value.toIntOrNull() ?: fallback
        else -> fallback
    }
}

private class WidgetPalette(
    dark: Boolean,
    paper: Boolean,
) {
    val primary: Int = when {
        dark -> Color.parseColor("#F2FFFFFF")
        else -> Color.parseColor("#F20F172A")
    }
    val secondary: Int = when {
        dark -> Color.parseColor("#CCFFFFFF")
        paper -> Color.parseColor("#CC1F2937")
        else -> Color.parseColor("#CC334155")
    }
    val muted: Int = when {
        dark -> Color.parseColor("#A6FFFFFF")
        paper -> Color.parseColor("#994B5563")
        else -> Color.parseColor("#B0647280")
    }
    val period: Int = when {
        dark -> Color.parseColor("#8CFFFFFF")
        paper -> Color.parseColor("#805B6472")
        else -> Color.parseColor("#8A64748B")
    }
    val dot: Int = when {
        dark -> Color.parseColor("#80FFFFFF")
        paper -> Color.parseColor("#806B7280")
        else -> Color.parseColor("#8064748B")
    }
    val donePrimary: Int = when {
        dark -> Color.parseColor("#B8FFFFFF")
        paper -> Color.parseColor("#B31F2937")
        else -> Color.parseColor("#B8334155")
    }
    val doneSecondary: Int = when {
        dark -> Color.parseColor("#99FFFFFF")
        paper -> Color.parseColor("#995B6472")
        else -> Color.parseColor("#9964748B")
    }
    val doneMuted: Int = when {
        dark -> Color.parseColor("#85FFFFFF")
        paper -> Color.parseColor("#855B6472")
        else -> Color.parseColor("#8A64748B")
    }
    val donePeriod: Int = when {
        dark -> Color.parseColor("#73FFFFFF")
        paper -> Color.parseColor("#735B6472")
        else -> Color.parseColor("#7864748B")
    }
    val doneDot: Int = when {
        dark -> Color.parseColor("#66FFFFFF")
        paper -> Color.parseColor("#66718096")
        else -> Color.parseColor("#66718096")
    }
    val current: Int = when {
        dark -> Color.parseColor("#5DCAA5")
        else -> Color.parseColor("#22A36F")
    }
}
