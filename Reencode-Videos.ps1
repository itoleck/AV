#Chad Schultz 2023
#Re-encodes videos in a root folder recursivley based on a HandBrake preset and information from the original video

#REQUIREMENTS
#HandBrake GUI & CLI versions
#ffprobe

#Use the included HandBrake presets and import into HandBrake GUI or,
#Create a HandBrake preset to use for ecoding videos using the HandBrake GUI and export to file. Copy the preset to the script folder. Note the name of the preset in GUI.
#Need to import the preset .json file into HandBrake GUI also.

param (
    [Parameter(Mandatory=$true)][System.IO.DirectoryInfo] $HandBrakeFolderPath,      #Path to where HandBrake is installed, i.e. 'c:\program Files\HandBrake'
    [Parameter(Mandatory=$true)][string] $HandBrakePresetFileName,  #HandBrake preset filename, .i.e. AMD-VCE-AV1-4K-PassThrough-Subs.json
    [Parameter(Mandatory=$true)][string] $HandBrakePresetName,      #Name of the preset in the HandBrake GUI
    [Parameter(Mandatory=$true)][System.IO.DirectoryInfo] $VideoFolderPath,          #Root videos folder, i.e. v:\movies
    [Parameter(Mandatory=$true)][System.IO.DirectoryInfo] $VideoOutputFolderPath,    #folder to output re-encoded files, i.e. c:\videos
    [Parameter(Mandatory=$false)][bool] $force                      #Force encoding of video, default just re-encodes h264 and not other formats like HEVC or AV1. Use force to re-encode non-h264 content
)

function Encode-Video {
    param (
        [Parameter(Mandatory=$true)][string] $InputFilename,
        [Parameter(Mandatory=$true)][string] $OutputFilename
    )

    #Fix path to preset to = script launch path
    Start-Process -FilePath "$HandBrakeFolderPath\HandBrakeCLI.exe" -ArgumentList "-i `"$InputFilename`" -o `"$OutputFilename`" --preset-import-gui .\$HandBrakePresetFileName -Z $HandBrakePresetName" -NoNewWindow -Wait
}

function Execute-Command ($commandArguments)
{
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = 'ffprobe.exe'
    $pinfo.WorkingDirectory = $hbfolder.DirectoryName
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "-i ""$commandArguments"""
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    [pscustomobject]@{
        commandTitle = 'Starting Media Probe'
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        ExitCode = $p.ExitCode
    }
}

function probe-files {
    $hbfolder = Get-Item -LiteralPath $HandBrakeFolderPath
    $files = Get-ChildItem -LiteralPath $VideoFolderPath -File -Recurse | Where-Object {$_.Extension -eq ".mkv" -or $_.Extension -eq ".mp4" -or $_.Extension -ne ".mv4"}
    ForEach($file in $files) {
    #    $hevc = Execute-Command -commandTitle 'mediainfo' -commandPath "$HandBrakeFolderPath\MediaInfo.exe" -commandArguments "Z:\Video\HumansS1E3-cli.mkv"
        #$hevc = Execute-Command -commandArguments $file.FullName
        #$hevc.stderr
        #$hevc = Execute-Command -commandTitle 'mediainfo' -commandPath "$HandBrakeFolderPath\ffprobe.exe" -commandArguments $file.FullName
        #Write-Output $hevc.stderr
        #$hevc.stderr | Select-String 'HEVC'

        $processOptions = @{
            FilePath = ".\ffprobe.exe"
            ArgumentList = "-i ""$file"""
            RedirectStandardError = "$($file.FullName)-sterr.txt"
            UseNewEnvironment = $true
        }
        Write-Verbose "$($processOptions.FilePath) $($processOptions.ArgumentList)"
        Start-Process @processOptions
    }
}

function process-encodingfiles {
    $files = Get-ChildItem -LiteralPath $VideoFolderPath -File -Recurse | Where-Object {$_.Extension -eq ".mkv" -or $_.Extension -eq ".mp4" -or $_.Extension -eq ".mv4"}
    ForEach($file in $files) {
        $selecth264 = Get-Content -LiteralPath "$($file.FullName)-sterr.txt" | Select-String 'h264'
        if($selecth264 -or $force) {
            Encode-Video -InputFilename $file.FullName -OutputFilename "$VideoOutputFolderPath\$($file.Name)"
        }
    }
}

probe-files
Start-Sleep -Seconds 5
process-encodingfiles