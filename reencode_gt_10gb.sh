#!/bin/bash
#From Gemini

if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/search"
    exit 1
fi

TARGET_DIR="$1"

echo "Scanning '$TARGET_DIR' for files >10GB and >7 days old..."

# 1. Use mapfile to store the null-delimited find output into an array named 'files'
# Added '! -name "*_compressed.*"' to filter out already compressed files directly in the search
mapfile -d '' files < <(find "$TARGET_DIR" -type f -size +10G -mtime +7 ! -name "*_compressed.*" -print0)

# 2. Check if the array is empty (no files found)
if [ ${#files[@]} -eq 0 ]; then
    echo "No eligible files found. Exiting."
    exit 0
fi

# 3. Print the list of found files
echo ""
echo "========================================================="
echo " Found ${#files[@]} file(s) ready for compression:"
echo "========================================================="
for file in "${files[@]}"; do
    echo " - $file"
done
echo "========================================================="
echo ""

# 4. Pause and wait for any key press
read -n 1 -s -r -p "Press any key to begin encoding (or press Ctrl+C to abort)..."
echo ""

# 5. Loop through the array and process each file
for file in "${files[@]}"; do
    
    echo ""
    echo "========================================================="
    echo "Processing: $file"
    echo "========================================================="

    base="${file%.*}"
    ext="${file##*.}"
    output="${base}_compressed.${ext}"

    ffmpeg -nostdin -y -probesize 100M -analyzeduration 100M -i "$file" \
        -map 0 \
        -c:v hevc_nvenc -preset p6 -tune hq -rc vbr -cq 28 -b:v 0 \
        -c:a copy \
        -c:s copy \
        "$output"
        
    echo "✅ Finished: $output"
done

echo ""
echo "All eligible files have been processed."