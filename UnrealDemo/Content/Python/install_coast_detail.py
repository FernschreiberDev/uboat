"""Rebuild only the optional scenery, in the full editor with AtlanticCoast open."""
from pathlib import Path
import runpy,unreal as u
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
assert world.get_path_name().startswith('/Game/Demo/AtlanticCoast.')
root=Path(u.Paths.project_dir())/'Content/Python'
for name in ['apply_coast_pbr.py','import_coast_outcrop.py','import_cliff_lod_sources.py','optimize_coast_outcrop.py','place_coast_outcrops.py']:
 runpy.run_path(str(root/name))
