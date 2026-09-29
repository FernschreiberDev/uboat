from pathlib import Path
import json,unreal as u
out={};level=u.get_editor_subsystem(u.LevelEditorSubsystem)
for path in ['/Game/Voyage/AtlanticVoyage','/Game/Demo/AtlanticCoast']:
 level.load_level(path)
 world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
 rows=[]
 for a in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors():
  row={'label':a.get_actor_label(),'class':a.get_class().get_name(),'tags':[str(t) for t in a.tags]}
  if isinstance(a,u.StaticMeshActor):
   c=a.static_mesh_component;row['mesh']=c.static_mesh.get_path_name() if c.static_mesh else None;row['collision']=str(c.get_collision_enabled())
  rows.append(row)
 gm=world.get_world_settings().get_editor_property('default_game_mode')
 out[path]={'mode':gm.get_path_name() if gm else None,'actors':rows}
(Path(u.Paths.project_dir())/'Docs/voyage-copy-audit.json').write_text(json.dumps(out,indent=2))
u.log('VOYAGE_COPY_AUDIT_COMPLETE')
