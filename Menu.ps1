#Requires -Version 5

Import-Module .\Modules\ModuleEncrypt.psm1


function Show-Menu
{
#    Clear-Host
    Write-Host "================ Ransomware Simulator ================"
    
    Write-Host "1: Press '1' for create a Dummy Files."
    Write-Host "2: Press '2' for Encrypt the files."
    Write-Host "3: Press '3' for Decrypt the files"
    Write-Host "Q: Press 'Q' to quit."
}



do {
    Show-Menu
    $option = Read-Host "Please make a selection"
    switch ($option) {
        #Menu Create Dummy Files
        '1' {
            $numberFiles = Read-Host "How many files want create?"
            $DestionationPath = Get-Folder
            $templatePath = ".\FileCreate\FilesTemplate"
            $FileNameTemplate = ".\FileCreate\FileTemplateName.txt"
            Write-Host "================ File Dummy Gen ================"
            Write-Host "NumberFiles: $numberFiles"
            Write-Host "DestionationPath: $DestionationPath"
            Write-Host "templatePath: $templatePath"
            Write-Host "FileNameTemplate: $FileNameTemplate"
            $confirm = Read-Host "Confirm[Y/N]"
            if($confirm.ToUpper() -eq 'Y'){
                Create-DummyFile -NumberFiles $numberFiles -TemplatePath $templatePath -FileTemplateName $FileNameTemplate -DestinationPath $DestionationPath
            }
        }

        #Encrypt Files
        '2'{
            [string]$folderPath = Get-Folder
            [string]$certDnsName = Read-Host "DnsName Certificate[default = 'ransomware.check.internal']"
            if(-not($certDnsName)){
                $certDnsName = 'ransomware.check.internal'
            }
            $cert = $(Get-ChildItem Cert:\localmachine\My | Where-Object {$_.DnsNameList -eq $certDnsName})
            if(-not($cert)){
                try{
                    #PS 5 need to use Provider because the default provider do not generate a PK
                    $cert = New-SelfSignedCertificate -CertStoreLocation cert:\localmachine\my -DnsName $certDnsName -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider'
                }
                catch{
                    Write-Error "Failed to create a certificate \n $($_.Message)" 
                    Exit
                }
            }
            try {
                $FilesToEncrypt = Get-ChildItem -recurse -Force -Path $folderPath | Where-Object { !($_.PSIsContainer -eq $true) -and  ( $_.Name -like "*$fileName*") }    
            }
            catch {
                Write-Error "Failed to create a certificate \n $($_.Message)" 
                Exit
            }
            $totalFiles = $FilesToEncrypt.Count
            $i = 1
            Write-Host "================ File Encrypt ================"
            Write-Host "certDnsName: $certDnsName"
            Write-Host "folderPath: $folderPath"
            $confirm = Read-Host "Confirm[Y/N]"
            if($confirm.ToUpper() -eq 'Y'){
                foreach ($f in $FilesToEncrypt){
                    Write-Progress -Activity "Encrypt files" -Status " Encrypt file $($f.Name) with certificate $certDnsName" -PercentComplete ($i++ / $totalFiles * 100)
                    Encrypt-File $f.FullName $cert -ErrorAction SilentlyContinue  
                }
            }
        }

        #Decrypt Files
        '3'{
            [string]$folderPath = Get-Folder
            [string]$certDnsName = Read-Host "DnsName Certificate[default = 'ransomware.check.internal']"
            if(-not($certDnsName)){
                $certDnsName = 'ransomware.check.internal'
            }
            $cert = $(Get-ChildItem Cert:\localmachine\My | Where-Object {$_.DnsNameList -eq $certDnsName})
            if(-not($cert)){
                Write-Host "Certificate not found to decrypt files"
                Exit
            }
            try {
                $FilesToDecrypt = Get-ChildItem -recurse -Force -Path $folderPath | Where-Object { !($_.PSIsContainer -eq $true) -and  ( $_.Name -like "*$fileName*") }    
            }
            catch {
                Write-Error "Failed to create a certificate \n $($_.Message)" 
                Exit
            }
            $totalFiles = $FilesToDecrypt.Count
            $i = 1
            Write-Host "================ File Decrypt ================"
            Write-Host "certDnsName: $certDnsName"
            Write-Host "folderPath: $folderPath"
            $confirm = Read-Host "Confirm[Y/N]"
            if($confirm.ToUpper() -eq 'Y'){
                
                foreach ($f in $FilesToDecrypt){
                    Write-Progress -Activity "Decrypt files" -Status " Decrypt file $($f.Name) with certificate $certDnsName" -PercentComplete ($i++ / $totalFiles * 100)
                    Decrypt-File $f.FullName $cert -ErrorAction SilentlyContinue  
                }
            }
        }
        'Q'{
            Exit
        }
        Default {
            Show-Menu
        }
    }    
} while ($true)
