# Changelog — exfat-sanitizer

All notable changes to this project are documented in this file.

**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)

---

## [v12.1.6](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.1.6) — 2026-03-06 — CRITICAL FIX + NEW FEATURE

**Upgrade Urgency:** CRITICAL

Fixes silent multibyte UTF-8 character loss on macOS by rewriting the sanitization pipeline in Python, and introduces Interactive Mode for operator-driven renames.

### Fixed

- **Multibyte UTF-8 characters silently dropped** — Characters like È (U+00C8), è, à, ì, ò, ù were lost during bash's `extract_utf8_chars | while IFS= read -r char` pipeline on macOS (bash 3.2). The byte-oriented pipe split multibyte sequences, causing characters to vanish (not replaced — dropped entirely), visible as double spaces in output filenames.
  - Root cause: Bash pipes are byte-oriented; multibyte UTF-8 sequences (e.g., È = bytes `C3 88`) were split across pipe reads
  - Fix: Entire character-level sanitization moved into an embedded Python script inside `sanitize_filename()`
  - Impact: All accented characters now preserved correctly on all platforms

  ```bash
  # BEFORE (v12.1.5) — BROKEN on macOS
  "Èssere o non Èssere.flac"  → "  ssere o non   ssere.flac"  # È dropped!
  "Perchè no.mp3"             → "Perch  no.mp3"               # è dropped!
  "Ce la farò.wav"            → "Ce la far .wav"               # ò dropped!

  # AFTER (v12.1.6) — FIXED
  "Èssere o non Èssere.flac"  → "Èssere o non Èssere.flac"    # Preserved ✅
  "Perchè no.mp3"             → "Perchè no.mp3"               # Preserved ✅
  "Ce la farò.wav"            → "Ce la farò.wav"               # Preserved ✅
  ```

- **Straight apostrophe `'` (U+0027) incorrectly removed** — The apostrophe is a legal character on all supported filesystems (exFAT, FAT32, NTFS, APFS, HFS+) but was being dropped during the bash-based sanitization loop, breaking filenames like `dell'Amore` and `Cos'è`. The Python-based pipeline only removes characters explicitly listed in the filesystem's illegal character set.

  ```bash
  # BEFORE (v12.1.5) — BROKEN
  "dell'Amore.flac"  → "dellAmore.flac"   # Apostrophe dropped!
  "Cos'è.mp3"        → "Cos.mp3"          # Apostrophe + è dropped!

  # AFTER (v12.1.6) — FIXED
  "dell'Amore.flac"  → "dell'Amore.flac"  # Preserved ✅
  "Cos'è.mp3"        → "Cos'è.mp3"        # Preserved ✅
  ```

### Added

- **Interactive Mode** (`INTERACTIVE=true`) — Operator-driven rename decisions with input validation. When enabled, each file or directory needing a rename triggers an interactive prompt displaying the current name and a suggested replacement.
  - Reads input from `/dev/tty` to avoid stdin conflicts with internal pipelines
  - Validates operator input against filesystem-specific illegal character rules
  - Checks for Windows reserved names (CON, PRN, AUX, NUL, COM1-9, LPT1-9) on FAT32/universal
  - Rejects empty names or names consisting only of spaces/dots
  - Re-prompts iteratively until a valid name is provided
  - No skip option — every flagged item must receive a valid name

  ```bash
  # Interactive mode with live changes
  INTERACTIVE=true FILESYSTEM=exfat DRY_RUN=false ./exfat-sanitizer-v12.1.6.sh ~/Music

  # Interactive mode preview (no changes applied)
  INTERACTIVE=true DRY_RUN=true FILESYSTEM=exfat ./exfat-sanitizer-v12.1.6.sh ~/Music
  ```

  Prompt example:
  ```
  ── Interactive Rename ──────────────────────
    Type:      File
    Current:   My Song: A Remix?.flac
    Suggested: My Song_ A Remix_.flac
  ────────────────────────────────────────────
    Enter new name (or press Enter to accept suggested):
  ```

- **`validate_filename()` function** — New function that checks a proposed filename against the target filesystem's illegal character set. Used by interactive mode to validate operator input before accepting it.

- **`interactive_prompt()` function** — New function that manages the interactive rename dialog, including display, input reading, validation loop, and reserved name checking.

- **DRY_RUN + INTERACTIVE coexistence** — Both modes can be active simultaneously. The operator is prompted for each rename and the chosen name is logged to the CSV report, but no filesystem changes are applied.

### Changed

- **`sanitize_filename()` rewritten with Python core** — The character-level sanitization loop has been replaced with an embedded Python script that performs all checks in a single pass: control characters, shell metacharacters, zero-width Unicode exploits, and filesystem-specific illegal characters. The old bash-based loop is retained as a fallback if Python 3 is unavailable.

- **`_process_items_recursive()` updated** — Added `final_name` variable and interactive mode branch. When `INTERACTIVE=true`, the operator-chosen name is used for renaming, logging, and `COPY_TO` destination instead of the auto-generated suggestion.

### New Configuration Variable

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `INTERACTIVE` | `false` | `true`, `false` | Prompt operator for each rename decision |

### Known Limitations

- **macOS AppleDouble (`._`) files** — When using `COPY_TO` to copy files to exFAT/FAT32 volumes, macOS creates `._` companion files to store extended attributes. This is OS behavior, not a script bug. Cleanup: `dot_clean -m /Volumes/DRIVE/` or `find /Volumes/DRIVE/ -name '._*' -delete`
- **Python 3 performance overhead** — The Python-based sanitization pipeline adds minor overhead per file compared to the old bash loop. On large libraries (10,000+ items), this may add a few seconds to total processing time.

### Technical Details

```bash
# BEFORE (v12.1.5) — Bash-based character loop
sanitized=""
while IFS= read -r char; do
    if ! is_illegal_char "$char" "$illegal_chars"; then
        sanitized="$sanitized$char"          # ← Multibyte chars lost in pipe!
    else
        sanitized="${sanitized}${REPLACEMENT_CHAR}"
    fi
done < <(extract_utf8_chars "$name")

# AFTER (v12.1.6) — Python-based single pass
sanitized=$(python3 -c "
import sys
text = sys.stdin.read().strip()
illegal_chars = sys.argv[1]
# ... all checks in one Unicode-safe pass ...
for c in text:
    if c in illegal_chars:
        result.append(replacement)
        continue
    result.append(c)
print(''.join(result))
" "$illegal_chars" "$mode" "$REPLACEMENT_CHAR" ... <<< "$name")
```

### Migration

- Drop-in replacement for v12.1.4 or v12.1.5 — no breaking changes
- All existing environment variables and options are identical
- New `INTERACTIVE` variable defaults to `false`, preserving existing behavior
- Scripts and automation calling the sanitizer require no changes

---

## [v12.1.5](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.1.5) — 2026-02 — INTERACTIVE MODE (Superseded)

**Upgrade Urgency:** Superseded by v12.1.6

Added Interactive Mode but still uses the bash-based sanitization pipeline with the multibyte UTF-8 bug.

### Added

- Interactive Mode (`INTERACTIVE=true`) — initial implementation
- `validate_filename()` function
- `interactive_prompt()` function with `/dev/tty` input

### Known Issues

- **Multibyte UTF-8 characters silently dropped** — The bash-based character pipeline still loses characters like È, è, à on macOS. Fixed in v12.1.6 with the Python-based sanitization pipeline.
- **Straight apostrophe dropped** — `'` (U+0027) incorrectly removed during processing. Fixed in v12.1.6.

---

## [v12.1.4](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.1.4) — 2026-02-17 — BUG FIX

**Upgrade Urgency:** Superseded by v12.1.6

Fixed inverted conditional logic in `sanitize_filename()` and consolidated all NFD/NFC normalization improvements.

### Fixed

- **Inverted `if/else` logic in `sanitize_filename()`** — Legal characters (including accented letters) were routed to the replacement branch while illegal characters were preserved. Added `!` (NOT operator) to the conditional test: `if ! is_illegal_char` instead of `if is_illegal_char`.
  - Function: `sanitize_filename()`
  - Change: Single character addition (`!`)
  - Impact: Corrects character classification for the entire sanitization pipeline

- **NFD→NFC normalization comparison** (from v12.1.3) — macOS stores filenames in NFD (decomposed) form. The script now normalizes both original and sanitized names to NFC before comparison, preventing false `RENAMED` status.
  - Function: `normalize_unicode()` with multi-method fallback (Python 3 → uconv → Perl → iconv)
  - Function: `process_directory()` — normalizes both sides before string comparison

### Added

- **`DEBUG_UNICODE` mode** — Set `DEBUG_UNICODE=true` to print NFD/NFC diagnostic output to stderr, including original→NFC mappings and mismatch detection.
  ```bash
  DEBUG_UNICODE=true DRY_RUN=true ./exfat-sanitizer-v12.1.4.sh ~/Music 2>debug.log
  ```

### Known Limitations

- **macOS AppleDouble (`._`) files** — When using `COPY_TO` to copy files to exFAT/FAT32 volumes, macOS creates `._` companion files to store extended attributes. This is OS behavior, not a script bug. Cleanup: `dot_clean -m /Volumes/DRIVE/` or `find /Volumes/DRIVE/ -name '._*' -delete`
- **UTF-8 character iteration** — The bash-based character-by-character pipeline may not preserve all multibyte Unicode sequences in some environments. Fixed in v12.1.6.

### Technical Details

```bash
# BEFORE (v12.1.3) — BUGGY
if is_illegal_char "$char" "$illegal_chars"; then
    sanitized="${sanitized}${REPLACEMENT_CHAR}"  # ← Legal chars went here
else
    sanitized="$sanitized$char"                  # ← Illegal chars went here
fi

# AFTER (v12.1.4) — FIXED
if ! is_illegal_char "$char" "$illegal_chars"; then
    sanitized="$sanitized$char"                  # ← Legal chars preserved ✅
else
    sanitized="${sanitized}${REPLACEMENT_CHAR}"   # ← Illegal chars replaced ✅
fi
```

### Migration

- Drop-in replacement for v12.1.2 or v12.1.3 — no breaking changes
- All environment variables and options are identical

---

## [v12.1.3](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.1.3) — 2026-02-04 — BUG FIX (Superseded)

**Upgrade Urgency:** Superseded by v12.1.6

Attempted fix for NFD/NFC comparison causing false `RENAMED` status on macOS.

### Fixed

- **NFD vs NFC comparison** — Added `normalize_unicode()` calls before comparing original and sanitized filenames, using Python 3 `unicodedata.normalize('NFC', ...)` as the primary method with uconv/Perl/iconv fallbacks.

### Added

- `DEBUG_UNICODE` environment variable for diagnostic output
- Multi-method `normalize_unicode()` function (Python 3 → uconv → Perl → iconv)

### Known Issues

- **Inverted conditional logic** — `sanitize_filename()` still had the `if/else` branches swapped, causing legal characters to be replaced. Fixed in v12.1.4.

---

## [v12.1.2](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.1.2) — 2026-02-03 — CRITICAL BUG FIX

**Upgrade Urgency:** Superseded by v12.1.6

If you're using v12.1.1 or earlier with `NORMALIZE_APOSTROPHES=true` (default), upgrade immediately to prevent accent corruption.

### Fixed

- **Apostrophe normalization corrupts multi-byte UTF-8** — The `normalize_apostrophes()` function used bash glob patterns (`${text//…}`) that corrupted multi-byte UTF-8 characters during apostrophe normalization.

  ```bash
  # v12.1.1 BROKEN BEHAVIOR
  "Loïc Nottet"    → "Loic Nottet"     # Accents stripped!
  "Révérence"      → "Reverence"       # Accents stripped!
  "Cè di più"      → "Ce di piu"       # Accents stripped!
  "Beaux rêves"    → "Beaux reves"     # Accents stripped!
  ```

- **Root cause:** Bash glob pattern (curly apostrophe, U+2019) matched more than intended, corrupting multi-byte UTF-8 sequences in accented characters.

### Changed

- **`normalize_apostrophes()` rewritten in Python** — Uses explicit Unicode code points (U+2018, U+2019, U+201A, U+02BC) for safe, targeted replacement. Falls back to skipping normalization (preserving curly apostrophes) if Python is unavailable.

### Verification

- Tested on 4,074-item music library
- Total items renamed: 0
- Accents preserved: 100%
- All French, Italian, and international accented filenames verified correct

### Dependency Change

- **Python 3 now REQUIRED** (was optional in v11.x) — needed for UTF-8 character extraction and apostrophe normalization.

---

## [v12.1.1](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.1.1) — 2026-02-02 — Enhanced Comparison

**⚠️ Known Bug:** Apostrophe normalization corrupts UTF-8. Skip this version — upgrade to v12.1.6.

### Improvements

- Normalized string comparison — added Unicode normalization (NFD/NFC) before comparing filenames to prevent false positives from macOS NFD vs Linux NFC differences
- Enhanced logging — better status reporting for normalization operations

---

## [v12.1.0](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.1.0) — 2026-02-02 — Feature Consolidation

**⚠️ Known Bug:** Apostrophe normalization corrupts UTF-8. Skip this version — upgrade to v12.1.6.

### New Features

- **Tree Generation** (`GENERATE_TREE`)
  ```bash
  GENERATE_TREE=true ./exfat-sanitizer-v12.1.0.sh ~/Music
  # Outputs: tree_<filesystem>_<timestamp>.csv
  ```
- Enhanced copy modes with improved conflict resolution and error handling
- Consolidated best features from v11.x and v12.0.0

### Configuration

- New variable: `GENERATE_TREE` (default: `false`)

---

## [v12.0.0](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.0.0) — 2026-02-01 — Unicode Rewrite

**⚠️ Known Bug:** Apostrophe normalization may have side effects. Upgrade to v12.1.6.

### New Features

- **Complete rewrite** of character handling with Unicode preservation architecture
- Python-based UTF-8 extraction (`extract_utf8_chars`)
- Unicode normalization function (`normalize_unicode`)
- Apostrophe normalization (`normalize_apostrophes`) — has bug until v12.1.2

### New Configuration Variables

```bash
PRESERVE_UNICODE=true       # Preserve all Unicode characters
NORMALIZE_APOSTROPHES=true  # Normalize curly apostrophes (bug until v12.1.2)
EXTENDED_CHARSET=true       # Allow extended character sets
```

### Technical Changes

- `sanitize_filename()` — complete rewrite with character-by-character Unicode processing
- `is_illegal_char()` — explicit case-based character checking
- Multi-method Unicode normalization fallback chain

### Migration from v11.1.0

- Backward compatible (mostly)
- New defaults: `PRESERVE_UNICODE=true`, `NORMALIZE_APOSTROPHES=true`, `EXTENDED_CHARSET=true`

---

## [v11.1.0](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v11.1.0) — 2026-02-01 — Comprehensive Release

Combines the critical accent preservation fix from v11.0.5 with advanced features from v9.0.2.2.

### New Features (from v9.0.2.2)

- **`CHECK_SHELL_SAFETY`** — Remove shell metacharacters (`$`, `` ` ``, `&`, `;`, `#`, `~`, `^`, `!`, `(`, `)`)
- **`COPY_BEHAVIOR`** — Advanced conflict resolution: `skip` (default), `overwrite`, `version`
- **`CHECK_UNICODE_EXPLOITS`** — Remove zero-width characters (U+200B, U+200C, U+200D, U+FEFF)
- **`REPLACEMENT_CHAR`** — Configurable replacement character (default: `_`)
- **System file filtering** — Auto-skips `.DS_Store`, `Thumbs.db`, `.Spotlight-V100`, etc.

### Preserved Features (from v11.0.5)

- Accent preservation (à, è, é, ì, ò, ù, ï, ê, ö, ü, ä)
- UTF-8 multi-byte character handling
- Unicode normalization (NFD/NFC)

### Migration

- No breaking changes from v11.0.5
- New defaults: `CHECK_SHELL_SAFETY=false`, `COPY_BEHAVIOR=skip`

---

## [v11.0.5](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v11.0.5) — 2026-02-01 — Accent Preservation Fix

### Critical Bug Fix

- **Fixed accent stripping** from v9.0.2.2 and earlier

  ```bash
  # BEFORE (v9.0.2.2) — BROKEN
  "Café del Mar.mp3"       → "Cafe del Mar.mp3"       # Stripped
  "L'interprète.flac"      → "L'interprete.flac"      # Stripped
  "Müller - España.wav"    → "Muller - Espana.wav"    # Stripped

  # AFTER (v11.0.5) — FIXED
  "Café del Mar.mp3"       → "Café del Mar.mp3"       # Preserved ✅
  "L'interprète.flac"      → "L'interprète.flac"      # Preserved ✅
  "Müller - España.wav"    → "Müller - España.wav"    # Preserved ✅
  ```

### Improvements

- UTF-8 multi-byte character handling
- Unicode normalization (NFC) using Python 3, uconv, or Perl
- Apostrophe preservation (straight apostrophe is FAT32/exFAT legal)

### Preserved Characters

- Italian: à, è, é, ì, ò, ù
- French: ï, ê, â, ë, ô, û, ç
- Spanish: ñ, á, é, í, ó, ú
- German: ä, ö, ü, ß
- Portuguese: ã, õ

---

## [v9.0.2.2](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v9.0.2.2) — 2026-01-30 — Advanced Features

**⚠️ Critical Bug:** Strips all accented characters. Do not use — upgrade to v12.1.6.

### New Features

- Shell safety controls (`CHECK_SHELL_SAFETY`)
- Copy behavior modes (`COPY_BEHAVIOR`: skip, overwrite, version)
- Unicode exploit detection (`CHECK_UNICODE_EXPLOITS`)
- Customizable replacement character (`REPLACEMENT_CHAR`)
- System file filtering (auto-skip `.DS_Store`, `Thumbs.db`, etc.)

### Known Bug

- **Accent stripping** — Incorrectly removes all accented characters from filenames. Fixed in v11.0.5.

---

## Version Comparison Summary

### Feature Matrix

| Feature | v9.0.2.2 | v11.0.5 | v11.1.0 | v12.0.0 | v12.1.2 | v12.1.4 | v12.1.6 |
|---------|----------|---------|---------|---------|---------|---------|---------|
| Accent Preservation | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | **Full** |
| Apostrophe Handling | — | ✅ | ✅ | ⚠️ Bug | ✅ Fixed | ✅ | **Full** |
| NFD/NFC Normalization | — | Basic | Basic | Yes | Yes | ✅ Improved | ✅ Improved |
| Conditional Logic | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ Fixed | ✅ |
| Python-Based Sanitization | — | — | — | — | — | — | **Yes** |
| Interactive Mode | — | — | — | — | — | — | **Yes** |
| `CHECK_SHELL_SAFETY` | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| `COPY_BEHAVIOR` | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| `CHECK_UNICODE_EXPLOITS` | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GENERATE_TREE` | — | — | — | — | ✅ | ✅ | ✅ |
| `DEBUG_UNICODE` | — | — | — | — | — | ✅ | ✅ |
| System File Filtering | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| Python 3 Required | — | — | — | Optional | Required | Required | Required |
| Production Ready | ❌ | ✅ | ✅ | Partial | ✅ | ✅ | **Yes** |

### Recommended Versions

- **v12.1.6** — Latest, all known bugs fixed, Python-based sanitization, interactive mode ← **RECOMMENDED**
- **v12.1.4** — Stable, but lacks Python sanitization pipeline and interactive mode
- **v11.1.0** — Stable legacy, comprehensive features, no Unicode rewrite bugs

### Versions to Avoid

- **v12.1.5** — Multibyte UTF-8 bug still present, superseded by v12.1.6
- **v12.1.1** — Critical apostrophe bug, corrupts UTF-8
- **v12.1.0** — Same apostrophe bug
- **v9.0.2.2** — Strips all accents

---

## Upgrade Path

```
v9.0.2.2 ──→ v11.0.5 ──→ v11.1.0 ──→ v12.0.0 ──→ v12.1.2 ──→ v12.1.4 ──→ v12.1.6
(Accent Bug)  (Fixed)     (+ Features)  (Unicode)   (+ Fixes)    (Logic Fix)  (LATEST)
                                                         │
                                            skip v12.1.0 & v12.1.1
                                            (Apostrophe corruption bug)
```

**Recommendation:** Skip v12.0.0–v12.1.1 and v12.1.5, upgrade directly to v12.1.6.

---

## Breaking Changes

### v12.1.6

- No breaking changes from v12.1.4 or v12.1.5
- New `INTERACTIVE` variable defaults to `false` (existing behavior unchanged)

### v12.1.2+

- **Python 3 now REQUIRED** (was optional in v11.x)

### v12.0.0

- New configuration variables: `PRESERVE_UNICODE`, `NORMALIZE_APOSTROPHES`, `EXTENDED_CHARSET`
- Changed internal character handling architecture

### v11.1.0

- No breaking changes from v11.0.5
- New defaults are more permissive than v9.0.2.2

### v11.0.5

- Accent handling changed (now preserves correctly)
- May cause "no changes" on files already sanitized by v9.0.2.2

---

## Configuration Variables Evolution

| Variable | v9.0.2.2 | v11.0.5 | v11.1.0 | v12.0.0+ | v12.1.6 |
|----------|----------|---------|---------|----------|---------|
| `FILESYSTEM` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `SANITIZATION_MODE` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `DRY_RUN` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `COPY_TO` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `COPY_BEHAVIOR` | ✅ | — | ✅ | ✅ | ✅ |
| `IGNORE_FILE` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GENERATE_TREE` | — | — | — | ✅ | ✅ |
| `REPLACEMENT_CHAR` | ✅ | — | ✅ | ✅ | ✅ |
| `CHECK_SHELL_SAFETY` | ✅ | — | ✅ | ✅ | ✅ |
| `CHECK_UNICODE_EXPLOITS` | ✅ | — | ✅ | ✅ | ✅ |
| `PRESERVE_UNICODE` | — | — | — | ✅ | ✅ |
| `NORMALIZE_APOSTROPHES` | — | — | — | ✅ | ✅ |
| `EXTENDED_CHARSET` | — | — | — | ✅ | ✅ |
| `DEBUG_UNICODE` | — | — | — | ✅ (v12.1.3+) | ✅ |
| `INTERACTIVE` | — | — | — | — | **✅ New** |

---

**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)
**License:** MIT
**Maintainer:** [fbaldassarri](https://github.com/fbaldassarri)
