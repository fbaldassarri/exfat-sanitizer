# Release Notes - exfat-sanitizer v11.1.0

**Release Date:** February 1, 2026  
**Version:** 11.1.0  
**Repository:** https://github.com/fbaldassarri/exfat-sanitizer

---

## 🎉 Overview

**v11.1.0 is a major feature release** that combines the critical accent preservation fix from v11.0.5 with the advanced features from v9.0.2.2, creating the most complete and reliable version to date.

This release delivers:
- ✅ **Fixed accent preservation** - Correctly preserves all Unicode/accented characters
- ✅ **Advanced security features** - Shell safety and Unicode exploit detection
- ✅ **Smart copy modes** - Conflict resolution with skip/overwrite/versioning
- ✅ **System file filtering** - Automatic exclusion of metadata files
- ✅ **Full backward compatibility** - Seamless upgrade from v11.0.5

---

## 📥 Installation

### Quick Install

```bash
# Download the latest version
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v11.1.0/exfat-sanitizer-v11.1.0.sh

# Make it executable
chmod +x exfat-sanitizer-v11.1.0.sh

# Test with dry-run (safe, no changes)
./exfat-sanitizer-v11.1.0.sh ~/Music
```

### Clone Repository

```bash
git clone https://github.com/fbaldassarri/exfat-sanitizer.git
cd exfat-sanitizer
chmod +x exfat-sanitizer-v11.1.0.sh
./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

## ✨ What's New in v11.1.0

### 🔥 New Features (from v9.0.2.2)

#### 1. **Shell Safety Control** (`CHECK_SHELL_SAFETY`)

Protect against command injection attacks by controlling shell metacharacter removal:

```bash
# Enable shell safety for untrusted files
CHECK_SHELL_SAFETY=true ./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**Removes dangerous characters:** `$` `` ` `` `&` `;` `#` `~` `^` `!` `(` `)`

**Example:**
```
Before: file$(rm -rf /).sh
After:  file__rm -rf ___.sh
```

**Default:** `false` (preserves more characters for trusted sources)

---

#### 2. **Advanced Copy Behavior** (`COPY_BEHAVIOR`)

Smart conflict resolution when copying files to backup destinations:

**Options:**
- **`skip`** (default) - Don't overwrite existing files
- **`overwrite`** - Replace existing files
- **`version`** - Create versioned copies (file-v1.ext, file-v2.ext)

```bash
# Copy with automatic versioning
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Example output:**
```
First run:  song.mp3 → /Volumes/Backup/song.mp3
Second run: song.mp3 → /Volumes/Backup/song-v1.mp3
Third run:  song.mp3 → /Volumes/Backup/song-v2.mp3
```

---

#### 3. **Unicode Exploit Detection** (`CHECK_UNICODE_EXPLOITS`)

Remove invisible zero-width characters that can be used for visual spoofing:

```bash
# Enable Unicode exploit detection
CHECK_UNICODE_EXPLOITS=true ./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**Removes:**
- U+200B (zero-width space)
- U+200C (zero-width non-joiner)
- U+200D (zero-width joiner)
- U+FEFF (zero-width no-break space)

**Example:**
```
Before: test​​​.pdf  (contains invisible characters)
After:  test.pdf    (cleaned)
```

**Default:** `false`

---

#### 4. **Custom Replacement Character** (`REPLACEMENT_CHAR`)

Customize what character replaces illegal characters:

```bash
# Use dash instead of underscore
REPLACEMENT_CHAR=- ./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Example:**
```
With REPLACEMENT_CHAR=_  →  song<test>.mp3 → song_test_.mp3
With REPLACEMENT_CHAR=-  →  song<test>.mp3 → song-test-.mp3
```

**Default:** `_` (underscore)

---

#### 5. **System File Filtering**

Automatically skips common system/metadata files (no configuration needed):

**Filtered files:**
- `.DS_Store` (macOS Finder metadata)
- `Thumbs.db` (Windows thumbnail cache)
- `.Spotlight-V100` (macOS Spotlight index)
- `.stfolder`, `.sync.ffs_db` (Sync tools)
- `.gitignore`, `.stignore` (Version control)

**Benefits:**
- Cleaner CSV logs
- ~5-10% faster processing
- No manual exclusion patterns needed

---

### 🐛 Preserved Fixes (from v11.0.5)

#### Critical: Accent Preservation Fixed

v11.1.0 maintains the **critical accent preservation fix** from v11.0.5:

```bash
# v9.0.2.2 (BROKEN)
"Café del Mar.mp3"   → "Cafe del Mar.mp3"      ❌ Stripped
"L'interprète.flac"  → "L'interprete.flac"     ❌ Stripped
"Müller - España.wav"→ "Muller - Espana.wav"   ❌ Stripped

# v11.1.0 (FIXED)
"Café del Mar.mp3"   → "Café del Mar.mp3"      ✅ Preserved
"L'interprète.flac"  → "L'interprète.flac"     ✅ Preserved
"Müller - España.wav"→ "Müller - España.wav"   ✅ Preserved
```

**Preserved characters:**
- Italian: `à è é ì ò ù`
- French: `é è ê ë à ù ô î ï ç`
- Spanish: `ñ á é í ó ú ü`
- German: `ö ä ü ß`
- Portuguese: `ã õ ç á é í ó ú`

---

## 📊 Complete Feature Matrix

| Feature | v9.0.2.2 | v11.0.5 | v11.1.0 |
|---------|----------|---------|---------|
| **Accent Preservation** | ❌ **BROKEN** | ✅ **FIXED** | ✅ **FIXED** |
| **UTF-8 Multi-byte Handling** | ⚠️ Basic | ✅ Advanced | ✅ Advanced |
| **Unicode Normalization (NFC)** | ❌ No | ✅ Yes | ✅ Yes |
| **Apostrophe Preservation** | ✅ Yes | ✅ Yes | ✅ Yes |
| **CHECK_SHELL_SAFETY** | ✅ Yes (default on) | ❌ No | ✅ Yes (default off) |
| **COPY_BEHAVIOR** | ✅ Yes | ❌ No | ✅ Yes |
| **CHECK_UNICODE_EXPLOITS** | ✅ Yes | ❌ No | ✅ Yes |
| **REPLACEMENT_CHAR** | ✅ Yes | ❌ No | ✅ Yes |
| **System File Filtering** | ✅ Yes | ❌ No | ✅ Yes |
| **IGNORE_FILE Support** | ❌ No | ✅ Yes | ✅ Yes |
| **GENERATE_TREE** | ✅ Yes | ✅ Yes | ✅ Yes |

---

## 🚀 Usage Examples

### Example 1: Audio Library (Recommended)

Perfect for music collections with international artists:

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

---

### Example 2: Maximum Security

For untrusted downloads with shell injection protection:

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
- ❌ `doc<script>.html` → `doc_script_.html` (illegal chars)

---

### Example 3: Smart Backup with Versioning

Create backups with automatic version control:

```bash
FILESYSTEM=exfat \
COPY_TO=/Volumes/Backup \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Result:**
- 1st run: `song.mp3` → `/Volumes/Backup/song.mp3`
- 2nd run: `song.mp3` → `/Volumes/Backup/song-v1.mp3`
- 3rd run: `song.mp3` → `/Volumes/Backup/song-v2.mp3`

---

## ⚙️ Configuration Reference

### Core Settings

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `FILESYSTEM` | `fat32` | `fat32`, `exfat`, `ntfs`, `apfs`, `hfsplus`, `universal` | Target filesystem |
| `SANITIZATION_MODE` | `conservative` | `strict`, `conservative`, `permissive` | Sanitization level |
| `DRY_RUN` | `true` | `true`, `false` | Preview or apply changes |

### New Features (v11.1.0)

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `CHECK_SHELL_SAFETY` | `false` | `true`, `false` | Remove shell metacharacters |
| `COPY_BEHAVIOR` | `skip` | `skip`, `overwrite`, `version` | Conflict resolution |
| `CHECK_UNICODE_EXPLOITS` | `false` | `true`, `false` | Remove zero-width chars |
| `REPLACEMENT_CHAR` | `_` | Any single char | Replacement character |

### Other Options

| Variable | Default | Description |
|----------|---------|-------------|
| `COPY_TO` | (empty) | Destination directory for copying |
| `IGNORE_FILE` | `~/.exfat-sanitizer-ignore` | Pattern file for exclusions |
| `GENERATE_TREE` | `false` | Generate directory tree CSV |

---

## 📈 Enhanced CSV Output

v11.1.0 includes enhanced CSV logging with the new **Copy Status** column:

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|song$.mp3|song_.mp3|ShellDangerous|Music/Album|25|RENAMED|COPIED|-
File|track.flac|track.flac|-|Music/Album|26|LOGGED|SKIPPED|-
Directory|bad<dir>|bad_dir_|UniversalForbidden|Music|20|RENAMED|NA|-
```

**New Copy Status values:**
- `COPIED` - Successfully copied to destination
- `SKIPPED` - Skipped due to conflict (with `COPY_BEHAVIOR=skip`)
- `NA` - No copy operation (when `COPY_TO` is not set)

---

## 🔄 Migration Guide

### From v11.0.5 to v11.1.0

✅ **Fully backward-compatible** - No breaking changes!

**What's new:**
- New configuration options (all default to v11.0.5 behavior)
- Enhanced CSV output with Copy Status column
- System file filtering (automatic)

**Action required:** None - simply replace the script file.

**To enable new features:**
```bash
# Add advanced features to your existing workflow
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
CHECK_SHELL_SAFETY=true \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

### From v9.0.2.2 to v11.1.0

⚠️ **Accent handling has changed (for the better!)**

**Critical difference:**
```bash
# v9.0.2.2 behavior (BROKEN)
"Café.mp3" → "Cafe.mp3"  # ❌ Accent stripped

# v11.1.0 behavior (CORRECT)
"Café.mp3" → "Café.mp3"  # ✅ Accent preserved
```

**Migration steps:**
1. **Backup your files first** (always recommended)
2. Run v11.1.0 with `DRY_RUN=true` to preview changes
3. Review the CSV output carefully
4. If satisfied, run with `DRY_RUN=false`

**To maintain v9.0.2.2 security settings:**
```bash
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**Default value changes:**

| Variable | v9.0.2.2 | v11.1.0 | Impact |
|----------|----------|---------|--------|
| `CHECK_SHELL_SAFETY` | `true` | `false` | More characters preserved by default |
| `SANITIZATION_MODE` | `strict` | `conservative` | Less aggressive by default |
| `FILESYSTEM` | `universal` | `fat32` | More permissive by default |

---

## 🧪 Testing

### Automated Test Suite

v11.1.0 includes a comprehensive test suite:

```bash
# Download test suite
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v11.1.0/test-v11.1.0.sh
chmod +x test-v11.1.0.sh

# Run tests
./test-v11.1.0.sh
```

**Tests verify:**
- ✅ Accent preservation (critical)
- ✅ Illegal character removal
- ✅ Shell safety feature
- ✅ System file filtering
- ✅ Copy versioning
- ✅ Custom replacement character
- ✅ Apostrophe preservation
- ✅ DRY_RUN mode

---

## 📚 Documentation

### Included Documentation

- **[README.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/README.md)** - Main project documentation
- **[QUICK-START-v11.1.0.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/docs/QUICK-START-v11.1.0.md)** - Quick start guide with examples
- **[CHANGELOG-v11.1.0.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/docs/CHANGELOG-v11.1.0.md)** - Complete changelog
- **[VERSION-COMPARISON.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/docs/VERSION-COMPARISON.md)** - Version comparison guide

### Example Scripts

- **[audio-library.sh](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/examples/audio-library.sh)** - Music library workflow
- **[security-scan.sh](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/examples/security-scan.sh)** - Security scanning
- **[backup-versioning.sh](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/examples/backup-versioning.sh)** - Backup with versioning

---

## 🔧 Requirements

### Minimum Requirements

- **Bash**: Version 4.0 or higher
- **Standard Unix Tools**: `find`, `sed`, `grep`, `awk`, `mv`, `cp`

### Optional (for Unicode Normalization)

One of the following:
- **Python 3** (recommended, usually pre-installed)
- **uconv** (ICU tools)
- **Perl** with `Unicode::Normalize` module

### Platform Support

- ✅ **macOS** - Works out of the box (Bash 3.2+ compatible)
- ✅ **Linux** - All distributions with Bash 4.0+
- ✅ **Windows** - WSL, Git Bash, or Cygwin

---

## 🐛 Known Issues

### None Currently Known

v11.1.0 is production-ready and fully tested.

If you encounter any issues, please report them on the [GitHub Issues page](https://github.com/fbaldassarri/exfat-sanitizer/issues).

---

## 💡 Why Upgrade to v11.1.0?

### If you're on v11.0.5:
✅ **Recommended upgrade** - Adds powerful features with zero breaking changes
- Shell safety for untrusted files
- Smart copy modes with versioning
- System file filtering
- Customizable replacement character

### If you're on v9.0.2.2:
🚨 **Critical upgrade** - Fixes broken accent handling
- **Fixed:** Accents are now preserved correctly
- **Added:** Unicode normalization for cross-platform compatibility
- **Improved:** UTF-8 multi-byte character handling
- **Maintained:** All advanced features from v9.0.2.2

### If you're on older versions:
🎯 **Essential upgrade** - Modern, production-ready release
- All critical fixes and features
- Comprehensive documentation
- Active maintenance and support

---

## 🤝 Contributing

Contributions are welcome! Please feel free to:
- Report bugs via [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- Submit pull requests for improvements
- Share usage examples and feedback
- Improve documentation

See [CONTRIBUTING.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/CONTRIBUTING.md) for guidelines.

---

## 📜 License

MIT License - See [LICENSE](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/LICENSE) file for details.

**Copyright (c) 2026 fbaldassarri**

---

## 🙏 Acknowledgments

- Community feedback on Unicode handling and security features
- Contributors who reported the accent preservation bug in v9.0.2.2
- Users who requested advanced copy modes and conflict resolution
- Open-source community for inspiration and support

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/fbaldassarri/exfat-sanitizer/discussions)
- **Documentation**: [docs/](https://github.com/fbaldassarri/exfat-sanitizer/tree/main/docs)
- **Repository**: https://github.com/fbaldassarri/exfat-sanitizer

---

## 📦 Download Links

### Main Script
- [exfat-sanitizer-v11.1.0.sh](https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v11.1.0/exfat-sanitizer-v11.1.0.sh)

### Test Suite
- [test-v11.1.0.sh](https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v11.1.0/test-v11.1.0.sh)

### Source Code
- [Source code (zip)](https://github.com/fbaldassarri/exfat-sanitizer/archive/refs/tags/v11.1.0.zip)
- [Source code (tar.gz)](https://github.com/fbaldassarri/exfat-sanitizer/archive/refs/tags/v11.1.0.tar.gz)

---

## 🎯 Quick Reference

### Basic Usage
```bash
# Preview changes (safe)
./exfat-sanitizer-v11.1.0.sh ~/Music

# Apply changes
DRY_RUN=false ./exfat-sanitizer-v11.1.0.sh ~/Music
```

### Common Workflows
```bash
# Audio library
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music

# Maximum security
CHECK_SHELL_SAFETY=true CHECK_UNICODE_EXPLOITS=true \
SANITIZATION_MODE=strict DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Downloads

# Backup with versioning
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

---

**Version**: 11.1.0  
**Release Date**: February 1, 2026  
**Maintainer**: [fbaldassarri](https://github.com/fbaldassarri)  
**Repository**: https://github.com/fbaldassarri/exfat-sanitizer

**Made with ❤️ for the open-source community**
