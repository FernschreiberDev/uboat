"""Diagnose water contact in /Game/Bismarck/AtlanticBismarck: the ocean's collision (extents, boxes,
profiles) and both boats' buoyancy components (pontoons, coefficient) in the editor, then 20 s of
Simulate with each boat's height, contact, known water bodies and first pontoon. Saves nothing.
Launch with Tools/port-bismarck.sh diagnose_bismarck_water.py; the script ends play and quits by itself.
"""
import time
import unreal as u

editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
level = u.get_editor_subsystem(u.LevelEditorSubsystem)
state = {'phase': 'inspect', 'end': 0.0, 'busy': False, 'next': 0.0}
start = time.monotonic()
handle = None


def log(text):
    u.log('BISMARCK_DIAG: ' + text)


def safe(fn):
    try:
        return fn()
    except Exception as error:
        return 'n/a (%s)' % error


def describe_ocean(actors, where):
    for ocean in [a for a in actors if isinstance(a, u.WaterBodyOcean)]:
        water = ocean.water_body_component

        def prop(name):
            try:
                return water.get_editor_property(name)
            except Exception as error:
                return 'n/a'
        log('%s ocean %s at %s collision_extents=%s ocean_extents=%s profile=%s overlaps=%s enabled=%s' % (
            where, ocean.get_name(), ocean.get_actor_location(), prop('collision_extents'), prop('ocean_extents'),
            water.get_collision_profile_name(), safe(lambda: water.get_editor_property('generate_overlap_events')), safe(water.get_collision_enabled)))
        for c in ocean.get_components_by_class(u.PrimitiveComponent):
            if c.get_class().get_name() in ('BoxComponent', 'OceanBoxCollisionComponent', 'OceanCollisionComponent'):
                origin, extent, radius = u.SystemLibrary.get_component_bounds(c)
                log('%s   %s %s origin=%s extent=%s profile=%s overlaps=%s' % (
                    where, c.get_class().get_name(), c.get_name(), origin, extent, c.get_collision_profile_name(),
                    safe(lambda: c.get_editor_property('generate_overlap_events'))))


def boats(actors):
    return [a for a in actors if isinstance(a, u.StaticMeshActor) and a.get_actor_label().split()[0] in ('VIIC', 'Bismarck')]


def tick(delta):
    if state['busy']:
        return
    state['busy'] = True
    try:
        now = time.monotonic() - start
        if state['phase'] == 'inspect':
            actors = u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
            describe_ocean(actors, 'editor')
            for b in boats(actors):
                comp = b.static_mesh_component
                origin, extent = b.get_actor_bounds(False)
                for buoyancy in b.get_components_by_class(u.BuoyancyComponent):
                    data = buoyancy.get_editor_property('buoyancy_data')
                    pontoons = data.get_editor_property('pontoons')
                    log('editor buoyancy %s class=%s pontoons=%d coefficient=%s max_force=%s first=%s' % (
                        b.get_actor_label().split()[0], buoyancy.get_class().get_name(), len(pontoons),
                        data.get_editor_property('buoyancy_coefficient'), data.get_editor_property('max_buoyant_force'),
                        pontoons[0].get_editor_property('relative_location') if pontoons else None))
                log('editor boat %s at %s bounds %s±%s profile=%s overlaps=%s streaming_overlaps=%s' % (
                    b.get_actor_label(), b.get_actor_location(), origin, extent, comp.get_collision_profile_name(),
                    safe(lambda: comp.get_editor_property('generate_overlap_events')), safe(lambda: b.get_editor_property('generate_overlap_events_during_level_streaming'))))
            for ocean in [a for a in actors if isinstance(a, u.WaterBodyOcean)]:
                log('editor ocean root mobility=%s update_method=%s streaming_overlaps=%s' % (
                    safe(lambda: ocean.root_component.mobility),
                    safe(lambda: ocean.get_editor_property('update_overlaps_method_during_level_streaming')),
                    safe(lambda: ocean.get_editor_property('generate_overlap_events_during_level_streaming'))))
            order = [a.get_name() for a in actors if isinstance(a, (u.WaterBodyOcean, u.StaticMeshActor))]
            log('editor actor order: ' + ', '.join(order))
            state.update(phase='warmup', end=now + 40)
        elif state['phase'] == 'warmup' and now >= state['end']:
            level.editor_play_simulate()
            state.update(phase='sim', end=now + 20)
        elif state['phase'] == 'sim':
            world = editor.get_game_world()
            if world is None:
                if now > state['end']:
                    state.update(phase='done', end=now)
                return
            if now >= state['next']:
                actors = u.GameplayStatics.get_all_actors_of_class(world, u.Actor)
                if state['next'] == 0.0:
                    describe_ocean(actors, 'sim')
                for b in boats(actors):
                    buoyancy = b.get_component_by_class(u.BuoyancyComponent)
                    overlapping = [a.get_name() for a in b.get_overlapping_actors()]
                    pontoons = buoyancy.get_editor_property('buoyancy_data').get_editor_property('pontoons') if buoyancy else []
                    log('sim t=%.1f %s z=%.0f in_water=%s overlapping_water=%s bodies=%s pontoons=%d water_h0=%s in0=%s overlapping=%s' % (
                        now, b.get_actor_label().split()[0], b.get_actor_location().z,
                        buoyancy.is_in_water_body() if buoyancy else None,
                        safe(buoyancy.is_overlapping_water_body) if buoyancy else None,
                        safe(lambda: [c.get_name() for c in buoyancy.get_current_water_body_components()]) if buoyancy else None,
                        len(pontoons), safe(lambda: pontoons[0].get_editor_property('water_height')),
                        safe(lambda: pontoons[0].get_editor_property('is_in_water')), overlapping))
                state['next'] = now + 3.0
            if now >= state['end']:
                level.editor_request_end_play()
                state.update(phase='stopping', end=now + 5)
        elif state['phase'] == 'stopping' and now >= state['end']:
            state.update(phase='done', end=now)
        elif state['phase'] == 'done' and now >= state['end']:
            u.unregister_slate_post_tick_callback(handle)
            log('DONE')
            u.SystemLibrary.quit_editor()
    except Exception as error:
        log('ERROR %s' % error)
        if editor.get_game_world() is not None:
            level.editor_request_end_play()
            state.update(phase='stopping', end=time.monotonic() - start + 5)
        else:
            state.update(phase='done', end=time.monotonic() - start)
    finally:
        state['busy'] = False


try:
    settings = u.get_default_object(u.load_class(None, '/Script/UnrealEd.EditorPerformanceSettings'))
    settings.set_editor_property('bThrottleCPUWhenNotForeground', False)
except Exception as error:
    log('THROTTLE_UNCHANGED: ' + str(error))
handle = u.register_slate_post_tick_callback(tick)
log('STARTED')
