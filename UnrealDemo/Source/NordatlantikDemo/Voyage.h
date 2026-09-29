#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/HUD.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/SaveGame.h"
#include "GameFramework/PlayerController.h"
#include "GearDynamics.h"
#include "Voyage.generated.h"
class UVoyageAudio;
class UStaticMeshComponent;
class UBuoyancyComponent;
class UCameraComponent;
class USpringArmComponent;

UCLASS()
class NORDATLANTIKDEMO_API AVoyageController : public APlayerController {
 GENERATED_BODY()
public:
 AVoyageController(){bShouldPerformFullTickWhenPaused=true;}
 virtual void SetupInputComponent() override;
};

UCLASS()
class NORDATLANTIKDEMO_API UVoyageSave : public USaveGame {
 GENERATED_BODY()
public:
 UPROPERTY() float SoundVolume=.75f;
 UPROPERTY() bool SoundMuted=false;
 UPROPERTY() int32 Version=1;
 UPROPERTY() FVector Position=FVector(0,0,-190);
 UPROPERTY() float Heading=-90;
 UPROPERTY() float TargetDepth=0;
 UPROPERTY() int32 Discoveries=0;
 UPROPERTY() float Distance=0;
};

UCLASS()
class NORDATLANTIKDEMO_API AVoyagePawn : public APawn {
 GENERATED_BODY()
public:
 AVoyagePawn();
 virtual void BeginPlay() override;
 virtual void Tick(float DeltaTime) override;
 virtual void EndPlay(const EEndPlayReason::Type Reason) override;
 virtual void SetupPlayerInputComponent(UInputComponent* Input) override;
 UPROPERTY() UVoyageAudio* Soundscape=nullptr;
 float SoundVolume=.75f; bool SoundMuted=false;
 void UpdateSound(); void SoundToggle(); void SoundUp(); void SoundDown();
 void SetupGear(); void UpdateGear(float Dt); void ToggleGear(); void GearCamera();
 FGearDynamics Gear;
 UPROPERTY() TArray<UStaticMeshComponent*> GearMeshes;
 bool Articulated=true;
 int32 GearView=0;
 void Pause(); void Save(); void SaveManual(); void Reset(); void Surface(); void Stop(); void NextObjective(); void Recenter(); void Help();
 bool ReadSave();
 UPROPERTY() UStaticMeshComponent* Hull=nullptr;
 UPROPERTY() UBuoyancyComponent* Buoyancy=nullptr;
 UPROPERTY() AActor* Boat=nullptr;
 UPROPERTY() USpringArmComponent* Arm=nullptr;
 UPROPERTY() UCameraComponent* Camera=nullptr;
 float Throttle=0,TargetDepth=0,Distance=0,Speed=0,Depth=0;
 float Heading=-90,Orbit=0,Elevation=-16,Zoom=10000;
 float SaveClock=0,NoticeClock=0,Elapsed=0;
 FString Notice;
 int32 Discoveries=0,Selected=0;
 bool ShowHelp=true,DiveControl=false,Ready=false,Smoke=false,ResumeTest=false;
 FVector LastSafe=FVector(0,0,-190);
 static FVector Goal(int32 Index);
 static FString GoalName(int32 Index);
 FString Slot() const;
 void Notify(const FString& Text);
 void SmokeTick(float DeltaTime);
private:
 int32 TestStage=0;
 FVector TestStart;
 float TestHeading=0;
 bool TestMoved=false,TestTurned=false,TestDived=false;
 float Rudder=0;
 void PollControls(float DeltaTime);
 bool SafeAt(const FVector& Position) const;
 void TestFail(const FString& Why);
};

UCLASS()
class NORDATLANTIKDEMO_API AVoyageHUD : public AHUD {
 GENERATED_BODY()
public:
 virtual void DrawHUD() override;
};

UCLASS()
class NORDATLANTIKDEMO_API AVoyageGameMode : public AGameModeBase {
 GENERATED_BODY()
public:
 AVoyageGameMode();
};
