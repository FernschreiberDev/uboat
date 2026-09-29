"""Visual check of the ported submarine: a few editor screenshots, then the editor quits.
Nothing is saved. Images go to Saved/PortCheck. Launch the editor with
  -ExecCmds="py <this file>"
(-ExecutePythonScript would close the editor as soon as this file has run). The script switches
off the editor's background throttling for the session; otherwise the editor renders a few frames
per second when it is not in front and the screenshots stall. An -ini override of that setting on
the command line is not enough.
The ocean is hidden temporarily for the close-ups, since the bow tubes sit below the waterline.
World frame of the scene: bow towards -Y, keel down, waterline at Z = 0 (model y = 1.9 m).
"""
from pathlib import Path
import time
import unreal as u

OUT = Path(u.Paths.project_dir()).resolve() / 'Saved' / 'PortCheck'
OUT.mkdir(parents=True, exist_ok=True)
editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
level = u.get_editor_subsystem(u.LevelEditorSubsystem)
actors = u.get_editor_subsystem(u.EditorActorSubsystem)

def look(eye, target):
    d = u.Vector(target[0] - eye[0], target[1] - eye[1], target[2] - eye[2])
    editor.set_level_viewport_camera_info(u.Vector(*eye), u.MathLibrary.make_rot_from_x(d))

# (name, camera, target, hide the ocean)
VIEWS = [
    ('ensemble', (-5500, -7000, 1250), (0, 0, 150), False),
    ('proue-tribord', (1900, -4700, 60), (0, -3050, -110), True),
    ('proue-babord', (-1900, -4700, 60), (0, -3050, -110), True),
    ('proue-face', (0, -5600, 20), (0, -3100, -60), True),
    ('massif', (1500, 800, 1050), (0, -100, 400), False),
    ('poupe', (-1500, 4600, -200), (0, 2950, -260), True),
]
oceans = [a for a in actors.get_all_level_actors() if isinstance(a, (u.WaterBodyOcean, u.WaterZone))]
start = time.monotonic()
state = {'step': 0, 'next': 75.0, 'phase': 'wait', 'task': None, 'placed': False, 'deadline': 0.0, 'busy': False}
handle = None

def place(view):
    name, eye, target, hide = view
    for ocean in oceans:
        ocean.set_is_temporarily_hidden_in_editor(hide)
    level.editor_set_game_view(True)
    level.editor_set_viewport_realtime(True)
    look(eye, target)

def finish():
    for ocean in oceans:
        ocean.set_is_temporarily_hidden_in_editor(False)
    u.unregister_slate_post_tick_callback(handle)
    u.log('PORT_CAPTURE_DONE')
    u.SystemLibrary.quit_editor()

def tick(delta):
    # Screenshot requests can pump Slate and re-enter this callback.
    if state['busy']:
        return
    state['busy'] = True
    try:
        level.editor_invalidate_viewports()
        now = time.monotonic() - start
        if state['step'] >= len(VIEWS):
            if now >= state['next']:
                finish()
            return
        view = VIEWS[state['step']]
        if state['phase'] == 'wait':
            if now < state['next']:
                return
            if not state['placed']:
                place(view)
                state['placed'] = True
                state['next'] = now + 8
                return
            path = str(OUT / ('unreal-' + view[0] + '.png'))
            state['task'] = u.AutomationLibrary.take_high_res_screenshot(1600, 900, path)
            state['phase'] = 'shoot'
            state['deadline'] = now + 40
            u.log('PORT_CAPTURE_REQUESTED: ' + path)
            return
        task = state['task']
        done = task is None or task.is_task_done()
        if done or now > state['deadline']:
            u.log(('PORT_CAPTURE: ' if done else 'PORT_CAPTURE_TIMEOUT: ') + view[0])
            state.update(step=state['step'] + 1, phase='wait', task=None, placed=False, next=now + 2)
            if state['step'] >= len(VIEWS):
                state['next'] = now + 6
    finally:
        state['busy'] = False

# Session only, never written to the settings files.
try:
    settings = u.get_default_object(u.load_class(None, '/Script/UnrealEd.EditorPerformanceSettings'))
    settings.set_editor_property('bThrottleCPUWhenNotForeground', False)
    u.log('PORT_CAPTURE_THROTTLE_OFF')
except Exception as error:
    u.log('PORT_CAPTURE_THROTTLE_UNCHANGED: ' + str(error))
handle = u.register_slate_post_tick_callback(tick)
u.log('PORT_CAPTURE_STARTED')
