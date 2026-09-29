"""Replace the submarine of /Game/Demo/AtlanticDemo with Import/VIIC.obj, as written by
Tools/export-submarine.sh, then reapply the Naval materials slot by slot and make the boat float
on the waves (float_submarine.py). The rest of the scene (ocean, coast, light, camera) is left as it is.
Runs in the editor (Tools > Execute Python Script) or headless:
UnrealEditor-Cmd NordatlantikDemo.uproject -run=pythonscript -script=<this file>
"""
from pathlib import Path
import importlib
import sys
import unreal as u

ROOT = Path(u.Paths.project_dir()).resolve()
sys.path.insert(0, str(ROOT / 'Content' / 'Python'))
import float_submarine
importlib.reload(float_submarine)

LEVEL = '/Game/Demo/AtlanticDemo'
MESH = '/Game/Demo/Meshes/VIIC'
# Exported model in metres: 67.18 m long, 6.21 m wide, 13.11 m high (periscopes raised), keel at
# -3.02 m. After import the bow points along +X (Unreal's forward axis), starboard along +Y, Z up.
EXPECTED_CM = (6718.0, 621.0, 1311.0)
KEEL_CM = -302.0

if not u.get_editor_subsystem(u.LevelEditorSubsystem).load_level(LEVEL):
    raise RuntimeError('Cannot load ' + LEVEL)

# Same import settings as build_demo.py, replacing the existing mesh asset in place.
task = u.AssetImportTask()
task.filename = str(ROOT / 'Import' / 'VIIC.obj')
task.destination_path = '/Game/Demo/Meshes'
task.destination_name = 'VIIC'
task.automated = True
task.replace_existing = True
task.replace_existing_settings = True
task.save = True
options = u.FbxImportUI()
options.import_mesh = True
options.import_materials = True
options.import_textures = True
options.import_as_skeletal = False
options.mesh_type_to_import = u.FBXImportType.FBXIT_STATIC_MESH
options.static_mesh_import_data.combine_meshes = True
options.static_mesh_import_data.import_uniform_scale = 100.0
options.static_mesh_import_data.convert_scene = True
# The OBJ is Y-up with the bow along +Z. Turn it here rather than on the actor: the Water plugin's
# buoyancy expects a body whose own Z axis is vertical, and roll and pitch then read as the boat's.
options.static_mesh_import_data.import_rotation = u.Rotator(roll=90, pitch=0, yaw=90)
# The hull's collision box comes from float_submarine.py.
options.static_mesh_import_data.auto_generate_collision = False
task.options = options
u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
u.log('DEMO_PORT_IMPORTED: ' + ', '.join(str(p) for p in task.imported_object_paths))

mesh = u.load_asset(MESH)
if not isinstance(mesh, u.StaticMesh):
    raise RuntimeError('Import failed: ' + MESH)
box = mesh.get_bounding_box()
size = (box.max.x - box.min.x, box.max.y - box.min.y, box.max.z - box.min.z)
u.log('DEMO_PORT_MESH: triangles=%d slots=%d size_cm=%.0f x %.0f x %.0f keel_cm=%.0f' % (
    mesh.get_num_triangles(0), len(mesh.static_materials), size[0], size[1], size[2], box.min.z))
if any(abs(got - want) > 5 for got, want in zip(size, EXPECTED_CM)) or abs(box.min.z - KEEL_CM) > 5:
    raise RuntimeError('Unexpected mesh size or orientation (cm): %s, keel at %.0f' % (size, box.min.z))

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

# Naval materials by MTL name, as created by refine_demo.py.
materials, current = {}, None
for line in (ROOT / 'Import' / 'VIIC.mtl').read_text().splitlines():
    parts = line.split()
    if not parts:
        continue
    if parts[0] == 'newmtl':
        current = parts[1]
        materials[current] = {}
    elif current:
        materials[current][parts[0]] = parts[1:]

actors = u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
boats = [a for a in actors if a.get_actor_label().startswith('VIIC')]
if len(boats) != 1:
    raise RuntimeError('Expected one VIIC actor, found %d' % len(boats))
boat = boats[0]
component = boat.static_mesh_component
component.set_static_mesh(mesh)
mel = u.MaterialEditingLibrary
for slot, entry in enumerate(mesh.static_materials):
    source = str(entry.material_slot_name)
    if source not in materials and entry.material_interface:
        source = entry.material_interface.get_name()
    if source not in materials:
        raise RuntimeError('Unmapped material slot %d: %s' % (slot, entry))
    material = u.load_asset('/Game/Demo/Materials/Naval_' + source)
    if material is None:
        raise RuntimeError('Missing /Game/Demo/Materials/Naval_' + source + ' (run refine_demo.py first)')
    # Keep the material in step with the MTL. Kd is sRGB, as the game's SceneKit reads it, while a
    # material constant is linear: taken as is, the dark hull greys came out several times too light.
    params = materials[source]
    base = mel.get_material_property_input_node(material, u.MaterialProperty.MP_BASE_COLOR)
    if isinstance(base, u.MaterialExpressionConstant3Vector) and 'map_Kd' not in params:
        base.set_editor_property('constant', u.LinearColor(*[srgb_to_linear(float(v)) for v in params['Kd']], 1))
    elif not (isinstance(base, u.MaterialExpressionTextureSample) and 'map_Kd' in params
              and base.get_editor_property('texture').get_name() == 'TEX_' + Path(params['map_Kd'][0]).stem):
        raise RuntimeError('Base colour of %s does not match the MTL' % material.get_name())
    for field, prop in (('Pr', u.MaterialProperty.MP_ROUGHNESS), ('Pm', u.MaterialProperty.MP_METALLIC)):
        mel.get_material_property_input_node(material, prop).set_editor_property('r', float(params[field][0]))
    mel.recompile_material(material)
    component.set_material(slot, material)
    u.log('DEMO_PORT_SLOT: %d %s -> %s base=%s' % (slot, source, material.get_name(),
          (base.get_editor_property('texture').get_name() if isinstance(base, u.MaterialExpressionTextureSample)
           else base.get_editor_property('constant'))))

# Waterline of the game (model y = 1.9 m) at sea level, bow towards -Y as in the rest of the scene.
boat.set_actor_location(u.Vector(0, 0, -190), False, False)
boat.set_actor_rotation(u.Rotator(roll=0, pitch=0, yaw=-90), False)
origin, extent = boat.get_actor_bounds(False)
u.log('DEMO_PORT_ACTOR: origin=%s extent=%s' % (origin, extent))
float_submarine.make_float(boat)

u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
u.EditorAssetLibrary.save_directory('/Game/Demo')
u.log('DEMO_PORT_COMPLETE')
