#!/bin/bash

# backup-versioning.sh
# Example: Backup with automatic versioning

# Use case: Creating backups with smart conflict resolution
# Features: Creates versioned copies (file-v1.ext, file-v2.ext) on conflicts
# Best for: Incremental backups, version control, testing

# Configuration
FILESYSTEM=exfat
SANITIZATION_MODE=conservative
COPY_TO="/Volumes/Backup"  # Change this to your backup destination
COPY_BEHAVIOR=version
DRY_RUN=false

# Source directory (change this to your source directory)
SOURCE_DIR="$HOME/Music"

# Check if backup destination exists
if [ ! -d "$COPY_TO" ]; then
    echo "❌ Error: Backup destination not found: $COPY_TO"
    echo ""
    echo "Please update COPY_TO variable in this script to point to your backup drive."
    echo "Example: COPY_TO=\"/Volumes/MyBackupDrive\""
    exit 1
fi

# Run sanitizer with backup and versioning
echo "Backing up with automatic versioning..."
echo "Source: $SOURCE_DIR"
echo "Destination: $COPY_TO"
echo ""
echo "v12.1.2 improvements:"
echo " ✅ Accents preserved (Loïc, Révérence, Café)"
echo " ✅ Curly apostrophes normalized safely"
echo " ✅ No UTF-8 corruption"
echo ""
echo "Versioning behavior:"
echo " • First run: song.mp3 → $COPY_TO/song.mp3"
echo " • Second run: song.mp3 → $COPY_TO/song-v1.mp3"
echo " • Third run: song.mp3 → $COPY_TO/song-v2.mp3"
echo ""

FILESYSTEM=$FILESYSTEM \
SANITIZATION_MODE=$SANITIZATION_MODE \
COPY_TO="$COPY_TO" \
COPY_BEHAVIOR=$COPY_BEHAVIOR \
DRY_RUN=$DRY_RUN \
./exfat-sanitizer-v12.1.2.sh "$SOURCE_DIR"

echo ""
echo "✅ Backup complete with versioning"
echo ""
echo "Check CSV log for details on copied/versioned files."
echo "Files are sanitized for $FILESYSTEM compatibility and copied to:"
echo "  $COPY_TO"
