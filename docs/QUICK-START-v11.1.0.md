# Quick Start Guide - exfat-sanitizer v11.1.0

## Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/fbaldassarri/exfat-sanitizer/main/exfat-sanitizer-v11.1.0.sh

# Make it executable
chmod +x exfat-sanitizer-v11.1.0.sh

# Test with dry-run (safe, no changes)
./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

## Common Usage Patterns

### 1. Preview Changes (Safe Mode)

```bash
# Default behavior: preview only, no changes
./exfat-sanitizer-v11.1.0.sh ~/Music

# Explicit dry-run
DRY_RUN=true ./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Output:**
- ✅ Shows what WOULD change
- ✅ Generates CSV report
- ❌ Makes NO actual changes

---

### 2. Apply Changes (Live Mode)

```bash
# Apply sanitization changes
DRY_RUN=false ./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Output:**
- ✅ Actually renames files/directories
- ✅ Generates CSV report
- ⚠️ **Changes are permanent**

---

### 3. Audio Library (Recommended Settings)

```bash
# Preserve accents, apostrophes - perfect for music
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Preserves:**
- ✅ `Café del Mar.mp3` → unchanged
- ✅ `L'interprète.flac` → unchanged
- ✅ `Müller - España.wav` → unchanged

**Removes:**
- ❌ `song<test>.mp3` → `song_test_.mp3`
- ❌ `track:new.flac` → `track_new.flac`

---

### 4. Maximum Security (Untrusted Files)

```bash
# Remove shell-dangerous characters and Unicode exploits
FILESYSTEM=universal \
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**Removes:**
- ❌ `file$(cmd).txt` → `file__cmd_.txt` (shell injection protection)
- ❌ `test​​​.pdf` → `test.pdf` (zero-width chars removed)
- ❌ `doc<script>.html` → `doc_script_.html`

---

### 5. Copy to Backup with Versioning

```bash
# Copy files to backup, create versions on conflicts
FILESYSTEM=exfat \
COPY_TO=/Volumes/Backup \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Result:**
- First run: `song.mp3` → `/Volumes/Backup/song.mp3`
- Second run: `song.mp3` → `/Volumes/Backup/song-v1.mp3`
- Third run: `song.mp3` → `/Volumes/Backup/song-v2.mp3`

---

## Configuration Variables

### Essential Variables

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `FILESYSTEM` | `fat32` | `fat32`, `exfat`, `ntfs`, `apfs`, `hfsplus`, `universal` | Target filesystem type |
| `SANITIZATION_MODE` | `conservative` | `strict`, `conservative`, `permissive` | How aggressive to sanitize |
| `DRY_RUN` | `true` | `true`, `false` | Preview mode (true) or apply changes (false) |

### Copy Mode Variables (NEW in v11.1.0)

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `COPY_TO` | (empty) | `/path/to/dest` | Destination directory for copying |
| `COPY_BEHAVIOR` | `skip` | `skip`, `overwrite`, `version` | How to handle file conflicts |

### Advanced Variables (NEW in v11.1.0)

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `CHECK_SHELL_SAFETY` | `false` | `true`, `false` | Remove shell metacharacters |
| `CHECK_UNICODE_EXPLOITS` | `false` | `true`, `false` | Remove zero-width characters |
| `REPLACEMENT_CHAR` | `_` | Any single char | Character for replacing illegal chars |
| `GENERATE_TREE` | `false` | `true`, `false` | Generate directory tree CSV |
| `IGNORE_FILE` | `~/.exfat-sanitizer-ignore` | File path | Custom ignore patterns file |

---

## Filesystem Types Explained

### `exfat` (Modern Removable Media)
**Use for:** Modern USB drives, SD cards (4GB+ files)
```bash
FILESYSTEM=exfat ./exfat-sanitizer-v11.1.0.sh ~/Music
```
- ✅ Allows: apostrophes, accents, Unicode
- ❌ Forbids: `" * / : < > ? \ |` + control chars

### `fat32` (Legacy Compatibility)
**Use for:** Older USB drives, car stereos, legacy devices
```bash
FILESYSTEM=fat32 ./exfat-sanitizer-v11.1.0.sh ~/Music
```
- ✅ Allows: apostrophes, accents, Unicode
- ❌ Forbids: `" * / : < > ? \ |` + control chars
- ⚠️ File size limit: 4GB max

### `universal` (Maximum Compatibility)
**Use for:** Unknown destination, maximum safety
```bash
FILESYSTEM=universal ./exfat-sanitizer-v11.1.0.sh ~/Downloads
```
- Most restrictive
- Ensures files work on ANY system

### `apfs` / `ntfs` / `hfsplus`
**Use for:** Specific native filesystems
```bash
FILESYSTEM=apfs ./exfat-sanitizer-v11.1.0.sh ~/Documents  # macOS
FILESYSTEM=ntfs ./exfat-sanitizer-v11.1.0.sh ~/Documents  # Windows
```

---

## Sanitization Modes Explained

### `conservative` (Recommended Default)
```bash
SANITIZATION_MODE=conservative ./exfat-sanitizer-v11.1.0.sh ~/Music
```
- Removes only **officially forbidden** characters per filesystem
- Preserves: apostrophes, accents, Unicode, spaces
- **Best for:** Music libraries, documents, general use

### `strict` (Maximum Safety)
```bash
SANITIZATION_MODE=strict ./exfat-sanitizer-v11.1.0.sh ~/Downloads
```
- Removes **all problematic** characters
- Removes control characters
- **Best for:** Untrusted sources, automation scripts

### `permissive` (Minimal Changes)
```bash
SANITIZATION_MODE=permissive ./exfat-sanitizer-v11.1.0.sh ~/Music
```
- Removes only **universal forbidden** characters
- Fastest, least invasive
- **Best for:** Speed-optimized workflows

---

## Copy Behavior Options (NEW in v11.1.0)

### `skip` (Default - Safe)
```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=skip DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```
**Behavior:** Skip if destination file already exists

**Use case:** Incremental backups, don't overwrite existing files

### `overwrite` (Replace Existing)
```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=overwrite DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```
**Behavior:** Replace destination file if it exists

**Use case:** Full backups, synchronization

### `version` (Create Versions)
```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```
**Behavior:** Create versioned copies (file-v1.ext, file-v2.ext)

**Use case:** Keep multiple versions, testing, archival

---

## Advanced Features

### Shell Safety (NEW in v11.1.0)

**Enable shell safety for untrusted files:**
```bash
CHECK_SHELL_SAFETY=true ./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**What it does:**
- Removes: `$` `` ` `` `&` `;` `#` `~` `^` `!` `(` `)`
- Protects against shell injection attacks
- **Use when:** Processing files from internet, email attachments

**Example:**
```bash
Input:  "file$(rm -rf /).sh"
Output: "file__rm -rf ___.sh"  # Shell chars neutralized
```

---

### Unicode Exploit Detection (NEW in v11.1.0)

**Enable zero-width character removal:**
```bash
CHECK_UNICODE_EXPLOITS=true ./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**What it does:**
- Removes: U+200B (zero-width space), U+200C, U+200D, U+FEFF
- Prevents visual spoofing attacks
- **Use when:** Files from untrusted sources

**Example:**
```bash
Input:  "file​​​.pdf"  # Contains invisible zero-width spaces
Output: "file.pdf"    # Cleaned
```

---

### Custom Replacement Character (NEW in v11.1.0)

**Change what replaces illegal characters:**
```bash
# Use dash instead of underscore
REPLACEMENT_CHAR=- ./exfat-sanitizer-v11.1.0.sh ~/Music

# Use space
REPLACEMENT_CHAR=" " ./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Example:**
```bash
# With REPLACEMENT_CHAR=_
"song<test>.mp3" → "song_test_.mp3"

# With REPLACEMENT_CHAR=-
"song<test>.mp3" → "song-test-.mp3"
```

---

### System File Filtering (NEW in v11.1.0)

**Automatically skips these files (no configuration needed):**
- `.DS_Store` (macOS Finder)
- `Thumbs.db` (Windows thumbnails)
- `.Spotlight-V100` (macOS Spotlight)
- `.stfolder`, `.sync.ffs_db` (Sync tools)
- `.gitignore`, `.stignore` (Version control)

**Result:** Cleaner CSV logs, faster processing

---

## Output Files

### CSV Log Format

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|song$.mp3|song_.mp3|ShellDangerous|Music/Album|25|RENAMED|COPIED|-
File|track.flac|track.flac|-|Music/Album|26|LOGGED|SKIPPED|-
Directory|bad<dir>|bad_dir_|UniversalForbidden|Music|20|RENAMED|NA|-
```

**Columns:**
- `Type`: File or Directory
- `Old Name`: Original filename
- `New Name`: Sanitized filename
- `Issues`: Detected problems (ShellDangerous, UniversalForbidden, etc.)
- `Path`: Parent directory path
- `Path Length`: Full path character count
- `Status`: RENAMED, LOGGED, IGNORED, FAILED
- `Copy Status`: COPIED, SKIPPED, NA (NEW in v11.1.0)
- `Ignore Pattern`: match or - (if ignored via pattern file)

---

### Tree Export (Optional)

```bash
# Generate directory tree snapshot
GENERATE_TREE=true ./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Generates:** `tree_<filesystem>_<timestamp>.csv`

```csv
Type|Name|Path|Depth
Directory|Music||0
Directory|Album|Album|1
File|song1.mp3|Album/song1.mp3|1
File|song2.flac|Album/song2.flac|1
```

---

## Ignore Patterns

### Create Ignore File

```bash
# Create ignore patterns file
cat > ~/.exfat-sanitizer-ignore << 'EOF'
# Ignore specific directories
backup/*
archive/*

# Ignore specific file patterns
*.tmp
*.bak

# Ignore specific files
debug.log
EOF
```

### Use Custom Ignore File

```bash
# Use custom ignore file
IGNORE_FILE=/path/to/custom-ignore.txt \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

## Real-World Examples

### Example 1: Clean Audio Library for USB Drive

**Scenario:** Preparing music for exFAT USB drive

```bash
# 1. Preview changes first
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=true \
./exfat-sanitizer-v11.1.0.sh ~/Music

# 2. Review CSV output
cat sanitizer_exfat_*.csv

# 3. Apply changes
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Result:**
- ✅ Accents preserved: `Café`, `España`, `Müller`
- ✅ Apostrophes preserved: `L'interprète`
- ❌ Illegal chars removed: `song:test.mp3` → `song_test.mp3`

---

### Example 2: Copy to Backup with Versioning

**Scenario:** Incremental backup with version control

```bash
# Copy sanitized files to backup with versioning
FILESYSTEM=exfat \
COPY_TO=/Volumes/Backup \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Result:**
- First run: Files copied to `/Volumes/Backup/`
- Second run: Conflicts create versioned copies (`song-v1.mp3`)
- CSV shows `Copy Status: COPIED` or `SKIPPED`

---

### Example 3: Security Scan for Downloaded Files

**Scenario:** Clean untrusted downloads with maximum security

```bash
# Maximum security mode
FILESYSTEM=universal \
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**Removes:**
- Shell metacharacters: `$` `` ` `` `&` `;` etc.
- Zero-width characters
- Control characters
- Universal forbidden characters

**Result:** Safe filenames for automation scripts

---

## Troubleshooting

### Issue: "No changes detected"

**Cause:** Files already compliant

**Solution:** Check CSV log - files may already be sanitized

---

### Issue: "Permission denied"

**Cause:** Insufficient permissions

**Solution:**
```bash
# Check permissions
ls -la ~/Music

# Run with proper permissions
sudo ./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

### Issue: "Unicode normalization not working"

**Cause:** Missing Python3/uconv/perl

**Solution:**
```bash
# Install Python3 (macOS)
brew install python3

# Install Python3 (Ubuntu/Debian)
sudo apt-get install python3

# Or install ICU tools
brew install icu4c  # macOS
```

---

### Issue: "Accents still being stripped"

**Verification:**
```bash
# Make sure you're using v11.1.0 (not v9.0.2.2)
head -1 exfat-sanitizer-v11.1.0.sh | grep "v11.1.0"
```

**Expected output:**
```
# exfat-sanitizer v11.1.0 - COMPREHENSIVE RELEASE
```

---

## Quick Reference Card

```bash
# 1. AUDIO LIBRARY (safe, preserve accents)
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music

# 2. MAXIMUM SECURITY (untrusted files)
SANITIZATION_MODE=strict CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Downloads

# 3. COPY WITH VERSIONING (backup)
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music

# 4. PREVIEW ONLY (safe, no changes)
DRY_RUN=true ./exfat-sanitizer-v11.1.0.sh ~/Music

# 5. CUSTOM REPLACEMENT (use dash)
REPLACEMENT_CHAR=- DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

## Getting Help

```bash
# Show usage information
./exfat-sanitizer-v11.1.0.sh

# Or without arguments
./exfat-sanitizer-v11.1.0.sh
```

---

**Version:** 11.1.0  
**Release Date:** 2026-02-01  
**Documentation:** See CHANGELOG-v11.1.0.md for full feature list
