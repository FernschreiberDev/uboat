from pathlib import Path
import unreal as u
u.get_editor_subsystem(u.LevelEditorSubsystem).editor_set_viewport_realtime(True)
u.get_editor_subsystem(u.LevelEditorSubsystem).editor_invalidate_viewports()
path = str(Path(u.Paths.project_dir()).resolve()/'Docs'/'Atlantic-demo.png')
u.log('DEMO_VIEW: '+str(u.get_editor_subsystem(u.UnrealEditorSubsystem).get_level_viewport_camera_info()))
task = u.AutomationLibrary.take_high_res_screenshot(1600,900,path)
u.log('DEMO_SCREENSHOT_TASK: '+str(task))
u.SystemLibrary.execute_console_command(u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world(),'HighResShot 1600x900 filename='+path)
