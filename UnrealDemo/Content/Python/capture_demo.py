"""Editor startup audit and delayed screenshot; keeps the editor open."""
from pathlib import Path
import time
import unreal as u
for actor in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
    u.log('DEMO_ACTOR: '+actor.get_actor_label()+' '+str(actor.get_actor_bounds(False)))
start = time.monotonic()
handle = None

def capture(delta):
    global handle
    if time.monotonic() - start < 35:
        return
    u.unregister_slate_post_tick_callback(handle)
    u.AutomationLibrary.take_high_res_screenshot(1600,900,'Atlantic-demo.png')
    u.log('DEMO_SCREENSHOT_REQUESTED')
handle = u.register_slate_post_tick_callback(capture)
