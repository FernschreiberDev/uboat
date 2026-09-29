import unreal as u
from pathlib import Path
import json
result={}
level=u.get_editor_subsystem(u.LevelEditorSubsystem)
for name in ['AtlanticDemo','AtlanticCoast']:
    level.load_level('/Game/Demo/'+name)
    data=[]
    for actor in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
        if not isinstance(actor,(u.WaterZone,u.WaterBodyOcean)): continue
        row={'actor':actor.get_actor_label(),'position':str(actor.get_actor_location()),'hidden':actor.get_editor_property('hidden')}
        components=actor.get_components_by_class(u.PrimitiveComponent)
        row['components']=[]
        for c in components:
            item={'name':c.get_name(),'class':c.get_class().get_name()}
            for prop in ['visible','hidden_in_game','render_in_main_pass','render_in_depth_pass','cast_shadow','far_distance_material','far_distance_mesh_extent','water_material','water_zone_override','ocean_extents']:
                try: item[prop]=str(c.get_editor_property(prop))
                except Exception: pass
            row['components'].append(item)
        data.append(row)
    result[name]=data
(Path(u.Paths.project_dir())/'Docs/water-diagnostic.json').write_text(json.dumps(result,indent=2))
