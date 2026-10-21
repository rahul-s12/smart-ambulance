import {FileBlob,PresentationFile} from '@oai/artifact-tool';
const p=await PresentationFile.importPptx(await FileBlob.load('D:/Academ/Projects/Major Project 2026-27/Documentation/Phase2/Review 2/Review 2 _ 7th semester_PPT-Template AY 2026-27_October 2026.pptx'));
const s=p.slides.items[3];
for(const [n,o] of [['slide',s],['shapes',s.shapes],['shape',s.shapes.items[0]],['images',s.images],['image',s.images.items[0]]])console.log(n,Object.getOwnPropertyNames(Object.getPrototypeOf(o)));
console.log('size',p.slides.defaultSize);
