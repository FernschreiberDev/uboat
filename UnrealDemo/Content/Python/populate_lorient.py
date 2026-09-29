"""Second pass: turn the copy of AtlanticVoyage into the Lorient roadstead and the Keroman base.

Run in the full rendering editor with /Game/Lorient/LorientKeroman open (a commandlet cannot build
the ocean's WaterInfo meshes). Inputs come from Import/Lorient (Tools/generate-lorient.py):
- OBJ meshes in metres, imported like the VIIC (roll 90, yaw 90, 100 cm per unit): east on +X,
  south on +Y, up on +Z. Each import is checked against its expected bounds, so a mirrored or
  rotated import stops the script instead of producing a wrong map.
- textures (colour sRGB, DirectX normals, ORM masks) and the land-cover map of the terrain;
- layout.json: the player's pen in Keroman III, the moored or docked VIICs, the objectives.

The player's VIIC, its buoyancy Blueprint and the Voyage game mode are kept from AtlanticVoyage;
the boat is only moved into its pen. The island, cliffs, wreck, beacon and Bismarck of the copy are
removed. Scenery gets query-only collision on its real triangles (complex as simple): the game's
safety traces then see the quays, pens and banks, and nothing pushes the floating hull.
"""
from pathlib import Path
import json
import unreal as u

ROOT = Path(u.Paths.project_dir()).resolve()
SRC = ROOT / 'Import' / 'Lorient'
MAP = '/Game/Lorient/LorientKeroman'
MESH_DIR = '/Game/Lorient/Meshes'
TEX_DIR = '/Game/Lorient/Textures'
MAT_DIR = '/Game/Lorient/Materials'
PREFIX = 'Lorient — '

world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
if not world.get_path_name().startswith(MAP + '.'):
    raise RuntimeError('Open /Game/Lorient/LorientKeroman in the full editor first (Tools/build-lorient.sh)')
sub = u.get_editor_subsystem(u.EditorActorSubsystem)
level = u.get_editor_subsystem(u.LevelEditorSubsystem)
assets = u.AssetToolsHelpers.get_asset_tools()
mel = u.MaterialEditingLibrary
layout = json.loads((SRC / 'layout.json').read_text())
report = json.loads((SRC / 'generation-report.json').read_text())


def log(text):
    u.log('LORIENT: ' + text)


actors = sub.get_all_level_actors()
if any(a.get_actor_label().startswith(PREFIX) for a in actors):
    raise RuntimeError('LorientKeroman is already populated; refusing to run twice')
boat = next(a for a in actors if 'VoyageVIIC' in [str(t) for t in a.tags])
boat_mesh = boat.static_mesh_component.static_mesh

# ------------------------------------------------------------------ clean-up
removed = []
for a in actors:
    if a == boat or not isinstance(a, u.StaticMeshActor):
        continue
    removed.append(a.get_actor_label())
    sub.destroy_actor(a)
log('removed %d static mesh actors of the Atlantic island: %s' % (len(removed), ', '.join(removed)))

# ------------------------------------------------------------------ textures
def texture(name, kind):
    """kind: 'color', 'normal', 'mask', 'map' (land cover, clamped, sRGB), 'datamap' (clamped, linear)."""
    path = TEX_DIR + '/' + name
    if not u.EditorAssetLibrary.does_asset_exist(path):
        source = next(SRC.joinpath('Textures').glob(name + '.*'))
        t = u.AssetImportTask()
        t.filename = str(source); t.destination_path = TEX_DIR; t.destination_name = name
        t.automated = True; t.save = True; t.replace_existing = True
        assets.import_asset_tasks([t])
    tex = u.load_asset(path)
    assert isinstance(tex, u.Texture2D), path
    tex.set_editor_property('srgb', kind in ('color', 'map'))
    tex.set_editor_property('compression_settings', {
        'normal': u.TextureCompressionSettings.TC_NORMALMAP,
        'mask': u.TextureCompressionSettings.TC_MASKS,
        'datamap': u.TextureCompressionSettings.TC_MASKS,
    }.get(kind, u.TextureCompressionSettings.TC_DEFAULT))
    if kind in ('map', 'datamap'):
        tex.set_editor_property('address_x', u.TextureAddress.TA_CLAMP)
        tex.set_editor_property('address_y', u.TextureAddress.TA_CLAMP)
        tex.set_editor_property('max_texture_size', 4096)
    else:
        tex.set_editor_property('max_texture_size', 1024)
    u.EditorAssetLibrary.save_loaded_asset(tex)
    return tex


# ------------------------------------------------------------------ materials
def new_material(name):
    path = MAT_DIR + '/' + name
    m = u.load_asset(path) if u.EditorAssetLibrary.does_asset_exist(path) else \
        assets.create_asset(name, MAT_DIR, u.Material, u.MaterialFactoryNew())
    mel.delete_all_material_expressions(m)
    return m


def custom(m, code, inputs, out, x, y, label):
    e = mel.create_material_expression(m, u.MaterialExpressionCustom, x, y)
    e.set_editor_property('description', label)
    e.set_editor_property('output_type', out)
    items = []
    for name in inputs:
        i = u.CustomInput(); i.set_editor_property('input_name', name); items.append(i)
    e.set_editor_property('inputs', items)
    e.set_editor_property('code', code)
    for name, (source, pin) in inputs.items():
        assert mel.connect_material_expressions(source, pin, e, name), name
    return e


def pbr_material(name, two_sided=False):
    """Colour x world-space macro variation (breaks up tiling), ORM masks, DirectX normals."""
    m = new_material('M_' + name)
    m.set_editor_property('two_sided', two_sided)
    color = mel.create_material_expression(m, u.MaterialExpressionTextureSample, -700, 0)
    color.set_editor_property('texture', texture('T_%s_D' % name, 'color'))
    color.set_editor_property('sampler_type', u.MaterialSamplerType.SAMPLERTYPE_COLOR)
    orm = mel.create_material_expression(m, u.MaterialExpressionTextureSample, -700, 260)
    orm.set_editor_property('texture', texture('T_%s_ORM' % name, 'mask'))
    orm.set_editor_property('sampler_type', u.MaterialSamplerType.SAMPLERTYPE_MASKS)
    normal = mel.create_material_expression(m, u.MaterialExpressionTextureSample, -700, 520)
    normal.set_editor_property('texture', texture('T_%s_N' % name, 'normal'))
    normal.set_editor_property('sampler_type', u.MaterialSamplerType.SAMPLERTYPE_NORMAL)
    pos = mel.create_material_expression(m, u.MaterialExpressionWorldPosition, -1000, -200)
    macro = mel.create_material_expression(m, u.MaterialExpressionNoise, -800, -250)
    macro.set_editor_property('scale', 0.0009); macro.set_editor_property('levels', 3)
    mel.connect_material_expressions(pos, '', macro, 'Position')
    base = custom(m, 'return T * (0.82 + 0.36 * saturate(Macro));', {'T': (color, 'RGB'), 'Macro': (macro, '')},
                  u.CustomMaterialOutputType.CMOT_FLOAT3, -300, 0, 'Large-scale weathering variation')
    mel.connect_material_property(base, '', u.MaterialProperty.MP_BASE_COLOR)
    mel.connect_material_property(orm, 'R', u.MaterialProperty.MP_AMBIENT_OCCLUSION)
    mel.connect_material_property(orm, 'G', u.MaterialProperty.MP_ROUGHNESS)
    mel.connect_material_property(orm, 'B', u.MaterialProperty.MP_METALLIC)
    mel.connect_material_property(normal, 'RGB', u.MaterialProperty.MP_NORMAL)
    mel.recompile_material(m)
    u.EditorAssetLibrary.save_loaded_asset(m)
    return m


def flat_material(name, rgb, rough):
    m = new_material('M_' + name)
    c = mel.create_material_expression(m, u.MaterialExpressionConstant3Vector, -300, 0)
    c.set_editor_property('constant', u.LinearColor(*rgb, 1))
    mel.connect_material_property(c, '', u.MaterialProperty.MP_BASE_COLOR)
    r = mel.create_material_expression(m, u.MaterialExpressionConstant, -300, 200)
    r.set_editor_property('r', rough)
    mel.connect_material_property(r, '', u.MaterialProperty.MP_ROUGHNESS)
    mel.recompile_material(m)
    u.EditorAssetLibrary.save_loaded_asset(m)
    return m


def terrain_material():
    """Land-cover map over the whole roadstead, detailed by tiling grain chosen by its mask."""
    m = new_material('M_LorientTerrain')
    uv = mel.create_material_expression(m, u.MaterialExpressionTextureCoordinate, -1100, 0)
    pos = mel.create_material_expression(m, u.MaterialExpressionWorldPosition, -1100, 150)
    nodes = {}
    for i, (key, name, kind) in enumerate([('L', 'T_LorientLandcover_D', 'map'), ('M', 'T_LorientLandcover_M', 'datamap'),
                                            ('D', 'T_LorientGroundDetail', 'mask')]):
        e = mel.create_material_expression(m, u.MaterialExpressionTextureObject, -1100, 320 + i * 180)
        e.set_editor_property('texture', texture(name, kind))
        e.set_editor_property('sampler_type', u.MaterialSamplerType.SAMPLERTYPE_COLOR if kind == 'map' else u.MaterialSamplerType.SAMPLERTYPE_MASKS)
        nodes[key] = e
    inputs = {'UV': (uv, ''), 'W': (pos, ''), 'L': (nodes['L'], ''), 'M': (nodes['M'], ''), 'D': (nodes['D'], '')}
    base = custom(m, '''
float3 c = Texture2DSample(L, LSampler, UV).rgb;
float4 k = Texture2DSample(M, MSampler, UV);
float4 d = Texture2DSample(D, DSampler, W.xy / 700.0);
float4 d2 = Texture2DSample(D, DSampler, W.xy / 3100.0);
float w = max(k.r + k.g + k.b + k.a, 0.001);
float detail = (k.r * (0.72 + 0.56 * d.r) + k.g * (0.86 + 0.28 * d.a) + k.b * (0.8 + 0.4 * d.b) + k.a * (0.7 + 0.6 * d.a)) / w;
return c * lerp(1.0, detail, 0.85) * (0.9 + 0.2 * d2.g);
''', inputs, u.CustomMaterialOutputType.CMOT_FLOAT3, -400, 0, 'Land cover with grass, paving, mud and rock grain')
    rough = custom(m, '''
float4 k = Texture2DSample(M, MSampler, UV);
return lerp(0.93, 0.42, saturate(k.b)) - 0.1 * k.g;
''', {'UV': (uv, ''), 'M': (nodes['M'], '')}, u.CustomMaterialOutputType.CMOT_FLOAT1, -400, 300, 'Wet foreshore and seabed are glossier')
    mel.connect_material_property(base, '', u.MaterialProperty.MP_BASE_COLOR)
    mel.connect_material_property(rough, '', u.MaterialProperty.MP_ROUGHNESS)
    mel.recompile_material(m)
    u.EditorAssetLibrary.save_loaded_asset(m)
    return m


materials = {
    'LorientTerrain': terrain_material(),
    'LorientGroix': flat_material('LorientGroix', (0.07, 0.085, 0.055), 0.95),
    'KeromanConcrete': pbr_material('KeromanConcrete'),
    'KeromanRoof': pbr_material('KeromanRoof'),
    'KeromanQuay': pbr_material('KeromanQuay'),
    'KeromanSteel': pbr_material('KeromanSteel'),
    'LorientMasonry': pbr_material('LorientMasonry', two_sided=True),   # ruined walls are seen from both sides
    'LorientSlate': pbr_material('LorientSlate'),
    'LorientTrees': pbr_material('LorientTrees'),
    'BuoyRed': flat_material('BuoyRed', (0.45, 0.02, 0.01), 0.5),
    'BuoyGreen': flat_material('BuoyGreen', (0.01, 0.2, 0.04), 0.5),
}
log('materials ready')

# ------------------------------------------------------------------ meshes
# Scenery the safety traces must see; slate roofs, trees and buoys stay out of the way.
COLLIDES = {'LorientTerrain', 'KeromanConcrete', 'KeromanRoof', 'KeromanQuay', 'KeromanSteel', 'LorientMasonry'}
NANITE = {'LorientTerrain', 'LorientMasonry', 'LorientSlate', 'LorientTrees'}


def import_mesh(name):
    task = u.AssetImportTask()
    task.filename = str(SRC / (name + '.obj'))
    task.destination_path = MESH_DIR; task.destination_name = name
    task.automated = True; task.save = True; task.replace_existing = True
    options = u.FbxImportUI()
    options.import_materials = False; options.import_textures = False; options.import_as_skeletal = False
    options.mesh_type_to_import = u.FBXImportType.FBXIT_STATIC_MESH
    data = options.static_mesh_import_data
    data.combine_meshes = True
    data.import_uniform_scale = 100.0
    data.import_rotation = u.Rotator(roll=90, pitch=0, yaw=90)
    data.auto_generate_collision = False
    try:
        data.set_editor_property('generate_lightmap_u_vs', False)    # Lumen: no lightmaps
    except Exception as error:
        log('lightmap UV option unavailable: %s' % error)
    task.options = options
    assets.import_asset_tasks([task])
    mesh = u.load_asset(MESH_DIR + '/' + name)
    if not isinstance(mesh, u.StaticMesh):
        raise RuntimeError('Import failed: ' + name)
    # Expected bounds from the generator, in Unreal axes: X = east, Y = -north, Z = up.
    lo, hi = report['meshes'][name]['min_m'], report['meshes'][name]['max_m']
    want_min = u.Vector(lo[0] * 100, -hi[1] * 100, lo[2] * 100)
    want_max = u.Vector(hi[0] * 100, -lo[1] * 100, hi[2] * 100)
    box = mesh.get_bounding_box()
    for axis in 'xyz':
        for got, want in ((getattr(box.min, axis), getattr(want_min, axis)), (getattr(box.max, axis), getattr(want_max, axis))):
            if abs(got - want) > 150:
                raise RuntimeError('%s imported with unexpected bounds %s (expected %s .. %s): wrong axes?' % (name, box, want_min, want_max))
    if name in COLLIDES:
        body = mesh.get_editor_property('body_setup')
        body.set_editor_property('collision_trace_flag', u.CollisionTraceFlag.CTF_USE_COMPLEX_AS_SIMPLE)
    if name in NANITE:
        try:
            nanite = mesh.get_editor_property('nanite_settings')
            nanite.set_editor_property('enabled', True)
            mesh.set_editor_property('nanite_settings', nanite)
        except Exception as error:
            log('Nanite not enabled on %s: %s' % (name, error))
    mesh.set_material(0, materials[name])
    u.EditorAssetLibrary.save_loaded_asset(mesh)
    log('%s imported, %d triangles' % (name, report['meshes'][name]['triangles']))
    return mesh


LABELS = {
    'LorientTerrain': 'terrain et fonds de la rade', 'LorientGroix': 'ile de Groix (lointain)',
    'KeromanConcrete': 'beton des blocs K1, K2, K3 et Dombunker', 'KeromanRoof': 'toitures et Fangrost',
    'KeromanQuay': 'quais, slips et terre-pleins', 'KeromanSteel': 'portes, transbordeur, rails et grues',
    'LorientMasonry': 'maconnerie (citadelle, villes, ruines)', 'LorientSlate': 'toits d ardoise',
    'LorientTrees': 'arbres et haies', 'BuoyRed': 'balises rouges du chenal', 'BuoyGreen': 'balises vertes du chenal',
}
for name in materials:
    mesh = import_mesh(name)
    a = sub.spawn_actor_from_class(u.StaticMeshActor, u.Vector(0, 0, 0), u.Rotator())
    a.set_actor_label(PREFIX + LABELS[name])
    c = a.static_mesh_component
    c.set_static_mesh(mesh)
    c.set_material(0, materials[name])
    if name in COLLIDES:
        c.set_collision_enabled(u.CollisionEnabled.QUERY_ONLY)
        c.set_collision_response_to_all_channels(u.CollisionResponseType.ECR_IGNORE)
        c.set_collision_response_to_channel(u.CollisionChannel.ECC_VISIBILITY, u.CollisionResponseType.ECR_BLOCK)
    else:
        c.set_collision_enabled(u.CollisionEnabled.NO_COLLISION)

# ------------------------------------------------------------------ boats
def place(actor, loc, yaw):
    actor.set_actor_location(u.Vector(*loc), False, True)
    actor.set_actor_rotation(u.Rotator(roll=0, pitch=0, yaw=yaw), True)


for p in layout['viic_props']:
    a = sub.spawn_actor_from_class(u.StaticMeshActor, u.Vector(*p['location']), u.Rotator(yaw=p['yaw']))
    a.set_actor_label(PREFIX + p['label'])
    c = a.static_mesh_component
    c.set_static_mesh(boat_mesh)
    c.set_collision_enabled(u.CollisionEnabled.QUERY_ONLY)
    c.set_collision_response_to_all_channels(u.CollisionResponseType.ECR_IGNORE)
    c.set_collision_response_to_channel(u.CollisionChannel.ECC_VISIBILITY, u.CollisionResponseType.ECR_BLOCK)
place(boat, layout['player']['location'], layout['player']['yaw'])
boat.set_actor_label('VIIC — alveole 4 de Keroman III')
for a in sub.get_all_level_actors():
    if isinstance(a, u.PlayerStart):
        loc = layout['player']['location']
        place(a, (loc[0] - 9000, loc[1], 2500), layout['player']['yaw'])
log('player VIIC in K3 pen 4 at %s, %d other VIICs placed' % (layout['player']['location'], len(layout['viic_props'])))

# ------------------------------------------------------------------ water
actors = sub.get_all_level_actors()
zone = next(a for a in actors if isinstance(a, u.WaterZone))
ocean = next(a for a in actors if isinstance(a, u.WaterBodyOcean))
water = ocean.water_body_component
# One zone over the roadstead, the open sea and the Ile de Groix (24 km).
CENTER = u.Vector(-200000, 400000, 0)
zone.set_actor_location(CENTER, False, True)
zone.set_editor_property('zone_extent', u.Vector2D(2400000, 2400000))
ocean.set_actor_location(CENTER, False, True)
water.set_editor_property('ocean_extents', u.Vector2D(2400000, 2400000))
# The ocean spline outlines "land": a small square inland, north-west of Lorient.
spline = ocean.spline_comp
spline.clear_spline_points(False)
for x, y in [(-270000, -200000), (-270000, -160000), (-230000, -160000), (-230000, -200000)]:
    spline.add_spline_point(u.Vector(x, y, 0), u.SplineCoordinateSpace.WORLD, False)
spline.set_closed_loop(True, True)
# Sheltered roadstead: a calmer copy of the ocean's Gerstner waves (the engine asset is untouched).
try:
    wpath = '/Game/Lorient/Water/GerstnerWaves_Rade'
    if not u.EditorAssetLibrary.does_asset_exist(wpath):
        u.EditorAssetLibrary.duplicate_asset('/Water/Waves/GerstnerWaves_Ocean', wpath)
    wasset = u.load_asset(wpath)
    waves = wasset.get_editor_property('WaterWaves')
    gen = waves.get_editor_property('gerstner_wave_generator')
    for prop, factor in (('min_amplitude', 0.35), ('max_amplitude', 0.35), ('max_wavelength', 0.6)):
        gen.set_editor_property(prop, gen.get_editor_property(prop) * factor)
    waves.set_editor_property('gerstner_wave_generator', gen)       # triggers the wave recomputation
    u.EditorAssetLibrary.save_loaded_asset(wasset)
    ocean.set_water_waves(waves)
    log('roadstead waves: amplitudes x0.35, wavelengths x0.6')
except Exception as error:
    log('WAVES_KEPT: ocean waves unchanged (%s)' % error)
# Rebuild the WaterInfo meshes (rendering editor only), as repair_coast_water.py does.
settings = water.get_editor_property('static_mesh_settings')
was_enabled = settings.get_editor_property('enable_water_body_static_mesh')
water.set_water_body_static_mesh_enabled(not was_enabled)
water.set_water_body_static_mesh_enabled(was_enabled)
water.set_water_zone_override(zone)
extent = zone.get_editor_property('zone_extent')
zone.set_editor_property('zone_extent', u.Vector2D(extent.x + 1, extent.y + 1))
zone.set_editor_property('zone_extent', extent)

# ------------------------------------------------------------------ save
start = layout['player']['location']
u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(start[0] + 30000, start[1] + 22000, 6000), u.Rotator(pitch=-9, yaw=-145, roll=0))
level.save_current_level()
for folder in (MESH_DIR, TEX_DIR, MAT_DIR):
    u.EditorAssetLibrary.save_directory(folder)
result = dict(map=MAP, removed=removed, meshes={k: report['meshes'][k]['triangles'] for k in materials},
              player=layout['player'], props=len(layout['viic_props']))
(ROOT / 'Saved').mkdir(exist_ok=True)
(ROOT / 'Saved' / 'lorient-built.json').write_text(json.dumps(result, indent=1, ensure_ascii=False))
u.log('LORIENT_MAP_BUILT')
u.SystemLibrary.quit_editor()
