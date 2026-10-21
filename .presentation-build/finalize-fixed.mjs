import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {FileBlob,PresentationFile} from '@oai/artifact-tool';
const root='D:/Academ/git-local/smart-ambulance';
const skill='C:/Users/rahul/.codex/plugins/cache/openai-primary-runtime/presentations/26.1015.12040/skills/presentations';
const {finalizePresentation}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
const owners=[6,7,8,9,10,11,12];
const result=await finalizePresentation({workspaceDir:root,candidatePath:root+'/.presentation-build/compatibility-draft.pptx',finalPath:root+'/output/Smart_Ambulance_Review_2_Fixed.pptx',pythonExecutable:'C:/Users/rahul/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry',...owners.flatMap(n=>['--require-native-table-slide',String(n)])],requiredNativeTableOwnerSlides:owners,verifyArtifactToolImport:true,receiptPath:root+'/.presentation-build/validation-fixed.json'});
console.log(JSON.stringify({final:result.finalPath,integrity:result.packageIntegrity.status,findings:result.presentationLayout.finding_count}));
const p=await PresentationFile.importPptx(await FileBlob.load(result.finalPath));
for(let i=0;i<p.slides.items.length;i++){
 await fs.writeFile(root+`/.presentation-build/restored-${i+1}.png`,new Uint8Array(await (await p.export({slide:p.slides.items[i],format:'png',scale:.8})).arrayBuffer()));
}
console.log('Rendered 15 slides');


