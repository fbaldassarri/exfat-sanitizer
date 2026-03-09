#!/bin/bash

# Audio Library Sanitizer for exFAT Drive
# Uses exfat-sanitizer v13.0.0

# Configuration
FILESYSTEM=exfat
SANITIZATION_MODE=conservative
DRY_RUN=false

# Source directory (change this to your music directory)
SOURCE_DIR="$HOME/Music"

echo "Sanitizing audio library for exFAT drive..."
echo "Source: $SOURCE_DIR"
echo ""

FILESYSTEM=$FILESYSTEM \
  SANITIZATION_MODE=$SANITIZATION_MODE \
  DRY_RUN=$DRY_RUN \
  ./exfat-sanitizer-v13.0.0.sh "$SOURCE_DIR"

echo ""
echo "Audio library sanitized for exFAT drive"
echo ""
echo "What was preserved (v13.0.0 Unicode-safe!):"
echo "  ✅ Café del Mar.mp3"
echo "  ✅ L'interprète.flac"
echo "  ✅ Müller - España.wav"
echo "  ✅ Loïc Nottet's Song.flac  (apostrophe + accent preserved)"
echo "  ✅ C'è di più.ogg  (Accents preserved!)"
echo ""
echo "What was sanitized:"
echo "  song<test>.mp3 → song_test_.mp3"
echo "  track:new.flac → track_new.flac"
