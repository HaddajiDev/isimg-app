package io.github.haddajidev.isimg

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * "Aujourd'hui" home-screen widget, fed by HomeWidgetSync on the Dart side with
 * the week the app last loaded. Today is picked here at render time, so the
 * widget stays correct across midnight without opening the app.
 *
 * Layout: header (date + "done/total" with a progress bar), a hero card for
 * the class in progress or the next one — or, once the day is over, the next
 * class later in the week — then as many compact "Ensuite" rows as fit.
 */
class TodayWidgetProvider : HomeWidgetProvider() {

    private class Session(
        val date: String,
        val start: String,
        val end: String,
        val matiere: String,
        val type: String,
        val salle: String,
        val ratt: Boolean,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) draw(context, appWidgetManager, id, widgetData)
    }

    /** Resizing changes how many "Ensuite" rows fit. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        draw(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private fun draw(context: Context, manager: AppWidgetManager, id: Int, data: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.widget_today)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
        render(context, views, data.getString(DATA_KEY, null), heightDp(manager, id))
        manager.updateAppWidget(id, views)
    }

    /** Portrait launchers report the real height as the max height. */
    private fun heightDp(manager: AppWidgetManager, id: Int): Int {
        val o = manager.getAppWidgetOptions(id)
        val max = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        return if (max > 0) max else o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
    }

    private fun render(context: Context, views: RemoteViews, json: String?, heightDp: Int) {
        val now = Date()
        val today = DAY.format(now)
        val nowHm = HM.format(now)
        views.setTextViewText(R.id.widget_date, capitalize(DATE_LABEL.format(now)))
        views.removeAllViews(R.id.widget_rows)

        val payload = json?.let { runCatching { JSONObject(it) }.getOrNull() }
        if (payload == null) return showMessage(views, context.getString(R.string.widget_today_loading))

        val to = payload.optString("to")
        if (to.isNotEmpty() && today > to) {
            return showMessage(views, "Emploi à actualiser — ouvrez l'application")
        }

        val all = parse(payload)
        val todays = all.filter { it.date == today }

        // Day progress.
        val done = todays.count { it.end <= nowHm }
        if (todays.isNotEmpty()) {
            views.setTextViewText(R.id.widget_count, "$done/${todays.size}")
            views.setViewVisibility(R.id.widget_count, View.VISIBLE)
            views.setProgressBar(R.id.widget_progress, todays.size, done, false)
            views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_count, View.GONE)
            views.setViewVisibility(R.id.widget_progress, View.GONE)
        }

        val current = todays.firstOrNull { it.start <= nowHm && nowHm < it.end }
        val nextToday = todays.firstOrNull { it.start > nowHm }
        val hero = current ?: nextToday ?: all.firstOrNull { it.date > today }

        if (hero == null) {
            val sunday = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY
            return showMessage(
                views,
                when {
                    todays.isNotEmpty() -> "Journée terminée — plus de cours cette semaine"
                    sunday -> "Pas de cours le dimanche"
                    else -> "Pas de cours aujourd'hui"
                },
            )
        }

        views.setViewVisibility(R.id.widget_empty, View.GONE)
        views.setViewVisibility(R.id.hero, View.VISIBLE)
        views.setTextViewText(
            R.id.hero_label,
            when {
                hero === current -> "EN COURS · JUSQU'À ${hero.end}"
                hero === nextToday -> "PROCHAIN COURS"
                todays.isNotEmpty() -> "JOURNÉE TERMINÉE · ${dayLabel(hero.date, now)}"
                else -> "PAS DE COURS AUJOURD'HUI · ${dayLabel(hero.date, now)}"
            },
        )
        views.setTextViewText(R.id.hero_title, hero.matiere)
        views.setTextViewText(R.id.hero_time, "${hero.start} – ${hero.end}")
        views.setTextViewText(
            R.id.hero_meta,
            listOf(hero.type, hero.salle, if (hero.ratt) "Rattrapage" else "")
                .filter { it.isNotBlank() }
                .joinToString(" · "),
        )

        // The rest of today, after the hero.
        val later = if (hero.date == today) todays.filter { it.start > hero.start } else emptyList()
        if (later.isEmpty()) {
            views.setViewVisibility(R.id.next_label, View.GONE)
            views.setViewVisibility(R.id.widget_rows, View.GONE)
            return
        }
        // header 20 + progress 10 + hero ~70 + "Ensuite" 22 + padding 24.
        val fits = ((heightDp - 146) / ROW_DP).coerceIn(0, later.size)
        val hidden = later.size - fits
        views.setTextViewText(
            R.id.next_label,
            if (fits == 0) "ENSUITE · ${later.size} COURS" else if (hidden > 0) "ENSUITE · +$hidden" else "ENSUITE",
        )
        views.setViewVisibility(R.id.next_label, View.VISIBLE)
        views.setViewVisibility(R.id.widget_rows, if (fits > 0) View.VISIBLE else View.GONE)
        for (s in later.take(fits)) {
            val row = RemoteViews(context.packageName, R.layout.widget_today_next_row)
            row.setTextViewText(R.id.row_time, s.start)
            row.setTextViewText(R.id.row_matiere, s.matiere)
            row.setTextViewText(R.id.row_salle, s.salle)
            views.addView(R.id.widget_rows, row)
        }
    }

    private fun parse(payload: JSONObject): List<Session> {
        val arr = payload.optJSONArray("sessions") ?: return emptyList()
        return (0 until arr.length()).mapNotNull { i ->
            arr.optJSONObject(i)?.let {
                Session(
                    date = it.optString("date"),
                    start = it.optString("start"),
                    end = it.optString("end"),
                    matiere = it.optString("matiere"),
                    type = it.optString("type"),
                    salle = it.optString("salle"),
                    ratt = it.optBoolean("ratt"),
                )
            }
        }.sortedWith(compareBy({ it.date }, { it.start }))
    }

    /** "DEMAIN" or the weekday, e.g. "LUNDI". */
    private fun dayLabel(date: String, now: Date): String {
        val tomorrow = Calendar.getInstance().apply {
            time = now
            add(Calendar.DAY_OF_YEAR, 1)
        }
        if (date == DAY.format(tomorrow.time)) return "DEMAIN"
        val d = runCatching { DAY.parse(date) }.getOrNull() ?: return date
        return WEEKDAY.format(d).uppercase(Locale.FRENCH)
    }

    private fun showMessage(views: RemoteViews, text: String) {
        views.setViewVisibility(R.id.hero, View.GONE)
        views.setViewVisibility(R.id.next_label, View.GONE)
        views.setViewVisibility(R.id.widget_rows, View.GONE)
        views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
        views.setTextViewText(R.id.widget_empty, text)
    }

    private fun capitalize(s: String) = s.replaceFirstChar { it.titlecase(Locale.FRENCH) }

    private companion object {
        const val DATA_KEY = "week_json"
        const val ROW_DP = 21
        val DAY = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val HM = SimpleDateFormat("HH:mm", Locale.US)
        val DATE_LABEL = SimpleDateFormat("EEEE d MMMM", Locale.FRENCH)
        val WEEKDAY = SimpleDateFormat("EEEE", Locale.FRENCH)
    }
}
