#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <file>" >&2
    exit 1
fi

input_file="$1"

if [[ ! -f "$input_file" ]]; then
    echo "Error: File '$input_file' not found" >&2
    exit 1
fi

# Check if file is webm
if [[ "${input_file##*.}" != "webm" ]]; then
    echo "File is not webm, nothing to do"
    exit 0
fi

# Get audio codec using ffmpeg
audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input_file")

if [[ -z "$audio_codec" ]]; then
    echo "Error: Could not determine audio codec" >&2
    exit 1
fi

echo "Detected audio codec: $audio_codec"

# If opus, convert to MKV with video passthrough and AAC audio
if [[ "$audio_codec" == "opus" ]]; then
    output_file="${input_file%.webm}.mkv"
    echo "Converting to MKV with AAC audio..."
    ffmpeg -i "$input_file" -c:v copy -c:a aac -b:a 192k "$output_file"
    echo "Created: $output_file"
else
    echo "Audio codec is $audio_codec, no conversion needed"
fi
