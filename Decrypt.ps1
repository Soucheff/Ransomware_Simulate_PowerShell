#Requires -Version 5

param (
    [Parameter(Mandatory=$true)]
    [string]$folderPath,
    [Parameter(Mandatory=$false)]
    [string]$certDnsName
)


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
    Write-Error "Failed to get files \n $($_.Message)" 
    Exit
}
$totalFiles = $FilesToDecrypt.Count
$i = 1
foreach ($f in $FilesToDecrypt){
    Write-Progress -Activity "Decrypt files" -Status " Decrypt file $($f.Name) with certificate $certDnsName" -PercentComplete ($i++ / $totalFiles * 100)
    Decrypt-File $f.FullName $cert -ErrorAction SilentlyContinue  
}