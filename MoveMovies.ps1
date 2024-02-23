#Move files work in progress scripts

$FolderPath = "P:\movies"
$files = Get-ChildItem -Path $FolderPath -File #| Select-Object -First 1   #For testing
foreach ($file in $files) {
    Move-Item -Path $file.FullName -Destination "$FolderPath\$($file.BaseName)\"
}

$FolderPath = "P:\movies"
$files = Get-ChildItem -Path $FolderPath -File #| Select-Object -First 10   #For testing
foreach ($file in $files) {
    if ($file.Extension.Length -lt 1) {
        Write-Output $file
        Move-Item $file "$file.mkv"
    }
    #Move-Item -Path $file.FullName -Destination "$FolderPath\$($file.BaseName)\"
}