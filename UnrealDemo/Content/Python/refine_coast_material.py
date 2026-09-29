"""Refine only the optional scenery material."""
import unreal as u
m=u.load_asset('/Game/Demo/Scenery/StratifiedCoast')
mel=u.MaterialEditingLibrary
for e in mel.get_material_expressions(m):
 if isinstance(e,u.MaterialExpressionNoise):
  old=e.get_editor_property('scale')
  e.set_editor_property('scale',0.00010 if old<0.001 else 0.004)
 if isinstance(e,u.MaterialExpressionCustom):
  if e.get_editor_property('output_type')==u.CustomMaterialOutputType.CMOT_FLOAT3:
   e.set_editor_property('code','''
float large=saturate(Macro);
float fine=saturate(Fine);
float strata=0.5+0.5*sin(W.z*0.010+W.x*0.0006+large*2.0);
float3 rock=float3(0.085,0.091,0.094)*(0.82+0.27*large+0.06*strata+0.04*fine);
float turf=smoothstep(0.62,0.89,N.z)*smoothstep(250.0,1800.0,W.z)*(0.60+0.30*large);
float3 moss=float3(0.046,0.064,0.027)*(0.8+0.35*large);
float wet=1.0-smoothstep(-50.0,250.0+100.0*large,W.z);
return lerp(rock,moss,turf)*(1.0-0.32*wet);
''')
  else:e.set_editor_property('code','return lerp(0.65,0.94,smoothstep(-50.0,300.0,W.z));')
mel.recompile_material(m)
u.EditorAssetLibrary.save_loaded_asset(m)
u.log('COAST_MATERIAL_REFINED')
