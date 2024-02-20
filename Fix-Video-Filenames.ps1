#Chad Schultz 2023
#Fixes ugly video file names (.mkv, .mp4, m4v) in a folder recursivley

param (
    [Parameter(Mandatory=$true)][string] $VideoFolderPath   #Root videos folder, i.e. v:\movies
)

function Fix-FileNames($rootpath) {
    $files = Get-ChildItem -LiteralPath $rootpath -File -Recurse | Where-Object {$_.Extension -eq ".mkv" -or $_.Extension -eq ".mp4" -or $_.Extension -ne ".mv4"}
    $replacers = "bigdoc","yify","1080p","720p","x265","h264","x264","sampa","mstm","dimension","ZZZ"," 0vyndros","xvidositv","collector’s","choice","xvidphase","dvdrip","jfkxvid","__dvdripdimension"," extended","bordure","qoq","demand","gwc","esubs","sigma","garshasp","dvdriptabularia","[","]"," Silence)","(",")","gi6-","hdtv","proper","kogi","webdl","web dl","amzn","web","web-dl","atmos","aac2","aac2.0","aac",".internal.",".proper.","rartv","-tbs","-dl","bluray","-deflate","reward","ntb","ntbrarbg","ntbrarbg","ddp5.1","dd5.1","webrip","brrip","repack","-cakes",".cakes","cakesrarbg","elite","ggezrarbg","ntbtgx","rubik",".rip","galaxytv","PECULATE","KOGirarbg","SHORTBREHD","FUMettv","KILLERSettv","-killers","-batv","-sva","hmax","metcon","ion10","rovers","pcok","minx","torrentgalaxy","megusta","-smurf","-truffle","-welp","-fleet","-nosivid","-gossip","dsnp","-turbo","-wdym",".nf.","-avs","mSDeztv","-CRiMSONeztv","-CookieMonstereztv","rarbg"

    ForEach($file in $files) {
        $newfile = $file.Name.ToLower()
        foreach($r in $replacers) {
            $tmpfile = $newfile.Replace($r.ToLower(),'')
            $newfile = $tmpfile
        }

        $tmpfile = $newfile.Replace('.',' ')
        
        if ($tmpfile.Substring($tmpfile.Length - 4,1) -eq ' ') {
            $tmpfile = $tmpfile.Remove($tmpfile.Length - 4,1).Insert($tmpfile.Length - 4,'.')
        }
        $tmpfile = $tmpfile.Replace('     ','').Replace('    ','').replace('   ','').replace('  ','').Replace(' -','').Replace('-','')
        if ($tmpfile.Substring($tmpfile.Length - 5,1) -eq ' ') {
            $tmpfile = $tmpfile.Remove($tmpfile.Length - 5,1)
        }
        $tmpfile = $tmpfile.Replace('s h i e l d','shield')
        $newfile = $tmpfile
        $newfile
        Rename-Item -LiteralPath $file.FullName -NewName $newfile
    }
}

Fix-FileNames $VideoFolderPath