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
ffmpeg_args=(-i "$input_file")

if [[ "$needs_video_reencode" == true ]]; then
    echo "Will re-encode video from $video_codec to H.265..."
    # CRF 18 is visually lossless, preset slow for better compression
    ffmpeg_args+=(-c:v libx265 -crf 18 -preset slow)
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
