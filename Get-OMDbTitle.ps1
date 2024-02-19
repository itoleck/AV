#Chad Schultz 2023
#Query OMDb API for fixing Movie Names and creating folder for Radarr imports
#Set $env:OMDB with OMDb API key

param (
    [Parameter(Mandatory=$true)][System.IO.DirectoryInfo] $FolderPath
)

function Query-OMDb {
    param (
        [Parameter(Mandatory=$true)][string] $Title,
        [Parameter(Mandatory=$true)][string] $Key
    )

    $Title = [uri]::EscapeDataString($Title)
    $URI = "http://www.omdbapi.com/?apikey=$Key&t=$Title&type=movie"
    $response = Invoke-WebRequest -Uri $URI
    $Movie = $response | ConvertFrom-Json
    Return $Movie
}

$files = Get-ChildItem -Path $FolderPath -File #| Select-Object -First 10   #For testing
foreach ($file in $files) {
    $m = Query-OMDb -Title $file.BaseName -Key $env:OMDB
    if ($m.Title.Length -gt 0) {
        $fixed_title = $m.Title.Replace(":","")
        if (Test-Path -Path "$FolderPath\$($fixed_title) ($($m.Year))") {
            Write-Verbose "Path already exists: $FolderPath\$($fixed_title) ($($m.Year))"
        } else {
            #If the filename has a year it will be duplicated, fix later
            New-Item -Path "$FolderPath\$($fixed_title) ($($m.Year))" -ItemType Directory
        }     
        Write-Output "$FolderPath\$($fixed_title) ($($m.Year))"
        Start-Sleep -Milliseconds 250
        Move-Item -Path $file.FullName -Destination "$FolderPath\$($fixed_title) ($($m.Year))"
    }
}