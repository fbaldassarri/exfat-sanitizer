# exfat-sanitizer — Deep Dive Documentation

| Field | Value |
|-------|-------|
| **File** | `DOCUMENTATION.md` |
| **Applies To** | `exfat-sanitizer-v12.1.6.sh` |
| **Version** | 12.1.6 |
| **Repository** | [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer) |
| **Status** | Production-Ready — Critical Fix + New Feature Release |

---

## 1. Introduction

This document provides a deep technical and conceptual dive into exfat-sanitizer v12.1.6, beyond what is covered in README.md and QUICK_START_GUIDE.md. It is intended for:

- **Developers** who want to understand or extend the script
- **Power users** who want to tune behavior deeply
- **Contributors** preparing pull requests
- **Future maintainers** picking up the project
- **Technical auditors** evaluating the tool

If you just want to use the tool, start with:
1. [README.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/README.md) — Overview and feature list
2. [QUICK_START_GUIDE.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/QUICK_START_GUIDE.md) — Getting started guide
3. [RELEASE-v12.1.6.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/RELEASE-v12.1.6.md) — Release notes
4. [CHANGELOG-v12.1.6.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/CHANGELOG-v12.1.6.md) — Version history

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
- Italian: à, è, é, ì, ò, ù, È
- Spanish: á, é, í, ó, ú, ñ, ü
- German: ä, ö, ü, ß
- Portuguese: ã, õ, á, é, ó, â, ê, ô

#### NFD vs NFC Normalization (v12.1.3+ Fix)

macOS stores filenames in **NFD** (Normalized Form Decomposed) where `ò` = `o` + combining grave accent (2 code points). Windows and Linux use **NFC** (Normalized Form Composed) where `ò` = single code point. Without normalization before comparison:

```
NFD "ò" (from macOS disk) ≠ NFC "ò" (from sanitization) → FALSE POSITIVE RENAME
```

v12.1.6 normalizes both the original and sanitized names to NFC before comparison, preventing false `RENAMED` status.

#### Bash vs Python: The Fundamental Tension (v12.1.6 Fix)

Bash is byte-oriented. Python is character-oriented. This distinction is the root cause of the critical UTF-8 bug fixed in v12.1.6.

```
Bash pipe processing of È (U+00C8):
  UTF-8 bytes: C3 88
  Bash pipe reads: byte C3 → byte 88 → LOST (neither byte is a valid char alone)

Python processing of È (U+00C8):
  Unicode code point: single character È
  Iteration: for c in text → c = 'È' → PRESERVED ✅
```

Prior to v12.1.6, the `extract_utf8_chars | while IFS= read -r char` pipeline split multibyte sequences on macOS (bash 3.2), silently dropping characters like È, è, à, ì, ò, ù. v12.1.6 moves the entire character-level sanitization into Python, eliminating this class of bugs entirely.

### 2.3 Core Solution

exfat-sanitizer solves cross-platform filename issues by:

1. Scanning a directory tree recursively
2. Evaluating each filename against selected filesystem rules
3. Preserving Unicode/accented characters via Python-based sanitization (v12.1.6)
4. Normalizing apostrophes safely (v12.1.2 fix)
5. Normalizing NFD→NFC for consistent comparison (v12.1.3+ fix)
6. Sanitizing illegal characters only (configurable strictness)
7. Optionally prompting operator for interactive rename decisions (v12.1.6)
8. Recording all decisions in detailed CSV logs
9. Optionally copying sanitized data to new destinations with conflict resolution

### 2.4 Core Principles

1. **Safety** — Default to preview mode (`DRY_RUN=true`); never delete any file; provide complete audit logs (CSV); preserve Unicode characters; interactive mode for operator control
2. **Correctness** — Filesystem-aware character rules; Unicode-safe operations via Python-based pipeline; explicit Unicode code point handling; NFD→NFC normalization
3. **Predictability** — Same input + same options = same output; mode- and filesystem-specific behavior clearly defined; deterministic renaming logic
4. **Transparency** — CSV logs show what changed, why, and where; summary statistics printed to console; tree export option for structure visualization; `DEBUG_UNICODE` mode for normalization diagnostics; interactive mode shows suggested names before applying

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
       │   ├── Normalize apostrophes (Python 3, v12.1.2+)
       │   ├── Python-based single-pass sanitization (v12.1.6) ← NEW
       │   │   ├── Control character detection
       │   │   ├── Shell metacharacter replacement
       │   │   ├── Zero-width Unicode exploit removal
       │   │   ├── Filesystem illegal character replacement
       │   │   └── Leading/trailing space/dot stripping
       │   ├── Bash fallback (if Python unavailable) ← WARNING: may lose UTF-8
       │   └── Handle reserved names (FAT32/universal)
       ├── Compare NFC(original) vs NFC(sanitized) ← v12.1.3+
       ├── DEBUG_UNICODE output (optional) ← v12.1.3+
       ├── Interactive prompt (if INTERACTIVE=true) ← v12.1.6 NEW
       │   ├── Display current + suggested name
       │   ├── Read operator input from /dev/tty
       │   ├── Validate input against filesystem rules
       │   └── Re-prompt if invalid
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
- **Python 3.6+** — Character-level sanitization, apostrophe normalization, Unicode normalization
- **Standard Unix tools** — `find`, `sed`, `grep`, `awk`, `mv`, `cp`

**Why Python 3 is critical (since v12.1.6):**

Three core operations now run in Python:

1. **`sanitize_filename()` core pipeline** — The entire character-level sanitization loop runs as an embedded Python script. All checks (control chars, shell safety, unicode exploits, illegal chars) execute in a single Python pass with native Unicode support:
   ```python
   for c in text:
       cp = ord(c)
       if cp < 32 or cp == 127:  # Control chars
           continue
       if c in illegal_chars:     # Filesystem-specific
           result.append(replacement)
           continue
       result.append(c)           # Legal — PRESERVE
   ```

2. **`normalize_apostrophes()`** — Normalizes curly apostrophes without corrupting UTF-8:
   ```python
   replacements = {
       '\u2018': "'",  # LEFT SINGLE QUOTATION MARK
       '\u2019': "'",  # RIGHT SINGLE QUOTATION MARK
       '\u201A': "'",  # SINGLE LOW-9 QUOTATION MARK
       '\u02BC': "'",  # MODIFIER LETTER APOSTROPHE
   }
   ```

3. **`normalize_unicode()`** — NFD→NFC normalization:
   ```python
   import unicodedata
   print(unicodedata.normalize('NFC', text))
   ```

**Fallback chain** (for `normalize_unicode`): Python 3 → uconv (ICU tools) → Perl (`Unicode::Normalize`) → iconv

### 3.3 Function Map

| Function | Language | Lines | Purpose |
|----------|----------|-------|---------|
| `check_dependencies()` | Bash | 43–88 | Validate Python 3, Perl, target dir |
| `normalize_unicode()` | Bash+Python | 90–136 | NFD→NFC normalization (multi-backend) |
| `should_skip_system_file()` | Bash | 138–152 | Filter .DS_Store, Thumbs.db, etc. |
| `get_illegal_chars()` | Bash | 154–173 | Return illegal chars for filesystem |
| `is_reserved_name()` | Bash | 175–187 | Check Windows reserved names |
| `handle_file_conflict()` | Bash | 189–212 | COPY_TO conflict resolution |
| `copy_file()` | Bash | 214–244 | File copy with conflict handling |
| `generate_tree_snapshot()` | Bash | 246–283 | Directory tree CSV export |
| `should_ignore()` | Bash | 285–340 | Pattern-based file exclusion |
| `normalize_apostrophes()` | Bash+Python | 342–379 | Curly→straight apostrophe (v12.1.2) |
| `is_illegal_char()` | Bash | 381–403 | Character legality check |
| `validate_filename()` | Bash | 405–430 | Validate name against filesystem rules **(v12.1.6 NEW)** |
| `interactive_prompt()` | Bash | 432–491 | Interactive rename dialog **(v12.1.6 NEW)** |
| `sanitize_filename()` | Bash+Python | 493–622 | Core sanitization pipeline **(v12.1.6 REWRITTEN)** |
| `process_directory()` | Bash | 628–740 | Recursive directory processing **(v12.1.6 MODIFIED)** |
| `main()` | Bash | 746+ | Entry point, usage, startup banner |

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
- Preserves all accented characters: Loïc, Révérence, Cè di più, Café, Èssere
- Preserves straight apostrophe `'` (U+0027) — it is **not** an illegal character

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

## 5. Unicode Handling Architecture (v12.1.6)

### 5.1 The Unicode Stack

```
Input Filename (potentially NFD or NFC)
    │
    ▼
normalize_apostrophes()     ← Python 3 (v12.1.2 FIX): Safe Unicode-aware
    │
    ▼
sanitize_filename()         ← Python 3 single-pass pipeline (v12.1.6 REWRITE)
    │   ├── Control character detection (ASCII 0-31, 127)
    │   ├── Shell metacharacter replacement (if CHECK_SHELL_SAFETY)
    │   ├── Zero-width character removal (if CHECK_UNICODE_EXPLOITS)
    │   ├── Filesystem illegal character replacement
    │   └── Leading/trailing space/dot stripping
    │
    ▼
normalize_unicode()         ← Python 3 / uconv / Perl: NFD → NFC conversion
    │
    ▼
[if INTERACTIVE=true]
interactive_prompt()        ← Operator-driven name choice (v12.1.6 NEW)
    │   ├── validate_filename()   ← Input validation (v12.1.6 NEW)
    │   ├── is_reserved_name()    ← Windows reserved name check
    │   └── Empty/whitespace check
    │
    ▼
Output Filename (NFC normalized, Unicode preserved, operator-approved)
```

### 5.2 Key Functions

#### `sanitize_filename(name, mode, filesystem)` — Python Core (v12.1.6 REWRITE)

**Purpose:** Transform a filename to comply with the target filesystem rules while preserving all legal Unicode characters.

**v12.1.6 Architecture Change:**

Prior to v12.1.6, character-level iteration used bash pipes:
```
name → extract_utf8_chars (Python) → bash pipe → while IFS= read -r char → bash if/else
```
This pipeline split multibyte UTF-8 sequences on macOS bash 3.2, silently dropping characters.

v12.1.6 runs the entire character loop in Python:
```
name → Python (single script: all checks in one pass) → sanitized result
```

**Implementation (v12.1.6):**

```python
import sys

text = sys.stdin.read().strip()
illegal_chars = sys.argv[1]
mode = sys.argv[2]
replacement = sys.argv[3]
check_shell_safety = sys.argv[4] == 'true'
check_unicode_exploits = sys.argv[5] == 'true'

shell_dangerous = set('$`&;#~^!()')
zero_width = {'\u200B', '\u200C', '\u200D', '\uFEFF'}

result = []
for c in text:
    cp = ord(c)

    # Control characters
    if cp < 32 or cp == 127:
        if mode == 'strict':
            result.append(replacement)
        continue

    # Shell-dangerous characters
    if check_shell_safety and c in shell_dangerous:
        result.append(replacement)
        continue

    # Zero-width characters
    if check_unicode_exploits and c in zero_width:
        continue

    # Filesystem illegal characters
    if c in illegal_chars:
        if mode in ('strict', 'conservative'):
            result.append(replacement)
        continue

    # Character is legal — PRESERVE IT
    result.append(c)

sanitized = ''.join(result)
sanitized = sanitized.strip(' .')
print(sanitized)
```

**Why this works:**
- Python's `for c in text` iterates over Unicode **code points**, not bytes
- È (U+00C8, UTF-8 bytes C3 88) is a single iteration step `c = 'È'`
- The `in` operator for set/string membership is Unicode-aware
- No pipe, no subshell, no byte splitting — the entire loop runs in one process

**Bash Fallback:**
If Python 3 is unavailable, the script falls back to the old bash-based character loop with a stderr warning. This fallback may exhibit the multibyte UTF-8 loss issue and is provided only for emergency compatibility.

#### `validate_filename(name, filesystem)` — v12.1.6 NEW

**Purpose:** Check a proposed filename against the target filesystem's illegal character set. Returns illegal characters found (if any) and exit code 0 (valid) or 1 (invalid).

```bash
validate_filename() {
    local name="$1"
    local filesystem="$2"
    local illegal_chars=$(get_illegal_chars "$filesystem")
    local found_illegal=""

    while IFS= read -r char; do
        [ -z "$char" ] && continue
        if is_illegal_char "$char" "$illegal_chars"; then
            found_illegal="${found_illegal}${char} "
        fi
    done < <(extract_utf8_chars "$name")

    if [ -n "$found_illegal" ]; then
        echo "$found_illegal"
        return 1
    fi
    return 0
}
```

**Used by:** `interactive_prompt()` to validate operator-provided names before accepting them.

#### `interactive_prompt(original, suggested, type, filesystem)` — v12.1.6 NEW

**Purpose:** Display an interactive rename dialog, read operator input, validate it, and return the chosen name.

```bash
interactive_prompt() {
    local original="$1"
    local suggested="$2"
    local type="$3"
    local filesystem="$4"
    local chosen=""

    while true; do
        echo "" >/dev/tty
        echo "── Interactive Rename ──────────────────────" >/dev/tty
        echo "  Type:      $type" >/dev/tty
        echo "  Current:   $original" >/dev/tty
        echo "  Suggested: $suggested" >/dev/tty
        echo "────────────────────────────────────────────" >/dev/tty
        echo -n "  Enter new name (or press Enter to accept suggested): " >/dev/tty
        IFS= read -r chosen </dev/tty

        if [ -z "$chosen" ]; then
            chosen="$suggested"
        fi

        # Validate against filesystem rules
        local illegal_found
        illegal_found=$(validate_filename "$chosen" "$filesystem")
        if [ $? -ne 0 ]; then
            echo "  ⚠️  Invalid! Illegal characters for $filesystem found: $illegal_found" >/dev/tty
            echo "  Please try again." >/dev/tty
            continue
        fi

        # Check reserved names (FAT32/universal)
        if [ "$filesystem" = "fat32" ] || [ "$filesystem" = "universal" ]; then
            local basename_only="${chosen%.*}"
            if is_reserved_name "$basename_only"; then
                echo "  ⚠️  '$basename_only' is a Windows reserved name" >/dev/tty
                echo "  Please try again." >/dev/tty
                continue
            fi
        fi

        # Check empty/whitespace-only
        local trimmed=$(echo "$chosen" | sed 's/^[[:space:].]*//;s/[[:space:].]*$//')
        if [ -z "$trimmed" ]; then
            echo "  ⚠️  Name cannot be empty or consist only of spaces/dots." >/dev/tty
            echo "  Please try again." >/dev/tty
            continue
        fi

        break
    done

    echo "$chosen"
}
```

**Key design decisions:**

1. **`/dev/tty` for I/O:** Interactive input reads from `/dev/tty` instead of stdin. This avoids conflicts with the script's internal pipelines (`extract_utf8_chars | while read`) which consume stdin. Output also goes to `/dev/tty` to bypass any stdout redirection.

2. **Iterative validation loop:** The `while true` loop ensures the operator cannot submit an invalid name. Each validation failure explains the problem and re-prompts.

3. **Three validation checks:**
   - Filesystem illegal characters (via `validate_filename`)
   - Windows reserved names (CON, PRN, AUX, NUL, COM1–9, LPT1–9)
   - Empty or whitespace/dot-only names

4. **No skip option:** Every flagged item must receive a valid name — either the suggestion (press Enter) or a custom one. This prevents accidental data loss from skipping renames.

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

**Implementation:** Uses explicit `case` statement to check each illegal character, returning 0 (true/illegal) or 1 (false/legal).

**Note:** In v12.1.6, this function is primarily used by `validate_filename()` for interactive mode validation. The main sanitization loop now runs in Python and checks characters directly with `if c in illegal_chars`.

### 5.3 Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PRESERVE_UNICODE` | `true` | Preserve all Unicode characters |
| `NORMALIZE_APOSTROPHES` | `true` | Normalize curly apostrophes (v12.1.2 FIXED) |
| `EXTENDED_CHARSET` | `true` | Allow extended character sets |
| `DEBUG_UNICODE` | `false` | NFD/NFC diagnostic output to stderr (v12.1.3+) |
| `INTERACTIVE` | `false` | Prompt operator for each rename decision (v12.1.6 NEW) |

### 5.4 DEBUG_UNICODE Mode (v12.1.3+)

When `DEBUG_UNICODE=true`, the script prints diagnostic output to stderr for every item processed:

```bash
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v12.1.6.sh ~/Music 2>debug.log
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
dell'Amore.flac        → unchanged ✅  (apostrophe preserved!)
Èssere.flac            → unchanged ✅  (È preserved!)
song<test>.mp3         → song_test_.mp3
```

#### `strict` (MAXIMUM SAFETY)

- Removes all problematic characters including control chars (replaced, not dropped)
- Adds extra safety checks
- Preserves accents and Unicode (only removes control/dangerous chars)
- Best for: Untrusted sources, automation scripts

```
Café.mp3               → unchanged ✅
file$(cmd).txt         → file__cmd_.txt (shell chars removed)
```

#### `permissive` (MINIMAL CHANGES)

- Removes only universal forbidden characters (dropped, not replaced)
- Fastest, least invasive
- Best for: Speed-optimized workflows

### 6.2 Sanitization Pipeline (v12.1.6)

The `sanitize_filename()` function implements a Python-based single-pass pipeline:

```
Input: "Loïc Nottet's Song<Test>2024.flac"

Stage 1:  Normalize apostrophes (Python 3, v12.1.2+)
          "Loïc Nottet's Song<Test>2024.flac"
          (curly→straight if applicable; straight apostrophe preserved)

Stage 2:  Python single-pass character classification (v12.1.6 REWRITE)
          For each Unicode code point:
            if control char (0-31, 127) → drop (or replace in strict)
            if shell dangerous & CHECK_SHELL_SAFETY → replace
            if zero-width & CHECK_UNICODE_EXPLOITS → drop
            if in filesystem illegal_chars → replace (or drop in permissive)
            else → PRESERVE
          "Loïc Nottet's Song_Test_2024.flac"

Stage 3:  Leading/trailing cleanup
          (remove leading/trailing spaces and dots)

Stage 4:  Reserved names (Windows/DOS)
          (not a reserved name)

Stage 5:  [If INTERACTIVE=true] Interactive prompt (v12.1.6 NEW)
          Operator reviews and accepts/modifies the suggested name

Output: "Loïc Nottet's Song_Test_2024.flac"
Status: RENAMED (< and > removed, accents + apostrophe preserved!)
```

**Key difference from v12.1.4:** Stages 1–3 previously ran as separate bash loops with Python subprocesses for character extraction. In v12.1.6, stages 2–3 run as a single embedded Python script, eliminating the bash pipe that caused multibyte character loss.

### 6.3 Character Replacement

Default replacement character: underscore (`_`). Configurable via `REPLACEMENT_CHAR`.

```bash
REPLACEMENT_CHAR=_   → song<test>.mp3 → song_test_.mp3
REPLACEMENT_CHAR=-   → song<test>.mp3 → song-test-.mp3
REPLACEMENT_CHAR=" " → song<test>.mp3 → song test .mp3
```

### 6.4 Reserved Names (Windows/DOS)

Windows reserves certain filenames for legacy DOS devices: `CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`.

Handling: Prepend `_` prefix.

```
CON.txt    → _CON.txt
LPT1.log   → _LPT1.log
normal.txt → normal.txt (unchanged)
```

Applied in `fat32`, `ntfs`, and `universal` modes. In interactive mode, reserved names typed by the operator are also rejected with a re-prompt.

---

## 7. Interactive Mode Architecture (v12.1.6)

### 7.1 Design Goals

Interactive mode addresses the need for operator control in scenarios where automatic renaming may not produce the preferred result. The operator sees both the current name and the auto-suggested replacement, and can accept or override the suggestion.

### 7.2 Activation

```bash
INTERACTIVE=true FILESYSTEM=exfat DRY_RUN=false ./exfat-sanitizer-v12.1.6.sh ~/Music
```

The `INTERACTIVE` environment variable defaults to `false`, preserving backward compatibility with all existing scripts and automation.

### 7.3 I/O Architecture

**Problem:** The script's internal pipelines (`extract_utf8_chars | while read`) consume stdin. If interactive input also reads from stdin, it gets consumed by the pipeline instead of reaching the prompt.

**Solution:** All interactive I/O uses `/dev/tty` directly:

```bash
echo "prompt text" >/dev/tty          # Output to terminal
IFS= read -r chosen </dev/tty         # Input from terminal
```

`/dev/tty` always refers to the controlling terminal, regardless of stdin/stdout redirection. This ensures interactive prompts work correctly even when the script's output is piped or redirected.

### 7.4 Validation Pipeline

Operator input goes through three validation stages before acceptance:

```
Operator input
    │
    ├── validate_filename() → Check filesystem illegal chars
    │   └── If invalid → show illegal chars, re-prompt
    │
    ├── is_reserved_name() → Check Windows reserved names (FAT32/universal)
    │   └── If reserved → show warning, re-prompt
    │
    └── Empty check → Trim spaces/dots, check if result is empty
        └── If empty → show warning, re-prompt
```

### 7.5 DRY_RUN + INTERACTIVE Coexistence

Both modes can be active simultaneously:

| DRY_RUN | INTERACTIVE | Behavior |
|---------|-------------|----------|
| `true` | `false` | Standard dry-run: log only, no changes |
| `false` | `false` | Standard auto-mode: rename automatically |
| `true` | `true` | Interactive preview: prompt + log, no changes |
| `false` | `true` | Interactive apply: prompt + rename |

When `DRY_RUN=true` and `INTERACTIVE=true`, the operator is prompted for each rename and the chosen name is logged to CSV, but no `mv` operations execute.

### 7.6 CSV Logging with Interactive Mode

In interactive mode, the CSV logs the operator-chosen name (not the auto-suggestion):

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|My Song: Remix?.flac|My Song - Remix.flac|-|Music/|35|RENAMED|NA|-
```

If the operator presses Enter (accepting the suggestion), `New Name` contains the auto-suggested name. If the operator types a custom name, `New Name` contains the custom name.

### 7.7 COPY_TO Integration

When both `INTERACTIVE=true` and `COPY_TO` are set, the operator-chosen name is used for the destination filename:

```bash
copy_file "$item" "$dest_dir" "${final_name:-$sanitized}" "$COPY_BEHAVIOR"
```

The `${final_name:-$sanitized}` pattern ensures the operator-chosen name takes priority, falling back to the auto-suggestion if no interactive choice was made.

---

## 8. System File Filtering

### 8.1 Rationale

Filesystem roots often contain system files that should never be touched:
- `.DS_Store` — macOS Finder metadata
- `Thumbs.db` — Windows thumbnail cache
- `.Spotlight-V100` — macOS Spotlight index
- `.stfolder`, `.stignore` — Syncthing
- `.sync.ffs_db`, `.sync.ffsdb` — FreeFileSync
- `.gitignore` — Git

Processing these files clutters logs with noise, risks breaking tools that expect them, and serves no user purpose.

### 8.2 Implementation

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

## 9. Ignore Patterns

### 9.1 Purpose

User-defined patterns to exclude specific files, directories, or glob patterns from processing.

### 9.2 Implementation

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

### 9.3 Example Ignore File

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

## 10. Directory Processing Strategy

### 10.1 Bottom-Up Renaming

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

### 10.2 Directory Processing Loop

For each directory:
1. Skip if system directory (`should_skip_system_file`)
2. Skip if matches ignore pattern (`should_ignore`)
3. Normalize name to NFC (`normalize_unicode`) ← v12.1.3+
4. Sanitize dirname via `sanitize_filename()` ← v12.1.6: Python-based
5. Normalize sanitized name to NFC ← v12.1.3+
6. Compare NFC(original) vs NFC(sanitized) — prevents NFD/NFC false positives
7. Optional `DEBUG_UNICODE` output ← v12.1.3+
8. If mismatch and `INTERACTIVE=true`: prompt operator ← v12.1.6 NEW
9. Copy if `COPY_TO` set
10. Branch based on `DRY_RUN`:
   - `DRY_RUN=true` → Log only, no `mv`
   - `DRY_RUN=false` → `mv` directory, log result
11. Log to CSV with status (`LOGGED`, `RENAMED`, `FAILED`)
12. Recurse into children

### 10.3 Collision Detection

**Problem:** Two distinct names might sanitize to the same result.

```
Song<Test>.mp3  → Song_Test_.mp3
Song?Test?.mp3  → Song_Test_.mp3   ← COLLISION!
```

**Solution:** Path existence check before `mv`.

```bash
if [ -e "$new_path" ] && [ "$new_path" != "$item" ]; then
    echo "$type|$name|$final_name|COLLISION|...|FAILED|NA|-" >> "$output_file"
else
    mv "$item" "$new_path" 2>/dev/null || true
fi
```

The second file with a collision gets `FAILED` status — never silently clobbered.

---

## 11. File Processing Strategy

### 11.1 Processing Loop

For files, the script:
1. Walks recursively through directories
2. For each file:
   - Skip if system file
   - Skip if matches ignore pattern
   - Normalize to NFC, sanitize (Python), normalize sanitized to NFC
   - Compare NFC(original) vs NFC(sanitized)
   - If mismatch and `INTERACTIVE=true`: prompt operator
   - Check path length
   - Branch based on `DRY_RUN` and `COPY_TO`
3. Log to CSV with detailed status

### 11.2 Copy Mode Architecture

`COPY_TO` enables non-destructive copying with sanitization:
- Source tree remains untouched
- Destination tree has sanitized names (operator-chosen names in interactive mode)
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
- In interactive mode, copies with the operator-chosen filename
- Logs copy status to CSV
- Returns success/failure

### 11.3 CSV Status Fields

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

## 12. Tree Generation (v12.1.0+)

### 12.1 Purpose

`GENERATE_TREE=true` creates a CSV snapshot of the directory structure before processing. Use cases: compare before/after sanitization, document library structure, audit file organization, generate manifests.

### 12.2 Implementation

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

### 12.3 Tree CSV Format

```csv
Type|Name|Path|Depth
Directory|Loïc Nottet|Loïc Nottet|0
Directory|2015 Rhythm Inside|Loïc Nottet/2015 Rhythm Inside|1
File|01 Rhythm Inside.flac|Loïc Nottet/2015 Rhythm Inside/01 Rhythm Inside.flac|2
```

### 12.4 Workflow: Before/After Comparison

```bash
# Before sanitization
FILESYSTEM=fat32 GENERATE_TREE=true DRY_RUN=true ./exfat-sanitizer-v12.1.6.sh ~/Music
# Generates: tree_fat32_20260306_120000.csv (before)

# After sanitization
FILESYSTEM=fat32 GENERATE_TREE=true DRY_RUN=false ./exfat-sanitizer-v12.1.6.sh ~/Music
# Generates: tree_fat32_20260306_120100.csv (after)

# Compare
diff tree_fat32_20260306_120000.csv tree_fat32_20260306_120100.csv
```

---

## 13. Counters, Temp Files & Traps

### 13.1 Why Temp Counters?

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

### 13.2 Counter Lifecycle

**Initialization:** Create temp directory with `mktemp -d`, initialize counters (scanned_dirs, scanned_files, renamed_dirs, renamed_files, etc.) to 0.

**Cleanup:** `trap cleanup_temp_counters EXIT` ensures temp files are removed even on errors or `Ctrl+C`.

### 13.3 Used Paths File

Tracks claimed paths to detect collisions:

```bash
USEDPATHSFILE="$TEMPCOUNTERDIR/usedpaths.txt"
register_path() { echo "$1" >> "$USEDPATHSFILE"; }
is_path_used() { grep -Fxq "$1" "$USEDPATHSFILE" 2>/dev/null; }
```

Prevents two distinct filenames that sanitize to the same result from clobbering each other.

---

## 14. CSV Logging & Exports

### 14.1 Main CSV Log

Filename pattern: `sanitizer_<filesystem>_<YYYYMMDD_HHMMSS>.csv`

Columns:
1. **Type** — `File` or `Directory`
2. **Old Name** — Original filename
3. **New Name** — Sanitized/chosen filename (may equal Old Name; in interactive mode, contains operator's choice)
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
- `COLLISION` — Another item already has this target name

**Example:**

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|Loïc Nottet.flac|Loïc Nottet.flac|-|Music/|45|LOGGED|NA|-
File|Song<test>.mp3|Song_test_.mp3|IllegalChar|Music/|47|RENAMED|COPIED|-
File|My Song: Remix?.flac|My Song - Remix.flac|-|Music/|50|RENAMED|NA|-
Directory|Bad:Dir|Bad_Dir|IllegalChar|Music/|40|RENAMED|NA|-
```

Note: The third entry shows an interactive mode rename where the operator chose `My Song - Remix.flac` instead of the auto-suggestion.

### 14.2 CSV Escaping

- Fields separated by pipe (`|`)
- Double quotes in data are doubled
- Newlines removed during sanitization
- Null bytes removed

### 14.3 Log File Location

Created in the current working directory where the script is run:

```bash
pwd  # /Users/username
./exfat-sanitizer-v12.1.6.sh ~/Music
# Creates: /Users/username/sanitizer_fat32_20260306_123456.csv
```

---

## 15. Error Handling Strategy

### 15.1 Philosophy

1. Fail fast on configuration errors (invalid `FILESYSTEM`, etc.)
2. Never silently ignore rename failures
3. Log all problems to CSV
4. Provide summary statistics
5. Graceful degradation (Python 3 unavailable? Warn and use bash fallback)

### 15.2 Input Validation

`check_dependencies()` validates:
- Python 3 available (REQUIRED — warns if missing, falls back to bash with stderr warning)
- Perl available (optional fallback — warns if missing)
- Target directory exists and is readable

On validation failure: clear error message to stderr, exit with non-zero status, no files are touched.

### 15.3 Operation-Level Errors

| Category | Handling |
|----------|----------|
| Permission errors | Log `FAILED` status, continue with next item |
| Collision errors | Log `FAILED` status with COLLISION note |
| Path length errors | Log `FAILED` with `PathTooLong` issue flag |
| IO errors (disk full, etc.) | Log `FAILED`, continue |
| Python sanitization failure | Fall back to bash loop with stderr warning |

### 15.4 Python 3 Dependency Check

```bash
if command -v python3 >/dev/null 2>&1; then
    # Use Python-based sanitization pipeline (v12.1.6)
else
    echo "⚠️  WARNING: Using bash fallback for sanitization - UTF-8 may be affected!" >&2
    # Fall back to bash character loop
fi
```

The script continues if Python 3 is missing but prints a prominent warning. The bash fallback may lose multibyte characters on macOS.

---

## 16. Security Considerations

### 16.1 Shell Safety Mode

Enabled via `CHECK_SHELL_SAFETY=true`. Removes dangerous shell metacharacters: `$`, `` ` ``, `&`, `;`, `#`, `~`, `^`, `!`, `(`, `)`.

```bash
# Before:
file$(rm -rf /).sh

# After (CHECK_SHELL_SAFETY=true):
file__rm -rf __.sh
```

In the Python-based pipeline (v12.1.6), shell dangerous characters are checked via set membership: `if c in shell_dangerous`.

**When to use:** Processing files from internet, email attachments, or untrusted sources; files that will be used in automation scripts.

### 16.2 Unicode Exploit Detection

Enabled via `CHECK_UNICODE_EXPLOITS=true`. Removes zero-width and control characters:

| Character | Unicode | Name |
|-----------|---------|------|
| (invisible) | U+200B | ZERO WIDTH SPACE |
| (invisible) | U+200C | ZERO WIDTH NON-JOINER |
| (invisible) | U+200D | ZERO WIDTH JOINER |
| (invisible) | U+FEFF | ZERO WIDTH NO-BREAK SPACE |

Prevents visual spoofing attacks, hidden characters in filenames, and homograph attacks.

### 16.3 Control Character Stripping

Always active in `strict` mode and NTFS. Removes ASCII control characters (0x00–0x1F) and DEL (0x7F). In `strict` mode, control characters are replaced with `REPLACEMENT_CHAR`; in other modes, they are silently dropped. Prevents terminal escape exploits, log file corruption, and CSV/toolchain breakage.

### 16.4 Interactive Mode Security

Interactive mode reads input from `/dev/tty`, not from stdin or piped input. This prevents injection attacks where crafted filenames could feed input into the prompt. All operator input is validated before use.

### 16.5 What the Script NEVER Does

- Never modifies file **contents**
- Never reads file **contents**
- Never **deletes** files or directories
- Never follows symlinks destructively
- Never interprets binary data
- Never executes arbitrary code from filenames

Scope: strictly names and paths only.

---

## 17. Performance Considerations

### 17.1 Bottlenecks

1. `find` traversal on very large trees (>100,000 files)
2. `grep` calls for collision detection (O(n) per check)
3. CSV append operations (file IO per item)
4. Python 3 subprocess calls (~10–20ms process spawn overhead per call)
5. Interactive mode pauses (user response time)

### 17.2 v12.1.6 Performance Profile

The Python-based sanitization pipeline changes the performance characteristics:

| Component | v12.1.4 | v12.1.6 | Impact |
|-----------|---------|---------|--------|
| Character extraction | Python subprocess per file | Integrated in sanitize_filename | Fewer subprocesses |
| Character classification | Bash loop per file | Python loop per file | ~Same total time |
| Apostrophe normalization | Python subprocess per file | Python subprocess per file | Unchanged |
| Overall per-file overhead | ~3 Python calls | ~2 Python calls | ~33% fewer spawns |

The net performance impact of v12.1.6 is approximately neutral — one fewer Python subprocess per file, but the single Python call does slightly more work.

### 17.3 Benchmarks

Test environment: 4,074-item music library

| Operation | Time | Items/sec |
|-----------|------|-----------|
| Full scan (dry-run) | ~15s | ~271 |
| With rename | ~18s | ~226 |
| With copy | ~45s | ~90 |
| With interactive mode | Varies | Depends on operator |
| Tree generation | ~3s | — |

Scalability: linear with item count. CPU-bound for dry-run; IO-bound for copy operations; human-bound for interactive mode.

### 17.4 Future Optimization Opportunities

- Parallel processing (`xargs -P` or GNU `parallel`)
- Hash-based collision detection (O(1) lookup)
- Bulk CSV writing (batch inserts)
- Persistent Python interpreter (avoid spawn overhead)
- Batch Python sanitization (process multiple names per invocation)

---

## 18. Real-World Usage Patterns

### 18.1 Audio Library Management

```bash
FILESYSTEM=fat32 \
  SANITIZATION_MODE=conservative \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.6.sh ~/Music
```

Observations on ~4,074-file library: 0 files renamed (all compliant), all accents preserved (French, Italian artists including È, è, à, ò), apostrophes preserved (dell'Amore, Cos'è), only illegal characters (`<`, `>`, `:`, `*`) would be replaced, typical execution time: ~15 seconds.

### 18.2 Interactive Audio Library Curation

```bash
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  INTERACTIVE=true \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh ~/Music
```

For music libraries with international filenames, interactive mode lets the operator review each rename and choose preferred alternatives. The operator can accept auto-suggestions (press Enter) or type custom names that are validated in real-time.

### 18.3 Cross-Platform Sync

```bash
FILESYSTEM=universal \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh ~/SharedDocs
```

Maximum compatibility — works everywhere, still preserves Unicode/accents, removes only truly problematic characters.

### 18.4 Pre-Backup Validation

```bash
# 1. Generate tree snapshot (before)
FILESYSTEM=exfat GENERATE_TREE=true DRY_RUN=true ./exfat-sanitizer-v12.1.6.sh ~/Data

# 2. Review CSV for issues
open sanitizer_exfat_*.csv

# 3. Apply fixes if needed
FILESYSTEM=exfat DRY_RUN=false ./exfat-sanitizer-v12.1.6.sh ~/Data

# 4. Generate tree snapshot (after)
FILESYSTEM=exfat GENERATE_TREE=true DRY_RUN=true ./exfat-sanitizer-v12.1.6.sh ~/Data

# 5. Compare snapshots
diff tree_exfat_*_before.csv tree_exfat_*_after.csv
```

### 18.5 Copy with Sanitization + Interactive

```bash
FILESYSTEM=exfat \
  COPY_TO=/Volumes/2.5ex/Musica/ \
  COPY_BEHAVIOR=skip \
  GENERATE_TREE=true \
  INTERACTIVE=true \
  IGNORE_FILE=./exfat-sanitizer-ignore.txt \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh ~/Music
```

Result: source untouched, destination has operator-approved sanitized names, tree export for documentation.

### 18.6 Post-Copy AppleDouble Cleanup

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

## 19. macOS AppleDouble (`._`) Files

### 19.1 What They Are

When macOS copies files to non-APFS/HFS+ volumes (exFAT, FAT32, NTFS), it creates `._` (dot-underscore) companion files to store:
- Extended attributes (`xattr`)
- Resource forks
- Finder metadata

Each `._` file is exactly **4,096 bytes** (4KB) and mirrors the real file/folder name:

```
._1997 Elisa - Pipes and Flowers (Album)    ← 4KB metadata sidecar
  1997 Elisa - Pipes and Flowers (Album)    ← Actual directory
```

### 19.2 Why They Appear

The script's `copy_file()` function uses the `cp` command internally. macOS hooks into `cp` to automatically write AppleDouble metadata. This is **OS-level behavior, not a script bug**.

### 19.3 Prevention & Cleanup

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

### 19.4 Future Improvement

A future version may use `cp -X` (strip extended attributes during copy) to prevent `._` file creation at the script level.

---

## 20. Extensibility & Future Directions

### 20.1 Plugin Architecture (Proposed)

Pluggable sanitization pipeline:

```bash
SANITIZER_STEPS="universal,controls,unicode,fs-specific,shell,reserved"
```

Benefits: user-configurable pipeline, third-party extensions, A/B testing of strategies.

### 20.2 Configuration File Support (Proposed)

INI-style configuration:

```ini
# .exfat-sanitizer.conf
[defaults]
FILESYSTEM=fat32
SANITIZATION_MODE=conservative
DRY_RUN=true
PRESERVE_UNICODE=true
INTERACTIVE=false

[paths]
IGNORE_FILE=.exfat-sanitizer-ignore

[copy]
COPY_BEHAVIOR=version

[security]
CHECK_SHELL_SAFETY=false
CHECK_UNICODE_EXPLOITS=false
```

### 20.3 Undo Functionality (Proposed)

Reverse operations using CSV log:

```bash
./exfat-sanitizer-v12.1.6.sh --undo sanitizer_fat32_20260306_123456.csv
```

Implementation: read CSV in reverse, rename from New→Old for each `RENAMED` entry, validate no conflicts.

### 20.4 Parallel Processing (Proposed)

```bash
PARALLEL_JOBS=4 ./exfat-sanitizer-v12.1.6.sh ~/BigData
```

Challenges: collision detection needs synchronization, counter updates need atomic operations, directory renaming order must be preserved.

### 20.5 Persistent Python Interpreter (Proposed)

Instead of spawning a new Python process per file, maintain a persistent Python interpreter via a named pipe or FIFO:

```bash
# Start persistent Python
mkfifo /tmp/sanitizer_in /tmp/sanitizer_out
python3 sanitizer_service.py &

# Send filename, receive sanitized result
echo "$name" > /tmp/sanitizer_in
read sanitized < /tmp/sanitizer_out
```

This would eliminate the ~10–20ms Python spawn overhead per file, potentially halving total execution time on large libraries.

---

## 21. Developer Notes

### 21.1 Code Style

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

### 21.2 Testing Strategy

Recommended test categories:

1. **Unit tests** — Individual function testing:
   - `sanitize_filename` input/output pairs (Python pipeline)
   - `normalize_apostrophes` edge cases
   - `validate_filename` character detection
   - `interactive_prompt` (requires /dev/tty mock)
   - `normalize_unicode` NFD→NFC

2. **Integration tests** — Full tree runs:
   - Empty directories
   - Deep nesting (10+ levels)
   - Large trees (10,000+ items)
   - Interactive mode with scripted input

3. **Edge case tests:**
   - Filenames with only forbidden characters → `unnamed_file`
   - Already-reserved names: `CON.txt`
   - Unicode edge cases: NFD vs NFC, combining characters
   - Multibyte characters: È (C3 88), è (C3 A8), à (C3 A0)
   - Zero-length filenames
   - Maximum path lengths
   - Apostrophe-heavy filenames: `dell'Amore`, `Cos'è`

4. **Regression tests (v12.1.6 specific):**
   - Accent preservation: `Loïc`, `Révérence`, `Cè di più`, `Èssere`
   - Apostrophe preservation: `dell'Amore`, `Cos'è`, `L'été`
   - Mixed accents and illegal chars: `Café<test>.mp3`
   - NFD filenames from macOS don't trigger false renames
   - Interactive mode validation rejects illegal chars
   - Interactive mode validation rejects reserved names
   - DRY_RUN + INTERACTIVE logs operator choices without renaming
   - COPY_TO + INTERACTIVE uses operator-chosen name for destination

5. **Test file creation (proper Unicode):**
   ```bash
   # Use Python for proper Unicode in test filenames
   python3 -c "
   for name in ['Èssere.flac', 'Perchè no.mp3', \"dell'Amore.flac\", 'Cos\\'è.mp3']:
       open(name, 'w').close()
   "
   # NOTE: bash `touch` does not interpret \u escapes — always use Python
   ```

### 21.3 Debugging Tips

```bash
# Enable verbose output
bash -x ./exfat-sanitizer-v12.1.6.sh ~/Music 2>&1 | head -100

# Check Python 3 availability
command -v python3 && python3 --version

# Test Python-based sanitization directly
python3 -c "
text = 'Èssere o non Èssere'
illegal = '\"*/:;<>?\\\\|'
result = []
for c in text:
    if c in illegal:
        result.append('_')
    else:
        result.append(c)
print(''.join(result))
"
# Expected: Èssere o non Èssere (no illegal chars, unchanged)

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
DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v12.1.6.sh ~/Music 2>debug.log
grep "MISMATCH" debug.log
```

### 21.4 Contributing Guidelines

Before submitting a pull request:
1. Test on at least macOS and Linux
2. Verify Python 3 dependency is documented
3. Update version number and CHANGELOG
4. Add tests for new features
5. Document new configuration variables
6. Follow existing code style
7. Preserve backward compatibility when possible
8. Test interactive mode if UI changes are involved

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
- [ ] Tested interactive mode (if applicable)

## Checklist
- [ ] Code follows style guidelines
- [ ] Backward compatible
- [ ] CHANGELOG updated
- [ ] Version number updated (if applicable)
```

---

## 22. Bug Fix History

### Critical Bugs Fixed (Cumulative)

| Version | Bug | Root Cause | Fix |
|---------|-----|-----------|-----|
| v12.1.6 | Multibyte UTF-8 chars dropped (È, è, à) | Bash pipe splits multibyte sequences | Python-based sanitization pipeline |
| v12.1.6 | Straight apostrophe `'` dropped | Bash loop mishandled character | Python pipeline preserves legal chars |
| v12.1.4 | Inverted `if/else` in sanitize_filename | Missing `!` operator | Added NOT operator to conditional |
| v12.1.3 | NFD/NFC false positives on macOS | No normalization before comparison | NFC normalization on both sides |
| v12.1.2 | Apostrophe normalization corrupts UTF-8 | Bash glob patterns on multi-byte | Python-based code point replacement |

### Golden Rules (from DEVELOPMENT_CONTEXT.md)

1. **Use Python for all Unicode operations** — Bash is byte-oriented, Python is character-oriented
2. **Never use bash glob patterns on UTF-8 strings** — `${text//pattern}` corrupts multi-byte sequences
3. **Always normalize to NFC before comparison** — macOS NFD ≠ Linux NFC for identical-looking strings
4. **Preserve originals when in doubt** — Better to log `LOGGED` than falsely `RENAMED`
5. **Test with real-world international data** — French, Italian, German, Spanish filenames expose different failure modes

---

## 23. Frequently Asked Questions (Technical)

**Q1: Why Python 3 instead of pure bash?**

Bash is byte-oriented; Python is character-oriented. This distinction caused every critical UTF-8 bug in the project's history. v12.1.6 makes this architectural commitment explicit by running the entire sanitization loop in Python.

```bash
# Bash (BROKEN on macOS): byte-level pipe processing
echo "È" | while IFS= read -r char; do echo "$char"; done  # May lose È

# Python (CORRECT): character-level iteration
for c in "È": print(c)  # Always works: prints È
```

**Q2: Why not use `sed` or `tr` for character replacement?**

`sed` and `tr` are also byte-oriented, not character-oriented. They can corrupt multi-byte UTF-8 sequences.

**Q3: Why use `set -o pipefail`?**

Ensures pipeline errors are caught. Without it, `cmd1 | cmd2` succeeds even if `cmd1` fails.

**Q4: What's the performance impact of the Python-based pipeline?**

Approximately neutral compared to v12.1.4. The v12.1.6 pipeline makes ~2 Python calls per file (sanitize + normalize) vs ~3 in v12.1.4 (extract_chars + sanitize apostrophes + normalize). The single sanitize call does more work but eliminates one subprocess spawn.

**Q5: Can I use the script without Python 3?**

Not recommended. The bash fallback may lose multibyte UTF-8 characters on macOS. A prominent warning is displayed if Python 3 is missing.

**Q6: How does NFD/NFC normalization work?**

macOS stores `è` as `e` + combining grave accent (2 code points = NFD). Windows stores `è` as a single code point (NFC). `normalize_unicode()` converts both to NFC so they compare as equal. Without this, every accented file on macOS would show as `RENAMED` (false positive).

**Q7: How does bottom-up directory renaming work?**

The script processes items recursively, with children processed before their parent directories. This ensures child paths remain valid when parent directories are renamed.

**Q8: What happens if two files sanitize to the same name?**

The second file gets `FAILED` status with `COLLISION` flag and is not renamed:

```csv
File|song<1>.mp3|song_1_.mp3|IllegalChar|Music/|30|RENAMED|NA|-
File|song?1?.mp3|song_1_.mp3|COLLISION|Music/|30|FAILED|NA|-
```

**Q9: Why does interactive mode use `/dev/tty`?**

The script's internal pipelines consume stdin via `extract_utf8_chars | while read`. If interactive prompts also read from stdin, operator input gets consumed by the pipeline. `/dev/tty` always refers to the controlling terminal, bypassing any stdin redirection.

**Q10: Is the script safe for production use?**

Yes, with caveats: always test with `DRY_RUN=true` first; backup critical data before applying changes; use `INTERACTIVE=true` for sensitive directories; review CSV logs carefully; verify Python 3 is installed. The script never deletes files and provides complete audit logs.

**Q11: What about the `._` (AppleDouble) files on exFAT?**

These are created by macOS, not by the script. See [Section 19: macOS AppleDouble Files](#19-macos-appledouble-_-files) for cleanup options including `dot_clean -m`.

**Q12: How does interactive mode interact with COPY_TO?**

The operator-chosen name is used for both the local rename and the destination filename. The expression `${final_name:-$sanitized}` in `copy_file` ensures the operator's choice takes priority.

---

## 24. Glossary

### Technical Terms

| Term | Definition |
|------|-----------|
| **Forbidden Characters** | Characters that a given filesystem does not allow in file or directory names |
| **Reserved Names** | Filenames with special meaning (e.g., Windows DOS device names: CON, PRN, NUL) |
| **Sanitization** | Process of transforming names to conform to filesystem rules |
| **Dry Run** | Preview mode where no actual changes occur — only logs produced |
| **Interactive Mode** | Operator-driven mode where each rename is prompted for approval (v12.1.6) |
| **CSV Log** | Pipe-delimited file containing detailed record of operations |
| **Tree Export** | CSV representation of directory hierarchy structure |
| **Shell Metacharacters** | Characters with special meaning to shells (e.g., `$`, `` ` ``, `&`) |
| **Unicode Normalization** | Converting between NFD (decomposed) and NFC (composed) forms |
| **Long Filename (LFN)** | FAT32/exFAT extension supporting UTF-16LE filenames up to 255 chars |
| **NFD** | Normalized Form Decomposed — e.g., `è` = `e` + combining accent |
| **NFC** | Normalized Form Composed — e.g., `è` = single code point |
| **AppleDouble** | macOS `._` companion files storing resource forks and extended attributes |
| **Python-Based Pipeline** | v12.1.6 architecture where character-level sanitization runs in Python |
| **Bash Fallback** | Legacy character loop used only when Python 3 is unavailable |

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

## 25. Summary

### Key Characteristics

**Technical Excellence:**
- Multi-filesystem aware rules (6 filesystem modes)
- Python-based sanitization pipeline (v12.1.6) — native Unicode safety
- Safe apostrophe normalization (v12.1.2 fix)
- Correct character classification logic (v12.1.4 fix)
- NFD→NFC normalization (v12.1.3+ fix)
- Multibyte UTF-8 preservation (v12.1.6 fix)
- Configurable sanitization pipeline
- Rich logging and audit trail

**Safety-First Design:**
- Default dry-run mode
- Interactive mode for operator control (v12.1.6)
- Never deletes files
- Collision detection
- Complete CSV logs
- Conservative path limits

**Unicode Support (v12.1.6):**
- Full accent preservation (È, è, à, ì, ò, ù, ï, ê, ö, ü)
- Apostrophe preservation (straight `'` U+0027 fully supported)
- Python-based UTF-8 safety — no more byte splitting
- FAT32 LFN (UTF-16) support documented
- NFD/NFC normalization
- Explicit Unicode code points
- DEBUG_UNICODE diagnostic mode

**Production Features:**
- Interactive mode with input validation
- System file filtering
- Ignore pattern support
- Copy mode with versioning
- Tree generation
- Error handling and recovery
- AppleDouble cleanup guidance

### Recommended Reading Order

1. [README.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/README.md) — Overview and quick start
2. [QUICK_START_GUIDE.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/QUICK_START_GUIDE.md) — Step-by-step guide
3. [RELEASE-v12.1.6.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/RELEASE-v12.1.6.md) — What's new and critical fixes
4. **DOCUMENTATION.md** (this file) — Deep technical dive
5. [CHANGELOG-v12.1.6.md](https://github.com/fbaldassarri/exfat-sanitizer/blob/main/CHANGELOG-v12.1.6.md) — Complete version history

---

**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)
**License:** MIT
**Maintainer:** [fbaldassarri](https://github.com/fbaldassarri)
**Version:** 12.1.6 | **Release Date:** March 6, 2026
