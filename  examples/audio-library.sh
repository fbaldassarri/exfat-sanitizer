#!/bin/bash

# audio-library.sh
# Example: Sanitize audio library for exFAT USB drive

# Use case: Preparing music collection for a USB drive or SD card
# Preserves: Accents, apostrophes, Unicode characters (v12.1.2 FIXED!)
# Removes: Only illegal characters for exFAT filesystem

# Configuration
FILESYSTEM=exfat
SANITIZATION_MODE=conservative
DRY_RUN=false

# Source directory (change this to your music directory)
SOURCE_DIR="$HOME/Music"

# Run sanitizer
echo "Sanitizing audio library for exFAT drive..."
echo "Source: $SOURCE_DIR"
echo ""

FILESYSTEM=$FILESYSTEM \
SANITIZATION_MODE=$SANITIZATION_MODE \
DRY_RUN=$DRY_RUN \
./exfat-sanitizer-v12.1.2.sh "$SOURCE_DIR"

echo ""
echo "✅ Audio library sanitized for exFAT drive"
echo ""
echo "What was preserved (v12.1.2 Unicode-safe!):"
echo " ✅ Café del Mar.mp3"
echo " ✅ L'interprète.flac"
echo " ✅ Müller - España.wav"
echo " ✅ Loïc Nottet's Song.flac  ← v12.1.2 FIX! (apostrophe + accent)"
echo " ✅ C'è di più.ogg  ← Accents preserved!"
echo ""
echo "What was sanitized:"
echo " ❌ song<test>.mp3 → song_test_.mp3"
echo " ❌ track:new.flac → track_new.flac"
