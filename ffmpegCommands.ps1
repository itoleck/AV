#Enable Stereo Mix in Sound Settings -> Recording tab -> Right click and Show Disabled Devices -> Enable Stereo Mix
#Does not record desktop audio in testing
#Voicemeeter Banana as an alternative https://vb-audio.com/Voicemeeter/potato.htm
#https://vb-audio.com/Cable/index.htm

.\ffmpeg.exe -list_devices true -f dshow -i dummy

.\ffmpeg.exe -f gdigrab -i desktop -f dshow -i audio="Stereo Mix (Realtek(R) Audio)" -c:v libx264 -c:a aac -preset fast -crf 23 z:\output.mkv

#Has to be in the foreground
#To get Window titles; Get-Process | Where-Object {$_.MainWindowTitle } | Select-Object MainWindowTitle
.\ffmpeg.exe -f gdigrab -i title="*Untitled - Notepad" -f dshow -i audio="Stereo Mix (Realtek(R) Audio)" -c:v libx264 -c:a aac -preset fast -crf 23 z:\output3.mkv


