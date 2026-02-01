# exfat-sanitizer

[![Version](https://img.shields.io/badge/version-11.1.0-blue.svg)](https://github.com/fbaldassarri/exfat-sanitizer/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey.svg)](https://github.com/fbaldassarri/exfat-sanitizer)

**Production-ready bash script for sanitizing filenames across multiple filesystems (exFAT, FAT32, APFS, NTFS, HFS+)**

Perfect for audio libraries, media collections, and cross-platform file management. Preserves accented characters, handles Unicode correctly, and provides advanced copy modes with conflict resolution.

---

## 🎯 Key Features

- **✅ Multi-Filesystem Support**: exFAT, FAT32, APFS, NTFS, HFS+, Universal
- **✅ Accent Preservation**: Correctly preserves è, é, à, ñ, ö, ü and all Unicode characters
- **✅ Three Sanitization Modes**: Strict, Conservative, Permissive
- **✅ Advanced Copy Mode**: Skip, overwrite, or version files on conflict
- **✅ Shell Safety**: Optional removal of shell metacharacters for security
- **✅ Dry Run Mode**: Preview all changes before applying
- **✅ System File Filtering**: Automatically skips `.DS_Store`, `Thumbs.db`, etc.
- **✅ Comprehensive Logging**: CSV export with detailed change tracking
- **✅ Ignore Patterns**: Flexible pattern-based file exclusion
- **✅ Unicode Normalization**: NFD→NFC conversion for cross-platform compatibility

---

## 🚀 Quick Start

### Installation

```bash
# Download the latest version
curl -O https://raw.githubusercontent.com/fbaldassarri/exfat-sanitizer/main/exfat-sanitizer-v11.1.0.sh

# Make it executable
chmod +x exfat-sanitizer-v11.1.0.sh

# Test with dry-run (safe, no changes)
./exfat-sanitizer-v11.1.0.sh ~/Music
```

### Basic Usage

```bash
# Preview changes (default: dry-run mode)
./exfat-sanitizer-v11.1.0.sh ~/Music

# Apply changes
DRY_RUN=false ./exfat-sanitizer-v11.1.0.sh ~/Music

# Target specific filesystem
FILESYSTEM=exfat DRY_RUN=false ./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

## 📋 Use Cases

### 1. Audio Library for USB Drive

Perfect for preparing music collections for exFAT/FAT32 drives:

```bash
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

### 2. Maximum Security for Downloads

Remove shell-dangerous characters and Unicode exploits:

```bash
FILESYSTEM=universal \
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**Protects against:**
- ❌ `file$(cmd).txt` → `file__cmd_.txt` (shell injection)
- ❌ `test​​​.pdf` → `test.pdf` (zero-width chars)

### 3. Copy to Backup with Versioning

Smart backup with automatic version control:

```bash
FILESYSTEM=exfat \
COPY_TO=/Volumes/Backup \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Creates versions on conflicts:**
- 1st run: `song.mp3` → `/Volumes/Backup/song.mp3`
- 2nd run: `song.mp3` → `/Volumes/Backup/song-v1.mp3`
- 3rd run: `song.mp3` → `/Volumes/Backup/song-v2.mp3`

---

## ⚙️ Configuration Options

### Core Settings

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `FILESYSTEM` | `fat32` | `fat32`, `exfat`, `ntfs`, `apfs`, `hfsplus`, `universal` | Target filesystem type |
| `SANITIZATION_MODE` | `conservative` | `strict`, `conservative`, `permissive` | How aggressive to sanitize |
| `DRY_RUN` | `true` | `true`, `false` | Preview mode (true) or apply changes (false) |

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
- Preserves: apostrophes, accents, Unicode, spaces
- **Best for**: Music libraries, documents, general use

### `strict` (Maximum Safety)
- Removes **all problematic** characters including control chars
- Adds extra safety checks
- **Best for**: Untrusted sources, automation scripts

### `permissive` (Minimal Changes)
- Removes only **universal forbidden** characters
- Fastest, least invasive
- **Best for**: Speed-optimized workflows

---

## 🗂️ Filesystem Types

### `exfat` - Modern USB Drives & SD Cards
Modern removable media, supports files >4GB
```bash
FILESYSTEM=exfat ./exfat-sanitizer-v11.1.0.sh ~/Music
```
- ✅ Allows: apostrophes, accents, Unicode
- ❌ Forbids: `" * / : < > ? \ |` + control chars

### `fat32` - Legacy Compatibility
Older USB drives, car stereos, legacy devices (4GB file limit)
```bash
FILESYSTEM=fat32 ./exfat-sanitizer-v11.1.0.sh ~/Music
```
- ✅ Same restrictions as exFAT
- ⚠️ File size limit: 4GB max

### `universal` - Maximum Compatibility
Unknown destination, ensures compatibility with ANY system
```bash
FILESYSTEM=universal ./exfat-sanitizer-v11.1.0.sh ~/Downloads
```
- Most restrictive ruleset
- Safest for cross-platform portability

### `apfs` / `ntfs` / `hfsplus`
Native filesystem optimizations for specific platforms
```bash
FILESYSTEM=apfs ./exfat-sanitizer-v11.1.0.sh ~/Documents    # macOS
FILESYSTEM=ntfs ./exfat-sanitizer-v11.1.0.sh ~/Documents    # Windows
FILESYSTEM=hfsplus ./exfat-sanitizer-v11.1.0.sh ~/Documents # Legacy macOS
```

---

## 📊 Output Files

### CSV Log Format

Every run generates a detailed CSV log:

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|song$.mp3|song_.mp3|ShellDangerous|Music/Album|25|RENAMED|COPIED|-
File|track.flac|track.flac|-|Music/Album|26|LOGGED|SKIPPED|-
Directory|bad<dir>|bad_dir_|UniversalForbidden|Music|20|RENAMED|NA|-
```

**Status values:**
- `RENAMED`: File was renamed
- `LOGGED`: File was checked but not changed
- `IGNORED`: File matched ignore pattern
- `FAILED`: Operation failed (collision, permissions, etc.)

**Copy Status values:**
- `COPIED`: Successfully copied to destination
- `SKIPPED`: Skipped due to conflict (with `COPY_BEHAVIOR=skip`)
- `NA`: No copy operation (COPY_TO not set)

### Tree Export (Optional)

Generate a directory tree snapshot:

```bash
GENERATE_TREE=true ./exfat-sanitizer-v11.1.0.sh ~/Music
```

Outputs: `tree_<filesystem>_<timestamp>.csv`

---

## 🛡️ Security Features

### Shell Safety Mode

Protect against command injection attacks:

```bash
CHECK_SHELL_SAFETY=true ./exfat-sanitizer-v11.1.0.sh ~/Downloads
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
CHECK_UNICODE_EXPLOITS=true ./exfat-sanitizer-v11.1.0.sh ~/Downloads
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
./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

## 🔄 Copy Mode Behaviors

### `skip` (Default - Safe)

Skip if destination file already exists:

```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=skip DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Use case:** Incremental backups, preserve existing files

### `overwrite` (Replace Existing)

Replace destination file if it exists:

```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=overwrite DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Use case:** Full backups, synchronization

### `version` (Create Versions)

Create versioned copies with incremental suffixes:

```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Use case:** Version control, testing, archival

**Example output:**
```
song.mp3      (original)
song-v1.mp3   (first conflict)
song-v2.mp3   (second conflict)
```

---

## 📚 Documentation

- **[QUICK-START-v11.1.0.md](docs/QUICK-START-v11.1.0.md)** - Quick start guide with examples
- **[CHANGELOG-v11.1.0.md](docs/CHANGELOG-v11.1.0.md)** - Complete changelog and feature list
- **[VERSION-COMPARISON.md](docs/VERSION-COMPARISON.md)** - Comparison between versions
- **[RELEASE-SUMMARY-v11.1.0.md](docs/RELEASE-SUMMARY-v11.1.0.md)** - Release package overview

---

## 💡 Advanced Examples

### Example 1: Custom Replacement Character

Use dash instead of underscore:

```bash
REPLACEMENT_CHAR=- DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Result:**
```
song<test>.mp3 → song-test-.mp3  (instead of song_test_.mp3)
```

### Example 2: Comprehensive Security Scan

Maximum security for untrusted files:

```bash
FILESYSTEM=universal \
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
REPLACEMENT_CHAR=_ \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

### Example 3: Workflow Automation

Create a reusable script:

```bash
#!/bin/bash
# sanitize-music.sh - Sanitize music library for USB drive

FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
COPY_TO=/Volumes/USB_DRIVE \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

## 🧪 Testing

Run the automated test suite to verify functionality:

```bash
# Download test suite
curl -O https://raw.githubusercontent.com/fbaldassarri/exfat-sanitizer/main/test-v11.1.0.sh

# Make executable
chmod +x test-v11.1.0.sh

# Run tests
./test-v11.1.0.sh
```

**Tests verify:**
- ✅ Accent preservation
- ✅ Illegal character removal
- ✅ Shell safety feature
- ✅ System file filtering
- ✅ Copy versioning
- ✅ Custom replacement character
- ✅ Apostrophe preservation
- ✅ DRY_RUN mode

---

## 🔧 Requirements

- **Bash**: Version 4.0 or higher
- **Standard Unix Tools**: `find`, `sed`, `grep`, `awk`, `mv`, `cp`
- **Optional (for Unicode normalization)**:
  - Python 3 (recommended)
  - OR `uconv` (ICU tools)
  - OR Perl with `Unicode::Normalize`

### Platform Support

- ✅ **macOS**: Pre-installed (works out of the box)
- ✅ **Linux**: Usually pre-installed
- ✅ **Windows**: WSL, Git Bash, or Cygwin

---

## 📈 What's New in v11.1.0

**Major feature release combining v11.0.5 + v9.0.2.2:**

### From v11.0.5 (Critical Fix)
- ✅ **Fixed accent preservation** - No longer strips è, é, à, ñ, ö, ü
- ✅ UTF-8 multi-byte character handling
- ✅ Unicode normalization (NFC) for cross-platform compatibility

### From v9.0.2.2 (Advanced Features)
- ✅ **CHECK_SHELL_SAFETY** - Control shell metacharacter removal
- ✅ **COPY_BEHAVIOR** - Conflict resolution (skip/overwrite/version)
- ✅ **CHECK_UNICODE_EXPLOITS** - Zero-width character removal
- ✅ **REPLACEMENT_CHAR** - Customizable replacement character
- ✅ **System file filtering** - Auto-skip `.DS_Store`, `Thumbs.db`, etc.

### Why v11.1.0?

| Feature | v9.0.2.2 | v11.0.5 | v11.1.0 |
|---------|----------|---------|---------|
| **Accent Preservation** | ❌ **BROKEN** | ✅ **FIXED** | ✅ **FIXED** |
| **Advanced Features** | ✅ Yes | ❌ No | ✅ Yes |

**v11.1.0 = Best of both worlds** 🎉

---

## 🐛 Troubleshooting

### Issue: "No changes detected"
**Cause:** Files are already compliant  
**Solution:** Check CSV log - files may already be sanitized

### Issue: "Permission denied"
**Cause:** Insufficient permissions  
**Solution:** 
```bash
# Check permissions
ls -la ~/Music

# Run with appropriate permissions
sudo ./exfat-sanitizer-v11.1.0.sh ~/Music
```

### Issue: "Unicode normalization not working"
**Cause:** Missing Python3/uconv/perl  
**Solution:**
```bash
# macOS
brew install python3

# Ubuntu/Debian
sudo apt-get install python3

# Or install ICU tools
brew install icu4c  # macOS
sudo apt-get install icu-devtools  # Linux
```

### Issue: Accents still being stripped
**Verification:** Make sure you're using v11.1.0 (not v9.0.2.2)
```bash
head -1 exfat-sanitizer-v11.1.0.sh | grep "v11.1.0"
```

**Expected output:**
```
# exfat-sanitizer v11.1.0 - COMPREHENSIVE RELEASE
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
vim exfat-sanitizer-v11.1.0.sh

# Test changes
./test-v11.1.0.sh

# Submit PR
git add .
git commit -m "Description of changes"
git push origin feature-branch
```

---

## 📜 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Inspired by cross-platform filesystem compatibility challenges
- Built for real-world audio library management
- Community feedback on Unicode handling and security features

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- **Documentation**: See [docs/](docs/) directory
- **Latest Release**: [Releases](https://github.com/fbaldassarri/exfat-sanitizer/releases)

---

## ⭐ Star History

If this project helped you, please consider giving it a star on GitHub!

[![Star History](https://img.shields.io/github/stars/fbaldassarri/exfat-sanitizer?style=social)](https://github.com/fbaldassarri/exfat-sanitizer)

---

**Made with ❤️ for the open-source community**

**Version**: 11.1.0 | **Release Date**: 2026-02-01 | **Maintainer**: [fbaldassarri](https://github.com/fbaldassarri)
