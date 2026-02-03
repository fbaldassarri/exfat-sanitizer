# Changelog - exfat-sanitizer

**Repository:** https://github.com/fbaldassarri/exfat-sanitizer

---

## v12.1.2 (2026-02-03) - CRITICAL BUG FIX 🚨

**🔴 CRITICAL FIX:** Apostrophe normalization no longer corrupts Unicode characters

### ⚠️ UPGRADE URGENCY: CRITICAL

**If you're using v12.1.1 or earlier with `NORMALIZE_APOSTROPHES=true` (default), upgrade immediately to prevent accent corruption.**

### 🐛 Critical Bug Fix

**Bug:** `normalize_apostrophes()` function used bash glob patterns that corrupted multi-byte UTF-8 characters

**Impact:**
```bash
# v12.1.1 BROKEN BEHAVIOR
"Loïc Nottet" → "Loic Nottet"         ❌ Accents stripped!
"Révérence" → "Reverence"             ❌ Accents stripped!
"C'è di più" → "C'e di piu"           ❌ Accents stripped!
"Beaux rêves" → "Beaux reves"         ❌ Accents stripped!
```

**Root Cause:**
```bash
# BROKEN CODE (v12.1.1)
text="${text//'/\'}"  # Bash glob pattern corrupted UTF-8 byte sequences
```

The glob pattern `'` (curly apostrophe, U+2019) was matching MORE than intended, corrupting multi-byte UTF-8 sequences in accented characters.

**Fix:**
```python
# FIXED CODE (v12.1.2) - Python-based normalization
replacements = {
    '\u2018': "'",  # LEFT SINGLE QUOTATION MARK
    '\u2019': "'",  # RIGHT SINGLE QUOTATION MARK
    '\u201A': "'",  # SINGLE LOW-9 QUOTATION MARK
    '\u02BC': "'",  # MODIFIER LETTER APOSTROPHE
}
```

**Result:**
```bash
# v12.1.2 FIXED BEHAVIOR
"Loïc Nottet" → "Loïc Nottet"         ✅ Preserved!
"Révérence" → "Révérence"             ✅ Preserved!
"C'è di più" → "C'è di più"           ✅ Preserved!
"Beaux rêves" → "Beaux rêves"         ✅ Preserved!
```

### ✅ Verification

**Test Results on 4,074-item music library:**
- Total items scanned: 4,074
- Items renamed: 0
- Accents preserved: 100%
- **VERIFIED:** All French, Italian, and international accented filenames preserved correctly

### 🔧 Technical Details

**Changed Function:** `normalize_apostrophes()` (lines 193-222)

**Method:**
- Replaced bash glob patterns with Python Unicode string operations
- Uses explicit Unicode code points (U+2018, U+2019, etc.)
- UTF-8 safe character-by-character replacement
- Fallback: Skip normalization if Python unavailable (preserves curly apostrophes rather than corrupt)

### 📦 Dependency Change

**Python 3 now REQUIRED** (was optional in v11.x)

**Why:**
- UTF-8 character extraction (`extract_utf8_chars()`)
- Apostrophe normalization (`normalize_apostrophes()`)
- Both functions need Unicode-aware string handling

**Installation:**
```bash
# macOS (usually pre-installed)
brew install python3

# Ubuntu/Debian
sudo apt-get install python3

# Verify
python3 --version  # Should be 3.6+
```

### 🚀 Migration from v12.1.1

**Action Required:** Immediate upgrade

**Steps:**
1. Download v12.1.2
2. Verify Python 3 is installed
3. Test with `DRY_RUN=true`
4. Apply with `DRY_RUN=false`

**If files were already sanitized by v12.1.1:**
- Accents may already be lost
- Restore from backup if critical
- v12.1.2 prevents future corruption

### 📝 Affected Versions

- ❌ v12.0.0: Partial accent issues
- ❌ v12.1.0: Partial accent issues
- ❌ v12.1.1: **Critical bug - corrupts UTF-8**
- ✅ v12.1.2: **Fixed**

### 🔗 References

- Issue: Apostrophe normalization corrupts multi-byte UTF-8
- Fix: Python-based Unicode-aware normalization
- Verified: 4,074-item real-world music library test

---

## v12.1.1 (2026-02-02) - Enhanced Comparison

### ✅ Improvements

1. **Normalized String Comparison**
   - Added Unicode normalization (NFD/NFC) before comparing filenames
   - Prevents false positives from macOS NFD vs Linux NFC differences
   - Uses `normalize_unicode()` function for consistent comparisons

2. **Enhanced Logging**
   - Better status reporting for normalization operations
   - Clearer output when files don't need renaming

### 🐛 Known Issues

- ❌ **CRITICAL BUG:** Apostrophe normalization corrupts UTF-8 (fixed in v12.1.2)
- **Impact:** Accented characters stripped during normalization
- **Recommendation:** Skip v12.1.1, upgrade directly to v12.1.2

---

## v12.1.0 (2026-02-02) - Feature Consolidation

### ✅ New Features

1. **Tree Generation (`GENERATE_TREE`)**
   ```bash
   GENERATE_TREE=true ./exfat-sanitizer-v12.1.0.sh ~/Music
   ```
   - Generates directory tree snapshot as CSV
   - Output format: `tree_<filesystem>_<timestamp>.csv`
   - Useful for before/after comparisons

2. **Enhanced Copy Modes**
   - Improved conflict resolution
   - Better error handling
   - More detailed copy status logging

3. **Consolidated Features**
   - Combined best features from v11.x and v12.0.0
   - Unified configuration interface
   - Consistent behavior across modes

### ⚙️ Configuration

**New Variable:**
- `GENERATE_TREE` (default: `false`) - Enable tree snapshot generation

**Tree CSV Format:**
```csv
Type|Name|Path|Depth
Directory|Music|Music|0
File|song.mp3|Music/album/song.mp3|2
```

### 🐛 Known Issues

- ❌ **CRITICAL BUG:** Apostrophe normalization corrupts UTF-8 (fixed in v12.1.2)
- **Recommendation:** Skip v12.1.0, upgrade directly to v12.1.2

---

## v12.0.0 (2026-02-01) - Unicode Rewrite

### ✅ New Features

1. **Unicode Preservation Architecture**
   - Complete rewrite of character handling
   - Python-based UTF-8 extraction
   - Proper multi-byte character support

2. **New Configuration Variables**
   ```bash
   PRESERVE_UNICODE=true            # Preserve all Unicode characters
   NORMALIZE_APOSTROPHES=true       # Normalize curly apostrophes
   EXTENDED_CHARSET=true            # Allow extended character sets
   ```

3. **Enhanced Sanitization Logic**
   - Character-by-character processing
   - UTF-8 aware operations
   - Filesystem-specific rule enforcement

### 🔧 Technical Changes

**New Functions:**
- `normalize_unicode()` - NFD/NFC normalization
- `extract_utf8_chars()` - Safe UTF-8 character extraction
- `normalize_apostrophes()` - Apostrophe normalization (⚠️ has bug until v12.1.2)

**Enhanced Functions:**
- `sanitize_filename()` - Complete rewrite with Unicode support
- `is_illegal_char()` - Explicit character checking

### ⚠️ Known Issues

- ⚠️ Apostrophe normalization may have side effects (fixed in v12.1.2)
- Some edge cases with complex Unicode sequences

### 🚀 Migration from v11.1.0

**Backward Compatible:** Yes (mostly)

**New Defaults:**
- `PRESERVE_UNICODE=true` - Preserves accents by default
- `NORMALIZE_APOSTROPHES=true` - Normalizes apostrophes (⚠️ bug until v12.1.2)
- `EXTENDED_CHARSET=true` - Allows extended characters

---

## v11.1.0 (2026-02-01) - COMPREHENSIVE RELEASE

### ✅ Major Feature Release

Combines the critical accent preservation fix from v11.0.5 with advanced features from v9.0.2.2.

### New Features (from v9.0.2.2)

1. **CHECK_SHELL_SAFETY** (Shell Metacharacter Control)
   ```bash
   CHECK_SHELL_SAFETY=true ./exfat-sanitizer-v11.1.0.sh ~/Music
   ```
   - **Removes:** `$` `` ` `` `&` `;` `#` `~` `^` `!` `(` `)`
   - **Protects:** Command injection in shell scripts
   - **Default:** `false` (preserves more characters)

2. **COPY_BEHAVIOR** (Advanced Conflict Resolution)
   ```bash
   COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false \
   ./exfat-sanitizer-v11.1.0.sh ~/Music
   ```
   - **Options:** `skip` (default), `overwrite`, `version`
   - **Versioning:** Creates file-v1.ext, file-v2.ext on conflicts

3. **CHECK_UNICODE_EXPLOITS** (Advanced Security)
   ```bash
   CHECK_UNICODE_EXPLOITS=true ./exfat-sanitizer-v11.1.0.sh ~/Downloads
   ```
   - **Removes:** Zero-width characters (U+200B, U+200C, U+200D, U+FEFF)
   - **Prevents:** Unicode-based visual spoofing

4. **REPLACEMENT_CHAR** (Customizable Replacement)
   ```bash
   REPLACEMENT_CHAR=- ./exfat-sanitizer-v11.1.0.sh ~/Music
   ```
   - **Configures:** Character for replacing illegal chars
   - **Default:** `_` (underscore)

5. **System File Filtering** (Automatic)
   - Auto-skips: `.DS_Store`, `Thumbs.db`, `.Spotlight-V100`, etc.
   - **Benefit:** Cleaner logs, ~5-10% faster

### Preserved Features (from v11.0.5)

**Critical Bug Fix: Accent Preservation**
- ✅ Preserves: `è é à ò ù ï ê ñ ö ü ß ç` etc.
- ✅ Italian, French, Spanish, German, Portuguese accents
- ✅ UTF-8 multi-byte character handling
- ✅ Unicode normalization (NFD→NFC)

### 📊 Configuration Matrix

| Variable | Default | v11.0.5 | v11.1.0 |
|----------|---------|---------|---------|
| `FILESYSTEM` | `fat32` | ✅ | ✅ |
| `SANITIZATION_MODE` | `conservative` | ✅ | ✅ |
| `DRY_RUN` | `true` | ✅ | ✅ |
| `COPY_TO` | (empty) | ✅ | ✅ |
| `IGNORE_FILE` | `~/.exfat-sanitizer-ignore` | ✅ | ✅ |
| `GENERATE_TREE` | `false` | ✅ | ✅ |
| **`REPLACEMENT_CHAR`** | `_` | ❌ | ✅ |
| **`CHECK_SHELL_SAFETY`** | `false` | ❌ | ✅ |
| **`CHECK_UNICODE_EXPLOITS`** | `false` | ❌ | ✅ |
| **`COPY_BEHAVIOR`** | `skip` | ❌ | ✅ |

### 🚀 Migration from v11.0.5

**No Breaking Changes** - Fully backward-compatible

**New Defaults:**
- `CHECK_SHELL_SAFETY=false` - Preserves more characters by default
- `COPY_BEHAVIOR=skip` - Safe default for copy mode

### 🚀 Migration from v9.0.2.2

**⚠️ Important Change:** Accent handling is now correct

```bash
# v9.0.2.2 behavior (BROKEN)
"interprète.mp3" → "interprete.mp3"  # ❌ Incorrectly stripped

# v11.1.0 behavior (CORRECT)
"interprète.mp3" → "interprète.mp3"  # ✅ Correctly preserved
```

---

## v11.0.5 (2026-02-01) - Accent Preservation Fix

### 🐛 Critical Bug Fix

**Fixed:** Accent stripping bug from previous versions

**Before (v9.0.2.2 and earlier):**
```bash
"Café del Mar.mp3" → "Cafe del Mar.mp3"      ❌ Stripped
"L'interprète.flac" → "L'interprete.flac"    ❌ Stripped
"Müller - España.wav" → "Muller - Espana.wav" ❌ Stripped
```

**After (v11.0.5):**
```bash
"Café del Mar.mp3" → "Café del Mar.mp3"      ✅ Preserved
"L'interprète.flac" → "L'interprète.flac"    ✅ Preserved
"Müller - España.wav" → "Müller - España.wav" ✅ Preserved
```

### ✅ Improvements

1. **UTF-8 Multi-byte Character Handling**
   - Proper handling of multi-byte UTF-8 sequences
   - No longer corrupts accented characters

2. **Unicode Normalization (NFC)**
   - Converts macOS NFD to NFC for cross-platform compatibility
   - Uses Python 3, uconv, or Perl for normalization

3. **Apostrophe Preservation**
   - Correctly preserves `'` (straight apostrophe)
   - FAT32/exFAT allow apostrophes in filenames

### 📝 Preserved Characters

- **Italian:** `à è é ì ò ù`
- **French:** `é è ê ë à ù ô î ï ç`
- **Spanish:** `ñ á é í ó ú ü`
- **German:** `ö ä ü ß`
- **Portuguese:** `ã õ ç á é í ó ú`

---

## v9.0.2.2 (2026-01-30) - Advanced Features

### ✅ New Features

1. Shell safety controls
2. Copy behavior modes (skip/overwrite/version)
3. Unicode exploit detection
4. Customizable replacement character
5. System file filtering

### 🐛 Critical Bug

❌ **Accent Stripping Bug** - Incorrectly removes accented characters

**Impact:**
- Strips all accents from filenames
- `interprète` becomes `interprete`
- **Fixed in v11.0.5**

### ⚠️ Recommendation

**Do not use v9.0.2.2** - Upgrade to v11.1.0 or later for accent preservation + advanced features

---

## Version Comparison Summary

| Feature | v9.0.2.2 | v11.0.5 | v11.1.0 | v12.0.0 | v12.1.0 | v12.1.1 | v12.1.2 |
|---------|----------|---------|---------|---------|---------|---------|---------|
| **Accent Preservation** | ❌ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ | ✅ |
| **Apostrophe Normalization** | ❌ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ❌ | ✅ |
| **CHECK_SHELL_SAFETY** | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **COPY_BEHAVIOR** | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **CHECK_UNICODE_EXPLOITS** | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **GENERATE_TREE** | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| **System File Filtering** | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Python 3 Required** | ❌ | ❌ | ❌ | ⚠️ | ⚠️ | ⚠️ | ✅ |
| **Production Ready** | ❌ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ | ✅ |

### Recommended Versions

- **✅ v12.1.2** - Latest, all bugs fixed, production-ready
- **✅ v11.1.0** - Stable, comprehensive features
- **⚠️ v12.1.0** - Good but upgrade to v12.1.2 recommended
- **❌ v12.1.1** - Critical bug, skip this version
- **❌ v9.0.2.2** - Accent bug, use v11.1.0+ instead

---

## Upgrade Path

```
v9.0.2.2 (❌ Accent Bug)
    ↓
v11.0.5 (✅ Fixed Accents, Basic Features)
    ↓
v11.1.0 (✅ Fixed Accents + Advanced Features) ← Stable Recommended
    ↓
v12.0.0 (⚠️ Unicode Rewrite, Some Issues)
    ↓
v12.1.0 (⚠️ Tree Generation Added)
    ↓
v12.1.1 (❌ CRITICAL BUG - Skip!)
    ↓
v12.1.2 (✅ ALL BUGS FIXED) ← LATEST RECOMMENDED
```

---

## Breaking Changes

### v12.1.2
- **Python 3 now REQUIRED** (was optional in v11.x)

### v12.0.0
- New configuration variables (`PRESERVE_UNICODE`, `NORMALIZE_APOSTROPHES`, `EXTENDED_CHARSET`)
- Changed internal character handling architecture

### v11.1.0
- No breaking changes from v11.0.5
- New defaults more permissive than v9.0.2.2

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
| `COPY_BEHAVIOR` | ✅ | ❌ | ✅ | ✅ |
| `IGNORE_FILE` | ❌ | ✅ | ✅ | ✅ |
| `GENERATE_TREE` | ✅ | ✅ | ✅ | ✅ |
| `REPLACEMENT_CHAR` | ✅ | ❌ | ✅ | ✅ |
| `CHECK_SHELL_SAFETY` | ✅ | ❌ | ✅ | ✅ |
| `CHECK_UNICODE_EXPLOITS` | ✅ | ❌ | ✅ | ✅ |
| `PRESERVE_UNICODE` | ❌ | ❌ | ❌ | ✅ |
| `NORMALIZE_APOSTROPHES` | ❌ | ❌ | ❌ | ✅ |
| `EXTENDED_CHARSET` | ❌ | ❌ | ❌ | ✅ |

---

**Repository:** https://github.com/fbaldassarri/exfat-sanitizer  
**License:** MIT  
**Maintainer:** [fbaldassarri](https://github.com/fbaldassarri)
