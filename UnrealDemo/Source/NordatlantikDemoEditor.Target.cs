using UnrealBuildTool;
public class NordatlantikDemoEditorTarget : TargetRules {
 public NordatlantikDemoEditorTarget(TargetInfo Target) : base(Target) {
  Type=TargetType.Editor; DefaultBuildSettings=BuildSettingsVersion.Latest;
  ExtraModuleNames.Add("NordatlantikDemo");
 }
}
