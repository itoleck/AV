#Take the last 4 characters of a filename, no extension and see if it's a number/year, if so, create a folder with the name

param (
    [Parameter(Mandatory=$true)][System.IO.DirectoryInfo] $FolderPath
)

[Int32]$OutNumber = $null

$files = Get-ChildItem -Path $FolderPath -File #| Select-Object -First 30   #For testing
foreach ($file in $files) {
    $file_str = $file.BaseName
    $year = $file_str.Substring($file_str.Length-4,4)

    if ([Int32]::TryParse($year,[ref]$OutNumber)){
        New-Item -Path "$FolderPath\$($file.BaseName)" -ItemType Directory
    } else {}
}