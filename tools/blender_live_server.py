"""Job server inside a visible Blender window opened by tools/blender_live.sh.

Polls <jobdir>/inbox for <id>.py every 0.25 s, runs each in the window's main
thread (so the agent's build shows up live in the viewport), writes the output
to <jobdir>/outbox/<id>.log and then <id>.done. Globals persist between jobs.
<jobdir> comes from the BLENDER_LIVE_DIR environment variable or the argument
after "--".
"""
import io
import os
import sys
import traceback
import contextlib

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
JOBDIR = argv[0] if argv else os.environ["BLENDER_LIVE_DIR"]
INBOX = os.path.join(JOBDIR, "inbox")
OUTBOX = os.path.join(JOBDIR, "outbox")
os.makedirs(INBOX, exist_ok=True)
os.makedirs(OUTBOX, exist_ok=True)
SESSION = {"__name__": "__main__"}


def _redraw():
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            area.tag_redraw()


def _poll():
    try:
        jobs = sorted(f for f in os.listdir(INBOX) if f.endswith(".py"))
    except OSError:
        return 0.5
    for name in jobs:
        path = os.path.join(INBOX, name)
        job = name[:-3]
        buf = io.StringIO()
        try:
            src = open(path, encoding="utf-8").read()
        except OSError:
            continue
        os.remove(path)
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            try:
                exec(compile(src, f"<job {job}>", "exec"), SESSION)
            except SystemExit:
                pass
            except BaseException:
                traceback.print_exc()
                print("BLENDER_RUN_FAILED")
        with open(os.path.join(OUTBOX, job + ".log"), "w", encoding="utf-8") as f:
            f.write(buf.getvalue())
        open(os.path.join(OUTBOX, job + ".done"), "w").close()
        _redraw()
        return 0.05
    return 0.25


bpy.app.timers.register(_poll, first_interval=1.0, persistent=True)
open(os.path.join(JOBDIR, "ready"), "w").close()
