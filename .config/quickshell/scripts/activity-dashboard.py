#!/usr/bin/env python3
"""
activity-dashboard.py — Unified 3-month (13 weeks) data provider for GitHub & Screen Time
"""

import subprocess
import json
import datetime
import sqlite3
import os
import sys
import shutil
import glob

def get_cache_file():
    cache_dir = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    try:
        os.makedirs(cache_dir, exist_ok=True)
        return os.path.join(cache_dir, "activity_dashboard.json")
    except Exception:
        return f"/tmp/activity_dashboard_{os.getuid()}.json"

CACHE_FILE = get_cache_file()
CACHE_AGE = 300  # 5 minutes
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

def get_enhanced_env():
    """
    Ensure PATH contains common binary locations where gh or mise shims might reside,
    especially when Quickshell runs with a stripped environment PATH.
    """
    env = os.environ.copy()
    cur_path = env.get("PATH", "")
    user = os.environ.get("USER") or os.environ.get("LOGNAME") or "user"
    extra_dirs = [
        os.path.expanduser("~/.local/bin"),
        os.path.expanduser("~/.local/share/mise/shims"),
        os.path.expanduser("~/.nix-profile/bin"),
        f"/etc/profiles/per-user/{user}/bin",
        "/opt/homebrew/bin",
        "/home/linuxbrew/.linuxbrew/bin",
        os.path.expanduser("~/.asdf/shims"),
        os.path.expanduser("~/.cargo/bin"),
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
    ]
    paths = [p for p in cur_path.split(os.pathsep) if p]
    for d in extra_dirs:
        if os.path.isdir(d) and d not in paths:
            paths.append(d)
    env["PATH"] = os.pathsep.join(paths)
    return env

def find_gh_binary(env=None):
    """
    Dynamically locate the gh binary using shutil.which("gh") plus common fallback paths.
    """
    if env is None:
        env = get_enhanced_env()

    # 1. Check standard & enhanced PATH
    gh_bin = shutil.which("gh", path=env.get("PATH"))
    if gh_bin and os.path.isfile(gh_bin) and os.access(gh_bin, os.X_OK):
        return gh_bin

    # 2. Common fallback candidate locations
    candidates = [
        "/usr/bin/gh",
        "/usr/local/bin/gh",
        os.path.expanduser("~/.local/bin/gh"),
        os.path.expanduser("~/.local/share/mise/shims/gh"),
        os.path.expanduser("~/.nix-profile/bin/gh"),
        "/opt/homebrew/bin/gh",
        "/home/linuxbrew/.linuxbrew/bin/gh",
    ]

    # 3. Dynamic search in mise/asdf versioned installs if present
    for tool_name in ["gh", "github-cli"]:
        for base_dir in [
            os.path.expanduser(f"~/.local/share/mise/installs/{tool_name}"),
            os.path.expanduser(f"~/.asdf/installs/{tool_name}"),
        ]:
            if os.path.isdir(base_dir):
                for match in glob.glob(os.path.join(base_dir, "**/bin/gh"), recursive=True):
                    candidates.append(match)
                for match in glob.glob(os.path.join(base_dir, "**/gh"), recursive=True):
                    candidates.append(match)

    for p in candidates:
        if os.path.isfile(p) and os.access(p, os.X_OK):
            bin_dir = os.path.dirname(p)
            cur_paths = env.get("PATH", "").split(os.pathsep)
            if bin_dir not in cur_paths:
                env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "")
            return p

    return None

def get_fallback_username(env=None):
    """
    Retrieve user from git config user.name or os.environ.get("USER") or empty string.
    Never returns a hardcoded dummy user.
    """
    if env is None:
        env = get_enhanced_env()
    try:
        res = subprocess.run(
            ["git", "config", "user.name"],
            capture_output=True,
            text=True,
            timeout=2,
            env=env
        )
        if res.returncode == 0:
            name = res.stdout.strip()
            if name:
                return name
    except Exception:
        pass

    return os.environ.get("USER") or os.environ.get("LOGNAME") or ""

def generate_empty_weeks():
    today = datetime.date.today()
    this_sunday = today - datetime.timedelta(days=(today.weekday() + 1) % 7)
    start_sunday = this_sunday - datetime.timedelta(weeks=12)
    empty_weeks = []
    cur = start_sunday
    month_labels = []
    last_month = None
    for w_idx in range(13):
        week = []
        for d_idx in range(7):
            if cur.day <= 7 and cur.strftime("%b") != last_month:
                month_labels.append({"name": cur.strftime("%b"), "col": w_idx})
                last_month = cur.strftime("%b")
            week.append({
                "date": cur.strftime("%Y-%m-%d"),
                "dayNum": cur.day,
                "count": 0,
                "level": 0,
                "weekday": d_idx,
                "isToday": cur.strftime("%Y-%m-%d") == today.strftime("%Y-%m-%d")
            })
            cur += datetime.timedelta(days=1)
        empty_weeks.append(week)
    return empty_weeks, month_labels

def build_github_fallback(status, status_message, username=None):
    if username is None:
        username = get_fallback_username()
    empty_weeks, month_labels = generate_empty_weeks()
    return {
        "status": status,
        "statusMessage": status_message,
        "username": username,
        "totalCount": 0,
        "todayCount": 0,
        "currentStreak": 0,
        "longestStreak": 0,
        "monthLabels": month_labels,
        "weeks": empty_weeks
    }

def get_github_data():
    env = get_enhanced_env()
    gh_bin = find_gh_binary(env)

    if not gh_bin:
        return build_github_fallback("not_installed", "GitHub CLI ('gh') not found")

    query = """
    query {
      viewer {
        login
        contributionsCollection {
          contributionCalendar {
            totalContributions
            weeks {
              firstDay
              contributionDays {
                date
                contributionCount
                weekday
              }
            }
          }
        }
      }
    }
    """
    try:
        res = subprocess.run(
            [gh_bin, "api", "graphql", "-f", f"query={query}"],
            capture_output=True,
            text=True,
            timeout=12,
            env=env
        )
    except subprocess.TimeoutExpired:
        return build_github_fallback("error", "GitHub API request timed out")
    except Exception as e:
        return build_github_fallback("error", f"Failed to execute gh: {e}")

    # Inspect returncode and outputs for authentication errors
    combined_err = f"{res.stderr}\n{res.stdout}".lower()
    if res.returncode != 0:
        is_auth_error = (
            "gh auth login" in combined_err
            or "bad credentials" in combined_err
            or "401" in res.stderr
            or "401" in combined_err
            or "authentication failed" in combined_err
            or "credentials expired" in combined_err
            or "not logged into" in combined_err
            or "token is expired" in combined_err
            or "oauth token" in combined_err
            or "saml" in combined_err
            or "sso" in combined_err
            or "unauthorized" in combined_err
            or res.returncode == 4
        )
        if is_auth_error:
            return build_github_fallback("auth_required", "GitHub CLI login required (run: gh auth login)")
        else:
            err_msg = res.stderr.strip() or "GitHub API request failed"
            if len(err_msg) > 80:
                err_msg = err_msg[:77] + "..."
            return build_github_fallback("error", err_msg)

    try:
        data = json.loads(res.stdout)
    except Exception:
        return build_github_fallback("error", "Invalid JSON from GitHub CLI")

    if "errors" in data:
        err_str = json.dumps(data["errors"]).lower()
        if any(k in err_str for k in ["credentials", "auth", "token", "unauthorized", "saml", "sso", "forbidden", "permission"]):
            return build_github_fallback("auth_required", "GitHub CLI login required (run: gh auth login)")
        if not data.get("data") or not data.get("data", {}).get("viewer"):
            first_msg = "GitHub GraphQL error"
            try:
                first_msg = data["errors"][0].get("message", first_msg)
            except Exception:
                pass
            return build_github_fallback("error", first_msg)

    try:
        viewer = data.get("data", {}).get("viewer")
        if not viewer:
            return build_github_fallback("auth_required", "GitHub CLI login required (run: gh auth login)")
        user = viewer.get("login")
        if not user:
            return build_github_fallback("auth_required", "GitHub CLI login required (run: gh auth login)")
        cal = viewer["contributionsCollection"]["contributionCalendar"]
        all_weeks = cal.get("weeks", [])
    except (KeyError, TypeError, AttributeError):
        return build_github_fallback("error", "Unexpected response structure from GitHub")

    # Map all dates from GitHub's full calendar
    date_to_count = {}
    for w in all_weeks:
        for d in w.get("contributionDays", []):
            date_to_count[d["date"]] = d.get("contributionCount", 0)

    # Days list for streak calculation
    days_all = [d for w in all_weeks for d in w.get("contributionDays", [])]

    today = datetime.date.today()
    today_str = today.strftime("%Y-%m-%d")
    today_cnt = date_to_count.get(today_str, 0)

    # Streak calculation
    curr_streak = 0
    max_streak = 0
    streak = 0
    for d in days_all:
        cnt = d.get("contributionCount", 0)
        if cnt > 0:
            streak += 1
            if streak > max_streak:
                max_streak = streak
        else:
            streak = 0

    for d in reversed(days_all):
        if d["date"] > today_str:
            continue
        if d.get("contributionCount", 0) > 0:
            curr_streak += 1
        elif curr_streak > 0:
            break
        elif d["date"] == today_str:
            continue
        else:
            break

    # Build 13 weeks ending with current week Sunday-Saturday
    this_sunday = today - datetime.timedelta(days=(today.weekday() + 1) % 7)
    start_sunday = this_sunday - datetime.timedelta(weeks=12)

    counts_3m = []
    temp_cur = start_sunday
    for _ in range(13 * 7):
        ds = temp_cur.strftime("%Y-%m-%d")
        c = date_to_count.get(ds, 0)
        if c > 0:
            counts_3m.append(c)
        temp_cur += datetime.timedelta(days=1)
    max_c = max(counts_3m) if counts_3m else 1

    total_3m = 0
    processed_weeks = []
    month_labels = []
    last_month = None
    cur = start_sunday

    for w_idx in range(13):
        week_days = []
        for d_idx in range(7):
            ds = cur.strftime("%Y-%m-%d")
            cnt = date_to_count.get(ds, 0)
            is_future = cur > today
            if not is_future:
                total_3m += cnt

            if cur.day <= 7 and cur.strftime("%b") != last_month:
                month_labels.append({"name": cur.strftime("%b"), "col": w_idx})
                last_month = cur.strftime("%b")

            if cnt == 0:
                lvl = 0
            elif cnt <= max(1, max_c * 0.25):
                lvl = 1
            elif cnt <= max(2, max_c * 0.50):
                lvl = 2
            elif cnt <= max(3, max_c * 0.75):
                lvl = 3
            else:
                lvl = 4

            week_days.append({
                "date": ds,
                "dayNum": cur.day,
                "count": cnt,
                "level": lvl,
                "weekday": d_idx,
                "isToday": ds == today_str
            })
            cur += datetime.timedelta(days=1)
        processed_weeks.append(week_days)

    return {
        "status": "ok",
        "statusMessage": "Connected",
        "username": user,
        "totalCount": total_3m,
        "todayCount": today_cnt,
        "currentStreak": curr_streak,
        "longestStreak": max_streak,
        "monthLabels": month_labels,
        "weeks": processed_weeks
    }

def get_screentime_data():
    daily_rows = {}
    top_app_rows = []

    if os.path.exists(DB_PATH):
        try:
            conn = sqlite3.connect(DB_PATH)
            c = conn.cursor()
            daily_rows = dict(c.execute("SELECT day, sum(seconds) FROM app_time GROUP BY day").fetchall())
            top_app_rows = c.execute("SELECT app, sum(seconds) FROM app_time GROUP BY app ORDER BY sum(seconds) DESC LIMIT 4").fetchall()
            conn.close()
        except Exception:
            pass

    today = datetime.date.today()
    today_str = today.strftime("%Y-%m-%d")

    # 13 weeks ending with current week
    this_sunday = today - datetime.timedelta(days=(today.weekday() + 1) % 7)
    start_sunday = this_sunday - datetime.timedelta(weeks=12)

    weeks = []
    month_labels = []
    last_month = None
    cur = start_sunday
    total_secs_3m = 0
    active_days_3m = 0

    for w_idx in range(13):
        week_days = []
        for d_idx in range(7):
            ds = cur.strftime("%Y-%m-%d")
            secs = daily_rows.get(ds, 0)
            is_today = ds == today_str
            future = cur > today

            if not future:
                total_secs_3m += secs
                if secs > 0:
                    active_days_3m += 1

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

    avg_secs = total_secs_3m // max(1, active_days_3m) if active_days_3m else 0
    today_secs = daily_rows.get(today_str, 0)

    # Current streak
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

    return {
        "totalFormatted": fmt_dur(total_secs_3m),
        "todayFormatted": fmt_dur(today_secs),
        "dailyAvgFormatted": fmt_dur(avg_secs),
        "currentStreak": curr_streak,
        "activeDays": active_days_3m,
        "topApps": [{"app": a[0], "formatted": fmt_dur(a[1])} for a in top_app_rows],
        "monthLabels": month_labels,
        "weeks": weeks
    }

def is_cache_stale(cache_file):
    if not os.path.exists(cache_file):
        return True
    try:
        cache_mtime = os.path.getmtime(cache_file)
        if (datetime.datetime.now().timestamp() - cache_mtime) >= CACHE_AGE:
            return True
        # Invalidate cache immediately if gh hosts/auth modified
        gh_config_dir = os.environ.get("GH_CONFIG_DIR") or os.path.expanduser("~/.config/gh")
        hosts_file = os.path.join(gh_config_dir, "hosts.yml")
        if os.path.exists(hosts_file) and os.path.getmtime(hosts_file) > cache_mtime:
            return True
    except Exception:
        pass
    return False

def main(force=False):
    if not force and not is_cache_stale(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                cached_data = json.load(f)
                if cached_data.get("github", {}).get("status") == "ok":
                    print(json.dumps(cached_data))
                    return
        except Exception:
            pass

    gh = get_github_data()
    st = get_screentime_data()

    # If GitHub fetch had a transient network error, fall back to valid cached github data
    if gh.get("status") == "error" and os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                old = json.load(f)
                old_gh = old.get("github")
                if old_gh and old_gh.get("status") == "ok":
                    gh = old_gh
        except Exception:
            pass

    now_time = datetime.datetime.now().strftime("%H:%M:%S")

    out = {
        "lastUpdated": now_time,
        "github": gh,
        "screentime": st
    }

    if gh.get("status") == "ok":
        try:
            with open(CACHE_FILE, "w") as f:
                json.dump(out, f)
        except Exception:
            pass
    elif gh.get("status") in ("auth_required", "not_installed"):
        # Purge stale cache so UI doesn't show old session or dummy user
        try:
            if os.path.exists(CACHE_FILE):
                os.remove(CACHE_FILE)
        except Exception:
            pass

    print(json.dumps(out))

if __name__ == "__main__":
    force = "--refresh" in sys.argv
    main(force=force)
