import unreal as u
from pathlib import Path
import json
out={}
for path in ['/Water/Materials/WaterSurface/Water_Material_Ocean','/Water/Materials/WaterSurface/LODs/Water_Material_Ocean_LOD']:
    m=u.load_asset(path)
    data={}
    for kind in ['vector','scalar']:
        names=getattr(u.MaterialEditingLibrary,'get_'+kind+'_parameter_names')(m)
        data[kind]={str(n):str(getattr(u.MaterialEditingLibrary,('get_material_instance_' if isinstance(m,u.MaterialInstanceConstant) else 'get_material_default_')+kind+'_parameter_value')(m,n)) for n in names}
    out[path]=data
(Path(u.Paths.project_dir())/'Docs'/'water-parameters.json').write_text(json.dumps(out,indent=2))
u.log('DEMO_MATERIAL_AUDIT_COMPLETE')
