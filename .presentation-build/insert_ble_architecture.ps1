$ErrorActionPreference='Stop'
$taskRoot='D:\Academ\git-local\smart-ambulance'
$taskPpt=New-Object -ComObject PowerPoint.Application
$taskDiagram=$taskPpt.Presentations.Open2007((Join-Path $taskRoot '.presentation-build\ble-architecture.pptx'),$true,$false,$false,$true)
$taskDiagramPath=Join-Path $taskRoot '.presentation-build\ble-architecture-native.pptx'
$taskDiagram.SaveAs($taskDiagramPath,24)
$taskDiagram.Close()
$taskDeck=$taskPpt.Presentations.Open((Join-Path $taskRoot 'output\Smart_Ambulance_Review_2_PowerPoint_Fixed.pptx'),$false,$false,$false)
$taskInserted=$taskDeck.Slides.InsertFromFile($taskDiagramPath,4,1,1)
if($taskInserted -ne 1){throw 'Architecture insertion did not create exactly one slide'}
for($taskIndex=5;$taskIndex -le $taskDeck.Slides.Count;$taskIndex++){
 $taskSlide=$taskDeck.Slides.Item($taskIndex)
 $taskFound=$false
 foreach($taskShape in $taskSlide.Shapes){
  if($taskShape.HasTextFrame -eq -1 -and $taskShape.Top -gt 500 -and $taskShape.Left -gt 880 -and $taskShape.TextFrame.TextRange.Text.Trim() -match '^\d+$'){
   $taskShape.TextFrame.TextRange.Text=[string]$taskIndex;$taskFound=$true
  }
 }
 if($taskIndex -eq 5 -and -not $taskFound){
  $taskNumber=$taskSlide.Shapes.AddTextbox(1,900,511.5,45,27)
  $taskNumber.TextFrame.TextRange.Text='5'
  $taskNumber.TextFrame.TextRange.Font.Name='Times New Roman'
  $taskNumber.TextFrame.TextRange.Font.Size=12
  $taskNumber.TextFrame.TextRange.Font.Color.RGB=16777215
  $taskNumber.TextFrame.TextRange.ParagraphFormat.Alignment=3
 }
}
$taskSave=Join-Path $taskRoot '.presentation-build\with-ble-architecture-native.pptx'
$taskDeck.SaveAs($taskSave,24)
$taskDeck.Close()
$taskVerify=$taskPpt.Presentations.Open($taskSave,$true,$false,$false)
if($taskVerify.Slides.Count -ne 16){throw 'Expected 16 slides'}
$taskVerify.Slides.Item(5).Export((Join-Path $taskRoot '.presentation-build\ble-architecture-powerpoint.png'),'PNG',1280,720)
$taskVerify.Close()
Write-Output 'Saved and normally reopened 16 slides in PowerPoint; architecture is slide 5.'
