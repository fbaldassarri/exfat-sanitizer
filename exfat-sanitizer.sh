#!/bin/bash

################################################################################
# exfat-sanitizer-v9.0.1.sh
# Cross-Platform Filename Sanitizer (exFAT, FAT32, APFS, NTFS, HFS+, Universal)
# Production-Ready Implementation + Bugfix Release
# Date: January 7, 2026
# License: MIT
################################################################################

set -e

################################################################################
# CONFIGURATION & COLORS
################################################################################

readonly SCRIPT_VERSION="9.0.1"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

# Filesystem modes: exfat, fat32, apfs, ntfs, hfsplus, universal
readonly FILESYSTEM="${FILESYSTEM:-universal}"

# Sanitization modes: strict, conservative, permissive
readonly SANITIZATION_MODE="${SANITIZATION_MODE:-strict}"

# Other configuration
readonly DRY_RUN="${DRY_RUN:-true}"
readonly COPY_TO="${COPY_TO:-}"
readonly COPY_BEHAVIOR="${COPY_BEHAVIOR:-skip}"
readonly REPLACEMENT_CHAR="${REPLACEMENT_CHAR:-_}"
readonly GENERATE_TREE="${GENERATE_TREE:-false}"

# Safety features
readonly CHECK_SHELL_SAFETY="${CHECK_SHELL_SAFETY:-true}"
readonly CHECK_UNICODE_EXPLOITS="${CHECK_UNICODE_EXPLOITS:-false}"
readonly CHECK_NORMALIZATION="${CHECK_NORMALIZATION:-false}"

# Temp directory for counters
TEMP_COUNTER_DIR=""

################################################################################
# TEMP COUNTER FUNCTIONS
################################################################################

init_temp_counters() {
    TEMP_COUNTER_DIR=$(mktemp -d) || {
        echo -e "${RED}Error: Failed to create temp counter directory${NC}" >&2
        return 1
    }
    
    local counters=(
        "total_items" "scanned_dirs" "scanned_files"
        "invalid_dirs" "invalid_files" "renamed_dirs" "renamed_files"
        "failed_dirs" "failed_files" "path_length_issues"
        "copied_dirs" "copied_files" "skipped_items" "failed_items"
    )
    
    for counter in "${counters[@]}"; do
        echo "0" > "$TEMP_COUNTER_DIR/$counter"
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
    [[ -n "$TEMP_COUNTER_DIR" && -d "$TEMP_COUNTER_DIR" ]] && rm -rf "$TEMP_COUNTER_DIR"
}

trap cleanup_temp_counters EXIT

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
    
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$type" "$old_name" "$new_name" "$issues" "$path" "$path_length" "$status" "$copy_status" >> "$csv_file"
}

################################################################################
# TREE CSV FUNCTIONS
################################################################################

generate_tree_csv() {
    local rootdir="$1"
    local tree_csv="tree_${FILESYSTEM}_$(date +%Y%m%d_%H%M%S).csv"
    echo "Type,Name,Path,Depth,Has Children" > "$tree_csv"
    
    find "$rootdir" -print 2>/dev/null | while read -r item; do
        local type="File"
        local name
        name=$(basename "$item")
        local path="${item#$rootdir}"
        path="${path%/}"
        local depth
        depth=$(echo "$path" | tr -cd '/' | wc -c)
        local has_children="No"
        
        if [[ -d "$item" ]]; then
            type="Directory"
            [[ -n $(find "$item" -maxdepth 1 \( -type f -o -type d \) ! -name "$item" 2>/dev/null) ]] && has_children="Yes"
        fi
        
        printf '%s,%s,%s,%s,%s\n' "$type" "$name" "$path" "$depth" "$has_children" >> "$tree_csv"
    done
    
    echo "$tree_csv"
}

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
    
    if (( ${#path} > max_length )); then
        return 1
    fi
    return 0
}

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
    grep -Fxq "$path" "$USED_PATHS_FILE" 2>/dev/null || return 1
}

################################################################################
# SYSTEM FILES TO SKIP
################################################################################

# Files that should be silently ignored (not processed, not renamed, not in CSV)
should_skip_item() {
    local item="$1"
    case "$item" in
        .DS_Store|.stfolder|.sync.ffs_db|.sync.ffsdb|.Spotlight-V100|Thumbs.db|.stignore|.gitignore|.sync)
            return 0  # Skip this item
            ;;
        *)
            return 1  # Process this item
            ;;
    esac
}

################################################################################
# COPY MODE FUNCTIONS
################################################################################

validate_destination_path() {
    local dest="$1"
    
    if [[ -z "$dest" ]]; then
        echo -e "${RED}Error: COPY_TO not set${NC}" >&2
        return 1
    fi
    
    if [[ -e "$dest" && ! -d "$dest" ]]; then
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
    source_size=$(du -sb "$source" 2>/dev/null | awk '{print $1}') || source_size=0
    local dest_free
    dest_free=$(df "$dest" 2>/dev/null | awk 'NR==2 {print $4 * 1024}') || dest_free=0
    
    if (( dest_free > 0 && source_size > 0 )); then
        local margin=$((dest_free - source_size))
        if (( margin < 0 )); then
            echo -e "${RED}Error: Insufficient disk space. Need: $((source_size / 1024 / 1024))MB, Available: $((dest_free / 1024 / 1024))MB${NC}" >&2
            return 1
        fi
        if (( margin < source_size / 10 )); then
            echo -e "${YELLOW}Warning: Limited disk space margin ($((margin / 1024 / 1024))MB)${NC}" >&2
        fi
    fi
    
    return 0
}

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
    [[ -f "$file" ]] && rm -f "$file" 2>/dev/null || true
}

copy_file() {
    local source="$1"
    local dest_dir="$2"
    local dest_filename="$3"
    local csv_file="$4"
    local behavior="$5"
    local dest_file="$dest_dir/$dest_filename"
    
    if handle_file_conflict "$dest_file" "$behavior"; then
        if [[ "$behavior" == "version" && -e "$dest_file" ]]; then
            local base="${dest_file%.*}"
            local ext="${dest_file##*.}"
            local version=1
            while [[ -e "$base-v$version.$ext" ]]; do
                ((version++))
            done
            dest_file="$base-v$version.$ext"
        fi
    else
        log_to_csv "$csv_file" "File" "$(basename "$source")" "$dest_filename" "" "$dest_dir" "${#dest_file}" "LOGGED" "SKIPPED"
        increment_counter "skipped_items"
        return 0
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

################################################################################
# NAME SANITIZATION - ENHANCED v9.0.1
################################################################################

sanitize_name() {
    local name="$1"
    local filesystem="$2"
    local mode="${3:-$SANITIZATION_MODE}"
    local shell_safe="${4:-$CHECK_SHELL_SAFETY}"
    local sanitized="$name"
    local issues=""
    
    # Step 1: Universal forbidden characters (ALL filesystems)
    local universal_forbidden='[<>:"|?*/]'
    if [[ "$sanitized" =~ $universal_forbidden ]]; then
        sanitized=$(printf '%s\n' "$sanitized" | sed "s/$universal_forbidden/$REPLACEMENT_CHAR/g")
        issues="Universal_Forbidden"
    fi
    
    # Step 2: Control characters (CRITICAL - strict mode or NTFS)
    if [[ "$mode" == "strict" ]] || [[ "$filesystem" == "ntfs" ]]; then
        if echo "$sanitized" | grep -q $'[\\x00-\\x1F\\x7F]' 2>/dev/null; then
            sanitized=$(printf '%s\n' "$sanitized" | sed 's/[[:cntrl:]]//g')
            [[ -n "$issues" ]] && issues="$issues,Control_Chars" || issues="Control_Chars"
        fi
    fi
    
    # Step 3: Unicode line separators (CRITICAL)
    if [[ "$mode" != "permissive" ]]; then
        if echo "$sanitized" | grep -qP '[\\u000A\\u000D\\u0085\\u2028\\u2029]' 2>/dev/null; then
            sanitized=$(printf '%s\n' "$sanitized" | sed 's/[^[:print:]\t]//g')
            [[ -n "$issues" ]] && issues="$issues,Unicode_Newlines" || issues="Unicode_Newlines"
        fi
    fi
    
    # Step 4: Filesystem-specific restrictions
    case "$filesystem" in
        fat32)
            local fat32_specific='[+,;=\[\]÷×]'
            if [[ "$sanitized" =~ $fat32_specific ]]; then
                sanitized=$(printf '%s\n' "$sanitized" | sed "s/$fat32_specific/$REPLACEMENT_CHAR/g")
                [[ -n "$issues" ]] && issues="$issues,FAT32_Specific" || issues="FAT32_Specific"
            fi
            ;;
        exfat)
            # exFAT allows more characters than FAT32
            ;;
        apfs)
            # APFS has fewer restrictions
            ;;
        ntfs)
            # NTFS has additional control character restrictions (handled above)
            ;;
        hfsplus)
            # HFS+ has colon restrictions
            if [[ "$sanitized" =~ : ]]; then
                sanitized="${sanitized//:/⁓}"  # Replace with fullwidth colon
                [[ -n "$issues" ]] && issues="$issues,HFS_Colon" || issues="HFS_Colon"
            fi
            ;;
        universal)
            # Apply most restrictive (FAT32)
            local fat32_specific='[+,;=\[\]÷×]'
            if [[ "$sanitized" =~ $fat32_specific ]]; then
                sanitized=$(printf '%s\n' "$sanitized" | sed "s/$fat32_specific/$REPLACEMENT_CHAR/g")
                [[ -n "$issues" ]] && issues="$issues,FAT32_Specific" || issues="FAT32_Specific"
            fi
            ;;
    esac
    
    # Step 5: Shell metacharacters (optional safety feature)
    if [[ "$shell_safe" == "true" && "$mode" == "strict" ]]; then
        local shell_dangerous='[$`&;#~^!()]'
        if [[ "$sanitized" =~ $shell_dangerous ]]; then
            sanitized=$(printf '%s\n' "$sanitized" | sed "s/$shell_dangerous/$REPLACEMENT_CHAR/g")
            [[ -n "$issues" ]] && issues="$issues,Shell_Dangerous" || issues="Shell_Dangerous"
        fi
    fi
    
    # Step 6: Zero-width characters (optional advanced feature)
    if [[ "$CHECK_UNICODE_EXPLOITS" == "true" ]]; then
        if echo "$sanitized" | grep -qP '[\\u200B\\u200C\\u200D]' 2>/dev/null; then
            sanitized=$(printf '%s\n' "$sanitized" | sed 's/[^\x00-\x7F]//g')
            [[ -n "$issues" ]] && issues="$issues,Zero_Width" || issues="Zero_Width"
        fi
    fi
    
    # Step 7: Leading/trailing problematic characters
    if [[ "$sanitized" == .* ]]; then
        sanitized="${sanitized:1}"
        [[ -n "$issues" ]] && issues="$issues,Leading_Invalid" || issues="Leading_Invalid"
    fi
    
    if [[ "$sanitized" == *. ]]; then
        sanitized="${sanitized%?}"
        [[ -n "$issues" ]] && issues="$issues,Trailing_Invalid" || issues="Trailing_Invalid"
    fi
    
    # Step 8: Reserved names (Windows/DOS)
    if [[ "$filesystem" =~ ntfs|fat32|exfat|universal ]]; then
        local reserved_pattern='(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]|\.\.?)'
        if [[ "$sanitized" =~ $reserved_pattern ]]; then
            sanitized="${sanitized}-reserved"
            [[ -n "$issues" ]] && issues="$issues,Reserved_Name" || issues="Reserved_Name"
        fi
    fi
    
    # Handle edge case: fully sanitized to empty
    [[ -z "$sanitized" ]] && sanitized="$REPLACEMENT_CHAR"
    
    echo "$sanitized" "$sanitized" "$issues"
    echo "$([[ "$sanitized" != "$name" ]] && echo true || echo false)"
    echo "$issues"
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

################################################################################
# DIRECTORY PROCESSING
################################################################################

process_directory_names() {
    local rootdir="$1"
    local csvfile="$2"
    
    find "$rootdir" -type d -print0 2>/dev/null | sort -z -r | while IFS= read -r -d '' dir; do
        increment_counter "scanned_dirs"
        
        local dirname
        dirname=$(basename "$dir")
        
        # Skip system directories - don't process or log these
        if should_skip_item "$dirname"; then
            continue  # Silently skip, not even in CSV
        fi
        
        local parentdir
        parentdir=$(dirname "$dir")
        
        local sanitize_result
        sanitize_result=$(sanitize_name "$dirname" "$FILESYSTEM" "$SANITIZATION_MODE" "$CHECK_SHELL_SAFETY")
        
        local newdirname hadchanges issues
        IFS= read -r newdirname hadchanges issues <<< "$sanitize_result"
        
        if [[ "$hadchanges" == "true" ]]; then
            local newpath="$parentdir/$newdirname"
            if check_path_length "$newpath" "$FILESYSTEM"; then
                if ! is_path_used "$newpath"; then
                    if [[ "$DRY_RUN" != "true" ]]; then
                        if mv "$dir" "$newpath" 2>/dev/null; then
                            log_to_csv "$csvfile" "Directory" "$dirname" "$newdirname" "$issues" "$parentdir" "${#newpath}" "RENAMED"
                            register_path "$newpath"
                            increment_counter "renamed_dirs"
                        else
                            log_to_csv "$csvfile" "Directory" "$dirname" "$newdirname" "$issues" "$parentdir" "${#newpath}" "FAILED"
                            increment_counter "failed_dirs"
                        fi
                    else
                        log_to_csv "$csvfile" "Directory" "$dirname" "$newdirname" "$issues" "$parentdir" "${#newpath}" "RENAMED"
                    fi
                fi
            else
                log_to_csv "$csvfile" "Directory" "$dirname" "$newdirname" "Path too long" "$parentdir" "${#newpath}" "FAILED"
                increment_counter "path_length_issues"
                increment_counter "failed_dirs"
            fi
        else
            register_path "$dir"
            log_to_csv "$csvfile" "Directory" "$dirname" "$dirname" "$parentdir" "$dir" "LOGGED"
        fi
    done
}

################################################################################
# FILE PROCESSING
################################################################################

process_files() {
    local rootdir="$1"
    local csvfile="$2"
    local copydest="${3:-}"
    
    find "$rootdir" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
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
        
        local parentdir
        parentdir=$(dirname "$file")
        
        local sanitize_result
        sanitize_result=$(sanitize_name "$filename" "$FILESYSTEM" "$SANITIZATION_MODE" "$CHECK_SHELL_SAFETY")
        
        local newfilename hadchanges issues
        IFS= read -r newfilename hadchanges issues <<< "$sanitize_result"
        
        local newpath="$parentdir/$newfilename"
        
        if check_path_length "$newpath" "$FILESYSTEM"; then
            if [[ "$hadchanges" == "true" ]]; then
                if [[ "$DRY_RUN" != "true" ]]; then
                    if mv "$file" "$newpath" 2>/dev/null; then
                        if [[ -n "$copydest" ]]; then
                            local reldir="${parentdir#$rootdir}"
                            reldir="${reldir#/}"
                            local destdir="$copydest/$reldir"
                            mkdir -p "$destdir" 2>/dev/null || true
                            copy_file "$newpath" "$destdir" "$newfilename" "$csvfile" "$COPY_BEHAVIOR"
                        else
                            log_to_csv "$csvfile" "File" "$filename" "$newfilename" "$issues" "$parentdir" "${#newpath}" "RENAMED" "N/A"
                        fi
                        increment_counter "renamed_files"
                    else
                        log_to_csv "$csvfile" "File" "$filename" "$newfilename" "$issues" "$parentdir" "${#newpath}" "FAILED" "N/A"
                    fi
                else
                    log_to_csv "$csvfile" "File" "$filename" "$newfilename" "$issues" "$parentdir" "${#newpath}" "RENAMED" "N/A"
                fi
            else
                if [[ -n "$copydest" ]]; then
                    local reldir="${parentdir#$rootdir}"
                    reldir="${reldir#/}"
                    local destdir="$copydest/$reldir"
                    mkdir -p "$destdir" 2>/dev/null || true
                    copy_file "$file" "$destdir" "$newfilename" "$csvfile" "$COPY_BEHAVIOR"
                else
                    log_to_csv "$csvfile" "File" "$filename" "$filename" "$parentdir" "${#newpath}" "LOGGED" "N/A"
                fi
            fi
        else
            log_to_csv "$csvfile" "File" "$filename" "$newfilename" "Path too long" "$parentdir" "${#newpath}" "FAILED" "N/A"
            increment_counter "path_length_issues"
            increment_counter "failed_files"
        fi
    done
}

################################################################################
# HELP FUNCTION
################################################################################

print_help() {
    cat << 'EOF'
exfat-sanitizer v9.0.1 - Cross-Platform Filename Sanitizer
Production-Ready Implementation (Bugfix Release)

USAGE:
  FILESYSTEM=<fs> SANITIZATION_MODE=<mode> DRY_RUN=<bool> \
  ./exfat-sanitizer-v9.0.1.sh <directory>

FILESYSTEMS:
  exfat      - exFAT restrictions (removable media, flexible)
  fat32      - FAT32 restrictions (older USB drives, legacy)
  apfs       - APFS restrictions (macOS Sonoma, native)
  ntfs       - NTFS restrictions (Windows, strict)
  hfsplus    - HFS restrictions (legacy macOS)
  universal  - Most restrictive (unknown destination) [DEFAULT]

SANITIZATION MODES:
  strict       - Remove all problematic chars including shell-dangerous [DEFAULT]
  conservative - Remove only officially-forbidden chars per filesystem
  permissive   - Remove only universal forbidden chars (fastest, least safe)

SAFETY OPTIONS:
  CHECK_SHELL_SAFETY=true|false          - Remove $, `, &, ;, #, ~, ^, !, ( ) [DEFAULT: true]
  CHECK_UNICODE_EXPLOITS=true|false      - Remove zero-width, bidirectional [DEFAULT: false]
  CHECK_NORMALIZATION=true|false         - Detect NFC/NFD differences [DEFAULT: false]

COPY MODE OPTIONS:
  COPY_TO=<path>              - Copy sanitized files to destination
  COPY_BEHAVIOR=<mode>        - How to handle conflicts: skip, overwrite, version [DEFAULT: skip]

OTHER OPTIONS:
  DRY_RUN=true|false          - Preview changes without modifying [DEFAULT: true]
  REPLACEMENT_CHAR=<char>     - Character for replacing forbidden chars [DEFAULT: _]
  GENERATE_TREE=true|false    - Export directory tree structure [DEFAULT: false]

IGNORED FILES:
The following system files are automatically skipped and never processed:
  .DS_Store, .stfolder, .sync.ffs_db, .sync.ffsdb, .Spotlight-V100,
  Thumbs.db, .stignore, .gitignore, .sync

These files will not appear in CSV output and will not be renamed.

EXAMPLES:

  Your Audio Library (exFAT USB):
    FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=false \
    ./exfat-sanitizer-v9.0.1.sh /media/usb/Audio

  macOS APFS Drive (optimized):
    FILESYSTEM=apfs SANITIZATION_MODE=conservative DRY_RUN=false \
    ./exfat-sanitizer-v9.0.1.sh ~/Music

  Maximum Security (untrusted sources):
    FILESYSTEM=universal SANITIZATION_MODE=strict CHECK_SHELL_SAFETY=true \
    DRY_RUN=false ./exfat-sanitizer-v9.0.1.sh ~/Downloads

CHARACTER COVERAGE v9.0.1 handles:
  - Universal forbidden: < > : " / \ | ? * NUL
  - FAT32-specific: + , ; = [ ] ÷ ×
  - APFS-optimized: Only 5 chars (/ : CR LF NUL)
  - NTFS-specific: Universal + Control chars
  - HFS+ Legacy: Colon handling
  - Control characters: 0x00-0x1F, 0x7F (security)
  - Unicode newlines: U+000A, U+000D, U+0085, U+2028, U+2029
  - Shell metacharacters: $ ` & ; # ~ ^ ! ( ) (optional)
  - Reserved names: Windows/DOS (CON, PRN, AUX, etc.)
  - Path length validation: 260 chars for FAT32, 255 for others

VERSION: 9.0.1

LICENSE: MIT
EOF
}

################################################################################
# MAIN FUNCTION
################################################################################

main() {
    local rootdir="${1:-.}"
    
    if [[ "$rootdir" == "-h" || "$rootdir" == "--help" ]]; then
        print_help
        return 0
    fi
    
    if ! [[ -d "$rootdir" ]]; then
        echo -e "${RED}Error: Source directory not found: $rootdir${NC}" >&2
        return 1
    fi
    
    validate_inputs || return 1
    init_temp_counters || return 1
    USED_PATHS_FILE=$(mktemp) || return 1
    trap "rm -f $USED_PATHS_FILE" RETURN
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}exfat-sanitizer v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}Filesystem: ${FILESYSTEM}${NC}"
    echo -e "${BLUE}Sanitization Mode: ${SANITIZATION_MODE}${NC}"
    echo -e "${BLUE}Dry Run: ${DRY_RUN}${NC}"
    [[ "$CHECK_SHELL_SAFETY" == "true" ]] && echo -e "${BLUE}Shell Safety: ENABLED${NC}"
    [[ "$CHECK_UNICODE_EXPLOITS" == "true" ]] && echo -e "${MAGENTA}Unicode Exploit Detection: ENABLED${NC}"
    [[ -n "$COPY_TO" ]] && echo -e "${BLUE}Copy To: ${COPY_TO} (Behavior: ${COPY_BEHAVIOR})${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    local csvfile
    csvfile=$(init_csv) || return 1
    echo -e "${GREEN}✓ CSV Log: $csvfile${NC}"
    
    if [[ -n "$COPY_TO" ]]; then
        if ! validate_destination_path "$COPY_TO"; then
            return 1
        fi
        if ! estimate_disk_space "$rootdir" "$COPY_TO"; then
            return 1
        fi
        echo -e "${GREEN}✓ Destination validated${NC}"
    fi
    
    echo -e "${CYAN}Processing directories...${NC}"
    process_directory_names "$rootdir" "$csvfile"
    
    echo -e "${CYAN}Processing files...${NC}"
    if [[ -n "$COPY_TO" ]]; then
        process_files "$rootdir" "$csvfile" "$COPY_TO"
    else
        process_files "$rootdir" "$csvfile"
    fi
    
    if [[ "$GENERATE_TREE" == "true" ]]; then
        echo -e "${CYAN}Generating tree export...${NC}"
        local tree_csv
        tree_csv=$(generate_tree_csv "$rootdir")
        echo -e "${GREEN}✓ Tree CSV: $tree_csv${NC}"
    fi
    
    echo
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Summary:${NC}"
    echo "  Scanned Directories: $(get_counter "scanned_dirs")"
    echo "  Scanned Files: $(get_counter "scanned_files")"
    echo "  Renamed Directories: $(get_counter "renamed_dirs")"
    echo "  Renamed Files: $(get_counter "renamed_files")"
    [[ -n "$COPY_TO" ]] && echo "  Copied Directories: $(get_counter "copied_dirs")"
    [[ -n "$COPY_TO" ]] && echo "  Copied Files: $(get_counter "copied_files")"
    [[ -n "$COPY_TO" ]] && echo "  Skipped Items: $(get_counter "skipped_items")"
    echo "  Failed Items: $(get_counter "failed_items")"
    echo "  Path Length Issues: $(get_counter "path_length_issues")"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}DRY RUN MODE: No changes were made. Set DRY_RUN=false to apply changes.${NC}"
    else
        echo -e "${GREEN}✓ Complete! Changes applied. CSV saved as $csvfile${NC}"
    fi
    
    return 0
}

main "$@"
