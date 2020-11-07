<#
Create-DummyFiles
.Description
    This script creates multiple files basead on templates files with a random and unique file name. 
.How to use
    You'll need to edit lines 21 and 30. Line 21, is the location of the word list. Line 30 is the location of the original file, that the script will make copies of.
.Created by
    Pedro Soucheff
#>
param(
      [Parameter(mandatory=$true)]
        $NumberFiles,
      [Parameter(mandatory=$true)]
        $TemplatePath,
      [Parameter(mandatory=$true)]
        $DestinationPath,
      [Parameter(mandatory=$true)]
        $FileTemplateName
)

try{
    $arrTemplate = Get-ChildItem -Path $TemplatePath | Where-Object {-not($_.PSIsContainer)}
}catch{
    Write-Host "Failed to get templates files" -BackgroundColor Red
    Exit
}

try{
    $arrFileNameTemplate = Get-Content -Path $FileTemplateName | Where-Object {-not($_.PSIsContainer)}
}catch{
    Write-Host "Failed to get name template" -BackgroundColor Red
    Exit
}


if(Test-Path $DestinationPath){
    Write-Host "The destination folder already exist!" -BackgroundColor Red
    Exit
}else{
    try{
        New-item $DestinationPath -ItemType Directory -Force
    }catch{
        Write-Host "Failed to create destination folder!" -BackgroundColor Red
        Exit
    }
}

for ($i = 1; $i -le $NumberFiles; $i++ ){
    $TemplateFile = $arrTemplate | get-Random
    $FileName = "$($arrFileNameTemplate | get-Random) - $i$($TemplateFile.Extension)"

    Write-Progress -Activity "Create dummy files" -Status "Create file $FileName basead - $($TemplateFile.Name)" -PercentComplete ($i/$NumberFiles*100)
    
    if(Test-Path "$DestinationPath\$FileName"){
        Write-Host "File already exists" -BackgroundColor Yellow -ForegroundColor Black
    }else{
        try{
            Copy-Item -Path $TemplateFile.FullName -Destination "$DestinationPath\$FileName"
            Write-Host "File Created" -BackgroundColor Green -ForegroundColor Black
        }catch{
            Write-Host "Failed to create a file on the destination ($DestinationPath\$FileName)" -BackgroundColor Red
        }
    }
        
}


