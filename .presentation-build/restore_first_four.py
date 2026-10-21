from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import posixpath
import xml.etree.ElementTree as ET
import hashlib
import json

root = Path('D:/Academ/git-local/smart-ambulance')
source = Path('D:/Academ/Projects/Major Project 2026-27/Documentation/Phase2/Review 2/Review 2 _ 7th semester_PPT-Template AY 2026-27_October 2026.pptx')
current = root / 'output/Smart_Ambulance_Review_2_WiFi_BLE.pptx'
target = root / '.presentation-build/restored-draft.pptx'
R = 'http://schemas.openxmlformats.org/package/2006/relationships'
C = 'http://schemas.openxmlformats.org/package/2006/content-types'
ET.register_namespace('', R)
with ZipFile(source) as z:
    src = {n: z.read(n) for n in z.namelist()}
with ZipFile(current) as z:
    dst = {n: z.read(n) for n in z.namelist()}
mapping = {f'ppt/slides/slide{i}.xml': f'ppt/slides/slide{i}.xml' for i in range(1,5)}
copied = set()

def relpart(part):
    folder, name = posixpath.split(part)
    return posixpath.join(folder, '_rels', name + '.rels')

def copy_part(part):
    if part not in mapping:
        folder, name = posixpath.split(part)
        mapping[part] = posixpath.join(folder, 'restored_' + name)
    out = mapping[part]
    if part in copied:
        return out
    copied.add(part)
    dst[out] = src[part]
    rp = relpart(part)
    if rp in src:
        rels = ET.fromstring(src[rp])
        for rel in rels:
            if rel.get('TargetMode') == 'External':
                continue
            raw = rel.get('Target')
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(part), raw)) if not raw.startswith('/') else raw[1:]
            child = copy_part(resolved)
            rel.set('Target', posixpath.relpath(child, posixpath.dirname(out)))
        dst[relpart(out)] = ET.tostring(rels, encoding='utf-8', xml_declaration=True)
    elif relpart(out) in dst:
        del dst[relpart(out)]
    return out

for i in range(1,5):
    copy_part(f'ppt/slides/slide{i}.xml')
types = ET.fromstring(dst['[Content_Types].xml'])
src_types = ET.fromstring(src['[Content_Types].xml'])
existing = {x.get('PartName'):x for x in types if x.tag.endswith('Override')}
defaults = {x.get('Extension') for x in types if x.tag.endswith('Default')}
for entry in src_types:
    if entry.tag.endswith('Default') and entry.get('Extension') not in defaults:
        types.append(entry)
        defaults.add(entry.get('Extension'))
    elif entry.tag.endswith('Override'):
        original = entry.get('PartName').lstrip('/')
        if original in mapping:
            newname = '/' + mapping[original]
            if newname in existing:
                existing[newname].set('ContentType', entry.get('ContentType'))
            else:
                types.append(ET.Element(f'{{{C}}}Override', PartName=newname, ContentType=entry.get('ContentType')))
ET.register_namespace('', C)
dst['[Content_Types].xml'] = ET.tostring(types, encoding='utf-8', xml_declaration=True)
with ZipFile(target, 'w', ZIP_DEFLATED) as z:
    for name, content in dst.items():
        z.writestr(name, content)
assert all(dst[f'ppt/slides/slide{i}.xml'] == src[f'ppt/slides/slide{i}.xml'] for i in range(1,5))
with ZipFile(current) as z:
    unchanged = all(dst[f'ppt/slides/slide{i}.xml'] == z.read(f'ppt/slides/slide{i}.xml') for i in range(5,16))
assert unchanged
print(json.dumps({'draft':str(target),'first_four_slide_xml_exact':True,'remaining_slide_xml_unchanged':True,'copied_source_parts':len(copied)}))
