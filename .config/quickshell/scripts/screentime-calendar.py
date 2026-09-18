#!/usr/bin/env python3
"""
screentime-calendar.py — Fetch and format Screen Time last month heatmap for Quickshell
"""

import sqlite3
import datetime
import json
import os
import sys

DB_PATH = os.path.expanduser("~/.local/share/screentime/screentime.db")

def fmt_dur(secs):
    if secs <= 0:
        return "0m"
    m = secs // 60
    if m < 60:
        return f"{m}m"
    h = m // 60
    rm = m % 60
    return f"{h}h {rm}m" if rm else f"{h}h"

def get_data():
    daily_rows = {}
    top_app_rows = []

    if os.path.exists(DB_PATH):
        try:
            conn = sqlite3.connect(DB_PATH)
            c = conn.cursor()
            daily_rows = dict(c.execute("SELECT day, sum(seconds) FROM app_time GROUP BY day").fetchall())
            top_app_rows = c.execute("SELECT app, sum(seconds) FROM app_time GROUP BY app ORDER BY sum(seconds) DESC LIMIT 5").fetchall()
            conn.close()
        except Exception:
            pass

    today = datetime.date.today()
    today_str = today.strftime("%Y-%m-%d")

    # Align to 5 weeks (35 days) ending with current week
    this_sunday = today - datetime.timedelta(days=(today.weekday() + 1) % 7)
    start_sunday = this_sunday - datetime.timedelta(weeks=4)

    weeks = []
    month_labels = []
    last_month = None
    cur = start_sunday
    month_secs = 0
    active_days_month = 0

    for w_idx in range(5):
        week_days = []
        for d_idx in range(7):
            ds = cur.strftime("%Y-%m-%d")
            secs = daily_rows.get(ds, 0)
            is_today = ds == today_str
            future = cur > today

            if not future:
                month_secs += secs
                if secs > 0:
                    active_days_month += 1

            if cur.day <= 7 and cur.strftime("%b") != last_month:
                month_labels.append({"name": cur.strftime("%b"), "col": w_idx})
                last_month = cur.strftime("%b")

            if secs == 0:
                lvl = 0
            elif secs < 3600:
                lvl = 1
            elif secs < 10800:
                lvl = 2
            elif secs < 21600:
                lvl = 3
            else:
                lvl = 4

            week_days.append({
                "date": ds,
                "dayNum": cur.day,
                "seconds": secs,
                "formatted": fmt_dur(secs),
                "level": lvl,
                "weekday": d_idx,
                "future": future,
                "isToday": is_today
            })
            cur += datetime.timedelta(days=1)
        weeks.append(week_days)

    avg_secs = month_secs // max(1, active_days_month) if active_days_month else 0
    today_secs = daily_rows.get(today_str, 0)

    # Streak
    all_dates_sorted = sorted(daily_rows.keys())
    curr_streak = 0
    check_day = today
    while True:
        ds = check_day.strftime("%Y-%m-%d")
        if daily_rows.get(ds, 0) > 0:
            curr_streak += 1
            check_day -= datetime.timedelta(days=1)
        elif check_day == today:
            check_day -= datetime.timedelta(days=1)
        else:
            break

    now_time = datetime.datetime.now().strftime("%H:%M:%S")

    out = {
        "monthSeconds": month_secs,
        "formattedMonth": fmt_dur(month_secs),
        "todaySeconds": today_secs,
        "formattedToday": fmt_dur(today_secs),
        "dailyAverage": fmt_dur(avg_secs),
        "currentStreak": curr_streak,
        "activeDays": active_days_month,
        "topApps": [{"app": a[0], "seconds": a[1], "formatted": fmt_dur(a[1])} for a in top_app_rows],
        "monthLabels": month_labels,
        "weeks": weeks,
        "lastUpdated": now_time
    }
    return out

if __name__ == "__main__":
    data = get_data()
    print(json.dumps(data))
