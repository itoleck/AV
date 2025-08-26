# Scripts to automate video recoding

## FFMPEG/FFPLAY/FFPROBE needed to be copied to root of this repo folder. Download latest from trusted sources.

Reencode-Videos.ps1 - Main script, re-encodes videos based on Handbrake presets. Needs ffmpeg apps. Needs write access to the source folder to store ffprobe information.

Example-Reencode.ps1 - Example command of Reencode-Videos.ps1

Fix-Video-Filenames.ps1 - Fixes ugly video filenames by removing erroneous information

Get-OMDbTitle.ps1 - Use www.omdbapi.com API to search video filename title and supply real movie title name. Need OMDB key.

