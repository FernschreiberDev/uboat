import unreal as u
from pathlib import Path
import time, json, statistics
samples=[]
start=time.monotonic()
previous=None
handle=None

def sample(delta):
    global previous,handle
    now=time.monotonic()
    if now-start<5:
        return
    if previous is not None:
        samples.append(now-previous)
    previous=now
    if now-start>=20:
        u.unregister_slate_post_tick_callback(handle)
        result={'scope':'Unreal editor Slate tick, includes editor overhead; not a standalone game benchmark',
                'samples':len(samples),'mean_fps':len(samples)/sum(samples),
                'p95_frame_ms':sorted(samples)[int(len(samples)*0.95)]*1000}
        path=Path(u.Paths.project_dir())/'Docs'/'editor-performance.json'
        path.write_text(json.dumps(result,indent=2))
        u.log('DEMO_MEASURED: '+str(result))
handle=u.register_slate_post_tick_callback(sample)
