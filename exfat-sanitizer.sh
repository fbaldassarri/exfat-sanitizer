#!/usr/bin/env bash

################################################################################
# exfat-sanitizer v7.6.0 - with Tree Export
# FAT32/exFAT Filename Sanitizer + Directory Tree CSV Export
# 
# v7.6.0 CHANGES:
# - Added GENERATE_TREE environment variable (default: false)
# - Added tree CSV export function (Level;Depth;Type;Name;Full_Path;Size;Date)
# - Tree generated BEFORE sanitization changes
# - 100% backward compatible - default behavior unchanged
################################################################################

set -euo pipefail
readonly SCRIPT_VERSION="7.6.0"

FILESYSTEM="${FILESYSTEM:-exfat}"
DRY_RUN="${DRY_RUN:-true}"
GENERATE_TREE="${GENERATE_TREE:-false}"
REPLACEMENT_CHAR="_"
LOG_CSV_FILE=""
TREE_CSV_FILE=""

# Statistics
TOTAL_ITEMS=0
SCANNED_DIRS=0
SCANNED_FILES=0
INVALID_DIRS=0
INVALID_FILES=0
RENAMED_DIRS=0
RENAMED_FILES=0
FAILED_DIRS=0
FAILED_FILES=0
PATH_LENGTH_ISSUES=0

# Temporary directory for counters
TEMP_COUNTERS=""

# Filesystem Limits
if [[ "$FILESYSTEM" == "fat32" ]]; then
    MAX_PATH_LENGTH=255
else
    MAX_PATH_LENGTH=32767
fi

# Collision tracking
USED_PATHS=""

# Color output
if [[ -t 1 ]]; then
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_NC='\033[0m'
else
    readonly COLOR_RED=''
    readonly COLOR_GREEN=''
    readonly COLOR_BLUE=''
    readonly COLOR_CYAN=''
    readonly COLOR_YELLOW=''
    readonly COLOR_NC=''
fi

log_info() { echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $*" >&2; }
log_success() { echo -e "${COLOR_GREEN}[✓]${COLOR_NC} $*" >&2; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $*" >&2; }
log_warning() { echo -e "${COLOR_YELLOW}[!]${COLOR_NC} $*" >&2; }

################################################################################
# TEMP COUNTER FUNCTIONS
################################################################################

init_temp_counters() {
    TEMP_COUNTERS=$(mktemp -d) || { log_error "Failed to create temp directory"; return 1; }
    echo "0" > "$TEMP_COUNTERS/scanned_dirs"
    echo "0" > "$TEMP_COUNTERS/scanned_files"
    echo "0" > "$TEMP_COUNTERS/invalid_dirs"
    echo "0" > "$TEMP_COUNTERS/invalid_files"
    echo "0" > "$TEMP_COUNTERS/renamed_dirs"
    echo "0" > "$TEMP_COUNTERS/renamed_files"
    echo "0" > "$TEMP_COUNTERS/failed_dirs"
    echo "0" > "$TEMP_COUNTERS/failed_files"
    echo "0" > "$TEMP_COUNTERS/path_length_issues"
    echo "0" > "$TEMP_COUNTERS/total_items"
}

cleanup_temp_counters() {
    if [[ -n "$TEMP_COUNTERS" ]] && [[ -d "$TEMP_COUNTERS" ]]; then
        rm -rf "$TEMP_COUNTERS"
    fi
}

increment_counter() {
    local counter_name="$1"
    local counter_file="$TEMP_COUNTERS/${counter_name}"
    local current_value=$(cat "$counter_file" 2>/dev/null || echo "0")
    echo $((current_value + 1)) > "$counter_file"
}

get_counter() {
    local counter_name="$1"
    local counter_file="$TEMP_COUNTERS/${counter_name}"
    cat "$counter_file" 2>/dev/null || echo "0"
}

################################################################################
# CSV FUNCTIONS
################################################################################

init_csv() {
    echo "Type,Old Name,New Name,Issues,Path,Path Length,Status" > "$1"
}

csv_escape() {
    echo "\"${1//\"/\"\"}\""
}

log_to_csv() {
    local logfile="$1" type="$2" old="$3" new="$4" issues="$5" path="$6" path_len="$7" status="$8"
    printf '%s,%s,%s,%s,%s,%s,%s\n' \
        "$type" \
        "$(csv_escape "$old")" "$(csv_escape "$new")" "$(csv_escape "$issues")" \
        "$(csv_escape "$path")" "$path_len" "$status" >> "$logfile"
}

################################################################################
# TREE CSV FUNCTIONS
################################################################################

init_tree_csv() {
    printf "Level;Depth;Type;Name;Full_Path;Size_Bytes;Modified_Date\r\n" > "$1"
}

log_tree_entry() {
    local treecsv="$1" level="$2" depth="$3" type="$4" name="$5" path="$6" size="$7" mdate="$8"
    printf '%s;%s;%s;%s;%s;%s;%s\r\n' "$level" "$depth" "$type" "\"${name//\"/\"\"}\"" "\"${path//\"/\"\"}\"" "$size" "$mdate" >> "$treecsv"
}

get_item_size() {
    local item="$1"
    if [[ -d "$item" ]]; then
        echo "-"
    else
        stat -f%z "$item" 2>/dev/null || echo "0"
    fi
}

get_item_mdate() {
    local item="$1"
    stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$item" 2>/dev/null || echo "N/A"
}

get_depth() {
    local full_path="$1" root="$2"
    local rel="${full_path#$root}"
    rel="${rel#/}"
    [[ -z "$rel" ]] && echo "0" || echo "$rel" | grep -o "/" | wc -l
}

generate_tree_csv() {
    local target_path="$1"
    log_info "Generating directory tree..."
    init_tree_csv "$TREE_CSV_FILE"
    
    local level=0
    find "$target_path" -mindepth 0 | sort | while IFS= read -r item; do
        local depth=$(get_depth "$item" "$target_path")
        local type="File"
        local name=$(basename "$item")
        local size size_str mdate
        
        [[ -d "$item" ]] && type="Directory" && size_str="-" || size_str=$(get_item_size "$item")
        mdate=$(get_item_mdate "$item")
        
        local rel_path="${item#$target_path}"
        [[ -z "$rel_path" ]] && rel_path="/"
        
        log_tree_entry "$TREE_CSV_FILE" "$level" "$depth" "$type" "$name" "$rel_path" "$size_str" "$mdate"
        ((level++))
    done
    
    log_success "Tree exported to: $TREE_CSV_FILE"
}

################################################################################
# PATH LENGTH VALIDATION
################################################################################

check_path_length() {
    local newpath="$1"
    local max_len="$2"
    local path_len=${#newpath}
    if [[ $path_len -gt $max_len ]]; then
        echo "TOO_LONG:$path_len"
        return 1
    fi
    echo "OK:$path_len"
    return 0
}

################################################################################
# COLLISION DETECTION
################################################################################

is_path_used() {
    local newpath="$1"
    if [[ -n "$USED_PATHS" ]] && echo "$USED_PATHS" | grep -F "$newpath" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

register_path() {
    local newpath="$1"
    if [[ -z "$USED_PATHS" ]]; then
        USED_PATHS="$newpath"
    else
        USED_PATHS="${USED_PATHS}
${newpath}"
    fi
}

################################################################################
# NAME SANITIZATION
################################################################################

sanitize_name() {
    local name="$1"
    local sanitized="$name"
    local had_changes=0
    local issues=""

    # Remove leading/trailing spaces
    if [[ "$sanitized" =~ ^[[:space:]] ]] || [[ "$sanitized" =~ [[:space:]]$ ]]; then
        sanitized="$(echo "$sanitized" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        had_changes=1
        issues="${issues}Leading/Trailing Spaces;"
    fi

    # Handle leading dots
    if [[ "$sanitized" =~ ^\. ]]; then
        sanitized="${sanitized#.}"
        [[ -z "$sanitized" ]] && sanitized="$REPLACEMENT_CHAR"
        had_changes=1
        issues="${issues}Leading Dot;"
    fi

    # Replace forbidden characters: < > : " / \ | ? *
    local original="$sanitized"
    sanitized="${sanitized//</$REPLACEMENT_CHAR}"
    sanitized="${sanitized//>/$REPLACEMENT_CHAR}"
    sanitized="${sanitized//:/$REPLACEMENT_CHAR}"
    sanitized="${sanitized//\"/$REPLACEMENT_CHAR}"
    sanitized="${sanitized//\//$REPLACEMENT_CHAR}"
    sanitized="${sanitized//\\/$REPLACEMENT_CHAR}"
    sanitized="${sanitized//|/$REPLACEMENT_CHAR}"
    sanitized="${sanitized//[?]/$REPLACEMENT_CHAR}"
    sanitized="${sanitized//[*]/$REPLACEMENT_CHAR}"
    
    if [[ "$sanitized" != "$original" ]]; then
        had_changes=1
        issues="${issues}Forbidden Chars;"
    fi

    # FAT32 specific characters: ; = + [ ] ÷ ×
    if [[ "$FILESYSTEM" == "fat32" ]]; then
        original="$sanitized"
        sanitized="${sanitized//;/$REPLACEMENT_CHAR}"
        sanitized="${sanitized//=/$REPLACEMENT_CHAR}"
        sanitized="${sanitized//+/$REPLACEMENT_CHAR}"
        sanitized="${sanitized//[[]/$REPLACEMENT_CHAR}"
        sanitized="${sanitized//[]]/$REPLACEMENT_CHAR}"
        sanitized="${sanitized//÷/$REPLACEMENT_CHAR}"
        sanitized="${sanitized//×/$REPLACEMENT_CHAR}"
        
        if [[ "$sanitized" != "$original" ]]; then
            had_changes=1
            issues="${issues}FAT32 Chars;"
        fi
    fi

    echo "$sanitized|$had_changes|${issues%;}"
}

################################################################################
# VALIDATION
################################################################################

validate_filesystem() {
    if [[ ! "$FILESYSTEM" =~ ^(exfat|fat32)$ ]]; then
        log_error "Invalid filesystem: $FILESYSTEM. Use 'exfat' or 'fat32'"
        return 1
    fi
    return 0
}

################################################################################
# DIRECTORY PROCESSING
################################################################################

process_directory_names() {
    local rootdir="$1" logfile="$2"
    log_info "Scanning directory names (depth-first)..."

    find "$rootdir" -type d ! -name "." ! -path "*/.*" -print 2>/dev/null | sort -r | while IFS= read -r dirpath; do
        [[ "$dirpath" == "$rootdir" ]] && continue
        [[ "$(basename "$dirpath")" =~ ^\. ]] && continue

        increment_counter "scanned_dirs"
        increment_counter "total_items"

        local dirname parentdir result sanitized had_changes issues
        dirname=$(basename "$dirpath")
        parentdir=$(dirname "$dirpath")

        [[ "$dirname" == ".stfolder" ]] || [[ "$dirname" == ".sync" ]] && continue

        result=$(sanitize_name "$dirname")
        IFS='|' read -r sanitized had_changes issues <<< "$result"

        [[ "$had_changes" == "0" ]] && continue

        increment_counter "invalid_dirs"
        [[ -z "$issues" ]] && issues="Forbidden characters"

        local newpath path_check path_len
        newpath="${parentdir}/${sanitized}"
        path_check=$(check_path_length "$newpath" "$MAX_PATH_LENGTH")
        path_len="${path_check#*:}"

        if [[ "$path_check" == TOO_LONG:* ]]; then
            increment_counter "path_length_issues"
            issues="${issues}Path Too Long ($path_len chars);"
            log_to_csv "$logfile" "Directory" "$dirname" "$sanitized" "$issues" "$parentdir" "$path_len" "SKIPPED"
            log_warning "Skipped DIR due to path length: $dirname (would be $path_len chars)"
            continue
        fi

        if is_path_used "$newpath"; then
            increment_counter "failed_dirs"
            issues="${issues}Name Collision;"
            log_to_csv "$logfile" "Directory" "$dirname" "$sanitized" "$issues" "$parentdir" "$path_len" "COLLISION"
            log_error "Skipped DIR due to name collision: $dirname"
            continue
        fi

        log_to_csv "$logfile" "Directory" "$dirname" "$sanitized" "$issues" "$parentdir" "$path_len" "LOGGED"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo ""
            echo -e "📁 ${COLOR_CYAN}Directory:${COLOR_NC} $dirname"
            echo -e " ${COLOR_YELLOW}→${COLOR_NC} $sanitized"
            echo -e " ${COLOR_RED}Issues:${COLOR_NC} $issues (Path: $path_len/$MAX_PATH_LENGTH chars)"
            register_path "$newpath"
        else
            if mv "$dirpath" "$newpath" 2>/dev/null; then
                increment_counter "renamed_dirs"
                log_success "Renamed DIR: $dirname → $sanitized"
                log_to_csv "$logfile" "Directory" "$dirname" "$sanitized" "$issues" "$parentdir" "$path_len" "RENAMED"
                register_path "$newpath"
            else
                increment_counter "failed_dirs"
                log_error "Failed DIR: $dirname"
                log_to_csv "$logfile" "Directory" "$dirname" "$sanitized" "$issues" "$parentdir" "$path_len" "FAILED"
            fi
        fi
    done
}

################################################################################
# FILE PROCESSING
################################################################################

process_file() {
    local filepath="$1" logfile="$2"
    local filename parentdir result sanitized had_changes issues newpath path_check path_len

    filename=$(basename "$filepath")
    parentdir=$(dirname "$filepath")

    case "$filename" in
        .DS_Store|Thumbs.db|.stignore|.gitignore|.sync|.sync.ffs_db|.stfolder)
            return 0
            ;;
    esac

    result=$(sanitize_name "$filename")
    IFS='|' read -r sanitized had_changes issues <<< "$result"

    [[ "$had_changes" == "0" ]] && return 0

    increment_counter "invalid_files"
    [[ -z "$issues" ]] && issues="Forbidden characters"

    newpath="${parentdir}/${sanitized}"
    path_check=$(check_path_length "$newpath" "$MAX_PATH_LENGTH")
    path_len="${path_check#*:}"

    if [[ "$path_check" == TOO_LONG:* ]]; then
        increment_counter "path_length_issues"
        issues="${issues}Path Too Long ($path_len chars);"
        log_to_csv "$logfile" "File" "$filename" "$sanitized" "$issues" "$parentdir" "$path_len" "SKIPPED"
        log_warning "Skipped FILE due to path length: $filename (would be $path_len chars)"
        return 0
    fi

    if is_path_used "$newpath"; then
        increment_counter "failed_files"
        issues="${issues}Name Collision;"
        log_to_csv "$logfile" "File" "$filename" "$sanitized" "$issues" "$parentdir" "$path_len" "COLLISION"
        log_error "Skipped FILE due to name collision: $filename"
        return 0
    fi

    log_to_csv "$logfile" "File" "$filename" "$sanitized" "$issues" "$parentdir" "$path_len" "LOGGED"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "📄 ${COLOR_BLUE}File:${COLOR_NC} $filename"
        echo -e " ${COLOR_YELLOW}→${COLOR_NC} $sanitized"
        echo -e " ${COLOR_RED}Issues:${COLOR_NC} $issues (Path: $path_len/$MAX_PATH_LENGTH chars)"
        register_path "$newpath"
    else
        if mv "$filepath" "$newpath" 2>/dev/null; then
            increment_counter "renamed_files"
            log_success "Renamed FILE: $filename → $sanitized"
            log_to_csv "$logfile" "File" "$filename" "$sanitized" "$issues" "$parentdir" "$path_len" "RENAMED"
            register_path "$newpath"
        else
            increment_counter "failed_files"
            log_error "Failed FILE: $filename"
            log_to_csv "$logfile" "File" "$filename" "$sanitized" "$issues" "$parentdir" "$path_len" "FAILED"
        fi
    fi
}

process_files() {
    local dirpath="$1" logfile="$2"
    log_info "Scanning file names..."

    find "$dirpath" -type d -name ".*" -prune -o -type f -print 2>/dev/null | while IFS= read -r filepath; do
        increment_counter "scanned_files"
        increment_counter "total_items"
        [[ -f "$filepath" ]] && process_file "$filepath" "$logfile"
        
        local total_scanned total_scanned=$(get_counter "total_items")
        if (( total_scanned % 100 == 0 )); then
            local scanned_dirs_count scanned_files_count invalid_count
            scanned_dirs_count=$(get_counter "scanned_dirs")
            scanned_files_count=$(get_counter "scanned_files")
            invalid_count=$(($(get_counter "invalid_dirs") + $(get_counter "invalid_files")))
            printf "\r... Scanned: %d (Dirs: %d, Files: %d) | Invalid: %d" \
                "$total_scanned" "$scanned_dirs_count" "$scanned_files_count" "$invalid_count" >&2
        fi
    done
    echo "" # Newline after progress
}

################################################################################
# MAIN
################################################################################

main() {
    local target_path="${1:-.}"

    if ! validate_filesystem; then
        return 1
    fi

    if ! init_temp_counters; then
        log_error "Failed to initialize temporary counters"
        return 1
    fi

    [[ "$target_path" == "." ]] && target_path="$(pwd)"

    if [[ ! -d "$target_path" ]]; then
        log_error "Directory not found: $target_path"
        cleanup_temp_counters
        return 1
    fi

    local timestamp timestamp=$(date +%Y%m%d_%H%M%S)
    LOG_CSV_FILE="sanitizer_${FILESYSTEM}_${timestamp}.csv"
    TREE_CSV_FILE="tree_${FILESYSTEM}_${timestamp}.csv"

    init_csv "$LOG_CSV_FILE"

    echo "========================================"
    echo "Filename Sanitizer v${SCRIPT_VERSION}"
    echo "========================================"
    echo ""
    echo "Filesystem: $(echo "$FILESYSTEM" | tr '[:lower:]' '[:upper:]')"
    echo "Mode: $([ "$DRY_RUN" == "true" ] && echo "DRY RUN (preview)" || echo "EXECUTION")"
    echo "Path limit: $MAX_PATH_LENGTH characters"
    echo "Log: $LOG_CSV_FILE"
    [[ "$GENERATE_TREE" == "true" ]] && echo "Tree: $TREE_CSV_FILE"
    echo ""

    # Generate tree BEFORE any changes
    if [[ "$GENERATE_TREE" == "true" ]]; then
        generate_tree_csv "$target_path"
        echo ""
    fi

    process_directory_names "$target_path" "$LOG_CSV_FILE"
    process_files "$target_path" "$LOG_CSV_FILE"

    # Read final counters
    TOTAL_ITEMS=$(get_counter "total_items")
    SCANNED_DIRS=$(get_counter "scanned_dirs")
    SCANNED_FILES=$(get_counter "scanned_files")
    INVALID_DIRS=$(get_counter "invalid_dirs")
    INVALID_FILES=$(get_counter "invalid_files")
    RENAMED_DIRS=$(get_counter "renamed_dirs")
    RENAMED_FILES=$(get_counter "renamed_files")
    FAILED_DIRS=$(get_counter "failed_dirs")
    FAILED_FILES=$(get_counter "failed_files")
    PATH_LENGTH_ISSUES=$(get_counter "path_length_issues")

    echo ""
    echo "========================================"
    echo "Summary"
    echo "========================================"
    echo "Total scanned: $TOTAL_ITEMS"
    echo " Directories: $SCANNED_DIRS"
    echo " Files: $SCANNED_FILES"
    echo ""
    echo "Invalid names: $((INVALID_DIRS + INVALID_FILES))"
    echo " Directories: $INVALID_DIRS"
    echo " Files: $INVALID_FILES"
    echo ""
    echo "Path length issues: $PATH_LENGTH_ISSUES"

    if [[ "$DRY_RUN" == "false" ]]; then
        echo ""
        echo "Renamed: $((RENAMED_DIRS + RENAMED_FILES))"
        echo " Directories: $RENAMED_DIRS"
        echo " Files: $RENAMED_FILES"
        echo ""
        echo "Failed/Skipped: $((FAILED_DIRS + FAILED_FILES))"
        echo " Directories: $FAILED_DIRS"
        echo " Files: $FAILED_FILES"
    fi

    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "To apply changes run:"
        echo " DRY_RUN=false FILESYSTEM=$FILESYSTEM $0 \"$target_path\""
    fi
    echo ""

    cleanup_temp_counters
}

trap 'log_error "Interrupted"; cleanup_temp_counters; exit 130' INT TERM

main "$@"
exit $?
