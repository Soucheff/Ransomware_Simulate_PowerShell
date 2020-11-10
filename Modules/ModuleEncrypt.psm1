
Function Get-Folder{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder"
    $foldername.rootfolder = "MyComputer"
    $foldername.SelectedPath = $initialDirectory

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return $folder
}
Function Encrypt-File {
    Param(
        [Parameter(mandatory = $true)]
            [System.IO.FileInfo] $FilesToEncrypt,
        [Parameter(mandatory = $true)]
            [System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert
    )
 
    #Load the assembly to encrypt
    Try { 
        [System.Reflection.Assembly]::LoadWithPartialName("System.Security.Cryptography") 
    }
    Catch { 
        Write-Error "Could not load required assembly. \n $($_.Message)"
        Return 
    }  

    $AesProvider = New-Object System.Security.Cryptography.AesManaged
    $AesProvider.KeySize = 256
    $AesProvider.BlockSize = 128
    $AesProvider.Mode = [System.Security.Cryptography.CipherMode]::CBC


    $KeyFormatter = New-Object System.Security.Cryptography.RSAPKCS1KeyExchangeFormatter($Cert.PublicKey.Key)
    [Byte[]]$KeyEncrypted = $KeyFormatter.CreateKeyExchange($AesProvider.Key, $AesProvider.GetType())
    [Byte[]]$LenKey = $Null
    [Byte[]]$LenIV = $Null
    [Int]$LKey = $KeyEncrypted.Length
    $LenKey = [System.BitConverter]::GetBytes($LKey)
    [Int]$LIV = $AesProvider.IV.Length
    $LenIV = [System.BitConverter]::GetBytes($LIV)

    $FileStreamWriter = $null
    
    Try { 
        $FileStreamWriter = New-Object System.IO.FileStream("$($env:temp+$FilesToEncrypt.Name)", [System.IO.FileMode]::Create) 
    }
    Catch { 
        Write-Error "Unable to open output file for writing.  \n $($_.Message)"
        Return
    }

    $FileStreamWriter.Write($LenKey, 0, 4)
    $FileStreamWriter.Write($LenIV, 0, 4)
    $FileStreamWriter.Write($KeyEncrypted, 0, $LKey)
    $FileStreamWriter.Write($AesProvider.IV, 0, $LIV)

    $Transform = $AesProvider.CreateEncryptor()
    $CryptoStream = New-Object System.Security.Cryptography.CryptoStream($FileStreamWriter, $Transform, [System.Security.Cryptography.CryptoStreamMode]::Write)
    [Int]$Count = 0
    [Int]$Offset = 0
    [Int]$BlockSizeBytes = $AesProvider.BlockSize / 8
    [Byte[]]$Data = New-Object Byte[] $BlockSizeBytes
    [Int]$BytesRead = 0
    Try { 
        $FileStreamReader = New-Object System.IO.FileStream("$($FilesToEncrypt.FullName)", [System.IO.FileMode]::Open) 
    }
    Catch { 
        Write-Error "Unable to open input file for reading.  \n $($_.Message)"
        Return 
    }
    
    Do {
        $Count = $FileStreamReader.Read($Data, 0, $BlockSizeBytes)
        $Offset += $Count
        $CryptoStream.Write($Data, 0, $Count)
        $BytesRead += $BlockSizeBytes
    } While ($Count -gt 0)
     
    $CryptoStream.FlushFinalBlock()
    $CryptoStream.Close()
    $FileStreamReader.Close()
    $FileStreamWriter.Close()

    Copy-Item -Path $($env:temp + $FilesToEncrypt.Name) -Destination $FilesToEncrypt.FullName -Force
}

Function Decrypt-File {
    Param(
        [Parameter(mandatory = $true)]
            [System.IO.FileInfo] $FileToDecrypt,
        [Parameter(mandatory = $true)]
            [System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert
        )
 
    #Load the assembly to encrypt
    Try { 
        [System.Reflection.Assembly]::LoadWithPartialName("System.Security.Cryptography") 
    }
    Catch { 
        Write-Error "Could not load required assembly.  \n $($_.Message)"
        Return 
    }  
    
    $AesProvider = New-Object System.Security.Cryptography.AesManaged
    $AesProvider.KeySize = 256
    $AesProvider.BlockSize = 128
    $AesProvider.Mode = [System.Security.Cryptography.CipherMode]::CBC


    [Byte[]]$LenKey = New-Object Byte[] 4
    [Byte[]]$LenIV = New-Object Byte[] 4

    If ( -not($Cert.HasPrivateKey) -or -not($Cert.PrivateKey) ) {
        Write-Error "The supplied certificate does not contain a private key, or it could not be accessed."
        Return
    }
    
    Try { 
        $FileStreamReader = New-Object System.IO.FileStream("$($FileToDecrypt.FullName)", [System.IO.FileMode]::Open) 
    }
    Catch {
        Write-Error "Unable to open input file for reading."  -BackgroundColor Red
        Return
    }  

    $FileStreamReader.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
    $FileStreamReader.Read($LenKey, 0, 3) | Out-Null
    $FileStreamReader.Seek(4, [System.IO.SeekOrigin]::Begin) | Out-Null
    $FileStreamReader.Read($LenIV, 0, 3) | Out-Null

    [Int]$LKey = [System.BitConverter]::ToInt32($LenKey, 0)
    [Int]$LIV = [System.BitConverter]::ToInt32($LenIV, 0)
    [Int]$StartC = $LKey + $LIV + 8
    [Int]$LenC = [Int]$FileStreamReader.Length - $StartC
    [Byte[]]$KeyEncrypted = New-Object Byte[] $LKey
    [Byte[]]$IV = New-Object Byte[] $LIV

    $FileStreamReader.Seek(8, [System.IO.SeekOrigin]::Begin) | Out-Null
    $FileStreamReader.Read($KeyEncrypted, 0, $LKey) | Out-Null
    $FileStreamReader.Seek(8 + $LKey, [System.IO.SeekOrigin]::Begin) | Out-Null
    $FileStreamReader.Read($IV, 0, $LIV) | Out-Null

    [Byte[]]$KeyDecrypted = $Cert.PrivateKey.Decrypt($KeyEncrypted, $false)
    $Transform = $AesProvider.CreateDecryptor($KeyDecrypted, $IV)
    Try { 
        $FileStreamWriter = New-Object System.IO.FileStream("$($env:TEMP)\$($FileToDecrypt.Name)", [System.IO.FileMode]::Create) 
    }
    Catch {
        Write-Error "Unable to open output file for writing.`n$($_.Message)"
        $FileStreamReader.Close()
        Return
    }

    [Int]$Count = 0
    [Int]$Offset = 0
    [Int]$BlockSizeBytes = $AesProvider.BlockSize / 8
    [Byte[]]$Data = New-Object Byte[] $BlockSizeBytes
    $CryptoStream = New-Object System.Security.Cryptography.CryptoStream($FileStreamWriter, $Transform, [System.Security.Cryptography.CryptoStreamMode]::Write)
    
    Do {
        $Count = $FileStreamReader.Read($Data, 0, $BlockSizeBytes)
        $Offset += $Count
        $CryptoStream.Write($Data, 0, $Count)
    } While ($Count -gt 0)
    
    $CryptoStream.FlushFinalBlock()
    $CryptoStream.Close()
    $FileStreamWriter.Close()
    $FileStreamReader.Close()
    Copy-Item -Path "$($env:TEMP)\$($FileToDecrypt.Name)" -Destination  $FileToDecrypt.DirectoryName -Force
}
Function Create-DummyFile {
    param(
        [Parameter(mandatory = $true)]
        $NumberFiles,
        [Parameter(mandatory = $true)]
        $TemplatePath,
        [Parameter(mandatory = $true)]
        $DestinationPath,
        [Parameter(mandatory = $true)]
        $FileTemplateName
    )

    try {
        $arrTemplate = Get-ChildItem -Path $TemplatePath | Where-Object { -not($_.PSIsContainer) }
    }
    catch {
        Write-Host "Failed to get templates files" -BackgroundColor Red
        return
    }

    try {
        $arrFileNameTemplate = Get-Content -Path $FileTemplateName | Where-Object { -not($_.PSIsContainer) }
    }
    catch {
        Write-Host "Failed to get name template" -BackgroundColor Red
        return
    }


    if (Test-Path $DestinationPath) {
        if( (Get-ChildItem $DestinationPath).Count -gt 0 ){
            Write-Host "The destination folder already exist and is not empty!" -BackgroundColor Red
            return
        }
    }
    else {
        try {
            New-item $DestinationPath -ItemType Directory -Force
        }
        catch {
            Write-Host "Failed to create destination folder!" -BackgroundColor Red
            return
        }
    }

    for ($i = 1; $i -le $NumberFiles; $i++ ) {
        $TemplateFile = $arrTemplate | get-Random
        $FileName = "$($arrFileNameTemplate | get-Random) - $i$($TemplateFile.Extension)"

        Write-Progress -Activity "Create dummy files" -Status "Create file $FileName basead - $($TemplateFile.Name)" -PercentComplete ($i / $NumberFiles * 100)
        
        if (Test-Path "$DestinationPath\$FileName") {
            Write-Host "File already exists" -BackgroundColor Yellow -ForegroundColor Black
        }
        else {
            try {
                Copy-Item -Path $TemplateFile.FullName -Destination "$DestinationPath\$FileName"
            }
            catch {
                Write-Host "Failed to create a file on the destination ($DestinationPath\$FileName)" -BackgroundColor Red
            }
        }
            
    }
}