import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {FileBlob,PresentationFile} from '@oai/artifact-tool';
const root='D:/Academ/git-local/smart-ambulance';
const skill='C:/Users/rahul/.codex/plugins/cache/openai-primary-runtime/presentations/26.1015.12040/skills/presentations';
const source='D:/Academ/Projects/Major Project 2026-27/Documentation/Phase2/Review 2/Review 2 _ 7th semester_PPT-Template AY 2026-27_October 2026.pptx';
const p=await PresentationFile.importPptx(await FileBlob.load(source));
const originals=[...p.slides.items], slides=[];
const navy='#002060',blue='#0070C0',ink='#111111',font='Times New Roman';
function text(s,t,x,y,w,h,size=32,color=ink,bold=false,align='left',fill='none',border='none'){
 const q=s.shapes.add({geometry:fill==='none'?'textbox':'rect',name:t.slice(0,45),position:{left:x,top:y,width:w,height:h},fill,line:{fill:border,width:border==='none'?0:1.5}});
 q.text=t;q.text.style={typeface:font,fontSize:size,color,bold,alignment:align,verticalAlignment:'middle'};q.text.insets=8;return q;
}
function page(title){
 const s=originals[3].duplicate();slides.push(s);
 for(const im of [...s.images.items])im.delete();
 const titleShape=s.shapes.items.find(q=>q.position.top<100);
 titleShape.text=title;titleShape.position={left:0,top:0,width:1280,height:80};titleShape.text.style={typeface:font,fontSize:54,bold:true,color:'#FFFFFF',alignment:'center'};
 return s;
}
function note(s,t){s.speakerNotes.text=t+'\nSources: current workspace app/lib/main.dart; esp32/components/ble/ble.c, ble_gap.c, ble_gatt.c; esp32/main/main.c. Repository inspection on 19 October 2026. Code presence establishes implementation only. Hardware test outcomes await captured evidence.';}
function foot(s,t){text(s,t,55,615,1170,44,25,blue);}
function table(s,vals,widths,top=145,height=425,size=29){
 const tb=s.tables.add({rows:vals.length,columns:vals[0].length,left:55,top,width:1170,height,columnWidths:widths,values:vals});
 tb.borders.assign({fill:'#CAD2DF',width:1});
 tb.cells.block({row:0,column:0,rowCount:vals.length,columnCount:vals[0].length}).assign({textStyle:{typeface:font,fontSize:size,color:ink},margins:{left:12,right:10,top:10,bottom:10},anchor:'center'});
 for(let r=0;r<vals.length;r++)for(let c=0;c<vals[0].length;c++){const cell=tb.getCell(r,c);cell.fill=r===0?navy:r%2?'#EDF3F9':'#FFFFFF';cell.text.style={typeface:font,fontSize:size,color:r===0?'#FFFFFF':ink,bold:r===0};}
 return tb;
}
function node(s,t,x,y,w=255,h=100,planned=false){return text(s,t,x,y,w,h,29,planned?blue:navy,true,'center',planned?'#FFFFFF':'#EDF3F9',planned?blue:navy);}
function link(s,a,b,vertical=false){s.shapes.connect(a,b,{kind:'straight',fromSide:vertical?'bottom':'right',toSide:vertical?'top':'left',line:{fill:navy,width:2},tail:{type:'arrow',width:'med',length:'med'}});}
const cover=originals[0].duplicate();slides.push(cover);
const cb=cover.shapes.items.find(q=>q.position.top>120&&q.position.top<200);
cb.text='Review 2 Presentation\nEnhancing Emergency Response Through IoT-Integrated\nSmart Ambulance and GPS Monitoring\n\nRahul S (1NT23EC120)     Rakshita S Wagge (1NT23EC124)\n\nProject Supervisor\nDr. Manjula B M, Professor\nDepartment of Electronics and Communication Engineering\nNitte Meenakshi Institute of Technology, Bengaluru';
cb.text.style={typeface:font,fontSize:33,color:ink,alignment:'center'};
note(cover,'Project title and team details retained from the supplied Review 2 template.');
let s=page('Presentation Outline');
['Objectives and system architecture','BLE workflow and design comparison','Requirements and validation plan','Implementation status and evidence','Conclusion and future work'].forEach((v,i)=>text(s,`${i+1}.  ${v}`,90,145+i*86,1120,64,37));
note(s,'Review 2 topics follow the supplied template. Additional slides separate methods, validation and evidence to keep each slide concise.');
s=page('Project Objectives');
[['Communication','BLE gateway with MQTT over TLS and CoAP fallback'],['Monitoring','Integrate patient sensors and local display'],['Concurrency','Coordinate acquisition and communication using RTOS'],['Risk assessment','Develop ML classification of patient deterioration'],['Location and ETA','Track ambulance location and estimate arrival time']].forEach((v,i)=>{text(s,v[0],65,125+i*98,260,80,32,navy,true);text(s,v[1],340,125+i*98,870,80,32);});
note(s,'Objectives preserve the template scope. User explicitly retained ML as an objective and added both GPS location and ETA. These are objectives, not completed results.');
s=page('System Architecture');
let a=node(s,'Patient sensors\nIntegration planned',60,155,260,110,true),b=node(s,'ESP32\nBLE implemented',390,155,260,110),c=node(s,'Flutter gateway\nBLE implemented',800,155,360,110);link(s,a,b);link(s,b,c);
text(s,'OLED and full RTOS pipeline: planned',70,290,660,50,28,blue);
let d=node(s,'Cloud ingestion\nand storage',800,400,360,110,true),e=node(s,'ML risk assessment',410,400,300,110,true),f=node(s,'Hospital dashboard',55,400,270,110,true);link(s,c,d,true);s.shapes.connect(d,e,{kind:'straight',fromSide:'left',toSide:'right',line:{fill:navy,width:2},tail:{type:'arrow'}});s.shapes.connect(e,f,{kind:'straight',fromSide:'left',toSide:'right',line:{fill:navy,width:2},tail:{type:'arrow'}});
text(s,'Phone GPS and ETA: planned gateway functions',70,345,850,45,27,blue);foot(s,'Filled blocks: current BLE prototype     Outlined blocks: planned integration');
note(s,'Target architecture replaces the dense source image with an editable diagram. Current firmware generates simulated observations. Planned phone-to-cloud transport is MQTT over TLS with CoAP fallback. GPS provider, ETA method, backend and ML model remain to be selected.');
s=page('BLE Communication Workflow');
const labels=['Scan for\nSmart_Ambulance','Connect and\nencrypt link','Discover GHSS\nand subscribe','Send Start\ncommand 0x01','Receive simulated\nvital observations','Decode and display\nHR, SpO2, temperature'];
const ns=labels.map((v,i)=>node(s,v,70+(i<3?i:5-i)*410,145+Math.floor(i/3)*250,320,115));link(s,ns[0],ns[1]);link(s,ns[1],ns[2]);link(s,ns[2],ns[3],true);for(const [a,b] of [[ns[3],ns[4]],[ns[4],ns[5]]])s.shapes.connect(a,b,{kind:'straight',fromSide:'left',toSide:'right',line:{fill:navy,width:2},tail:{type:'arrow'}});
text(s,'After subscription, the app enables start/stop control',90,290,1100,60,31,blue);
foot(s,'Stop: 0x02     Disconnect: ESP32 resumes advertising     Reconnect: scan and select again');
note(s,'GHSS UUID 0x1840; observations 0x2B8B; control point 0x2BF4. Firmware creates simulated readings on a nominal one-second task interval. The two rows show setup followed by telemetry, with editable step objects. Automatic app reconnection is not implemented.');
s=page('Methods and Design Comparison');
table(s,[['Design aspect','Current prototype','Target design'],['Device to phone','BLE notifications','Retain BLE gateway'],['Wide-area upload','Not implemented','MQTT/TLS with CoAP fallback'],['Data source','Simulated observations','Integrated physical sensors'],['Patient assessment','Vitals display','ML risk classification'],['Ambulance location','Not implemented','Phone GPS with ETA']],[270,420,480],135,450,29);
foot(s,'BLE supports the local link. Cloud transports require phone internet connectivity.');note(s,'Comparison describes observed implementation versus the user-approved target, without claiming measured superiority over competing protocols. No backend stack or risk model is finalized in the current repository.');
s=page('Functional Requirements');
table(s,[['ID','Required behavior','Implementation'],['FR1','Discover, connect and receive BLE vitals','Code present'],['FR2','Start/stop telemetry from the app','Code present'],['FR3','Acquire sensors and update local OLED','Integration pending'],['FR4','Queue and upload telemetry to cloud','Planned'],['FR5','Provide GPS location and ETA','Planned'],['FR6','Predict risk and show hospital updates','Planned']],[100,730,340],125,480,29);
note(s,'FR1 and FR2 are implemented in source but need hardware evidence. Sensor sketches exist separately. Persistent queueing, cloud transport, GPS, ETA, ML and hospital dashboard are requirements for subsequent integration.');
s=page('Non-Functional Requirements');
table(s,[['Quality','Acceptance check','Evidence needed'],['Security','Encrypted BLE before stream control','ESP32 encryption log'],['Responsiveness','Regular updates without a frozen UI','Timed recording and logs'],['Recovery','Resume telemetry after reconnect','Disconnect/reconnect recording'],['Data integrity','App values match transmitted values','Matched app and serial captures'],['Continuity','Retain unsent readings during outage','Future queue/retry test']],[235,570,365],135,445,29);
foot(s,'Latency, endurance and reliability thresholds remain proposed until measured and agreed.');note(s,'Security code uses LE Secure Connections with Just Works and NVS bonds. This does not establish authenticated protection against active interception. No measured latency, delivery ratio, endurance or clinical accuracy is available.');
s=page('Wi-Fi vs BLE: Design Rationale');
table(s,[['Criterion','Earlier Wi-Fi approach','Selected BLE approach'],['Local connection','ESP32 joins access point or hotspot','ESP32 connects directly to phone'],['Internet gateway','ESP32 manages network uplink','Phone handles cloud uplink (planned)'],['Data workload','Supports higher data throughput','Fits small, periodic vital readings'],['Device setup','Configure SSID and password','Discover device and pair'],['Power rationale','Measure under the same workload','Low-power design; savings unmeasured']],[255,450,465],125,450,28);
foot(s,'BLE fits the phone gateway design. Phone proximity remains a requirement.');
note(s,'Design rationale, not measured Wi-Fi versus BLE test results. The earlier project README describes direct ESP32 Wi-Fi MQTT/TLS upload. The current architecture moves internet upload, GPS and planned buffering to the phone, while BLE carries nearby vital observations. Wi-Fi also supports local communication without internet, and a phone hotspot can provide a Wi-Fi uplink. The selected design removes Wi-Fi credentials and cloud connection handling from the ESP32 local link; it does not establish better latency, reliability, range or measured power consumption. BLE is designed for low-power point-to-point data exchange, including health monitoring. A fair empirical comparison would use the same board, workload, distance and observation duration, recording current draw, delivery ratio, update interval and recovery time. Sources: https://www.bluetooth.com/learn-about-bluetooth/topology-options/ ; https://www.bluetooth.com/bluetooth-le-primer/ ; https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/bluetooth/bt_le.html ; earlier project README at D:/Academ/Projects/Major Project 2026-27/Coding Part/Smart Ambulance/README.md.');
s=page('BLE Test Cases');
table(s,[['Test','Action','Expected observation'],['TC1 / FR1','Scan with ESP32 advertising','Smart_Ambulance appears'],['TC2 / FR1','Select device and pair','Connected and ready status'],['TC3 / FR1','Start telemetry','Vitals update and match logs'],['TC4 / FR2','Tap Stop','Stop acknowledged; updates cease'],['TC5 / FR1','Disconnect, then scan and connect','Telemetry can restart']],[200,450,520],135,445,29);
foot(s,'Execution status: evidence pending. Capture the observed outcome before marking Pass.');note(s,'These cases validate the current BLE prototype. Capture at least two updates for TC3, and a recording or timestamped logs for TC4 and TC5. A stopped app may retain the last displayed values. Reconnection is manual.');
s=page('Planned Integration Tests');
table(s,[['Requirement','Test scenario','Expected result'],['FR3 / Sensors','Connect sensors and OLED','Correct acquisition and local display'],['FR4 / Upload','Lose and restore phone internet','Queue retained and uploaded once'],['FR5 / GPS + ETA','Move along a known route','Location and ETA update'],['FR6 / ML','Evaluate a labeled held-out dataset','Report classification metrics'],['FR6 / Dashboard','Deliver live and stale telemetry','Correct values and freshness state']],[255,475,440],135,445,28);
foot(s,'All cases on this slide are planned. No cloud, GPS, ETA or ML results are claimed.');note(s,'Future tests need a defined telemetry contract and acceptance thresholds. ETA should be compared with actual arrival times on test routes. ML evaluation requires a selected dataset, labels, model and held-out split. Do not invent accuracy figures.');
s=page('Implementation Status');
table(s,[['Module','Current evidence','Remaining work'],['ESP32 BLE','Advertising, encryption, streaming code','Device validation evidence'],['Flutter app','Scan, connect, display, start/stop','Gateway persistence and uploads'],['Sensors / OLED','Separate sensor sketches','Integrate into BLE firmware'],['RTOS','BLE host and simulation tasks','Full acquisition/display pipeline'],['Cloud / Dashboard','Placeholder component folders','Implement and integrate'],['GPS / ETA / ML','No implementation found','Design, implement and evaluate']],[260,465,445],120,490,28);
note(s,'Main repository checked at D:/Academ/git-local/smart-ambulance. The older Coding Part/Smart Ambulance README describes a Wi-Fi/cloud design, but the inspected backend/frontend folders contain remnants rather than a complete current implementation. Status follows current source and the user confirmation, not older README claims.');
s=page('Prototype Evidence');
for(const [i,label] of ['Connected and ready','Simulated vitals streaming','Stopped or reconnected'].entries()){
 text(s,label,70+i*410,130,320,60,30,navy,true,'center');
 text(s,'Screenshot pending',90+i*410,215,280,320,29,'#666666',false,'center','#F6F6F6','#AAB4C4');
}
foot(s,'Use real device captures. Pair the app display with matching ESP32 serial logs.');
note(s,'Evidence slots intentionally await user screenshots. Suggested captures: connected-ready status; streaming HR/SpO2/temperature; stopped status or successful manual reconnection. A recording must establish changing readings and cessation of updates. All readings in the current demonstration are simulated.');
s=page('Conclusion and Future Work');
text(s,'Current implementation',70,140,1100,60,38,navy,true);
text(s,'ESP32 BLE and Flutter gateway code support\nsimulated vital streaming with start/stop control',70,215,1110,110,36);
const future=['Sensor and OLED\nintegration','Persistent uploads\nand cloud','GPS location\nand ETA','ML risk assessment\nand dashboard'];
const fn=future.map((v,i)=>node(s,v,55+i*305,435,255,110,true));for(let i=0;i<3;i++)link(s,fn[i],fn[i+1]);
foot(s,'Next validation: capture BLE evidence, then integrate and test the remaining modules.');note(s,'Conclusions distinguish implemented code from demonstrated hardware results. The full system remains a prototype. ML risk assessment is a project objective and requires dataset/model selection and evaluation.');
const end=originals[8].duplicate();slides.push(end);note(end,'End of Review 2 presentation.');
for(const o of originals)o.delete();
for(let i=0;i<slides.length;i++){
 slides[i].moveTo(i);
 const f=slides[i].shapes.items.find(q=>q.position.top>675);
 if(f){f.text='Dept. of Electronics and Communication Engineering, NMIT, Bengaluru';f.text.style={typeface:font,fontSize:16,color:'#FFFFFF',bold:true};f.position={left:0,top:681.67,width:1280,height:38.33};text(slides[i],String(i+1),1200,682,60,36,16,'#FFFFFF',true,'right');}
}
await (await PresentationFile.exportPptx(p)).save(root+'/.presentation-build/draft.pptx');
console.log('Draft exported',p.slides.items.length);
const {finalizePresentation}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
const result=await finalizePresentation({workspaceDir:root,candidatePath:root+'/.presentation-build/draft.pptx',finalPath:root+'/output/Smart_Ambulance_Review_2_WiFi_BLE.pptx',pythonExecutable:'C:/Users/rahul/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-heading-fit',...[6,7,8,9,10,11,12].flatMap(n=>['--require-native-table-slide',String(n)])],requiredNativeTableOwnerSlides:[6,7,8,9,10,11,12],fontPolicy:{basis:'reference',families:['Times New Roman','Calibri'],referencePath:source,referenceSha256:createHash('sha256').update(await fs.readFile(source)).digest('hex')},verifyArtifactToolImport:true,receiptPath:root+'/.presentation-build/validation-wifi-ble.json'});
console.log(JSON.stringify(result));
await fs.writeFile(root+'/.presentation-build/final-montage.webp',new Uint8Array(await (await p.export({format:'webp',montage:true,scale:.8})).arrayBuffer()));
console.log('Montage exported');
for(let i=0;i<slides.length;i++){await fs.writeFile(root+`/.presentation-build/final-${i+1}.png`,new Uint8Array(await (await p.export({slide:slides[i],format:'png',scale:1})).arrayBuffer()));console.log('Rendered',i+1);}







