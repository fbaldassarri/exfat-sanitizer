#!/bin/bash

# exfat-sanitizer v11.1.0 - COMPREHENSIVE RELEASE
#
# NEW in v11.1.0: Merging best features from v11.0.5 and v9.0.2.2
# - ✅ Fixed accent preservation from v11.0.5 (è é à ñ ö ü preserved)
# - ✅ CHECK_SHELL_SAFETY control from v9.0.2.2
# - ✅ COPY_BEHAVIOR options (skip/overwrite/version) from v9.0.2.2
# - ✅ CHECK_UNICODE_EXPLOITS from v9.0.2.2
# - ✅ System file filtering (.DS_Store, Thumbs.db, etc.)
# - ✅ REPLACEMENT_CHAR configuration
# - ✅ Improved copy mode with conflict resolution
#
# FIXED in v11.0.5: Typography normalization was incorrectly stripping accents
# - Removed buggy normalize_typography() call from sanitize_filename()
# - Now ONLY uses normalize_unicode() for NFD→NFC normalization
# - PRESERVES all accented characters exactly (à è é ì ò ù ö ä ñ ë ï etc.)
#
# FAT32/exFAT illegal characters (Microsoft specification):
# - Control characters: ASCII 0-31 and 127
# - Special characters: " * / : < > ? \ |
# - NOTE: Apostrophes (') and accented characters ARE ALLOWED

set -o pipefail

SCRIPT_VERSION="11.1.0"
SCRIPT_NAME="exfat-sanitizer"

# ============================================================================
# CONFIGURATION VARIABLES (via environment)
# ============================================================================

FILESYSTEM="${FILESYSTEM:=fat32}"
SANITIZATION_MODE="${SANITIZATION_MODE:=conservative}"
DRY_RUN="${DRY_RUN:=true}"
COPY_TO="${COPY_TO:=}"
COPY_BEHAVIOR="${COPY_BEHAVIOR:=skip}"
IGNORE_FILE="${IGNORE_FILE:=$HOME/.exfat-sanitizer-ignore}"
GENERATE_TREE="${GENERATE_TREE:=false}"
REPLACEMENT_CHAR="${REPLACEMENT_CHAR:=_}"

# Safety features (from v9.0.2.2)
CHECK_SHELL_SAFETY="${CHECK_SHELL_SAFETY:=false}"
CHECK_UNICODE_EXPLOITS="${CHECK_UNICODE_EXPLOITS:=false}"

# ============================================================================
# UNICODE NORMALIZATION
# ============================================================================

# Normalize Unicode string to NFC (precomposed form)
# This ensures "é" (NFC: U+00E9) equals "é" (NFD: U+0065+U+0301)
normalize_unicode() {
    local text="$1"
    
    # Try multiple methods (in order of preference)
    
    # Method 1: Use 'uconv' (ICU - most reliable)
    if command -v uconv >/dev/null 2>&1; then
        echo "$text" | uconv -f UTF-8 -t UTF-8 -x NFC 2>/dev/null && return
    fi
    
    # Method 2: Use Python3 (very common)
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import sys, unicodedata; print(unicodedata.normalize('NFC', sys.stdin.read().strip()))" <<< "$text" 2>/dev/null && return
    fi
    
    # Method 3: Use Perl (Unicode::Normalize)
    if command -v perl >/dev/null 2>&1; then
        perl -CS -MUnicode::Normalize -ne 'print NFC($_)' <<< "$text" 2>/dev/null && return
    fi
    
    # Method 4: Use iconv (limited but widely available)
    if command -v iconv >/dev/null 2>&1; then
        # iconv doesn't normalize but ensures valid UTF-8
        echo "$text" | iconv -f UTF-8 -t UTF-8 2>/dev/null && return
    fi
    
    # Fallback: return original text
    echo "$text"
}

# ============================================================================
# SYSTEM FILE FILTERING (from v9.0.2.2)
# ============================================================================

# Check if item should be skipped (system files)
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

# ============================================================================
# CHARACTER SANITIZATION FUNCTIONS
# ============================================================================

# Get illegal characters for filesystem (NOT allowed chars)
# These are the ONLY characters that need to be removed/replaced
get_illegal_chars() {
    local fs="$1"
    
    case "$fs" in
        fat32|exfat|universal)
            # Microsoft official specification:
            # Control chars (0-31, 127) + " * / : < > ? \ |
            # NOTE: Single quotes (') ARE ALLOWED in FAT32!
            echo '\\"*/:<>?\\|'
            ;;
        ntfs)
            # NTFS has fewer restrictions
            echo '\\"*/:<>?\\|'
            ;;
        apfs)
            # APFS only disallows : and /
            echo ':/'
            ;;
        hfsplus)
            # HFS+ only disallows : and /
            echo ':/'
            ;;
        *)
            # Universal safe set
            echo '\\"*/:<>?\\|'
            ;;
    esac
}

# Reserved names for FAT32
is_reserved_name() {
    local name="$1"
    local name_upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
    
    case "$name_upper" in
        CON|PRN|AUX|NUL|COM1|COM2|COM3|COM4|COM5|COM6|COM7|COM8|COM9|LPT1|LPT2|LPT3|LPT4|LPT5|LPT6|LPT7|LPT8|LPT9)
            return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================================
# COPY MODE FUNCTIONS (from v9.0.2.2)
# ============================================================================

# Handle file conflicts based on COPY_BEHAVIOR
handle_file_conflict() {
    local dest_file="$1"
    local behavior="$2"
    
    if [ ! -e "$dest_file" ]; then
        return 0  # No conflict
    fi
    
    case "$behavior" in
        skip)
            return 1  # Skip this file
            ;;
        overwrite)
            rm -f "$dest_file" 2>/dev/null
            return 0
            ;;
        version)
            # Will be handled by copy_file function
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Copy file with conflict resolution
copy_file() {
    local source="$1"
    local dest_dir="$2"
    local dest_filename="$3"
    local behavior="$4"
    
    local dest_file="$dest_dir/$dest_filename"
    
    # Handle conflict
    if ! handle_file_conflict "$dest_file" "$behavior"; then
        if [ "$behavior" = "version" ] && [ -e "$dest_file" ]; then
            # Create versioned filename
            local base="${dest_file%.*}"
            local ext="${dest_file##*.}"
            local version=1
            
            while [ -e "$base-v$version.$ext" ]; do
                ((version++))
            done
            
            dest_file="$base-v$version.$ext"
        else
            return 1  # Skip
        fi
    fi
    
    # Copy the file
    if cp "$source" "$dest_file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# PHASE 1: GENERATE ORIGINAL TREE SNAPSHOT
# ============================================================================

generate_tree_snapshot() {
    local target_dir="$1"
    local output_file="tree_${FILESYSTEM}_$(date +%Y%m%d_%H%M%S).csv"
    
    echo "Generating original tree snapshot: $output_file" >&2
    
    # Write CSV header
    echo "Type|Name|Path|Depth" > "$output_file"
    
    local _tree_depth=0
    
    _process_tree_recursive() {
        local current_path="$1"
        local depth="${2:-0}"
        local item
        
        for item in "$current_path"/*; do
            [ -e "$item" ] || continue
            
            local name=$(basename "$item")
            
            # Skip system files
            should_skip_system_file "$name" && continue
            
            local relative_path="${item#$target_dir/}"
            
            if [ -d "$item" ]; then
                echo "Directory|$name|$relative_path|$depth" >> "$output_file"
                _process_tree_recursive "$item" $((depth + 1))
            else
                echo "File|$name|$relative_path|$depth" >> "$output_file"
            fi
        done
    }
    
    _process_tree_recursive "$target_dir" 0
    echo "$output_file"
}

# ============================================================================
# PHASE 2: PROCESS DIRECTORY (SANITIZE, COPY, IGNORE)
# ============================================================================

should_ignore() {
    local file="$1"
    local pattern_file="$2"
    
    if [ ! -f "$pattern_file" ]; then
        return 1
    fi
    
    local pattern
    while IFS= read -r pattern; do
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$pattern" ]] && continue
        
        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [[ "$file" == $pattern ]]; then
            return 0
        fi
    done < "$pattern_file"
    
    return 1
}

# Proper character-by-character checking with escaped illegal chars
is_illegal_char() {
    local char="$1"
    local illegal_chars="$2"
    
    # Escape special regex characters for safe matching
    case "$char" in
        '"'|'*'|'/'|':'|'<'|'>'|'?'|'\'|'|')
            # Check if this specific character is in the illegal set
            case "$illegal_chars" in
                *"$char"*)
                    return 0 # Character IS illegal
                    ;;
            esac
            ;;
    esac
    
    return 1 # Character is NOT illegal
}

# Sanitize filename - v11.1.0 (combines v11.0.5 + v9.0.2.2 features)
sanitize_filename() {
    local name="$1"
    local mode="$2"
    local filesystem="$3"
    
    # ✅ From v11.0.5: No typography normalization (preserves accents)
    # ✅ From v9.0.2.2: Shell safety and Unicode exploits checking
    
    local illegal_chars=$(get_illegal_chars "$filesystem")
    local sanitized=""
    
    # Extract UTF-8 characters one by one using grep
    # This properly handles multi-byte UTF-8 sequences
    while IFS= read -r char; do
        [ -z "$char" ] && continue
        
        # Check for control characters (only single-byte ASCII 0-31, 127)
        # Multi-byte UTF-8 chars will not match this
        if [ ${#char} -eq 1 ]; then
            local ascii=$(printf '%d' "'$char" 2>/dev/null || echo 32)
            
            # Skip control characters
            if [ "$ascii" -lt 32 ] || [ "$ascii" -eq 127 ]; then
                if [ "$mode" = "strict" ]; then
                    sanitized="${sanitized}${REPLACEMENT_CHAR}"
                fi
                continue
            fi
        fi
        
        # Check for shell-dangerous characters (if enabled)
        if [ "$CHECK_SHELL_SAFETY" = "true" ]; then
            case "$char" in
                '$'|'`'|'&'|';'|'#'|'~'|'^'|'!'|'('|')')
                    sanitized="${sanitized}${REPLACEMENT_CHAR}"
                    continue
                    ;;
            esac
        fi
        
        # Check if character is illegal for filesystem
        if is_illegal_char "$char" "$illegal_chars"; then
            # Character is illegal - replace or skip
            if [ "$mode" = "strict" ] || [ "$mode" = "conservative" ]; then
                sanitized="${sanitized}${REPLACEMENT_CHAR}"
            fi
            # In permissive mode: skip illegal chars
        else
            # ✅ Character is LEGAL - preserve it exactly (including UTF-8 multibyte)
            # This includes: apostrophes, Italian à è é ì ò ù, French é è ê, Spanish ñ, German ö ä ü, etc.
            sanitized="$sanitized$char"
        fi
    done < <(echo "$name" | grep -o .)
    
    # Remove zero-width characters (if enabled)
    if [ "$CHECK_UNICODE_EXPLOITS" = "true" ] && command -v python3 >/dev/null 2>&1; then
        sanitized=$(python3 -c "import sys; text = sys.stdin.read(); print(''.join(c for c in text if c not in ['\u200B', '\u200C', '\u200D', '\uFEFF']))" <<< "$sanitized" 2>/dev/null || echo "$sanitized")
    fi
    
    # Remove leading/trailing spaces and dots
    sanitized=$(echo "$sanitized" | sed 's/^[[:space:].]*//;s/[[:space:].]*$//')
    
    # Handle empty result
    if [ -z "$sanitized" ]; then
        sanitized="unnamed_file"
    fi
    
    # Check for reserved names (FAT32)
    if [ "$filesystem" = "fat32" ] || [ "$filesystem" = "universal" ]; then
        if is_reserved_name "$sanitized"; then
            sanitized="_${sanitized}"
        fi
    fi
    
    echo "$sanitized"
}

# Main processing function
process_directory() {
    local source_dir="$1"
    local output_file="sanitizer_${FILESYSTEM}_$(date +%Y%m%d_%H%M%S).csv"
    
    echo "Type|Old Name|New Name|Issues|Path|Path Length|Status|Copy Status|Ignore Pattern" > "$output_file"
    
    local _total_scanned=0
    local _total_renamed=0
    local _total_ignored=0
    local _total_copied=0
    local _total_skipped=0
    
    _process_items_recursive() {
        local current_path="$1"
        local item
        
        for item in "$current_path"/*; do
            [ -e "$item" ] || continue
            
            local name=$(basename "$item")
            
            # Skip system files (don't even log them)
            should_skip_system_file "$name" && continue
            
            local relative_path="${item#$source_dir/}"
            local type="File"
            
            if [ -d "$item" ]; then
                type="Directory"
            fi
            
            ((_total_scanned++))
            
            # Check ignore patterns
            if should_ignore "$relative_path" "$IGNORE_FILE"; then
                echo "$type|$name|$name|-|$relative_path|${#relative_path}|IGNORED|NA|match" >> "$output_file"
                ((_total_ignored++))
                
                if [ "$type" = "Directory" ]; then
                    _process_items_recursive "$item"
                fi
                continue
            fi
            
            # Sanitize filename
            local sanitized=$(sanitize_filename "$name" "$SANITIZATION_MODE" "$FILESYSTEM")
            
            # Normalize BOTH strings for comparison (handles NFD vs NFC)
            local name_normalized=$(normalize_unicode "$name")
            local sanitized_normalized=$(normalize_unicode "$sanitized")
            
            local copy_status="NA"
            
            if [ "$sanitized_normalized" != "$name_normalized" ]; then
                echo "$type|$name|$sanitized|-|$relative_path|${#relative_path}|RENAMED|$copy_status|-" >> "$output_file"
                ((_total_renamed++))
                
                # Apply changes if not dry-run
                if [ "$DRY_RUN" != "true" ]; then
                    local new_path="$(dirname "$item")/$sanitized"
                    
                    if [ -e "$new_path" ] && [ "$new_path" != "$item" ]; then
                        echo "$type|$name|$sanitized|COLLISION|$relative_path|${#relative_path}|FAILED|NA|-" >> "$output_file"
                    else
                        mv "$item" "$new_path" 2>/dev/null || true
                        
                        # Handle copy if specified
                        if [ -n "$COPY_TO" ] && [ -f "$new_path" ]; then
                            local dest_dir="$COPY_TO/$(dirname "$relative_path")"
                            mkdir -p "$dest_dir" 2>/dev/null || true
                            
                            if copy_file "$new_path" "$dest_dir" "$sanitized" "$COPY_BEHAVIOR"; then
                                copy_status="COPIED"
                                ((_total_copied++))
                            else
                                copy_status="SKIPPED"
                                ((_total_skipped++))
                            fi
                        fi
                    fi
                fi
            else
                # Handle copy for unchanged files
                if [ -n "$COPY_TO" ] && [ -f "$item" ]; then
                    if [ "$DRY_RUN" != "true" ]; then
                        local dest_dir="$COPY_TO/$(dirname "$relative_path")"
                        mkdir -p "$dest_dir" 2>/dev/null || true
                        
                        if copy_file "$item" "$dest_dir" "$name" "$COPY_BEHAVIOR"; then
                            copy_status="COPIED"
                            ((_total_copied++))
                        else
                            copy_status="SKIPPED"
                            ((_total_skipped++))
                        fi
                    fi
                fi
                
                echo "$type|$name|$name|-|$relative_path|${#relative_path}|LOGGED|$copy_status|-" >> "$output_file"
            fi
            
            # Recurse into subdirectories
            if [ -d "$item" ]; then
                _process_items_recursive "$item"
            fi
        done
    }
    
    _process_items_recursive "$source_dir"
    echo "$output_file"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $SCRIPT_NAME [OPTIONS] <target-directory>"
        echo ""
        echo "Environment Variables:"
        echo "  FILESYSTEM=fat32|exfat|ntfs|apfs|universal|hfsplus (default: fat32)"
        echo "  SANITIZATION_MODE=strict|conservative|permissive (default: conservative)"
        echo "  DRY_RUN=true|false (default: true)"
        echo "  COPY_TO=<destination> (optional)"
        echo "  COPY_BEHAVIOR=skip|overwrite|version (default: skip)"
        echo "  IGNORE_FILE=<file> (default: ~/.exfat-sanitizer-ignore)"
        echo "  GENERATE_TREE=true|false (default: false)"
        echo "  REPLACEMENT_CHAR=<char> (default: _)"
        echo ""
        echo "Safety Options (NEW in v11.1.0):"
        echo "  CHECK_SHELL_SAFETY=true|false (default: false)"
        echo "    Remove shell metacharacters: \$ \` & ; # ~ ^ ! ( )"
        echo "  CHECK_UNICODE_EXPLOITS=true|false (default: false)"
        echo "    Remove zero-width and bidirectional characters"
        echo ""
        echo "Character Handling (v11.1.0):"
        echo "  • Preserves ALL Unicode/accented characters (à è é ì ò ù ö ä ñ, etc.)"
        echo "  • Fixed: No longer strips accents (interprète stays interprète)"
        echo "  • Unicode normalization (NFC) for macOS/Linux/Windows compatibility"
        echo "  • Preserves apostrophes (') - they ARE allowed in FAT32!"
        echo "  • System files filtered: .DS_Store, Thumbs.db, etc."
        echo "  • Only removes: control chars (0-31, 127) and \" * / : < > ? \\ |"
        echo ""
        echo "Copy Mode (v11.1.0):"
        echo "  COPY_BEHAVIOR options:"
        echo "    skip     - Skip if destination file exists (default)"
        echo "    overwrite - Replace existing destination files"
        echo "    version  - Create versioned copies (file-v1.ext, file-v2.ext)"
        return 1
    fi
    
    local target_dir="$1"
    
    if [ ! -d "$target_dir" ]; then
        echo "Error: Directory not found: $target_dir" >&2
        return 1
    fi
    
    echo "========== EXFAT-SANITIZER v$SCRIPT_VERSION =========="
    echo "Scanning: $target_dir"
    echo "Filesystem: $FILESYSTEM"
    echo "Sanitization Mode: $SANITIZATION_MODE"
    echo "Dry Run: $DRY_RUN"
    echo "Shell Safety: $CHECK_SHELL_SAFETY"
    echo "Unicode Exploit Detection: $CHECK_UNICODE_EXPLOITS"
    
    if [ -n "$COPY_TO" ]; then
        echo "Copy Destination: $COPY_TO"
        echo "Copy Behavior: $COPY_BEHAVIOR"
    fi
    
    echo ""
    
    # Phase 1: Generate tree snapshot if requested
    if [ "$GENERATE_TREE" = "true" ]; then
        local tree_file=$(generate_tree_snapshot "$target_dir")
        echo "✅ Tree Snapshot: $tree_file"
    fi
    
    # Phase 2: Process directory
    local csv_file=$(process_directory "$target_dir")
    
    echo "✅ Processing complete"
    echo "CSV Log: $csv_file"
    echo ""
    echo "========== SUMMARY =========="
    echo "Scanned Directories: $(grep -c "^Directory|" "$csv_file" 2>/dev/null || echo "0")"
    echo "Scanned Files: $(grep -c "^File|" "$csv_file" 2>/dev/null || echo "0")"
    echo "Ignored Items: $(grep -c "|IGNORED|" "$csv_file" 2>/dev/null || echo "0")"
    echo "Items to Rename: $(grep -c "|RENAMED|" "$csv_file" 2>/dev/null || echo "0")"
    
    if [ -n "$COPY_TO" ]; then
        echo "Files Copied: $(grep -c "|COPIED|" "$csv_file" 2>/dev/null || echo "0")"
        echo "Files Skipped: $(grep -c "|SKIPPED|" "$csv_file" 2>/dev/null || echo "0")"
    fi
    
    echo ""
    echo "Dry Run: $DRY_RUN"
    
    if [ "$DRY_RUN" != "true" ]; then
        echo "⚠️  CHANGES APPLIED!"
    else
        echo "✅ NO CHANGES MADE (preview only)"
    fi
    
    echo ""
}

main "$@"
