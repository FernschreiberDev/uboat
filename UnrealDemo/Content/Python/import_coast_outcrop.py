"""Import photographed cliff textures and material; geometry is imported separately by LOD."""
from pathlib import Path
import json
import unreal as u
ROOT=Path(u.Paths.project_dir()).resolve()
DIR='/Game/Demo/Scenery/CoastalCliff01'
assets=u.AssetToolsHelpers.get_asset_tools();mel=u.MaterialEditingLibrary
source=ROOT/'Import/CoastalCliff01'
textures={}
for key,suffix in [('color','diff'),('rough','rough'),('normal','nor_dx')]:
 name='coastal_cliff_01_'+suffix+'_2k';path=DIR+'/'+name
 if not u.EditorAssetLibrary.does_asset_exist(path):
  t=u.AssetImportTask();t.filename=str(source/(name+'.jpg'));t.destination_path=DIR;t.destination_name=name;t.automated=True;t.save=True
  assets.import_asset_tasks([t])
 tex=u.load_asset(path)
 tex.set_editor_property('srgb',key=='color')
 tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_NORMALMAP if key=='normal' else (u.TextureCompressionSettings.TC_DEFAULT if key=='color' else u.TextureCompressionSettings.TC_MASKS))
 tex.set_editor_property('max_texture_size',2048)
 u.EditorAssetLibrary.save_loaded_asset(tex);textures[key]=tex
path=DIR+'/CoastalCliffSurface'
m=u.load_asset(path) if u.EditorAssetLibrary.does_asset_exist(path) else assets.create_asset('CoastalCliffSurface',DIR,u.Material,u.MaterialFactoryNew())
mel.delete_all_material_expressions(m)
for i,key in enumerate(['color','rough','normal']):
 e=mel.create_material_expression(m,u.MaterialExpressionTextureSample,-500,i*220)
 e.set_editor_property('texture',textures[key]);e.set_editor_property('sampler_type',u.MaterialSamplerType.SAMPLERTYPE_NORMAL if key=='normal' else (u.MaterialSamplerType.SAMPLERTYPE_COLOR if key=='color' else u.MaterialSamplerType.SAMPLERTYPE_MASKS))
 if key=='normal':mel.connect_material_property(e,'RGB',u.MaterialProperty.MP_NORMAL);continue
 w=mel.create_material_expression(m,u.MaterialExpressionWorldPosition,-500,700+i*100)
 shade=mel.create_material_expression(m,u.MaterialExpressionCustom,0,i*220)
 shade.set_editor_property('output_type',u.CustomMaterialOutputType.CMOT_FLOAT3 if key=='color' else u.CustomMaterialOutputType.CMOT_FLOAT1)
 items=[]
 for name in ['T','W']:
  inp=u.CustomInput();inp.set_editor_property('input_name',name);items.append(inp)
 shade.set_editor_property('inputs',items)
 damp='float wet=1.0-smoothstep(-60.0,210.0+50.0*sin(W.x*0.007+W.y*0.009),W.z);'
 shade.set_editor_property('code',damp+('return T*(1.0-0.38*wet);' if key=='color' else 'return lerp(max(T.r*0.65,0.4),max(T.r,0.65),1.0-wet);'))
 mel.connect_material_expressions(e,'RGB',shade,'T');mel.connect_material_expressions(w,'',shade,'W')
 mel.connect_material_property(shade,'',u.MaterialProperty.MP_BASE_COLOR if key=='color' else u.MaterialProperty.MP_ROUGHNESS)
mel.recompile_material(m);u.EditorAssetLibrary.save_loaded_asset(m)
u.log('COAST_OUTCROP_MATERIAL_IMPORTED')
