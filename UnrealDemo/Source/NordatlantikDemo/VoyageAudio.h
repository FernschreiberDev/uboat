#pragma once
#include "CoreMinimal.h"
#include "Components/SynthComponent.h"
#include "OceanSoundDSP.h"
#include <atomic>
#include "VoyageAudio.generated.h"
UCLASS()
class NORDATLANTIKDEMO_API UVoyageAudio : public USynthComponent {
 GENERATED_BODY()
public:
 UVoyageAudio(const FObjectInitializer& Init):Super(Init){NumChannels=2;bAutoActivate=false;bAllowSpatialization=false;bIsUISound=true;}
 void SetEnvironment(float volume,float rpm,float water,float electric,float speed,float proximity){Volume.store(volume);RPM.store(rpm);Water.store(water);Electric.store(electric);Speed.store(speed);Near.store(proximity);}
 std::atomic<uint64_t> Frames{0},AudibleFrames{0};
protected:
 virtual bool Init(int32& SampleRate) override {Rate=SampleRate;return true;}
 virtual int32 OnGenerateAudio(float* Out,int32 Count) override;
private:
 FOceanSoundDSP DSP;float Rate=48000;
 std::atomic<float> Volume{0},RPM{0},Water{0},Electric{0},Speed{0},Near{0};
};
