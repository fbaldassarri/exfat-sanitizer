# exfat-sanitizer

[![Version](https://img.shields.io/badge/version-12.1.2-blue.svg)](https://github.com/fbaldassarri/exfat-sanitizer/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey.svg)](https://github.com/fbaldassarri/exfat-sanitizer)

**Production-ready bash script for sanitizing filenames across multiple filesystems (exFAT, FAT32, APFS, NTFS, HFS+)**

Perfect for audio libraries, media collections, and cross-platform file management. **Fully preserves Unicode characters** including accented letters (è, é, à, ñ, ö, ü) and handles filesystem-specific restrictions correctly.

---

## 🎯 Key Features

- **✅ Multi-Filesystem Support**: exFAT, FAT32, APFS, NTFS, HFS+, Universal
- **✅ Unicode Preservation**: Correctly preserves ALL accented characters (Loïc, Révérence, C'è di più)
- **✅ FAT32 LFN Support**: Leverages Long Filename (LFN) UTF-16 support in modern FAT32
- **✅ Smart Apostrophe Normalization**: Python-based Unicode-aware normalization (no corruption!)
- **✅ Three Sanitization Modes**: Strict, Conservative, Permissive
- **✅ Advanced Copy Mode**: Skip, overwrite, or version files on conflict
- **✅ Shell Safety**: Optional removal of shell metacharacters for security
- **✅ Dry Run Mode**: Preview all changes before applying
- **✅ System File Filtering**: Automatically skips `.DS_Store`, `Thumbs.db`, etc.
- **✅ Comprehensive Logging**: CSV export with detailed change tracking
- **✅ Tree Export**: Optional directory tree snapshot generation
- **✅ Ignore Patterns**: Flexible pattern-based file exclusion

---

## 🔴 What's New in v12.1.2

**CRITICAL BUG FIX**: Apostrophe normalization no longer corrupts Unicode characters!

### The Bug (v12.1.1 and earlier)
- Used bash glob patterns (`${var//'/\'}`) that corrupted multi-byte UTF-8 characters
- **Result**: `Loïc Nottet` became `Loic Nottet`, `Révérence` became `Reverence`

### The Fix (v12.1.2)
- ✅ **Python-based Unicode-aware apostrophe normalization**
- ✅ **Explicit Unicode code points** (U+2018, U+2019, etc.)
- ✅ **Preserves ALL Unicode characters** while normalizing only apostrophes
- ✅ **Verified working**: 0 unwanted renames on 4,074-item music library test

### Verified Preservation Examples

**French/Belgian Artists (Loïc Nottet):**
```
✅ "Loïc Nottet Rhythm Inside.flac"     → PRESERVED
✅ "Révérence.flac"                      → PRESERVED
✅ "Beaux rêves.flac"                    → PRESERVED
✅ "Mis à mort.flac"                     → PRESERVED
```

**Italian Artists:**
```
✅ "C'è di più.flac"                     → PRESERVED
✅ "La vita e la felicità.flac"          → PRESERVED
✅ "E ti farò volare.flac"               → PRESERVED
```

**Only Illegal Characters Removed:**
```
❌ "Mr:Mme.mp3"      → "Mr_Mme.mp3"     (colon illegal in FAT32)
❌ "Album*.zip"      → "Album_.zip"      (asterisk illegal in FAT32)
```

---

## 🚀 Quick Start

### Installation

```bash
# Download the latest version
curl -O https://raw.githubusercontent.com/fbaldassarri/exfat-sanitizer/main/exfat-sanitizer-v12.1.2.sh

# Make it executable
chmod +x exfat-sanitizer-v12.1.2.sh

# Test with dry-run (safe, no changes)
./exfat-sanitizer-v12.1.2.sh ~/Music
```

### Basic Usage

```bash
# Preview changes (default: dry-run mode)
./exfat-sanitizer-v12.1.2.sh ~/Music

# Apply changes
DRY_RUN=false ./exfat-sanitizer-v12.1.2.sh ~/Music

# Target specific filesystem
FILESYSTEM=fat32 DRY_RUN=false ./exfat-sanitizer-v12.1.2.sh ~/Music
```

### Dependencies

**Required:** Python 3 (for UTF-8 character extraction and apostrophe normalization)

```bash
# Check if you have Python 3
python3 --version

# Install if missing:
# macOS
brew install python3

# Ubuntu/Debian
sudo apt-get install python3

# Fedora/RHEL
sudo dnf install python3
```

**Optional (fallback):** Perl with Unicode::Normalize module

---

## 📋 Use Cases

### 1. Audio Library for USB Drive (FAT32/exFAT)

Perfect for preparing music collections with **accents preserved**:

```bash
FILESYSTEM=fat32 \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Preserves:**
- ✅ `Café del Mar.mp3` → **unchanged**
- ✅ `L'interprète.flac` → **unchanged**  
- ✅ `Müller - España.wav` → **unchanged**
- ✅ `Loïc Nottet - Révérence.flac` → **unchanged**

**Only removes illegal characters:**
- ❌ `song<test>.mp3` → `song_test_.mp3` (< > illegal)
- ❌ `track:new.flac` → `track_new.flac` (: illegal)

### 2. Copy with Sanitization to Backup Drive

Smart backup with automatic version control:

```bash
FILESYSTEM=fat32 \
COPY_TO=/Volumes/Backup \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Creates versions on conflicts:**
- 1st run: `song.mp3` → `/Volumes/Backup/song.mp3`
- 2nd run: `song.mp3` → `/Volumes/Backup/song-v1.mp3`
- 3rd run: `song.mp3` → `/Volumes/Backup/song-v2.mp3`

### 3. Generate Directory Tree Snapshot

Export complete directory structure before changes:

```bash
GENERATE_TREE=true \
FILESYSTEM=fat32 \
DRY_RUN=true \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Outputs:** `tree_fat32_YYYYMMDD_HHMMSS.csv`

### 4. Maximum Security for Downloads

Remove shell-dangerous characters and Unicode exploits:

```bash
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

## ⚙️ Configuration Options

### Core Settings

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `FILESYSTEM` | `fat32` | `fat32`, `exfat`, `ntfs`, `apfs`, `hfsplus`, `universal` | Target filesystem type |
| `SANITIZATION_MODE` | `conservative` | `strict`, `conservative`, `permissive` | How aggressive to sanitize |
| `DRY_RUN` | `true` | `true`, `false` | Preview mode (true) or apply changes (false) |

### Unicode Handling (NEW in v12.x)

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `PRESERVE_UNICODE` | `true` | `true`, `false` | Preserve all Unicode characters |
| `NORMALIZE_APOSTROPHES` | `true` | `true`, `false` | Normalize curly apostrophes to straight |
| `EXTENDED_CHARSET` | `true` | `true`, `false` | Allow extended character sets |

### Copy Mode Options

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `COPY_TO` | (empty) | `/path/to/dest` | Destination directory for copying |
| `COPY_BEHAVIOR` | `skip` | `skip`, `overwrite`, `version` | Conflict resolution strategy |

### Advanced Security Options

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `CHECK_SHELL_SAFETY` | `false` | `true`, `false` | Remove shell metacharacters (`$`, `` ` ``, `&`, `;`, etc.) |
| `CHECK_UNICODE_EXPLOITS` | `false` | `true`, `false` | Remove zero-width and bidirectional characters |
| `REPLACEMENT_CHAR` | `_` | Any single char | Character for replacing illegal chars |

### Other Options

| Variable | Default | Description |
|----------|---------|-------------|
| `IGNORE_FILE` | `~/.exfat-sanitizer-ignore` | Pattern file for exclusions |
| `GENERATE_TREE` | `false` | Generate directory tree CSV snapshot |

---

## 🎨 Sanitization Modes

### `conservative` (Recommended Default)
- Removes only **officially forbidden** characters per filesystem
- **Preserves**: apostrophes, accents, Unicode, spaces
- **Best for**: Music libraries, documents, general use

**Example (FAT32):**
```
✅ "Café Müller.mp3"         → unchanged
✅ "L'été - Vivaldi.flac"    → unchanged
❌ "song:test.mp3"           → "song_test.mp3"
```

### `strict` (Maximum Safety)
- Removes **all problematic** characters including control chars
- Adds extra safety checks
- **Preserves**: accents and Unicode (only removes control/dangerous chars)
- **Best for**: Untrusted sources, automation scripts

### `permissive` (Minimal Changes)
- Removes only **universal forbidden** characters
- Fastest, least invasive
- **Best for**: Speed-optimized workflows

---

## 🗂️ Filesystem Types

### `fat32` - Legacy USB Drives & Car Stereos

Older USB drives, car stereos, legacy devices (4GB file limit)

```bash
FILESYSTEM=fat32 ./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Character Support:**
- ✅ **Unicode accents preserved** via Long Filename (LFN) UTF-16 support
- ✅ Allows: apostrophes, accents (è é à ò ù ï ê), spaces, Unicode
- ❌ Forbids: `" * / : < > ? \ |` + control chars (0-31, 127)
- ⚠️ **File size limit**: 4GB max per file

**Technical Note:** Modern FAT32 implementations support Long File Names (LFN) stored as UTF-16LE, enabling full Unicode support for filenames up to 255 characters.

### `exfat` - Modern USB Drives & SD Cards

Modern removable media, supports files >4GB

```bash
FILESYSTEM=exfat ./exfat-sanitizer-v12.1.2.sh ~/Music
```

- ✅ **Full Unicode support**
- ✅ Same character restrictions as FAT32
- ✅ No file size limit (supports >4GB files)
- **Best for**: Modern USB drives, SD cards, external SSDs

### `universal` - Maximum Compatibility

Unknown destination, ensures compatibility with ANY system

```bash
FILESYSTEM=universal ./exfat-sanitizer-v12.1.2.sh ~/Downloads
```

- Most restrictive ruleset
- Still preserves Unicode/accents
- Safest for cross-platform portability

### `apfs` / `ntfs` / `hfsplus`

Native filesystem optimizations for specific platforms

```bash
FILESYSTEM=apfs ./exfat-sanitizer-v12.1.2.sh ~/Documents    # macOS
FILESYSTEM=ntfs ./exfat-sanitizer-v12.1.2.sh ~/Documents    # Windows
FILESYSTEM=hfsplus ./exfat-sanitizer-v12.1.2.sh ~/Documents # Legacy macOS
```

---

## 📊 Output Files

### CSV Log Format

Every run generates a detailed CSV log:

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|song$.mp3|song_.mp3|ShellDangerous|Music/Album|25|RENAMED|COPIED|-
File|Loïc.flac|Loïc.flac|-|Music/Album|26|LOGGED|SKIPPED|-
Directory|bad<dir>|bad_dir_|UniversalForbidden|Music|20|RENAMED|NA|-
```

**Status values:**
- `RENAMED`: File was renamed (illegal characters found)
- `LOGGED`: File was checked but not changed (already compliant)
- `IGNORED`: File matched ignore pattern
- `FAILED`: Operation failed (collision, permissions, etc.)

**Copy Status values:**
- `COPIED`: Successfully copied to destination
- `SKIPPED`: Skipped due to conflict (with `COPY_BEHAVIOR=skip`)
- `NA`: No copy operation (COPY_TO not set)

### Tree Export (Optional)

Generate a complete directory tree snapshot:

```bash
GENERATE_TREE=true ./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Outputs:** `tree_<filesystem>_<timestamp>.csv`

**Format:**
```csv
Type|Name|Path|Depth
Directory|Loic Nottet|Loic Nottet|0
File|01 Loïc Nottet Rhythm Inside.flac|Loic Nottet/2015 Rhythm Inside (Single)/01 Loïc Nottet Rhythm Inside.flac|2
```

**Use cases:**
- Compare before/after sanitization
- Audit filesystem contents
- Generate file manifests
- Track directory structure changes

---

## 🛡️ Security Features

### Shell Safety Mode

Protect against command injection attacks:

```bash
CHECK_SHELL_SAFETY=true ./exfat-sanitizer-v12.1.2.sh ~/Downloads
```

**Removes dangerous characters:**
- `$` (variable expansion)
- `` ` `` (command substitution)
- `&` `;` (command chaining)
- `#` `~` `^` `!` `(` `)` (shell metacharacters)

**Use when:**
- Processing files from internet/email
- Files will be used in automated scripts
- Unknown or untrusted sources

### Unicode Exploit Detection

Remove invisible zero-width characters:

```bash
CHECK_UNICODE_EXPLOITS=true ./exfat-sanitizer-v12.1.2.sh ~/Downloads
```

**Removes:**
- U+200B (zero-width space)
- U+200C (zero-width non-joiner)
- U+200D (zero-width joiner)
- U+FEFF (zero-width no-break space)

**Prevents:**
- Visual spoofing attacks
- Hidden characters in filenames
- Unicode-based filename exploits

---

## 🚫 Ignore Patterns

Create custom exclusion rules:

### Create Ignore File

```bash
cat > ~/.exfat-sanitizer-ignore << 'EOF'
# Ignore specific directories
backup/*
archive/*
temp/*

# Ignore file patterns
*.tmp
*.bak
*.cache

# Ignore specific files
debug.log
test.txt
EOF
```

### Use Custom Ignore File

```bash
IGNORE_FILE=/path/to/custom-ignore.txt \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

---

## 🔄 Copy Mode Behaviors

### `skip` (Default - Safe)

Skip if destination file already exists:

```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=skip DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Use case:** Incremental backups, preserve existing files

### `overwrite` (Replace Existing)

Replace destination file if it exists:

```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=overwrite DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Use case:** Full backups, synchronization

### `version` (Create Versions)

Create versioned copies with incremental suffixes:

```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Use case:** Version control, testing, archival

**Example output:**
```
song.mp3      (original)
song-v1.mp3   (first conflict)
song-v2.mp3   (second conflict)
```

---

## 💡 Advanced Examples

### Example 1: Sanitize + Copy French Music Library to FAT32 USB

```bash
FILESYSTEM=fat32 \
COPY_TO=/Volumes/USB_DRIVE \
COPY_BEHAVIOR=version \
GENERATE_TREE=true \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music/French
```

**Result:**
- Accents preserved: `Loïc`, `Révérence`, `Café`
- Illegal chars removed: `:` `*` `<` `>` `?` → `_`
- Tree snapshot generated for comparison
- Files copied with versioning

### Example 2: Maximum Security Scan

```bash
FILESYSTEM=universal \
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
REPLACEMENT_CHAR=- \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Downloads
```

### Example 3: Custom Replacement Character

Use dash instead of underscore:

```bash
REPLACEMENT_CHAR=- DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Result:**
```
song<test>.mp3 → song-test-.mp3  (instead of song_test_.mp3)
```

### Example 4: Workflow Automation Script

Create a reusable script:

```bash
#!/bin/bash
# sanitize-music.sh - Sanitize music library for USB drive

FILESYSTEM=fat32 \
COPY_TO=/Volumes/USB_DRIVE \
COPY_BEHAVIOR=version \
GENERATE_TREE=true \
IGNORE_FILE=~/.music-ignore \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

---

## 🔧 Requirements

### Minimum Requirements

- **Bash**: Version 4.0 or higher
- **Python 3**: Required for UTF-8 character handling and apostrophe normalization
- **Standard Unix Tools**: `find`, `sed`, `grep`, `awk`, `mv`, `cp`

### Optional (Fallback Support)

- **Perl** with `Unicode::Normalize` module (fallback if Python unavailable)
- **uconv** (ICU tools) for Unicode normalization

### Platform Support

- ✅ **macOS**: Fully supported (Python 3 pre-installed on macOS 12.3+)
- ✅ **Linux**: Fully supported (install Python 3 if missing)
- ✅ **Windows**: WSL, Git Bash, or Cygwin required

### Verify Installation

```bash
# Check Python 3
python3 --version
# Expected: Python 3.6 or higher

# Test script
./exfat-sanitizer-v12.1.2.sh --help
```

---

## 📈 Version History & Changelog

### v12.1.2 (2026-02-03) - CRITICAL BUG FIX ⚠️

**Fixed:** Apostrophe normalization no longer corrupts Unicode!

**Technical Details:**
- ❌ **Bug (v12.1.1):** Used bash glob patterns that corrupted multi-byte UTF-8
- ✅ **Fix (v12.1.2):** Python-based normalization with explicit Unicode code points
- ✅ **Verified:** 0 unwanted renames on 4,074-item test library

**Affected versions:**
- v12.1.1 and earlier: Apostrophe normalization stripped accents
- v12.0.0 to v12.1.0: Same bug present

**Upgrade priority:** **CRITICAL** if using `NORMALIZE_APOSTROPHES=true`

### v12.1.1 (2026-02-02)
- Added normalized comparison (NFD/NFC) to prevent false positives
- Improved Unicode handling
- ❌ **Bug:** Apostrophe normalization corrupted UTF-8 (fixed in v12.1.2)

### v12.1.0 (2026-02-02)
- Major feature consolidation
- Added tree generation (`GENERATE_TREE`)
- Enhanced copy modes
- ❌ **Bug:** Apostrophe normalization corrupted UTF-8 (fixed in v12.1.2)

### v12.0.0 (2026-02-01)
- Complete rewrite with Unicode support
- Added `PRESERVE_UNICODE`, `NORMALIZE_APOSTROPHES`
- Python-based UTF-8 character extraction

### v11.0.5 (2026-02-01)
- Fixed accent preservation (critical fix)
- UTF-8 multi-byte character handling

### v9.0.2.2 (2026-01-30)
- Advanced features (shell safety, copy behavior)
- ❌ **Bug:** Stripped all accents

**Recommendation:** Always use **v12.1.2 or later** for Unicode/accent preservation.

---

## 🐛 Troubleshooting

### Issue: "No changes detected" but accents are missing

**Diagnosis:** Files were sanitized by older version (v11.0.4 or earlier)

**Solution:** 
```bash
# Check if accents exist in source
ls -R ~/Music | grep -E '[àèéìòùïêâäöüø]'

# If none found, source files already stripped
# Option 1: Re-import from original backup
# Option 2: Accept sanitized names (FAT32 compatible)
```

### Issue: "Python3 not found"

**Cause:** Python 3 not installed

**Solution:**
```bash
# macOS
brew install python3

# Ubuntu/Debian
sudo apt-get install python3

# Fedora/RHEL
sudo dnf install python3

# Verify
python3 --version
```

### Issue: "Permission denied"

**Cause:** Insufficient permissions

**Solution:**
```bash
# Check permissions
ls -la ~/Music

# Option 1: Fix permissions
chmod -R u+rw ~/Music

# Option 2: Run with sudo (not recommended)
sudo ./exfat-sanitizer-v12.1.2.sh ~/Music
```

### Issue: Apostrophes becoming straight quotes

**Expected behavior:** Curly apostrophes (`'`) normalize to straight (`'`)

**To disable:**
```bash
NORMALIZE_APOSTROPHES=false ./exfat-sanitizer-v12.1.2.sh ~/Music
```

### Verify You're Running v12.1.2

```bash
# Check version in script header
head -3 exfat-sanitizer-v12.1.2.sh

# Expected output:
# #!/bin/bash
# 
# # exfat-sanitizer v12.1.2 - ACCENT PRESERVATION FIX (ACTUAL FIX)
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

### Development

```bash
# Clone repository
git clone https://github.com/fbaldassarri/exfat-sanitizer.git
cd exfat-sanitizer

# Make changes
vim exfat-sanitizer-v12.1.2.sh

# Test changes
DRY_RUN=true ./exfat-sanitizer-v12.1.2.sh test-data/

# Submit PR
git add .
git commit -m "Description of changes"
git push origin feature-branch
```

### Code Style

- Use shellcheck for bash linting
- Add comments for complex logic
- Test with both Python 3 and Perl fallback
- Verify Unicode preservation with real-world filenames

---

## 📜 License

MIT License - See [LICENSE](LICENSE) file for details.

**Summary:** Free to use, modify, and distribute. No warranty provided.

---

## 🙏 Acknowledgments

- Inspired by cross-platform filesystem compatibility challenges
- Built for real-world audio library management
- Special thanks to the community for Unicode handling feedback
- FAT32 LFN specification: Microsoft Extensible Firmware Initiative

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/fbaldassarri/exfat-sanitizer/discussions)
- **Latest Release**: [Releases](https://github.com/fbaldassarri/exfat-sanitizer/releases)
- **Documentation**: See repository root for guides

---

## ⭐ Star History

If this project helped you, please consider giving it a star on GitHub!

[![Star History](https://img.shields.io/github/stars/fbaldassarri/exfat-sanitizer?style=social)](https://github.com/fbaldassarri/exfat-sanitizer)

---

## 📚 Related Resources

- [FAT32 File System Specification (Microsoft)](https://www.cs.fsu.edu/~cop4610t/assignments/project3/spec/fatspec.pdf)
- [Unicode Normalization Forms (UAX #15)](https://unicode.org/reports/tr15/)
- [exFAT File System Specification](https://docs.microsoft.com/en-us/windows/win32/fileio/exfat-specification)

---

**Made with ❤️ for the open-source community**

**Version**: 12.1.2 | **Release Date**: 2026-02-03 | **Maintainer**: [fbaldassarri](https://github.com/fbaldassarri)
