"""Local editor automation for this demo only; no network listener."""
from pathlib import Path
import runpy
import time
import traceback
import unreal as u
root = Path(u.Paths.project_dir()).resolve()
request = root / 'Saved' / 'editor-request.txt'
last = request.stat().st_mtime_ns if request.exists() else 0
last_check = 0

def process(delta):
    global last, last_check
    if time.monotonic() - last_check < 1:
        return
    last_check = time.monotonic()
    if not request.exists() or request.stat().st_mtime_ns == last:
        return
    last = request.stat().st_mtime_ns
    name = request.read_text().strip()
    if '/' in name or '\\' in name or not name.endswith('.py'):
        u.log_error('DEMO_REQUEST_INVALID')
        return
    try:
        runpy.run_path(str(root / 'Content' / 'Python' / name),run_name='__demo__')
        u.log('DEMO_REQUEST_COMPLETE: '+name)
    except Exception:
        u.log_error(traceback.format_exc())
handle = u.register_slate_post_tick_callback(process)
u.log('DEMO_SESSION_READY')
