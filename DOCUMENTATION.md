# exfat-sanitizer Deep Dive Documentation

**File**: `DOCUMENTATION.md`  
**Applies To**: `exfat-sanitizer-v9.0.2.2.sh`  
**Version**: 9.0.2.2  
**Status**: Production-Ready (Bugfix Release)

---

## 1. Introduction

This document provides a **deep technical and conceptual dive** into `exfat-sanitizer`, beyond what is covered in `README.md` and `QUICK_START_GUIDE.md`.

It is intended for:
- Developers who want to understand or extend the script
- Power users who want to tune behavior deeply
- Contributors preparing pull requests
- Future maintainers picking up the project

If you just want to use the tool, start with:
- `README.md`
- `QUICK_START_GUIDE.md`
- Release notes `RELEASE-v9.0.2.2.md`

This document assumes **familiarity with bash**, filesystems, and command-line workflows.

---

## 2. Conceptual Model

### 2.1 Problem Space

Modern workflows regularly move data across:
- macOS (APFS)
- Windows (NTFS, legacy FAT32)
- Linux (ext4, xfs, btrfs, etc.)
- Removable media (exFAT, FAT32)

Each filesystem has differing rules for:
- Allowed characters
- Reserved filenames
- Path length limits
- Unicode normalization

As a result, filenames that are valid in one environment may:
- Fail to copy or sync
- Be silently skipped
- Break backup tools
- Fail in media players or DAWs

`exfat-sanitizer` solves this by:
1. **Scanning** a directory tree
2. **Evaluating** each filename and path against selected filesystem rules
3. **Sanitizing** names when needed (configurable strictness)
4. **Recording** all decisions in a CSV log
5. **Optionally copying** sanitized data to a new destination

### 2.2 Core Goals

1. **Safety**
   - Default to no changes (`DRY_RUN=true`)
   - Never delete any file or directory
   - Provide complete audit logs (CSV)

2. **Predictability**
   - Same input + same options → same output
   - Mode- and filesystem-specific behavior clearly defined

3. **Portability**
   - Pure bash + standard POSIX-ish tools
   - Work on macOS, Linux, and Windows (via WSL/Git Bash/Cygwin)

4. **Transparency**
   - CSV logs show what changed, why, and where
   - Summary printed to console

---

## 3. Filesystem Modes & Semantics

### 3.1 Filesystem Types

`FILESYSTEM` controls **which ruleset** is applied:

- `exfat`: exFAT-style rules aimed at modern removable media
- `fat32`: FAT32-style legacy restrictions
- `apfs`: macOS APFS rules (reduced forbidden set)
- `ntfs`: Windows NTFS rules + control character constraints
- `hfsplus`: HFS+ legacy macOS rules (colon handling)
- `universal`: Safest, most restrictive superset for unknown targets

This setting affects:
- Forbidden character sets (filesystem-specific)
- Path length limit
- Reserved name handling

### 3.2 Character Rules by Filesystem

**Universal forbidden characters (applies to ALL modes)**:
- `< > : " / \ | ? * NUL`

**FAT32-specific extras**:
- `+ , ; = [ ] ÷ ×`

**HFS+ specifics**:
- Colon `:` is invalid and replaced with a fullwidth variant `⁓`.

**NTFS specifics**:
- All universal forbidden characters
- Control characters `0x00–0x1F`, `0x7F`

**APFS specifics**:
- Has relatively few restrictions compared to FAT-family
- Focus on universal forbidden and line breaks

**exFAT specifics**:
- More permissive than FAT32, but `exfat-sanitizer` applies universal forbidden plus optional safety rules for compatibility.

### 3.3 Path Length Semantics

Even though some filesystems support very long paths, the script uses **conservative limits** for cross-platform compatibility:

- `fat32` / `exfat`: 260 characters (Windows-style MAX_PATH)
- `apfs` / `ntfs` / `hfsplus`: 255 characters
- `universal`: 260 characters

This is implemented in `check_path_length()`.

**Why conservative?**
- Ensures data works when accessed from Windows tools
- Avoids edge cases in backup/sync tools still built around 260-char assumptions

Future enhancement could introduce a `STRICT_PATH_LIMITS` toggle to relax this for exFAT/APFS.

---

## 4. Sanitization Modes & Strategy

### 4.1 Sanitization Modes

`SANITIZATION_MODE` defines **how aggressively** names are modified:

- `strict`
  - Removes all forbidden characters
  - Removes control characters
  - Optionally removes shell-dangerous characters
  - Most aggressive

- `conservative`
  - Removes only officially forbidden characters per filesystem
  - Leaves benign characters intact
  - Balanced and recommended for most use cases

- `permissive`
  - Removes only universal forbidden characters
  - Fastest and least intrusive

### 4.2 Sanitization Pipeline

The `sanitize_name()` function implements a multi-step pipeline:

1. **Universal forbidden characters**
   - Replace `< > : " / \ | ? *` and NUL with `REPLACEMENT_CHAR` (default `_`).

2. **Control characters** (strict mode or NTFS)
   - Strips non-printable ASCII control characters.

3. **Unicode line separators**
   - Removes characters that can break lines mid-name: `U+000A`, `U+000D`, `U+0085`, `U+2028`, `U+2029`.

4. **Filesystem-specific restrictions**
   - FAT32: handles `+ , ; = [ ] ÷ ×`.
   - HFS+: colon replacement.
   - NTFS: combination of universal + control rules.

5. **Shell metacharacters** (optional via `CHECK_SHELL_SAFETY`)
   - `$`, `` ` ``, `&`, `;`, `#`, `~`, `^`, `!`, `(`, `)`.

6. **Unicode exploit/zero-width characters** (optional)
   - When `CHECK_UNICODE_EXPLOITS=true`, removes suspicious invisibles like `U+200B`, `U+200C`, `U+200D`.

7. **Leading/trailing invalid characters**
   - Leading dot or trailing dot removal when relevant.

8. **Reserved names** (Windows/DOS)
   - Appends `-reserved` to: `CON`, `PRN`, `AUX`, `NUL`, `COM1–9`, `LPT1–9`, `..`.

The function returns:
- Sanitized name
- Boolean flag (`had_changes`) indicating whether modifications were applied
- Issues label string (comma-separated, e.g. `Universal_Forbidden,FAT32_Specific`)

---

## 5. System File Filtering

### 5.1 Rationale

Filesystem roots often contain system files that **should never be touched**, such as:
- `.DS_Store`
- `Thumbs.db`
- `.stfolder`, `.stignore` (Syncthing)
- `.sync.ffs_db`, `.sync.ffsdb` (FreeFileSync)
- `.Spotlight-V100`
- `.gitignore`

Processing them is:
- Noisy (clutters logs)
- Risky (tools expect these files in specific states)
- Unnecessary (they serve only internal metadata roles)

### 5.2 Implementation

`should_skip_item()` encapsulates the logic:

```bash
should_skip_item() {
    local item="$1"
    case "$item" in
        .DS_Store|.stfolder|.sync.ffs_db|.sync.ffsdb|.Spotlight-V100|\
        Thumbs.db|.stignore|.gitignore|.sync)
            return 0  # Skip this item
            ;;
        *)
            return 1  # Process this item
            ;;
    esac
}
```

Both directory and file walkers call this before processing:

```bash
if should_skip_item "$filename"; then
    continue  # Not even logged to CSV
fi
```

**Result**:
- System files are *invisible* to the sanitizer
- CSV logs include only user data

This behavior was refined and solidified in v9.0.2.2.

---

## 6. Directory Processing Strategy

### 6.1 Bottom-Up Renaming

Directory renaming must be done **bottom-up** to avoid path breakage:

- If parent directories are renamed first, all child paths become stale
- Bottom-up guarantees children are renamed while parent paths are still valid

Implementation pattern:

```bash
find "$rootdir" -type d -print0 2>/dev/null | sort -z -r | while IFS= read -r -d '' dir; do
    # Process from deepest path to shallowest
    ...
done
```

This ensures that:
- Deepest nested directories are processed first
- Higher-level directories see already-sanitized child names, but process their own names independently

### 6.2 Directory Logging Semantics

For each directory:
1. Skip if system directory (`should_skip_item`)
2. Extract `dirname` and `parentdir`
3. Run `sanitize_name()` on `dirname`
4. Construct `newpath` as `parentdir/newdirname`
5. Check path length via `check_path_length()`
6. Check for collision via `is_path_used()`
7. Behavior differs depending on `DRY_RUN` and path validity:
   - Valid + different name + `DRY_RUN=false` → `mv` directory, log `RENAMED`
   - Valid + different name + `DRY_RUN=true` → log `RENAMED` (planned), no `mv`
   - Invalid path length → log `FAILED`, increment `path_length_issues`
   - No change → log `LOGGED`

---

## 7. File Processing Strategy

### 7.1 Processing Loop

For files, the script:

1. Walks using `find -type f -print0`
2. For each file:
   - Increments `scanned_files` counter
   - Optionally prints progress every 100 files
   - Derives `filename` and `parentdir`
   - Skips if system file
   - Runs `sanitize_name()` on `filename`
   - Builds `newpath = parentdir/newfilename`
   - Checks path length
   - Branches based on:
     - `had_changes`
     - `DRY_RUN`
     - `COPY_TO` usage

### 7.2 Copy Mode

`COPY_TO` enables a non-destructive copy of files into a sanitized target tree.

- Source tree remains untouched
- Destination tree reproduces structure with sanitized names

Core helpers:

- `validate_destination_path(dest)`
- `estimate_disk_space(source, dest)`
- `handle_file_conflict(dest_file, behavior)`
  - `skip` (default): keep existing file if conflict
  - `overwrite`: replace existing file
  - `version`: write `-vN` suffixed copies
- `copy_file(source, dest_dir, dest_filename, csv_file, COPY_BEHAVIOR)`

### 7.3 Status and Copy_Status Fields

In file-related CSV rows:

- `Status` reflects **rename processing** of the original file
  - `LOGGED`: no rename was necessary
  - `RENAMED`: rename would/did occur
  - `FAILED`: rename could not proceed (path too long, permissions, etc.)

- `Copy_Status` reflects **copy processing** (if `COPY_TO` is set)
  - `COPIED`: file copied to destination
  - `SKIPPED`: copy skipped due to conflict rule
  - `FAILED`: copy failed (I/O or permission error)
  - `N/A`: copy mode not in use

---

## 8. Counters, Temp Files & Traps

### 8.1 Why Temp Counters?

Bash pipelines and subshells make it hard to keep consistent numeric counters via simple variables. Instead, the script uses **temp files** as counter stores.

This has advantages:
- Works across nested functions
- Works even if loops spawn subshells
- Minimizes shared-state bugs

### 8.2 Counter Lifecycle

- `init_temp_counters()` creates a temporary directory with a file per counter
- `increment_counter(name)` reads the value, increments, writes back
- `get_counter(name)` returns the current value
- `cleanup_temp_counters()` removes the temporary directory on exit

A `trap` ensures cleanup even on interruption:

```bash
trap cleanup_temp_counters EXIT
```

Counters tracked include:
- `scanned_dirs`, `scanned_files`
- `renamed_dirs`, `renamed_files`
- `failed_dirs`, `failed_files`
- `copied_dirs`, `copied_files`
- `skipped_items`, `failed_items`
- `path_length_issues`

### 8.3 USED_PATHS_FILE

To detect collisions in renamed paths, `USED_PATHS_FILE` stores every new path that has been claimed so far.

- `register_path(path)` appends to this file
- `is_path_used(path)` checks for existence via `grep -Fxq`

This ensures that two originally distinct names that sanitize to the **same** string are not silently clobbered.

---

## 9. CSV & Tree Exports

### 9.1 Main CSV Log

File naming pattern:

```text
sanitizer_<filesystem>_<YYYYMMDD_HHMMSS>.csv
```

Columns:

1. `Type` — `File` or `Directory`
2. `Old Name` — Original name
3. `New Name` — Sanitized name (may equal Old Name)
4. `Issues` — Comma-separated flags (e.g. `Universal_Forbidden,FAT32_Specific`)
5. `Path` — Parent directory path
6. `Path Length` — Character count of full new path
7. `Status` — `LOGGED`, `RENAMED`, or `FAILED`
8. `Copy_Status` — `COPIED`, `SKIPPED`, `FAILED`, or `N/A`

Escaping:
- Double quotes in data are doubled (`"` → `""`)
- Fields are comma-separated
- Newlines removed by earlier sanitization

### 9.2 Tree CSV Export

When `GENERATE_TREE=true`, the script also creates:

```text
tree_<filesystem>_<YYYYMMDD_HHMMSS>.csv
```

Columns:

1. `Type` — `File` or `Directory`
2. `Name` — Final name at that node
3. `Path` — Relative path from root
4. `Depth` — Directory nesting depth
5. `Has Children` — `Yes` or `No` for directories

This is useful for:
- Visualizing structure
- Comparing before/after (when run twice with copies)
- Documentation

---

## 10. Error Handling Strategy

### 10.1 Philosophy

- **Fail fast on configuration errors** (invalid `FILESYSTEM`, etc.)
- **Never silently ignore actual rename failures**
- **Log all problems to CSV and summarize counters**

### 10.2 Validations

The `validate_inputs()` function ensures the environment is sane:
- `validate_filesystem(FILESYSTEM)`
- `validate_sanitization_mode(SANITIZATION_MODE)`
- `validate_copy_behavior(COPY_BEHAVIOR)` (if `COPY_TO` is set)

On failure, the script:
- Prints a clear error message to stderr
- Exits with non-zero status

### 10.3 Operation-Level Errors

For rename or copy operations, errors can stem from:
- Permission issues
- Existing conflicting files
- Path length problems

These are handled by:
- Logging `FAILED` or `SKIPPED`
- Incrementing appropriate counters
- Continuing with the next item (non-fatal)

No operations are performed if:
- `DRY_RUN=true` (only logging is done)
- `validate_destination_path()` fails in copy mode

---

## 11. Security Considerations

### 11.1 Shell Safety

When `CHECK_SHELL_SAFETY=true` (default in strict mode), the script removes or neutralizes characters that could be interpreted by shells if the filename is later used in scripts:

- `$`, `` ` ``, `&`, `;`, `#`, `~`, `^`, `!`, `(`, `)`

This is particularly important when:
- Files are pulled from untrusted sources
- Names might be interpolated into scripts or commands

### 11.2 Unicode Exploit Mitigation

With `CHECK_UNICODE_EXPLOITS=true`, the script attempts to remove zero-width characters and potentially confusing Unicode constructs.

While not a complete defense against all homograph attacks or bidi trickery, it reduces the risk of filenames that:
- Appear identical while being different
- Hide dangerous content behind invisible characters

### 11.3 Control Characters & Newlines

Stripping control characters and Unicode line separators prevents:
- Log file corruption
- Terminal escape exploits
- CSV and toolchain breakage

### 11.4 No File Content Changes

The script **never**:
- Modifies file contents
- Reads or interprets binary data

Its scope is strictly **names and paths**.

---

## 12. Real-World Usage Patterns

### 12.1 Audio Library Management

Representative use case:

- High-resolution WAV library (32-bit/192kHz)
- 3,555 files, 368 directories
- Organized by Artist / Album / Year / Format

Typical command:

```bash
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
CHECK_SHELL_SAFETY=false \
DRY_RUN=true \
./exfat-sanitizer-v9.0.2.2.sh /Users/username/Sync/Audio
```

Observations:
- No forbidden characters found in filenames
- 56 files exceeded path length limits
- Most issues from very long track titles and nested directories

### 12.2 Cross-Platform Sync

Use `FILESYSTEM=universal` when:
- Destination filesystem is unknown
- Data will be used on multiple OS and devices
- Safety and compatibility outweigh minimal changes

Typical configuration:

```bash
FILESYSTEM=universal \
SANITIZATION_MODE=strict \
CHECK_SHELL_SAFETY=true \
DRY_RUN=true \
./exfat-sanitizer-v9.0.2.2.sh ~/Downloads
```

### 12.3 Pre-Backup Validation

Before running a backup of a directory tree:

```bash
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
GENERATE_TREE=true \
DRY_RUN=true \
./exfat-sanitizer-v9.0.2.2.sh /data/archive
```

Use the CSV + tree output to:
- Identify problematic paths
- Fix a few key directories
- Rerun to confirm cleanliness

---

## 13. Extensibility & Future Directions

### 13.1 Pluggable Sanitization Steps

The pipeline in `sanitize_name()` is currently linear and fixed, but could be made **pluggable**:
- Ordered list of transformation steps
- Configurable enable/disable per step
- User-provided steps (plugins)

Potential interface:

```bash
SANITIZER_STEPS="universal,controls,fs-specific,shell,zero-width,reserved"
```

### 13.2 Rule Configuration via File

Instead of environment variables, allow a configuration file:

```ini
[defaults]
FILESYSTEM=exfat
SANITIZATION_MODE=conservative
CHECK_SHELL_SAFETY=false

[paths]
include=/Users/username/Sync/Audio
exclude=.DS_Store,Thumbs.db
```

### 13.3 Native exFAT Path Limits

Option to respect native exFAT limits instead of 260 chars:

```bash
STRICT_PATH_LIMITS=false  # Let exFAT be exFAT
```

### 13.4 Interactive & Undo Mode

Potential enhancements:
- Interactive confirmations
- Undo using CSV as a source of truth

```bash
./exfat-sanitizer-v9.0.2.2.sh --undo sanitizer_exfat_20260110_123456.csv
```

---

## 14. Developer Notes

### 14.1 Code Style

- Lowercase snake_case for functions
- `readonly` for constants
- `local` for function-scope variables
- `set -e` to catch unexpected errors early
- Colors used sparingly for clarity

### 14.2 Testing Strategy

Recommended tests:

- Unit-style tests for `sanitize_name()` input/output
- Integration tests for full tree runs
- Edge cases:
  - Empty directories
  - Filenames with only forbidden characters
  - Already-reserved names
  - Very deep nesting

### 14.3 Performance Considerations

Bottlenecks:
- `find` traversal on very large trees
- `grep` calls for collision detection
- CSV append operations

Optimizations:
- Minimize external process calls inside tight loops
- Consider batched operations if moving to more advanced environments

---

## 15. Glossary

- **Forbidden Characters**: Characters that a given filesystem does not allow in file or directory names.
- **Reserved Names**: Filenames that have special meaning, especially on Windows (e.g. `CON`, `PRN`).
- **Sanitization**: The process of transforming names to conform to filesystem rules.
- **Dry Run**: Mode where no actual changes happen; only logs are produced.
- **CSV Log**: Comma-separated file containing detailed record of actions.
- **Tree Export**: CSV representation of the directory hierarchy.
- **Shell Metacharacters**: Characters with special meaning to shells (e.g. `$`, `&`).

---

## 16. Summary

`exfat-sanitizer` is more than a simple rename script; it is a **filesystem-aware, safety-conscious, and audit-focused** tool for cross-platform filename hygiene.

Key characteristics:
- Multi-filesystem rules
- Configurable sanitization modes
- Conservative, compatibility-oriented path limits
- Rich logging and optional copy mode
- No external dependencies, pure bash

This document provides the **deep technical context** for understanding and extending the tool. For everyday usage, refer to:
- `README.md`
- `QUICK_START_GUIDE.md`
- `RELEASE-v9.0.2.2.md`

*Last updated: January 10, 2026 (v9.0.2.2)*
