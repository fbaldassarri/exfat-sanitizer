# exfat-sanitizer Deep Dive Documentation

**File**: `DOCUMENTATION.md`  
**Applies To**: `exfat-sanitizer-v12.1.2.sh`  
**Version**: 12.1.2  
**Repository**: https://github.com/fbaldassarri/exfat-sanitizer  
**Status**: Production-Ready (Critical Bug Fix Release)

---

## 1. Introduction

This document provides a **deep technical and conceptual dive** into `exfat-sanitizer` v12.1.2, beyond what is covered in `README.md` and `QUICK-START-v12.1.2.md`.

It is intended for:
- Developers who want to understand or extend the script
- Power users who want to tune behavior deeply
- Contributors preparing pull requests
- Future maintainers picking up the project
- Technical auditors evaluating the tool

If you just want to use the tool, start with:
- `README.md` - Overview and feature list
- `QUICK-START-v12.1.2.md` - Getting started guide
- `RELEASE-v12.1.2.md` - Release notes
- `CHANGELOG-v12.1.2.md` - Version history

This document assumes **familiarity with bash**, filesystems, Unicode, and command-line workflows.

---

## 2. Conceptual Model

### 2.1 Problem Space

Modern workflows regularly move data across:
- macOS (APFS, HFS+)
- Windows (NTFS, legacy FAT32)
- Linux (ext4, xfs, btrfs, etc.)
- Removable media (exFAT, FAT32)
- Network shares (SMB/CIFS, NFS)

Each filesystem has differing rules for:
- **Allowed characters**: What characters are legal in filenames
- **Unicode support**: How Unicode is stored (UTF-8, UTF-16LE, normalization)
- **Reserved filenames**: Names with special meanings (Windows DOS names)
- **Path length limits**: Maximum path and filename lengths
- **Case sensitivity**: Case-preserving vs case-insensitive

As a result, filenames that are valid in one environment may:
- Fail to copy or sync silently
- Be rejected with cryptic error messages
- Break backup tools and workflows
- Fail in media players, DAWs, or other applications
- Lose accented characters during transfer

### 2.2 The Unicode Challenge

**v12.1.2 specifically addresses Unicode preservation:**

#### FAT32/exFAT Unicode Support

Modern FAT32 and exFAT support Unicode via **Long Filename (LFN)** stored as UTF-16LE:

- **Short Filename (SFN)**: 8.3 format, ASCII-only (legacy DOS)
- **Long Filename (LFN)**: Up to 255 characters, stored as UTF-16LE

This means FAT32/exFAT **fully support** accented characters like:
- French: `è é ê ë à ù ô î ï ç ñ`
- Italian: `à è é ì ò ù`
- Spanish: `ñ á é í ó ú ü`
- German: `ö ä ü ß`
- Portuguese: `ã õ ç`

**Critical v12.1.2 Fix**: Previous versions (v12.1.1 and earlier) had a bug where apostrophe normalization corrupted multi-byte UTF-8 sequences, stripping accents. v12.1.2 uses Python-based Unicode-aware normalization to preserve all Unicode characters.

### 2.3 Core Solution

`exfat-sanitizer` solves cross-platform filename issues by:

1. **Scanning** a directory tree recursively
2. **Evaluating** each filename against selected filesystem rules
3. **Preserving** Unicode/accented characters (v12.x feature)
4. **Normalizing** apostrophes safely (v12.1.2 fix)
5. **Sanitizing** illegal characters only (configurable strictness)
6. **Recording** all decisions in detailed CSV logs
7. **Optionally copying** sanitized data to new destinations with conflict resolution

### 2.4 Core Principles

1. **Safety**
   - Default to preview mode (`DRY_RUN=true`)
   - Never delete any file or directory
   - Provide complete audit logs (CSV)
   - Preserve Unicode characters

2. **Correctness**
   - Filesystem-aware character rules
   - Unicode-safe operations (Python 3 required)
   - Explicit Unicode code point handling

3. **Predictability**
   - Same input + same options → same output
   - Mode- and filesystem-specific behavior clearly defined
   - Deterministic renaming logic

4. **Transparency**
   - CSV logs show what changed, why, and where
   - Summary statistics printed to console
   - Tree export option for structure visualization

---

## 3. Architecture Overview

### 3.1 Execution Flow

```
1. Initialization
   ├─ Validate inputs (FILESYSTEM, SANITIZATION_MODE, etc.)
   ├─ Initialize temp counters
   ├─ Create CSV log file
   └─ Set up trap for cleanup

2. Optional Tree Generation
   └─ Generate pre-sanitization tree snapshot

3. Directory Processing (Bottom-Up)
   ├─ Find all directories
   ├─ Sort reverse (deepest first)
   └─ For each directory:
       ├─ Skip system files
       ├─ Extract UTF-8 characters (Python 3)
       ├─ Sanitize filename
       ├─ Normalize apostrophes (Python 3)
       ├─ Check path length
       ├─ Detect collisions
       └─ Rename (if DRY_RUN=false) or log

4. File Processing (Top-Down)
   └─ For each file:
       ├─ Skip system files
       ├─ Extract UTF-8 characters (Python 3)
       ├─ Sanitize filename
       ├─ Normalize apostrophes (Python 3)
       ├─ Check path length
       ├─ Detect collisions
       ├─ Rename (if DRY_RUN=false) or log
       └─ Copy (if COPY_TO set)

5. Summary & Cleanup
   ├─ Print statistics
   ├─ Close CSV log
   └─ Cleanup temp files
```

### 3.2 Key Dependencies

**Required:**
- Bash 4.0+
- Python 3.6+ (new in v12.1.2)
- Standard Unix tools: `find`, `sed`, `grep`, `awk`, `mv`, `cp`

**Why Python 3 is Required (v12.1.2):**

Two critical functions require Unicode-aware string handling:

1. **`extract_utf8_chars()`**: Safely extracts UTF-8 characters from filenames
   ```python
   # Handles multi-byte UTF-8 sequences correctly
   text = sys.stdin.read().strip()
   print(text)  # UTF-8 safe output
   ```

2. **`normalize_apostrophes()`**: Normalizes curly apostrophes without corrupting UTF-8
   ```python
   # Uses explicit Unicode code points
   replacements = {
       '\u2018': "'",  # LEFT SINGLE QUOTATION MARK
       '\u2019': "'",  # RIGHT SINGLE QUOTATION MARK
       # ... etc
   }
   ```

**Fallback Behavior**: If Python 3 is unavailable, critical functions fail gracefully, but the script cannot guarantee Unicode preservation.

---

## 4. Filesystem Modes & Character Rules

### 4.1 Filesystem Types

`FILESYSTEM` controls **which ruleset** is applied:

- **`fat32`**: FAT32-style rules for legacy removable media
  - 4GB max file size limit
  - **Supports Unicode via LFN** (Long Filename UTF-16LE)
  - Path limit: 260 characters
  - Forbidden: `" * / : < > ? \ |` + control chars (0-31, 127)

- **`exfat`**: exFAT-style rules for modern removable media
  - No file size limit
  - **Supports full Unicode**
  - Path limit: 260 characters (conservative for Windows compatibility)
  - Forbidden: same as FAT32

- **`ntfs`**: Windows NTFS rules
  - Full Unicode support
  - Path limit: 255 characters
  - Forbidden: universal forbidden + control characters

- **`apfs`**: macOS APFS rules
  - Full Unicode support (NFD normalized)
  - Path limit: 255 characters
  - Minimal forbidden character set

- **`hfsplus`**: HFS+ legacy macOS rules
  - Unicode support with colon handling
  - Path limit: 255 characters
  - Colon (`:`) replaced with alternate

- **`universal`**: Maximum compatibility mode
  - Most restrictive ruleset
  - Works on ANY filesystem
  - Path limit: 260 characters

### 4.2 Character Rules by Filesystem

#### Universal Forbidden Characters (ALL modes)

```
< > : " / \ | ? * NUL
```

These characters are **never allowed** in any filesystem mode, as they're forbidden by at least one major filesystem.

#### FAT32/exFAT Specifics

**Forbidden characters:**
```
" * / : < > ? \ |
+ control characters (0-31, 127)
```

**Unicode Support via LFN:**
- Long Filename (LFN) stored as UTF-16LE
- Supports full Unicode range
- Up to 255 UTF-16 code units
- ✅ **Preserves all accented characters**

**Example preserved characters:**
```
✅ è é à ò ù ï ê ñ ö ü ß ç ã õ
✅ Loïc, Révérence, C'è di più, Café
```

#### NTFS Specifics

**Forbidden characters:**
```
< > : " / \ | ? * NUL
+ control characters (0x00–0x1F, 0x7F)
```

**Unicode Support:**
- Native UTF-16LE storage
- Full Unicode support
- Case-insensitive, case-preserving

#### APFS Specifics

**Forbidden characters:**
```
/ : (minimal set)
```

**Unicode Support:**
- NFD normalized (decomposed)
- Full Unicode support
- Case-insensitive or case-sensitive (depends on volume)

**Note**: macOS uses NFD normalization, so `é` is stored as `e` + combining accent. The script handles NFC↔NFD conversion via `normalize_unicode()`.

#### HFS+ Specifics

**Forbidden characters:**
```
: / (colon replaced with alternate)
```

**Unicode Support:**
- UTF-16 storage
- NFD normalized (like APFS)

### 4.3 Path Length Semantics

Path limits are **conservative** for cross-platform compatibility:

| Filesystem | Path Limit | Reason |
|------------|------------|--------|
| `fat32` | 260 chars | Windows MAX_PATH compatibility |
| `exfat` | 260 chars | Windows MAX_PATH compatibility |
| `ntfs` | 255 chars | NTFS native limit |
| `apfs` | 255 chars | macOS native limit |
| `hfsplus` | 255 chars | Legacy macOS limit |
| `universal` | 260 chars | Most restrictive |

**Why Conservative?**
- Ensures compatibility with Windows tools
- Avoids edge cases in backup/sync tools
- Many applications still assume 260-character MAX_PATH

**Implementation**: `check_path_length()` function

---

## 5. Unicode Handling Architecture (v12.x)

### 5.1 The Unicode Stack

v12.x introduces a comprehensive Unicode handling architecture:

```
Input Filename (potentially NFD or NFC)
    ↓
extract_utf8_chars() - Python 3
    ↓ (UTF-8 safe extraction)
sanitize_filename() - Bash + Python
    ↓ (Remove illegal characters only)
normalize_apostrophes() - Python 3 (v12.1.2 FIX)
    ↓ (Safe Unicode-aware normalization)
normalize_unicode() - Python 3 / uconv / Perl
    ↓ (NFD → NFC conversion)
Output Filename (NFC normalized, Unicode preserved)
```

### 5.2 Key Functions

#### `extract_utf8_chars(text)` - Python 3

**Purpose**: Safely extract UTF-8 characters from potentially mixed-encoding input

**Implementation**:
```python
def extract_utf8_chars():
    import sys
    text = sys.stdin.read().strip()
    # Python's stdin handles UTF-8 natively
    print(text)
```

**Why needed**: Bash string operations can corrupt multi-byte UTF-8. Python handles UTF-8 natively.

#### `normalize_apostrophes(text)` - Python 3 (v12.1.2 FIX)

**Purpose**: Normalize curly apostrophes to straight apostrophes without corrupting UTF-8

**The Bug (v12.1.1)**:
```bash
# BROKEN: Bash glob pattern corrupted UTF-8
text="${text//'/\'}"  # ❌ Matches more than intended
# Result: "Loïc" → "Loic" (accent stripped!)
```

**The Fix (v12.1.2)**:
```python
def normalize_apostrophes():
    import sys
    text = sys.stdin.read().strip()
    
    # Explicit Unicode code points - no ambiguity!
    replacements = {
        '\u2018': "'",  # LEFT SINGLE QUOTATION MARK
        '\u2019': "'",  # RIGHT SINGLE QUOTATION MARK
        '\u201A': "'",  # SINGLE LOW-9 QUOTATION MARK
        '\u02BC': "'",  # MODIFIER LETTER APOSTROPHE
    }
    
    for old, new in replacements.items():
        text = text.replace(old, new)
    
    print(text)
```

**Why this works**:
- Uses explicit Unicode code points (`\u2018` not `'`)
- Python's `.replace()` is UTF-8 safe
- Character-by-character replacement
- No glob pattern ambiguity

**Fallback**: If Python unavailable, skip normalization (preserve curly apostrophes rather than corrupt)

#### `normalize_unicode(text)` - Multiple backends

**Purpose**: Convert NFD (macOS decomposed) to NFC (Windows/Linux composed)

**Backends** (priority order):
1. **Python 3** (preferred):
   ```python
   import unicodedata
   text = unicodedata.normalize('NFC', text)
   ```

2. **uconv** (ICU tools):
   ```bash
   echo "$text" | uconv -x "::NFD; ::NFC;"
   ```

3. **Perl** (fallback):
   ```perl
   use Unicode::Normalize;
   $text = NFC($text);
   ```

**Why needed**: macOS stores `é` as `e` + combining accent (NFD). Windows/Linux store `é` as single code point (NFC). Normalization ensures consistency.

### 5.3 Configuration Variables (v12.x)

| Variable | Default | Description |
|----------|---------|-------------|
| `PRESERVE_UNICODE` | `true` | Preserve all Unicode characters |
| `NORMALIZE_APOSTROPHES` | `true` | Normalize curly apostrophes (v12.1.2 FIXED) |
| `EXTENDED_CHARSET` | `true` | Allow extended character sets |

**Note**: In v12.1.2, these defaults ensure maximum Unicode preservation while still normalizing apostrophes safely.

---

## 6. Sanitization Modes & Pipeline

### 6.1 Sanitization Modes

`SANITIZATION_MODE` defines **how aggressively** names are modified:

#### `conservative` (RECOMMENDED DEFAULT)
- Removes only **officially forbidden** characters per filesystem
- **Preserves**: apostrophes, accents, Unicode, spaces
- **Removes**: `< > : " / \ | ? *` (universal forbidden)
- **Best for**: Music libraries, documents, general use

**Example**:
```
✅ "Café del Mar.mp3"         → unchanged
✅ "L'interprète.flac"        → unchanged
❌ "song:test.mp3"            → "song_test.mp3"
```

#### `strict` (MAXIMUM SAFETY)
- Removes **all problematic** characters
- Adds extra safety checks
- **Preserves**: accents and Unicode (only removes control/dangerous chars)
- **Best for**: Untrusted sources, automation scripts

**Example**:
```
✅ "Café.mp3"                 → unchanged
❌ "file$(cmd).txt"           → "file__cmd_.txt" (shell chars removed)
```

#### `permissive` (MINIMAL CHANGES)
- Removes only **universal forbidden** characters
- Fastest, least invasive
- **Best for**: Speed-optimized workflows

### 6.2 Sanitization Pipeline

The `sanitize_filename()` function implements a multi-stage pipeline:

```
Input: "Loïc Nottet's Song<Test>:2024.flac"
    ↓
Stage 1: Extract UTF-8 characters (Python 3)
    → "Loïc Nottet's Song<Test>:2024.flac"
    ↓
Stage 2: Remove universal forbidden characters
    → "Loïc Nottet's Song_Test__2024.flac"
    ↓
Stage 3: Control characters (if strict/NTFS)
    → (no control chars in this example)
    ↓
Stage 4: Unicode line separators
    → (no line breaks in this example)
    ↓
Stage 5: Filesystem-specific restrictions
    → (FAT32: no additional restrictions)
    ↓
Stage 6: Shell metacharacters (if CHECK_SHELL_SAFETY=true)
    → (apostrophe preserved in conservative mode)
    ↓
Stage 7: Unicode exploits (if CHECK_UNICODE_EXPLOITS=true)
    → (no zero-width chars in this example)
    ↓
Stage 8: Normalize apostrophes (Python 3, v12.1.2)
    → "Loïc Nottet's Song_Test__2024.flac"
    ↓
Stage 9: Leading/trailing cleanup
    → (no dots to remove)
    ↓
Stage 10: Reserved names (Windows/DOS)
    → (not a reserved name)
    ↓
Output: "Loïc Nottet's Song_Test__2024.flac"
Status: RENAMED (< > : removed, accents preserved!)
```

### 6.3 Character Replacement

**Default replacement character**: `_` (underscore)

**Configurable via**: `REPLACEMENT_CHAR`

**Examples**:
```bash
REPLACEMENT_CHAR=_  # song<test>.mp3 → song_test_.mp3
REPLACEMENT_CHAR=-  # song<test>.mp3 → song-test-.mp3
REPLACEMENT_CHAR=" " # song<test>.mp3 → song test .mp3
```

### 6.4 Reserved Names (Windows/DOS)

Windows reserves certain filenames for legacy DOS devices:

```
CON, PRN, AUX, NUL, COM1-9, LPT1-9
```

**Handling**: Append `-reserved` suffix

**Examples**:
```
CON.txt      → CON-reserved.txt
LPT1.log     → LPT1-reserved.log
normal.txt   → normal.txt (unchanged)
```

---

## 7. System File Filtering

### 7.1 Rationale

Filesystem roots often contain system files that should **never be touched**:

- `.DS_Store` (macOS Finder metadata)
- `Thumbs.db` (Windows thumbnail cache)
- `.Spotlight-V100` (macOS Spotlight index)
- `.stfolder`, `.stignore` (Syncthing)
- `.sync.ffs_db`, `.sync.ffsdb` (FreeFileSync)
- `.gitignore` (Git)

Processing these files:
- Clutters logs with noise
- Risks breaking tools that expect these files
- Serves no user purpose

### 7.2 Implementation

**Function**: `should_skip_system_file(item)`

```bash
should_skip_system_file() {
    local item="$1"
    case "$item" in
        .DS_Store|.stfolder|.sync.ffs_db|.sync.ffsdb|\
        .Spotlight-V100|Thumbs.db|.stignore|.gitignore|.sync)
            return 0  # Skip this item
            ;;
        *)
            return 1  # Process this item
            ;;
    esac
}
```

**Usage** (both directories and files):
```bash
if should_skip_system_file "$filename"; then
    continue  # Not even logged to CSV
fi
```

**Result**:
- System files are invisible to the sanitizer
- CSV logs contain only user data
- Processing is ~5-10% faster

---

## 8. Directory Processing Strategy

### 8.1 Bottom-Up Renaming

Directory renaming **must** be done **bottom-up** to avoid path breakage:

**Why?**
- If parent directories are renamed first, all child paths become invalid
- Bottom-up guarantees children are processed while parent paths are still valid

**Implementation**:
```bash
find "$TARGET_DIR" -type d -print0 2>/dev/null | \
  sort -z -r | \
  while IFS= read -r -d '' dir; do
    # Process from deepest to shallowest
    process_directory "$dir"
  done
```

**Example**:
```
Original structure:
/Music/Bad<Dir>/Sub:Dir/file.mp3

Bottom-up processing order:
1. /Music/Bad<Dir>/Sub:Dir   → /Music/Bad<Dir>/Sub_Dir
2. /Music/Bad<Dir>            → /Music/Bad_Dir_
3. /Music                     → /Music (no change)

Final structure:
/Music/Bad_Dir_/Sub_Dir/file.mp3
```

### 8.2 Directory Processing Loop

For each directory:

1. **Skip** if system directory (`should_skip_system_file()`)
2. **Extract** dirname and parent path
3. **Sanitize** dirname via `sanitize_filename()`
4. **Normalize** apostrophes via `normalize_apostrophes()`
5. **Normalize** Unicode via `normalize_unicode()`
6. **Compare** old vs new (with normalization for false positive prevention)
7. **Check** path length via `check_path_length()`
8. **Check** for collision via `is_path_used()`
9. **Branch** based on `DRY_RUN`:
   - `DRY_RUN=true`: Log only, no `mv`
   - `DRY_RUN=false`: `mv` directory, log result
10. **Log** to CSV with status (`LOGGED`, `RENAMED`, `FAILED`)

### 8.3 Collision Detection

**Problem**: Two distinct names might sanitize to the same result

**Example**:
```
"Song<Test>.mp3"  → "Song_Test_.mp3"
"Song:Test?.mp3"  → "Song_Test_.mp3"  # COLLISION!
```

**Solution**: `is_path_used()` + `register_path()`

```bash
USED_PATHS_FILE="/tmp/exfat-sanitizer-paths.txt"

is_path_used() {
    local path="$1"
    grep -Fxq "$path" "$USED_PATHS_FILE" 2>/dev/null
}

register_path() {
    local path="$1"
    echo "$path" >> "$USED_PATHS_FILE"
}
```

**Result**: Second file with collision gets `FAILED` status, not silently clobbered

---

## 9. File Processing Strategy

### 9.1 Processing Loop

For files, the script:

1. **Walk** using `find -type f -print0` (null-terminated for safety)
2. **For each file**:
   - Increment `scanned_files` counter
   - Optionally print progress (every 100 files)
   - Extract `filename` and `parentdir`
   - Skip if system file
   - Sanitize filename via full pipeline
   - Build `newpath = parentdir/newfilename`
   - Check path length
   - Branch based on:
     - `had_changes`
     - `DRY_RUN`
     - `COPY_TO` usage
3. **Log** to CSV with detailed status

### 9.2 Copy Mode Architecture

`COPY_TO` enables non-destructive copying with sanitization:

**Features**:
- Source tree remains untouched
- Destination tree has sanitized names
- Conflict resolution options
- Disk space validation

**Key Functions**:

#### `validate_destination_path(dest)`
- Checks destination exists
- Validates write permissions
- Estimates disk space requirements

#### `handle_file_conflict(dest_file, behavior)`
- **`skip`** (default): Keep existing file
- **`overwrite`**: Replace existing file
- **`version`**: Create versioned copy (`file-v1.ext`, `file-v2.ext`)

**Example** (`COPY_BEHAVIOR=version`):
```
1st run: song.mp3 → /Volumes/Backup/song.mp3
2nd run: song.mp3 → /Volumes/Backup/song-v1.mp3
3rd run: song.mp3 → /Volumes/Backup/song-v2.mp3
```

#### `copy_file(source, dest_dir, dest_filename, behavior)`
- Validates source file
- Creates destination directory if needed
- Handles conflicts per `COPY_BEHAVIOR`
- Logs copy status to CSV
- Returns success/failure

### 9.3 CSV Status Fields

**Status column** (rename processing):
- `LOGGED`: No rename needed (compliant filename)
- `RENAMED`: File was renamed (illegal characters found)
- `FAILED`: Rename failed (permissions, collision, path too long)

**Copy Status column** (copy processing):
- `COPIED`: Successfully copied to destination
- `SKIPPED`: Copy skipped due to conflict (with `COPY_BEHAVIOR=skip`)
- `FAILED`: Copy failed (I/O or permission error)
- `NA`: Copy mode not in use (`COPY_TO` not set)

**Example CSV rows**:
```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|Loïc.flac|Loïc.flac|-|Music|25|LOGGED|NA|-
File|song:test.mp3|song_test.mp3|IllegalChar|Music|27|RENAMED|COPIED|-
File|CON.txt|CON-reserved.txt|ReservedName|Docs|15|RENAMED|NA|-
```

---

## 10. Tree Generation (v12.1.0+)

### 10.1 Purpose

`GENERATE_TREE=true` creates a CSV snapshot of the directory structure:

**Use cases**:
- Compare before/after sanitization
- Document library structure
- Audit file organization
- Generate manifests

### 10.2 Implementation

**Function**: `generate_tree(root_dir, csv_file)`

**Algorithm**:
```bash
# Walk entire tree
find "$root_dir" -print0 | sort -z | while IFS= read -r -d '' item; do
    # Determine type (File or Directory)
    # Calculate depth (path component count)
    # Determine if directory has children
    # Log to tree CSV
done
```

### 10.3 Tree CSV Format

**Filename**: `tree_<filesystem>_<YYYYMMDD_HHMMSS>.csv`

**Columns**:
```csv
Type|Name|Path|Depth
Directory|Music|Music|0
Directory|Loic Nottet|Music/Loic Nottet|1
File|01 Rhythm Inside.flac|Music/Loic Nottet/01 Rhythm Inside.flac|2
```

**Field descriptions**:
- `Type`: `File` or `Directory`
- `Name`: Item name only (no path)
- `Path`: Relative path from root
- `Depth`: Directory nesting level (0 = root)

### 10.4 Workflow Example

**Before sanitization**:
```bash
FILESYSTEM=fat32 GENERATE_TREE=true DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Music
# Generates: tree_fat32_20260203_120000.csv (before)
```

**After sanitization**:
```bash
FILESYSTEM=fat32 GENERATE_TREE=true DRY_RUN=false \
  ./exfat-sanitizer-v12.1.2.sh ~/Music
# Generates: tree_fat32_20260203_120100.csv (after)
```

**Compare**:
```bash
diff tree_fat32_20260203_120000.csv tree_fat32_20260203_120100.csv
```

---

## 11. Counters, Temp Files & Traps

### 11.1 Why Temp Counters?

Bash pipelines and subshells make shared variables difficult:
- Variables in subshells don't propagate to parent
- Pipelines spawn subshells (`while` in pipeline)
- Shared state across nested functions is error-prone

**Solution**: Use temp files as counter stores

### 11.2 Counter Lifecycle

**Initialization**: `init_temp_counters()`
```bash
TEMP_COUNTER_DIR=$(mktemp -d)
for counter in scanned_dirs scanned_files renamed_dirs renamed_files \
               failed_dirs failed_files copied_files skipped_items \
               failed_items path_length_issues; do
    echo "0" > "$TEMP_COUNTER_DIR/$counter"
done
```

**Increment**: `increment_counter(name)`
```bash
increment_counter() {
    local name="$1"
    local file="$TEMP_COUNTER_DIR/$name"
    local value=$(cat "$file")
    echo $((value + 1)) > "$file"
}
```

**Read**: `get_counter(name)`
```bash
get_counter() {
    local name="$1"
    cat "$TEMP_COUNTER_DIR/$name" 2>/dev/null || echo "0"
}
```

**Cleanup**: `cleanup_temp_counters()`
```bash
cleanup_temp_counters() {
    rm -rf "$TEMP_COUNTER_DIR"
}

trap cleanup_temp_counters EXIT
```

### 11.3 USED_PATHS_FILE

**Purpose**: Track claimed paths to detect collisions

**Implementation**:
```bash
USED_PATHS_FILE="$TEMP_COUNTER_DIR/used_paths.txt"

register_path() {
    echo "$1" >> "$USED_PATHS_FILE"
}

is_path_used() {
    grep -Fxq "$1" "$USED_PATHS_FILE" 2>/dev/null
}
```

**Why needed**: Prevents two distinct filenames that sanitize to the same result from clobbering each other

---

## 12. CSV Logging & Exports

### 12.1 Main CSV Log

**Filename pattern**:
```
sanitizer_<filesystem>_<YYYYMMDD_HHMMSS>.csv
```

**Columns**:
1. **Type**: `File` or `Directory`
2. **Old Name**: Original filename
3. **New Name**: Sanitized filename (may equal Old Name)
4. **Issues**: Comma-separated issue flags
5. **Path**: Parent directory path
6. **Path Length**: Character count of full new path
7. **Status**: `LOGGED`, `RENAMED`, or `FAILED`
8. **Copy Status**: `COPIED`, `SKIPPED`, `FAILED`, or `NA`
9. **Ignore Pattern**: Ignore pattern matched (or `-`)

**Issue flags**:
- `IllegalChar`: Universal forbidden characters found
- `FAT32Specific`: FAT32-specific forbidden characters
- `ControlChar`: Control characters found
- `ShellDangerous`: Shell metacharacters found
- `ZeroWidth`: Zero-width characters found
- `ReservedName`: Windows reserved name
- `PathTooLong`: Path exceeds length limit

**Example**:
```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|Loïc Nottet.flac|Loïc Nottet.flac|-|Music|45|LOGGED|NA|-
File|Song<test>.mp3|Song_test_.mp3|IllegalChar|Music|47|RENAMED|COPIED|-
Directory|Bad:Dir|Bad_Dir|IllegalChar|Music|40|RENAMED|NA|-
```

### 12.2 CSV Escaping

**Rules**:
- Fields separated by `|` (pipe)
- Double quotes in data are doubled (`"` → `""`)
- Newlines removed during sanitization
- Null bytes removed

**Example**:
```
Original: Song "Best" (2024).mp3
Escaped:  Song ""Best"" (2024).mp3
```

### 12.3 Log File Location

Created in the **current working directory** where the script is run:

```bash
pwd
# /Users/username

./exfat-sanitizer-v12.1.2.sh ~/Music
# Creates: /Users/username/sanitizer_fat32_20260203_123456.csv
```

---

## 13. Error Handling Strategy

### 13.1 Philosophy

1. **Fail fast on configuration errors** (invalid `FILESYSTEM`, etc.)
2. **Never silently ignore rename failures**
3. **Log all problems to CSV**
4. **Provide summary statistics**
5. **Graceful degradation** (Python 3 unavailable? Warn but continue)

### 13.2 Input Validation

**Function**: `validate_inputs()`

**Checks**:
- `FILESYSTEM` in valid set (`fat32`, `exfat`, `ntfs`, `apfs`, `hfsplus`, `universal`)
- `SANITIZATION_MODE` in valid set (`strict`, `conservative`, `permissive`)
- `COPY_BEHAVIOR` in valid set (`skip`, `overwrite`, `version`) if `COPY_TO` set
- `DRY_RUN` is boolean (`true` or `false`)
- Python 3 available (warning if missing)
- Target directory exists and is readable

**On validation failure**:
- Print clear error message to stderr
- Exit with non-zero status
- No files are touched

### 13.3 Operation-Level Errors

**Categories**:
1. **Permission errors**: Cannot read/write file or directory
2. **Collision errors**: Target path already exists or claimed
3. **Path length errors**: Resulting path too long
4. **I/O errors**: Disk full, network issues, etc.

**Handling**:
- Log `FAILED` status to CSV
- Increment appropriate counter
- Print warning (optional)
- Continue with next item (non-fatal)

**Example CSV entry**:
```csv
File|verylongfilename.txt|verylongfilename.txt|PathTooLong|Very/Long/Path|275|FAILED|NA|-
```

### 13.4 Python 3 Dependency Check

**At startup**:
```bash
if ! command -v python3 >/dev/null 2>&1; then
    echo "WARNING: Python 3 not found. Unicode preservation may fail." >&2
    echo "Install Python 3 for full v12.1.2 functionality." >&2
fi
```

**During execution**:
- If Python 3 unavailable, critical functions return original input
- Warning logged to stderr
- Processing continues (degraded mode)

---

## 14. Security Considerations

### 14.1 Shell Safety Mode

**Enabled via**: `CHECK_SHELL_SAFETY=true`

**Removes dangerous shell metacharacters**:
```
$ ` & ; # ~ ^ ! ( )
```

**Why needed**:
- Prevents command injection if filenames used in scripts
- Protects against shell expansion surprises
- Important for files from untrusted sources

**Example**:
```bash
# Before
file$(rm -rf /).sh

# After (CHECK_SHELL_SAFETY=true)
file__rm -rf ___.sh
```

**When to use**:
- Processing files from internet
- Files from email attachments
- Files that will be used in automation scripts
- Unknown or untrusted sources

### 14.2 Unicode Exploit Detection

**Enabled via**: `CHECK_UNICODE_EXPLOITS=true`

**Removes zero-width and control characters**:
```
U+200B  ZERO WIDTH SPACE
U+200C  ZERO WIDTH NON-JOINER
U+200D  ZERO WIDTH JOINER
U+FEFF  ZERO WIDTH NO-BREAK SPACE
```

**Why needed**:
- Visual spoofing attacks
- Hidden characters in filenames
- Homograph attacks
- Unicode-based exploits

**Example**:
```bash
# Before (contains U+200B invisible spaces)
test​​​.pdf

# After
test.pdf
```

### 14.3 Control Character Stripping

**Always active in `strict` mode and NTFS**

**Removes**:
```
0x00-0x1F  (ASCII control characters)
0x7F       (DEL)
```

**Prevents**:
- Terminal escape exploits
- Log file corruption
- CSV and toolchain breakage

### 14.4 What the Script NEVER Does

**Guaranteed safe operations**:
- ✅ Never modifies file contents
- ✅ Never reads file contents
- ✅ Never deletes files or directories
- ✅ Never follows symlinks destructively
- ✅ Never interprets binary data
- ✅ Never executes arbitrary code from filenames

**Scope**: Strictly **names and paths only**

---

## 15. Performance Considerations

### 15.1 Bottlenecks

**Identified bottlenecks**:
1. **`find` traversal** on very large trees (100,000+ files)
2. **`grep` calls** for collision detection (O(n) per check)
3. **CSV append operations** (file I/O per item)
4. **Python 3 subprocess calls** (process spawn overhead)

### 15.2 Optimizations

**Current optimizations**:
- Null-terminated `find` output (binary-safe)
- Batched counter operations
- System file filtering early (skip before processing)
- Single-pass directory and file walks
- Minimal external process calls

**Future optimization opportunities**:
- Parallel processing (`xargs -P` or GNU `parallel`)
- Hash-based collision detection (O(1) lookup)
- Bulk CSV writing (batch inserts)
- Persistent Python interpreter (avoid spawn overhead)

### 15.3 Benchmarks

**Test environment**: 4,074-item music library

| Operation | Time | Items/sec |
|-----------|------|-----------|
| Full scan (dry-run) | 15s | 271 |
| With rename | 18s | 226 |
| With copy | 45s | 90 |
| Tree generation | +3s | - |

**Scalability**:
- Linear with item count
- CPU-bound (not I/O-bound for dry-run)
- I/O-bound for copy operations

---

## 16. Real-World Usage Patterns

### 16.1 Audio Library Management

**Scenario**: High-resolution music library for USB drive

**Configuration**:
```bash
FILESYSTEM=fat32 \
SANITIZATION_MODE=conservative \
DRY_RUN=true \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Observations**:
- 4,074 files scanned
- 0 files renamed (all compliant!)
- **All accents preserved** (French, Italian artists)
- Only illegal characters (`<`, `>`, `:`) would be replaced
- Typical execution time: 15 seconds

### 16.2 Cross-Platform Sync

**Scenario**: Mac to Windows file sharing

**Configuration**:
```bash
FILESYSTEM=universal \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/SharedDocs
```

**Benefits**:
- Maximum compatibility (works everywhere)
- Still preserves Unicode/accents
- Removes only truly problematic characters

### 16.3 Pre-Backup Validation

**Scenario**: Validate before backup to exFAT drive

**Workflow**:
```bash
# 1. Generate tree snapshot (before)
FILESYSTEM=exfat GENERATE_TREE=true DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Data

# 2. Review CSV for issues
open sanitizer_exfat_*.csv

# 3. Apply fixes if needed
FILESYSTEM=exfat DRY_RUN=false \
  ./exfat-sanitizer-v12.1.2.sh ~/Data

# 4. Generate tree snapshot (after)
FILESYSTEM=exfat GENERATE_TREE=true DRY_RUN=true \
  ./exfat-sanitizer-v12.1.2.sh ~/Data

# 5. Compare snapshots
diff tree_exfat_*_before.csv tree_exfat_*_after.csv
```

### 16.4 Copy with Sanitization

**Scenario**: Sanitized backup to external drive

**Configuration**:
```bash
FILESYSTEM=fat32 \
COPY_TO=/Volumes/Backup \
COPY_BEHAVIOR=version \
GENERATE_TREE=true \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh ~/Music
```

**Result**:
- Source untouched
- Destination has sanitized names
- Versioning handles conflicts
- Tree export for documentation

---

## 17. Extensibility & Future Directions

### 17.1 Plugin Architecture (Proposed)

**Concept**: Pluggable sanitization pipeline

**Example configuration**:
```bash
SANITIZER_STEPS="universal,controls,unicode,fs-specific,shell,reserved"
```

**Benefits**:
- User-configurable pipeline
- Third-party extensions
- A/B testing of strategies

### 17.2 Configuration File Support (Proposed)

**Format**: INI-style configuration

**Example** (`~/.exfat-sanitizer.conf`):
```ini
[defaults]
FILESYSTEM=fat32
SANITIZATION_MODE=conservative
DRY_RUN=true
PRESERVE_UNICODE=true

[paths]
IGNORE_FILE=~/.exfat-sanitizer-ignore

[copy]
COPY_BEHAVIOR=version

[security]
CHECK_SHELL_SAFETY=false
CHECK_UNICODE_EXPLOITS=false
```

### 17.3 Undo Functionality (Proposed)

**Concept**: Reverse operations using CSV log

**Example**:
```bash
./exfat-sanitizer-v12.1.2.sh --undo sanitizer_fat32_20260203_123456.csv
```

**Implementation**:
- Read CSV in reverse
- For each `RENAMED` entry, rename back from New → Old
- Validate no conflicts exist
- Log undo operations

### 17.4 Parallel Processing (Proposed)

**Concept**: Multi-threaded processing for large trees

**Example**:
```bash
PARALLEL_JOBS=4 ./exfat-sanitizer-v12.1.2.sh ~/BigData
```

**Challenges**:
- Collision detection needs synchronization
- Counter updates need atomic operations
- Directory renaming order must be preserved

### 17.5 Interactive Mode (Proposed)

**Concept**: Prompt for confirmation on each rename

**Example**:
```bash
./exfat-sanitizer-v12.1.2.sh --interactive ~/Music
```

**Workflow**:
```
Rename "Song<test>.mp3" → "Song_test_.mp3"? [Y/n/q]
```

---

## 18. Developer Notes

### 18.1 Code Style

**Conventions**:
- `snake_case` for function names
- `UPPER_CASE` for constants and environment variables
- `readonly` for true constants
- `local` for all function-scope variables
- `set -e` to fail fast on errors (disabled in specific sections)

**Example**:
```bash
readonly DEFAULT_FILESYSTEM="fat32"

sanitize_filename() {
    local filename="$1"
    local mode="$2"
    # ... processing
}
```

### 18.2 Testing Strategy

**Recommended test categories**:

1. **Unit tests**: Individual function testing
   - `sanitize_filename()` input/output
   - `normalize_apostrophes()` edge cases
   - `extract_utf8_chars()` Unicode handling

2. **Integration tests**: Full tree runs
   - Empty directories
   - Deep nesting (>10 levels)
   - Large trees (10,000+ items)

3. **Edge case tests**:
   - Filenames with only forbidden characters (`<<<<.txt`)
   - Already-reserved names (`CON.txt`)
   - Unicode edge cases (NFD vs NFC, combining characters)
   - Zero-length filenames
   - Maximum path lengths

4. **Regression tests** (v12.1.2 specific):
   - Accent preservation (`Loïc`, `Révérence`)
   - Apostrophe normalization (`L'été`)
   - Mixed accents and illegal chars (`Café<test>.mp3`)

### 18.3 Debugging Tips

**Enable verbose output**:
```bash
bash -x ./exfat-sanitizer-v12.1.2.sh ~/Music 2>&1 | head -100
```

**Check Python 3 availability**:
```bash
command -v python3 && python3 --version
```

**Test individual functions**:
```bash
# Extract and test normalize_apostrophes()
python3 << 'EOF'
import sys
text = "Loïc Nottet's Song"
replacements = {
    '\u2018': "'",
    '\u2019': "'",
}
for old, new in replacements.items():
    text = text.replace(old, new)
print(text)
EOF
```

**Inspect temp counters**:
```bash
ls -la /tmp/exfat-sanitizer-*/
cat /tmp/exfat-sanitizer-*/scanned_files
```

### 18.4 Contributing Guidelines

**Before submitting a pull request**:

1. **Test** on at least macOS and Linux
2. **Verify** Python 3 dependency is documented
3. **Update** version number and CHANGELOG
4. **Add** tests for new features
5. **Document** new configuration variables
6. **Follow** existing code style
7. **Preserve** backward compatibility when possible

**Pull request template**:
```markdown
## Description
[Brief description of change]

## Motivation
[Why this change is needed]

## Testing
- [ ] Tested on macOS
- [ ] Tested on Linux
- [ ] Added tests for new functionality
- [ ] Updated documentation

## Checklist
- [ ] Code follows style guidelines
- [ ] Backward compatible
- [ ] CHANGELOG updated
- [ ] Version number updated (if applicable)
```

---

## 19. Glossary

### Technical Terms

- **Forbidden Characters**: Characters that a given filesystem does not allow in file or directory names
- **Reserved Names**: Filenames that have special meaning (e.g., Windows DOS device names)
- **Sanitization**: Process of transforming names to conform to filesystem rules
- **Dry Run**: Preview mode where no actual changes occur, only logs produced
- **CSV Log**: Comma-separated (pipe-delimited) file containing detailed record of operations
- **Tree Export**: CSV representation of directory hierarchy structure
- **Shell Metacharacters**: Characters with special meaning to shells (e.g., `$`, `&`, `;`)
- **Unicode Normalization**: Converting between NFD (decomposed) and NFC (composed) forms
- **Long Filename (LFN)**: FAT32/exFAT extension supporting UTF-16LE filenames up to 255 chars
- **NFD**: Normalized Form Decomposed (e.g., `é` = `e` + combining accent)
- **NFC**: Normalized Form Composed (e.g., `é` = single code point)

### Status Values

- **LOGGED**: Item checked, no changes needed (compliant)
- **RENAMED**: Item was or will be renamed (non-compliant)
- **FAILED**: Operation failed (collision, permissions, path length)
- **COPIED**: File successfully copied to destination
- **SKIPPED**: Copy skipped due to conflict resolution rule
- **NA**: Not applicable (copy mode not in use)

---

## 20. Frequently Asked Questions (Technical)

### Q1: Why Python 3 instead of pure bash?

**A**: Bash string operations are **not UTF-8 safe**. They operate on bytes, not characters. This causes corruption when handling multi-byte UTF-8 sequences. Python 3 handles Unicode natively and correctly.

**Example of bash corruption**:
```bash
text="Loïc"
echo "${text//ï/i}"  # May corrupt UTF-8 byte sequence
# Result: "Loc" or worse (byte-level operation)
```

**Python 3 correct handling**:
```python
text = "Loïc"
text = text.replace("ï", "i")
# Result: "Loic" (character-level operation)
```

### Q2: Why not use `sed` or `tr` for character replacement?

**A**: `sed` and `tr` are also byte-oriented, not character-oriented. They can corrupt multi-byte UTF-8 sequences.

**Example**:
```bash
echo "Loïc" | tr "'" "'"  # May corrupt ï
```

### Q3: How does the script handle macOS NFD vs Windows NFC?

**A**: The `normalize_unicode()` function converts NFD to NFC using:
1. Python 3 `unicodedata.normalize('NFC', text)`
2. Or `uconv -x "::NFD; ::NFC;"`
3. Or Perl `Unicode::Normalize::NFC($text)`

This ensures filenames are compatible across platforms.

### Q4: What's the performance impact of Python 3 calls?

**A**: Moderate. Each Python 3 call spawns a subprocess (~10-20ms overhead). For 4,000 files, this adds ~40-80 seconds total.

**Optimization opportunity**: Persistent Python interpreter or batch processing.

### Q5: Can I use the script without Python 3?

**A**: Not recommended for v12.1.2. Critical functions (`extract_utf8_chars`, `normalize_apostrophes`) require Python 3 for Unicode safety. The script will warn and degrade functionality.

### Q6: Why not use Perl instead of Python 3?

**A**: Perl with `Unicode::Normalize` module works, but:
- Python 3 is more commonly installed (especially on modern macOS)
- Python 3 has clearer Unicode semantics
- Python 3 code is more maintainable

Perl is supported as a **fallback** for `normalize_unicode()`.

### Q7: How does bottom-up directory renaming work exactly?

**A**: 
1. `find` generates list of all directories
2. `sort -r` reverses the list (deepest paths first)
3. Process each directory from deepest to shallowest
4. This ensures child paths are valid when parents are renamed

**Example**:
```
/a/b/c  → process first
/a/b    → process second
/a      → process last
```

### Q8: What happens if two files sanitize to the same name?

**A**: The second file gets `FAILED` status and is not renamed. The `is_path_used()` function detects the collision.

**CSV output**:
```csv
File|song<1>.mp3|song_1_.mp3|IllegalChar|Music|30|RENAMED|NA|-
File|song:1?.mp3|song_1_.mp3|IllegalChar|Music|30|FAILED|NA|Collision
```

### Q9: Why use temp files for counters instead of variables?

**A**: Bash pipelines create subshells. Variables modified in subshells don't propagate to the parent shell. Temp files provide a shared state mechanism.

**Example problem**:
```bash
count=0
find . -type f | while read file; do
    count=$((count + 1))
done
echo $count  # Always prints 0! (subshell isolation)
```

**Solution**:
```bash
echo "0" > /tmp/count
find . -type f | while read file; do
    echo $(($(cat /tmp/count) + 1)) > /tmp/count
done
cat /tmp/count  # Correct count
```

### Q10: Is the script safe for production use?

**A**: Yes, with caveats:
- **Always** test with `DRY_RUN=true` first
- **Backup** critical data before applying changes
- **Review** CSV logs carefully
- **Verify** Python 3 is installed for v12.1.2
- **Test** on a subset of data first

The script never deletes files and provides complete audit logs.

---

## 21. Summary

`exfat-sanitizer` v12.1.2 represents a mature, production-ready tool for cross-platform filename sanitization with comprehensive Unicode support.

### Key Characteristics

**Technical Excellence**:
- Multi-filesystem aware rules
- Python 3-based Unicode handling
- Safe apostrophe normalization (v12.1.2 fix)
- Configurable sanitization pipeline
- Rich logging and audit trail

**Safety-First Design**:
- Default dry-run mode
- Never deletes files
- Collision detection
- Complete CSV logs
- Conservative path limits

**Unicode Support** (v12.x):
- Preserves all accented characters
- FAT32 LFN UTF-16 support documented
- Python 3-based UTF-8 safety
- NFD/NFC normalization
- Explicit Unicode code points

**Production Features**:
- System file filtering
- Copy mode with versioning
- Tree generation
- Progress reporting
- Error handling and recovery

### Recommended Reading Order

1. **README.md** - Overview and quick start
2. **QUICK-START-v12.1.2.md** - Step-by-step guide
3. **RELEASE-v12.1.2.md** - What's new and critical fixes
4. **DOCUMENTATION.md** (this file) - Deep technical dive
5. **CHANGELOG-v12.1.2.md** - Complete version history

### Support & Contributing

- **Issues**: https://github.com/fbaldassarri/exfat-sanitizer/issues
- **Discussions**: https://github.com/fbaldassarri/exfat-sanitizer/discussions
- **Repository**: https://github.com/fbaldassarri/exfat-sanitizer
- **License**: MIT

---

*Last updated: February 3, 2026 (v12.1.2)*  
*Maintainer: [fbaldassarri](https://github.com/fbaldassarri)*  
*Repository: https://github.com/fbaldassarri/exfat-sanitizer*
