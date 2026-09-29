"""Make the VIIC of /Game/Demo/AtlanticDemo float on the ocean's Gerstner waves.

The boat's static mesh simulates physics (Chaos) on a collision box around the hull. A buoyancy
component from the Water plugin (Blueprint /Game/Demo/Blueprints/BP_FlottaisonVIIC, which holds
the pontoons) pushes up at 16 points of the hull in proportion to the immersed volume of a sphere,
measured against the wave height at that point. Heave, pitch and roll therefore come from the
waves themselves; the boat does not move forward.

port_submarine.py calls make_float() after each import, since a new import resets the mesh's
collision. Run this file alone (Tools > Execute Python Script, or headless like port_submarine.py)
to reapply the settings after changing the values below. Motion only exists in Play/Simulate or
in game mode; the editor keeps the boat at rest on the game's waterline.

Mesh frame after import (cm): X towards the bow, Y to starboard, Z up, waterline at Z = 190.
"""
from math import pi, sqrt
import unreal as u

BLUEPRINT = '/Game/Demo/Blueprints/BP_FlottaisonVIIC'
LEVEL = '/Game/Demo/AtlanticDemo'
G = 980.0                      # cm/s²

# Hull, measured on the exported model.
WATERLINE_Z = 190.0            # game waterline (model y = 1.9 m)
KEEL_Z, DECK_Z = -302.0, 330.0 # keel and casing deck
BEAM = 620.0
WATERLINE_X = (-3299.0, 3355.0)  # ends of the waterline, stern then bow
# Type VIIC surfaced: 769 t. Centre of gravity 3.3 m above the keel and a small surfaced
# metacentric height (estimates).
MASS_KG = 769000.0
COM_Z = 30.0
GM_T = 40.0

# Pontoons: 8 stations over 60 m, one each side. Sphere centres at the height of the centre of
# gravity, 1.6 m below the waterline. Radius and depth set the heave stiffness (waterplane area over
# displaced volume, here about 6 m, a 4.9 s period); the lateral spread sets the metacentric height,
# the length spread the pitch stiffness. The spheres reach 4.4 m above the waterline: the ocean's
# crests (standard deviation 1.1 m) must not overtop them, or the boat loses buoyancy and sinks.
STATIONS = 8
STATION_SPAN = 6000.0
PONTOON_RADIUS = 600.0
PONTOON_DEPTH = WATERLINE_Z - COM_Z

# Damping rates (1/s): about 0.3 of critical in heave, 0.2 in pitch and 0.3 in roll. Chaos damps
# rotation equally on all axes; pitch, which the 40 to 60 m waves excite near resonance, sets it.
LINEAR_DAMPING = 0.8
ANGULAR_DAMPING = 0.5


def sphere_cap(radius, height):
    """Volume and waterplane area of a sphere immersed up to height above its bottom."""
    volume = pi * height * height * (3 * radius - height) / 3
    area = pi * (radius * radius - (height - radius) ** 2)
    return volume, area


def design():
    """Pontoons and buoyancy coefficient, plus the natural periods they give."""
    volume, area = sphere_cap(PONTOON_RADIUS, PONTOON_RADIUS + PONTOON_DEPTH)
    # Pontoon forces are weighted so that they add up to one sphere: at rest they carry the weight.
    coefficient = MASS_KG * G / volume
    half_spread = sqrt(GM_T * volume / area)
    centre_x = sum(WATERLINE_X) / 2
    stations = [centre_x + STATION_SPAN * ((i + 0.5) / STATIONS - 0.5) for i in range(STATIONS)]
    pontoons = [(x, side * half_spread, COM_Z) for x in stations for side in (-1, 1)]
    # Radii of gyration of the collision box, which gives the inertia.
    height = DECK_Z - KEEL_Z
    length = WATERLINE_X[1] - WATERLINE_X[0]
    k_roll = sqrt((BEAM ** 2 + height ** 2) / 12)
    k_pitch = sqrt((length ** 2 + height ** 2) / 12)
    gm_l = sum((x - centre_x) ** 2 for x in stations) / STATIONS * area / volume
    periods = (2 * pi * sqrt(volume / area / G), 2 * pi * k_roll / sqrt(G * GM_T), 2 * pi * k_pitch / sqrt(G * gm_l))
    return pontoons, coefficient, periods


def hull_box(mesh):
    """Replace the mesh's simple collision by one box around the hull, below the deck.
    (The static mesh editor subsystem is not loaded when running headless, hence the direct edit.)"""
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


def buoyancy_class(pontoons, coefficient):
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
    spheres = ','.join('(RelativeLocation=(X=%.1f,Y=%.1f,Z=%.1f),Radius=%.1f)' % (x, y, z, PONTOON_RADIUS)
                       for x, y, z in pontoons)
    fields = [('Pontoons', '(%s)' % spheres), ('bCenterPontoonsOnCOM', 'False'),
              ('BuoyancyCoefficient', '%.6f' % coefficient),
              # The plugin's damping only acts while rising; the body's damping is used instead.
              ('BuoyancyDamp', '0.0'), ('BuoyancyDamp2', '0.0'), ('BuoyancyRampMax', '1.0'),
              ('MaxBuoyantForce', '100000000000.0'),
              ('bApplyDragForcesInWater', 'False'), ('bApplyRiverForces', 'False')]
    data = u.BuoyancyData()
    data.import_text('(%s)' % ','.join('%s=%s' % field for field in fields))
    if len(data.get_editor_property('pontoons')) != len(pontoons) or \
            abs(data.get_editor_property('buoyancy_coefficient') - coefficient) > 1e-3:
        raise RuntimeError('Buoyancy data not taken: ' + data.export_text())
    defaults = u.get_default_object(generated)
    defaults.modify()
    defaults.set_editor_property('buoyancy_data', data)
    blueprint.modify()
    u.EditorAssetLibrary.save_loaded_asset(blueprint, False)
    return generated


def make_float(boat):
    """Collision box, physics body and buoyancy component for the placed VIIC actor."""
    component = boat.static_mesh_component
    pontoons, coefficient, periods = design()
    hull_box(component.static_mesh)
    generated = buoyancy_class(pontoons, coefficient)

    component.set_mobility(u.ComponentMobility.MOVABLE)
    component.set_collision_profile_name('PhysicsActor')
    # The coast collides through a single convex hull around the island and the sea floor, which
    # takes in the boat's mooring: blocking static geometry would throw the hull out of the water.
    # Overlapping is enough, and it is how the ocean detects the boat.
    component.set_collision_response_to_channel(u.CollisionChannel.ECC_WORLD_STATIC, u.CollisionResponseType.ECR_OVERLAP)
    component.set_editor_property('generate_overlap_events', True)
    # The boat is in the water from the start. Unless this is set, loading the level records that
    # overlap silently and the ocean never hands itself to the buoyancy component.
    boat.set_editor_property('generate_overlap_events_during_level_streaming', True)
    body = component.get_editor_property('body_instance')
    body.set_editor_property('simulate_physics', True)
    body.set_editor_property('override_mass', True)
    body.set_editor_property('mass_in_kg_override', MASS_KG)
    body.set_editor_property('linear_damping', LINEAR_DAMPING)
    body.set_editor_property('angular_damping', ANGULAR_DAMPING)
    body.set_editor_property('com_nudge', u.Vector(0, 0, COM_Z - (KEEL_Z + DECK_Z) / 2))
    # Never put the hull to sleep during a calm moment.
    body.set_editor_property('sleep_family', u.SleepFamily.CUSTOM)
    body.set_editor_property('custom_sleep_threshold_multiplier', 0.0)
    component.set_editor_property('body_instance', body)

    existing = boat.get_components_by_class(u.BuoyancyComponent)
    if not existing:
        subobjects = u.get_engine_subsystem(u.SubobjectDataSubsystem)
        root = subobjects.k2_gather_subobject_data_for_instance(boat)[0]
        params = u.AddNewSubobjectParams(parent_handle=root, new_class=generated, blueprint_context=None)
        handle, reason = subobjects.add_new_subobject(params)
        if not u.SubobjectDataBlueprintFunctionLibrary.is_handle_valid(handle):
            raise RuntimeError('Cannot add the buoyancy component: %s' % reason)
        subobjects.rename_subobject(handle, u.Text('Flottaison'))
    elif existing[0].get_class() != generated:
        raise RuntimeError('%s already has another buoyancy component' % boat.get_actor_label())
    u.log('FLOAT_SETUP: %d pontoons r=%.0f cm, coefficient %.4f, periods heave %.1f s roll %.1f s pitch %.1f s' % (
        len(pontoons), PONTOON_RADIUS, coefficient, *periods))


def run():
    level = u.get_editor_subsystem(u.LevelEditorSubsystem)
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    if world is None or world.get_path_name().split('.')[0] != LEVEL:
        if not level.load_level(LEVEL):
            raise RuntimeError('Cannot load ' + LEVEL)
    actors = u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
    boats = [a for a in actors if a.get_actor_label().startswith('VIIC')]
    if len(boats) != 1:
        raise RuntimeError('Expected one VIIC actor, found %d' % len(boats))
    make_float(boats[0])
    level.save_current_level()
    u.log('FLOAT_COMPLETE')


if __name__ == '__main__':
    run()
