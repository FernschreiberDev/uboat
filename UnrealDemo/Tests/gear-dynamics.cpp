#include "../Source/NordatlantikDemo/GearDynamics.h"
#include <cassert>
#include <cstdio>
int main(){
 FGearDynamics s;
 for(int i=0;i<600;i++){float before=s.Rudder;s.Step(1.f/60,1,1,20,0,8,true);assert(std::abs(s.Rudder-before)<=5.f/60+.0001);}
 assert(std::abs(s.RPM-280)<.01 && s.Rudder==33 && s.Bow>0 && s.Stern<0);
 float rpm=s.RPM;s.Step(.05,-.3,-1,-20,0,8,true);assert(s.RPM>0&&s.RPM<rpm);
 for(int i=0;i<1080;i++)s.Step(1.f/60,-.3,-1,-20,0,-2,true);
 assert(s.RPM<0 && s.Rudder==-33 && s.Bow>0 && s.Stern<0);
 for(int i=0;i<1200;i++)s.Step(1.f/60,0,0,0,0,0,false);
 assert(s.RPM==0 && s.Rudder==0 && s.Bow==0 && s.Stern==0);
 float phase=s.Phase;s.Step(0,1,1,30,0,8,true);assert(s.Phase==phase&&s.RPM==0);
 FGearDynamics a,b;for(int i=0;i<300;i++)a.Step(1.f/30,1,1,10,0,5,true);for(int i=0;i<1200;i++)b.Step(1.f/120,1,1,10,0,5,true);
 assert(std::abs(a.RPM-b.RPM)<.01 && std::abs(a.Bow-b.Bow)<.01);
 puts("PASS: servo rate, angle stops, paired planes, ahead/astern, gradual reversal, stop, pause, 30/120 Hz");
}
