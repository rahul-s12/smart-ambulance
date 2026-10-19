import fs from 'node:fs/promises';
import {FileBlob,PresentationFile} from '@oai/artifact-tool';
const source='D:/Academ/Projects/Major Project 2026-27/Documentation/Phase2/Review 2/Review 2 _ 7th semester_PPT-Template AY 2026-27_October 2026.pptx';
const p=await PresentationFile.importPptx(await FileBlob.load(source));
console.log((await p.inspect({kind:'slide,layout,textbox,shape,image',maxChars:24000})).ndjson);
console.log('slide collection',Object.getOwnPropertyNames(Object.getPrototypeOf(p.slides)));
await fs.writeFile('.presentation-build/source-montage.webp',new Uint8Array(await (await p.export({format:'webp',montage:true,scale:.7})).arrayBuffer()));
for(let i=0;i<p.slides.items.length;i++) await fs.writeFile(`.presentation-build/source-${i+1}.png`,new Uint8Array(await (await p.export({slide:p.slides.items[i],format:'png',scale:.8})).arrayBuffer()));
await fs.writeFile('.presentation-build/inspect.txt',(await p.inspect({kind:'slide,layout,textbox,shape,image',maxChars:60000})).ndjson);
