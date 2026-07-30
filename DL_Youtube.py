import sys
import yt_dlp

def download_video(url, output_path="."):
    ydl_opts = {
        'format': 'bestvideo[height<=1080]+bestaudio/best',  # Max 1080p
        'outtmpl': './downloads/%(title)s.%(ext)s',
        'merge_output_format': 'mp4',                        # Merge into mp4
        'postprocessors': [{                                  # Convert to mp3 (audio only)
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
        }],
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python DL_Youtube.py <video_url>")
        sys.exit(1)
    download_video(sys.argv[1])