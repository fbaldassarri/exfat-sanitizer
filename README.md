# exfat-sanitizer

**Production-ready bash script for sanitizing filenames across multiple filesystems (exFAT, FAT32, APFS, NTFS, HFS+).** Perfect for audio libraries, media collections, and cross-platform file management.

Handles filesystem-specific character restrictions, Unicode normalization (NFD→NFC), smart apostrophe normalization, and advanced copy modes — all with dry-run preview, interactive rename mode, comprehensive CSV logging, and flexible ignore patterns.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Shell-Bash%204.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/Requires-Python%203-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey.svg)](#platform-support)

---

## Key Features

- **Multi-Filesystem Support** — exFAT, FAT32, APFS, NTFS, HFS+, Universal
- **Unicode Preservation** — Preserves accented characters (à, è, é, ì, ò, ù, ï, ê, ö, ü, ä, È)
- **Python-Based Sanitization** — Character-level processing runs entirely in Python for full Unicode safety
- **FAT32 LFN Support** — Leverages Long Filename (LFN) UTF-16 support in modern FAT32
- **Smart Apostrophe Normalization** — Python-based Unicode-aware curly→straight conversion
- **NFD→NFC Normalization** — Handles macOS decomposed Unicode for consistent comparison
- **Interactive Mode** — Operator-driven rename decisions with input validation
- **Three Sanitization Modes** — Strict, Conservative, Permissive
- **Advanced Copy Mode** — Skip, overwrite, or version files on conflict
- **Shell Safety** — Optional removal of shell metacharacters for security
- **Unicode Exploit Detection** — Optional removal of zero-width and bidirectional characters
- **Dry Run Mode** — Preview all changes before applying
- **System File Filtering** — Automatically skips `.DS_Store`, `Thumbs.db`, etc.
- **Comprehensive Logging** — CSV export with detailed change tracking
- **Tree Export** — Optional directory tree snapshot generation
- **Ignore Patterns** — Flexible pattern-based file exclusion
- **Debug Mode** — `DEBUG_UNICODE=true` for NFD/NFC diagnostic output

---

## Quick Start

### Installation

```bash
# Download the latest version
curl -O https://raw.githubusercontent.com/fbaldassarri/exfat-sanitizer/main/exfat-sanitizer-v13.0.0.sh

# Make it executable
chmod +x exfat-sanitizer-v13.0.0.sh

# Test with dry-run (safe, no changes)
./exfat-sanitizer-v13.0.0.sh ~/Music
```

### Basic Usage

```bash
# Preview changes (default dry-run mode)
./exfat-sanitizer-v13.0.0.sh ~/Music

# Apply changes
DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music

# Target specific filesystem
FILESYSTEM=exfat DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music

# Copy sanitized files to external drive
FILESYSTEM=exfat COPY_TO=/Volumes/USB/ DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music

# Interactive mode — approve each rename manually
FILESYSTEM=exfat INTERACTIVE=true DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music

# Generate tree snapshot + sanitize
GENERATE_TREE=true FILESYSTEM=fat32 DRY_RUN=true ./exfat-sanitizer-v13.0.0.sh ~/Music
```

### Dependencies

**Required:**
- Python 3 — for character-level sanitization, UTF-8 handling, and apostrophe normalization

```bash
# Check if you have Python 3
python3 --version

# Install if missing
# macOS
brew install python3

# Ubuntu/Debian
sudo apt-get install python3

# Fedora/RHEL
sudo dnf install python3
```

**Optional (fallback):**
- Perl with `Unicode::Normalize` module
- `uconv` (ICU tools) for Unicode normalization
- `iconv` (last-resort UTF-8 passthrough)

---

## What's New in v13.0.0

### New Feature: Interactive Mode

Set `INTERACTIVE=true` to manually approve or override each rename. The script shows the current filename and an auto-suggested replacement; press Enter to accept, or type a custom name. Invalid input (containing illegal characters for the target filesystem) is rejected with a prompt to try again.

```bash
FILESYSTEM=exfat INTERACTIVE=true DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music
```

Example session:

```
── Interactive Rename ──────────────────────
  Type:      File
  Current:   Song<Test>Track.mp3
  Suggested: Song_Test_Track.mp3
────────────────────────────────────────────
  Enter new name (or press Enter to accept suggested): My Custom Song.mp3
```

Interactive mode works with `DRY_RUN=true` (choices are logged to CSV but not applied) and `DRY_RUN=false` (choices are applied immediately). Files that are already compliant are never prompted.

### Python-Based Sanitization Pipeline

The entire character-level sanitization now runs inside Python instead of piping characters through bash's `while read` loop. This resolves a critical bug where multibyte UTF-8 characters (È, è, à, ì, ò, ù, and others) were silently dropped on macOS due to byte-splitting in bash pipe processing. All Unicode characters are now handled natively as code points, guaranteeing correct preservation.

### Bug Fixes

| Version | Issue | Status |
|---------|-------|--------|
| v13.0.0 | Multibyte UTF-8 characters (È, è, à) silently dropped during bash pipe processing on macOS | Fixed |
| v12.1.5 | Added interactive mode (`INTERACTIVE=true`) for operator-driven rename decisions | New feature |
| v12.1.5 | Moved character-level sanitization from bash to Python for Unicode safety | Fixed |
| v12.1.4 | Inverted `if/else` logic in `sanitize_filename()` — legal characters entered the replace branch | Fixed |
| v12.1.3 | NFD vs NFC comparison causing false `RENAMED` status on macOS | Fixed |
| v12.1.2 | Apostrophe normalization using bash globs corrupted multi-byte UTF-8 | Fixed |

### Known Limitations

- **macOS `._` (AppleDouble) files**: When using `COPY_TO` to copy files to exFAT/FAT32 volumes, macOS automatically creates `._` companion files to store extended attributes. This is standard macOS behavior, not a script bug. See [Handling AppleDouble Files](#handling-appledouble-files) for cleanup options.
- **Python 3 subprocess overhead**: Each file invokes a Python subprocess for sanitization (~10–20ms). For large libraries (4,000+ files) this adds ~40–80 seconds total. A future release will use a persistent Python interpreter for batch processing.

---

## Configuration

All configuration is done via environment variables.

### Core Settings

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `FILESYSTEM` | `fat32` | `fat32`, `exfat`, `ntfs`, `apfs`, `hfsplus`, `universal` | Target filesystem type |
| `SANITIZATION_MODE` | `conservative` | `strict`, `conservative`, `permissive` | How aggressively to sanitize |
| `DRY_RUN` | `true` | `true`, `false` | Preview mode (`true`) or apply changes (`false`) |
| `REPLACEMENT_CHAR` | `_` | Any single character | Character used to replace illegal characters |

### Interactive Mode

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `INTERACTIVE` | `false` | `true`, `false` | Prompt operator for each rename decision |

When enabled, only files and directories that need renaming are prompted. The operator sees the current name and a suggested replacement. Input is validated against the target filesystem's rules and re-prompted if invalid. Works with both `DRY_RUN=true` (preview) and `DRY_RUN=false` (apply).

### Copy Mode

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `COPY_TO` | *(empty)* | Path to destination | Destination directory for sanitized copies |
| `COPY_BEHAVIOR` | `skip` | `skip`, `overwrite`, `version` | How to handle filename conflicts at destination |

### Unicode Handling

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `PRESERVE_UNICODE` | `true` | `true`, `false` | Preserve all Unicode characters |
| `NORMALIZE_APOSTROPHES` | `true` | `true`, `false` | Convert curly apostrophes to straight |
| `EXTENDED_CHARSET` | `true` | `true`, `false` | Allow extended character sets |
| `DEBUG_UNICODE` | `false` | `true`, `false` | Print NFD/NFC diagnostic output to stderr |

### Security Options

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `CHECK_SHELL_SAFETY` | `false` | `true`, `false` | Remove shell metacharacters (`$`, `` ` ``, `&`, `;`, etc.) |
| `CHECK_UNICODE_EXPLOITS` | `false` | `true`, `false` | Remove zero-width and bidirectional characters |

### Other Options

| Variable | Default | Description |
|----------|---------|-------------|
| `IGNORE_FILE` | `~/.exfat-sanitizer-ignore` | Path to pattern file for exclusions |
| `GENERATE_TREE` | `false` | Generate directory tree CSV snapshot before processing |

---

## Sanitization Modes

### `conservative` (Recommended Default)

Removes only officially forbidden characters per filesystem. Preserves apostrophes, accents, Unicode, and spaces. Best for music libraries, documents, and general use.

```
exFAT:  Café Müller.mp3              → unchanged ✅
exFAT:  03 È Per Te.flac             → unchanged ✅
exFAT:  L'amore resta se c'è.flac   → unchanged ✅
FAT32:  song<test>.mp3               → song_test_.mp3
```

### `strict` (Maximum Safety)

Removes all problematic characters including control characters. Adds extra safety checks. Best for untrusted sources and automation scripts.

### `permissive` (Minimal Changes)

Removes only universal forbidden characters. Fastest and least invasive. Best for speed-optimized workflows.

---

## Filesystem Types

### `fat32` — Legacy USB Drives, Car Stereos

Older USB drives, car stereos, legacy devices (4GB file limit).

```bash
FILESYSTEM=fat32 ./exfat-sanitizer-v13.0.0.sh ~/Music
```

- Unicode accents preserved via Long Filename (LFN) UTF-16 support
- Forbids `" * / : < > ? \ |` and control chars (0–31, 127)
- File size limit: 4GB max per file
- Reserved names blocked: `CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`

### `exfat` — Modern USB Drives, SD Cards

Modern removable media, supports files >4GB.

```bash
FILESYSTEM=exfat ./exfat-sanitizer-v13.0.0.sh ~/Music
```

- Full Unicode support, same character restrictions as FAT32
- No file size limit (supports >4GB files)
- Best for modern USB drives, SD cards, external SSDs

### `universal` — Maximum Compatibility

Ensures compatibility with any target system.

```bash
FILESYSTEM=universal ./exfat-sanitizer-v13.0.0.sh ~/Downloads
```

- Most restrictive ruleset (union of all filesystem rules)
- Still preserves Unicode and accents
- Safest for cross-platform portability

### `apfs`, `ntfs`, `hfsplus`

Native filesystem optimizations for specific platforms.

```bash
FILESYSTEM=apfs ./exfat-sanitizer-v13.0.0.sh ~/Documents     # macOS
FILESYSTEM=ntfs ./exfat-sanitizer-v13.0.0.sh ~/Documents     # Windows
FILESYSTEM=hfsplus ./exfat-sanitizer-v13.0.0.sh ~/Documents  # Legacy macOS
```

---

## Use Cases

### 1. Audio Library for USB Drive (FAT32/exFAT)

Prepare a music collection with accents preserved:

```bash
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v13.0.0.sh ~/Music
```

### 2. Interactive Sanitization for Careful Review

Manually approve each rename, with the option to type a custom name:

```bash
FILESYSTEM=exfat \
  INTERACTIVE=true \
  DRY_RUN=false \
  ./exfat-sanitizer-v13.0.0.sh ~/Music
```

Files that are already compliant are skipped silently. Only files with illegal characters trigger a prompt.

### 3. Copy with Sanitization to Backup Drive

Smart backup with automatic version control:

```bash
FILESYSTEM=fat32 \
  COPY_TO=/Volumes/USBDRIVE/ \
  COPY_BEHAVIOR=version \
  DRY_RUN=false \
  ./exfat-sanitizer-v13.0.0.sh ~/Music
```

Version conflicts are handled automatically:
- 1st run: `song.mp3` → `/Volumes/USBDRIVE/song.mp3`
- 2nd run: `song.mp3` → `/Volumes/USBDRIVE/song-v1.mp3`
- 3rd run: `song.mp3` → `/Volumes/USBDRIVE/song-v2.mp3`

### 4. Generate Directory Tree Snapshot

Export complete directory structure before changes:

```bash
GENERATE_TREE=true \
  FILESYSTEM=fat32 \
  DRY_RUN=true \
  ./exfat-sanitizer-v13.0.0.sh ~/Music
# Outputs: tree_fat32_YYYYMMDD_HHMMSS.csv
```

### 5. Maximum Security for Downloads

Remove shell-dangerous characters and Unicode exploits:

```bash
FILESYSTEM=universal \
  SANITIZATION_MODE=strict \
  CHECK_SHELL_SAFETY=true \
  CHECK_UNICODE_EXPLOITS=true \
  DRY_RUN=false \
  ./exfat-sanitizer-v13.0.0.sh ~/Downloads
```

### 6. Workflow Automation Script

Create a reusable wrapper:

```bash
#!/bin/bash
# sanitize-music.sh — Sanitize music library for USB drive
FILESYSTEM=exfat \
  COPY_TO=/Volumes/USBDRIVE/ \
  COPY_BEHAVIOR=version \
  GENERATE_TREE=true \
  IGNORE_FILE=./exfat-sanitizer-ignore.txt \
  DRY_RUN=false \
  ./exfat-sanitizer-v13.0.0.sh ~/Music
```

---

## Output Files

### CSV Log

Every run generates a detailed CSV log (`sanitizer_<filesystem>_<timestamp>.csv`):

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|song<test>.mp3|song_test_.mp3|-|Music/Album/|25|RENAMED|COPIED|-
File|Loïc.flac|Loïc.flac|-|Music/Album/|26|LOGGED|SKIPPED|-
Directory|bad:dir|bad_dir|-|Music/|20|RENAMED|NA|-
```

**Status values:**
- `RENAMED` — File was renamed (illegal characters found, or operator chose a new name in interactive mode)
- `LOGGED` — File was checked but not changed (already compliant)
- `IGNORED` — File matched an ignore pattern
- `FAILED` — Operation failed (collision, permissions, etc.)

**Copy Status values:**
- `COPIED` — Successfully copied to destination
- `SKIPPED` — Skipped due to conflict (with `COPY_BEHAVIOR=skip`)
- `NA` — No copy operation (`COPY_TO` not set)

### Tree Export (Optional)

```bash
GENERATE_TREE=true ./exfat-sanitizer-v13.0.0.sh ~/Music
# Outputs: tree_<filesystem>_<timestamp>.csv
```

```csv
Type|Name|Path|Depth
Directory|Loïc Nottet|Loïc Nottet|0
File|01 Rhythm Inside.flac|Loïc Nottet/2015 Rhythm Inside/01 Rhythm Inside.flac|2
```

---

## Ignore Patterns

Create an ignore file to exclude specific files, directories, or patterns from processing.

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
IGNORE_FILE=./exfat-sanitizer-ignore.txt ./exfat-sanitizer-v13.0.0.sh ~/Music
```

---

## Copy Mode Behaviors

### `skip` (Default — Safe)

Skip if destination file already exists. Best for incremental backups.

```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=skip DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music
```

### `overwrite` (Replace Existing)

Replace destination file if it exists. Best for full backups and synchronization.

```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=overwrite DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music
```

### `version` (Create Versions)

Create versioned copies with incremental suffixes. Best for version control and archival.

```bash
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false ./exfat-sanitizer-v13.0.0.sh ~/Music
# song.mp3 (original)
# song-v1.mp3 (first conflict)
# song-v2.mp3 (second conflict)
```

---

## Handling AppleDouble Files

When copying files to exFAT or FAT32 volumes on macOS, the system automatically creates `._` (dot-underscore) companion files. These store extended attributes and resource forks that the target filesystem cannot natively hold. **This is standard macOS behavior, not a script bug.**

### Identification

```
._1997 Elisa - Pipes and Flowers (Album)    ← 4KB AppleDouble metadata
  1997 Elisa - Pipes and Flowers (Album)    ← Actual directory
```

All `._` files are exactly 4,096 bytes and mirror the real file/folder name.

### Cleanup Options

```bash
# Option 1: Merge or remove orphaned ._ files
dot_clean -m /Volumes/USBDRIVE/

# Option 2: Delete all ._ files
find /Volumes/USBDRIVE/ -name '._*' -delete

# Option 3: Prevent on USB drives (system-wide macOS setting)
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
# (Requires logout/restart to take effect)
```

---

## Security Features

### Shell Safety Mode

Protect against command injection attacks:

```bash
CHECK_SHELL_SAFETY=true ./exfat-sanitizer-v13.0.0.sh ~/Downloads
```

Removes dangerous characters: `$`, `` ` ``, `&`, `;`, `#`, `~`, `^`, `!`, `(`, `)`

### Unicode Exploit Detection

Remove invisible zero-width characters:

```bash
CHECK_UNICODE_EXPLOITS=true ./exfat-sanitizer-v13.0.0.sh ~/Downloads
```

Removes: U+200B (zero-width space), U+200C (zero-width non-joiner), U+200D (zero-width joiner), U+FEFF (zero-width no-break space)

---

## Troubleshooting

### Accented characters being stripped

In versions prior to v12.1.5, the bash-based character iteration pipeline could split multibyte UTF-8 sequences, causing characters like È, è, and à to be silently dropped on macOS. **This is fixed in v13.0.0** — the character-level sanitization now runs entirely in Python.

If you still see unexpected behavior:

```bash
# Enable debug mode to inspect normalization
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v13.0.0.sh ~/Music 2>debug.log

# Check debug output
grep "MISMATCH" debug.log
```

### Permission denied

```bash
# Check permissions
ls -la ~/Music

# Fix permissions
chmod -R u+rw ~/Music
```

### Apostrophes becoming straight quotes

This is expected behavior when `NORMALIZE_APOSTROPHES=true` (default). Curly apostrophes (`'` `'`) are converted to straight (`'`) for maximum filesystem compatibility.

To disable:

```bash
NORMALIZE_APOSTROPHES=false ./exfat-sanitizer-v13.0.0.sh ~/Music
```

### Verify you're running v13.0.0

```bash
head -7 exfat-sanitizer-v13.0.0.sh
# Expected: SCRIPT_VERSION="13.0.0"
```

---

## Requirements

### Minimum Requirements

- **Bash** 4.0 or higher
- **Python 3** — Required for character-level sanitization, UTF-8 handling, and apostrophe normalization
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

## Version History

| Version | Date | Description |
|---------|------|-------------|
| **v13.0.0** | 2026-03-06 | Fixed multibyte UTF-8 characters (È, è, à) being silently dropped on macOS |
| v12.1.5 | 2026-03-06 | Interactive mode (`INTERACTIVE=true`); Python-based sanitization pipeline replacing bash character loop |
| v12.1.4 | 2026-02-17 | Fixed inverted `if/else` logic in `sanitize_filename()`; NFD→NFC normalization improvements; `DEBUG_UNICODE` mode |
| v12.1.3 | 2026-02-04 | NFD/NFC normalization comparison fix; debug output support |
| v12.1.2 | 2026-02-03 | Fixed apostrophe normalization corrupting UTF-8 (Python-based rewrite) |
| v12.1.1 | 2026-02-02 | Normalized comparison (NFD/NFC) to prevent false positives |
| v12.1.0 | 2026-02-02 | Added `PRESERVE_UNICODE`, `NORMALIZE_APOSTROPHES`, Python-based UTF-8 extraction |
| v12.0.0 | 2026-02-01 | Complete rewrite with Unicode support, tree generation, enhanced copy modes |

**Upgrade priority:** Always use the latest version for best Unicode/accent preservation.

---

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

### Development

```bash
# Clone repository
git clone https://github.com/fbaldassarri/exfat-sanitizer.git
cd exfat-sanitizer

# Make changes
vim exfat-sanitizer-v13.0.0.sh

# Test changes
DRY_RUN=true ./exfat-sanitizer-v13.0.0.sh ~/test-data/

# Submit PR
git add .
git commit -m "Description of changes"
git push origin feature-branch
```

### Code Style

- Use `shellcheck` for bash linting
- Add comments for complex logic
- Test with both Python 3 and Perl fallback
- Verify Unicode preservation with real-world filenames (including È, è, à, ì, ò, ù)

---

## Related Resources

- [FAT32 File System Specification (Microsoft)](https://learn.microsoft.com/en-us/windows/win32/fileio/filesystem-functionality-comparison)
- [Unicode Normalization Forms (UAX #15)](https://unicode.org/reports/tr15/)
- [exFAT File System Specification](https://learn.microsoft.com/en-us/windows/win32/fileio/exfat-specification)

---

## License

MIT License — See [LICENSE](LICENSE) file for details.

Free to use, modify, and distribute. No warranty provided.

---

## Support

- [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- [GitHub Discussions](https://github.com/fbaldassarri/exfat-sanitizer/discussions)
- [Latest Release](https://github.com/fbaldassarri/exfat-sanitizer/releases)

---

If this project helped you, please consider giving it a ⭐ on GitHub!

---

*Made with ❤️ for the open-source community*

**Version:** 13.0.0 | **Release Date:** 2026-03-06 | **Maintainer:** [fbaldassarri](https://github.com/fbaldassarri)
