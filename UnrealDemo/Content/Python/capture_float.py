"""Check that the VIIC floats: Simulate in Editor for a while, record the boat's motion and take a
series of screenshots, then quit without saving anything. Output in Saved/FloatCheck: motion.csv
(simulation time, position, roll, pitch, yaw, mean water height at the pontoons), frames.csv and
frame-NN.png. Launch the editor with -ExecCmds="py <this file>", as for capture_port.py, and let
the script stop the simulation: an editor killed while simulating crashes on the way out.
"""
from pathlib import Path
import math
import time
import unreal as u

OUT = Path(u.Paths.project_dir()).resolve() / 'Saved' / 'FloatCheck'
OUT.mkdir(parents=True, exist_ok=True)
WARMUP = 75.0          # editor start-up, shaders, ocean
SETTLE = 10.0          # first seconds of simulation, left out of the statistics
RECORD = 90.0
FRAME_START, FRAME_STEP, FRAME_COUNT = 20.0, 0.4, 36
# Three-quarter view from the port bow, just above the sea.
EYE, TARGET = (-1300, -4200, 330), (0, -700, 80)
REST_Z = -190.0

editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
level = u.get_editor_subsystem(u.LevelEditorSubsystem)
state = {'phase': 'warmup', 'busy': False, 'sim_start': 0.0, 'boat': None, 'task': None, 'frame': 0,
         'next_frame': FRAME_START, 'end': 0.0}
samples, frames = [], []
start = time.monotonic()
handle = None


def log(text):
    u.log('FLOAT_CHECK: ' + text)


def describe_editor_boat():
    actors = u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
    boat = next(a for a in actors if a.get_actor_label().startswith('VIIC'))
    comp = boat.static_mesh_component
    body = comp.get_editor_property('body_instance')
    log('editor boat rot=%s mobility=%s simulate=%s mass=%.0f profile=%s' % (
        boat.get_actor_rotation(), comp.mobility, body.get_editor_property('simulate_physics'),
        body.get_editor_property('mass_in_kg_override'), comp.get_collision_profile_name()))
    for buoyancy in boat.get_components_by_class(u.BuoyancyComponent):
        data = buoyancy.get_editor_property('buoyancy_data')
        log('editor buoyancy %s class=%s pontoons=%d coefficient=%.4f' % (
            buoyancy.get_name(), buoyancy.get_class().get_name(), len(data.get_editor_property('pontoons')),
            data.get_editor_property('buoyancy_coefficient')))


def find_boat(world):
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.StaticMeshActor):
        if actor.get_actor_label().startswith('VIIC'):
            return actor
    return None


def record(world, boat):
    t = u.GameplayStatics.get_time_seconds(world) - state['sim_start']
    loc, rot = boat.get_actor_location(), boat.get_actor_rotation()
    buoyancy = boat.get_component_by_class(u.BuoyancyComponent)
    water = float('nan')
    in_water = False
    if buoyancy:
        in_water = buoyancy.is_in_water_body()
        heights = [p.get_editor_property('water_height') for p in buoyancy.get_editor_property('buoyancy_data').get_editor_property('pontoons')]
        water = sum(heights) / len(heights) if heights else water
    samples.append((t, loc.x, loc.y, loc.z, rot.roll, rot.pitch, rot.yaw, water, int(in_water)))
    return t


def summary():
    with open(OUT / 'motion.csv', 'w') as f:
        f.write('t,x,y,z,roll,pitch,yaw,water,in_water\n')
        for row in samples:
            f.write(','.join('%.4f' % v for v in row) + '\n')
    with open(OUT / 'frames.csv', 'w') as f:
        f.write('frame,t\n')
        for index, t in frames:
            f.write('%d,%.4f\n' % (index, t))
    kept = [s for s in samples if s[0] >= SETTLE]
    if not kept:
        log('NO SAMPLES')
        return

    def stats(name, values):
        mean = sum(values) / len(values)
        std = math.sqrt(sum((v - mean) ** 2 for v in values) / len(values))
        log('%s mean=%.2f std=%.2f min=%.2f max=%.2f' % (name, mean, std, min(values), max(values)))

    log('samples=%d over %.1f s, in water %.0f%%' % (len(kept), kept[-1][0] - kept[0][0], 100.0 * sum(s[8] for s in kept) / len(kept)))
    stats('heave_cm', [s[3] - REST_Z for s in kept])
    stats('roll_deg', [s[4] for s in kept])
    stats('pitch_deg', [s[5] for s in kept])
    stats('yaw_deg', [s[6] for s in kept])
    stats('drift_cm', [math.hypot(s[1] - kept[0][1], s[2] - kept[0][2]) for s in kept])
    stats('water_at_pontoons_cm', [s[7] for s in kept if not math.isnan(s[7])])


def tick(delta):
    if state['busy']:
        return
    state['busy'] = True
    try:
        level.editor_invalidate_viewports()
        now = time.monotonic() - start
        phase = state['phase']
        if phase == 'warmup':
            if now < WARMUP:
                return
            describe_editor_boat()
            # Simulate turns the viewport real-time by itself.
            level.editor_set_game_view(True)
            d = u.Vector(TARGET[0] - EYE[0], TARGET[1] - EYE[1], TARGET[2] - EYE[2])
            editor.set_level_viewport_camera_info(u.Vector(*EYE), u.MathLibrary.make_rot_from_x(d))
            level.editor_play_simulate()
            state.update(phase='starting', end=now + 30)
            log('SIMULATE_REQUESTED')
            return
        if phase == 'starting':
            world = editor.get_game_world()
            boat = find_boat(world) if world else None
            if boat is None:
                if now > state['end']:
                    log('SIMULATE_FAILED')
                    state.update(phase='done', end=now)
                return
            state.update(phase='sim', boat=boat, sim_start=u.GameplayStatics.get_time_seconds(world))
            log('SIMULATE_STARTED')
            return
        if phase == 'sim':
            world = editor.get_game_world()
            if world is None:
                log('SIMULATE_STOPPED_EARLY')
                state.update(phase='done', end=now)
                return
            t = record(world, state['boat'])
            if t >= state.setdefault('next_log', 0.0):
                row = samples[-1]
                log('t=%.1f s heave=%.0f cm roll=%.2f pitch=%.2f yaw=%.2f in_water=%d' % (
                    t, row[3] - REST_Z, row[4], row[5], row[6], row[8]))
                state['next_log'] = t + 10.0
            task = state['task']
            if task is not None and task.is_task_done():
                state['task'] = None
            if state['task'] is None and state['frame'] < FRAME_COUNT and t >= state['next_frame']:
                path = str(OUT / ('frame-%02d.png' % state['frame']))
                state['task'] = u.AutomationLibrary.take_high_res_screenshot(1280, 720, path)
                frames.append((state['frame'], t))
                state['frame'] += 1
                state['next_frame'] += FRAME_STEP
            if t >= SETTLE + RECORD and state['frame'] >= FRAME_COUNT and state['task'] is None:
                level.editor_request_end_play()
                state.update(phase='stopping', end=now + 5)
            return
        if phase == 'stopping' and now >= state['end']:
            state.update(phase='done', end=now)
            return
        if phase == 'done' and now >= state['end']:
            summary()
            u.unregister_slate_post_tick_callback(handle)
            log('DONE')
            u.SystemLibrary.quit_editor()
    finally:
        state['busy'] = False


# In the background the editor otherwise drops to a few frames per second, and Unreal caps the
# simulated time per frame: the simulation would crawl. Session only, never written to the settings.
try:
    settings = u.get_default_object(u.load_class(None, '/Script/UnrealEd.EditorPerformanceSettings'))
    settings.set_editor_property('bThrottleCPUWhenNotForeground', False)
    log('THROTTLE_OFF')
except Exception as error:
    log('THROTTLE_UNCHANGED: ' + str(error))
handle = u.register_slate_post_tick_callback(tick)
log('STARTED')
