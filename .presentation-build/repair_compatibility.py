from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from lxml import etree as E
import posixpath
root=Path('D:/Academ/git-local/smart-ambulance')
source=root/'output/Smart_Ambulance_Review_2_Updated.pptx'
target=root/'.presentation-build/compatibility-draft.pptx'
with ZipFile(source) as z: parts={n:z.read(n) for n in z.namelist()}
P='http://schemas.openxmlformats.org/presentationml/2006/main'
R='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
PKG='http://schemas.openxmlformats.org/package/2006/relationships'
pres=E.fromstring(parts['ppt/presentation.xml'])
rels=E.fromstring(parts['ppt/_rels/presentation.xml.rels'])
masterlist=pres.find('{'+P+'}sldMasterIdLst')
E.SubElement(rels,'{'+PKG+'}Relationship',Id='rIdRestoredOriginalMaster',Type=R+'/slideMaster',Target='slideMasters/restored_slideMaster1.xml')
E.SubElement(masterlist,'{'+P+'}sldMasterId',id='2147483649',attrib={'{'+R+'}id':'rIdRestoredOriginalMaster'})
parts['ppt/presentation.xml']=E.tostring(pres,xml_declaration=True,encoding='utf-8',standalone=True)
parts['ppt/_rels/presentation.xml.rels']=E.tostring(rels,xml_declaration=True,encoding='utf-8',standalone=True)
for name,data in list(parts.items()):
    if 'restored_' not in name: continue
    if name.endswith('.rels') and '/notesSlides/' in name:
        x=E.fromstring(data)
        for rel in x:
            if rel.get('Type')==R+'/notesMaster':rel.set('Target','../notesMasters/notesMaster1.xml')
        parts[name]=E.tostring(x,xml_declaration=True,encoding='utf-8',standalone=True)
    elif name.endswith('.xml'):
        x=E.fromstring(data)
        changed=False
        for el in x.iter():
            if 'smtClean' in el.attrib:
                del el.attrib['smtClean'];changed=True
        if name=='ppt/slideMasters/restored_slideMaster1.xml':
            for i,el in enumerate(x.findall('.//{'+P+'}sldLayoutId')):
                el.set('id',str(3000000000+i));changed=True
        if changed:parts[name]=E.tostring(x,xml_declaration=True,encoding='utf-8',standalone=True)
with ZipFile(target,'w',ZIP_DEFLATED) as z:
    for n,b in parts.items():z.writestr(n,b)
with ZipFile(source) as z:
    assert all(parts[f'ppt/slides/slide{i}.xml']==z.read(f'ppt/slides/slide{i}.xml') for i in range(1,16))
print('Repaired master registration and notes links; all 15 slide XML parts unchanged')
