#!/bin/bash

set -euo pipefail

VAAPI_DEVICE="${VAAPI_DEVICE:-/dev/dri/renderD128}"

# Check if VAAPI hardware encoding is available
use_vaapi=false
if [[ -r "$VAAPI_DEVICE" ]] && ffmpeg -hide_banner -vaapi_device "$VAAPI_DEVICE" -f lavfi -i nullsrc -t 0.1 -vf 'format=nv12,hwupload' -c:v hevc_vaapi -f null - 2>/dev/null; then
    use_vaapi=true
fi

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <file>" >&2
    exit 1
fi

input_file="$1"

if [[ ! -f "$input_file" ]]; then
    echo "Error: File '$input_file' not found" >&2
    exit 1
fi

extension="${input_file##*.}"

# Only process video containers we care about
if [[ ! "$extension" =~ ^(webm|mkv|mp4)$ ]]; then
    echo "File is not webm/mkv/mp4, nothing to do"
    exit 0
fi

# Get video and audio codecs
video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input_file")
audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input_file")

echo "Detected video codec: $video_codec"
echo "Detected audio codec: $audio_codec"

# Determine if we need to re-encode
needs_video_reencode=false
needs_audio_reencode=false

# AV1 not supported by older TVs (e.g., LG C8)
if [[ "$video_codec" == "av1" ]]; then
    needs_video_reencode=true
fi

# Opus not widely supported on TVs
if [[ "$audio_codec" == "opus" ]]; then
    needs_audio_reencode=true
fi

if [[ "$needs_video_reencode" == false && "$needs_audio_reencode" == false ]]; then
    echo "No conversion needed"
    exit 0
fi

# Build output filename
output_file="${input_file%.*}.mkv"
if [[ "$output_file" == "$input_file" ]]; then
    output_file="${input_file%.*}_converted.mkv"
fi

# Build ffmpeg command
ffmpeg_args=()

if [[ "$use_vaapi" == true ]]; then
    ffmpeg_args+=(-vaapi_device "$VAAPI_DEVICE")
fi

ffmpeg_args+=(-i "$input_file")

if [[ "$needs_video_reencode" == true ]]; then
    if [[ "$use_vaapi" == true ]]; then
        echo "Will re-encode video from $video_codec to H.265 (VAAPI hardware)..."
        ffmpeg_args+=(-vf 'format=nv12,hwupload' -c:v hevc_vaapi -qp 20)
    else
        echo "Will re-encode video from $video_codec to H.265 (software)..."
        ffmpeg_args+=(-c:v libx265 -crf 18 -preset slow)
    fi
else
    ffmpeg_args+=(-c:v copy)
fi

if [[ "$needs_audio_reencode" == true ]]; then
    echo "Will re-encode audio from $audio_codec to AAC..."
    ffmpeg_args+=(-c:a aac -b:a 192k)
else
    ffmpeg_args+=(-c:a copy)
fi

ffmpeg_args+=("$output_file")

echo "Converting..."
ffmpeg "${ffmpeg_args[@]}"
echo "Created: $output_file"
