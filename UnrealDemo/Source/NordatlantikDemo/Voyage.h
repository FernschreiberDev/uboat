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

// Per-map settings of the exploration: start, play area, objectives, save slot. AtlanticVoyage keeps
// its original values; /Game/Lorient/LorientKeroman starts in Keroman III (Import/Lorient/layout.json).
struct FVoyageMission {
 FString Title=TEXT("NORDATLANTIK  /  EXPLORATION");
 FString SlotBase=TEXT("NordatlantikVoyage");
 FString Welcome=TEXT("Bienvenue a bord — H : commandes");
 FString Home=TEXT("Retour au mouillage — decouvertes conservees");
 FVector Start=FVector(0,0,-190);
 float StartYaw=-90;
 FVector2D Center=FVector2D::ZeroVector;
 float Radius=200000;       // cm, play area
 float ChartRadius=100000;  // cm shown by the chart's radius
 bool Harbour=false;        // pens and quays: traces start below roofs, walls are traced sideways
 FVector Goals[3]={FVector(0,-35000,0),FVector(28000,-62000,-4500),FVector(6000,34000,0)};
 FString Names[3]={TEXT("Balise du large"),TEXT("Epave a 45 metres"),TEXT("Rendez-vous avec le Bismarck")};
 // Smoke test: where it starts, points it must find blocked, and approach offsets to each goal.
 FVector TestStart=FVector::ZeroVector; bool TestTeleport=false;
 FVector TestBlocked=FVector(80000,50000,-190);
 FVector TestOffsets[3]={FVector(0,0,-190),FVector(-7000,0,-190),FVector(0,-7800,-190)};
 static FVoyageMission ForMap(const FString& MapName);
};

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
 FVoyageMission Mission;
 FVector Goal(int32 Index) const{return Mission.Goals[Index%3];}
 const FString& GoalName(int32 Index) const{return Mission.Names[Index%3];}
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
