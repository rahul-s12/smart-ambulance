from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path('D:/Academ/git-local/smart-ambulance')
with ZipFile(root/'output/Smart_Ambulance_Review_2_Restored.pptx') as z:
    parts = {n:z.read(n) for n in z.namelist()}
with ZipFile(root/'.presentation-build/conclusion-authored.pptx') as z:
    parts['ppt/slides/slide14.xml'] = z.read('ppt/slides/slide14.xml')
with ZipFile(root/'.presentation-build/conclusion-draft.pptx','w',ZIP_DEFLATED) as z:
    for n,b in parts.items(): z.writestr(n,b)
print('All package parts preserved except conclusion slide XML')
