"""Install the optional coastline's photographed rock material; full editor only.
Original map, boat, waves, buoyancy and the previous procedural material are preserved.
"""
from pathlib import Path
import hashlib
import json
import unreal as u
ROOT=Path(u.Paths.project_dir()).resolve()
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
assert world.get_path_name().startswith('/Game/Demo/AtlanticCoast.'), 'AtlanticCoast only'
assets=u.AssetToolsHelpers.get_asset_tools()
mel=u.MaterialEditingLibrary
DIR='/Game/Demo/Scenery/SeasideRock'
manifest=json.loads((ROOT/'Import/SeasideRock/source.json').read_text())
textures={}
for key,meta in manifest['files'].items():
    filename=meta['url'].rsplit('/',1)[-1]
    source=ROOT/'Import/SeasideRock'/filename
    assert hashlib.md5(source.read_bytes()).hexdigest()==meta['md5'], filename
    name=source.stem
    path=DIR+'/'+name
    if not u.EditorAssetLibrary.does_asset_exist(path):
        task=u.AssetImportTask()
        task.filename=str(source);task.destination_path=DIR
        task.destination_name=name;task.automated=True;task.save=True
        assets.import_asset_tasks([task])
    tex=u.load_asset(path)
    assert isinstance(tex,u.Texture2D), path
    tex.set_editor_property('srgb',key=='Diffuse')
    tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_DEFAULT if key=='Diffuse' else u.TextureCompressionSettings.TC_MASKS)
    tex.set_editor_property('max_texture_size',2048)
    u.EditorAssetLibrary.save_loaded_asset(tex)
    textures[key]=tex
path='/Game/Demo/Scenery/CoastalRockPBR'
m=u.load_asset(path) if u.EditorAssetLibrary.does_asset_exist(path) else assets.create_asset('CoastalRockPBR','/Game/Demo/Scenery',u.Material,u.MaterialFactoryNew())
mel.delete_all_material_expressions(m)
m.set_editor_property('tangent_space_normal',False)
def expr(cls,x,y):return mel.create_material_expression(m,cls,x,y)
def scalar(name,value,x,y):
    e=expr(u.MaterialExpressionScalarParameter,x,y)
    e.set_editor_property('parameter_name',name);e.set_editor_property('default_value',value)
    return e
def custom(code,inputs,out,x,y,label):
    e=expr(u.MaterialExpressionCustom,x,y)
    e.set_editor_property('description',label)
    e.set_editor_property('output_type',out)
    items=[]
    for name,source in inputs.items():
        i=u.CustomInput();i.set_editor_property('input_name',name);items.append(i)
    e.set_editor_property('inputs',items);e.set_editor_property('code',code)
    for name,source in inputs.items():assert mel.connect_material_expressions(source,'',e,name),name
    return e
pos=expr(u.MaterialExpressionWorldPosition,-1400,0)
normal=expr(u.MaterialExpressionVertexNormalWS,-1400,180)
size=scalar('RockTileCm',200,-1400,360)
relief=scalar('ReliefCm',4,-1400,500)
moisture=scalar('DampHeightCm',260,-1400,640)
macro=expr(u.MaterialExpressionNoise,-1150,800)
macro.set_editor_property('scale',0.00013);macro.set_editor_property('levels',2)
mel.connect_material_expressions(pos,'',macro,'Position')
texnodes={}
for idx,(key,tex) in enumerate(textures.items()):
    e=expr(u.MaterialExpressionTextureObject,-1100,-250-idx*180)
    e.set_editor_property('texture',tex)
    e.set_editor_property('sampler_type',u.MaterialSamplerType.SAMPLERTYPE_COLOR if key=='Diffuse' else u.MaterialSamplerType.SAMPLERTYPE_MASKS)
    texnodes[key]=e
# Object-independent projection blends three planar samples and keeps cliffs unstretched.
common='''
float3 weights=pow(abs(N),4.0); weights/=max(dot(weights,float3(1,1,1)),0.0001);
float3 p=W/max(Tile,1.0);
'''
sample=lambda t: f'(Texture2DSample({t},{t}Sampler,p.yz)*weights.x + Texture2DSample({t},{t}Sampler,p.xz)*weights.y + Texture2DSample({t},{t}Sampler,p.xy)*weights.z)'
inputs={'W':pos,'N':normal,'Tile':size,'Macro':macro,'Damp':moisture}
base=custom(common+'float3 rock='+sample('Rock')+'.rgb; p/=16.0; float3 broad='+sample('Rock')+'.rgb;'+'''
float large=saturate(Macro);
float turf=smoothstep(0.64,0.9,N.z)*smoothstep(350.0,2200.0,W.z)*(0.55+0.25*large);
float3 moss=float3(0.039,0.055,0.021)*(0.75+large*0.45);
float wet=1.0-smoothstep(-80.0,Damp*(0.7+0.6*large),W.z);
rock=lerp(rock,broad,0.55)*(0.78+0.35*large);
return lerp(rock,moss,turf)*(1.0-0.42*wet);
''',dict(inputs,Rock=texnodes['Diffuse']),u.CustomMaterialOutputType.CMOT_FLOAT3,-450,0,'Seaside rock / slope turf / irregular damp shore')
rough=custom(common+'float rough='+sample('Rough')+'.r;'+'''
float wet=1.0-smoothstep(-80.0,Damp*(0.7+0.6*saturate(Macro)),W.z);
return lerp(max(rough*0.68,0.40),clamp(rough,0.65,0.98),1.0-wet);
''',dict(inputs,Rough=texnodes['Rough']),u.CustomMaterialOutputType.CMOT_FLOAT1,-450,350,'Measured dry roughness, damp rock')
bump=custom(common+'float h='+sample('Height')+'.r; p/=16.0; float broadHeight='+sample('Height')+'.r; h+=broadHeight*10.0;'+'''
float3 dpdx=ddx(W),dpdy=ddy(W);
float3 r1=cross(dpdy,N),r2=cross(N,dpdx);
float det=dot(dpdx,r1);
float3 grad=sign(det)*(ddx(h)*r1+ddy(h)*r2)*Relief;
return normalize(max(abs(det),0.00001)*N-grad);
''',dict(W=pos,N=normal,Tile=size,Height=texnodes['Displacement'],Relief=relief),u.CustomMaterialOutputType.CMOT_FLOAT3,-450,700,'World-space relief from photographed height')
for node,prop in [(base,u.MaterialProperty.MP_BASE_COLOR),(rough,u.MaterialProperty.MP_ROUGHNESS),(bump,u.MaterialProperty.MP_NORMAL)]:
    assert mel.connect_material_property(node,'',prop)
mel.recompile_material(m)
u.EditorAssetLibrary.save_loaded_asset(m)
land=next(a for a in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors() if a.get_actor_label().startswith('Côte'))
land.static_mesh_component.set_material(0,m)
u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
u.log('COAST_PBR_APPLIED')
