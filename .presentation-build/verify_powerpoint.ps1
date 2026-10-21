$ErrorActionPreference='Stop'
$taskFile='D:\Academ\git-local\smart-ambulance\output\Smart_Ambulance_Review_2_Fixed.pptx'
$taskPpt=New-Object -ComObject PowerPoint.Application
$taskDeck=$taskPpt.Presentations.Open($taskFile,$true,$false,$false)
Write-Output "PowerPoint opened file; slides=$($taskDeck.Slides.Count)"
$taskPreview='D:\Academ\git-local\smart-ambulance\.presentation-build\native-fixed'
New-Item -ItemType Directory -Path $taskPreview -Force | Out-Null
foreach($taskIndex in 1..$taskDeck.Slides.Count){
 $taskSlide=$taskDeck.Slides.Item($taskIndex)
 $taskSlide.Export((Join-Path $taskPreview "slide-$taskIndex.png"),'PNG',1280,720)
}
$taskDeck.Close()
Write-Output 'PowerPoint rendered all 15 slides and closed the test file.'
