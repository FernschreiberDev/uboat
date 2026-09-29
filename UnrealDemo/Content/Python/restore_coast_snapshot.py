"""Restore only our accidental additions, from the audited pre-gameplay copy.
The audited source has 19 actors, no VoyageVIIC tag, and no GameMode override.
Both on-disk maps were backed up in Saved/VoyageRecovery before this script.
"""
from pathlib import Path
import json,unreal as u
SOURCE='/Game/Voyage/AtlanticVoyage'
BACKUP='/Game/VoyageRecovery/CoastSnapshot'
DEST='/Game/Demo/AtlanticCoast'
root=Path(u.Paths.project_dir())
assert (root/'Saved/VoyageRecovery/UnmodifiedCoastCopy.umap').exists()
audit=json.loads((root/'Docs/voyage-copy-audit.json').read_text())
assert audit[SOURCE]['mode'] is None and len(audit[SOURCE]['actors'])==19
assert len(audit[DEST]['actors'])==27
level=u.get_editor_subsystem(u.LevelEditorSubsystem)
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
assert world.get_path_name().startswith(BACKUP+'.')
actors=u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
assert len(actors)==19
assert world.get_world_settings().get_editor_property('default_game_mode') is None
assert all(u.Name('VoyageVIIC') not in a.tags for a in actors)
assert {a.get_actor_label() for a in actors}=={a['label'] for a in audit[SOURCE]['actors']}
# Reconstruct copied water render data in the loaded backup, keeping waves untouched.
ocean=next(a for a in actors if isinstance(a,u.WaterBodyOcean));zone=next(a for a in actors if isinstance(a,u.WaterZone))
ocean.water_body_component.set_water_zone_override(zone)
ocean.water_body_component.set_water_body_static_mesh_enabled(True);ocean.water_body_component.set_water_body_static_mesh_enabled(False)
extent=zone.get_editor_property('zone_extent');zone.set_editor_property('zone_extent',u.Vector2D(extent.x+1,extent.y+1));zone.set_editor_property('zone_extent',extent)
assert u.EditorLoadingAndSavingUtils.save_map(world,DEST)
u.log('COAST_SNAPSHOT_RESTORED_FROM_LOADED_BACKUP')
u.SystemLibrary.quit_editor()
