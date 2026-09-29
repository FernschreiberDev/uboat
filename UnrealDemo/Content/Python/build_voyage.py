"""First pass only: copy the coast without editing it. Restart into the copy
and run populate_voyage.py in a second full-editor session.
"""
from pathlib import Path
import unreal as u
root=Path(u.Paths.project_dir())
dest='/Game/Voyage/AtlanticVoyage'
if u.EditorAssetLibrary.does_asset_exist(dest):
 raise RuntimeError('Playable map already exists; refusing to overwrite')
level=u.get_editor_subsystem(u.LevelEditorSubsystem)
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
if not world.get_path_name().startswith('/Game/Demo/AtlanticCoast.'):
 assert level.load_level('/Game/Demo/AtlanticCoast')
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
assert u.EditorLoadingAndSavingUtils.save_map(world,dest)
# Save Map creates a copy but keeps the source world open. Do not edit it,
# or load the new world in this session (world cleanup can fail).
u.log('VOYAGE_COPY_READY: restart into AtlanticVoyage, then run populate_voyage.py')
u.SystemLibrary.quit_editor()
