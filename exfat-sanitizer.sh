#!/bin/bash

################################################################################
# exfat-sanitizer v9.0.2.2 - Cross-Platform Filename Sanitizer
# CRITICAL BUGFIX: DRY_RUN now properly respects copy behavior
# 
# v9.0.2.2 fixes the bug where files were being copied to COPY_TO destination
# even when DRY_RUN=true. When DRY_RUN=true + COPY_TO set, only VALIDATES but
# does NOT actually copy files.
#
# Previous version incorrectly flagged all files as reserved.
# Changed pattern matching to use exact word boundaries and proper
# base name extraction before checking against Windows/DOS reserved names.
#
# Bash 3.2+ compatible - works on macOS and all Linux systems
################################################################################

set -e

################################################################################
# CONFIGURATION
################################################################################

readonly SCRIPT_VERSION="9.0.2.2"
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Titles - for documentation/readability
: "CONFIGURATION"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

: "Colors for output"

# Filesystem modes (exfat, fat32, apfs, ntfs, hfsplus, universal)
readonly FILESYSTEM="${FILESYSTEM:-universal}"

: "Filesystem modes: exfat, fat32, apfs, ntfs, hfsplus, universal"

# Sanitization modes (strict, conservative, permissive)
readonly SANITIZATION_MODE="${SANITIZATION_MODE:-strict}"

: "Sanitization modes: strict, conservative, permissive"

readonly DRY_RUN="${DRY_RUN:-true}"
readonly COPY_TO="${COPY_TO:-}"
readonly COPY_BEHAVIOR="${COPY_BEHAVIOR:-skip}"
readonly REPLACEMENT_CHAR="${REPLACEMENT_CHAR:-_}"
readonly GENERATE_TREE="${GENERATE_TREE:-false}"

: "Other configuration"

# Safety features
readonly CHECK_SHELL_SAFETY="${CHECK_SHELL_SAFETY:-true}"
readonly CHECK_UNICODE_EXPLOITS="${CHECK_UNICODE_EXPLOITS:-false}"
readonly CHECK_NORMALIZATION="${CHECK_NORMALIZATION:-false}"

: "Safety features"

# Temp directory for counters
TEMP_COUNTER_DIR=""

: "Temp directory for counters"

################################################################################
# TEMP COUNTER FUNCTIONS
################################################################################

init_temp_counters() {
    TEMP_COUNTER_DIR=$(mktemp -d)
    if [[ -z "$TEMP_COUNTER_DIR" ]]; then
        echo -e "${RED}Error: Failed to create temp counter directory${NC}" >&2
        return 1
    fi

    local counters=(
        total_items scanned_dirs scanned_files invalid_dirs invalid_files
        renamed_dirs renamed_files failed_dirs failed_files path_length_issues
        copied_dirs copied_files skipped_items failed_items
    )

    for counter in "${counters[@]}"; do
        echo 0 > "$TEMP_COUNTER_DIR/$counter"
    done
}

increment_counter() {
    local counter="$1"
    local value
    value=$(cat "$TEMP_COUNTER_DIR/$counter" 2>/dev/null || echo 0)
    echo $((value + 1)) > "$TEMP_COUNTER_DIR/$counter"
}

get_counter() {
    local counter="$1"
    cat "$TEMP_COUNTER_DIR/$counter" 2>/dev/null || echo 0
}

cleanup_temp_counters() {
    if [[ -n "$TEMP_COUNTER_DIR" ]] && [[ -d "$TEMP_COUNTER_DIR" ]]; then
        rm -rf "$TEMP_COUNTER_DIR"
    fi
}

trap cleanup_temp_counters EXIT

: "TEMP COUNTER FUNCTIONS"

################################################################################
# CSV FUNCTIONS
################################################################################

init_csv() {
    local csv_file="sanitizer_${FILESYSTEM}_$(date +%Y%m%d_%H%M%S).csv"
    echo "Type,Old Name,New Name,Issues,Path,Path Length,Status,Copy_Status" > "$csv_file"
    echo "$csv_file"
}

log_to_csv() {
    local csv_file="$1"
    local type="$2"
    local old_name="$3"
    local new_name="$4"
    local issues="$5"
    local path="$6"
    local path_length="$7"
    local status="$8"
    local copy_status="${9:-N/A}"

    old_name="${old_name//\"/\"\"}"
    new_name="${new_name//\"/\"\"}"
    issues="${issues//\"/\"\"}"

    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$type" "$old_name" "$new_name" "$issues" "$path" "$path_length" "$status" "$copy_status" >> "$csv_file"
}

: "CSV FUNCTIONS"

################################################################################
# TREE CSV FUNCTIONS
################################################################################

generate_tree_csv() {
    local root_dir="$1"
    local tree_csv="tree_${FILESYSTEM}_$(date +%Y%m%d_%H%M%S).csv"
    echo "Type,Name,Path,Depth,Has Children" > "$tree_csv"

    find "$root_dir" -print0 2>/dev/null | while IFS= read -r -d '' item; do
        local type="File"
        local name
        name=$(basename "$item")
        local path
        path="${item#$root_dir}"
        path="${path#/}"
        local depth
        depth=$(echo "$path" | tr -cd '/' | wc -c)
        local has_children="No"

        if [[ -d "$item" ]]; then
            type="Directory"
            if [[ -n $(find "$item" -maxdepth 1 \( -type f -o -type d \) ! -name "$item" 2>/dev/null) ]]; then
                has_children="Yes"
            fi
        fi

        printf '%s,%s,%s,%s,%s\n' "$type" "$name" "$path" "$depth" "$has_children" >> "$tree_csv"
    done

    echo "$tree_csv"
}

: "TREE CSV FUNCTIONS"

################################################################################
# PATH LENGTH VALIDATION
################################################################################

check_path_length() {
    local path="$1"
    local filesystem="$2"

    local max_length
    case "$filesystem" in
        fat32|exfat)
            max_length=260
            ;;
        apfs|ntfs|hfsplus)
            max_length=255
            ;;
        universal)
            max_length=260
            ;;
        *)
            max_length=255
            ;;
    esac

    if [[ ${#path} -gt $max_length ]]; then
        return 1
    fi

    return 0
}

: "PATH LENGTH VALIDATION"

################################################################################
# COLLISION DETECTION
################################################################################

USED_PATHS_FILE=""

register_path() {
    local path="$1"
    echo "$path" >> "$USED_PATHS_FILE"
}

is_path_used() {
    local path="$1"
    grep -Fxq "$path" "$USED_PATHS_FILE" 2>/dev/null && return 0 || return 1
}

: "COLLISION DETECTION"

################################################################################
# SYSTEM FILES TO SKIP
################################################################################

should_skip_item() {
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

: "Files that should be silently ignored - not processed, not renamed, not in CSV"

################################################################################
# COPY MODE FUNCTIONS
################################################################################

validate_destination_path() {
    local dest="$1"

    if [[ -z "$dest" ]]; then
        echo -e "${RED}Error: COPY_TO not set${NC}" >&2
        return 1
    fi

    if [[ -e "$dest" ]] && [[ ! -d "$dest" ]]; then
        echo -e "${RED}Error: Destination exists but is not a directory: $dest${NC}" >&2
        return 1
    fi

    if [[ ! -d "$dest" ]]; then
        if ! mkdir -p "$dest" 2>/dev/null; then
            echo -e "${RED}Error: Cannot create destination directory: $dest${NC}" >&2
            return 1
        fi
    fi

    if [[ ! -w "$dest" ]]; then
        echo -e "${RED}Error: No write permission for destination: $dest${NC}" >&2
        return 1
    fi

    return 0
}

estimate_disk_space() {
    local source="$1"
    local dest="$2"

    local source_size
    source_size=$(du -sb "$source" 2>/dev/null | awk '{print $1}')
    source_size=${source_size:-0}

    local dest_free
    dest_free=$(df "$dest" 2>/dev/null | awk 'NR==2 {print $4 * 1024}')
    dest_free=${dest_free:-0}

    if [[ $dest_free -gt 0 ]] && [[ $source_size -gt 0 ]]; then
        local margin=$((dest_free - source_size))

        if [[ $margin -lt 0 ]]; then
            echo -e "${RED}Error: Insufficient disk space. Need $((source_size / 1024 / 1024))MB, Available $((dest_free / 1024 / 1024))MB${NC}" >&2
            return 1
        fi

        if [[ $margin -lt $((source_size / 10)) ]]; then
            echo -e "${YELLOW}Warning: Limited disk space: $((margin / 1024 / 1024))MB margin${NC}" >&2
        fi
    fi

    return 0
}

: "COPY MODE FUNCTIONS"

handle_file_conflict() {
    local dest_file="$1"
    local behavior="$2"

    if [[ ! -e "$dest_file" ]]; then
        return 0
    fi

    case "$behavior" in
        skip)
            return 1
            ;;
        overwrite)
            rm -f "$dest_file"
            return 0
            ;;
        version)
            local base="${dest_file%.*}"
            local ext="${dest_file##*.}"
            local version=1

            while [[ -e "$base-v$version.$ext" ]]; do
                ((version++))
            done

            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

cleanup_partial_file() {
    local file="$1"
    [[ -f "$file" ]] && rm -f "$file" 2>/dev/null
    true
}

: "COPY MODE FUNCTIONS"

copy_file() {
    local source="$1"
    local dest_dir="$2"
    local dest_filename="$3"
    local csv_file="$4"
    local behavior="$5"

    local dest_file="$dest_dir/$dest_filename"

    if ! handle_file_conflict "$dest_file" "$behavior"; then
        if [[ "$behavior" == "version" ]] && [[ -e "$dest_file" ]]; then
            local base="${dest_file%.*}"
            local ext="${dest_file##*.}"
            local version=1

            while [[ -e "$base-v$version.$ext" ]]; do
                ((version++))
            done

            dest_file="$base-v$version.$ext"
        else
            log_to_csv "$csv_file" "File" "$(basename "$source")" "$dest_filename" "" "$dest_dir" "${#dest_file}" "LOGGED" "SKIPPED"
            increment_counter "skipped_items"
            return 0
        fi
    fi

    if cp "$source" "$dest_file" 2>/dev/null; then
        log_to_csv "$csv_file" "File" "$(basename "$source")" "$dest_filename" "" "$dest_dir" "${#dest_file}" "LOGGED" "COPIED"
        increment_counter "copied_files"
        return 0
    else
        cleanup_partial_file "$dest_file"
        log_to_csv "$csv_file" "File" "$(basename "$source")" "$dest_filename" "Copy failed" "$dest_dir" "${#dest_file}" "LOGGED" "FAILED"
        increment_counter "failed_items"
        return 1
    fi
}

: "COPY MODE FUNCTIONS"

################################################################################
# SANITIZATION FUNCTION - v9.0.2.2 (CRITICAL BUGFIX - OUTPUT FORMAT)
################################################################################

sanitize_name() {
    local name="$1"
    local filesystem="${2:-$FILESYSTEM}"
    local mode="${3:-$SANITIZATION_MODE}"
    local shell_safe="${4:-$CHECK_SHELL_SAFETY}"
    
    local sanitized="$name"
    local issues=""

    : "NAME SANITIZATION - ENHANCED v9.0.2.2"

    # Step 1: Universal forbidden characters (ALL filesystems)
    local universal_forbidden='[<>:"/\\|?*]'
    if [[ "$sanitized" =~ $universal_forbidden ]]; then
        sanitized=$(printf '%s' "$sanitized" | sed "s/$universal_forbidden/$REPLACEMENT_CHAR/g")
        issues="${issues},UniversalForbidden"
    fi

    : "Step 1: Universal forbidden characters (ALL filesystems)"

    # Step 2: Control characters (CRITICAL - strict mode or NTFS)
    if [[ "$mode" == "strict" ]] || [[ "$filesystem" == "ntfs" ]]; then
        if echo "$sanitized" | grep -q '[[:cntrl:]]' 2>/dev/null; then
            sanitized=$(printf '%s' "$sanitized" | sed 's/[[:cntrl:]]//g')
            [[ ! "$issues" =~ "ControlChars" ]] && issues="${issues},ControlChars"
        fi
    fi

    : "Step 2: Control characters (CRITICAL - strict mode or NTFS)"

    # Step 3: Unicode line separators (CRITICAL)
    if [[ "$mode" != "permissive" ]]; then
        if echo "$sanitized" | grep -qP '\x0A|\x0D|\x85|\u2028|\u2029' 2>/dev/null; then
            sanitized=$(printf '%s' "$sanitized" | sed 's/[\x0A\x0D\x85]//g')
            [[ ! "$issues" =~ "UnicodeNewlines" ]] && issues="${issues},UnicodeNewlines"
        fi
    fi

    : "Step 3: Unicode line separators (CRITICAL)"

    # Step 4: Filesystem-specific restrictions
    case "$filesystem" in
        fat32)
            local fat32_specific='[+,;=\[\]÷×]'
            if [[ "$sanitized" =~ $fat32_specific ]]; then
                sanitized=$(printf '%s' "$sanitized" | sed "s/$fat32_specific/$REPLACEMENT_CHAR/g")
                [[ ! "$issues" =~ "FAT32Specific" ]] && issues="${issues},FAT32Specific"
            fi
            ;;
        exfat)
            : "exFAT allows more characters than FAT32"
            ;;
        apfs)
            : "APFS has fewer restrictions"
            ;;
        ntfs)
            : "NTFS has additional control character restrictions (handled above)"
            ;;
        hfsplus)
            if [[ "$sanitized" =~ : ]]; then
                sanitized="${sanitized//:/ }"
                [[ ! "$issues" =~ "HFSColon" ]] && issues="${issues},HFSColon"
            fi
            ;;
        universal)
            local fat32_specific='[+,;=\[\]÷×]'
            if [[ "$sanitized" =~ $fat32_specific ]]; then
                sanitized=$(printf '%s' "$sanitized" | sed "s/$fat32_specific/$REPLACEMENT_CHAR/g")
                [[ ! "$issues" =~ "FAT32Specific" ]] && issues="${issues},FAT32Specific"
            fi
            ;;
    esac

    : "Apply most restrictive (FAT32)"

    # Step 5: Shell metacharacters (optional safety feature)
    if [[ "$shell_safe" == "true" ]] || [[ "$mode" == "strict" ]]; then
        local shell_dangerous='[$`&;#~^!()]'
        if [[ "$sanitized" =~ $shell_dangerous ]]; then
            sanitized=$(printf '%s' "$sanitized" | sed "s/$shell_dangerous/$REPLACEMENT_CHAR/g")
            [[ ! "$issues" =~ "ShellDangerous" ]] && issues="${issues},ShellDangerous"
        fi
    fi

    : "Step 5: Shell metacharacters (optional safety feature)"

    # Step 6: Zero-width characters (optional advanced feature)
    if [[ "$CHECK_UNICODE_EXPLOITS" == "true" ]]; then
        if echo "$sanitized" | grep -qP '\u200B|\u200C|\u200D' 2>/dev/null; then
            sanitized=$(printf '%s' "$sanitized" | sed 's/[\u200B\u200C\u200D]//g')
            [[ ! "$issues" =~ "ZeroWidth" ]] && issues="${issues},ZeroWidth"
        fi
    fi

    : "Step 6: Zero-width characters (optional advanced feature)"

    # Step 7: Leading/trailing problematic characters
    if [[ "$sanitized" =~ ^\. ]]; then
        sanitized="${sanitized:1}"
        [[ ! "$issues" =~ "LeadingInvalid" ]] && issues="${issues},LeadingInvalid"
    fi

    if [[ "$sanitized" =~ \?$ ]]; then
        sanitized="${sanitized%\?}"
        [[ ! "$issues" =~ "TrailingInvalid" ]] && issues="${issues},TrailingInvalid"
    fi

    : "Step 7: Leading/trailing problematic characters"

    # =========================================================================
    # Step 8: Reserved names (Windows/DOS) - BUGFIX v9.0.2 - COMPAT VERSION
    # =========================================================================
    # COMPATIBILITY FIX: Using tr instead of ${var^^} for bash 3.2 compatibility
    # - Extract base name (filename without extension)
    # - Check if base name (case-insensitive) is EXACTLY a reserved word
    # - Preserve extension properly
    # - Only applies to specific filesystems
    # =========================================================================
    
    if [[ "$filesystem" =~ (ntfs|fat32|exfat|universal) ]]; then
        # Extract base name and extension
        local base_name="${sanitized%.*}"
        local extension="${sanitized##*.}"
        
        # If no extension was found, extension will equal the whole filename
        if [[ "$base_name" == "$sanitized" ]]; then
            extension=""  # No extension found
        fi
        
        # Check if base name (case-insensitive) is EXACTLY a reserved name
        # Using tr to convert to uppercase for maximum compatibility
        # Using ^ and $ for start/end anchors, ensuring exact match only
        local base_name_upper
        base_name_upper=$(echo "$base_name" | tr '[:lower:]' '[:upper:]')
        
        if [[ "$base_name_upper" =~ ^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]|\.\.?)$ ]]; then
            # Add reserved suffix before extension
            if [[ -n "$extension" ]]; then
                sanitized="${base_name}-reserved.${extension}"
            else
                sanitized="${base_name}-reserved"
            fi
            [[ ! "$issues" =~ "ReservedName" ]] && issues="${issues},ReservedName"
        fi
    fi

    : "Step 8: Reserved names (Windows/DOS) - FIXED v9.0.2.2 - COMPAT"

    # Handle edge case: fully sanitized to empty
    [[ -z "$sanitized" ]] && sanitized="$REPLACEMENT_CHAR"

    # =========================================================================
    # CRITICAL FIX v9.0.2.1: Proper output format for IFS parsing
    # =========================================================================
    # Output format: "NEW_NAME|HAD_CHANGES|ISSUES"
    # Using pipe delimiter to avoid issues with spaces in filenames
    # Had_changes is 1 (true) or 0 (false)
    # =========================================================================
    
    local had_changes=0
    [[ "$sanitized" != "$name" ]] && had_changes=1
    
    echo "$sanitized|$had_changes|$issues"
}

################################################################################
# VALIDATION FUNCTIONS
################################################################################

validate_filesystem() {
    local fs="$1"

    case "$fs" in
        fat32|exfat|apfs|ntfs|hfsplus|universal)
            return 0
            ;;
        *)
            echo -e "${RED}Error: Invalid filesystem: $fs${NC}" >&2
            echo "Valid options: fat32, exfat, apfs, ntfs, hfsplus, universal" >&2
            return 1
            ;;
    esac
}

validate_sanitization_mode() {
    local mode="$1"

    case "$mode" in
        strict|conservative|permissive)
            return 0
            ;;
        *)
            echo -e "${RED}Error: Invalid SANITIZATION_MODE: $mode${NC}" >&2
            echo "Valid options: strict, conservative, permissive" >&2
            return 1
            ;;
    esac
}

validate_copy_behavior() {
    local behavior="$1"

    case "$behavior" in
        skip|overwrite|version)
            return 0
            ;;
        *)
            echo -e "${RED}Error: Invalid COPY_BEHAVIOR: $behavior${NC}" >&2
            echo "Valid options: skip, overwrite, version" >&2
            return 1
            ;;
    esac
}

validate_inputs() {
    validate_filesystem "$FILESYSTEM" || return 1
    validate_sanitization_mode "$SANITIZATION_MODE" || return 1
    [[ -n "$COPY_TO" ]] && validate_copy_behavior "$COPY_BEHAVIOR" || return 0

    return 0
}

: "VALIDATION FUNCTIONS"

################################################################################
# DIRECTORY PROCESSING
################################################################################

process_directory_names() {
    local root_dir="$1"
    local csv_file="$2"

    find "$root_dir" -type d -print0 2>/dev/null | sort -z -r | while IFS= read -r -d '' dir; do
        increment_counter "scanned_dirs"

        local dirname
        dirname=$(basename "$dir")

        # Skip system directories - don't process or log these
        if should_skip_item "$dirname"; then
            continue  # Silently skip, not even in CSV
        fi

        local parent_dir
        parent_dir=$(dirname "$dir")

        local sanitize_result
        sanitize_result=$(sanitize_name "$dirname" "$FILESYSTEM" "$SANITIZATION_MODE" "$CHECK_SHELL_SAFETY")

        # Parse result: NEW_NAME|HAD_CHANGES|ISSUES
        local new_dirname had_changes issues
        IFS='|' read -r new_dirname had_changes issues <<< "$sanitize_result"

        if [[ "$had_changes" == "1" ]]; then
            local new_path="$parent_dir/$new_dirname"

            if check_path_length "$new_path" "$FILESYSTEM"; then
                if ! is_path_used "$new_path"; then
                    if [[ "$DRY_RUN" != "true" ]]; then
                        if mv "$dir" "$new_path" 2>/dev/null; then
                            log_to_csv "$csv_file" "Directory" "$dirname" "$new_dirname" "$issues" "$parent_dir" "${#new_path}" "RENAMED"
                            register_path "$new_path"
                            increment_counter "renamed_dirs"
                        else
                            log_to_csv "$csv_file" "Directory" "$dirname" "$new_dirname" "$issues" "$parent_dir" "${#new_path}" "FAILED"
                            increment_counter "failed_dirs"
                        fi
                    else
                        log_to_csv "$csv_file" "Directory" "$dirname" "$new_dirname" "$issues" "$parent_dir" "${#new_path}" "RENAMED"
                    fi
                fi
            else
                log_to_csv "$csv_file" "Directory" "$dirname" "$new_dirname" "Path too long" "$parent_dir" "${#new_path}" "FAILED"
                increment_counter "path_length_issues"
                increment_counter "failed_dirs"
            fi
        else
            register_path "$dir"
            log_to_csv "$csv_file" "Directory" "$dirname" "$dirname" "" "$parent_dir" "${#dir}" "LOGGED"
        fi
    done
}

: "DIRECTORY PROCESSING"

################################################################################
# FILE PROCESSING - BUGFIX v9.0.2.2
################################################################################

process_files() {
    local root_dir="$1"
    local csv_file="$2"
    local copy_dest="${3:-}"

    find "$root_dir" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
        increment_counter "scanned_files"

        local count
        count=$(get_counter "scanned_files")

        if (( count % 100 == 0 )); then
            echo -e "${CYAN}Processed $count files...${NC}"
        fi

        local filename
        filename=$(basename "$file")

        # Skip system files - don't process or log these
        if should_skip_item "$filename"; then
            continue  # Silently skip, not even in CSV
        fi

        local parent_dir
        parent_dir=$(dirname "$file")

        local sanitize_result
        sanitize_result=$(sanitize_name "$filename" "$FILESYSTEM" "$SANITIZATION_MODE" "$CHECK_SHELL_SAFETY")

        # Parse result: NEW_NAME|HAD_CHANGES|ISSUES
        local new_filename had_changes issues
        IFS='|' read -r new_filename had_changes issues <<< "$sanitize_result"

        local new_path="$parent_dir/$new_filename"

        if check_path_length "$new_path" "$FILESYSTEM"; then
            if [[ "$had_changes" == "1" ]]; then
                # File needs renaming
                if [[ "$DRY_RUN" != "true" ]]; then
                    # REAL RUN: Actually rename the file
                    if mv "$file" "$new_path" 2>/dev/null; then
                        if [[ -n "$copy_dest" ]]; then
                            # ONLY copy if DRY_RUN is false
                            local rel_dir="${parent_dir#$root_dir}"
                            rel_dir="${rel_dir#/}"
                            local dest_dir="$copy_dest/$rel_dir"

                            mkdir -p "$dest_dir" 2>/dev/null || true
                            copy_file "$new_path" "$dest_dir" "$new_filename" "$csv_file" "$COPY_BEHAVIOR"
                        else
                            log_to_csv "$csv_file" "File" "$filename" "$new_filename" "$issues" "$parent_dir" "${#new_path}" "RENAMED" "N/A"
                        fi

                        increment_counter "renamed_files"
                    else
                        log_to_csv "$csv_file" "File" "$filename" "$new_filename" "$issues" "$parent_dir" "${#new_path}" "FAILED" "N/A"
                    fi
                else
                    # DRY RUN: Don't rename or copy, just log what would happen
                    if [[ -n "$copy_dest" ]]; then
                        log_to_csv "$csv_file" "File" "$filename" "$new_filename" "$issues" "$parent_dir" "${#new_path}" "RENAMED" "WOULD_COPY"
                    else
                        log_to_csv "$csv_file" "File" "$filename" "$new_filename" "$issues" "$parent_dir" "${#new_path}" "RENAMED" "N/A"
                    fi
                fi
            else
                # File doesn't need renaming
                if [[ -n "$copy_dest" ]]; then
                    if [[ "$DRY_RUN" != "true" ]]; then
                        # REAL RUN: Copy file as-is
                        local rel_dir="${parent_dir#$root_dir}"
                        rel_dir="${rel_dir#/}"
                        local dest_dir="$copy_dest/$rel_dir"

                        mkdir -p "$dest_dir" 2>/dev/null || true
                        copy_file "$file" "$dest_dir" "$new_filename" "$csv_file" "$COPY_BEHAVIOR"
                    else
                        # DRY RUN: Don't copy, just log what would happen
                        log_to_csv "$csv_file" "File" "$filename" "$filename" "" "$parent_dir" "${#new_path}" "LOGGED" "WOULD_COPY"
                    fi
                else
                    log_to_csv "$csv_file" "File" "$filename" "$filename" "" "$parent_dir" "${#new_path}" "LOGGED" "N/A"
                fi
            fi
        else
            log_to_csv "$csv_file" "File" "$filename" "$new_filename" "Path too long" "$parent_dir" "${#new_path}" "FAILED" "N/A"
            increment_counter "path_length_issues"
            increment_counter "failed_files"
        fi
    done
}

: "FILE PROCESSING - BUGFIX v9.0.2.2"

################################################################################
# HELP FUNCTION
################################################################################

print_help() {
    cat << 'EOF'
exfat-sanitizer v9.0.2.2-COMPAT - Cross-Platform Filename Sanitizer
Production-Ready Implementation - Bugfix Release (Bash 3.2 Compatible)

USAGE:
  FILESYSTEM=<fs> SANITIZATION_MODE=<mode> DRY_RUN=<bool> \
    ./exfat-sanitizer-v9.0.2.2-COMPAT.sh <directory>

FILESYSTEMS:
  exfat    - exFAT restrictions (removable media, flexible)
  fat32    - FAT32 restrictions (older USB drives, legacy)
  apfs     - APFS restrictions (macOS Sonoma, native)
  ntfs     - NTFS restrictions (Windows, strict)
  hfsplus  - HFS restrictions (legacy macOS)
  universal - Most restrictive (unknown destination) [DEFAULT]

SANITIZATION MODES:
  strict        - Remove all problematic chars (including shell-dangerous) [DEFAULT]
  conservative  - Remove only officially-forbidden chars per filesystem
  permissive    - Remove only universal forbidden chars (fastest, least safe)

SAFETY OPTIONS:
  CHECK_SHELL_SAFETY=<true|false>     - Remove $, `, &, ;, #, ~, ^, !, ( ) [DEFAULT: true]
  CHECK_UNICODE_EXPLOITS=<true|false> - Remove zero-width, bidirectional [DEFAULT: false]
  CHECK_NORMALIZATION=<true|false>    - Detect NFC/NFD differences [DEFAULT: false]

COPY MODE OPTIONS:
  COPY_TO=<path>          - Copy sanitized files to destination
  COPY_BEHAVIOR=<mode>    - How to handle conflicts: skip, overwrite, version [DEFAULT: skip]

OTHER OPTIONS:
  DRY_RUN=<true|false>    - Preview changes without modifying [DEFAULT: true]
  REPLACEMENT_CHAR=<char> - Character for replacing forbidden chars [DEFAULT: _]
  GENERATE_TREE=<true|false> - Export directory tree structure [DEFAULT: false]

DRY_RUN BEHAVIOR WITH COPY_TO:
  When both DRY_RUN=true AND COPY_TO is set:
  - ✅ Validates destination path
  - ✅ Checks available disk space
  - ✅ Validates target filesystem compatibility
  - ✅ Sanitizes and logs all filenames
  - ✅ Logs what WOULD be copied
  - ❌ Does NOT actually copy any files

COMPATIBILITY:
  This version uses pipe-delimited output and tr for bash 3.2 compatibility.
  Works on macOS, older Linux systems, and all modern systems.

VERSION: 9.0.2.2-COMPAT
LICENSE: MIT
EOF
}

: "HELP FUNCTION"

################################################################################
# MAIN FUNCTION
################################################################################

main() {
    local root_dir="${1:-.}"

    if [[ "$root_dir" == "-h" ]] || [[ "$root_dir" == "--help" ]]; then
        print_help
        return 0
    fi

    if [[ ! -d "$root_dir" ]]; then
        echo -e "${RED}Error: Source directory not found: $root_dir${NC}" >&2
        return 1
    fi

    validate_inputs || return 1
    init_temp_counters || return 1

    USED_PATHS_FILE=$(mktemp) || return 1
    trap "rm -f $USED_PATHS_FILE" RETURN

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}exfat-sanitizer v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}Filesystem: $FILESYSTEM${NC}"
    echo -e "${BLUE}Sanitization Mode: $SANITIZATION_MODE${NC}"
    echo -e "${BLUE}Dry Run: $DRY_RUN${NC}"

    if [[ "$CHECK_SHELL_SAFETY" == "true" ]]; then
        echo -e "${BLUE}Shell Safety: ENABLED${NC}"
    fi

    if [[ "$CHECK_UNICODE_EXPLOITS" == "true" ]]; then
        echo -e "${MAGENTA}Unicode Exploit Detection: ENABLED${NC}"
    fi

    if [[ -n "$COPY_TO" ]]; then
        echo -e "${BLUE}Copy To: $COPY_TO (Behavior: $COPY_BEHAVIOR)${NC}"
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    local csv_file
    csv_file=$(init_csv) || return 1

    echo -e "${GREEN}✓ CSV Log: $csv_file${NC}"

    if [[ -n "$COPY_TO" ]]; then
        if ! validate_destination_path "$COPY_TO"; then
            return 1
        fi

        if ! estimate_disk_space "$root_dir" "$COPY_TO"; then
            return 1
        fi

        echo -e "${GREEN}✓ Destination validated${NC}"
    fi

    echo -e "${CYAN}Processing directories...${NC}"
    process_directory_names "$root_dir" "$csv_file"

    echo -e "${CYAN}Processing files...${NC}"
    if [[ -n "$COPY_TO" ]]; then
        process_files "$root_dir" "$csv_file" "$COPY_TO"
    else
        process_files "$root_dir" "$csv_file"
    fi

    if [[ "$GENERATE_TREE" == "true" ]]; then
        echo -e "${CYAN}Generating tree export...${NC}"
        local tree_csv
        tree_csv=$(generate_tree_csv "$root_dir")
        echo -e "${GREEN}✓ Tree CSV: $tree_csv${NC}"
    fi

    echo
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Summary:${NC}"
    echo "  Scanned Directories:  $(get_counter "scanned_dirs")"
    echo "  Scanned Files:        $(get_counter "scanned_files")"
    echo "  Renamed Directories:  $(get_counter "renamed_dirs")"
    echo "  Renamed Files:        $(get_counter "renamed_files")"

    if [[ -n "$COPY_TO" ]]; then
        echo "  Copied Directories:   $(get_counter "copied_dirs")"
        echo "  Copied Files:         $(get_counter "copied_files")"
    fi

    echo "  Skipped Items:        $(get_counter "skipped_items")"
    echo "  Failed Items:         $(get_counter "failed_items")"
    echo "  Path Length Issues:   $(get_counter "path_length_issues")"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}DRY RUN MODE: No changes were made. Set DRY_RUN=false to apply changes.${NC}"
    else
        echo -e "${GREEN}✓ Complete! Changes applied. CSV saved as: $csv_file${NC}"
    fi

    return 0
}

: "MAIN FUNCTION"

main "$@"
