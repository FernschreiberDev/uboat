#include "../Source/NordatlantikDemo/OceanSoundDSP.h"
#include <cassert>
#include <cstdio>
#include <fstream>
#include <vector>
void wav(const char* path,const std::vector<int16_t>& data){std::ofstream f(path,std::ios::binary);auto u=[&](uint32_t n,int bytes){for(int i=0;i<bytes;i++)f.put((n>>(i*8))&255);};f.write("RIFF",4);u(36+data.size()*2,4);f.write("WAVEfmt ",8);u(16,4);u(1,2);u(2,2);u(48000,4);u(192000,4);u(4,2);u(16,2);f.write("data",4);u(data.size()*2,4);f.write((const char*)data.data(),data.size()*2);}
int main(){
 FOceanSoundDSP s;float out[2];double energy[4]={},peak=0,step=0,last=0;std::vector<int16_t> pcm;
 for(int section=0;section<4;section++)for(int i=0;i<48000*5;i++){
  s.Frame(48000,section==3?0:.75,section==0?0:section==1?400:180,section>=2?1:0,section>=2?1:0,section==0?0:12,.8,out);
  for(float v:out){assert(std::isfinite(v)&&std::abs(v)<.86);pcm.push_back(int16_t(v*32767));peak=std::max(peak,double(std::abs(v)));}
  if(i>48000)energy[section]+=out[0]*out[0];
  step=std::max(step,double(std::abs(out[0]-last)));last=out[0];
 }
 assert(energy[0]>1 && energy[1]>energy[0] && energy[2]>1 && energy[3]<energy[2]*.0001);
 wav("/private/tmp/uboat-audio-preview.wav",pcm);
 printf("PASS: stereo finite, peak %.3f, max adjacent delta %.3f; surface/engine/submerged/mute energy %.2f %.2f %.2f %.8f\n",peak,step,energy[0],energy[1],energy[2],energy[3]);
}
