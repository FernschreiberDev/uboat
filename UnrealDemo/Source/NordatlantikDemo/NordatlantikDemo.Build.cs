using UnrealBuildTool;
public class NordatlantikDemo : ModuleRules {
 public NordatlantikDemo(ReadOnlyTargetRules Target) : base(Target) {
  PCHUsage=PCHUsageMode.UseExplicitOrSharedPCHs;
  PublicDependencyModuleNames.AddRange(new string[]{"Core","CoreUObject","Engine","InputCore","Water","AudioMixer"});
 }
}
