"""Make the Bismarck float on the ocean's Gerstner waves, as float_submarine.py does for the VIIC.

The ship's static mesh simulates physics (Chaos) on a collision box around the underwater hull. A
buoyancy component from the Water plugin (Blueprint /Game/Bismarck/Blueprints/BP_FlottaisonBismarck,
which holds the pontoons) pushes up at 20 points in proportion to the immersed volume of a sphere,
measured against the wave height at each point. The pontoons are sized from the hull's own
hydrostatics (Import/Bismarck/Bismarck.json, written by Tools/export-bismarck.sh) so that the ship
floats on her 10 m waterline with the heave, roll and pitch stiffness of the real hull. The ship does
not steam: she lies stopped, as at anchor.

port_bismarck.py calls make_float() after each import. Motion only exists in Play/Simulate or in game
mode; the editor keeps the ship at rest on her waterline.

Mesh frame after import (cm): X towards the bow, Y to starboard, Z up, waterline at Z = 0.
"""
from math import pi, sqrt
from pathlib import Path
import json
import unreal as u

ROOT = Path(u.Paths.project_dir()).resolve()
BLUEPRINT = '/Game/Bismarck/Blueprints/BP_FlottaisonBismarck'
HYDRO = json.loads((ROOT / 'Import' / 'Bismarck' / 'Bismarck.json').read_text())
G = 980.0                        # cm/s²
M = 100.0                        # cm per metre

MASS_KG = HYDRO['displacement_t'] * 1000.0          # 49,264 t at the 10 m waterline
V_OVER_A = HYDRO['volume_m3'] / HYDRO['waterplane_m2'] * M
# Metacentric height on Rheinübung (about 50,000 t): about 3.9 m, an estimate. The centre of gravity
# follows from the hull's metacentre: KG = KB + BMt − GM.
GM_T = 3.9 * M
KB = HYDRO['kb_m'] * M
KG = KB + HYDRO['bm_t_m'] * M - GM_T
GM_L = KB + HYDRO['bm_l_m'] * M - KG
KEEL_Z = -HYDRO['draught_m'] * M
COM = (HYDRO['lcb_m'] * M, 0.0, KEEL_Z + KG)          # above the centre of buoyancy, 1.2 m above the waterline
WATERLINE_X = tuple(x * M for x in HYDRO['waterline_m'])
DECK_Z = HYDRO['deck_at_side_m'] * M
BEAM = HYDRO['beam_m'] * M
# Radii of gyration of a battleship: 0.38 of the beam in roll, 0.25 of the length in pitch and yaw.
K_ROLL = 0.38 * BEAM
K_PITCH = 0.25 * (WATERLINE_X[1] - WATERLINE_X[0])

# Pontoons: 10 stations, one each side, centres at the height of the centre of gravity (they then add
# no heeling moment of their own). Radius: the spheres' immersed volume over waterplane area equals the
# hull's (8.2 m, a 5.8 s heave period). Lateral spread: the metacentric height. Length of the row: the
# longitudinal metacentric height (about 330 m).
STATIONS = 10
PONTOON_HEIGHT = COM[2]            # centre above the waterline

# Damping rates (1/s): about 0.23 of critical in heave; 0.22 in roll and 0.11 in pitch (Chaos damps all
# rotations alike).
LINEAR_DAMPING = 0.5
ANGULAR_DAMPING = 0.2


def sphere_cap(radius, height):
    """Volume and waterplane area of a sphere immersed up to height above its bottom."""
    volume = pi * height * height * (3 * radius - height) / 3
    area = pi * (radius * radius - (height - radius) ** 2)
    return volume, area


def pontoon_radius():
    """Sphere radius whose immersed volume over waterplane area matches the hull's (bisection)."""
    lo, hi = PONTOON_HEIGHT + 100.0, 5000.0
    for _ in range(60):
        r = (lo + hi) / 2
        volume, area = sphere_cap(r, r - PONTOON_HEIGHT)
        if volume / area < V_OVER_A:
            lo = r
        else:
            hi = r
    return (lo + hi) / 2


def design():
    """Pontoons, buoyancy coefficient, inertia scale and the natural periods they give."""
    radius = pontoon_radius()
    volume, area = sphere_cap(radius, radius - PONTOON_HEIGHT)
    # Pontoon forces are weighted so that they add up to one sphere: at rest they carry the weight.
    coefficient = MASS_KG * G / volume
    half_spread = sqrt(GM_T * volume / area)
    # Stations at the middle of equal intervals: mean square distance span² (1 − 1/n²) / 12.
    span = sqrt(12 * GM_L * volume / area / (1 - 1.0 / STATIONS ** 2))
    stations = [COM[0] + span * ((i + 0.5) / STATIONS - 0.5) for i in range(STATIONS)]
    pontoons = [(x, side * half_spread, PONTOON_HEIGHT) for x in stations for side in (-1, 1)]
    # The collision box gives the inertia; scale it to the ship's radii of gyration.
    height = DECK_Z - KEEL_Z
    length = WATERLINE_X[1] - WATERLINE_X[0]
    box_roll = (BEAM ** 2 + height ** 2) / 12
    box_pitch = (length ** 2 + height ** 2) / 12
    box_yaw = (length ** 2 + BEAM ** 2) / 12
    inertia_scale = (K_ROLL ** 2 / box_roll, K_PITCH ** 2 / box_pitch, K_PITCH ** 2 / box_yaw)
    gm_l = sum((x - COM[0]) ** 2 for x in stations) / STATIONS * area / volume
    periods = (2 * pi * sqrt(volume / area / G), 2 * pi * K_ROLL / sqrt(G * GM_T), 2 * pi * K_PITCH / sqrt(G * gm_l))
    return dict(radius=radius, pontoons=pontoons, coefficient=coefficient, inertia_scale=inertia_scale,
                periods=periods, span=span, half_spread=half_spread,
                max_force=MASS_KG * G * (4 / 3 * pi * radius ** 3) / volume * 10)


def hull_box(mesh):
    """Replace the mesh's simple collision by one box around the underwater hull and topsides, up to
    the deck at the side. (The static mesh editor subsystem is not loaded when running headless.)"""
    mesh.modify()
    box = u.KBoxElem()
    box.set_editor_property('center', u.Vector(sum(WATERLINE_X) / 2, 0, (KEEL_Z + DECK_Z) / 2))
    box.set_editor_property('x', WATERLINE_X[1] - WATERLINE_X[0])
    box.set_editor_property('y', BEAM)
    box.set_editor_property('z', DECK_Z - KEEL_Z)
    body = mesh.get_editor_property('body_setup')
    geometry = body.get_editor_property('agg_geom')
    for shapes in ('sphere_elems', 'sphyl_elems', 'convex_elems', 'tapered_capsule_elems'):
        geometry.set_editor_property(shapes, [])
    geometry.set_editor_property('box_elems', [box])
    body.set_editor_property('agg_geom', geometry)
    u.EditorAssetLibrary.save_loaded_asset(mesh, False)


def buoyancy_class(d):
    """Blueprint of the buoyancy component, created once, with the pontoons in its defaults
    (the Water plugin only lets them be edited there)."""
    blueprint = u.load_asset(BLUEPRINT)
    if blueprint is None:
        factory = u.BlueprintFactory()
        factory.set_editor_property('parent_class', u.BuoyancyComponent)
        folder, name = BLUEPRINT.rsplit('/', 1)
        blueprint = u.AssetToolsHelpers.get_asset_tools().create_asset(name, folder, u.Blueprint, factory)
        u.BlueprintEditorLibrary.compile_blueprint(blueprint)
    generated = u.BlueprintEditorLibrary.generated_class(blueprint)
    # A struct built in Python counts as an instance, where these fields are read-only: fill it
    # from Unreal's text form instead, then assign it to the class defaults.
    spheres = ','.join('(RelativeLocation=(X=%.1f,Y=%.1f,Z=%.1f),Radius=%.1f)' % (x, y, z, d['radius'])
                       for x, y, z in d['pontoons'])
    fields = [('Pontoons', '(%s)' % spheres), ('bCenterPontoonsOnCOM', 'False'),
              ('BuoyancyCoefficient', '%.6f' % d['coefficient']),
              # The plugin's damping only acts while rising; the body's damping is used instead.
              ('BuoyancyDamp', '0.0'), ('BuoyancyDamp2', '0.0'), ('BuoyancyRampMax', '1.0'),
              # The ship weighs 4.8e10 kg·cm/s²; the default cap would clip every pontoon.
              ('MaxBuoyantForce', '%.1f' % d['max_force']),
              ('bApplyDragForcesInWater', 'False'), ('bApplyRiverForces', 'False')]
    data = u.BuoyancyData()
    data.import_text('(%s)' % ','.join('%s=%s' % field for field in fields))
    if len(data.get_editor_property('pontoons')) != len(d['pontoons']) or \
            abs(data.get_editor_property('buoyancy_coefficient') - d['coefficient']) > 1e-3 or \
            data.get_editor_property('max_buoyant_force') < 0.99 * d['max_force']:
        raise RuntimeError('Buoyancy data not taken: ' + data.export_text())
    defaults = u.get_default_object(generated)
    defaults.modify()
    defaults.set_editor_property('buoyancy_data', data)
    blueprint.modify()
    u.EditorAssetLibrary.save_loaded_asset(blueprint, False)
    return generated


def make_float(ship):
    """Collision box, physics body and buoyancy component for the placed Bismarck actor."""
    component = ship.static_mesh_component
    d = design()
    hull_box(component.static_mesh)
    generated = buoyancy_class(d)

    component.set_mobility(u.ComponentMobility.MOVABLE)
    component.set_collision_profile_name('PhysicsActor')
    # As for the VIIC: the coast's collision is one convex hull that takes in the anchorage. Overlap it
    # (that is also how the ocean detects the ship) rather than be thrown out of the water.
    component.set_collision_response_to_channel(u.CollisionChannel.ECC_WORLD_STATIC, u.CollisionResponseType.ECR_OVERLAP)
    component.set_editor_property('generate_overlap_events', True)
    # In the water from the start: without this the ocean never hands itself to the buoyancy component.
    ship.set_editor_property('generate_overlap_events_during_level_streaming', True)
    body = component.get_editor_property('body_instance')
    body.set_editor_property('simulate_physics', True)
    body.set_editor_property('override_mass', True)
    body.set_editor_property('mass_in_kg_override', MASS_KG)
    body.set_editor_property('linear_damping', LINEAR_DAMPING)
    body.set_editor_property('angular_damping', ANGULAR_DAMPING)
    box_centre = (sum(WATERLINE_X) / 2, 0.0, (KEEL_Z + DECK_Z) / 2)
    body.set_editor_property('com_nudge', u.Vector(COM[0] - box_centre[0], 0, COM[2] - box_centre[2]))
    body.set_editor_property('inertia_tensor_scale', u.Vector(*d['inertia_scale']))
    # Never put the hull to sleep during a calm moment.
    body.set_editor_property('sleep_family', u.SleepFamily.CUSTOM)
    body.set_editor_property('custom_sleep_threshold_multiplier', 0.0)
    component.set_editor_property('body_instance', body)

    # The component takes its pontoons from the Blueprint's defaults when it is created, and the level then
    # keeps them as they were: a component made while the Blueprint was being created came out with none (the
    # ship sank). Replace any component whose pontoons differ from the design.
    subobjects = u.get_engine_subsystem(u.SubobjectDataSubsystem)
    library = u.SubobjectDataBlueprintFunctionLibrary

    def pontoon_count(component):
        return len(component.get_editor_property('buoyancy_data').get_editor_property('pontoons'))

    for component in ship.get_components_by_class(u.BuoyancyComponent):
        if component.get_class() != generated:
            raise RuntimeError('%s already has another buoyancy component' % ship.get_actor_label())
        if pontoon_count(component) != len(d['pontoons']):
            handles = subobjects.k2_gather_subobject_data_for_instance(ship)
            handle = next(h for h in handles if library.get_object(library.get_data(h)) == component)
            if subobjects.delete_subobject(handles[0], handle, None) != 1:
                raise RuntimeError('Cannot remove the outdated buoyancy component')
            u.log('BISMARCK_FLOAT: outdated buoyancy component removed (%d pontoons)' % pontoon_count(component))
    if not ship.get_components_by_class(u.BuoyancyComponent):
        root = subobjects.k2_gather_subobject_data_for_instance(ship)[0]
        params = u.AddNewSubobjectParams(parent_handle=root, new_class=generated, blueprint_context=None)
        handle, reason = subobjects.add_new_subobject(params)
        if not library.is_handle_valid(handle):
            raise RuntimeError('Cannot add the buoyancy component: %s' % reason)
        subobjects.rename_subobject(handle, u.Text('Flottaison'))
    component = ship.get_components_by_class(u.BuoyancyComponent)[0]
    if pontoon_count(component) != len(d['pontoons']):
        raise RuntimeError('The buoyancy component has %d pontoons instead of %d' % (pontoon_count(component), len(d['pontoons'])))
    u.log('BISMARCK_FLOAT: mass %.0f t, KG %.2f m, GM %.2f / %.0f m, %d pontoons r=%.0f cm over %.0f m, spread ±%.0f cm, '
          'coefficient %.4f, inertia scale %.2f %.2f %.2f, periods heave %.1f s roll %.1f s pitch %.1f s' % (
              MASS_KG / 1000, KG / M, GM_T / M, GM_L / M, len(d['pontoons']), d['radius'], d['span'] / M,
              d['half_spread'], d['coefficient'], *d['inertia_scale'], *d['periods']))
    return d
