# exfat-sanitizer: Quick Start Guide

**Version:** 12.1.2  
**Get started in 5 minutes** - No complex setup required!

---

## 🎯 30-Second Overview

**What It Does**: Safely renames files and folders to work across different devices (Mac, Windows, Linux, USB drives, etc.) while **preserving accented characters** (è, é, à, ñ, ö, ü, etc.)

**Who Needs It**: Anyone syncing files between different computers or devices who encounters:
- ❌ Files disappearing during copy
- ❌ Sync failures between devices
- ❌ Cryptic error messages about filenames
- ❌ Problems reading files on different computers
- ✅ Wants to keep international characters intact (Loïc, Révérence, C'è di più)

**How It Works**: Preview all changes in a safe mode first, then apply changes if you're happy

**What's New in v12.1.2**: 🔴 **CRITICAL FIX** - Apostrophe normalization no longer corrupts Unicode characters!

---

## ⚡ Quick Start (5 Minutes)

### Step 1: Download & Setup (1 minute)

```bash
# Download the latest version
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.2/exfat-sanitizer-v12.1.2.sh

# Make it executable
chmod +x exfat-sanitizer-v12.1.2.sh

# Verify Python 3 is installed (REQUIRED)
python3 --version
# Should show Python 3.6 or higher

# Test the script
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Expected Output**: You should see configuration info and a CSV file created.

### Step 2: Preview Changes (2 minutes)

```bash
# Test with your files (safe - no changes made)
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh /path/to/your/files
```

**What to Replace**:
- `/path/to/your/files` → Your actual directory path
  - Examples: `~/Music`, `/Volumes/USB_Drive`, `~/Documents`

**What You'll See**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exfat-sanitizer v12.1.2
Filesystem: fat32
Sanitization Mode: conservative
Dry Run: true
Preserve Unicode: true
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ CSV Log: sanitizer_fat32_20260203_123456.csv
Processing directories...
Processing files...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary:
 Total Items Scanned: 4074
 Items to Rename: 0
 Already Compliant: 4074
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DRY RUN MODE: No changes were made. Set DRY_RUN=false to apply changes.
```

### Step 3: Review Results (1 minute)

```bash
# Check the CSV file that was created
open sanitizer_fat32_20260203_123456.csv
# (or on Linux: cat sanitizer_fat32_*.csv | head -20)
```

**What to Look For**:
- ✅ **LOGGED**: No changes needed - file is compliant
- ✅ **RENAMED**: File will be renamed to fix illegal characters
- ⚠️ **FAILED**: File couldn't be processed (usually permissions)

**Example CSV Output**:
```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|Loïc Nottet.flac|Loïc Nottet.flac|-|Music|25|LOGGED|NA|-
File|Song<test>.mp3|Song_test_.mp3|IllegalChar|Music|26|RENAMED|NA|-
```

### Step 4: Apply Changes (1 minute)

**If happy with changes**:
```bash
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v12.1.2.sh /path/to/your/files
```

**Safety Note**: The script never deletes files, only renames them. The CSV shows old → new names if you need to undo.

---

## 🎬 Common Scenarios

### Scenario 1: Audio Library for FAT32/exFAT USB Drive

**Your Situation**: Want to copy music to a USB drive with accents preserved

```bash
# Step 1: Preview what needs to change
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Music

# Step 2: Review the CSV file created
open sanitizer_fat32_*.csv

# Step 3: If happy, apply changes
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v12.1.2.sh ~/Music

# Step 4: Copy to USB
cp -r ~/Music /Volumes/USB_DRIVE/
```

**What gets preserved:**
- ✅ `Loïc Nottet - Révérence.flac` → **unchanged**
- ✅ `C'è di più.flac` → **unchanged**
- ✅ `Café del Mar.mp3` → **unchanged**

**What gets fixed:**
- ❌ `Song:Test.mp3` → `Song_Test.mp3` (colon illegal in FAT32)
- ❌ `Album*.zip` → `Album_.zip` (asterisk illegal in FAT32)

**Time**: 5-10 minutes

### Scenario 2: Generate Directory Snapshot

**Your Situation**: Want a complete directory tree before making changes

```bash
# Generate tree snapshot
FILESYSTEM=fat32 GENERATE_TREE=true DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Music

# Output: tree_fat32_YYYYMMDD_HHMMSS.csv
# Contains: Complete directory structure with all files
```

**Use cases:**
- Compare before/after sanitization
- Document library structure
- Audit file organization

### Scenario 3: Copy to Backup with Versioning

**Your Situation**: Want to backup files with automatic version control

```bash
# Copy with versioning (creates file-v1, file-v2, etc.)
FILESYSTEM=fat32 \
COPY_TO=/Volumes/Backup \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Result:**
- 1st run: `song.mp3` → `/Volumes/Backup/song.mp3`
- 2nd run: `song.mp3` → `/Volumes/Backup/song-v1.mp3`
- 3rd run: `song.mp3` → `/Volumes/Backup/song-v2.mp3`

### Scenario 4: Syncing Between Mac and Windows

**Your Situation**: Files work on Mac but not on Windows

```bash
# Use "universal" mode for maximum compatibility
FILESYSTEM=universal SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Documents

# Apply if good
FILESYSTEM=universal SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v12.1.2.sh ~/Documents
```

**Key Difference**: `universal` mode applies most restrictive rules (works everywhere)

### Scenario 5: Maximum Security for Downloads

**Your Situation**: Files from the internet have weird/dangerous characters

```bash
# Maximum safety - strict mode, with shell safety + Unicode exploit checks
FILESYSTEM=universal \
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
DRY_RUN=true \
./exfat-sanitizer-v12.1.2.sh ~/Downloads

# Apply when ready
FILESYSTEM=universal \
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Downloads
```

**Protects against:**
- ❌ `file$(cmd).txt` → `file__cmd_.txt` (shell injection)
- ❌ `test​​​.pdf` → `test.pdf` (zero-width chars)

---

## 🛠️ Configuration Cheat Sheet

### Pick Your Filesystem

```bash
FILESYSTEM=fat32      # USB drives, SD cards, car stereos (RECOMMENDED)
FILESYSTEM=exfat      # Modern USB drives (>4GB file support)
FILESYSTEM=apfs       # Mac native (macOS only)
FILESYSTEM=ntfs       # Windows drives
FILESYSTEM=universal  # Works everywhere (most restrictive)
```

**Not Sure?** Use `fat32` or `exfat` - both work great for USB drives.

**Key Difference:**
- `fat32`: 4GB max file size, but **supports Unicode via LFN** (Long Filename)
- `exfat`: No file size limit, also **supports full Unicode**

### Pick Your Sanitization Mode

```bash
SANITIZATION_MODE=conservative  # Minimal changes, preserves accents (RECOMMENDED)
SANITIZATION_MODE=strict        # Remove more characters for safety
SANITIZATION_MODE=permissive    # Fastest, least thorough
```

**Best Practice**: Start with `conservative` - it preserves Unicode/accents!

### Always Test First

```bash
DRY_RUN=true    # Preview only (DEFAULT - SAFE)
DRY_RUN=false   # Actually make changes
```

**Pro Tip**: Always run with `DRY_RUN=true` first!

### Unicode Preservation (NEW in v12.x)

```bash
PRESERVE_UNICODE=true          # Keep accented characters (DEFAULT)
NORMALIZE_APOSTROPHES=true     # Normalize curly apostrophes (DEFAULT)
EXTENDED_CHARSET=true          # Allow extended character sets (DEFAULT)
```

**Result**: Accents like `è é à ò ù ï ê ñ ö ü` are preserved!

### Optional Features

```bash
GENERATE_TREE=true              # Create directory structure CSV
CHECK_SHELL_SAFETY=true         # Remove shell metacharacters
CHECK_UNICODE_EXPLOITS=true     # Remove zero-width characters
COPY_TO=/backup/path            # Copy files instead of renaming
COPY_BEHAVIOR=version           # Create versioned copies (skip/overwrite/version)
REPLACEMENT_CHAR=_              # Character for replacing illegal chars
```

---

## 📊 What Gets Fixed vs. Preserved?

### ✅ Preserved (v12.1.2)

**Accented Characters** (via FAT32 LFN UTF-16 support):
```
✅ Loïc Nottet.flac        → PRESERVED (ï)
✅ Révérence.flac          → PRESERVED (é)
✅ C'è di più.flac         → PRESERVED (è, ù)
✅ Café del Mar.mp3        → PRESERVED (é)
✅ Müller - España.wav     → PRESERVED (ü, ñ)
✅ L'interprète.flac       → PRESERVED (è)
✅ Beaux rêves.flac        → PRESERVED (ê)
```

### ❌ Fixed (Illegal Characters)

**Characters That Never Work** (removed/replaced):
```
❌ Song<test>.mp3          → Song_test_.mp3     (< > illegal)
❌ Track:Album.flac        → Track_Album.flac   (: illegal)
❌ File*.zip               → File_.zip          (* illegal)
❌ Doc"Quotes".txt         → Doc_Quotes_.txt    (" illegal)
❌ Path\File.doc           → Path_File.doc      (\ illegal)
```

**FAT32/exFAT Forbidden Characters**:
```
< > : " / \ | ? *
+ control characters (0-31, 127)
```

### Example Comparison Table

| Input | v9.0.2.2 (Broken) | v12.1.2 (Fixed) | Status |
|-------|-------------------|-----------------|--------|
| `Loïc Nottet.flac` | `Loic Nottet.flac` ❌ | `Loïc Nottet.flac` ✅ | LOGGED |
| `Révérence.mp3` | `Reverence.mp3` ❌ | `Révérence.mp3` ✅ | LOGGED |
| `Song:Test.mp3` | `Song_Test.mp3` ✅ | `Song_Test.mp3` ✅ | RENAMED |
| `Album*.zip` | `Album_.zip` ✅ | `Album_.zip` ✅ | RENAMED |

---

## 📝 Understanding CSV Output

### CSV Format

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|Loïc.flac|Loïc.flac|-|Music/Album|26|LOGGED|NA|-
File|song:test.mp3|song_test.mp3|IllegalChar|Music|27|RENAMED|COPIED|-
Directory|bad<dir>|bad_dir_|IllegalChar|Music|15|RENAMED|NA|-
```

### Status Values

**Status column:**
- `LOGGED` - File checked, no changes needed (already compliant)
- `RENAMED` - File was renamed (illegal characters found)
- `IGNORED` - File matched ignore pattern
- `FAILED` - Operation failed (permissions, collision, etc.)

**Copy Status column:**
- `COPIED` - Successfully copied to destination
- `SKIPPED` - Skipped due to conflict (with `COPY_BEHAVIOR=skip`)
- `NA` - No copy operation (when `COPY_TO` not set)

---

## ❓ FAQ (Quick Answers)

### Q1: Will this delete my files?
**A**: No! It only renames files. Nothing is deleted. Ever.

### Q2: What changed in v12.1.2?
**A**: 🔴 **CRITICAL FIX** - Apostrophe normalization no longer corrupts accents. Now `Loïc` stays `Loïc` instead of becoming `Loic`.

### Q3: Do I need Python 3?
**A**: Yes! Python 3 is **required** in v12.1.2 for proper UTF-8 handling. Install with:
```bash
# macOS
brew install python3

# Ubuntu/Debian
sudo apt-get install python3
```

### Q4: Can I undo changes?
**A**: The CSV file shows old → new names. You can manually rename back if needed.

### Q5: How long does it take?
**A**: For ~4,000 files: 15-30 seconds

### Q6: Does it work on Windows?
**A**: Yes! Use WSL (Windows Subsystem for Linux), Git Bash, or Cygwin

### Q7: My files didn't change - is that bad?
**A**: No! Means your files are already compatible. That's good! (Status: LOGGED)

### Q8: Will accents be stripped like in older versions?
**A**: No! v12.1.2 **preserves all accents** via FAT32 LFN UTF-16 support. Only illegal characters (`:`, `*`, `<`, `>`, etc.) are replaced.

### Q9: What does "Path too long" mean?
**A**: Filename + directory path exceeds limits. Shorten folder names or file names.

### Q10: How do I know which filesystem to use?
**A**: 
- USB drive (modern)? → `fat32` or `exfat`
- USB drive (old, pre-2010)? → `fat32`
- Mac only? → `apfs`
- Windows only? → `ntfs`
- Not sure / multiple systems? → `universal`

---

## 🚨 Troubleshooting

### Problem: "Python3 not found"

```bash
# Check if Python 3 is installed
python3 --version

# If missing, install:
# macOS
brew install python3

# Ubuntu/Debian
sudo apt-get install python3

# Fedora/RHEL
sudo dnf install python3

# Verify
python3 --version
```

### Problem: "Permission denied"

```bash
# Solution 1: Make script executable
chmod +x exfat-sanitizer-v12.1.2.sh

# Solution 2: Run with elevated permissions (if needed)
sudo ./exfat-sanitizer-v12.1.2.sh /path/to/files

# Solution 3: Check file/directory permissions
ls -la /path/to/files
```

### Problem: "No such file or directory"

```bash
# Make sure path exists
ls -la /path/to/files

# Make sure you're in the right directory
pwd

# Use absolute path if needed
./exfat-sanitizer-v12.1.2.sh ~/Music
```

### Problem: Files not being renamed

```bash
# Check if you're in dry-run mode (default)
echo "DRY_RUN is: $DRY_RUN"

# To actually apply changes:
DRY_RUN=false ./exfat-sanitizer-v12.1.2.sh /path/to/files
```

### Problem: Accents are being stripped

```bash
# Check your version
head -3 exfat-sanitizer-v12.1.2.sh

# Expected output:
# #!/bin/bash
# 
# # exfat-sanitizer v12.1.2 - ACCENT PRESERVATION FIX (ACTUAL FIX)

# If you see v12.1.1 or earlier, download v12.1.2!
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.2/exfat-sanitizer-v12.1.2.sh
```

### Problem: CSV shows nothing

```bash
# If summary says 0 scanned files, directory might be empty
ls /path/to/files | wc -l

# Or directory path might be wrong
file /path/to/files

# Or all files are already compliant (good!)
grep "LOGGED" sanitizer_*.csv | wc -l
```

---

## 📋 Workflow Example (Step by Step)

Let's say you want to clean up your French/Italian music library for a USB drive:

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

### Step 3: Preview changes (SAFE)
```bash
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Music
```

### Step 4: Check the CSV output
```bash
# View summary
cat sanitizer_fat32_*.csv | tail -20

# Or open in Excel/Numbers
open sanitizer_fat32_*.csv
```

### Step 5: Review results in CSV
- How many files need renaming? (Should be 0 if only accents present)
- Any illegal characters (`:`, `*`, `<`, `>`) found? (These will be replaced)
- Any "Path too long" errors? (Shorten folder names manually)
- Check that accented files show **LOGGED** status (not RENAMED)

### Step 6: Verify accent preservation
```bash
# Check that accented files are NOT being renamed
grep "Loïc\|Révérence\|C'è" sanitizer_fat32_*.csv

# Should show LOGGED status, NOT RENAMED
# Example: File|Loïc Nottet.flac|Loïc Nottet.flac|-|...|LOGGED|NA|-
```

### Step 7: Apply changes (if any needed)
```bash
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v12.1.2.sh ~/Music
```

### Step 8: Verify changes applied
```bash
# Check for any renames
grep "RENAMED" sanitizer_fat32_*.csv

# Should only show files with illegal characters, NOT accents
```

### Step 9: Copy to USB
```bash
cp -r ~/Music /Volumes/USB_DRIVE/
```

**Done!** 🎉 Your accented filenames are preserved!

---

## 💡 Pro Tips

### Tip 1: Always Backup First
```bash
# Copy to backup location first
cp -r ~/Music ~/Music_Backup

# Then test on backup
FILESYSTEM=fat32 DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Music_Backup
```

### Tip 2: Generate Tree Snapshot
```bash
# See directory structure before changes
GENERATE_TREE=true FILESYSTEM=fat32 DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Music

# Creates: tree_fat32_YYYYMMDD_HHMMSS.csv
# Contains: Complete directory tree with all files
```

### Tip 3: Use Copy Mode for Backup
```bash
# Copy to backup with sanitization + versioning
FILESYSTEM=fat32 \
COPY_TO=/Volumes/Backup \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

### Tip 4: Automate Regular Cleanups
```bash
# Create a script to run monthly
cat > ~/sanitize-music.sh << 'EOF'
#!/bin/bash
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=false \
  ~/exfat-sanitizer-v12.1.2.sh ~/Music
echo "Sanitization complete on $(date)" >> ~/Music_Cleanup.log
EOF

chmod +x ~/sanitize-music.sh
./sanitize-music.sh
```

### Tip 5: Test Accent Preservation
```bash
# Create test files to verify
mkdir -p /tmp/test-accents
cd /tmp/test-accents
touch "Loïc Nottet.flac"
touch "Révérence.mp3"
touch "C'è di più.wav"

# Run sanitizer
FILESYSTEM=fat32 DRY_RUN=true \
  ~/exfat-sanitizer-v12.1.2.sh /tmp/test-accents

# Check CSV - all should show LOGGED (not RENAMED)
grep "Loïc\|Révérence\|C'è" sanitizer_fat32_*.csv
```

---

## ✨ Quick Command Reference

```bash
# Most common: Audio library for USB (accents preserved!)
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Music

# Maximum compatibility (Mac ↔ Windows)
FILESYSTEM=universal SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Documents

# Maximum security (untrusted files)
FILESYSTEM=universal SANITIZATION_MODE=strict \
  CHECK_SHELL_SAFETY=true CHECK_UNICODE_EXPLOITS=true DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Downloads

# With directory tree export
FILESYSTEM=fat32 GENERATE_TREE=true DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Music

# Copy mode with versioning
FILESYSTEM=fat32 \
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false \
  ./exfat-sanitizer-v12.1.2.sh ~/Music

# Apply changes (after testing!)
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v12.1.2.sh ~/Music
```

---

## 🎯 Success Checklist

After running exfat-sanitizer v12.1.2, you should be able to:

- ✅ Copy files to FAT32/exFAT USB drives without errors
- ✅ Sync between Mac and Windows without issues
- ✅ **Preserve accented characters** (Loïc, Révérence, C'è di più)
- ✅ Open files on different devices
- ✅ See all files in directory listings
- ✅ Safely backup files across systems
- ✅ Use files with different applications
- ✅ Share files with other users
- ✅ No more "illegal character" errors

---

## 🔗 Additional Resources

### Documentation
- 📖 **[README.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/README.md)** - Comprehensive documentation
- 🔴 **[RELEASE-v12.1.2.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/RELEASE-v12.1.2.md)** - Release notes and critical bug fix
- 📋 **[CHANGELOG-v12.1.2.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/CHANGELOG-v12.1.2.md)** - Complete version history

### Support
- **Issues**: [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/fbaldassarri/exfat-sanitizer/discussions)
- **Repository**: https://github.com/fbaldassarri/exfat-sanitizer

---

## ⏱️ Time Estimates

| Task | Time | Prerequisites |
|------|------|---------------|
| Install Python 3 | 2 min | Internet connection |
| Download & setup | 1 min | Internet connection |
| Preview (dry-run) | 15-30 sec | 100-10,000 files |
| Review CSV | 1 min | Text editor |
| Apply changes | 15-30 sec | Review complete |
| Copy to USB | 5-30 min | Depends on file size |
| **Total** | **~10-40 min** | Start to finish |

---

## 🎓 What Makes v12.1.2 Special?

### Accent Preservation (FIXED!)

**Previous versions (v12.1.1 and earlier):**
```bash
❌ "Loïc Nottet" → "Loic Nottet"      # Accents stripped!
❌ "Révérence" → "Reverence"          # Accents stripped!
```

**v12.1.2:**
```bash
✅ "Loïc Nottet" → "Loïc Nottet"      # Accents preserved!
✅ "Révérence" → "Révérence"          # Accents preserved!
```

### How It Works

- **FAT32 LFN Support**: Modern FAT32 uses Long Filename (LFN) stored as UTF-16LE
- **Python-based normalization**: Unicode-aware character handling
- **Explicit code points**: Uses `\u2018`, `\u2019` for apostrophe normalization
- **No glob pattern corruption**: Avoids bash glob pattern issues

### Why Upgrade to v12.1.2?

| Version | Accent Preservation | Production Ready | Recommendation |
|---------|---------------------|------------------|----------------|
| v9.0.2.2 | ❌ Broken | ❌ No | ⛔ Avoid |
| v11.0.5 | ✅ Fixed | ✅ Yes | ⚠️ Upgrade to v12.1.2 |
| v11.1.0 | ✅ Fixed | ✅ Yes | ⚠️ Upgrade to v12.1.2 |
| v12.0.0 | ⚠️ Partial | ⚠️ Partial | ⛔ Skip |
| v12.1.0 | ⚠️ Partial | ⚠️ Partial | ⛔ Skip |
| v12.1.1 | ❌ **CRITICAL BUG** | ❌ No | ⛔ **DO NOT USE** |
| **v12.1.2** | ✅ **Fixed** | ✅ **Yes** | ✅ **RECOMMENDED** |

---

## 🚀 You're Ready!

Start with **Step 1** above, and you'll be sanitizing files (with accents preserved!) in no time!

**Need Help?**
- 📖 See [README.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/README.md) for detailed docs
- 🐛 Report issues on [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- 💬 Ask questions on [GitHub Discussions](https://github.com/fbaldassarri/exfat-sanitizer/discussions)

---

*Last Updated: February 3, 2026*  
*Version: 12.1.2*  
*Repository: https://github.com/fbaldassarri/exfat-sanitizer*  
*Maintainer: [fbaldassarri](https://github.com/fbaldassarri)*
