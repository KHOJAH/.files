#!/usr/bin/env python3
"""
github-contributions.py — Fetch and format GitHub last month contribution calendar for Quickshell
"""

import subprocess
import json
import datetime
import os
import sys
import shutil
import glob

def get_cache_file():
    cache_dir = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    try:
        os.makedirs(cache_dir, exist_ok=True)
        return os.path.join(cache_dir, "github_contributions.json")
    except Exception:
        return f"/tmp/github_contributions_{os.getuid()}.json"

CACHE_FILE = get_cache_file()
CACHE_AGE = 300  # 5 minutes cache

def get_enhanced_env():
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
    if env is None:
        env = get_enhanced_env()
    gh_bin = shutil.which("gh", path=env.get("PATH"))
    if gh_bin and os.path.isfile(gh_bin) and os.access(gh_bin, os.X_OK):
        return gh_bin
    candidates = [
        "/usr/bin/gh",
        "/usr/local/bin/gh",
        os.path.expanduser("~/.local/bin/gh"),
        os.path.expanduser("~/.local/share/mise/shims/gh"),
        os.path.expanduser("~/.nix-profile/bin/gh"),
        "/opt/homebrew/bin/gh",
        "/home/linuxbrew/.linuxbrew/bin/gh",
    ]
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

def get_fallback_username():
    try:
        res = subprocess.run(
            ["git", "config", "user.name"],
            capture_output=True,
            text=True,
            timeout=2
        )
        if res.returncode == 0:
            name = res.stdout.strip()
            if name:
                return name
    except Exception:
        pass
    return os.environ.get("USER") or os.environ.get("LOGNAME") or ""

def get_data(force=False):
    if not force and os.path.exists(CACHE_FILE):
        try:
            if (datetime.datetime.now().timestamp() - os.path.getmtime(CACHE_FILE)) < CACHE_AGE:
                with open(CACHE_FILE, "r") as f:
                    return json.load(f)
        except Exception:
            pass

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
    env = get_enhanced_env()
    gh_bin = find_gh_binary(env)
    if not gh_bin:
        return generate_empty_calendar()

    try:
        res = subprocess.run(
            [gh_bin, "api", "graphql", "-f", f"query={query}"],
            capture_output=True,
            text=True,
            timeout=10,
            env=env
        )
        if res.returncode != 0:
            raise RuntimeError(res.stderr)
        data = json.loads(res.stdout)
        cal = data["data"]["viewer"]["contributionsCollection"]["contributionCalendar"]
        user = data["data"]["viewer"]["login"]
    except Exception as e:
        if os.path.exists(CACHE_FILE):
            with open(CACHE_FILE, "r") as f:
                return json.load(f)
        return generate_empty_calendar()

    all_weeks = cal["weeks"]
    weeks_5 = all_weeks[-5:] if len(all_weeks) >= 5 else all_weeks
    
    days_all = [d for w in all_weeks for d in w["contributionDays"]]
    days_month = [d for w in weeks_5 for d in w["contributionDays"]]

    month_total = sum(d["contributionCount"] for d in days_month)
    year_total = cal["totalContributions"]
    today = datetime.date.today()
    today_str = today.strftime("%Y-%m-%d")
    today_cnt = next((d["contributionCount"] for d in days_month if d["date"] == today_str), 0)

    # Current streak from full history
    curr_streak = 0
    max_streak = 0
    streak = 0
    for d in days_all:
        if d["contributionCount"] > 0:
            streak += 1
            if streak > max_streak:
                max_streak = streak
        else:
            streak = 0

    for d in reversed(days_all):
        if d["date"] > today_str:
            continue
        if d["contributionCount"] > 0:
            curr_streak += 1
        elif curr_streak > 0:
            break
        elif d["date"] == today_str:
            continue
        else:
            break

    # Max count in the month for level scaling
    counts = [d["contributionCount"] for d in days_month if d["contributionCount"] > 0]
    max_c = max(counts) if counts else 1

    processed_weeks = []
    month_labels = []
    last_month = None

    for w_idx, w in enumerate(weeks_5):
        week_days = []
        for d in w["contributionDays"]:
            dt = datetime.datetime.strptime(d["date"], "%Y-%m-%d").date()
            if dt.day <= 7 and dt.strftime("%b") != last_month:
                month_labels.append({"name": dt.strftime("%b"), "col": w_idx})
                last_month = dt.strftime("%b")

            cnt = d["contributionCount"]
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
                "date": d["date"],
                "dayNum": dt.day,
                "count": cnt,
                "level": lvl,
                "weekday": d["weekday"],
                "isToday": d["date"] == today_str
            })
        processed_weeks.append(week_days)

    now_time = datetime.datetime.now().strftime("%H:%M:%S")

    out = {
        "username": user,
        "monthContributions": month_total,
        "yearContributions": year_total,
        "todayContributions": today_cnt,
        "currentStreak": curr_streak,
        "longestStreak": max_streak,
        "monthLabels": month_labels,
        "weeks": processed_weeks,
        "lastUpdated": now_time
    }

    try:
        with open(CACHE_FILE, "w") as f:
            json.dump(out, f)
    except Exception:
        pass

    return out

def generate_empty_calendar():
    today = datetime.date.today()
    this_sunday = today - datetime.timedelta(days=(today.weekday() + 1) % 7)
    start_sunday = this_sunday - datetime.timedelta(weeks=4)
    weeks = []
    cur = start_sunday
    month_labels = []
    last_month = None
    today_str = today.strftime("%Y-%m-%d")

    for w_idx in range(5):
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
                "isToday": cur.strftime("%Y-%m-%d") == today_str
            })
            cur += datetime.timedelta(days=1)
        weeks.append(week)

    return {
        "username": get_fallback_username(),
        "monthContributions": 0,
        "yearContributions": 0,
        "todayContributions": 0,
        "currentStreak": 0,
        "longestStreak": 0,
        "monthLabels": month_labels,
        "weeks": weeks,
        "lastUpdated": datetime.datetime.now().strftime("%H:%M:%S")
    }

if __name__ == "__main__":
    force = "--refresh" in sys.argv
    data = get_data(force=force)
    print(json.dumps(data))
