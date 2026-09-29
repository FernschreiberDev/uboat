from pathlib import Path
import unreal as u
root=Path(u.Paths.project_dir())
assets=u.AssetToolsHelpers.get_asset_tools()
mel=u.MaterialEditingLibrary
all_actors=u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
boat=next(a for a in all_actors if a.get_actor_label().startswith('VIIC'))
mesh=boat.static_mesh_component.static_mesh
materials={}
current=None
for line in (root/'Import'/'VIIC.mtl').read_text().splitlines():
    p=line.split()
    if not p: continue
    if p[0]=='newmtl':
        current=p[1]; materials[current]={}
    elif current: materials[current][p[0]]=p[1:]
for slot, entry in enumerate(mesh.static_materials):
    source=str(entry.material_slot_name)
    if source not in materials:
        source=entry.material_interface.get_name()
    if source not in materials:
        raise RuntimeError('Unmapped material slot: '+str(entry))
    params=materials[source]
    name='Naval_'+source
    mat=u.load_asset('/Game/Demo/Materials/'+name)
    if mat is None:
        mat=assets.create_asset(name,'/Game/Demo/Materials',u.Material,u.MaterialFactoryNew())
        color=mel.create_material_expression(mat,u.MaterialExpressionConstant3Vector,-500,0)
        # Kd is sRGB, a material constant is linear.
        rgb=[c/12.92 if c<=0.04045 else ((c+0.055)/1.055)**2.4 for c in (float(v) for v in params.get('Kd',['0.3']*3))]
        color.set_editor_property('constant',u.LinearColor(*rgb,1))
        if 'map_Kd' in params:
            texname='TEX_'+Path(params['map_Kd'][0]).stem
            tex=u.load_asset('/Game/Demo/Meshes/'+texname)
            if tex is None: raise RuntimeError('Missing texture '+texname)
            node=mel.create_material_expression(mat,u.MaterialExpressionTextureSample,-500,0)
            node.texture=tex
            mel.connect_material_property(node,'RGB',u.MaterialProperty.MP_BASE_COLOR)
        else: mel.connect_material_property(color,'',u.MaterialProperty.MP_BASE_COLOR)
        for field,prop in [('Pr',u.MaterialProperty.MP_ROUGHNESS),('Pm',u.MaterialProperty.MP_METALLIC)]:
            node=mel.create_material_expression(mat,u.MaterialExpressionConstant,-250,200)
            node.set_editor_property('r',float(params.get(field,['0.5'])[0]))
            mel.connect_material_property(node,'',prop)
        mel.recompile_material(mat)
    boat.static_mesh_component.set_material(slot,mat)
for actor in all_actors:
    if isinstance(actor,u.PostProcessVolume):
        s=actor.settings
        s.auto_exposure_min_brightness=13.8
        s.auto_exposure_max_brightness=13.8
        actor.settings=s
    if isinstance(actor,u.PlayerStart):
        actor.set_actor_location(u.Vector(-5500,-7000,1250),False,False)
        actor.set_actor_rotation(u.Rotator(pitch=-7,yaw=52,roll=0),False)
u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(-5500,-7000,1250),u.Rotator(pitch=-7,yaw=52,roll=0))
u.EditorLevelLibrary.editor_set_game_view(True)
u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
u.EditorAssetLibrary.save_directory('/Game/Demo')
u.log('DEMO_REFINED')
# Independent ocean instances; never modify Epic plugin assets.
for actor in all_actors:
    if isinstance(actor,u.WaterBodyOcean):
        ocean=u.load_asset('/Game/Demo/Materials/AtlanticWater')
        if ocean is None:
            ocean=assets.create_asset('AtlanticWater','/Game/Demo/Materials',u.MaterialInstanceConstant,u.MaterialInstanceConstantFactoryNew())
            mel.set_material_instance_parent(ocean,u.load_asset('/Water/Materials/WaterSurface/Water_Material_Ocean'))
        for name,value in {
            'Scattering':u.LinearColor(0.5,0.65,0.72,0.045),
            'Absorption':u.LinearColor(30,65,85,8),
            'Water Albedo':u.LinearColor(0.035,0.06,0.075,0.5)
        }.items(): mel.set_material_instance_vector_parameter_value(ocean,name,value)
        for name,value in {'Water Roughness':0.09,'Water Fresnel Roughness':0.12,'Default Near Normal Strength':0.4,'Default Distant Normal Strength':0.4}.items():
            mel.set_material_instance_scalar_parameter_value(ocean,name,value)
        actor.water_body_component.set_water_material(ocean)
rock=assets.create_asset('AtlanticRock','/Game/Demo/Materials',u.Material,u.MaterialFactoryNew())
if rock:
    position=mel.create_material_expression(rock,u.MaterialExpressionWorldPosition,-700,0)
    noise=mel.create_material_expression(rock,u.MaterialExpressionNoise,-500,0)
    noise.set_editor_property('scale',0.0007)
    noise.set_editor_property('levels',3)
    mel.connect_material_expressions(position,'',noise,'Position')
    blend=mel.create_material_expression(rock,u.MaterialExpressionLinearInterpolate,-200,0)
    for pin,rgb in [('A',(0.045,0.05,0.052)),('B',(0.11,0.105,0.085))]:
        color=mel.create_material_expression(rock,u.MaterialExpressionConstant3Vector,-500,200)
        color.set_editor_property('constant',u.LinearColor(*rgb,1))
        mel.connect_material_expressions(color,'',blend,pin)
    mel.connect_material_expressions(noise,'',blend,'Alpha')
    mel.connect_material_property(blend,'',u.MaterialProperty.MP_BASE_COLOR)
    rough=mel.create_material_expression(rock,u.MaterialExpressionConstant,-200,300)
    rough.r=0.92
    mel.connect_material_property(rough,'',u.MaterialProperty.MP_ROUGHNESS)
    mel.recompile_material(rock)
    for actor in all_actors:
        if actor.get_actor_label().startswith('Côte'): actor.static_mesh_component.set_material(0,rock)
u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
u.EditorAssetLibrary.save_directory('/Game/Demo')
u.log('DEMO_OCEAN_REFINED')
