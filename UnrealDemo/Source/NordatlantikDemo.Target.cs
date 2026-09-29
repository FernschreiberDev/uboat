using UnrealBuildTool;
public class NordatlantikDemoTarget : TargetRules {
 public NordatlantikDemoTarget(TargetInfo Target) : base(Target) {
  Type=TargetType.Game; DefaultBuildSettings=BuildSettingsVersion.Latest;
  ExtraModuleNames.Add("NordatlantikDemo");
 }
}
