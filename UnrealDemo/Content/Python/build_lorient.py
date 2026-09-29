"""First pass only: copy AtlanticVoyage (VIIC with its buoyancy, ocean, sky, light, game mode) to the
new map /Game/Lorient/LorientKeroman without editing it. Restart the full editor into the copy and
run populate_lorient.py (Tools/build-lorient.sh chains both passes).
"""
from pathlib import Path
import unreal as u

ROOT = Path(u.Paths.project_dir())
SOURCE = '/Game/Voyage/AtlanticVoyage'
DEST = '/Game/Lorient/LorientKeroman'
if u.EditorAssetLibrary.does_asset_exist(DEST):
    raise RuntimeError('LorientKeroman already exists; refusing to overwrite')
level = u.get_editor_subsystem(u.LevelEditorSubsystem)
world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
if not world.get_path_name().startswith(SOURCE + '.'):
    assert level.load_level(SOURCE)
world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
assert u.EditorLoadingAndSavingUtils.save_map(world, DEST)
# As for AtlanticVoyage: the copy is saved but the source stays open; do not edit it here.
u.log('LORIENT_COPY_READY: restart into LorientKeroman, then run populate_lorient.py')
u.SystemLibrary.quit_editor()
