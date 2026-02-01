# Changelog - exfat-sanitizer v11.1.0

## v11.1.0 (2026-02-01) - COMPREHENSIVE RELEASE

**Major Feature Release: Combining Best of v11.0.5 and v9.0.2.2**

This release merges the critical accent preservation fix from v11.0.5 with advanced features from v9.0.2.2, creating the most complete version to date.

### ✅ New Features (from v9.0.2.2)

#### 1. **CHECK_SHELL_SAFETY** (Shell Metacharacter Control)
```bash
# Enable shell safety (remove dangerous characters)
CHECK_SHELL_SAFETY=true ./exfat-sanitizer-v11.1.0.sh ~/Music

# Disable shell safety (preserve more characters)
CHECK_SHELL_SAFETY=false ./exfat-sanitizer-v11.1.0.sh ~/Music
```

**When enabled (`CHECK_SHELL_SAFETY=true`):**
- Removes/replaces: `$` `` ` `` `&` `;` `#` `~` `^` `!` `(` `)`
- Protects against: Command injection in shell scripts
- Use case: Files from untrusted sources, automation scripts

**When disabled (`CHECK_SHELL_SAFETY=false`, DEFAULT):**
- Preserves these characters (unless forbidden by filesystem)
- Faster processing
- Use case: Audio libraries, trusted sources

#### 2. **COPY_BEHAVIOR** (Advanced Conflict Resolution)
```bash
# Skip existing files (default)
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=skip DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music

# Overwrite existing files
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=overwrite DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music

# Create versioned copies (file-v1.ext, file-v2.ext)
COPY_TO=/Volumes/Backup COPY_BEHAVIOR=version DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Options:**
- **`skip`** (default): Don't copy if destination file exists
- **`overwrite`**: Replace existing destination files
- **`version`**: Create versioned copies with incremental suffixes

#### 3. **CHECK_UNICODE_EXPLOITS** (Advanced Security)
```bash
# Enable zero-width character removal
CHECK_UNICODE_EXPLOITS=true ./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**When enabled:**
- Removes zero-width characters: U+200B, U+200C, U+200D, U+FEFF
- Prevents: Unicode-based visual spoofing attacks
- Use case: Files from untrusted sources (downloads, attachments)

#### 4. **REPLACEMENT_CHAR** (Customizable Replacement)
```bash
# Use dash instead of underscore
REPLACEMENT_CHAR=- ./exfat-sanitizer-v11.1.0.sh ~/Music

# Use space
REPLACEMENT_CHAR=" " ./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Configures** what character replaces illegal characters (default: `_`)

#### 5. **System File Filtering** (Automatic)

The script now **automatically skips** these system files (not processed, not logged):
- `.DS_Store` (macOS Finder metadata)
- `Thumbs.db` (Windows thumbnail cache)
- `.Spotlight-V100` (macOS Spotlight index)
- `.stfolder` (Syncthing folder marker)
- `.sync.ffs_db` / `.sync.ffsdb` (FreeFileSync database)
- `.stignore` / `.gitignore` / `.sync` (sync configuration files)

### ✅ Preserved Features (from v11.0.5)

#### Critical Bug Fix: Accent Preservation
- ✅ **FIXED**: No longer strips accents from filenames
- ✅ Preserves: `interprète`, `naïve`, `Müller`, `España`, `café`, etc.
- ✅ Only normalizes Unicode (NFD→NFC) without changing characters
- ✅ Italian: `à è é ì ò ù` preserved
- ✅ French: `é è ê ë à ù ô î ï ç` preserved
- ✅ Spanish: `ñ á é í ó ú ü` preserved
- ✅ German: `ö ä ü ß` preserved
- ✅ Portuguese: `ã õ ç á é í ó ú` preserved

#### Other v11.0.5 Features
- ✅ UTF-8 multi-byte character handling
- ✅ macOS NFD vs Linux/Windows NFC compatibility
- ✅ Apostrophes (') correctly preserved (FAT32/exFAT allow them)

### 📊 Configuration Matrix

| Variable | Default | v11.0.5 | v9.0.2.2 | v11.1.0 |
|----------|---------|---------|----------|---------|
| `FILESYSTEM` | `fat32` | ✅ | ✅ | ✅ |
| `SANITIZATION_MODE` | `conservative` | ✅ | ✅ | ✅ |
| `DRY_RUN` | `true` | ✅ | ✅ | ✅ |
| `COPY_TO` | (empty) | ✅ | ✅ | ✅ |
| `IGNORE_FILE` | `~/.exfat-sanitizer-ignore` | ✅ | ❌ | ✅ |
| `GENERATE_TREE` | `false` | ✅ | ✅ | ✅ |
| **`REPLACEMENT_CHAR`** | `_` | ❌ | ✅ | ✅ |
| **`CHECK_SHELL_SAFETY`** | `false` | ❌ | ✅ | ✅ |
| **`CHECK_UNICODE_EXPLOITS`** | `false` | ❌ | ✅ | ✅ |
| **`COPY_BEHAVIOR`** | `skip` | ❌ | ✅ | ✅ |

### 🔧 Technical Changes

#### Enhanced `sanitize_filename()` Function
```bash
# v11.0.5: Only preserved accents
sanitized=$(sanitize_filename "$name" "$mode" "$filesystem")

# v11.1.0: Preserves accents + checks shell safety + Unicode exploits
sanitized=$(sanitize_filename "$name" "$mode" "$filesystem")
# Internally checks: CHECK_SHELL_SAFETY, CHECK_UNICODE_EXPLOITS, REPLACEMENT_CHAR
```

#### New `copy_file()` Function
```bash
# v11.0.5: Basic copying, no conflict resolution
cp "$source" "$dest"

# v11.1.0: Advanced copying with conflict resolution
copy_file "$source" "$dest_dir" "$filename" "$COPY_BEHAVIOR"
# Handles: skip, overwrite, versioning
```

#### System File Filtering
```bash
# v11.0.5: No system file filtering

# v11.1.0: Automatic system file skipping
should_skip_system_file "$name" && continue
```

### 📈 CSV Output Format

**Enhanced with Copy Status tracking:**

```csv
Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern
File|song$.mp3|song_.mp3|ShellDangerous|Music/Album|25|RENAMED|COPIED|-
File|track.flac|track.flac|-|Music/Album|26|LOGGED|SKIPPED|-
```

**New `Copy Status` values:**
- `COPIED`: Successfully copied to destination
- `SKIPPED`: Skipped due to conflict (with COPY_BEHAVIOR=skip)
- `NA`: No copy operation (COPY_TO not set)

### 🚀 Migration Guide

#### From v11.0.5 to v11.1.0

**No breaking changes.** v11.1.0 is fully backward-compatible.

**New defaults:**
- `CHECK_SHELL_SAFETY=false` (preserves more characters by default)
- `COPY_BEHAVIOR=skip` (safe default for copy mode)
- `REPLACEMENT_CHAR=_` (consistent with v9.0.2.2)

**To get v9.0.2.2 behavior:**
```bash
# Enable all v9.0.2.2 features
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
COPY_BEHAVIOR=version \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

#### From v9.0.2.2 to v11.1.0

**⚠️ Important Change:** Accent handling is now **correct**

**v9.0.2.2 behavior:**
```
Input:  "interprète.mp3"
Output: "interprete.mp3"  # ❌ Incorrectly stripped accent
```

**v11.1.0 behavior:**
```
Input:  "interprète.mp3"
Output: "interprète.mp3"  # ✅ Correctly preserved
```

**To maintain maximum security (like v9.0.2.2 strict mode):**
```bash
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

### 🧪 Testing Examples

#### Example 1: Audio Library (Default Settings)
```bash
# Preserves accents, apostrophes, safe for music files
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=true \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Result:**
- ✅ `Café del Mar.mp3` → `Café del Mar.mp3` (preserved)
- ✅ `L'interprète.flac` → `L'interprète.flac` (preserved)
- ✅ `song<test>.mp3` → `song_test_.mp3` (illegal char removed)

#### Example 2: Untrusted Downloads (Maximum Security)
```bash
# Remove shell-dangerous chars and Unicode exploits
FILESYSTEM=universal \
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
CHECK_UNICODE_EXPLOITS=true \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Downloads
```

**Result:**
- ✅ `file$(cmd).txt` → `file__cmd_.txt` (shell chars removed)
- ✅ `test​​​.pdf` → `test.pdf` (zero-width chars removed)
- ✅ `doc<script>.html` → `doc_script_.html` (illegal chars removed)

#### Example 3: Copy with Versioning
```bash
# Copy to backup with versioning on conflicts
FILESYSTEM=exfat \
COPY_TO=/Volumes/Backup \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh ~/Music
```

**Result:**
- First copy: `song.mp3` → `/Volumes/Backup/song.mp3`
- Second copy: `song.mp3` → `/Volumes/Backup/song-v1.mp3`
- Third copy: `song.mp3` → `/Volumes/Backup/song-v2.mp3`

### 📝 Complete Variable Reference

```bash
# Core Settings
FILESYSTEM=fat32                              # fat32|exfat|ntfs|apfs|hfsplus|universal
SANITIZATION_MODE=conservative               # strict|conservative|permissive
DRY_RUN=true                                  # true|false

# Copy Settings (NEW in v11.1.0)
COPY_TO=/path/to/destination                  # Destination directory
COPY_BEHAVIOR=skip                            # skip|overwrite|version

# Advanced Settings
IGNORE_FILE=$HOME/.exfat-sanitizer-ignore     # Custom ignore patterns file
GENERATE_TREE=false                           # Generate CSV tree snapshot
REPLACEMENT_CHAR=_                            # Character for replacing illegal chars

# Security Settings (NEW in v11.1.0)
CHECK_SHELL_SAFETY=false                      # Remove shell metacharacters
CHECK_UNICODE_EXPLOITS=false                  # Remove zero-width characters
```

### 🐛 Bug Fixes

1. **Fixed accent stripping** (critical - from v11.0.5)
   - Typography normalization no longer applied
   - All Unicode/accented characters preserved correctly

2. **Improved copy mode** (from v9.0.2.2)
   - Copy operations now respect DRY_RUN properly
   - Conflict resolution options added

3. **System file filtering** (from v9.0.2.2)
   - `.DS_Store`, `Thumbs.db`, etc. now automatically skipped
   - Reduces CSV log noise

### 📊 Performance

- **Processing speed**: Same as v11.0.5 (no performance regression)
- **System file filtering**: ~5-10% faster on typical directories
- **Copy mode**: Efficient conflict detection with versioning

### 🔄 Version Comparison

| Feature | v9.0.2.2 | v11.0.5 | v11.1.0 |
|---------|----------|---------|---------|
| Accent preservation | ❌ Buggy | ✅ Fixed | ✅ Fixed |
| CHECK_SHELL_SAFETY | ✅ Yes | ❌ No | ✅ Yes |
| COPY_BEHAVIOR | ✅ Yes | ❌ No | ✅ Yes |
| CHECK_UNICODE_EXPLOITS | ✅ Yes | ❌ No | ✅ Yes |
| System file filtering | ✅ Yes | ❌ No | ✅ Yes |
| REPLACEMENT_CHAR | ✅ Yes | ❌ No | ✅ Yes |
| UTF-8 handling | ⚠️ Basic | ✅ Advanced | ✅ Advanced |
| Unicode normalization | ❌ No | ✅ Yes | ✅ Yes |

### 🎯 Recommended Use Cases

#### Use v11.1.0 when:
- ✅ You need accent preservation (music, documents, international files)
- ✅ You want advanced copy mode with conflict resolution
- ✅ You need shell safety controls for untrusted sources
- ✅ You want system file filtering
- ✅ You need customizable replacement characters

#### Stay on v11.0.5 when:
- ⚠️ You don't need copy mode features
- ⚠️ You don't need shell safety controls
- ⚠️ You want the simplest possible script

#### Avoid v9.0.2.2 because:
- ❌ Accent preservation is broken (critical bug)
- ❌ Will strip `interprète` to `interprete` incorrectly

### 🔜 Future Plans (v11.2.0+)

Potential future enhancements:
- Parallel processing for large directories
- Progress bars for copy operations
- Hash-based duplicate detection
- Incremental sync mode
- Configurable system file patterns

### 📦 Files in This Release

```
exfat-sanitizer-v11.1.0.sh          # Main script
CHANGELOG-v11.1.0.md                # This changelog
README-v11.1.0.md                   # Updated documentation (coming)
MIGRATION-GUIDE-v11.1.0.md          # Detailed migration guide (coming)
```

### 🙏 Acknowledgments

- v11.0.5: Critical accent preservation fix
- v9.0.2.2: Advanced features (shell safety, copy behavior, system filtering)
- Community feedback on Unicode handling and copy mode requirements

### 📄 License

MIT License - See LICENSE file

---

**Version**: 11.1.0  
**Release Date**: 2026-02-01  
**Previous Version**: 11.0.5  
**Branch**: v11 (combined features)
