# exfat-sanitizer: Quick Start Guide

**Get started in 5 minutes** - No complex setup required!

---

## 🎯 30-Second Overview

**What It Does**: Safely renames files and folders to work across different devices (Mac, Windows, Linux, USB drives, etc.)

**Who Needs It**: Anyone syncing files between different computers or devices who encounters:
- ❌ Files disappearing during copy
- ❌ Sync failures between devices
- ❌ Cryptic error messages about filenames
- ❌ Problems reading files on different computers

**How It Works**: Preview all changes in a safe mode first, then apply changes if you're happy

---

## ⚡ Quick Start (5 Minutes)

### Step 1: Download & Setup (1 minute)

```bash
# Download the script
curl -O https://github.com/yourusername/exfat-sanitizer/releases/download/v9.0.1/exfat-sanitizer-v9.0.1.sh

# Make it executable
chmod +x exfat-sanitizer-v9.0.1.sh

# Verify it works
./exfat-sanitizer-v9.0.1.sh --help
```

**Expected Output**: You should see the help text with configuration options.

### Step 2: Preview Changes (2 minutes)

```bash
# Test with your files (safe - no changes made)
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh /path/to/your/files
```

**What to Replace**:
- `/path/to/your/files` → Your actual directory path
  - Examples: `~/Music`, `/Volumes/USB_Drive`, `~/Documents`

**What You'll See**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exfat-sanitizer v9.0.1
Filesystem: exfat
Sanitization Mode: conservative
Dry Run: true
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ CSV Log: sanitizer_exfat_20260110_123456.csv
Processing directories...
Processing files...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary:
 Scanned Directories: 368
 Scanned Files: 3555
 Renamed Directories: 0
 Renamed Files: 0
 Path Length Issues: 56
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DRY RUN MODE: No changes were made. Set DRY_RUN=false to apply changes.
```

### Step 3: Review Results (1 minute)

```bash
# Check the CSV file that was created
open sanitizer_exfat_20260110_123456.csv
# (or on Linux: cat sanitizer_exfat_*.csv | head -20)
```

**What to Look For**:
- ✅ **LOGGED**: No changes needed - file is fine
- ✅ **RENAMED**: File will be renamed to fix issues
- ⚠️ **FAILED**: File couldn't be processed (usually path too long)

**Example CSV Output**:
```csv
Type,Old Name,New Name,Issues,Path,Path Length,Status,Copy_Status
File,Normal Song.wav,Normal Song.wav,,/path/to/music,145,LOGGED,N/A
File,Song <Bad>.wav,Song _Bad_.wav,Universal_Forbidden,,/path/to/music,152,RENAMED,N/A
```

### Step 4: Apply Changes (1 minute)

**If happy with changes**:
```bash
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v9.0.1.sh /path/to/your/files
```

**If you want to make changes**:
Edit the problematic files manually, then run the script again.

**Safety Note**: The script never deletes files, only renames them. The CSV shows old → new names if you need to undo.

---

## 🎬 Common Scenarios

### Scenario 1: Audio Library for USB Drive

**Your Situation**: Want to copy music to an exFAT USB drive but files aren't syncing

```bash
# Step 1: Preview what needs to change
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Music

# Step 2: Review the CSV file created
open sanitizer_exfat_*.csv

# Step 3: If happy, apply changes
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v9.0.1.sh ~/Music

# Step 4: Copy to USB
cp -r ~/Music /Volumes/USB_DRIVE/
```

**Time**: 5-10 minutes

### Scenario 2: Syncing Between Mac and Windows

**Your Situation**: Files work on Mac but not on Windows

```bash
# Use "universal" mode for maximum compatibility
FILESYSTEM=universal SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Documents

# Review results...

# Apply if good
FILESYSTEM=universal SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v9.0.1.sh ~/Documents
```

**Key Difference**: `universal` mode applies most restrictive rules (works everywhere)

### Scenario 3: Downloads Folder Cleanup

**Your Situation**: Files from the internet have weird characters

```bash
# Maximum safety - strict mode, with shell safety
FILESYSTEM=universal SANITIZATION_MODE=strict \
  CHECK_SHELL_SAFETY=true DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Downloads

# Apply when ready
FILESYSTEM=universal SANITIZATION_MODE=strict \
  CHECK_SHELL_SAFETY=true DRY_RUN=false \
  ./exfat-sanitizer-v9.0.1.sh ~/Downloads
```

### Scenario 4: Legacy USB Drive (FAT32)

**Your Situation**: Old USB drive that uses FAT32 (not exFAT)

```bash
# Older USB drives use FAT32, more restrictions
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Music
```

---

## 🛠️ Configuration Cheat Sheet

### Pick Your Filesystem

```bash
FILESYSTEM=exfat      # Modern USB drives, SD cards (RECOMMENDED)
FILESYSTEM=fat32      # Older USB drives (pre-2010)
FILESYSTEM=apfs       # Mac native (Sonoma+)
FILESYSTEM=ntfs       # Windows drives
FILESYSTEM=universal  # Works everywhere (most restrictive)
```

**Not Sure?** Use `exfat` - it's the modern standard.

### Pick Your Sanitization Mode

```bash
SANITIZATION_MODE=conservative  # Minimal changes (RECOMMENDED)
SANITIZATION_MODE=strict        # Remove more stuff for safety
SANITIZATION_MODE=permissive    # Fastest, least thorough
```

**Best Practice**: Start with `conservative`

### Always Test First

```bash
DRY_RUN=true    # Preview only (DEFAULT - SAFE)
DRY_RUN=false   # Actually make changes
```

**Pro Tip**: Always run with `DRY_RUN=true` first!

### Optional Features

```bash
GENERATE_TREE=true              # Create directory structure CSV
CHECK_SHELL_SAFETY=false        # Skip shell character checking
COPY_TO=/backup/path            # Copy files to new location instead of renaming
```

---

## 📊 What Gets Fixed?

### Characters That Cause Problems

The script removes or replaces these characters (varies by filesystem):

```
< > : " / \ | ? *     ← These never work
+ , ; = [ ] ÷ ×       ← These don't work on older systems
$ ` & ; #             ← These can cause security problems
```

### Example Fixes

| Problem | Fixed | Status |
|---------|-------|--------|
| `Song <Official>.wav` | `Song _Official_.wav` | ✅ RENAMED |
| `Song "Remix".wav` | `Song _Remix_.wav` | ✅ RENAMED |
| `/path/way/too/long/filename/here/...` | (Path shortened or ignored) | ⚠️ FAILED |
| `CON.txt` (reserved) | `CON-reserved.txt` | ✅ RENAMED |
| `Normal Song.wav` | `Normal Song.wav` | ✅ LOGGED (no change) |

---

## ❓ FAQ (Quick Answers)

### Q1: Will this delete my files?
**A**: No! It only renames files. Nothing is deleted. Ever.

### Q2: Can I undo changes?
**A**: The CSV file shows old → new names. You can manually rename back if needed.

### Q3: How long does it take?
**A**: For ~3,500 files: 15-30 seconds

### Q4: Does it work on Windows?
**A**: Yes! Use WSL (Windows Subsystem for Linux), Git Bash, or Cygwin

### Q5: My files didn't change - is that bad?
**A**: No! Means your files are already compatible. That's good!

### Q6: What does "Path too long" mean?
**A**: Filename + directory path exceeds 260 characters. Shorten folder names or file names.

### Q7: Do I need admin/sudo?
**A**: Only if the directory needs elevated permissions. Try without first.

### Q8: What's this CSV file?
**A**: Audit log of all changes. Shows exactly what was renamed and why.

### Q9: Can I run this on multiple directories?
**A**: Yes! Run the command separately for each directory.

### Q10: How do I know which mode to use?
**A**: 
- Not sure? → Use `exfat` + `conservative`
- Mac to Windows? → Use `universal` + `conservative`
- Maximum safety? → Use `universal` + `strict`
- Fastest? → Use `exfat` + `permissive`

---

## 🚨 Troubleshooting

### Problem: "Permission denied"

```bash
# Solution 1: Run with elevated permissions
sudo ./exfat-sanitizer-v9.0.1.sh /path/to/files

# Solution 2: Make sure script is executable
chmod +x exfat-sanitizer-v9.0.1.sh
```

### Problem: "No such file or directory"

```bash
# Make sure path exists
ls -la /path/to/files

# Make sure you're in the right directory
pwd
```

### Problem: Files not being renamed

```bash
# Check if you're in dry-run mode (default)
echo "Current setting: $DRY_RUN"

# Should output: Current setting: true

# To actually apply changes:
DRY_RUN=false ./exfat-sanitizer-v9.0.1.sh /path/to/files
```

### Problem: CSV shows nothing

```bash
# If summary says 0 scanned files, directory might be empty
ls /path/to/files | wc -l

# Or directory path might be wrong
file /path/to/files
```

### Problem: "Insufficient disk space"

```bash
# Check available space
df -h /path/to/files

# Use copy mode to backup elsewhere
COPY_TO=/external/drive DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh /path/to/files
```

---

## 📝 Workflow Example (Step by Step)

Let's say you want to clean up your music library for a USB drive:

### Step 1: Navigate to your music folder
```bash
cd ~/Music
pwd  # Verify path
```

### Step 2: Preview changes (SAFE)
```bash
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Music
```

### Step 3: Check the CSV output
```bash
# View summary
tail sanitizer_exfat_*.csv

# Or open in Excel/Numbers
open sanitizer_exfat_*.csv
```

### Step 4: Review results in CSV
- How many files need renaming? (Should be low with conservative mode)
- Any "Path too long" errors? (You may need to shorten folder names manually)
- Any unexpected issues?

### Step 5: Make manual fixes (if needed)
```bash
# Shorten folder names if needed
mv "Artist Name - Really Long Album Title 2025" "Artist - Album 2025"

# Re-run to verify
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Music
```

### Step 6: Apply changes
```bash
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v9.0.1.sh ~/Music
```

### Step 7: Verify changes applied
```bash
# New CSV should show RENAMED status
grep "RENAMED" sanitizer_exfat_*.csv | head -5
```

### Step 8: Copy to USB
```bash
cp -r ~/Music /Volumes/USB_DRIVE/
```

**Done!** 🎉

---

## 🎓 Learning Resources

### To Understand More
- 📖 **Full README**: See README.md for comprehensive docs
- 🏗️ **Architecture**: See ARCHITECTURE.md for technical details
- 📋 **API**: See API.md for function reference

### Example Commands
```bash
# See all help options
./exfat-sanitizer-v9.0.1.sh --help

# Run with debug output
bash -x ./exfat-sanitizer-v9.0.1.sh /path 2>&1 | head -50

# Generate tree visualization
GENERATE_TREE=true ./exfat-sanitizer-v9.0.1.sh /path
```

---

## 💡 Pro Tips

### Tip 1: Backup First
```bash
# Copy to backup location first
cp -r ~/Music ~/Music_Backup

# Then test on backup
FILESYSTEM=exfat DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Music_Backup
```

### Tip 2: Use Tree Export
```bash
# See directory structure before and after
GENERATE_TREE=true DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh /path/to/files
# Creates: tree_exfat_*.csv with directory structure
```

### Tip 3: Automate Regularly
```bash
# Create a script to run monthly
cat > ~/sanitize-music.sh << 'EOF'
#!/bin/bash
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=false \
  ~/exfat-sanitizer-v9.0.1.sh ~/Music
echo "Sanitization complete on $(date)" >> ~/Music_Cleanup.log
EOF

chmod +x ~/sanitize-music.sh
./sanitize-music.sh
```

### Tip 4: Monitor Changes
```bash
# Keep CSV files for audit trail
mkdir -p ~/Sanitizer_Logs
cd ~/Sanitizer_Logs
FILESYSTEM=exfat DRY_RUN=false \
  ~/exfat-sanitizer-v9.0.1.sh ~/Music
# CSV files stay here for future reference
```

### Tip 5: Check Before Syncing
```bash
# Run before major sync operations
FILESYSTEM=exfat DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Music

# Review CSV, then sync
rsync -av ~/Music /Volumes/USB_DRIVE/
```

---

## 🚀 Next Steps

### What to Do Now
1. ✅ Download the script
2. ✅ Run `--help` to see options
3. ✅ Test with `DRY_RUN=true` first
4. ✅ Review the CSV output
5. ✅ Apply changes with `DRY_RUN=false`

### Need More Help?
- 📖 Read the full **README.md** for detailed documentation
- 💬 Open an issue on GitHub with your question
- 🤔 Check FAQ above for common questions
- 🔧 See ARCHITECTURE.md if you want to understand the code

### Found a Bug?
- Describe what went wrong
- Share your command (sanitized if private)
- Include the CSV file snippet
- Report on GitHub Issues

---

## ⏱️ Time Estimates

| Task | Time | Prerequisites |
|------|------|---------------|
| Download & setup | 1 min | Internet connection |
| Preview (dry-run) | 2-5 min | 100-10,000 files |
| Review CSV | 1 min | Text editor |
| Apply changes | 2-5 min | Review complete |
| Copy to USB | 5-30 min | Depends on file size |
| **Total** | **~15-45 min** | Start to finish |

---

## ✨ Quick Command Reference

```bash
# Most common (audio library for USB)
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Music

# Maximum compatibility (Mac ↔ Windows)
FILESYSTEM=universal SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Documents

# Maximum safety (untrusted files)
FILESYSTEM=universal SANITIZATION_MODE=strict \
  CHECK_SHELL_SAFETY=true DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Downloads

# With directory tree export
FILESYSTEM=exfat GENERATE_TREE=true DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh /path/to/files

# Copy mode (backup with cleaning)
FILESYSTEM=exfat COPY_TO=~/Music_Cleaned DRY_RUN=true \
  ./exfat-sanitizer-v9.0.1.sh ~/Music
```

---

## 🎯 Success Checklist

After running exfat-sanitizer, you should be able to:

- ✅ Copy files to exFAT USB drives without errors
- ✅ Sync between Mac and Windows without issues
- ✅ Open files on different devices
- ✅ See all files in directory listings
- ✅ Safely backup files across systems
- ✅ Use files with different applications
- ✅ Share files with other users

---

## 📞 Getting Help

- **Quick Questions**: Check this guide's FAQ section
- **Technical Issues**: See TROUBLESHOOTING.md
- **Architecture Deep Dive**: See ARCHITECTURE.md
- **Code Reference**: See API.md
- **Bug Reports**: GitHub Issues
- **General Discussion**: GitHub Discussions

---

**You're ready to go!** 🚀

Start with the **Quick Start (5 Minutes)** section above, and you'll be sanitizing files in no time!

---

*Last Updated: January 10, 2026*  
*Version: 9.0.1*  
*For detailed info, see README.md*
