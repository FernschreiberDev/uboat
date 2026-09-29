#pragma once
#include <algorithm>
#include <cmath>
// Visual/actuator model. Rates and control gains are game approximations;
// angle stops follow the VIIC manual (electric rudder: 33 degrees).
struct FGearDynamics {
 float RPM=0,Phase=0,Rudder=0,Bow=0,Stern=0;
 static float Approach(float current,float target,float delta){return current+std::clamp(target-current,-delta,delta);}
 void Step(float dt,float throttle,float helm,float depthError,float verticalSpeed,float forwardSpeed,bool submerged){
  dt=std::clamp(dt,0.f,.1f);
  float target=std::clamp(throttle,-.3f,1.f)*(submerged?280.f:470.f);
  // Reverse only after crossing zero; no instantaneous shaft reversal.
  RPM=Approach(RPM,target,dt*65.f);
  Phase=std::fmod(Phase+RPM*6.f*dt,360.f);
  Rudder=Approach(Rudder,std::clamp(helm,-1.f,1.f)*33.f,dt*5.f);
  // Depth error drives the bow down / stern up, with vertical-rate damping.
  // Reverse the foil incidence in sternway. At rest the depth assist remains responsible.
  float demand=submerged?std::clamp(depthError*1.8f+verticalSpeed*.06f,-25.f,25.f):0.f;
  float flow=forwardSpeed<-.3f?-1.f:1.f;
  Bow=Approach(Bow,std::clamp(demand*flow,-30.f,30.f),dt*6.f);
  Stern=Approach(Stern,std::clamp(-demand*flow,-25.f,35.f),dt*6.f);
 }
};
