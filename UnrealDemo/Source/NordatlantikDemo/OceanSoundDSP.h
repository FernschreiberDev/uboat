#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
// Original procedural sound design, no recordings or external sample licences.
struct FOceanSoundDSP {
 float Master=0,RPM=0,Water=0,Electric=0,Speed=0,Near=0;
 double T=0,Phase=0;uint32_t Seed=0x517ca321;
 float Surf[2]={},Deep[2]={},Filtered[2]={},Churn[2]={};
 float Noise(){Seed^=Seed<<13;Seed^=Seed>>17;Seed^=Seed<<5;return float(Seed)/2147483648.f-1.f;}
 void Frame(float rate,float master,float rpm,float water,float electric,float speed,float near,float* out){
  const float smooth=1.f-std::exp(-1.f/(rate*.18f));
  Master+=(master-Master)*smooth;RPM+=(std::abs(rpm)-RPM)*smooth;Water+=(water-Water)*smooth;Electric+=(electric-Electric)*smooth;Speed+=(speed-Speed)*smooth;Near+=(near-Near)*smooth;
  T+=1./rate;Phase=std::fmod(Phase+(RPM/60.*3.)/rate,1.);
  const double tau=6.283185307179586;
  const float power=std::clamp(RPM/470.f,0.f,1.f),running=std::clamp(RPM/35.f,0.f,1.f);
  float pulse=std::pow(.5f+.5f*std::cos(tau*Phase),6.f);
  float diesel=(.17f*std::sin(tau*Phase)+.09f*std::sin(tau*Phase*2)+.08f*std::sin(tau*Phase*4))*(.7f+.3f*pulse);
  float electricHum=.12f*std::sin(tau*Phase*4)+.045f*std::sin(tau*Phase*8);
  float swell=.35f+.65f*std::pow(.5f+.5f*std::sin(T*.87+1.3*std::sin(T*.19)),2.f);
  const float lp=1.f-std::exp(-tau*(Water*650+(1-Water)*9000)/rate);
  for(int c=0;c<2;c++){
   float n=Noise();Surf[c]+=.12f*(n-Surf[c]);Deep[c]+=.004f*(n-Deep[c]);Churn[c]+=.035f*(n-Churn[c]);
   float waves=(Surf[c]*.65f+n*.025f)*swell;
   float spray=(n-Surf[c])*.05f*std::clamp(Speed/17.f,0.f,1.f);
   float underwater=Deep[c]*1.1f+Churn[c]*.16f*(.4f+.6f*std::pow(.5f+.5f*std::sin(T*2.3+c*.8),8.f));
   float engine=((1-Electric)*(diesel+n*.055f*pulse)+Electric*(electricHum+Churn[c]*.035f))*running*(.4f+.6f*power)*Near;
   float screw=Churn[c]*.22f*running*Near*(.4f+.6f*std::cos(tau*Phase)*std::cos(tau*Phase));
   float v=waves*(1-Water)+spray*(1-Water)+underwater*Water+engine+screw*Water;
   Filtered[c]+=lp*(v-Filtered[c]);
   out[c]=std::tanh(Filtered[c]*1.8f)*Master*.85f;
  }
 }
};
