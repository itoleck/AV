### Must have ffmpeg and whisper(OpenAI) installed and added to the system PATH for this script to work.
### Use UNC path if the folder is on a network drive, e.g., \\server\folder

param (
    [Parameter(Mandatory=$true)][string]$FolderPath,
    [switch]$ReportOnly
)

function doesVideoHaveSubtitles {
    param (
        [string]$videoPath
    )
    $isSubtitles = $false

    $subtitlePath = [System.IO.Path]::ChangeExtension($videoPath, ".srt")
    if (Test-Path -Path $subtitlePath) {
        $isSubtitles = $true
    }

    #$subs = Start-Process -FilePath "C:\Users\itole\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1-full_build\bin\ffprobe.exe" -ArgumentList "$videoPath 2>&1" -NoNewWindow -Wait
    $subs = @(ffprobe.exe $videoPath 2>&1 | Select-String -Pattern "Subtitle: ")
    if ($subs.count -gt 0) {
        $isSubtitles = $true
    }

    return $isSubtitles
}

# Check if the folder path is provided
if (-not $FolderPath) {
    Write-Host "Please provide a folder path."
    exit
}

# Get all video files in the folder
$videoFiles = Get-ChildItem -Path $FolderPath -Filter "*.m*" -Recurse

if ($videoFiles.Count -eq 0) {
    Write-Host "No video files found in the specified folder."
    exit
}

foreach ($video in $videoFiles) {

    if (doesVideoHaveSubtitles($video.FullName)) {
        #Write-Host "Video '$($video.Name)' already has subtitles. Skipping..."
    } else {
        Write-Host "Video '$($video.Name)' does not have subtitles. Processing..."
        $videoPath = $video.FullName

        # Generate subtitles using ffmpeg and whisper
        try {
            # Extract audio from the video
            $audioPath = [System.IO.Path]::ChangeExtension($videoPath, ".mp3")
            
            if (-not $ReportOnly) {
                Start-Process -FilePath "C:\Users\itole\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1-full_build\bin\ffmpeg.exe" -ArgumentList "-i", "`"$videoPath`"", "-vn", "-c:a", "libmp3lame", "-q:a", "2", "`"$audioPath`"" -Wait -noNewWindow
                Start-Sleep -Seconds 5 # Wait for a moment to ensure the audio file is created
                # Generate subtitles using whisper
                whisper $audioPath --model medium --language en --output_format srt --output_dir $FolderPath
                # Clean up the extracted audio file
                Remove-Item -Path $audioPath -Force
                Write-Host "Subtitles generated for '$($video.Name)'."
            }

        } catch {
            Write-Host "An error occurred while processing '$($video.FullName)': $_"
        }
    }
}