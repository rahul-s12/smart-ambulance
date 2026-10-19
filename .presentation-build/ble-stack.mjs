import fs from 'node:fs/promises';
import {Presentation,PresentationFile} from '@oai/artifact-tool';
const root='D:/Academ/git-local/smart-ambulance/.presentation-build';
const p=Presentation.create({slideSize:{width:1280,height:720}}),s=p.slides.add();
const navy='#002060';
function box(t,x,y,w,h,size=30,fill='none',color=navy){const q=s.shapes.add({geometry:fill==='none'?'textbox':'rect',name:t.slice(0,48),position:{left:x,top:y,width:w,height:h},fill,line:{fill:fill==='none'?'none':navy,width:fill==='none'?0:1.6}});q.text=t;q.text.style={typeface:'Times New Roman',fontSize:size,color,bold:true,alignment:'center',verticalAlignment:'middle'};q.text.insets=6;return q;}
box('BLE Stack Architecture on ESP32',0,0,1280,80,52,navy,'#FFFFFF');
const layers=[
 ['Application layer','Vital data generation and stream control'],
 ['BLE host: NimBLE','GAP, GATT, ATT, SMP and L2CAP'],
 ['Host–controller interface: HCI / VHCI','Commands, events and data transport'],
 ['Bluetooth controller: Link Layer','Packet scheduling, connections and link encryption'],
 ['ESP32-C6 hardware: PHY and radio','2.4 GHz wireless transmission and reception']
];
const shapes=layers.map((v,i)=>box(v.join('\n'),190,110+i*108,900,78,29,i===4?'#DCE8F4':'#EDF3F9'));
for(let i=0;i<4;i++)s.shapes.connect(shapes[i],shapes[i+1],{kind:'straight',fromSide:'bottom',toSide:'top',line:{fill:navy,width:2},head:{type:'arrow',width:'med',length:'med'},tail:{type:'arrow',width:'med',length:'med'}});
box('Application and host run under FreeRTOS on the ESP32-C6',70,632,1140,35,25,'none','#0070C0');
box('Dept. of Electronics and Communication Engineering, NMIT, Bengaluru',0,681.67,1280,38.33,16,navy,'#FFFFFF');
s.speakerNotes.text='Layered architecture inside the ESP32-C6. The application uses NimBLE host APIs. The host includes GAP, GATT/ATT, SMP and L2CAP. The HCI/VHCI boundary connects the host with the Espressif Bluetooth controller. The controller includes Link Layer functions and PHY support. The PHY/radio is shown as the hardware-facing layer, not a separate external microcontroller. Bidirectional arrows represent commands, events and BLE data. Firmware sources: esp32/components/ble/ble.c, ble_gap.c, ble_gatt.c; sdkconfig confirms esp32c6, NimBLE host and enabled Bluetooth controller. Official references: https://docs.espressif.com/projects/esp-idf/en/stable/esp32c6/api-reference/bluetooth/nimble/index.html and https://docs.espressif.com/projects/esp-idf/en/stable/esp32c6/api-guides/ble/get-started/ble-introduction.html';
await (await PresentationFile.exportPptx(p)).save(root+'/ble-stack.pptx');
await fs.writeFile(root+'/ble-stack.png',new Uint8Array(await (await p.export({slide:s,format:'png',scale:1})).arrayBuffer()));
console.log('Created layered BLE stack diagram');
