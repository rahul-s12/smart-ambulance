import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {FileBlob,PresentationFile} from '@oai/artifact-tool';
const root='D:/Academ/git-local/smart-ambulance';
const skill='C:/Users/rahul/.codex/plugins/cache/openai-primary-runtime/presentations/26.1015.12040/skills/presentations';
const {makeNativeBulletParagraphs}=await import(pathToFileURL(skill+'/container_tools/artifact_tool_utils.mjs').href);
const p=await PresentationFile.importPptx(await FileBlob.load(root+'/output/Smart_Ambulance_Review_2_Restored.pptx'));
const s=p.slides.items[13];
for(const q of [...s.shapes.items])if(q.position.top>=100&&q.position.top<675)q.delete();
const list=s.shapes.add({geometry:'textbox',name:'Conclusion and future work bullets',position:{left:80,top:140,width:1120,height:475},fill:'none',line:{fill:'none',width:0}});
list.text=makeNativeBulletParagraphs([
 'Implemented ESP32 BLE communication and a Flutter app for simulated vitals.',
 'Supported device discovery, encrypted connection and start/stop control.',
 'Integrate physical sensors, OLED and the full RTOS task pipeline.',
 'Add persistent uploads, cloud services and the hospital dashboard.',
 'Develop GPS tracking, ETA estimation and ML risk prediction.'
],{marginLeftPoints:24,hangingPoints:12,spaceAfterPoints:20});
list.text.style={typeface:'Times New Roman',fontSize:35,color:'#111111',autoFit:'none'};
list.text.insets=0;
await (await PresentationFile.exportPptx(p)).save(root+'/.presentation-build/conclusion-authored.pptx');
await fs.writeFile(root+'/.presentation-build/conclusion-bullets.png',new Uint8Array(await (await p.export({slide:s,format:'png',scale:1})).arrayBuffer()));
console.log('Updated conclusion slide');
