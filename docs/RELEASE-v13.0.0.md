# Release Notes — exfat-sanitizer v13.0.0

**Release Date:** March 6, 2026
**Version:** 13.0.0
**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)

---

## Upgrade Urgency: CRITICAL

v13.0.0 is a major release that introduces **Interactive Mode** for operator-driven renames and fixes a **critical UTF-8 bug** where multibyte characters (È, è, à, ì, ò, ù) were silently dropped during bash pipe processing on macOS. The entire character-level sanitization pipeline has been rewritten in Python for native Unicode safety.

**If you're using v12.1.5 or earlier**, upgrade immediately to prevent silent data loss on filenames containing accented characters.

### Summary of Changes

| Issue | Severity | Status |
|-------|----------|--------|
| Multibyte UTF-8 characters (È, è, à, ì, ò, ù) silently dropped in bash pipe | Critical | **Fixed** |
| Straight apostrophe `'` (U+0027) incorrectly removed during sanitization | Critical | **Fixed** |
| Character-level sanitization rewritten from bash to Python | Architecture | **New** |
| Interactive mode (`INTERACTIVE=true`) for operator-driven renames | Feature | **New** |
| Input validation with iterative re-prompting in interactive mode | Feature | **New** |
| DRY_RUN + INTERACTIVE coexistence for safe testing | Feature | **New** |

---

## Installation

### Quick Install

```bash
# Download the latest version
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v13.0.0/exfat-sanitizer-v13.0.0.sh

# Make it executable
chmod +x exfat-sanitizer-v13.0.0.sh

# Test with dry-run (safe, no changes)
./exfat-sanitizer-v13.0.0.sh ~/Music
```

### Clone Repository

```bash
git clone https://github.com/fbaldassarri/exfat-sanitizer.git
cd exfat-sanitizer
chmod +x exfat-sanitizer-v13.0.0.sh
./exfat-sanitizer-v13.0.0.sh ~/Music
```

---

## What's Fixed in v13.0.0

### Fix 1: Multibyte UTF-8 Characters Silently Dropped (CRITICAL)

**The Problem (v12.1.5 and earlier):**

The bash-based character-by-character sanitization pipeline used `extract_utf8_chars | while IFS= read -r char` to iterate over filenames. On macOS (bash 3.2), multibyte UTF-8 sequences were split during pipe processing. Characters like È (U+00C8, UTF-8 bytes `C3 88`) were silently dropped — not replaced, but lost entirely — leaving double spaces in suggested filenames.

Real-world example from an Italian music library:

```
Original:  "Èssere o non Èssere.flac"
v12.1.5:   "  ssere o non   ssere.flac"   ← È silently dropped!
v13.0.0:   "Èssere o non Èssere.flac"     ← È correctly preserved ✅
```

Affected characters included all multibyte UTF-8 sequences: È, è, à, ì, ò, ù, ï, ê, ö, ü, and others.

**The Fix (v13.0.0):**

The entire character-level sanitization logic has been moved from bash into an embedded Python script inside `sanitize_filename()`. Python operates on Unicode code points natively, eliminating the byte-splitting issue entirely. All checks — control characters, shell safety, zero-width exploits, illegal filesystem characters — now execute in a single Python pass.

The old bash-based loop is retained only as a fallback if Python 3 is unavailable.

**File:** `exfat-sanitizer-v13.0.0.sh`
**Function:** `sanitize_filename()`
**Change:** Complete rewrite of character-level processing from bash to Python

### Fix 2: Straight Apostrophe Incorrectly Removed

**The Problem (v12.1.5 and earlier):**

The straight apostrophe `'` (U+0027) is a legal character on exFAT, FAT32, NTFS, APFS, and HFS+ filesystems. However, the bash-based sanitization pipeline was dropping it during processing, causing filenames like `dell'Amore` to become `dellAmore` and `Cos'è` to become `Cos`.

**The Fix (v13.0.0):**

The Python-based sanitization pipeline only removes characters that are explicitly listed in the filesystem's illegal character set. Since `'` (U+0027) is not illegal on any supported filesystem, it is now correctly preserved.

---

## New Feature: Interactive Mode

v13.0.0 introduces **Interactive Mode** (`INTERACTIVE=true`), giving operators full control over every rename decision. When enabled, each file or directory that needs renaming triggers an interactive prompt showing the current name and a suggested replacement.

### How It Works

```bash
INTERACTIVE=true FILESYSTEM=exfat DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music
```

For each item needing a rename, you'll see:

```
── Interactive Rename ──────────────────────
  Type:      File
  Current:   My Song: A Remix?.flac
  Suggested: My Song_ A Remix_.flac
────────────────────────────────────────────
  Enter new name (or press Enter to accept suggested):
```

### Key Behaviors

- **Press Enter** to accept the auto-suggested name
- **Type a custom name** to use your own replacement
- **Input validation**: If your custom name contains illegal characters for the target filesystem, you'll be warned and re-prompted
- **Reserved name check**: Windows reserved names (CON, PRN, AUX, NUL, COM1-9, LPT1-9) are rejected on FAT32/universal targets
- **Empty name check**: Names that are empty or consist only of spaces/dots are rejected
- **No skip option**: Every flagged item must be given a valid name (either the suggestion or a custom one)

### DRY_RUN + INTERACTIVE Coexistence

Both modes work together for safe testing:

```bash
INTERACTIVE=true DRY_RUN=true FILESYSTEM=exfat ./exfat-sanitizer-v13.0.0.sh ~/Music
```

When both are enabled, the operator is prompted for each rename and the chosen name is logged to the CSV report, but **no filesystem changes are applied**. This is ideal for previewing the interactive workflow before committing changes.

### Technical Implementation

Interactive input reads from `/dev/tty` instead of stdin to avoid conflicts with the script's internal pipelines (which consume stdin via `extract_utf8_chars | while read`). This ensures the prompt works correctly regardless of pipeline state.

---

## Architecture Change: Python-Based Sanitization Pipeline

The most significant internal change in v13.0.0 is the migration of the character-level sanitization loop from bash to Python. This addresses the fundamental architectural tension between bash's byte-oriented processing and Unicode's character-oriented model.

### Before (v12.1.5)

```
filename → extract_utf8_chars (Python) → bash pipe → while IFS= read -r char → bash if/else → result
                                              ↑
                                    Multibyte bytes split here on macOS
```

### After (v13.0.0)

```
filename → Python (single pass: all checks in one script) → result
```

All character-level checks now execute in a single embedded Python script:

- Control character detection and removal (ASCII 0-31, 127)
- Shell metacharacter replacement (`$`, backtick, `&`, `;`, `#`, etc.)
- Zero-width Unicode exploit removal (U+200B, U+200C, U+200D, U+FEFF)
- Filesystem-specific illegal character replacement
- Leading/trailing space and dot stripping

The bash-based loop is retained as a fallback path, activated only if Python 3 is not available on the system.

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

### Python 3 Dependency

The Python-based sanitization pipeline requires Python 3.6 or higher. If Python 3 is not available, the script falls back to the bash-based character loop, which may exhibit the multibyte UTF-8 issues described above. Python 3 is pre-installed on macOS 12.3+ and most modern Linux distributions.

---

## Verification

### Test Accent Preservation (Critical Fix)

```bash
# Create test directory
mkdir -p /tmp/test-accents && cd /tmp/test-accents

# Create test files with Italian accented characters
python3 -c "
for name in ['Èssere.flac', 'Perchè no.mp3', 'Ce la farò.wav', 'Loïc Nottet.flac', \"dell'Amore.flac\"]:
    open(name, 'w').close()
"

# Run v13.0.0
FILESYSTEM=exfat DRY_RUN=true ../exfat-sanitizer-v13.0.0.sh .

# Check results
cat sanitizer_exfat_*.csv | grep -E "Èssere|Perchè|farò|Loïc|Amore"
# Expected: All should show LOGGED status (not RENAMED)
```

### Test Interactive Mode

```bash
# Create test files with illegal characters
mkdir -p /tmp/test-interactive && cd /tmp/test-interactive
python3 -c "open('My Song: Remix?.flac', 'w').close()"

# Run with interactive mode (DRY_RUN for safety)
INTERACTIVE=true DRY_RUN=true FILESYSTEM=exfat ../exfat-sanitizer-v13.0.0.sh .

# Expected: Prompt appears showing original and suggested name
# Press Enter to accept, or type a custom name
```

### Verify Version

```bash
head -5 exfat-sanitizer-v13.0.0.sh
# Expected: SCRIPT_VERSION="13.0.0"
```

---

## Version Comparison

### Feature Matrix (v12.x Series)

| Feature | v12.1.2 | v12.1.3 | v12.1.4 | v12.1.5 | v13.0.0 |
|---------|---------|---------|---------|---------|---------|
| Accent Preservation | Mostly | Mostly | Mostly | Mostly | **Full** |
| Apostrophe Handling | Fixed | Fixed | Fixed | Fixed | **Fixed** |
| NFD/NFC Normalization | Yes | Improved | Improved | Improved | Improved |
| Conditional Logic | Correct | Inverted | Fixed | Fixed | Fixed |
| Python-Based Sanitization | No | No | No | No | **Yes** |
| Interactive Mode | No | No | No | No | **Yes** |
| Debug Mode | No | New | Yes | Yes | Yes |
| Tree Generation | Yes | Yes | Yes | Yes | Yes |
| Python 3 Required | Required | Required | Required | Required | Required |
| Production Ready | Yes | Partial | Yes | Partial | **Yes** |

### Upgrade Path

| From | To | Priority | Notes |
|------|----|----------|-------|
| v12.1.5 | v13.0.0 | **Critical** | Fixes silent multibyte character loss |
| v12.1.4 | v13.0.0 | **Critical** | Fixes UTF-8 pipeline + adds interactive mode |
| v12.1.3 or earlier | v13.0.0 | **Critical** | Multiple critical fixes + new features |
| v11.x | v13.0.0 | **Critical** | Major upgrade with full Unicode support |

---

## Migration Guide

### From v12.1.4 or v12.1.5 to v13.0.0

**Action Required:** Critical upgrade

```bash
# Replace script file
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v13.0.0/exfat-sanitizer-v13.0.0.sh
chmod +x exfat-sanitizer-v13.0.0.sh

# Test (same commands work)
DRY_RUN=true ./exfat-sanitizer-v13.0.0.sh ~/Music
```

**Backward Compatibility:** Fully compatible — no breaking changes. All existing environment variables and options work identically. The new `INTERACTIVE` variable defaults to `false`, preserving existing behavior.

### From v12.1.3 or Earlier to v13.0.0

**Action Required:** Critical upgrade

1. **Check your Python 3 installation:**
   ```bash
   python3 --version
   # Should be 3.6 or higher
   ```

2. **Download v13.0.0:**
   ```bash
   curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v13.0.0/exfat-sanitizer-v13.0.0.sh
   chmod +x exfat-sanitizer-v13.0.0.sh
   ```

3. **Test with dry run:**
   ```bash
   DRY_RUN=true ./exfat-sanitizer-v13.0.0.sh ~/Music
   ```

4. **If your files were already sanitized by earlier versions:**
   - Files with accented characters (È, è, à, etc.) that were previously incorrectly renamed can be re-imported from original backups
   - v13.0.0 prevents future accent loss but cannot restore already-removed accents
   - Use `INTERACTIVE=true` for fine-grained control over future renames

### From v11.x to v13.0.0

**Action Required:** Critical upgrade

```bash
# Backup old script
mv exfat-sanitizer-v11.*.sh exfat-sanitizer-v11.sh.backup

# Download v13.0.0
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v13.0.0/exfat-sanitizer-v13.0.0.sh
chmod +x exfat-sanitizer-v13.0.0.sh

# Test (same commands work)
./exfat-sanitizer-v13.0.0.sh ~/Music
```

**What's new since v11.x:** FAT32 Unicode preservation via LFN support, Python-based sanitization pipeline, interactive mode, tree generation, enhanced copy modes, NFD/NFC normalization, and debug mode.

---

## Configuration Reference

### Core Settings

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `FILESYSTEM` | `fat32` | `fat32`, `exfat`, `ntfs`, `apfs`, `hfsplus`, `universal` | Target filesystem |
| `SANITIZATION_MODE` | `conservative` | `strict`, `conservative`, `permissive` | Sanitization level |
| `DRY_RUN` | `true` | `true`, `false` | Preview or apply changes |
| `REPLACEMENT_CHAR` | `_` | Any single character | Replacement for illegal characters |
| `INTERACTIVE` | `false` | `true`, `false` | Prompt operator for each rename **(New in v13.0.0)** |

### Unicode Handling

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `PRESERVE_UNICODE` | `true` | `true`, `false` | Preserve all Unicode characters |
| `NORMALIZE_APOSTROPHES` | `true` | `true`, `false` | Normalize curly apostrophes |
| `EXTENDED_CHARSET` | `true` | `true`, `false` | Allow extended character sets |
| `DEBUG_UNICODE` | `false` | `true`, `false` | NFD/NFC diagnostic output |

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
- **Python 3** (3.6 or higher) — Required for UTF-8 character sanitization and apostrophe normalization
- **Standard Unix Tools** — `find`, `sed`, `grep`, `awk`, `mv`, `cp`

### Optional (Fallback Support)

- Perl with `Unicode::Normalize` module
- `uconv` (ICU tools) for Unicode normalization

### Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | Fully supported | Python 3 pre-installed on macOS 12.3+ |
| Linux | Fully supported | Install Python 3 if missing |
| Windows | Partial | Requires WSL, Git Bash, or Cygwin |

---

## Download Links

### Main Script

- [`exfat-sanitizer-v13.0.0.sh`](https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v13.0.0/exfat-sanitizer-v13.0.0.sh)

### Source Code

- [Source code (zip)](https://github.com/fbaldassarri/exfat-sanitizer/archive/refs/tags/v13.0.0.zip)
- [Source code (tar.gz)](https://github.com/fbaldassarri/exfat-sanitizer/archive/refs/tags/v13.0.0.tar.gz)

---

## Documentation

Included in this release:

- **exfat-sanitizer-v13.0.0.sh** — Main script
- **README.md** — Complete project documentation
- **QUICK_START_GUIDE.md** — Getting started guide with common scenarios
- **DOCUMENTATION.md** — Deep technical dive for developers and contributors
- **RELEASE-v13.0.0.md** — This file
- **CHANGELOG-v13.0.0.md** — Complete version history
- **PROJECT_ANALYSIS.md** — Comprehensive project analysis
- **DEVELOPMENT_CONTEXT.md** — Development continuity guide with bug fix history and architecture notes
- **test.sh** — Test suite (20 tests)
- **audio-library.sh** — Example: audio library sanitization workflow
- **backup-versioning.sh** — Example: backup with versioning workflow
- **security-scan.sh** — Example: security-focused sanitization workflow
- **exfat-sanitizer-ignore.example.txt** — Example ignore patterns

---

## Quick Reference

### Verify Fix

```bash
# Download v13.0.0
curl -LO https://github.com/fbaldassarri/exfat-sanitizer/releases/download/v13.0.0/exfat-sanitizer-v13.0.0.sh
chmod +x exfat-sanitizer-v13.0.0.sh

# Test on your music library
./exfat-sanitizer-v13.0.0.sh ~/Music
```

### Common Workflows

```bash
# Sanitize exFAT music library (accents fully preserved)
FILESYSTEM=exfat DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music

# Interactive mode — choose each rename manually
INTERACTIVE=true FILESYSTEM=exfat DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music

# Preview interactive mode (no changes applied)
INTERACTIVE=true DRY_RUN=true FILESYSTEM=exfat ./exfat-sanitizer-v13.0.0.sh ~/Music

# Copy to USB drive with versioning
FILESYSTEM=exfat COPY_TO=/Volumes/USB/ COPY_BEHAVIOR=version DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music

# Generate tree snapshot
GENERATE_TREE=true ./exfat-sanitizer-v13.0.0.sh ~/Music

# Debug Unicode normalization
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v13.0.0.sh ~/Music 2>debug.log
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

- Community members who reported the multibyte UTF-8 character loss bug
- Users who provided test cases with Italian music libraries exposing the È/è/à regression
- Contributors who helped verify fixes on real-world data across macOS and Linux
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

*Made with care for the open-source community*

**Version:** 13.0.0 | **Release Date:** March 6, 2026 | **Maintainer:** [fbaldassarri](https://github.com/fbaldassarri)
