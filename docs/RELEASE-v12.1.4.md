# Release Notes — exfat-sanitizer v12.1.4

**Release Date:** February 17, 2026
**Version:** 12.1.4
**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)

---

## Upgrade Urgency: RECOMMENDED

v12.1.4 is a bug fix release that addresses the inverted conditional logic in `sanitize_filename()` and consolidates all NFD/NFC normalization improvements from v12.1.3.

**If you're using v12.1.3 or earlier**, upgrade to get the corrected character classification logic and improved Unicode debug capabilities.

### Summary of Fixes

| Issue | Severity | Status |
|-------|----------|--------|
| Inverted `if/else` logic in `sanitize_filename()` — legal characters entered the replace branch | Critical | **Fixed** |
| NFD vs NFC comparison causing false `RENAMED` status on macOS (from v12.1.3) | Critical | **Fixed** |
| Apostrophe normalization using bash globs corrupted multi-byte UTF-8 (from v12.1.2) | Critical | **Fixed** |
| Added `DEBUG_UNICODE` mode for NFD/NFC diagnostic output | Enhancement | **New** |

---

## Installation

### Quick Install

```bash
# Download the latest version
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.4/exfat-sanitizer-v12.1.4.sh

# Make it executable
chmod +x exfat-sanitizer-v12.1.4.sh

# Test with dry-run (safe, no changes)
./exfat-sanitizer-v12.1.4.sh ~/Music
```

### Clone Repository

```bash
git clone https://github.com/fbaldassarri/exfat-sanitizer.git
cd exfat-sanitizer
chmod +x exfat-sanitizer-v12.1.4.sh
./exfat-sanitizer-v12.1.4.sh ~/Music
```

---

## What's Fixed in v12.1.4

### Fix 1: Inverted Conditional Logic in `sanitize_filename()`

**The Problem (v12.1.3 and earlier):**

The character classification logic in `sanitize_filename()` had an inverted `if/else` test. Legal characters (including accented letters) were routed to the replacement branch, while illegal characters were preserved.

```bash
# BUGGY CODE (v12.1.3)
if is_illegal_char "$char" "$illegal_chars"; then
    sanitized="${sanitized}${REPLACEMENT_CHAR}"  # ← Legal chars went here!
else
    sanitized="$sanitized$char"                  # ← Illegal chars went here!
fi
```

**The Fix (v12.1.4):**

Added the `!` (NOT) operator to invert the test, routing characters to their correct branches:

```bash
# FIXED CODE (v12.1.4)
if ! is_illegal_char "$char" "$illegal_chars"; then
    sanitized="$sanitized$char"                  # ← Legal chars preserved ✅
else
    sanitized="${sanitized}${REPLACEMENT_CHAR}"   # ← Illegal chars replaced ✅
fi
```

**File:** `exfat-sanitizer-v12.1.4.sh`
**Function:** `sanitize_filename()`
**Change:** Single character addition (`!`) to conditional test

### Fix 2: NFD→NFC Normalization (from v12.1.3)

macOS HFS+/APFS stores filenames in NFD (decomposed) Unicode form where `ò` = `o` + combining grave accent (2 code points). The script's sanitization returns NFC (composed) form where `ò` = single character (1 code point). Without normalization before comparison:

```
NFD "ò" (from disk) ≠ NFC "ò" (from sanitization) → FALSE POSITIVE
```

**Fix:** Both the original filename and the sanitized result are now normalized to NFC before comparison, using a multi-method fallback chain: Python 3 → uconv → Perl → iconv.

### Fix 3: Python-Based Apostrophe Normalization (from v12.1.2)

Curly apostrophe normalization uses Python with explicit Unicode code points (U+2018, U+2019, U+201A, U+02BC) instead of bash glob patterns that corrupted multi-byte UTF-8 sequences.

---

## New Feature: Debug Mode

v12.1.4 includes `DEBUG_UNICODE` mode for diagnosing normalization issues:

```bash
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music 2>debug.log
```

Output includes:
```
DEBUG: Original: 'Ce la farò.wav' → NFC: 'Ce la farò.wav'
DEBUG: Sanitized: 'Ce la farò.wav' → NFC: 'Ce la farò.wav'
DEBUG: MISMATCH DETECTED
```

---

## Known Limitations

### macOS AppleDouble (`._`) Files

When using `COPY_TO` to copy files to exFAT or FAT32 volumes on macOS, the system automatically creates `._` companion files (4KB each) to store extended attributes and resource forks. **This is standard macOS behavior, not a script bug.**

**Cleanup options:**

```bash
# Merge or remove orphaned ._ files
dot_clean -m /Volumes/USBDRIVE/

# Delete all ._ files
find /Volumes/USBDRIVE/ -name '._*' -delete

# Prevent on USB drives (system-wide macOS setting)
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
```

### UTF-8 Character Iteration

The bash-based character-by-character processing pipeline (`extract_utf8_chars` → `while read`) may not preserve all multibyte Unicode sequences in some environments. Files with accented characters (à, è, ì, ò, ù, ï, ê, ö, ü) may still be flagged for rename when UTF-8 bytes are split during shell processing.

**Workaround:** Enable `DEBUG_UNICODE=true` to diagnose specific cases. A future release will move the character-level sanitization logic into Python for native Unicode handling.

---

## Verification

### Test Accent Preservation

```bash
# Create test directory
mkdir -p /tmp/test-accents && cd /tmp/test-accents

# Create test files
touch "Loïc Nottet.flac"
touch "Révérence.mp3"
touch "Cè di più.wav"
touch "Ce la farò.wav"

# Run v12.1.4
FILESYSTEM=fat32 DRY_RUN=true ../exfat-sanitizer-v12.1.4.sh .

# Check results
cat sanitizer_fat32_*.csv | grep -E "Loïc|Révérence|Cè|farò"
# Expected: All should show LOGGED status (not RENAMED)
```

### Verify Version

```bash
head -5 exfat-sanitizer-v12.1.4.sh
# Expected: SCRIPT_VERSION="12.1.4"
```

---

## Version Comparison

### Feature Matrix (v12.x Series)

| Feature | v12.0.0 | v12.1.0 | v12.1.1 | v12.1.2 | v12.1.3 | v12.1.4 |
|---------|---------|---------|---------|---------|---------|---------|
| Accent Preservation | Mostly | Mostly | ❌ Broken | ✅ Fixed | ✅ Fixed | ✅ Fixed |
| Apostrophe Normalization | Basic | Basic | ❌ Corrupts | ✅ Fixed | ✅ Fixed | ✅ Fixed |
| NFD/NFC Normalization | Yes | Yes | Yes | Yes | ✅ Improved | ✅ Improved |
| Conditional Logic | Correct | Correct | Correct | Correct | ❌ Inverted | ✅ Fixed |
| Debug Mode | No | No | No | No | ✅ New | ✅ Yes |
| Tree Generation | No | Yes | Yes | Yes | Yes | Yes |
| Python 3 Required | Optional | Optional | Optional | Required | Required | Required |
| Production Ready | Partial | Partial | ❌ No | ✅ Yes | Partial | ✅ Yes |

### Upgrade Path

| From | To | Priority | Notes |
|------|----|----------|-------|
| v12.1.3 | v12.1.4 | Recommended | Fixes inverted conditional logic |
| v12.1.2 | v12.1.4 | Recommended | Adds NFD/NFC normalization + logic fix |
| v12.1.1 or earlier | v12.1.4 | **Critical** | Fixes accent corruption, normalization, and logic bugs |
| v11.x | v12.1.4 | **Critical** | Major upgrade with full Unicode support |

---

## Migration Guide

### From v12.1.2 or v12.1.3 to v12.1.4

**Action Required:** Recommended upgrade

```bash
# Replace script file
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.4/exfat-sanitizer-v12.1.4.sh
chmod +x exfat-sanitizer-v12.1.4.sh

# Test (same commands work)
DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music
```

**Backward Compatibility:** Fully compatible — no breaking changes. All environment variables and options are identical.

### From v12.1.1 or Earlier to v12.1.4

**Action Required:** Critical upgrade

1. **Check your Python 3 installation:**
   ```bash
   python3 --version
   # Should be 3.6 or higher
   ```

2. **Download v12.1.4:**
   ```bash
   curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.4/exfat-sanitizer-v12.1.4.sh
   chmod +x exfat-sanitizer-v12.1.4.sh
   ```

3. **Test with dry run:**
   ```bash
   DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music
   ```

4. **If your files were already sanitized by v12.1.1 or earlier:**
   - **Option 1:** Re-import from original backup (accents intact)
   - **Option 2:** Accept sanitized names (they're FAT32-compatible)
   - **Option 3:** Manually rename critical files to restore accents
   - v12.1.4 prevents future accent loss but cannot restore already-removed accents.

### From v11.x to v12.1.4

**Action Required:** Recommended upgrade

```bash
# Backup old script
mv exfat-sanitizer-v11.*.sh exfat-sanitizer-v11.sh.backup

# Download v12.1.4
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.4/exfat-sanitizer-v12.1.4.sh
chmod +x exfat-sanitizer-v12.1.4.sh

# Test (same commands work)
./exfat-sanitizer-v12.1.4.sh ~/Music
```

**What's new since v11.x:**
- FAT32 Unicode preservation via LFN (Long Filename) support
- Python-based UTF-8 character handling
- Tree generation (`GENERATE_TREE=true`)
- Enhanced copy modes (`COPY_BEHAVIOR=version`)
- NFD/NFC normalization
- Debug mode (`DEBUG_UNICODE=true`)

---

## Configuration Reference

### Core Settings

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `FILESYSTEM` | `fat32` | `fat32`, `exfat`, `ntfs`, `apfs`, `hfsplus`, `universal` | Target filesystem |
| `SANITIZATION_MODE` | `conservative` | `strict`, `conservative`, `permissive` | Sanitization level |
| `DRY_RUN` | `true` | `true`, `false` | Preview or apply changes |
| `REPLACEMENT_CHAR` | `_` | Any single character | Replacement for illegal characters |

### Unicode Handling (v12.x)

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `PRESERVE_UNICODE` | `true` | `true`, `false` | Preserve all Unicode characters |
| `NORMALIZE_APOSTROPHES` | `true` | `true`, `false` | Normalize curly apostrophes (fixed in v12.1.2) |
| `EXTENDED_CHARSET` | `true` | `true`, `false` | Allow extended character sets |
| `DEBUG_UNICODE` | `false` | `true`, `false` | NFD/NFC diagnostic output (new in v12.1.3) |

### Copy & Security

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `COPY_TO` | *(empty)* | Path to destination | Destination directory for copying |
| `COPY_BEHAVIOR` | `skip` | `skip`, `overwrite`, `version` | Conflict resolution |
| `CHECK_SHELL_SAFETY` | `false` | `true`, `false` | Remove shell metacharacters |
| `CHECK_UNICODE_EXPLOITS` | `false` | `true`, `false` | Remove zero-width characters |

### Other

| Variable | Default | Description |
|----------|---------|-------------|
| `IGNORE_FILE` | `~/.exfat-sanitizer-ignore` | Pattern file for exclusions |
| `GENERATE_TREE` | `false` | Generate directory tree CSV snapshot |

---

## Requirements

### Minimum Requirements

- **Bash** 4.0 or higher
- **Python 3** (3.6 or higher) — Required for UTF-8 character handling and apostrophe normalization
- **Standard Unix Tools** — `find`, `sed`, `grep`, `awk`, `mv`, `cp`

### Optional (Fallback Support)

- Perl with `Unicode::Normalize` module
- `uconv` (ICU tools) for Unicode normalization

### Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | ✅ Fully supported | Python 3 pre-installed on macOS 12.3+ |
| Linux | ✅ Fully supported | Install Python 3 if missing |
| Windows | ⚠️ Partial | Requires WSL, Git Bash, or Cygwin |

---

## Download Links

### Main Script

- [`exfat-sanitizer-v12.1.4.sh`](https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.4/exfat-sanitizer-v12.1.4.sh)

### Source Code

- [Source code (zip)](https://github.com/fbaldassarri/exfat-sanitizer/archive/refs/tags/v12.1.4.zip)
- [Source code (tar.gz)](https://github.com/fbaldassarri/exfat-sanitizer/archive/refs/tags/v12.1.4.tar.gz)

---

## Documentation

Included in this release:

- **README.md** — Complete project documentation
- **RELEASE-v12.1.4.md** — This file
- **exfat-sanitizer-ignore.example.txt** — Example ignore patterns

---

## Quick Reference

### Verify Fix

```bash
# Download v12.1.4
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v12.1.4/exfat-sanitizer-v12.1.4.sh
chmod +x exfat-sanitizer-v12.1.4.sh

# Test on your music library
./exfat-sanitizer-v12.1.4.sh ~/Music
```

### Common Workflows

```bash
# Sanitize FAT32 music library (accents preserved)
FILESYSTEM=fat32 DRY_RUN=false ./exfat-sanitizer-v12.1.4.sh ~/Music

# Copy to USB drive with versioning
FILESYSTEM=exfat COPY_TO=/Volumes/USB/ COPY_BEHAVIOR=version DRY_RUN=false ./exfat-sanitizer-v12.1.4.sh ~/Music

# Generate tree snapshot
GENERATE_TREE=true ./exfat-sanitizer-v12.1.4.sh ~/Music

# Debug Unicode normalization
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music 2>debug.log
```

---

## Contributing

Contributions are welcome! Please feel free to:

- Report bugs via [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- Submit pull requests for improvements
- Share usage examples and feedback
- Improve documentation

---

## Acknowledgments

- Community members who reported the inverted logic and NFD/NFC normalization bugs
- Users who provided test cases with French, Italian, and German music libraries
- Contributors who helped verify fixes on real-world data
- Open-source community for inspiration and support

---

## License

MIT License — See [LICENSE](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/LICENSE) file for details.

Copyright (c) 2026 fbaldassarri

---

## Support

- [Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- [Discussions](https://github.com/fbaldassarri/exfat-sanitizer/discussions)
- [Repository](https://github.com/fbaldassarri/exfat-sanitizer)

---

*Made with ❤️ for the open-source community*

**Version:** 12.1.4 | **Release Date:** February 17, 2026 | **Maintainer:** [fbaldassarri](https://github.com/fbaldassarri)
