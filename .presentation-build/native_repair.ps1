$ErrorActionPreference='Stop'
$taskFile='D:\Academ\git-local\smart-ambulance\output\Smart_Ambulance_Review_2_Fixed.pptx'
$taskNative='D:\Academ\git-local\smart-ambulance\.presentation-build\native-repaired.pptx'
$taskPpt=New-Object -ComObject PowerPoint.Application
$taskDeck=$taskPpt.Presentations.Open2007($taskFile,$true,$false,$false,$true)
Write-Output "Native repair opened slides=$($taskDeck.Slides.Count)"
$taskRecords=@()
foreach($taskSlide in $taskDeck.Slides){
 $taskText=@()
 foreach($taskShape in $taskSlide.Shapes){if($taskShape.HasTextFrame -eq -1){$taskText+=$taskShape.TextFrame.TextRange.Text}}
 $taskRecords+=@{slide=$taskSlide.SlideIndex;shapes=$taskSlide.Shapes.Count;text=($taskText -join "`n")}
}
$taskRecords | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath 'D:\Academ\git-local\smart-ambulance\.presentation-build\native-content.json' -Encoding utf8
$taskDeck.SaveAs($taskNative,24)
$taskDeck.Close()
$taskCheck=$taskPpt.Presentations.Open($taskNative,$true,$false,$false)
Write-Output "Normal reopen successful; slides=$($taskCheck.Slides.Count)"
$taskPreview='D:\Academ\git-local\smart-ambulance\.presentation-build\native-fixed'
New-Item -ItemType Directory -Path $taskPreview -Force | Out-Null
foreach($taskIndex in 1..$taskCheck.Slides.Count){$taskCheck.Slides.Item($taskIndex).Export((Join-Path $taskPreview "slide-$taskIndex.png"),'PNG',1280,720)}
$taskCheck.Close()
Write-Output 'Rendered every slide in PowerPoint.'
