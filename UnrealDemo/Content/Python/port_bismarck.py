"""Put the Bismarck (Import/Bismarck, written by Tools/export-bismarck.sh) at sea in her own level,
/Game/Bismarck/AtlanticBismarck: a copy of /Game/Demo/AtlanticDemo (ocean, island, sky, VIIC) with the
battleship lying stopped 430 m from the start camera, beyond the U-boat. Her assets live in /Game/Bismarck.

AtlanticDemo, AtlanticCoast and the U-boat's assets are never written: their SHA-256 are compared before
and after, and only the new level and /Game/Bismarck are saved. Run again after each export: the mesh,
textures and materials are replaced in place and the ship keeps her place.

The ocean's WaterInfo meshes of a copied level can only be built by the full editor, so run it there.
The first time, the editor starts on AtlanticDemo and the script only saves the copy; afterwards it starts
on the copy and does the port (Tools/port-bismarck.sh does both):
UnrealEditor NordatlantikDemo.uproject /Game/Bismarck/AtlanticBismarck -ExecCmds="py <this file>"
The script quits the editor when done. Results: log lines BISMARCK_PORT: and BISMARCK_FLOAT:,
Docs/bismarck-port.json.
"""
from pathlib import Path
import hashlib
import importlib
import json
import sys
import time
import traceback
import unreal as u

ROOT = Path(u.Paths.project_dir()).resolve()
sys.path.insert(0, str(ROOT / 'Content' / 'Python'))
import float_bismarck
importlib.reload(float_bismarck)

SOURCE_LEVEL = '/Game/Demo/AtlanticDemo'
LEVEL = '/Game/Bismarck/AtlanticBismarck'
FOLDER = '/Game/Bismarck'
IMPORT = ROOT / 'Import' / 'Bismarck'
INFO = json.loads((IMPORT / 'Bismarck.json').read_text())
PROTECTED = ['Content/Demo/AtlanticDemo.umap', 'Content/Demo/AtlanticCoast.umap', 'Content/Demo/Meshes/VIIC.uasset',
             'Content/Demo/Blueprints/BP_FlottaisonVIIC.uasset', 'Content/Python/float_submarine.py']
LABEL = 'Bismarck — cuirassé, mai 1941'
# Midships 60 m east and 340 m north of the U-boat, heading 204°: her starboard bow faces the start
# camera, 430 m away. Her stern stays 90 m from the island's bounding box (x from 266 m), in 50 m of water.
LOCATION = u.Vector(6000, 34000, 0)
ROTATION = u.Rotator(roll=0, pitch=0, yaw=-156)
# Start camera of the copy: same place as the demo's, turned to frame both boats.
CAMERA = (u.Vector(-5500, -7000, 1250), u.Rotator(roll=0, pitch=-4, yaw=62))
WARMUP = 20.0
# Livery: 24mai (Operation Rheinübung, Denmark Strait; default) or 21mai (Korsfjord: stripes, air-recognition
# panels with swastikas on the decks). Given after the script name: port-bismarck.sh port_bismarck.py 21mai
LIVERY = next((a for a in sys.argv[1:] if a in ('21mai', '24mai')), '24mai')

editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
level = u.get_editor_subsystem(u.LevelEditorSubsystem)
actors = u.get_editor_subsystem(u.EditorActorSubsystem)
assets = u.AssetToolsHelpers.get_asset_tools()
mel = u.MaterialEditingLibrary
state = {'phase': 'warmup', 'end': 0.0, 'busy': False}
start = time.monotonic()
report = {}


def log(text):
    u.log('BISMARCK_PORT: ' + text)


def digests():
    return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in PROTECTED if (ROOT / p).exists()}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def open_level():
    """True when the Bismarck's level is the open world. The first time, the editor starts on AtlanticDemo
    and the script only saves a copy of it (EditorLoadingAndSavingUtils.save_map, which leaves the open
    world and its file as they are); Tools/port-bismarck.sh then restarts the editor on the copy.
    (Duplicating the map asset and opening the copy in the same session stops the editor on a world leak.)"""
    world = editor.get_editor_world()
    current = world.get_path_name().split('.')[0] if world else ''
    if current == LEVEL:
        return True
    if current != SOURCE_LEVEL or u.EditorAssetLibrary.does_asset_exist(LEVEL):
        raise RuntimeError('Start the editor on %s (or on %s once it exists), not %s' % (SOURCE_LEVEL, LEVEL, current))
    if not u.EditorLoadingAndSavingUtils.save_map(world, LEVEL):
        raise RuntimeError('Cannot save the copy as ' + LEVEL)
    log('COPY_SAVED %s from %s: restart the editor on the copy' % (LEVEL, SOURCE_LEVEL))
    return False


def import_texture(filename, name, address, normal=False):
    task = u.AssetImportTask()
    task.filename = str(IMPORT / filename)
    task.destination_path = FOLDER + '/Textures'
    task.destination_name = name
    task.automated = True
    task.replace_existing = True
    task.save = False
    assets.import_asset_tasks([task])
    texture = u.load_asset('%s/Textures/%s' % (FOLDER, name))
    if not isinstance(texture, u.Texture2D):
        raise RuntimeError('Texture import failed: ' + name)
    texture.set_editor_property('address_x', address)
    texture.set_editor_property('address_y', address)
    if normal:
        texture.set_editor_property('compression_settings', u.TextureCompressionSettings.TC_NORMALMAP)
        texture.set_editor_property('srgb', False)
        texture.set_editor_property('lod_group', u.TextureGroup.TEXTUREGROUP_WORLD_NORMAL_MAP)
    else:
        texture.set_editor_property('srgb', True)
    u.EditorAssetLibrary.save_loaded_asset(texture, False)
    log('texture %s %dx%d %s%s' % (name, texture.blueprint_get_size_x(), texture.blueprint_get_size_y(),
                                   'repeat' if address == u.TextureAddress.TA_WRAP else 'clamp', ' normal' if normal else ''))
    return texture


def import_textures():
    textures = {}
    for paint in INFO['paints']:
        if 'texture' not in paint:
            continue
        # Hull and deck textures cover their surface once; the superstructure plating repeats.
        address = u.TextureAddress.TA_WRAP if paint['tiling'] else u.TextureAddress.TA_CLAMP
        textures[paint['name']] = import_texture(paint['texture'], Path(paint['texture']).stem, address)
        if 'normal' in paint:
            textures[paint['name'] + '_N'] = import_texture(paint['normal'], Path(paint['normal']).stem, address, normal=True)
        for livery, filename in paint.get('variants', {}).items():
            textures[paint['name'] + '_' + livery] = import_texture(filename, Path(filename).stem, address)
    return textures


def import_mesh():
    task = u.AssetImportTask()
    task.filename = str(IMPORT / 'Bismarck.obj')
    task.destination_path = FOLDER + '/Meshes'
    task.destination_name = 'Bismarck'
    task.automated = True
    task.replace_existing = True
    task.replace_existing_settings = True
    task.save = False
    options = u.FbxImportUI()
    options.import_mesh = True
    options.import_materials = False
    options.import_textures = False
    options.import_as_skeletal = False
    options.mesh_type_to_import = u.FBXImportType.FBXIT_STATIC_MESH
    data = options.static_mesh_import_data
    data.combine_meshes = True
    data.import_uniform_scale = 100.0
    data.convert_scene = True
    # Y-up OBJ with the bow along +Z, turned as the VIIC: bow along +X, starboard +Y, Z up.
    data.import_rotation = u.Rotator(roll=90, pitch=0, yaw=90)
    data.auto_generate_collision = False
    data.generate_lightmap_u_vs = False
    data.normal_import_method = u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS
    task.options = options
    assets.import_asset_tasks([task])
    mesh = u.load_asset(FOLDER + '/Meshes/Bismarck')
    if not isinstance(mesh, u.StaticMesh):
        raise RuntimeError('Mesh import failed')
    box = mesh.get_bounding_box()
    size = (box.max.x - box.min.x, box.max.y - box.min.y, box.max.z - box.min.z)
    want = (INFO['size_m'][2] * 100, INFO['size_m'][0] * 100, INFO['size_m'][1] * 100)
    log('mesh triangles=%d slots=%d size_cm=%.0f x %.0f x %.0f keel_cm=%.0f bow_cm=%.0f' % (
        mesh.get_num_triangles(0), len(mesh.static_materials), size[0], size[1], size[2], box.min.z, box.max.x))
    if any(abs(g - w) > 5 for g, w in zip(size, want)) or abs(box.min.z + 1000) > 5 or abs(box.max.x - 12525) > 5:
        raise RuntimeError('Unexpected mesh size or orientation (cm): %s, keel %.0f, bow %.0f' % (size, box.min.z, box.max.x))
    # The bounding box is symmetric fore and aft: check the bow through the main mast's truck, the tallest
    # point, which stands 19 m aft of amidships (so at x ≈ -1930 cm with the bow along +X).
    want_x = INFO['main_mast_top_m'][2] * 100
    try:
        description = mesh.get_static_mesh_description(0)
        top = max((description.get_vertex_position(u.VertexID(i)) for i in range(description.get_vertex_count())),
                  key=lambda v: v.z)
    except Exception as error:
        top = None
        log('bow direction not checked: %s' % error)
    if top is not None:
        log('main mast truck at x=%.0f z=%.0f cm (expected x=%.0f)' % (top.x, top.z, want_x))
        if abs(top.x - want_x) > 100:
            raise RuntimeError('The bow is not along +X: tallest point at x=%.0f cm' % top.x)
    report['mesh'] = dict(triangles=mesh.get_num_triangles(0), size_cm=size, keel_cm=box.min.z,
                          main_mast_x_cm=top.x if top is not None else None)
    return mesh


def flag_motion(material):
    """World position offset making the ensign wave: sideways ripples running from the hoist to the fly,
    growing towards the fly (u of the texture), 1.3 per second."""
    def expr(cls, x, y):
        return mel.create_material_expression(material, cls, x, y)
    uv = expr(u.MaterialExpressionTextureCoordinate, -1400, 600)
    mask = expr(u.MaterialExpressionComponentMask, -1250, 600)
    for c, on in (('r', True), ('g', False), ('b', False), ('a', False)):
        mask.set_editor_property(c, on)
    mel.connect_material_expressions(uv, '', mask, '')
    time = expr(u.MaterialExpressionTime, -1250, 700)
    along = expr(u.MaterialExpressionMultiply, -1100, 600); along.set_editor_property('const_b', 2.2)
    mel.connect_material_expressions(mask, '', along, 'A')
    rate = expr(u.MaterialExpressionMultiply, -1100, 700); rate.set_editor_property('const_b', 1.3)
    mel.connect_material_expressions(time, '', rate, 'A')
    phase = expr(u.MaterialExpressionSubtract, -950, 650)
    mel.connect_material_expressions(along, '', phase, 'A')
    mel.connect_material_expressions(rate, '', phase, 'B')
    wave = expr(u.MaterialExpressionSine, -800, 650); wave.set_editor_property('period', 1.0)
    mel.connect_material_expressions(phase, '', wave, '')
    grow = expr(u.MaterialExpressionMultiply, -650, 650)
    mel.connect_material_expressions(wave, '', grow, 'A')
    mel.connect_material_expressions(mask, '', grow, 'B')
    size = expr(u.MaterialExpressionMultiply, -500, 650); size.set_editor_property('const_b', 30.0)
    mel.connect_material_expressions(grow, '', size, 'A')
    zero = expr(u.MaterialExpressionConstant, -650, 800)
    xy = expr(u.MaterialExpressionAppendVector, -350, 700)
    mel.connect_material_expressions(zero, '', xy, 'A')
    mel.connect_material_expressions(size, '', xy, 'B')
    xyz = expr(u.MaterialExpressionAppendVector, -250, 700)
    mel.connect_material_expressions(xy, '', xyz, 'A')
    mel.connect_material_expressions(zero, '', xyz, 'B')
    # the cloth lies in the ship's length and height: ripple across it (local Y), turned into world space
    world = expr(u.MaterialExpressionTransform, -150, 700)
    world.set_editor_property('transform_source_type', u.MaterialVectorCoordTransformSource.TRANSFORMSOURCE_LOCAL)
    world.set_editor_property('transform_type', u.MaterialVectorCoordTransform.TRANSFORM_WORLD)
    mel.connect_material_expressions(xyz, '', world, '')
    mel.connect_material_property(world, '', u.MaterialProperty.MP_WORLD_POSITION_OFFSET)


def material_for(paint, textures, livery=None):
    name = 'M_' + paint['name'] + ('_' + livery if livery else '')
    path = '%s/Materials/%s' % (FOLDER, name)
    material = u.load_asset(path)
    if material is None:
        material = assets.create_asset(name, FOLDER + '/Materials', u.Material, u.MaterialFactoryNew())
    else:
        mel.delete_all_material_expressions(material)
    if 'texture' in paint:
        node = mel.create_material_expression(material, u.MaterialExpressionTextureSample, -500, 0)
        node.set_editor_property('texture', textures[paint['name'] + ('_' + livery if livery else '')])
        mel.connect_material_property(node, 'RGB', u.MaterialProperty.MP_BASE_COLOR)
    else:
        # MTL colours are sRGB, material constants linear.
        node = mel.create_material_expression(material, u.MaterialExpressionConstant3Vector, -500, 0)
        node.set_editor_property('constant', u.LinearColor(*[srgb_to_linear(c) for c in paint['srgb']], 1))
        mel.connect_material_property(node, '', u.MaterialProperty.MP_BASE_COLOR)
    if 'normal' in paint:
        node = mel.create_material_expression(material, u.MaterialExpressionTextureSample, -500, 450)
        node.set_editor_property('texture', textures[paint['name'] + '_N'])
        node.set_editor_property('sampler_type', u.MaterialSamplerType.SAMPLERTYPE_NORMAL)
        mel.connect_material_property(node, 'RGB', u.MaterialProperty.MP_NORMAL)
    for key, prop, y in (('roughness', u.MaterialProperty.MP_ROUGHNESS, 200), ('metallic', u.MaterialProperty.MP_METALLIC, 300)):
        node = mel.create_material_expression(material, u.MaterialExpressionConstant, -300, y)
        node.set_editor_property('r', float(paint[key]))
        mel.connect_material_property(node, '', prop)
    if paint['paint'] == 'ensign':
        flag_motion(material)
    mel.recompile_material(material)
    u.EditorAssetLibrary.save_loaded_asset(material, False)
    return material


def apply_materials(mesh, textures):
    paints = {p['name']: p for p in INFO['paints']}
    slots = []
    for slot, entry in enumerate(mesh.static_materials):
        source = str(entry.material_slot_name)
        if source not in paints and entry.material_interface:
            source = entry.material_interface.get_name()
        if source not in paints:
            raise RuntimeError('Unmapped material slot %d: %s' % (slot, entry))
        material = material_for(paints[source], textures)
        for livery in paints[source].get('variants', {}):
            variant = material_for(paints[source], textures, livery)
            if livery == LIVERY:
                material = variant
        mesh.set_material(slot, material)
        slots.append(source)
    u.EditorAssetLibrary.save_loaded_asset(mesh, False)
    log('slots ' + ' '.join(slots) + ', livery ' + LIVERY)
    report['slots'] = slots
    report['livery'] = LIVERY


def place(mesh):
    found = [a for a in actors.get_all_level_actors() if a.get_actor_label().startswith('Bismarck')]
    if len(found) > 1:
        raise RuntimeError('Several Bismarck actors')
    if found:
        ship = found[0]
    else:
        ship = actors.spawn_actor_from_class(u.StaticMeshActor, LOCATION, ROTATION)
        ship.set_actor_label(LABEL)
    ship.static_mesh_component.set_static_mesh(mesh)
    for slot in range(len(mesh.static_materials)):
        ship.static_mesh_component.set_material(slot, None)
    ship.set_actor_location(LOCATION, False, False)
    ship.set_actor_rotation(ROTATION, False)
    return ship


def frame_start_camera():
    for actor in actors.get_all_level_actors():
        if isinstance(actor, u.PlayerStart):
            actor.set_actor_location(CAMERA[0], False, False)
            actor.set_actor_rotation(CAMERA[1], False)
    editor.set_level_viewport_camera_info(*CAMERA)


def repair_water():
    """A copied world keeps pointing at the source's water zone, and needs its WaterInfo meshes rebuilt
    (as the coast variant did in repair_coast_water.py)."""
    all_actors = actors.get_all_level_actors()
    zone = next(a for a in all_actors if isinstance(a, u.WaterZone))
    ocean = next(a for a in all_actors if isinstance(a, u.WaterBodyOcean))
    water = ocean.water_body_component
    water.set_water_zone_override(zone)
    settings = water.get_editor_property('static_mesh_settings')
    enabled = settings.get_editor_property('enable_water_body_static_mesh')
    water.set_water_body_static_mesh_enabled(not enabled)
    water.set_water_body_static_mesh_enabled(enabled)
    info = [c for c in ocean.get_components_by_class(u.StaticMeshComponent)
            if c.get_class().get_name() == 'WaterBodyInfoMeshComponent']
    if not info or any(c.static_mesh is None for c in info):
        raise RuntimeError('WaterInfo meshes missing: the full editor is required')
    extent = zone.get_editor_property('zone_extent')
    zone.set_editor_property('zone_extent', u.Vector2D(extent.x + 1, extent.y + 1))
    zone.set_editor_property('zone_extent', extent)
    log('water zone retargeted, %d WaterInfo meshes' % len(info))


def port():
    before = digests()
    if not open_level():
        return
    textures = import_textures()
    mesh = import_mesh()
    apply_materials(mesh, textures)
    ship = place(mesh)
    design = float_bismarck.make_float(ship)
    frame_start_camera()
    repair_water()
    if not level.save_current_level():
        raise RuntimeError('Level not saved')
    u.EditorAssetLibrary.save_directory(FOLDER, only_if_is_dirty=True, recursive=True)
    dirty = [p.get_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()] + \
            [p.get_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
    if dirty:
        log('left unsaved: ' + ', '.join(dirty))
    after = digests()
    changed = [p for p in PROTECTED if before.get(p) != after.get(p)]
    if changed:
        raise RuntimeError('Protected files changed: ' + ', '.join(changed))
    origin, extent = ship.get_actor_bounds(False)
    report.update(level=LEVEL, actor=ship.get_actor_label(),
                  location_cm=[LOCATION.x, LOCATION.y, LOCATION.z], yaw=ROTATION.yaw,
                  bounds_origin_cm=[origin.x, origin.y, origin.z], bounds_extent_cm=[extent.x, extent.y, extent.z],
                  mass_t=float_bismarck.MASS_KG / 1000, gm_m=float_bismarck.GM_T / 100, kg_m=float_bismarck.KG / 100,
                  pontoons=len(design['pontoons']), pontoon_radius_cm=design['radius'],
                  periods_s=dict(zip(('heave', 'roll', 'pitch'), design['periods'])),
                  protected_unchanged=sorted(after), unsaved=dirty)
    (ROOT / 'Docs' / 'bismarck-port.json').write_text(json.dumps(report, indent=2, ensure_ascii=False))
    log('COMPLETE')


def tick(delta):
    if state['busy']:
        return
    state['busy'] = True
    try:
        now = time.monotonic() - start
        if state['phase'] == 'warmup' and now >= WARMUP:
            try:
                port()
            except Exception:
                log('FAILED\n' + traceback.format_exc())
            state.update(phase='quit', end=now + 5)
        elif state['phase'] == 'quit' and now >= state['end']:
            u.unregister_slate_post_tick_callback(handle)
            log('QUIT')
            u.SystemLibrary.quit_editor()
    finally:
        state['busy'] = False


handle = u.register_slate_post_tick_callback(tick)
log('STARTED')
