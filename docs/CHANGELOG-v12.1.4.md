# Changelog — exfat-sanitizer

All notable changes to this project are documented in this file.

**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)

---

## [v12.1.4](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.1.4) — 2026-02-17 — BUG FIX

**Upgrade Urgency:** RECOMMENDED

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
- **UTF-8 character iteration** — The bash-based character-by-character pipeline may not preserve all multibyte Unicode sequences in some environments. A future release will move sanitization logic into Python for native Unicode handling.

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

**Upgrade Urgency:** Superseded by v12.1.4

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

**Upgrade Urgency:** CRITICAL

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

**⚠️ Known Bug:** Apostrophe normalization corrupts UTF-8. Skip this version — upgrade to v12.1.4.

### Improvements

- Normalized string comparison — added Unicode normalization (NFD/NFC) before comparing filenames to prevent false positives from macOS NFD vs Linux NFC differences
- Enhanced logging — better status reporting for normalization operations

---

## [v12.1.0](https://github.com/fbaldassarri/exfat-sanitizer/releases/tag/v12.1.0) — 2026-02-02 — Feature Consolidation

**⚠️ Known Bug:** Apostrophe normalization corrupts UTF-8. Skip this version — upgrade to v12.1.4.

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

**⚠️ Known Bug:** Apostrophe normalization may have side effects. Upgrade to v12.1.4.

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

**⚠️ Critical Bug:** Strips all accented characters. Do not use — upgrade to v11.1.0 or later.

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

| Feature | v9.0.2.2 | v11.0.5 | v11.1.0 | v12.0.0 | v12.1.2 | v12.1.3 | v12.1.4 |
|---------|----------|---------|---------|---------|---------|---------|---------|
| Accent Preservation | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Apostrophe Normalization | — | — | — | ⚠️ Bug | ✅ Fixed | ✅ | ✅ |
| NFD/NFC Normalization | — | Basic | Basic | Yes | Yes | ✅ Improved | ✅ Improved |
| Conditional Logic | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ Inverted | ✅ Fixed |
| `CHECK_SHELL_SAFETY` | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| `COPY_BEHAVIOR` | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| `CHECK_UNICODE_EXPLOITS` | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| `GENERATE_TREE` | — | — | — | — | ✅ | ✅ | ✅ |
| `DEBUG_UNICODE` | — | — | — | — | — | ✅ | ✅ |
| System File Filtering | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| Python 3 Required | — | — | — | Optional | Required | Required | Required |
| Production Ready | ❌ | ✅ | ✅ | Partial | ✅ | Partial | ✅ |

### Recommended Versions

- **v12.1.4** — Latest, all known bugs fixed, production-ready ← **RECOMMENDED**
- **v11.1.0** — Stable, comprehensive features, no Unicode rewrite bugs
- **v12.1.2** — Good, but upgrade to v12.1.4 for conditional logic fix

### Versions to Avoid

- **v12.1.1** — Critical apostrophe bug, corrupts UTF-8
- **v12.1.0** — Same apostrophe bug
- **v9.0.2.2** — Strips all accents

---

## Upgrade Path

```
v9.0.2.2 ──→ v11.0.5 ──→ v11.1.0 ──→ v12.0.0 ──→ v12.1.2 ──→ v12.1.4
(Accent Bug)  (Fixed)     (+ Features)  (Unicode)   (+ Fixes)    (LATEST)
                                                         │
                                            skip v12.1.0 & v12.1.1
                                            (Apostrophe corruption bug)
```

**Recommendation:** Skip v12.0.0–v12.1.1, upgrade directly from v11.1.0 to v12.1.4.

---

## Breaking Changes

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

| Variable | v9.0.2.2 | v11.0.5 | v11.1.0 | v12.0.0+ |
|----------|----------|---------|---------|----------|
| `FILESYSTEM` | ✅ | ✅ | ✅ | ✅ |
| `SANITIZATION_MODE` | ✅ | ✅ | ✅ | ✅ |
| `DRY_RUN` | ✅ | ✅ | ✅ | ✅ |
| `COPY_TO` | ✅ | ✅ | ✅ | ✅ |
| `COPY_BEHAVIOR` | ✅ | — | ✅ | ✅ |
| `IGNORE_FILE` | ✅ | ✅ | ✅ | ✅ |
| `GENERATE_TREE` | — | — | — | ✅ |
| `REPLACEMENT_CHAR` | ✅ | — | ✅ | ✅ |
| `CHECK_SHELL_SAFETY` | ✅ | — | ✅ | ✅ |
| `CHECK_UNICODE_EXPLOITS` | ✅ | — | ✅ | ✅ |
| `PRESERVE_UNICODE` | — | — | — | ✅ |
| `NORMALIZE_APOSTROPHES` | — | — | — | ✅ |
| `EXTENDED_CHARSET` | — | — | — | ✅ |
| `DEBUG_UNICODE` | — | — | — | ✅ (v12.1.3+) |

---

**Repository:** [https://github.com/fbaldassarri/exfat-sanitizer](https://github.com/fbaldassarri/exfat-sanitizer)
**License:** MIT
**Maintainer:** [fbaldassarri](https://github.com/fbaldassarri)
