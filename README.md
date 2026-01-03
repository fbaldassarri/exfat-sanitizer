# exfat-sanitizer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-5.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![macOS](https://img.shields.io/badge/macOS-Supported-blue.svg)](https://www.apple.com/macos/)
[![Linux](https://img.shields.io/badge/Linux-Supported-blue.svg)](https://www.linux.org/)

A production-ready POSIX-compliant bash script to recursively sanitize filenames and folder names for compatibility with **exFAT** and **FAT32** file systems.

## Features

✅ **Dual Filesystem Support**
- exFAT mode: Permissive character handling (32,767 char path limit)
- FAT32 mode: Strict character restrictions (255 char path limit)

✅ **Comprehensive Sanitization**
- Removes leading/trailing whitespace
- Eliminates leading dots (`.file`)
- Replaces universal forbidden characters: `< > : " / \ | ? *`
- Removes FAT32-specific characters: `; = + [ ] ÷ ×`
- Validates path lengths against filesystem limits
- Detects and prevents naming collisions

✅ **Safe & Non-Destructive**
- Dry-run mode (default) previews all changes without execution
- Dry-run CSV logging for verification
- Full audit trail in CSV format
- System file protection (`.DS_Store`, `Thumbs.db`, `.sync`, etc.)

✅ **Production Features**
- Directory tree export (CSV format with metadata)
- Real-time progress reporting
- Collision detection and prevention
- Exit code handling for automation
- Color-coded terminal output
- Bash 3.2+ compatible (macOS compatible)

## Installation

### Quick Start

```bash
# Clone the repository
git clone https://github.com/fbaldassarri/exfat-sanitizer.git
cd exfat-sanitizer

# Make executable
chmod +x exfat-sanitizer-v7.6.0.sh

# Run with dry-run (preview mode)
./exfat-sanitizer-v7.6.0.sh /path/to/directory
```

### System Requirements

- **Bash** 3.2 or later
- **POSIX-compliant system** (macOS, Linux, BSD, etc.)
- Standard utilities: `find`, `stat`, `sed`, `grep`
- Write permissions to target directory (for actual execution)

### Optional Setup

```bash
# Make globally accessible
sudo cp exfat-sanitizer-v7.6.0.sh /usr/local/bin/exfat-sanitizer
sudo chmod +x /usr/local/bin/exfat-sanitizer

# Then run from anywhere
exfat-sanitizer /path/to/directory
```

## Usage

### Basic Syntax

```bash
./exfat-sanitizer-v7.6.0.sh [target_directory]
```

### Environment Variables

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `DRY_RUN` | `true` | `true`/`false` | Preview changes without execution |
| `FILESYSTEM` | `exfat` | `exfat`/`fat32` | Target filesystem rules |
| `GENERATE_TREE` | `false` | `true`/`false` | Export directory tree to CSV |

### Examples

#### 1. Dry-Run Preview (FAT32 mode)

```bash
FILESYSTEM=fat32 DRY_RUN=true ./exfat-sanitizer-v7.6.0.sh ~/Music
```

Output shows:
- Proposed filename changes
- Issues detected
- Path length validation
- Collision warnings

#### 2. Dry-Run with Tree Export

```bash
GENERATE_TREE=true DRY_RUN=true FILESYSTEM=fat32 ./exfat-sanitizer-v7.6.0.sh ~/Music
```

Generates:
- `tree_fat32_TIMESTAMP.csv` - Directory structure with metadata
- `sanitizer_fat32_TIMESTAMP.csv` - Proposed changes
- Console output with progress

#### 3. Execute Actual Sanitization

```bash
DRY_RUN=false FILESYSTEM=exfat ./exfat-sanitizer-v7.6.0.sh ~/Documents
```

**⚠️ Warning:** This performs actual renames. Always test with `DRY_RUN=true` first.

#### 4. Recursive Directory Sanitization

```bash
for dir in ~/Audio/*; do
  if [ -d "$dir" ]; then
    DRY_RUN=false FILESYSTEM=fat32 ./exfat-sanitizer-v7.6.0.sh "$dir"
  fi
done
```

#### 5. Continuous Monitoring

```bash
watch -n 5 "DRY_RUN=true FILESYSTEM=fat32 ./exfat-sanitizer-v7.6.0.sh ~/Sync"
```

## Output Files

### Sanitizer CSV (`sanitizer_FILESYSTEM_TIMESTAMP.csv`)

Tab-separated log of all detected issues:

```csv
Type,Old Name,New Name,Issues,Path,Path Length,Status
Directory,"[Live Album]","_Live Album_","FAT32 Chars","/Users/user/Music",85,LOGGED
File,"Song [Remix].mp3","Song _Remix_.mp3","FAT32 Chars","/Users/user/Music/Album",105,LOGGED
```

**Columns:**
- `Type`: Directory or File
- `Old Name`: Original filename
- `New Name`: Sanitized filename
- `Issues`: Violations detected
- `Path`: Parent directory path
- `Path Length`: Full path length (bytes)
- `Status`: LOGGED, RENAMED, FAILED, COLLISION, SKIPPED

### Tree CSV (`tree_FILESYSTEM_TIMESTAMP.csv`)

Complete directory structure export (semicolon-delimited for Excel):

```csv
Level;Depth;Type;Name;Full_Path;Size_Bytes;Modified_Date
0;0;Directory;"Music";"/";-;2026-01-03 21:39:06
1;1;Directory;"Album";"/Album";-;2025-12-28 14:22:15
2;2;File;"01 Track.wav";"/Album/01 Track.wav";85234912;2025-12-28 14:20:33
```

**Columns:**
- `Level`: Sequential entry number
- `Depth`: Directory nesting level
- `Type`: Directory or File
- `Name`: Item filename
- `Full_Path`: Relative path from target
- `Size_Bytes`: File size or "-" for directories
- `Modified_Date`: Last modification timestamp

## Character Restrictions

### Universal (Both filesystems)

These characters are forbidden in ALL filenames:

```
< > : " / \ | ? *
```

**Examples of automatic replacement:**
- `song<artist>.mp3` → `song_artist_.mp3`
- `"quote".txt` → `_quote_.txt`
- `folder/subfolder` → `folder_subfolder`

### FAT32-Specific

Additional restrictions for FAT32 compatibility:

```
; = + [ ] ÷ ×
```

**Examples:**
- `album[disc1].mp3` → `album_disc1_.mp3`
- `equation=solution.txt` → `equation_solution.txt`
- `math÷symbols.doc` → `math_symbols.doc`

### exFAT

exFAT is more permissive and allows:
- `[ ] ; = + ÷ ×`
- Long filenames (up to 255 characters)
- Extended Unicode support

## System File Protection

These files are NEVER modified (safe list):

```
.DS_Store          (macOS metadata)
Thumbs.db          (Windows thumbnails)
.stignore          (Syncthing ignore)
.stfolder          (Syncthing marker)
.sync              (Sync markers)
.sync.ffs_db       (FreeFileSync database)
.gitignore         (Git ignore)
```

## Path Length Validation

### FAT32 Mode
- **Maximum path length**: 255 characters (including full path)
- Files exceeding limit are skipped with warning
- Path length reported in CSV for verification

### exFAT Mode
- **Maximum path length**: 32,767 characters
- Most real-world paths pass validation
- Path length still tracked for documentation

## Collision Detection

The script prevents naming conflicts:

```bash
# Before sanitization (same after):
song[1].mp3
song_1_.mp3

# Script detects this would create "song_1_.mp3" twice
# Second occurrence is marked as COLLISION and skipped
```

## Advanced Usage

### Automation with Cron

```bash
# Add to crontab -e
0 2 * * * DRY_RUN=false FILESYSTEM=fat32 /usr/local/bin/exfat-sanitizer ~/Backups >> ~/sanitizer.log 2>&1
```

### Docker Usage

```dockerfile
FROM alpine:latest
RUN apk add bash coreutils findutils

COPY exfat-sanitizer-v7.6.0.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/exfat-sanitizer-v7.6.0.sh

ENTRYPOINT ["exfat-sanitizer-v7.6.0.sh"]
```

### Integration with Backup Scripts

```bash
#!/bin/bash
# Sanitize before backup

BACKUP_DIR="/mnt/backup"
SOURCE_DIR="/home/user/media"

# Sanitize with FAT32 compatibility
DRY_RUN=false FILESYSTEM=fat32 exfat-sanitizer "$SOURCE_DIR"

# Verify exit code
if [ $? -eq 0 ]; then
    rsync -av "$SOURCE_DIR" "$BACKUP_DIR"
else
    echo "Sanitization failed" >&2
    exit 1
fi
```

### Monitoring Multiple Directories

```bash
#!/bin/bash
WATCH_LIST=(
    ~/Documents
    ~/Pictures
    ~/Downloads
)

for dir in "${WATCH_LIST[@]}"; do
    echo "Processing: $dir"
    DRY_RUN=false FILESYSTEM=fat32 exfat-sanitizer "$dir"
done
```

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| `0` | Success | Operation completed |
| `1` | Error | Invalid filesystem or missing directory |
| `130` | Interrupted | Script interrupted by user (Ctrl+C) |

## Performance

### Benchmarks (on 3,500 files, 350 directories)

```
FAT32 Mode (with sanitization):
- Scan: ~2-3 seconds
- Tree export: ~1 second
- CSV generation: <500ms
- Total dry-run: ~4 seconds

exFAT Mode (no sanitization):
- Scan: ~2-3 seconds
- Tree export: ~1 second
- Total dry-run: ~3 seconds
```

### Recommendations

- **Small directories** (<100 items): Run interactively
- **Medium directories** (100-10K items): Background process acceptable
- **Large directories** (>10K items): Schedule during off-peak hours
- **Network mounts**: Add 2-5x time overhead

## Troubleshooting

### Issue: "syntax error in conditional expression"

**Cause**: Bash version too old or incorrect syntax
**Solution**:
```bash
bash --version  # Check version (need 3.2+)
bash ./exfat-sanitizer-v7.6.0.sh  # Run with explicit bash
```

### Issue: "Permission denied"

**Cause**: Script not executable
**Solution**:
```bash
chmod +x exfat-sanitizer-v7.6.0.sh
```

### Issue: Files not renamed despite `DRY_RUN=false`

**Cause**: Possible collision or system file protection
**Solution**:
```bash
# Check CSV log for status
grep -i "collision\|skipped\|failed" sanitizer_*.csv
```

### Issue: Path length shows as 0

**Cause**: macOS `stat` command variation
**Solution**: Script handles this gracefully; not a critical issue

### Issue: Slow performance on network drives

**Cause**: Network latency
**Solution**:
```bash
# Consider copying to local disk first
cp -r /Volumes/NetworkDrive/Media ~/temp/
./exfat-sanitizer-v7.6.0.sh ~/temp/Media
cp -r ~/temp/Media /Volumes/NetworkDrive/
```

## Real-World Examples

### Prepare music library for portable player

```bash
# Most portable audio players use FAT32
DRY_RUN=true FILESYSTEM=fat32 GENERATE_TREE=true ./exfat-sanitizer-v7.6.0.sh ~/Music

# Review tree_fat32_*.csv in Excel
# Review proposed changes in sanitizer_fat32_*.csv

# If satisfied, execute:
DRY_RUN=false FILESYSTEM=fat32 ./exfat-sanitizer-v7.6.0.sh ~/Music
```

### Backup before external drive migration

```bash
# Create pre-migration inventory
GENERATE_TREE=true DRY_RUN=true FILESYSTEM=fat32 ./exfat-sanitizer-v7.6.0.sh ~/Projects

# Store tree_fat32_*.csv as documentation
mv tree_fat32_*.csv ~/backups/project_inventory_$(date +%Y%m%d).csv

# Then sanitize and backup
DRY_RUN=false FILESYSTEM=fat32 ./exfat-sanitizer-v7.6.0.sh ~/Projects
rsync -av ~/Projects /Volumes/ExternalDrive/
```

### Regular maintenance with logging

```bash
#!/bin/bash
LOG_DIR="$HOME/.sanitizer_logs"
mkdir -p "$LOG_DIR"

DRY_RUN=false FILESYSTEM=fat32 ./exfat-sanitizer-v7.6.0.sh ~/Documents

# Archive outputs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mv sanitizer_*.csv tree_*.csv "$LOG_DIR/$TIMESTAMP/"
```

## Compatibility

### Operating Systems

- ✅ **macOS** 10.13+ (Tested on Big Sur, Monterey, Ventura, Sonoma)
- ✅ **Linux** (Tested on Ubuntu 18.04+, Debian, CentOS)
- ✅ **BSD** (OpenBSD, FreeBSD)
- ✅ **Windows** (WSL 2, Git Bash)

### Shell Compatibility

- ✅ **Bash** 3.2+ (Primary)
- ⚠️ **Zsh** (Runs but test first)
- ❌ **Fish** (Not supported)
- ❌ **Dash** (Not supported)

### Filesystem Targets

- ✅ **exFAT** (External drives, SD cards, USB)
- ✅ **FAT32** (Older USB drives, legacy systems)
- ✅ **APFS** (macOS native)
- ✅ **ext4** (Linux native)
- ✅ **NTFS** (Windows drives)

## Limitations

- **No undo**: Changes are permanent. Always test with dry-run first.
- **Special permissions**: Script runs as current user; cannot change files owned by others
- **Symlinks**: Script follows symlinks; use `-L` in find command for behavior change
- **Case sensitivity**: On case-insensitive filesystems (macOS), `file.txt` and `FILE.TXT` are same
- **Very deep nesting**: Scripts with 100+ directory levels may hit depth limits

## Contributing

Contributions welcome! Please:

1. Test on macOS and at least one Linux distribution
2. Maintain Bash 3.2+ compatibility
3. Include test cases in PR description
4. Follow existing code style (no external dependencies)

## License

MIT License - See LICENSE file for details

```
Copyright (c) 2024-2026 Fabio Baldassarri

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

## Support & Questions

### Common Questions

**Q: Is my data safe?**
A: Yes! Use `DRY_RUN=true` (default) to preview changes. No modifications occur until you set `DRY_RUN=false`.

**Q: Can I run this on a live system?**
A: Yes, but recommend testing on subset first. The script uses depth-first directory processing, which is safer.

**Q: What if script interrupts during execution?**
A: Partial renames may occur. Always backup before running with `DRY_RUN=false`.

**Q: Does it work on network drives?**
A: Yes, but performance is slower. Consider copying to local disk first for large collections.

### Getting Help

- Check troubleshooting section above
- Review CSV logs for detailed information
- Run with dry-run first to understand proposed changes
- Check script header comments for version and feature info

## Changelog

### v7.6.0 (Latest)

✨ **New Features:**
- Directory tree export to CSV (`GENERATE_TREE=true`)
- Complete file structure documentation with sizes and timestamps
- FAT32 path length validation (255 character limit)
- Enhanced collision detection

🔧 **Improvements:**
- Better progress reporting
- Comprehensive CSV escaping
- System file exclusion list expanded
- Better error messages

### v7.5.0

- Fixed Bash 3.2 compatibility issues
- Improved counter tracking in subshells
- FAT32 path length validation
- Collision detection system

### v7.4.0 & Earlier

- Core sanitization functionality
- Multi-filesystem support
- CSV logging system

---

**Made with ❤️ for data integrity and filesystem compatibility**

*Last updated: January 3, 2026*
