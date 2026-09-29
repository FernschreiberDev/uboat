"""Check the Bismarck at sea in /Game/Bismarck/AtlanticBismarck: Simulate in Editor, record her motion,
take still views and a series of frames, then quit without saving anything.

Output in Saved/BismarckCheck: vue-*.png (stills), frame-NN.png (series from the starboard bow),
motion.csv (simulation time, position, roll, pitch, yaw, mean water height at the pontoons, in water).
Launch with Tools/port-bismarck.sh capture_bismarck.py and let the script stop the simulation: an editor
killed while simulating crashes on the way out.
"""
from pathlib import Path
import math
import time
import unreal as u

OUT = Path(u.Paths.project_dir()).resolve() / 'Saved' / 'BismarckCheck'
OUT.mkdir(parents=True, exist_ok=True)
LEVEL = '/Game/Bismarck/AtlanticBismarck'
WARMUP = 90.0          # after the level is open: shaders, ocean, clouds
SETTLE = 10.0          # first seconds of simulation, left out of the statistics
RECORD = 100.0
SIZE = (1600, 900)
# Views in the ship's frame (cm; x forward, y to starboard, z up from the waterline): eye, target.
STILLS = [
    ('vue-depart', None, None),
    ('vue-trois-quarts', (14000, 12000, 1100), (-1500, 0, 1200)),
    ('vue-travers', (0, 45000, 1000), (0, 0, 1000)),
    ('vue-passerelle', (3000, 9000, 3500), (1500, 0, 1800)),
    ('vue-tourelles-avant', (10500, 5500, 2300), (6000, 0, 1200)),
    ('vue-poupe', (-17000, -11000, 1400), (-2500, 0, 900)),
    ('vue-aerienne', (15000, -12000, 9000), (-1000, 0, 0)),
    ('vue-comme-photo-1940', (9000, -21000, 500), (-1500, 0, 1300)),
    ('vue-pavillon', (-900, -4200, 4300), (-2500, 0, 3750)),
]
STILL_START, STILL_STEP = 12.0, 4.0          # 3 s to settle after each camera move
SERIES = ('frame', (14000, 12000, 1100), (-1500, 0, 1200))
SERIES_START, SERIES_STEP, SERIES_COUNT = 53.0, 0.5, 40

editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
level = u.get_editor_subsystem(u.LevelEditorSubsystem)
state = {'phase': 'open', 'busy': False, 'sim_start': 0.0, 'ship': None, 'task': None, 'end': 0.0,
         'still': 0, 'frame': 0, 'rest': None, 'camera_at': -1.0}
samples = []
start = time.monotonic()
handle = None


def log(text):
    u.log('BISMARCK_CHECK: ' + text)


def find_ship(world):
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.StaticMeshActor):
        if actor.get_actor_label().startswith('Bismarck'):
            return actor
    return None


def ship_view(eye, target):
    """World camera from a view in the ship's frame at rest (editor placement)."""
    loc, yaw = state['rest']
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def world(p):
        return u.Vector(loc.x + p[0] * c - p[1] * s, loc.y + p[0] * s + p[1] * c, p[2])
    e, t = world(eye), world(target)
    return e, u.MathLibrary.make_rot_from_x(u.Vector(t.x - e.x, t.y - e.y, t.z - e.z))


def set_camera(view):
    name, eye, target = view
    if eye is None:
        editor.set_level_viewport_camera_info(*state['start_camera'])
    else:
        editor.set_level_viewport_camera_info(*ship_view(eye, target))


def record(world, ship):
    t = u.GameplayStatics.get_time_seconds(world) - state['sim_start']
    loc, rot = ship.get_actor_location(), ship.get_actor_rotation()
    buoyancy = ship.get_component_by_class(u.BuoyancyComponent)
    water, in_water = float('nan'), False
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
    kept = [s for s in samples if s[0] >= SETTLE]
    if not kept:
        log('NO SAMPLES')
        return

    def stats(name, values):
        mean = sum(values) / len(values)
        std = math.sqrt(sum((v - mean) ** 2 for v in values) / len(values))
        log('%s mean=%.2f std=%.2f min=%.2f max=%.2f' % (name, mean, std, min(values), max(values)))

    log('samples=%d over %.1f s, in water %.0f%%' % (len(kept), kept[-1][0] - kept[0][0], 100.0 * sum(s[8] for s in kept) / len(kept)))
    stats('heave_cm', [s[3] for s in kept])
    stats('roll_deg', [s[4] for s in kept])
    stats('pitch_deg', [s[5] for s in kept])
    stats('yaw_deg', [s[6] for s in kept])
    stats('drift_cm', [math.hypot(s[1] - kept[0][1], s[2] - kept[0][2]) for s in kept])
    stats('water_at_pontoons_cm', [s[7] for s in kept if not math.isnan(s[7])])


def shoot(name, t):
    path = str(OUT / (name + '.png'))
    state['task'] = u.AutomationLibrary.take_high_res_screenshot(SIZE[0], SIZE[1], path)
    log('shot %s at %.1f s' % (name, t))


def tick(delta):
    if state['busy']:
        return
    state['busy'] = True
    try:
        level.editor_invalidate_viewports()
        now = time.monotonic() - start
        phase = state['phase']
        if phase == 'open':
            world = editor.get_editor_world()
            if world is None or not world.get_path_name().startswith(LEVEL + '.'):
                log('LEVEL_FAILED: start the editor on ' + LEVEL)
                state.update(phase='done', end=now)
                return
            ship = next(a for a in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
                        if a.get_actor_label().startswith('Bismarck'))
            state['rest'] = (ship.get_actor_location(), ship.get_actor_rotation().yaw)
            start_point = next(a for a in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
                               if isinstance(a, u.PlayerStart))
            state['start_camera'] = (start_point.get_actor_location(), start_point.get_actor_rotation())
            level.editor_set_game_view(True)
            set_camera(STILLS[0])
            state.update(phase='warmup', end=now + WARMUP)
            log('LEVEL_OPEN ship at %s yaw %.1f' % state['rest'])
            return
        if phase == 'warmup':
            if now < state['end']:
                return
            level.editor_play_simulate()
            state.update(phase='starting', end=now + 30)
            log('SIMULATE_REQUESTED')
            return
        if phase == 'starting':
            world = editor.get_game_world()
            ship = find_ship(world) if world else None
            if ship is None:
                if now > state['end']:
                    log('SIMULATE_FAILED')
                    state.update(phase='done', end=now)
                return
            state.update(phase='sim', ship=ship, sim_start=u.GameplayStatics.get_time_seconds(world))
            log('SIMULATE_STARTED')
            return
        if phase == 'sim':
            world = editor.get_game_world()
            if world is None:
                log('SIMULATE_STOPPED_EARLY')
                state.update(phase='done', end=now)
                return
            t = record(world, state['ship'])
            if t >= state.setdefault('next_log', 0.0):
                row = samples[-1]
                log('t=%.1f s z=%.0f cm roll=%.2f pitch=%.2f yaw=%.2f in_water=%d' % (t, row[3], row[4], row[5], row[6], row[8]))
                state['next_log'] = t + 10.0
            task = state['task']
            if task is not None:
                if not task.is_task_done():
                    return
                state['task'] = None
            i = state['still']
            if i < len(STILLS):
                due = STILL_START + i * STILL_STEP
                if state['camera_at'] < 0 and t >= due - 3.0:
                    set_camera(STILLS[i])
                    state['camera_at'] = t
                elif state['camera_at'] >= 0 and t >= due:
                    shoot(STILLS[i][0], t)
                    state.update(still=i + 1, camera_at=-1.0)
                return
            if state['frame'] == 0 and state['camera_at'] < 0:
                set_camera(SERIES)
                state['camera_at'] = t
            if state['frame'] < SERIES_COUNT and t >= SERIES_START + state['frame'] * SERIES_STEP:
                shoot('frame-%02d' % state['frame'], t)
                state['frame'] += 1
                return
            if t >= SETTLE + RECORD and state['frame'] >= SERIES_COUNT:
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
    except Exception as error:
        log('ERROR %s' % error)
        # Never quit while simulating: end play first.
        if editor.get_game_world() is not None:
            level.editor_request_end_play()
            state.update(phase='stopping', end=time.monotonic() - start + 5)
        else:
            state.update(phase='done', end=time.monotonic() - start)
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
