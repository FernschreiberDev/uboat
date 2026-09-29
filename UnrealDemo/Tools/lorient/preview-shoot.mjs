// Screenshots of preview.html in headless Chromium (see the comment at the top of preview.html).
import {chromium} from 'playwright-core';
import fs from 'fs';
const views=JSON.parse(process.argv[2]);const outdir=process.argv[3];
const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell',args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const p=await b.newPage({viewport:{width:1600,height:900}});
p.on('console',m=>console.log('page:',m.text()));p.on('pageerror',e=>console.log('ERR',e.message));
await p.goto('http://127.0.0.1:8765/preview/index.html');
await p.waitForFunction('window.ready===true',null,{timeout:900000});
await p.waitForTimeout(3000);
for(const [name,eye,at,fov] of views){const d=await p.evaluate(([e,a,f])=>window.shot(e,a,f),[eye,at,fov||50]);fs.writeFileSync(`${outdir}/${name}.jpg`,Buffer.from(d.split(',')[1],'base64'));console.log('shot',name)}
await b.close();
