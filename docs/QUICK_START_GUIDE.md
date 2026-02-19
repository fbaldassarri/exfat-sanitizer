# exfat-sanitizer — Quick Start Guide

**Version 12.1.4** — Get started in 5 minutes. No complex setup required!

**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)

---

## 30-Second Overview

**What It Does:** Safely renames files and folders to work across different devices (Mac, Windows, Linux, USB drives, etc.) while preserving accented characters (à, è, é, ì, ò, ù, ö, ü, ï, ê, etc.).

**Who Needs It:** Anyone syncing files between different computers or devices who encounters:
- Files disappearing or failing during copy
- Sync failures between devices
- Cryptic error messages about filenames
- Problems reading files on different OS/hardware
- Needs to keep international characters intact (Loïc, Révérence, Cè di più)

**How It Works:** Preview all changes in a safe dry-run mode first, then apply changes when you're satisfied.

**What's New in v12.1.4:**
- Fixed inverted conditional logic in `sanitize_filename()`
- NFD→NFC normalization improvements for macOS
- `DEBUG_UNICODE` mode for diagnostics
- AppleDouble (`._` file) cleanup guidance

---

## Quick Start (5 Minutes)

### Step 1: Download & Setup (1 minute)

```bash
# Download the latest version
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.4/exfat-sanitizer-v12.1.4.sh

# Make it executable
chmod +x exfat-sanitizer-v12.1.4.sh

# Verify Python 3 is installed (REQUIRED)
python3 --version
# Should show Python 3.6 or higher

# Test the script
./exfat-sanitizer-v12.1.4.sh ~/Music
# Expected: configuration info displayed and a CSV file created
```

**Python 3 not installed?**

```bash
# macOS (usually pre-installed on 12.3+)
brew install python3

# Ubuntu/Debian
sudo apt-get install python3

# Fedora/RHEL
sudo dnf install python3
```

### Step 2: Preview Changes (2 minutes)

```bash
# Test with your files (safe — no changes made)
FILESYSTEM=fat32 \
  SANITIZATION_MODE=conservative \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.4.sh /path/to/your/files
```

Replace `/path/to/your/files` with your actual directory — e.g., `~/Music`, `/Volumes/USBDRIVE`, `~/Documents`.

**What you'll see:**

```
EXFAT-SANITIZER v12.1.4
BUG FIX v12.1.4: Inverted logic FIXED - accents now preserved!
Scanning /path/to/your/files
Filesystem: fat32
Sanitization Mode: conservative
Dry Run: true
Preserve Unicode: true
...
SUMMARY
Scanned Directories: 150
Scanned Files: 4074
Ignored Items: 0
Items to Rename: 3

Dry Run: true
NO CHANGES MADE (preview only)
```

### Step 3: Review Results (1 minute)

```bash
# Check the CSV file
open sanitizer_fat32_*.csv        # macOS
# or
cat sanitizer_fat32_*.csv | head -20  # Linux
```

**What to look for in the CSV:**
- `LOGGED` — File checked, no changes needed (already compliant) ✅
- `RENAMED` — File will be renamed to fix illegal characters ⚠️
- `IGNORED` — File matched an ignore pattern
- `FAILED` — Operation failed (usually permissions)

**Example CSV output:**

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|Loïc Nottet.flac|Loïc Nottet.flac|-|Music/|25|LOGGED|NA|-
File|Song<test>.mp3|Song_test_.mp3|IllegalChar|Music/|26|RENAMED|NA|-
```

### Step 4: Apply Changes (1 minute)

If happy with the preview:

```bash
FILESYSTEM=fat32 \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh /path/to/your/files
```

> **Safety Note:** The script never deletes files — it only renames them. The CSV log records old→new names if you ever need to undo.

---

## Common Scenarios

### Scenario 1: Audio Library for FAT32/exFAT USB Drive

Copy your music collection to a USB drive with accents preserved:

```bash
# Step 1: Preview
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.4.sh ~/Music

# Step 2: Review the CSV
open sanitizer_exfat_*.csv

# Step 3: Apply changes
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Music

# Step 4: Copy to USB
cp -r ~/Music /Volumes/USBDRIVE/
```

**What gets preserved:**
- `Loïc Nottet` → `Loïc Nottet` ✅
- `Révérence.flac` → `Révérence.flac` ✅
- `Cè di più.flac` → `Cè di più.flac` ✅
- `Café del Mar.mp3` → `Café del Mar.mp3` ✅

**What gets fixed:**
- `Song<Test>.mp3` → `Song_Test_.mp3` (angle brackets illegal in FAT32)
- `Album*.zip` → `Album_.zip` (asterisk illegal in FAT32)

**Time:** ~5–10 minutes

### Scenario 2: Sanitize + Copy to External Drive

Sanitize filenames and copy them directly to the destination in one pass:

```bash
FILESYSTEM=exfat \
  COPY_TO=/Volumes/USBDRIVE/Musica/ \
  COPY_BEHAVIOR=skip \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
```

With ignore file and tree snapshot:

```bash
FILESYSTEM=exfat \
  COPY_TO=/Volumes/USBDRIVE/Musica/ \
  COPY_BEHAVIOR=skip \
  GENERATE_TREE=true \
  IGNORE_FILE=./exfat-sanitizer-ignore.txt \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
```

### Scenario 3: Generate Directory Snapshot

Export your directory tree before making changes:

```bash
GENERATE_TREE=true \
  FILESYSTEM=fat32 \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
# Output: tree_fat32_YYYYMMDD_HHMMSS.csv
```

### Scenario 4: Copy with Versioning

Smart backup with automatic version control:

```bash
FILESYSTEM=fat32 \
  COPY_TO=/Volumes/Backup/ \
  COPY_BEHAVIOR=version \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
```

Result on repeated runs:
- 1st run: `song.mp3` → `/Volumes/Backup/song.mp3`
- 2nd run: `song.mp3` → `/Volumes/Backup/song-v1.mp3`
- 3rd run: `song.mp3` → `/Volumes/Backup/song-v2.mp3`

### Scenario 5: Syncing Between Mac and Windows

Files work on Mac but not on Windows:

```bash
# Use universal mode for maximum cross-platform compatibility
FILESYSTEM=universal \
  SANITIZATION_MODE=conservative \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.4.sh ~/Documents

# Apply when ready
FILESYSTEM=universal \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Documents
```

`universal` mode applies the most restrictive rules — works everywhere.

### Scenario 6: Maximum Security for Downloads

Files from the internet with suspicious or dangerous characters:

```bash
FILESYSTEM=universal \
  SANITIZATION_MODE=strict \
  CHECK_SHELL_SAFETY=true \
  CHECK_UNICODE_EXPLOITS=true \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Downloads
```

Protects against:
- `file$(cmd).txt` → `file__cmd_.txt` (shell injection)
- `test‌.pdf` → `test.pdf` (zero-width chars removed)

---

## Configuration Cheat Sheet

### Pick Your Filesystem

```bash
FILESYSTEM=fat32       # USB drives, SD cards, car stereos (RECOMMENDED)
FILESYSTEM=exfat       # Modern USB drives, >4GB file support
FILESYSTEM=apfs        # Mac native (macOS only)
FILESYSTEM=ntfs        # Windows drives
FILESYSTEM=universal   # Works everywhere (most restrictive)
```

**Not sure?** Use `fat32` or `exfat` — both work great for USB drives. Key difference: `fat32` has a 4GB max file size; `exfat` has no limit.

### Pick Your Sanitization Mode

```bash
SANITIZATION_MODE=conservative   # Minimal changes, preserves accents (RECOMMENDED)
SANITIZATION_MODE=strict         # Remove more characters for safety
SANITIZATION_MODE=permissive     # Fastest, least thorough
```

**Best practice:** Start with `conservative`.

### Always Test First

```bash
DRY_RUN=true     # Preview only (DEFAULT — SAFE)
DRY_RUN=false    # Actually make changes
```

> **Pro Tip:** Always run with `DRY_RUN=true` first!

### Unicode Preservation (v12.x)

```bash
PRESERVE_UNICODE=true         # Keep accented characters (DEFAULT)
NORMALIZE_APOSTROPHES=true    # Normalize curly→straight apostrophes (DEFAULT)
EXTENDED_CHARSET=true         # Allow extended character sets (DEFAULT)
DEBUG_UNICODE=false           # NFD/NFC diagnostic output (v12.1.3+)
```

### Optional Features

```bash
GENERATE_TREE=true                    # Create directory structure CSV
CHECK_SHELL_SAFETY=true               # Remove shell metacharacters
CHECK_UNICODE_EXPLOITS=true           # Remove zero-width characters
COPY_TO=/backup/path                  # Copy files to destination
COPY_BEHAVIOR=version                 # Create versioned copies (skip/overwrite/version)
IGNORE_FILE=./my-ignore.txt           # Custom pattern file
REPLACEMENT_CHAR=_                    # Character for replacing illegal chars
```

---

## What Gets Fixed vs. Preserved

### Preserved (v12.1.4)

Accented characters are preserved via FAT32 LFN (UTF-16) support:

```
Loïc Nottet.flac       → PRESERVED ✅
Révérence.flac         → PRESERVED ✅
Cè di più.flac         → PRESERVED ✅  (à, è, ì, ò, ù)
Café del Mar.mp3       → PRESERVED ✅
Müller - España.wav    → PRESERVED ✅  (ä, ö, ü, ñ)
L'interprète.flac      → PRESERVED ✅
Beaux rêves.flac       → PRESERVED ✅
```

### Fixed (Illegal Characters)

Characters forbidden by the target filesystem are replaced:

```
Song<test>.mp3         → Song_test_.mp3    (< > illegal in FAT32)
Track:Album.flac       → Track_Album.flac  (: illegal in FAT32)
File*.zip              → File_.zip         (* illegal in FAT32)
Doc"Quotes".txt        → Doc_Quotes_.txt   (" illegal in FAT32)
Path\File.doc          → Path_File.doc     (\ illegal in FAT32)
```

**FAT32/exFAT Forbidden Characters:** `" * / : < > ? \ |` and control characters (0–31, 127)

### Comparison Table

| Input | v9.0.2.2 (Broken) | v12.1.4 (Fixed) | Status |
|-------|-------------------|-----------------|--------|
| `Loïc Nottet.flac` | `Loic Nottet.flac` | `Loïc Nottet.flac` | `LOGGED` |
| `Révérence.mp3` | `Reverence.mp3` | `Révérence.mp3` | `LOGGED` |
| `Song<Test>.mp3` | `Song_Test_.mp3` | `Song_Test_.mp3` | `RENAMED` |
| `Album*.zip` | `Album_.zip` | `Album_.zip` | `RENAMED` |

---

## Understanding CSV Output

### CSV Format

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|Loïc.flac|Loïc.flac|-|Music/Album/|26|LOGGED|NA|-
File|song<test>.mp3|song_test_.mp3|IllegalChar|Music/|27|RENAMED|COPIED|-
Directory|bad:dir|bad_dir|IllegalChar|Music/|15|RENAMED|NA|-
```

### Status Values

| Status | Meaning | Action |
|--------|---------|--------|
| `LOGGED` | Already compliant — no changes needed | None required ✅ |
| `RENAMED` | Illegal characters found and replaced | Review new name |
| `IGNORED` | Matched an ignore pattern | None required |
| `FAILED` | Operation failed (permissions, collision) | Check permissions |

### Copy Status Values

| Status | Meaning |
|--------|---------|
| `COPIED` | Successfully copied to destination |
| `SKIPPED` | Skipped (conflict with `COPY_BEHAVIOR=skip`) |
| `NA` | No copy operation (`COPY_TO` not set) |

---

## Ignore Patterns

Create an ignore file to skip specific files, directories, or patterns:

### Example Ignore File

```bash
# exfat-sanitizer-ignore.txt

# macOS metadata
.DS_Store
.AppleDouble
.AppleDB
.LSOverride
.TemporaryItems

# Windows metadata
Thumbs.db
Desktop.ini

# Syncthing
.stfolder
.stignore

# FreeFileSync
.sync.ffs_db
.sync.ffsdb

# System/indexing
.Spotlight-V100
.metadata

# Custom patterns
*.tmp
*.bak
NOTE.txt
.fseventsd
```

### Usage

```bash
IGNORE_FILE=./exfat-sanitizer-ignore.txt ./exfat-sanitizer-v12.1.4.sh ~/Music
```

A ready-to-use example file is included in the repository: [`exfat-sanitizer-ignore.example.txt`](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/exfat-sanitizer-ignore.example.txt)

---

## Workflow Example (Step by Step)

A complete walkthrough for cleaning up a French/Italian music library for a USB drive.

### Step 1: Verify Python 3

```bash
python3 --version
# Should show Python 3.6 or higher
```

### Step 2: Navigate to your music folder

```bash
cd ~/Music
pwd  # Verify path
```

### Step 3: Backup first (recommended)

```bash
cp -r ~/Music ~/Music_Backup
```

### Step 4: Preview changes (SAFE)

```bash
FILESYSTEM=fat32 \
  SANITIZATION_MODE=conservative \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
```

### Step 5: Check the CSV output

```bash
# View summary
cat sanitizer_fat32_*.csv | tail -20

# Or open in Excel/Numbers
open sanitizer_fat32_*.csv
```

**What to check:**
- How many files need renaming? (Should be 0 if only accents present)
- Any illegal characters (`<`, `>`, `:`, `*`) found? These will be replaced.
- Any "Path too long" errors? Shorten folder names manually.
- Accented files show `LOGGED` status (not `RENAMED`).

### Step 6: Apply changes

```bash
FILESYSTEM=fat32 \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
```

### Step 7: Verify changes

```bash
# Check for any renames
grep "RENAMED" sanitizer_fat32_*.csv
# Should only show files with illegal characters, NOT accents
```

### Step 8: Copy to USB

```bash
cp -r ~/Music /Volumes/USBDRIVE/
# Done! Accented filenames are preserved!
```

---

## Time Estimates

| Task | Time | Prerequisites |
|------|------|---------------|
| Install Python 3 | ~2 min | Internet connection |
| Download & setup | ~1 min | Internet connection |
| Preview (dry-run) | ~15–30 sec | 100–10,000 files |
| Review CSV | ~1 min | Text editor |
| Apply changes | ~15–30 sec | Review complete |
| Copy to USB | ~5–30 min | Depends on file size |
| **Total** | **~10–40 min** | **Start to finish** |

---

## Quick Command Reference

```bash
# Most common: Audio library for USB (accents preserved!)
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music

# Maximum compatibility (Mac ↔ Windows)
FILESYSTEM=universal SANITIZATION_MODE=conservative DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Documents

# Maximum security (untrusted files)
FILESYSTEM=universal SANITIZATION_MODE=strict CHECK_SHELL_SAFETY=true CHECK_UNICODE_EXPLOITS=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Downloads

# With directory tree export
FILESYSTEM=fat32 GENERATE_TREE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music

# Copy mode with versioning
FILESYSTEM=fat32 COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false ./exfat-sanitizer-v12.1.4.sh ~/Music

# Copy to exFAT drive with ignore file
FILESYSTEM=exfat COPY_TO=/Volumes/USBDRIVE/Musica/ IGNORE_FILE=./exfat-sanitizer-ignore.txt DRY_RUN=false ./exfat-sanitizer-v12.1.4.sh ~/Music

# Debug Unicode normalization
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music 2>debug.log

# Apply changes after testing!
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=false ./exfat-sanitizer-v12.1.4.sh ~/Music
```

---

## Pro Tips

### Tip 1: Always Backup First

```bash
# Copy to a backup location first
cp -r ~/Music ~/Music_Backup

# Then test on original
FILESYSTEM=fat32 DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music
```

### Tip 2: Generate Tree Snapshot

```bash
# See directory structure before changes
GENERATE_TREE=true FILESYSTEM=fat32 DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music
# Creates: tree_fat32_YYYYMMDD_HHMMSS.csv — complete directory tree
```

### Tip 3: Use Copy Mode for Backup

```bash
# Copy to backup with sanitization + versioning
FILESYSTEM=fat32 \
  COPY_TO=/Volumes/Backup \
  COPY_BEHAVIOR=version \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
```

### Tip 4: Automate Regular Cleanups

```bash
# Create a reusable script
cat > sanitize-music.sh << 'EOF'
#!/bin/bash
FILESYSTEM=fat32 \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
echo "Sanitization complete on $(date)" >> ~/Music_Cleanup.log
EOF

chmod +x sanitize-music.sh
./sanitize-music.sh
```

### Tip 5: Test Accent Preservation

```bash
# Create test files to verify
mkdir -p /tmp/test-accents && cd /tmp/test-accents
touch "Loïc Nottet.flac"
touch "Révérence.mp3"
touch "Cè di più.wav"

# Run sanitizer
FILESYSTEM=fat32 DRY_RUN=true ../exfat-sanitizer-v12.1.4.sh /tmp/test-accents

# Check CSV — all should show LOGGED (not RENAMED)
grep -E "Loïc|Révérence|Cè" sanitizer_fat32_*.csv
```

---

## FAQ (Quick Answers)

**Q: Will this delete my files?**
No! It only renames files. Nothing is deleted, ever.

**Q: Can I undo changes?**
The CSV file records all old→new names. You can manually rename back if needed.

**Q: Do I need Python 3?**
Yes. Python 3 (3.6+) is required for proper UTF-8 handling. macOS 12.3+ includes it by default.

**Q: My files didn't change — is that bad?**
No! That means your files are already compatible. Status: `LOGGED`. That's good!

**Q: Will accents be stripped like in older versions?**
No! v12.1.4 preserves all accents via FAT32 LFN (UTF-16) support. Only illegal characters (`<`, `>`, `:`, `*`, etc.) are replaced.

**Q: How long does it take?**
For ~4,000 files: 15–30 seconds (dry-run or apply).

**Q: Does it work on Windows?**
Yes, with WSL (Windows Subsystem for Linux), Git Bash, or Cygwin.

**Q: Which filesystem should I use?**
- Modern USB drive → `exfat`
- Old USB drive / car stereo → `fat32`
- Mac only → `apfs`
- Windows only → `ntfs`
- Not sure / multiple systems → `universal`

**Q: What does "Path too long" mean?**
The full filename + directory path exceeds the filesystem limit. Shorten folder names or file names.

**Q: What changed in v12.1.4?**
Fixed inverted conditional logic in character classification, improved NFD→NFC normalization for macOS, and added `DEBUG_UNICODE` diagnostic mode.

---

## Troubleshooting

### Python3 not found

```bash
python3 --version
# If missing:
brew install python3          # macOS
sudo apt-get install python3  # Ubuntu/Debian
sudo dnf install python3      # Fedora/RHEL
```

### Permission denied

```bash
# Make script executable
chmod +x exfat-sanitizer-v12.1.4.sh

# Check file/directory permissions
ls -la /path/to/files

# Fix permissions if needed
chmod -R u+rw /path/to/files
```

### No such file or directory

```bash
# Make sure path exists
ls -la /path/to/files

# Make sure you're in the right directory
pwd

# Use absolute path if needed
./exfat-sanitizer-v12.1.4.sh ~/Music
```

### Files not being renamed

```bash
# Check if you're in dry-run mode (default)
echo "DRY_RUN is $DRY_RUN"

# To actually apply changes:
DRY_RUN=false ./exfat-sanitizer-v12.1.4.sh /path/to/files
```

### Accents are being stripped

```bash
# Check your version
head -3 exfat-sanitizer-v12.1.4.sh
# Expected: SCRIPT_VERSION="12.1.4"

# Enable debug mode
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music 2>debug.log
grep "MISMATCH" debug.log

# If you see an older version, download v12.1.4:
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.4/exfat-sanitizer-v12.1.4.sh
```

### CSV shows nothing

```bash
# Directory might be empty
ls /path/to/files | wc -l

# Or all files are already compliant (good!)
grep "LOGGED" sanitizer_*.csv | wc -l
```

---

## Why v12.1.4?

| Version | Accent Preservation | Production Ready | Recommendation |
|---------|--------------------|--------------------|----------------|
| v9.0.2.2 | ❌ Broken | No | Avoid |
| v11.0.5 | ✅ Fixed | Yes | Upgrade to v12.1.4 |
| v11.1.0 | ✅ Fixed | Yes | Upgrade to v12.1.4 |
| v12.0.0 | ⚠️ Partial | Partial | Skip |
| v12.1.0 | ⚠️ Partial | Partial | Skip |
| v12.1.1 | ❌ Critical Bug | No | **DO NOT USE** |
| v12.1.2 | ✅ Fixed | Yes | Upgrade to v12.1.4 |
| v12.1.3 | ⚠️ Inverted Logic | Partial | Skip |
| **v12.1.4** | **✅ Fixed** | **Yes** | **← RECOMMENDED** |

---

## Best Practice: Cleaning Up macOS AppleDouble (`._`) Files

When you copy files to an exFAT or FAT32 volume on macOS, the system automatically creates `._` (dot-underscore) companion files alongside every file and folder. These are **AppleDouble resource forks** — macOS metadata that the target filesystem cannot store natively.

### How to Identify Them

```bash
$ ls -las /Volumes/USBDRIVE/Music/Elisa/
256 -rwx------  1 user  staff    4096 17 Feb 01:08 ._1997 Elisa - Pipes and Flowers (Album)
256 drwx------@ 1 user  staff  131072 17 Feb 01:08   1997 Elisa - Pipes and Flowers (Album)
256 -rwx------  1 user  staff    4096 17 Feb 01:09 ._2001 Elisa - Then Comes the Sun (Album)
256 drwx------@ 1 user  staff  131072 17 Feb 01:09   2001 Elisa - Then Comes the Sun (Album)
```

Every `._` file is exactly **4,096 bytes** (4KB) and mirrors a real file or folder name. These files are invisible in Finder but visible in Terminal and on non-macOS devices.

### Option 1: `dot_clean` (Recommended — macOS Built-In)

The `dot_clean` command merges `._` files back into their parent files or removes orphaned ones:

```bash
# Merge ._ files into their native resources, remove leftovers
dot_clean -m /Volumes/USBDRIVE/

# Example: clean a specific music folder
dot_clean -m /Volumes/2.5ex/Musica/

# Verbose mode (see what's being processed)
dot_clean -mv /Volumes/USBDRIVE/
```

The `-m` flag means "merge if possible, delete if orphaned." This is the safest and cleanest approach.

### Option 2: `find` + `delete` (Fast Bulk Removal)

If you just want to delete all `._` files without merging:

```bash
# Delete all ._ files on the entire volume
find /Volumes/USBDRIVE/ -name '._*' -delete

# Example: clean a specific music drive
find /Volumes/2.5ex/ -name '._*' -delete

# Preview first (list without deleting)
find /Volumes/USBDRIVE/ -name '._*' -print

# Count how many there are
find /Volumes/USBDRIVE/ -name '._*' | wc -l
```

### Option 3: Prevent `._` Files System-Wide (macOS Setting)

Prevent macOS from creating `._` files on USB and network drives entirely:

```bash
# Disable ._ file creation on USB drives
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Disable ._ file creation on network drives
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Requires logout/restart to take effect
```

To re-enable:

```bash
defaults delete com.apple.desktopservices DSDontWriteUSBStores
defaults delete com.apple.desktopservices DSDontWriteNetworkStores
```

### Option 4: Delete `.DS_Store` Files Too

For a complete cleanup, remove both `._` and `.DS_Store` files:

```bash
# Full macOS metadata cleanup on an external drive
find /Volumes/USBDRIVE/ -name '._*' -delete
find /Volumes/USBDRIVE/ -name '.DS_Store' -delete

# One-liner for both
find /Volumes/USBDRIVE/ \( -name '._*' -o -name '.DS_Store' \) -delete
```

### Recommended Post-Copy Workflow

After running exfat-sanitizer with `COPY_TO`, clean up the destination volume:

```bash
# Step 1: Sanitize + copy to USB
FILESYSTEM=exfat \
  COPY_TO=/Volumes/2.5ex/Musica/ \
  IGNORE_FILE=./exfat-sanitizer-ignore.txt \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Music

# Step 2: Clean up ._ files (choose one)
dot_clean -m /Volumes/2.5ex/Musica/          # Option A: merge/clean (recommended)
# or
find /Volumes/2.5ex/Musica/ -name '._*' -delete  # Option B: bulk delete

# Step 3: Optionally remove .DS_Store files too
find /Volumes/2.5ex/Musica/ -name '.DS_Store' -delete

# Step 4: Verify — no ._ files remaining
find /Volumes/2.5ex/Musica/ -name '._*' | wc -l
# Expected: 0
```

> **Note:** This cleanup only needs to be done once after each copy operation. If you prevent `._` file creation system-wide (Option 3), you won't need to clean up at all.

---

## Additional Resources

### Documentation

- [README.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/README.md) — Comprehensive documentation
- [RELEASE-v12.1.4.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/RELEASE-v12.1.4.md) — Release notes
- [CHANGELOG-v12.1.4.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/CHANGELOG-v12.1.4.md) — Complete version history

### Support

- [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues) — Report bugs
- [GitHub Discussions](https://github.com/fbaldassarri/exfat-sanitizer/discussions) — Ask questions
- [Latest Release](https://github.com/fbaldassarri/exfat-sanitizer/releases) — Download

---

## Success Checklist

After running exfat-sanitizer v12.1.4, you should be able to:

- ✅ Copy files to FAT32/exFAT USB drives without errors
- ✅ Sync between Mac and Windows without issues
- ✅ Preserve accented characters (Loïc, Révérence, Cè di più)
- ✅ Open files on different devices
- ✅ See all files in directory listings
- ✅ Safely backup files across systems
- ✅ No more "illegal character" errors
- ✅ Clean destination volume free of `._` clutter

---

*Start with Step 1 above, and you'll be sanitizing files — with accents preserved! — in no time!*

**Need Help?** See [README.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/README.md) for detailed docs, or open an [issue](https://github.com/fbaldassarri/exfat-sanitizer/issues).

---

**Last Updated:** February 17, 2026
**Version:** 12.1.4
**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)
**Maintainer:** [fbaldassarri](https://github.com/fbaldassarri)
