#include "VoyageAudio.h"
int32 UVoyageAudio::OnGenerateAudio(float* Out,int32 Count){
 const float v=Volume.load(),r=RPM.load(),w=Water.load(),e=Electric.load(),s=Speed.load(),n=Near.load();
 uint64_t audible=0;
 for(int32 i=0;i+1<Count;i+=2){DSP.Frame(Rate,v,r,w,e,s,n,Out+i);if(FMath::Abs(Out[i])+FMath::Abs(Out[i+1])>.0001f)audible++;}
 if(Count%2)Out[Count-1]=0;
 Frames.fetch_add(Count/2);AudibleFrames.fetch_add(audible);return Count;
}
