# exfat-sanitizer — Deep Dive Documentation

| Field | Value |
|-------|-------|
| **File** | `DOCUMENTATION.md` |
| **Applies To** | `exfat-sanitizer-v12.1.4.sh` |
| **Version** | 12.1.4 |
| **Repository** | [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer) |
| **Status** | Production-Ready — Bug Fix Release |

---

## 1. Introduction

This document provides a deep technical and conceptual dive into exfat-sanitizer v12.1.4, beyond what is covered in README.md and QUICK_START_GUIDE.md. It is intended for:

- **Developers** who want to understand or extend the script
- **Power users** who want to tune behavior deeply
- **Contributors** preparing pull requests
- **Future maintainers** picking up the project
- **Technical auditors** evaluating the tool

If you just want to use the tool, start with:
1. [README.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/README.md) — Overview and feature list
2. [QUICK_START_GUIDE.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/QUICK_START_GUIDE.md) — Getting started guide
3. [RELEASE-v12.1.4.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/RELEASE-v12.1.4.md) — Release notes
4. [CHANGELOG-v12.1.4.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/CHANGELOG-v12.1.4.md) — Version history

This document assumes familiarity with bash, filesystems, Unicode, and command-line workflows.

---

## 2. Conceptual Model

### 2.1 Problem Space

Modern workflows regularly move data across:
- **macOS** — APFS, HFS+
- **Windows** — NTFS, legacy FAT32
- **Linux** — ext4, xfs, btrfs, etc.
- **Removable media** — exFAT, FAT32
- **Network shares** — SMB/CIFS, NFS

Each filesystem has differing rules for:
- **Allowed characters** — What characters are legal in filenames
- **Unicode support** — How Unicode is stored (UTF-8, UTF-16LE, normalization)
- **Reserved filenames** — Names with special meanings (Windows DOS names)
- **Path length limits** — Maximum path and filename lengths
- **Case sensitivity** — Case-preserving vs case-insensitive

As a result, filenames valid in one environment may:
- Fail to copy or sync (silently)
- Be rejected with cryptic error messages
- Break backup tools and workflows
- Fail in media players, DAWs, or other applications
- Lose accented characters during transfer

### 2.2 The Unicode Challenge

#### FAT32/exFAT Unicode Support

Modern FAT32 and exFAT support Unicode via Long Filename (LFN) stored as UTF-16LE:
- **Short Filename (SFN):** 8.3 format, ASCII-only (legacy DOS)
- **Long Filename (LFN):** Up to 255 characters, stored as UTF-16LE

This means FAT32/exFAT **fully support** accented characters:
- French: à, â, ç, é, è, ê, ë, ï, î, ô, ù, û
- Italian: à, è, é, ì, ò, ù
- Spanish: á, é, í, ó, ú, ñ, ü
- German: ä, ö, ü, ß
- Portuguese: ã, õ, á, é, ó, â, ê, ô

#### NFD vs NFC Normalization (v12.1.3+ Fix)

macOS stores filenames in **NFD** (Normalized Form Decomposed) where `ò` = `o` + combining grave accent (2 code points). Windows and Linux use **NFC** (Normalized Form Composed) where `ò` = single code point. Without normalization before comparison:

```
NFD "ò" (from macOS disk) ≠ NFC "ò" (from sanitization) → FALSE POSITIVE RENAME
```

v12.1.4 normalizes both the original and sanitized names to NFC before comparison, preventing false `RENAMED` status.

#### v12.1.4 Conditional Logic Fix

v12.1.3 had an inverted `if/else` in `sanitize_filename()` where legal characters entered the replacement branch. v12.1.4 adds the `!` (NOT) operator to correct character classification.

### 2.3 Core Solution

exfat-sanitizer solves cross-platform filename issues by:

1. Scanning a directory tree recursively
2. Evaluating each filename against selected filesystem rules
3. Preserving Unicode/accented characters (v12.x feature)
4. Normalizing apostrophes safely (v12.1.2 fix)
5. Normalizing NFD→NFC for consistent comparison (v12.1.3+ fix)
6. Classifying characters correctly via fixed conditional logic (v12.1.4 fix)
7. Sanitizing illegal characters only (configurable strictness)
8. Recording all decisions in detailed CSV logs
9. Optionally copying sanitized data to new destinations with conflict resolution

### 2.4 Core Principles

1. **Safety** — Default to preview mode (`DRY_RUN=true`); never delete any file; provide complete audit logs (CSV); preserve Unicode characters
2. **Correctness** — Filesystem-aware character rules; Unicode-safe operations (Python 3 required); explicit Unicode code point handling; NFD→NFC normalization
3. **Predictability** — Same input + same options = same output; mode- and filesystem-specific behavior clearly defined; deterministic renaming logic
4. **Transparency** — CSV logs show what changed, why, and where; summary statistics printed to console; tree export option for structure visualization; `DEBUG_UNICODE` mode for normalization diagnostics

---

## 3. Architecture Overview

### 3.1 Execution Flow

```
1. Initialization
   ├── Validate inputs (FILESYSTEM, SANITIZATION_MODE, etc.)
   ├── Check dependencies (Python 3, Perl, etc.)
   ├── Initialize counters and temp files
   ├── Create CSV log file
   └── Set up trap for cleanup

2. Optional: Tree Generation
   └── Generate pre-sanitization tree snapshot (tree_*.csv)

3. Recursive Item Processing
   └── For each item (directories and files):
       ├── Skip system files (should_skip_system_file)
       ├── Check ignore patterns (should_ignore)
       ├── Normalize to NFC (normalize_unicode) ← v12.1.3+
       ├── Sanitize filename (sanitize_filename)
       │   ├── Extract UTF-8 characters (Python 3)
       │   ├── Normalize apostrophes (Python 3)
       │   ├── Check each character against filesystem rules
       │   │   └── if ! is_illegal_char → PRESERVE ← v12.1.4 fix
       │   ├── Check shell safety (optional)
       │   ├── Check Unicode exploits (optional)
       │   ├── Remove leading/trailing spaces and dots
       │   └── Handle reserved names (FAT32/universal)
       ├── Compare NFC(original) vs NFC(sanitized) ← v12.1.3+
       ├── DEBUG_UNICODE output (optional) ← v12.1.3+
       ├── Rename if DRY_RUN=false, or log
       └── Copy if COPY_TO set

4. Summary & Cleanup
   ├── Print statistics
   ├── Close CSV log
   └── Cleanup temp files (trap)
```

### 3.2 Key Dependencies

**Required:**
- **Bash 4.0+** — associative arrays, `set -o pipefail`
- **Python 3.6+** — UTF-8 character extraction, apostrophe normalization, Unicode normalization
- **Standard Unix tools** — `find`, `sed`, `grep`, `awk`, `mv`, `cp`

**Why Python 3 is required (since v12.1.2):**

Two critical functions require Unicode-aware string handling:

1. `extract_utf8_chars()` — Safely extracts UTF-8 characters from filenames:
   ```python
   text = sys.stdin.read().strip()
   for c in text:
       print(c)  # Each Unicode character, not byte
   ```

2. `normalize_apostrophes()` — Normalizes curly apostrophes without corrupting UTF-8:
   ```python
   replacements = {
       '\u2018': "'",  # LEFT SINGLE QUOTATION MARK
       '\u2019': "'",  # RIGHT SINGLE QUOTATION MARK
       '\u201A': "'",  # SINGLE LOW-9 QUOTATION MARK
       '\u02BC': "'",  # MODIFIER LETTER APOSTROPHE
   }
   ```

3. `normalize_unicode()` — NFD→NFC normalization:
   ```python
   import unicodedata
   print(unicodedata.normalize('NFC', text))
   ```

**Fallback chain** (for `normalize_unicode`): Python 3 → uconv (ICU tools) → Perl (`Unicode::Normalize`) → iconv

---

## 4. Filesystem Modes & Character Rules

### 4.1 Filesystem Types

`FILESYSTEM` controls which ruleset is applied:

| Filesystem | Description | Path Limit | Unicode | File Size Limit |
|------------|-------------|------------|---------|-----------------|
| `fat32` | Legacy removable media | 260 chars | Via LFN (UTF-16LE) | 4GB max |
| `exfat` | Modern removable media | 260 chars | Full UTF-16 | No limit |
| `ntfs` | Windows NTFS | 255 chars | Full UTF-16 | No limit |
| `apfs` | macOS APFS | 255 chars | Full (NFD) | No limit |
| `hfsplus` | Legacy macOS | 255 chars | UTF-16 (NFD) | No limit |
| `universal` | Maximum compatibility | 260 chars | Most restrictive | N/A |

### 4.2 Character Rules by Filesystem

#### Universal Forbidden Characters (ALL modes)

```
" * / : < > ? \ | NUL
```

These characters are never allowed in any filesystem mode.

#### FAT32/exFAT Specifics

- Forbidden: `" * / : < > ? \ |` and control characters (0x00–0x1F, 0x7F)
- Unicode: via LFN — Long Filename stored as UTF-16LE, supports full Unicode range, up to 255 UTF-16 code units
- Preserves all accented characters: Loïc, Révérence, Cè di più, Café

#### NTFS Specifics

- Forbidden: `" * / : < > ? \ | NUL` and control characters (0x00–0x1F, 0x7F)
- Unicode: native UTF-16LE storage, full Unicode support
- Case-insensitive, case-preserving

#### APFS Specifics

- Forbidden: minimal set (`:` and `/`)
- Unicode: NFD normalized (decomposed) — `è` stored as `e` + combining accent
- Full Unicode support, case-insensitive or case-sensitive (depends on volume)
- The script handles NFC↔NFD conversion via `normalize_unicode()`

#### HFS+ Specifics

- Forbidden: colon (replaced with alternate)
- Unicode: UTF-16 storage, NFD normalized (like APFS)

#### Universal Mode

- Most restrictive ruleset (union of all filesystem forbidden characters)
- Works on ANY filesystem
- Still preserves Unicode and accents

### 4.3 Path Length Semantics

| Filesystem | Path Limit | Reason |
|------------|-----------|--------|
| `fat32` | 260 chars | Windows MAX_PATH compatibility |
| `exfat` | 260 chars | Windows MAX_PATH compatibility |
| `ntfs` | 255 chars | NTFS native limit |
| `apfs` | 255 chars | macOS native limit |
| `hfsplus` | 255 chars | Legacy macOS limit |
| `universal` | 260 chars | Most restrictive |

Path limits are conservative for cross-platform compatibility, ensuring compatibility with Windows tools and backup/sync utilities that still assume 260-character MAX_PATH.

---

## 5. Unicode Handling Architecture (v12.x)

### 5.1 The Unicode Stack

```
Input Filename (potentially NFD or NFC)
    │
    ▼
extract_utf8_chars()        ← Python 3: UTF-8 safe extraction
    │
    ▼
sanitize_filename()         ← Bash + Python: Remove illegal characters only
    │   └── is_illegal_char()   ← Fixed in v12.1.4: ! NOT operator
    │
    ▼
normalize_apostrophes()     ← Python 3 (v12.1.2 FIX): Safe Unicode-aware
    │
    ▼
normalize_unicode()         ← Python 3 / uconv / Perl: NFD → NFC conversion
    │
    ▼
Output Filename (NFC normalized, Unicode preserved)
```

### 5.2 Key Functions

#### `extract_utf8_chars(text)` — Python 3

**Purpose:** Safely extract UTF-8 characters from potentially mixed-encoding input.

```python
import sys
text = sys.stdin.read().strip()
try:
    text.encode('utf-8')
    for c in text:
        print(c)
except UnicodeEncodeError:
    sys.exit(1)
```

**Why needed:** Bash string operations can corrupt multi-byte UTF-8. Python handles UTF-8 natively.

**Fallback chain:** Python 3 → Perl (`-CSD -ne 'print for split //'`) → `grep -o .` (WARNING: may break UTF-8)

#### `normalize_apostrophes(text)` — Python 3 (v12.1.2 Fix)

**Purpose:** Normalize curly apostrophes to straight apostrophes without corrupting UTF-8.

**The Bug (v12.1.1 and earlier):**

```bash
# BROKEN: Bash glob pattern corrupted UTF-8
text="${text//'/\'}"
# Result: "Loïc" → "Loic" (accent stripped!)
```

**The Fix (v12.1.2+):**

```python
replacements = {
    '\u2018': "'",  # LEFT SINGLE QUOTATION MARK
    '\u2019': "'",  # RIGHT SINGLE QUOTATION MARK
    '\u201A': "'",  # SINGLE LOW-9 QUOTATION MARK
    '\u02BC': "'",  # MODIFIER LETTER APOSTROPHE
}
for old, new in replacements.items():
    text = text.replace(old, new)
```

**Why this works:** Uses explicit Unicode code points (U+2018 not `'`); Python's `.replace()` is UTF-8 safe; character-by-character replacement with no glob pattern ambiguity.

**Fallback:** If Python unavailable, skip normalization entirely (preserve curly apostrophes rather than corrupt).

#### `normalize_unicode(text)` — Multiple Backends (v12.1.3+)

**Purpose:** Convert NFD (macOS decomposed) to NFC (Windows/Linux composed).

**Backends (priority order):**

1. **Python 3** (preferred):
   ```python
   import unicodedata
   print(unicodedata.normalize('NFC', text))
   ```

2. **uconv** (ICU tools):
   ```bash
   echo "$text" | uconv -f UTF-8 -t UTF-8 -x NFC
   ```

3. **Perl** (fallback):
   ```perl
   use Unicode::Normalize;
   print NFC($text);
   ```

4. **iconv** (last resort — doesn't normalize but preserves UTF-8):
   ```bash
   echo "$text" | iconv -f UTF-8 -t UTF-8
   ```

**Why needed:** macOS stores `è` as `e` + combining accent (NFD). Windows/Linux store `è` as single code point (NFC). Without normalization, identical-looking filenames compare as different.

#### `is_illegal_char(char, illegal_chars)` — Bash

**Purpose:** Check whether a character is illegal for the target filesystem.

**v12.1.4 Fix:** The conditional logic was inverted in v12.1.3:

```bash
# BEFORE (v12.1.3) — BUGGY
if is_illegal_char "$char" "$illegal_chars"; then
    sanitized="${sanitized}${REPLACEMENT_CHAR}"  # Legal chars went here!
else
    sanitized="$sanitized$char"                  # Illegal chars went here!
fi

# AFTER (v12.1.4) — FIXED
if ! is_illegal_char "$char" "$illegal_chars"; then
    sanitized="$sanitized$char"                  # Legal chars preserved ✅
else
    sanitized="${sanitized}${REPLACEMENT_CHAR}"   # Illegal chars replaced ✅
fi
```

**Implementation:** Uses explicit `case` statement to check each illegal character, returning 0 (true/illegal) or 1 (false/legal).

### 5.3 Configuration Variables (v12.x)

| Variable | Default | Description |
|----------|---------|-------------|
| `PRESERVE_UNICODE` | `true` | Preserve all Unicode characters |
| `NORMALIZE_APOSTROPHES` | `true` | Normalize curly apostrophes (v12.1.2 FIXED) |
| `EXTENDED_CHARSET` | `true` | Allow extended character sets |
| `DEBUG_UNICODE` | `false` | NFD/NFC diagnostic output to stderr (v12.1.3+) |

### 5.4 DEBUG_UNICODE Mode (v12.1.3+)

When `DEBUG_UNICODE=true`, the script prints diagnostic output to stderr for every item processed:

```bash
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music 2>debug.log
```

Output format:

```
DEBUG: Original: 'Ce la farò.wav' → NFC: 'Ce la farò.wav'
DEBUG: Sanitized: 'Ce la farò.wav' → NFC: 'Ce la farò.wav'
DEBUG: MISMATCH DETECTED
```

This is invaluable for diagnosing false `RENAMED` status on macOS where NFD/NFC differences may cause string comparison mismatches.

---

## 6. Sanitization Modes & Pipeline

### 6.1 Sanitization Modes

`SANITIZATION_MODE` defines how aggressively names are modified:

#### `conservative` (RECOMMENDED DEFAULT)

- Removes only officially forbidden characters per filesystem
- Preserves apostrophes, accents, Unicode, spaces
- Removes `" * / : < > ? \ |` (universal forbidden)
- Best for: Music libraries, documents, general use

```
Café del Mar.mp3       → unchanged ✅
L'interprète.flac      → unchanged ✅
song<test>.mp3         → song_test_.mp3
```

#### `strict` (MAXIMUM SAFETY)

- Removes all problematic characters including control chars
- Adds extra safety checks
- Preserves accents and Unicode (only removes control/dangerous chars)
- Best for: Untrusted sources, automation scripts

```
Café.mp3               → unchanged ✅
file$(cmd).txt         → file__cmd_.txt (shell chars removed)
```

#### `permissive` (MINIMAL CHANGES)

- Removes only universal forbidden characters
- Fastest, least invasive
- Best for: Speed-optimized workflows

### 6.2 Sanitization Pipeline

The `sanitize_filename()` function implements a multi-stage pipeline:

```
Input: "Loïc Nottet's Song<Test>2024.flac"

Stage 1:  Extract UTF-8 characters (Python 3)
          "Loïc Nottet's Song<Test>2024.flac"

Stage 2:  Character-by-character classification (v12.1.4 FIXED)
          For each char:
            if ! is_illegal_char → PRESERVE
            else → REPLACE with REPLACEMENT_CHAR
          "Loïc Nottet's Song_Test_2024.flac"

Stage 3:  Control characters (if strict/NTFS)
          (no control chars in this example)

Stage 4:  Shell metacharacters (if CHECK_SHELL_SAFETY=true)
          (apostrophe preserved in conservative mode)

Stage 5:  Unicode exploits (if CHECK_UNICODE_EXPLOITS=true)
          (no zero-width chars in this example)

Stage 6:  Normalize apostrophes (Python 3, v12.1.2+)
          "Loïc Nottet's Song_Test_2024.flac"
          (curly→straight if applicable)

Stage 7:  Leading/trailing cleanup
          (remove leading/trailing spaces and dots)

Stage 8:  Reserved names (Windows/DOS)
          (not a reserved name)

Output: "Loïc Nottet's Song_Test_2024.flac"
Status: RENAMED (< and > removed, accents preserved!)
```

### 6.3 Character Replacement

Default replacement character: underscore (`_`). Configurable via `REPLACEMENT_CHAR`.

```bash
REPLACEMENT_CHAR=_   → song<test>.mp3 → song_test_.mp3
REPLACEMENT_CHAR=-   → song<test>.mp3 → song-test-.mp3
REPLACEMENT_CHAR=" " → song<test>.mp3 → song test .mp3
```

### 6.4 Reserved Names (Windows/DOS)

Windows reserves certain filenames for legacy DOS devices: `CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`.

Handling: Append `_reserved` suffix.

```
CON.txt    → CON_reserved.txt
LPT1.log   → LPT1_reserved.log
normal.txt → normal.txt (unchanged)
```

Applied in `fat32`, `ntfs`, and `universal` modes.

---

## 7. System File Filtering

### 7.1 Rationale

Filesystem roots often contain system files that should never be touched:
- `.DS_Store` — macOS Finder metadata
- `Thumbs.db` — Windows thumbnail cache
- `.Spotlight-V100` — macOS Spotlight index
- `.stfolder`, `.stignore` — Syncthing
- `.sync.ffs_db`, `.sync.ffsdb` — FreeFileSync
- `.gitignore` — Git

Processing these files clutters logs with noise, risks breaking tools that expect them, and serves no user purpose.

### 7.2 Implementation

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

System files are invisible to the sanitizer — not even logged to CSV. Processing is ~5–10% faster as a result.

---

## 8. Ignore Patterns

### 8.1 Purpose

User-defined patterns to exclude specific files, directories, or glob patterns from processing.

### 8.2 Implementation

```bash
should_ignore() {
    local file="$1"
    local patternfile="$2"

    if [[ ! -f "$patternfile" ]]; then return 1; fi

    local pattern
    while IFS= read -r pattern; do
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue  # Skip comments
        [[ -z "$pattern" ]] && continue                   # Skip empty lines
        pattern=$(echo "$pattern" | sed 's/[[:space:]]*$//')
        if [[ "$file" == *"$pattern"* ]]; then
            return 0  # Match — ignore this item
        fi
    done < "$patternfile"
    return 1  # No match
}
```

### 8.3 Example Ignore File

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

# Custom
*.tmp
*.bak
NOTE.txt
.fseventsd
```

A ready-to-use example file is included: [`exfat-sanitizer-ignore.example.txt`](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/exfat-sanitizer-ignore.example.txt)

Items matching ignore patterns are logged with `IGNORED` status in the CSV and are not processed.

---

## 9. Directory Processing Strategy

### 9.1 Bottom-Up Renaming

Directory renaming must be done bottom-up to avoid path breakage. If parent directories are renamed first, all child paths become invalid.

```
Original structure:
Music/Bad<Dir>/Sub*Dir/file.mp3

Bottom-up processing order:
1. Music/Bad<Dir>/Sub*Dir → Music/Bad<Dir>/Sub_Dir
2. Music/Bad<Dir>         → Music/Bad_Dir
3. Music/                 → Music/ (no change)

Final structure:
Music/Bad_Dir/Sub_Dir/file.mp3
```

### 9.2 Directory Processing Loop

For each directory:
1. Skip if system directory (`should_skip_system_file`)
2. Skip if matches ignore pattern (`should_ignore`)
3. Normalize name to NFC (`normalize_unicode`) ← v12.1.3+
4. Sanitize dirname via `sanitize_filename()`
5. Normalize sanitized name to NFC ← v12.1.3+
6. Compare NFC(original) vs NFC(sanitized) — prevents NFD/NFC false positives
7. Optional `DEBUG_UNICODE` output ← v12.1.3+
8. Copy if `COPY_TO` set
9. Branch based on `DRY_RUN`:
   - `DRY_RUN=true` → Log only, no `mv`
   - `DRY_RUN=false` → `mv` directory, log result
10. Log to CSV with status (`LOGGED`, `RENAMED`, `FAILED`)
11. Recurse into children

### 9.3 Collision Detection

**Problem:** Two distinct names might sanitize to the same result.

```
Song<Test>.mp3  → Song_Test_.mp3
Song?Test?.mp3  → Song_Test_.mp3   ← COLLISION!
```

**Solution:** Path registration via temp file.

```bash
USEDPATHSFILE="$TEMPCOUNTERDIR/usedpaths.txt"

is_path_used() { grep -Fxq "$1" "$USEDPATHSFILE" 2>/dev/null; }
register_path() { echo "$1" >> "$USEDPATHSFILE"; }
```

The second file with a collision gets `FAILED` status — never silently clobbered.

---

## 10. File Processing Strategy

### 10.1 Processing Loop

For files, the script:
1. Walks using `find -type f` (null-terminated for binary safety)
2. For each file:
   - Skip if system file
   - Skip if matches ignore pattern
   - Normalize to NFC, sanitize, normalize sanitized to NFC
   - Compare NFC(original) vs NFC(sanitized)
   - Check path length
   - Branch based on `DRY_RUN` and `COPY_TO`
3. Log to CSV with detailed status

### 10.2 Copy Mode Architecture

`COPY_TO` enables non-destructive copying with sanitization:
- Source tree remains untouched
- Destination tree has sanitized names
- Conflict resolution options
- Directory structure created automatically

#### `handle_file_conflict(dest_file, behavior)`

| Behavior | Action |
|----------|--------|
| `skip` (default) | Keep existing file — return 1 (skip copy) |
| `overwrite` | Replace existing file — `rm -f` then copy |
| `version` | Create versioned copy — `file-v1.ext`, `file-v2.ext` |

Version example:
```
1st run: song.mp3 → /Volumes/Backup/song.mp3
2nd run: song.mp3 → /Volumes/Backup/song-v1.mp3
3rd run: song.mp3 → /Volumes/Backup/song-v2.mp3
```

#### `copy_file(source, destdir, destfilename, behavior)`

- Creates destination directory if needed (`mkdir -p`)
- Handles conflicts per `COPY_BEHAVIOR`
- Uses `cp` for the actual copy operation
- Logs copy status to CSV
- Returns success/failure

### 10.3 CSV Status Fields

**Status column** (rename processing):
- `LOGGED` — No rename needed (compliant filename)
- `RENAMED` — File was renamed (illegal characters found)
- `IGNORED` — File matched ignore pattern
- `FAILED` — Rename failed (permissions, collision, path too long)

**Copy Status column** (copy processing):
- `COPIED` — Successfully copied to destination
- `SKIPPED` — Copy skipped due to conflict (`COPY_BEHAVIOR=skip`)
- `FAILED` — Copy failed (IO or permission error)
- `NA` — Copy mode not in use (`COPY_TO` not set)

---

## 11. Tree Generation (v12.1.0+)

### 11.1 Purpose

`GENERATE_TREE=true` creates a CSV snapshot of the directory structure before processing. Use cases: compare before/after sanitization, document library structure, audit file organization, generate manifests.

### 11.2 Implementation

```bash
generate_tree_snapshot() {
    local targetdir="$1"
    local outputfile="tree_${FILESYSTEM}_$(date +%Y%m%d_%H%M%S).csv"
    echo "Type|Name|Path|Depth" > "$outputfile"

    process_tree_recursive() {
        local currentpath="$1"
        local depth="${2:-0}"
        local item
        for item in "$currentpath"/*; do
            [[ ! -e "$item" ]] && continue
            local name=$(basename "$item")
            should_skip_system_file "$name" && continue
            local relativepath="${item#$targetdir/}"
            if [[ -d "$item" ]]; then
                echo "Directory|$name|$relativepath|$depth" >> "$outputfile"
                process_tree_recursive "$item" $((depth + 1))
            else
                echo "File|$name|$relativepath|$depth" >> "$outputfile"
            fi
        done
    }

    process_tree_recursive "$targetdir" 0
    echo "$outputfile"
}
```

### 11.3 Tree CSV Format

```csv
Type|Name|Path|Depth
Directory|Loïc Nottet|Loïc Nottet|0
Directory|2015 Rhythm Inside|Loïc Nottet/2015 Rhythm Inside|1
File|01 Rhythm Inside.flac|Loïc Nottet/2015 Rhythm Inside/01 Rhythm Inside.flac|2
```

### 11.4 Workflow: Before/After Comparison

```bash
# Before sanitization
FILESYSTEM=fat32 GENERATE_TREE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music
# Generates: tree_fat32_20260217_120000.csv (before)

# After sanitization
FILESYSTEM=fat32 GENERATE_TREE=true DRY_RUN=false ./exfat-sanitizer-v12.1.4.sh ~/Music
# Generates: tree_fat32_20260217_120100.csv (after)

# Compare
diff tree_fat32_20260217_120000.csv tree_fat32_20260217_120100.csv
```

---

## 12. Counters, Temp Files & Traps

### 12.1 Why Temp Counters?

Bash pipelines and subshells make shared variables difficult. Variables in subshells don't propagate to parent; pipelines spawn subshells. Solution: use temp files as counter stores.

```bash
# Problem:
count=0
find . -type f | while read file; do
    count=$((count + 1))
done
echo $count  # Always prints 0! (subshell isolation)

# Solution:
echo 0 > /tmp/count
find . -type f | while read file; do
    echo $(( $(cat /tmp/count) + 1 )) > /tmp/count
done
cat /tmp/count  # Correct count
```

### 12.2 Counter Lifecycle

**Initialization:** Create temp directory with `mktemp -d`, initialize counters (scanned_dirs, scanned_files, renamed_dirs, renamed_files, etc.) to 0.

**Cleanup:** `trap cleanup_temp_counters EXIT` ensures temp files are removed even on errors or `Ctrl+C`.

### 12.3 Used Paths File

Tracks claimed paths to detect collisions:

```bash
USEDPATHSFILE="$TEMPCOUNTERDIR/usedpaths.txt"
register_path() { echo "$1" >> "$USEDPATHSFILE"; }
is_path_used() { grep -Fxq "$1" "$USEDPATHSFILE" 2>/dev/null; }
```

Prevents two distinct filenames that sanitize to the same result from clobbering each other.

---

## 13. CSV Logging & Exports

### 13.1 Main CSV Log

Filename pattern: `sanitizer_<filesystem>_<YYYYMMDD_HHMMSS>.csv`

Columns:
1. **Type** — `File` or `Directory`
2. **Old Name** — Original filename
3. **New Name** — Sanitized filename (may equal Old Name)
4. **Issues** — Comma-separated issue flags
5. **Path** — Parent directory path
6. **Path Length** — Character count of full new path
7. **Status** — `LOGGED`, `RENAMED`, `IGNORED`, or `FAILED`
8. **Copy Status** — `COPIED`, `SKIPPED`, `FAILED`, or `NA`
9. **Ignore Pattern** — Pattern matched, or `-`

**Issue flags:**
- `IllegalChar` — Universal forbidden characters found
- `FAT32Specific` — FAT32-specific forbidden characters
- `ControlChar` — Control characters found
- `ShellDangerous` — Shell metacharacters found
- `ZeroWidth` — Zero-width characters found
- `ReservedName` — Windows reserved name
- `PathTooLong` — Path exceeds length limit

**Example:**

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|Loïc Nottet.flac|Loïc Nottet.flac|-|Music/|45|LOGGED|NA|-
File|Song<test>.mp3|Song_test_.mp3|IllegalChar|Music/|47|RENAMED|COPIED|-
Directory|Bad:Dir|Bad_Dir|IllegalChar|Music/|40|RENAMED|NA|-
```

### 13.2 CSV Escaping

- Fields separated by pipe (`|`)
- Double quotes in data are doubled
- Newlines removed during sanitization
- Null bytes removed

### 13.3 Log File Location

Created in the current working directory where the script is run:

```bash
pwd  # /Users/username
./exfat-sanitizer-v12.1.4.sh ~/Music
# Creates: /Users/username/sanitizer_fat32_20260217_123456.csv
```

---

## 14. Error Handling Strategy

### 14.1 Philosophy

1. Fail fast on configuration errors (invalid `FILESYSTEM`, etc.)
2. Never silently ignore rename failures
3. Log all problems to CSV
4. Provide summary statistics
5. Graceful degradation (Python 3 unavailable? Warn but continue)

### 14.2 Input Validation

`check_dependencies()` validates:
- Python 3 available (REQUIRED — aborts if missing)
- Perl available (optional fallback — warns if missing)
- Target directory exists and is readable

On validation failure: clear error message to stderr, exit with non-zero status, no files are touched.

### 14.3 Operation-Level Errors

| Category | Handling |
|----------|----------|
| Permission errors | Log `FAILED` status, continue with next item |
| Collision errors | Log `FAILED` status with collision note |
| Path length errors | Log `FAILED` with `PathTooLong` issue flag |
| IO errors (disk full, etc.) | Log `FAILED`, continue |

### 14.4 Python 3 Dependency Check

```bash
if ! command -v python3 &>/dev/null && ! command -v perl &>/dev/null; then
    echo "ERROR: UTF-8 character extraction requires Python3 or Perl" >&2
    echo "Aborting to prevent data loss." >&2
    return 1
fi
```

The script **aborts** if neither Python 3 nor Perl is available — preventing silent data corruption.

---

## 15. Security Considerations

### 15.1 Shell Safety Mode

Enabled via `CHECK_SHELL_SAFETY=true`. Removes dangerous shell metacharacters: `$`, `` ` ``, `&`, `;`, `#`, `~`, `^`, `!`, `(`, `)`.

```bash
# Before:
file$(rm -rf /).sh

# After (CHECK_SHELL_SAFETY=true):
file__rm -rf __.sh
```

**When to use:** Processing files from internet, email attachments, or untrusted sources; files that will be used in automation scripts.

### 15.2 Unicode Exploit Detection

Enabled via `CHECK_UNICODE_EXPLOITS=true`. Removes zero-width and control characters:

| Character | Unicode | Name |
|-----------|---------|------|
| (invisible) | U+200B | ZERO WIDTH SPACE |
| (invisible) | U+200C | ZERO WIDTH NON-JOINER |
| (invisible) | U+200D | ZERO WIDTH JOINER |
| (invisible) | U+FEFF | ZERO WIDTH NO-BREAK SPACE |

Prevents visual spoofing attacks, hidden characters in filenames, and homograph attacks.

### 15.3 Control Character Stripping

Always active in `strict` mode and NTFS. Removes ASCII control characters (0x00–0x1F) and DEL (0x7F). Prevents terminal escape exploits, log file corruption, and CSV/toolchain breakage.

### 15.4 What the Script NEVER Does

- Never modifies file **contents**
- Never reads file **contents**
- Never **deletes** files or directories
- Never follows symlinks destructively
- Never interprets binary data
- Never executes arbitrary code from filenames

Scope: strictly names and paths only.

---

## 16. Performance Considerations

### 16.1 Bottlenecks

1. `find` traversal on very large trees (>100,000 files)
2. `grep` calls for collision detection (O(n) per check)
3. CSV append operations (file IO per item)
4. Python 3 subprocess calls (~10–20ms process spawn overhead per call)

### 16.2 Current Optimizations

- Null-terminated `find` output (binary-safe)
- System file filtering (early skip before processing)
- Single-pass directory and file walks
- Minimal external process calls

### 16.3 Benchmarks

Test environment: 4,074-item music library

| Operation | Time | Items/sec |
|-----------|------|-----------|
| Full scan (dry-run) | ~15s | ~271 |
| With rename | ~18s | ~226 |
| With copy | ~45s | ~90 |
| Tree generation | ~3s | — |

Scalability: linear with item count. CPU-bound for dry-run; IO-bound for copy operations.

### 16.4 Future Optimization Opportunities

- Parallel processing (`xargs -P` or GNU `parallel`)
- Hash-based collision detection (O(1) lookup)
- Bulk CSV writing (batch inserts)
- Persistent Python interpreter (avoid spawn overhead)

---

## 17. Real-World Usage Patterns

### 17.1 Audio Library Management

```bash
FILESYSTEM=fat32 \
  SANITIZATION_MODE=conservative \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
```

Observations on ~4,074-file library: 0 files renamed (all compliant), all accents preserved (French, Italian artists), only illegal characters (`<`, `>`, `:`, `*`) would be replaced, typical execution time: ~15 seconds.

### 17.2 Cross-Platform Sync

```bash
FILESYSTEM=universal \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/SharedDocs
```

Maximum compatibility — works everywhere, still preserves Unicode/accents, removes only truly problematic characters.

### 17.3 Pre-Backup Validation

```bash
# 1. Generate tree snapshot (before)
FILESYSTEM=exfat GENERATE_TREE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Data

# 2. Review CSV for issues
open sanitizer_exfat_*.csv

# 3. Apply fixes if needed
FILESYSTEM=exfat DRY_RUN=false ./exfat-sanitizer-v12.1.4.sh ~/Data

# 4. Generate tree snapshot (after)
FILESYSTEM=exfat GENERATE_TREE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Data

# 5. Compare snapshots
diff tree_exfat_*_before.csv tree_exfat_*_after.csv
```

### 17.4 Copy with Sanitization

```bash
FILESYSTEM=exfat \
  COPY_TO=/Volumes/2.5ex/Musica/ \
  COPY_BEHAVIOR=skip \
  GENERATE_TREE=true \
  IGNORE_FILE=./exfat-sanitizer-ignore.txt \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.4.sh ~/Music
```

Result: source untouched, destination has sanitized names, tree export for documentation.

### 17.5 Post-Copy AppleDouble Cleanup

After copying to exFAT/FAT32 on macOS, clean up `._` metadata files:

```bash
# Option A: Merge/clean (recommended)
dot_clean -m /Volumes/2.5ex/Musica/

# Option B: Bulk delete
find /Volumes/2.5ex/Musica/ -name '._*' -delete

# Option C: Full cleanup (._ + .DS_Store)
find /Volumes/2.5ex/Musica/ \( -name '._*' -o -name '.DS_Store' \) -delete

# Verify
find /Volumes/2.5ex/Musica/ -name '._*' | wc -l
# Expected: 0
```

---

## 18. macOS AppleDouble (`._`) Files

### 18.1 What They Are

When macOS copies files to non-APFS/HFS+ volumes (exFAT, FAT32, NTFS), it creates `._` (dot-underscore) companion files to store:
- Extended attributes (`xattr`)
- Resource forks
- Finder metadata

Each `._` file is exactly **4,096 bytes** (4KB) and mirrors the real file/folder name:

```
._1997 Elisa - Pipes and Flowers (Album)    ← 4KB metadata sidecar
  1997 Elisa - Pipes and Flowers (Album)    ← Actual directory
```

### 18.2 Why They Appear

The script's `copy_file()` function uses the `cp` command internally. macOS hooks into `cp` to automatically write AppleDouble metadata. This is **OS-level behavior, not a script bug**.

### 18.3 Prevention & Cleanup

| Method | Command | Scope |
|--------|---------|-------|
| Merge/clean | `dot_clean -m /Volumes/DRIVE/` | Per-volume (recommended) |
| Bulk delete | `find /Volumes/DRIVE/ -name '._*' -delete` | Per-volume |
| Full cleanup | `find /Volumes/DRIVE/ \( -name '._*' -o -name '.DS_Store' \) -delete` | Per-volume |
| Prevent on USB | `defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true` | System-wide |
| Prevent on network | `defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true` | System-wide |

System-wide prevention requires logout/restart to take effect. To re-enable:

```bash
defaults delete com.apple.desktopservices DSDontWriteUSBStores
defaults delete com.apple.desktopservices DSDontWriteNetworkStores
```

### 18.4 Future Improvement

A future version may use `cp -X` (strip extended attributes during copy) to prevent `._` file creation at the script level.

---

## 19. Extensibility & Future Directions

### 19.1 Plugin Architecture (Proposed)

Pluggable sanitization pipeline:

```bash
SANITIZER_STEPS="universal,controls,unicode,fs-specific,shell,reserved"
```

Benefits: user-configurable pipeline, third-party extensions, A/B testing of strategies.

### 19.2 Configuration File Support (Proposed)

INI-style configuration:

```ini
# .exfat-sanitizer.conf
[defaults]
FILESYSTEM=fat32
SANITIZATION_MODE=conservative
DRY_RUN=true
PRESERVE_UNICODE=true

[paths]
IGNORE_FILE=.exfat-sanitizer-ignore

[copy]
COPY_BEHAVIOR=version

[security]
CHECK_SHELL_SAFETY=false
CHECK_UNICODE_EXPLOITS=false
```

### 19.3 Undo Functionality (Proposed)

Reverse operations using CSV log:

```bash
./exfat-sanitizer-v12.1.4.sh --undo sanitizer_fat32_20260217_123456.csv
```

Implementation: read CSV in reverse, rename from New→Old for each `RENAMED` entry, validate no conflicts.

### 19.4 Parallel Processing (Proposed)

```bash
PARALLEL_JOBS=4 ./exfat-sanitizer-v12.1.4.sh ~/BigData
```

Challenges: collision detection needs synchronization, counter updates need atomic operations, directory renaming order must be preserved.

### 19.5 Interactive Mode (Proposed)

```bash
./exfat-sanitizer-v12.1.4.sh --interactive ~/Music

# Rename "Song<test>.mp3" → "Song_test_.mp3"? [Y/n/q]
```

### 19.6 Python-Based Sanitization (Planned)

Move the character-by-character iteration from bash into Python to eliminate the UTF-8 byte-splitting issue in the current `extract_utf8_chars` → `while read` pipeline. This would natively handle all multibyte Unicode sequences without corruption risk.

---

## 20. Developer Notes

### 20.1 Code Style

Conventions:
- `snake_case` for function names
- `UPPERCASE` for constants and environment variables
- `readonly` for true constants
- `local` for all function-scope variables
- `set -o pipefail` to fail on pipeline errors

```bash
readonly DEFAULT_FILESYSTEM="fat32"

sanitize_filename() {
    local filename="$1"
    local mode="$2"
    # ... processing
}
```

### 20.2 Testing Strategy

Recommended test categories:

1. **Unit tests** — Individual function testing:
   - `sanitize_filename` input/output pairs
   - `normalize_apostrophes` edge cases
   - `extract_utf8_chars` Unicode handling
   - `is_illegal_char` character classification (v12.1.4 fix)
   - `normalize_unicode` NFD→NFC (v12.1.3+ fix)

2. **Integration tests** — Full tree runs:
   - Empty directories
   - Deep nesting (10+ levels)
   - Large trees (10,000+ items)

3. **Edge case tests:**
   - Filenames with only forbidden characters → `___.txt`
   - Already-reserved names: `CON.txt`
   - Unicode edge cases: NFD vs NFC, combining characters
   - Zero-length filenames
   - Maximum path lengths

4. **Regression tests (v12.1.4 specific):**
   - Accent preservation: `Loïc`, `Révérence`, `Cè di più`
   - Apostrophe normalization: `L'été`
   - Mixed accents and illegal chars: `Café<test>.mp3`
   - NFD filenames from macOS don't trigger false renames
   - Conditional logic: legal chars preserved, illegal chars replaced

### 20.3 Debugging Tips

```bash
# Enable verbose output
bash -x ./exfat-sanitizer-v12.1.4.sh ~/Music 2>&1 | head -100

# Check Python 3 availability
command -v python3 && python3 --version

# Test normalize_apostrophes
python3 << 'EOF'
import sys
text = "Loïc Nottet\u2019s Song"
replacements = {'\u2018': "'", '\u2019': "'"}
for old, new in replacements.items():
    text = text.replace(old, new)
print(text)
EOF

# Test normalize_unicode
python3 -c "
import unicodedata
nfd = 'Cafe\u0300'  # NFD: e + combining grave
nfc = unicodedata.normalize('NFC', nfd)
print(f'NFD: {repr(nfd)} → NFC: {repr(nfc)}')
print(f'Equal: {nfd == nfc}')
"

# Enable DEBUG_UNICODE
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music 2>debug.log
grep "MISMATCH" debug.log
```

### 20.4 Contributing Guidelines

Before submitting a pull request:
1. Test on at least macOS and Linux
2. Verify Python 3 dependency is documented
3. Update version number and CHANGELOG
4. Add tests for new features
5. Document new configuration variables
6. Follow existing code style
7. Preserve backward compatibility when possible

**Pull request template:**

```markdown
## Description
Brief description of change

## Motivation
Why this change is needed

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

## 21. Frequently Asked Questions (Technical)

**Q1: Why Python 3 instead of pure bash?**

Bash string operations are byte-oriented, not character-oriented. They corrupt multi-byte UTF-8 sequences. Python handles Unicode natively and correctly.

```bash
# Bash (BROKEN): byte-level operation
text="Loïc"; echo "${text/ï/i}"  # May corrupt UTF-8

# Python (CORRECT): character-level operation
text = "Loïc"; text = text.replace("ï", "i")  # Works correctly
```

**Q2: Why not use `sed` or `tr` for character replacement?**

`sed` and `tr` are also byte-oriented, not character-oriented. They can corrupt multi-byte UTF-8 sequences.

**Q3: Why use `set -o pipefail`?**

Ensures pipeline errors are caught. Without it, `cmd1 | cmd2` succeeds even if `cmd1` fails.

**Q4: What's the performance impact of Python 3 calls?**

Moderate. Each Python 3 call spawns a subprocess (~10–20ms overhead). For 4,000 files, this adds ~40–80 seconds total. Optimization opportunity: persistent Python interpreter or batch processing.

**Q5: Can I use the script without Python 3?**

Not recommended for v12.1.4. Critical functions (`extract_utf8_chars`, `normalize_apostrophes`, `normalize_unicode`) require Python 3 for Unicode safety. The script aborts if neither Python 3 nor Perl is available.

**Q6: How does NFD/NFC normalization work?**

macOS stores `è` as `e` + combining grave accent (2 code points = NFD). Windows stores `è` as a single code point (NFC). `normalize_unicode()` converts both to NFC so they compare as equal. Without this, every accented file on macOS would show as `RENAMED` (false positive).

**Q7: How does bottom-up directory renaming work?**

1. `find` generates list of all directories
2. Sort in reverse (deepest paths first)
3. Process each directory from deepest to shallowest
4. This ensures child paths are valid when parents are renamed

**Q8: What happens if two files sanitize to the same name?**

The second file gets `FAILED` status and is not renamed. The `is_path_used()` function detects the collision:

```csv
File|song<1>.mp3|song_1_.mp3|IllegalChar|Music/|30|RENAMED|NA|-
File|song?1?.mp3|song_1_.mp3|IllegalChar|Music/|30|FAILED|NA|Collision
```

**Q9: Why use temp files for counters instead of variables?**

Bash pipelines create subshells. Variables modified in subshells don't propagate to the parent shell. Temp files provide a shared state mechanism.

**Q10: Is the script safe for production use?**

Yes, with caveats: always test with `DRY_RUN=true` first; backup critical data before applying changes; review CSV logs carefully; verify Python 3 is installed; test on a subset of data first. The script never deletes files and provides complete audit logs.

**Q11: What about the `._` (AppleDouble) files on exFAT?**

These are created by macOS, not by the script. See [Section 18: macOS AppleDouble Files](#18-macos-appledouble-_-files) for cleanup options.

---

## 22. Glossary

### Technical Terms

| Term | Definition |
|------|-----------|
| **Forbidden Characters** | Characters that a given filesystem does not allow in file or directory names |
| **Reserved Names** | Filenames with special meaning (e.g., Windows DOS device names: CON, PRN, NUL) |
| **Sanitization** | Process of transforming names to conform to filesystem rules |
| **Dry Run** | Preview mode where no actual changes occur — only logs produced |
| **CSV Log** | Pipe-delimited file containing detailed record of operations |
| **Tree Export** | CSV representation of directory hierarchy structure |
| **Shell Metacharacters** | Characters with special meaning to shells (e.g., `$`, `` ` ``, `&`) |
| **Unicode Normalization** | Converting between NFD (decomposed) and NFC (composed) forms |
| **Long Filename (LFN)** | FAT32/exFAT extension supporting UTF-16LE filenames up to 255 chars |
| **NFD** | Normalized Form Decomposed — e.g., `è` = `e` + combining accent |
| **NFC** | Normalized Form Composed — e.g., `è` = single code point |
| **AppleDouble** | macOS `._` companion files storing resource forks and extended attributes |

### Status Values

| Status | Meaning |
|--------|---------|
| `LOGGED` | Item checked, no changes needed (compliant) |
| `RENAMED` | Item was (or will be) renamed (non-compliant) |
| `IGNORED` | Item matched an ignore pattern |
| `FAILED` | Operation failed (collision, permissions, path length) |
| `COPIED` | File successfully copied to destination |
| `SKIPPED` | Copy skipped due to conflict resolution rule |
| `NA` | Not applicable (copy mode not in use) |

---

## 23. Summary

### Key Characteristics

**Technical Excellence:**
- Multi-filesystem aware rules (6 filesystem modes)
- Python 3-based Unicode handling
- Safe apostrophe normalization (v12.1.2 fix)
- Correct character classification logic (v12.1.4 fix)
- NFD→NFC normalization (v12.1.3+ fix)
- Configurable sanitization pipeline
- Rich logging and audit trail

**Safety-First Design:**
- Default dry-run mode
- Never deletes files
- Collision detection
- Complete CSV logs
- Conservative path limits

**Unicode Support (v12.x):**
- Preserves all accented characters
- FAT32 LFN (UTF-16) support documented
- Python 3-based UTF-8 safety
- NFD/NFC normalization
- Explicit Unicode code points
- DEBUG_UNICODE diagnostic mode

**Production Features:**
- System file filtering
- Ignore pattern support
- Copy mode with versioning
- Tree generation
- Error handling and recovery
- AppleDouble cleanup guidance

### Recommended Reading Order

1. [README.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/README.md) — Overview and quick start
2. [QUICK_START_GUIDE.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/QUICK_START_GUIDE.md) — Step-by-step guide
3. [RELEASE-v12.1.4.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/RELEASE-v12.1.4.md) — What's new and critical fixes
4. **DOCUMENTATION.md** (this file) — Deep technical dive
5. [CHANGELOG-v12.1.4.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/CHANGELOG-v12.1.4.md) — Complete version history

---

**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)
**License:** MIT
**Maintainer:** [fbaldassarri](https://github.com/fbaldassarri)
**Version:** 12.1.4 | **Release Date:** February 17, 2026
