#!/usr/bin/env python3
"""Watch a Skagit CCE course-catalog category and file a RED heph task into
Erich's heph when a new ceramics class appears.

Stdlib only (urllib, json, re, subprocess, datetime). Designed to run as a
systemd user oneshot (packaged by nixos/ringtail/skagit-cce-watch.nix).

Identity: each listed class carries an "Item Number" (the canonical CCE class
id, what you'd quote when registering). That is the "class id" this watch is
keyed on. A class is *new* when its item number has not been seen before. The
course id (course.aspx?C=) and section id (moreInfoDiv_N) are recorded too, as
fallbacks / provenance.

Alert policy: a new class whose title matches the ceramics pattern files a red
task and fires a best-effort ntfy push (self-hosted ntfy.ops.eblu.me, topic
"ceramics") so it also reaches Erich's phone. A new class that is *not*
ceramics is recorded (so we never alert on it again) but files nothing — the
watch is specifically "look for a new ceramics class". First run establishes a
baseline and files nothing, so an already-listed course does not wake Erich.
An ntfy failure never fails the tick: the red heph task is the primary alert.
"""

import datetime
import json
import os
import re
import subprocess
import sys
import urllib.request
from urllib.parse import urlsplit

URL = os.environ.get(
    "SKAGIT_CCE_URL", "https://www.campusce.net/skagit/course/course.aspx?catId=47"
)
STATE_DIR = os.environ.get(
    "SKAGIT_CCE_STATE_DIR",
    os.path.join(os.path.expanduser("~"), ".local", "state", "skagit-cce-watch"),
)
STATE_FILE = os.path.join(STATE_DIR, "state.json")
PROJECT = os.environ.get("SKAGIT_CCE_PROJECT", "Ceramics")
HEPH = os.environ.get("SKAGIT_CCE_HEPH", "heph")
# Best-effort phone alert alongside the red task: a push to the self-hosted
# ntfy. Open today (no token); the token knob exists so enabling auth later is
# a config change, not a code change.
NTFY_URL = os.environ.get("SKAGIT_CCE_NTFY_URL", "https://ntfy.ops.eblu.me")
NTFY_TOPIC = os.environ.get("SKAGIT_CCE_NTFY_TOPIC", "ceramics")
NTFY_TOKEN = os.environ.get("SKAGIT_CCE_NTFY_TOKEN", "")
# A ceramics class under whatever name the college gives it. Extend as needed;
# the title is short free text, so a loose term net is fine (a near-miss alert
# is cheap, a missed ceramics class is the failure we are here to avoid).
CERAMICS = re.compile(
    r"\b(ceramic|ceramics|pottery|clay|wheel[\s-]?throwing|stoneware|"
    r"porcelain|bisque|kiln|hand[\s-]?building|earthenware)\b",
    re.I,
)
UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)
# One course panel: the <h3><a course.aspx?C=..>title</a> anchor, then a window
# after it holding the Item Number / section id. The window is generous but
# bounded so a later course's item number is never attributed to the wrong one.
COURSE_RE = re.compile(r"course\.aspx\?C=(\d+)&pc=(\d+)(?:&[a-z0-9=]+)*'>([^<]+)</a>")
ITEM_RE = re.compile(r"Item Number:</strong>\s*(\d+)")
SECTION_RE = re.compile(r"moreInfoDiv_(\d+)")
WINDOW = 4000


def log(msg):
    print(f"skagit-cce-watch: {msg}", flush=True)


def fetch(url):
    req = urllib.request.Request(
        url, headers={"User-Agent": UA, "Accept": "text/html,application/xhtml+xml"}
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def parse_courses(html):
    entries = []
    for m in COURSE_RE.finditer(html):
        course_id, pc, title = m.groups()
        window = html[m.end() : m.end() + WINDOW]
        im = ITEM_RE.search(window)
        sm = SECTION_RE.search(window)
        item_no = im.group(1) if im else None
        section_id = sm.group(1) if sm else None
        entries.append(
            {
                "key": item_no or course_id,  # item number = the class id
                "item_no": item_no,
                "course_id": course_id,
                "pc": pc,
                "section_id": section_id,
                "title": title.strip(),
            }
        )
    return entries


def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=2, sort_keys=True)
    os.replace(tmp, STATE_FILE)


def heph(*args):
    return subprocess.run([HEPH, *args], capture_output=True, text=True)


def ensure_project():
    r = heph("project", "list")
    names = set()
    for line in r.stdout.splitlines():
        parts = line.split(None, 1)
        if len(parts) == 2:
            names.add(parts[1].strip())
    if PROJECT in names:
        return
    r = heph("project", "add", PROJECT)
    if r.returncode != 0:
        log(f"warning: could not create project {PROJECT!r}: {r.stderr.strip()}")


def file_red_task(entry):
    now = datetime.date.today().isoformat()
    title = f"New ceramics class: {entry['title']} (item {entry['key']})"
    r = heph(
        "task",
        title,
        "--project",
        PROJECT,
        "--do-date",
        "today",
        "--attention",
        "red",
        "--json",
    )
    if r.returncode != 0:
        log(f"error: heph task failed for {entry['title']!r}: {r.stderr.strip()}")
        return
    try:
        node = json.loads(r.stdout).get("node_id")
    except (json.JSONDecodeError, AttributeError):
        node = None
    # Best-effort: drop the source link + provenance into the task's context
    # doc so the alert is actionable. A failure here must not fail the tick.
    detail = (
        f"source: {URL}\n"
        f"item number: {entry['key']}\n"
        f"course id: {entry['course_id']}"
        f"{', section ' + entry['section_id'] if entry['section_id'] else ''}\n"
        f"first seen: {now}"
    )
    if node:
        c = heph("context", node, "--append", detail)
        if c.returncode != 0:
            log(f"warning: could not append context to {node}: {c.stderr.strip()}")
    log(f"filed RED task node={node} title={title!r}")


def course_url(e):
    """The course page for an entry, on the same host and path as the
    watched catalog, so a tapped notification opens exactly that class."""
    p = urlsplit(URL)
    return f"{p.scheme}://{p.netloc}{p.path}?C={e['course_id']}&pc={e['pc']}"


def ntfy_push(e):
    """Best-effort phone alert for a new ceramics class, fired alongside the
    red heph task. Any failure is logged and swallowed: ntfy is a convenience,
    the red task is the primary alert, and a down ntfy must not fail the tick.
    """
    headers = {
        "X-Title": "New ceramics class",
        # 5 = maximum; this is a "look now" alert, not background noise.
        "X-Priority": "5",
        # Tapping the notification opens the course page.
        "X-Click": course_url(e),
    }
    if NTFY_TOKEN:
        headers["Authorization"] = f"Bearer {NTFY_TOKEN}"
    req = urllib.request.Request(
        f"{NTFY_URL.rstrip('/')}/{NTFY_TOPIC}",
        data=f"New ceramics class: {e['title']}  (item {e['key']})".encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            log(f"ntfy push sent (HTTP {r.status}) to {NTFY_URL}/{NTFY_TOPIC}")
    except Exception as exc:  # noqa: BLE001 - best-effort by design
        log(f"warning: ntfy push failed (red task still primary): {exc}")


def main():
    try:
        html = fetch(URL)
    except Exception as e:  # noqa: BLE001 - a fetch failure should fail the tick
        log(f"error: fetch failed for {URL}: {e}")
        return 1

    courses = parse_courses(html)
    if not courses:
        # A zero-course parse almost always means a page/parse regression, not an
        # empty catalog. Refuse to touch state so we do not wipe the baseline or
        # flood alerts on the next real fetch; fail the unit so it gets noticed.
        log("error: parsed 0 courses; page layout or parse changed? state untouched")
        return 1

    state = load_state()
    first_run = "known" not in state
    now_ms = int(datetime.datetime.now().timestamp() * 1000)
    known = state.get("known", {})

    if first_run:
        for c in courses:
            known[c["key"]] = {
                "title": c["title"],
                "first_seen": now_ms,
                "item_no": c["item_no"],
                "course_id": c["course_id"],
            }
        state["known"] = known
        save_state(state)
        log(f"baseline: recorded {len(courses)} class(es), no alerts on first run")
        for c in courses:
            log(f"  - item {c['key']}: {c['title']}")
        return 0

    new = [c for c in courses if c["key"] not in known]
    changed = [
        c
        for c in courses
        if c["key"] in known and known[c["key"]].get("title") != c["title"]
    ]

    for c in changed:
        known[c["key"]]["title"] = c["title"]
        known[c["key"]]["title_changed"] = now_ms

    for c in new:
        known[c["key"]] = {
            "title": c["title"],
            "first_seen": now_ms,
            "item_no": c["item_no"],
            "course_id": c["course_id"],
        }
        if CERAMICS.search(c["title"]):
            ensure_project()
            file_red_task(c)
            ntfy_push(c)
        else:
            log(
                f"new non-ceramics class recorded (no alert): "
                f"item {c['key']}: {c['title']}"
            )

    state["known"] = known
    save_state(state)
    log(
        f"updated: {len(courses)} listed, {len(new)} new "
        f"({sum(1 for c in new if CERAMICS.search(c['title']))} ceramics), "
        f"{len(changed)} title change(s)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
