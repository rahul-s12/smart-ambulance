$ErrorActionPreference='Stop'
$taskRoot='D:\Academ\git-local\smart-ambulance'
$taskPpt=New-Object -ComObject PowerPoint.Application
$taskDiagram=$taskPpt.Presentations.Open2007((Join-Path $taskRoot '.presentation-build\ble-stack.pptx'),$true,$false,$false,$true)
$taskDiagramPath=Join-Path $taskRoot '.presentation-build\ble-stack-native.pptx'
$taskDiagram.SaveAs($taskDiagramPath,24)
$taskDiagram.Close()
$taskDeck=$taskPpt.Presentations.Open((Join-Path $taskRoot 'output\Smart_Ambulance_Review_2_BLE_Architecture.pptx'),$true,$false,$false)
$taskCount=$taskDeck.Slides.Count
$taskMatches=@()
foreach($taskSlide in $taskDeck.Slides){foreach($taskShape in $taskSlide.Shapes){if($taskShape.HasTextFrame -eq -1 -and $taskShape.TextFrame.TextRange.Text -like '*BLE Architecture: Flutter to ESP32*'){$taskMatches+=$taskSlide.SlideIndex}}}
if($taskMatches.Count -gt 1){throw 'Multiple BLE architecture slides found'}
$taskReplace=$taskMatches.Count -eq 1
if($taskReplace){$taskIndex=[int]$taskMatches[0]}else{
 $taskArchitecture=@()
 foreach($taskSlide in $taskDeck.Slides){foreach($taskShape in $taskSlide.Shapes){if($taskShape.HasTextFrame -eq -1 -and $taskShape.TextFrame.TextRange.Text.Trim() -eq 'Architecture'){$taskArchitecture+=$taskSlide.SlideIndex}}}
 if($taskArchitecture.Count -ne 1){throw 'Cannot locate the system architecture slide'}
 $taskIndex=[int]$taskArchitecture[0]+1
}
$taskInserted=$taskDeck.Slides.InsertFromFile($taskDiagramPath,($taskIndex-1),1,1)
if($taskInserted -ne 1){throw 'Could not insert stack diagram'}
if($taskReplace){$taskDeck.Slides.Item($taskIndex+1).Delete()}
$taskNumber=$taskDeck.Slides.Item($taskIndex).Shapes.AddTextbox(1,900,511.5,45,27)
$taskNumber.TextFrame.TextRange.Text=[string]$taskIndex
$taskNumber.TextFrame.TextRange.Font.Name='Times New Roman'
$taskNumber.TextFrame.TextRange.Font.Size=12
$taskNumber.TextFrame.TextRange.Font.Color.RGB=16777215
$taskNumber.TextFrame.TextRange.ParagraphFormat.Alignment=3
for($taskPage=$taskIndex+1;$taskPage -le $taskDeck.Slides.Count;$taskPage++){
 foreach($taskShape in $taskDeck.Slides.Item($taskPage).Shapes){
  if($taskShape.HasTextFrame -eq -1 -and $taskShape.Top -gt 500 -and $taskShape.Left -gt 880 -and $taskShape.TextFrame.TextRange.Text.Trim() -match '^\d+$'){$taskShape.TextFrame.TextRange.Text=[string]$taskPage}
 }
}
$taskSave=Join-Path $taskRoot '.presentation-build\with-ble-stack-native.pptx'
$taskDeck.SaveAs($taskSave,24)
$taskDeck.Close()
$taskVerify=$taskPpt.Presentations.Open($taskSave,$true,$false,$false)
$taskExpected=if($taskReplace){$taskCount}else{$taskCount+1}
if($taskVerify.Slides.Count -ne $taskExpected){throw 'Slide count changed unexpectedly'}
$taskVerify.Slides.Item($taskIndex).Export((Join-Path $taskRoot '.presentation-build\ble-stack-powerpoint.png'),'PNG',1280,720)
$taskVerify.Close()
Write-Output "Stack architecture is slide $taskIndex; normally reopened $taskExpected slides in PowerPoint."
