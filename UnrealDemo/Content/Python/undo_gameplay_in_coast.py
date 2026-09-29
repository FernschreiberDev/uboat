"""Undo exactly our eight misplaced gameplay actors and property edits.
The baseline is the audited untouched snapshot. No source mesh or physics asset is saved.
"""
from pathlib import Path
import json,unreal as u
root=Path(u.Paths.project_dir())
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
assert world.get_path_name().startswith('/Game/Demo/AtlanticCoast.')
audit=json.loads((root/'Docs/voyage-copy-audit.json').read_text())
baseline={a['label']:a for a in audit['/Game/Voyage/AtlanticVoyage']['actors']}
expected={a['label']:a for a in audit['/Game/Demo/AtlanticCoast']['actors']}
sub=u.get_editor_subsystem(u.EditorActorSubsystem)
actors={a.get_actor_label():a for a in sub.get_all_level_actors()}
assert set(actors)==set(expected), 'Unexpected edits: stop instead of removing them'
extra=set(expected)-set(baseline)
assert len(extra)==8
assert (root/'Saved/VoyageRecovery/CoastBeforeCorrection.umap').exists()
for label in extra:assert sub.destroy_actor(actors[label])
world.get_world_settings().set_editor_property('default_game_mode',None)
for label,row in baseline.items():
 actor=actors[label]
 actor.set_editor_property('tags',[u.Name(t) for t in row['tags']])
 if 'collision' in row:
  c=actor.static_mesh_component
  assert (c.static_mesh.get_path_name() if c.static_mesh else None)==row['mesh']
  for key in ['NO_COLLISION','QUERY_ONLY','PHYSICS_ONLY','QUERY_AND_PHYSICS']:
   if key in row['collision']:
    c.set_collision_enabled(getattr(u.CollisionEnabled,key));break
assert len(sub.get_all_level_actors())==19
u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
(root/'Docs/coast-restoration.json').write_text(json.dumps({'method':'scoped rollback against untouched audited snapshot','removed_only_our_actors':sorted(extra),'source_actor_count':19,'game_mode_override':None,'restored_tags_and_collision':True},indent=2))
u.log('COAST_SCOPED_ROLLBACK_COMPLETE')
u.SystemLibrary.quit_editor()
