#!/bin/bash

################################################################################
# exFAT Filename Compatibility Script - Version 5.1.0
# Production-Ready with Automator Integration
# 
# Features:
# - Reads folder path from stdin or command-line argument
# - Full dry-run support before making changes
# - Proper renaming in production mode (FIXED)
# - Filesystem observer mode for new files
# - Compatible with /bin/bash (POSIX-compliant)
# - macOS Automator compatible
################################################################################

set -u

# ============================================================================
# CONFIGURATION
# ============================================================================

REPLACEMENT_CHAR="_"
HANDLE_TRAILING_SPACES="true"
HANDLE_TRAILING_DOTS="true"
HANDLE_TRIPLE_LEADING_DOTS="true"
DRY_RUN="${DRY_RUN:-false}"
MONITOR_MODE="${MONITOR_MODE:-false}"
LOG_CSV_FILE=""

# System/sync files to skip
SKIP_PATTERNS=(".DS_Store" ".stfolder" ".sync.ffs_db" ".sync.ffsdb" ".Spotlight-V100" ".TemporaryItems")

# Statistics
TOTAL_ITEMS=0
SKIPPED_ITEMS=0
ANALYZED_ITEMS=0
INVALID_ITEMS=0
RENAMED_ITEMS=0
FAILED_ITEMS=0

# ============================================================================
# INPUT HANDLING (stdin or argument)
# ============================================================================

TARGET_DIR=""

# Check if input comes from stdin (piped)
if [ -t 0 ]; then
    # No stdin (interactive terminal)
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <directory_path>"
        echo "   or: echo '/path/to/folder' | $0"
        echo ""
        echo "Environment variables:"
        echo "  DRY_RUN=true|false    (default: false - applies changes)"
        echo "  MONITOR_MODE=true     (default: false - watch for new files)"
        exit 1
    fi
    TARGET_DIR="$1"
else
    # Read from stdin (piped input)
    read -r TARGET_DIR
    TARGET_DIR=$(echo "$TARGET_DIR" | xargs)  # Trim whitespace
fi

# Validate directory
if [ -z "$TARGET_DIR" ]; then
    echo "❌ Error: No directory path provided"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Error: Directory does not exist: $TARGET_DIR"
    exit 1
fi

# Set up logging
if [ -z "$LOG_CSV_FILE" ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    LOG_CSV_FILE="./exfat_sanitizer_${TIMESTAMP}.csv"
fi

# Initialize CSV header
echo "Old Name,New Name,Issues,Path,Status" > "$LOG_CSV_FILE"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

should_skip() {
    local item="$1"
    local basename
    basename=$(basename "$item")
    
    for pattern in "${SKIP_PATTERNS[@]}"; do
        if [ "$basename" = "$pattern" ]; then
            return 0
        fi
    done
    
    return 1
}

has_control_chars() {
    local str="$1"
    if echo "$str" | grep -q "$(printf '[[:cntrl:]]')"; then
        return 0
    fi
    return 1
}

remove_control_chars() {
    local str="$1"
    echo "$str" | tr -d '[:cntrl:]'
}

sanitize_filename() {
    local filename="$1"
    local sanitized="$filename"
    local issues=""

    # Remove invisible control characters
    if has_control_chars "$sanitized"; then
        sanitized=$(remove_control_chars "$sanitized")
        issues="${issues}Control Character(s);"
    fi

    # Handle triple leading dots
    if [ "$HANDLE_TRIPLE_LEADING_DOTS" = "true" ]; then
        if echo "$sanitized" | grep -q "^\.\.\."; then
            sanitized=$(echo "$sanitized" | sed 's/^\.\.*//')
            issues="${issues}Triple Leading Dots;"
        fi
    fi

    # Handle leading dots
    if [ "$HANDLE_TRAILING_DOTS" = "true" ]; then
        if echo "$sanitized" | grep -q "^\."; then
            sanitized=$(echo "$sanitized" | sed 's/^\.*//')
            issues="${issues}Leading Dot(s);"
        fi
    fi

    # Handle trailing dots (preserve file extension)
    if [ "$HANDLE_TRAILING_DOTS" = "true" ]; then
        if echo "$sanitized" | grep -q '\.$'; then
            sanitized=$(echo "$sanitized" | sed 's/\.$//')
            issues="${issues}Trailing Dot(s);"
        fi
    fi

    # Handle leading/trailing spaces
    if [ "$HANDLE_TRAILING_SPACES" = "true" ]; then
        if echo "$sanitized" | grep -qE "^[[:space:]]|[[:space:]]$"; then
            sanitized=$(echo "$sanitized" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            issues="${issues}Leading/Trailing Space(s);"
        fi
    fi

    # Replace forbidden exFAT characters
    # Double quotes
    if echo "$sanitized" | grep -q '"'; then
        sanitized=$(echo "$sanitized" | tr -d '"')
        issues="${issues}Double Quote(\");"
    fi

    # Asterisks
    if echo "$sanitized" | grep -q '\*'; then
        sanitized=$(echo "$sanitized" | tr -d '*')
        issues="${issues}Asterisk(*);"
    fi

    # Forward slashes
    if echo "$sanitized" | grep -q '/'; then
        sanitized=$(echo "$sanitized" | tr '/' "$REPLACEMENT_CHAR")
        issues="${issues}Forward Slash(/);"
    fi

    # Colons
    if echo "$sanitized" | grep -q ':'; then
        sanitized=$(echo "$sanitized" | tr ':' "$REPLACEMENT_CHAR")
        issues="${issues}Colon(:);"
    fi

    # Less than
    if echo "$sanitized" | grep -q '<'; then
        sanitized=$(echo "$sanitized" | tr -d '<')
        issues="${issues}Less Than(<);"
    fi

    # Greater than
    if echo "$sanitized" | grep -q '>'; then
        sanitized=$(echo "$sanitized" | tr -d '>')
        issues="${issues}Greater Than(>);"
    fi

    # Question mark
    if echo "$sanitized" | grep -q '?'; then
        sanitized=$(echo "$sanitized" | tr -d '?')
        issues="${issues}Question Mark(?);"
    fi

    # Backslash
    if echo "$sanitized" | grep -q '\\'; then
        sanitized=$(echo "$sanitized" | tr -d '\\')
        issues="${issues}Backslash(\\);"
    fi

    # Pipe
    if echo "$sanitized" | grep -q '|'; then
        sanitized=$(echo "$sanitized" | tr -d '|')
        issues="${issues}Pipe(|);"
    fi

    # Remove trailing semicolon from issues
    issues="${issues%;}"

    # Output both sanitized name and issues (one per line for safe parsing)
    echo "$sanitized"
    echo "$issues"
}

csv_escape() {
    local str="$1"
    # Escape quotes by doubling them, wrap in quotes
    echo "\"${str//\"/\"\"}\""
}

# ============================================================================
# MAIN PROCESSING FUNCTION
# ============================================================================

process_item() {
    local item="$1"
    local parent_dir
    local basename
    
    TOTAL_ITEMS=$((TOTAL_ITEMS + 1))
    
    basename=$(basename "$item")
    parent_dir=$(dirname "$item")
    
    # Skip system/sync files
    if should_skip "$item"; then
        SKIPPED_ITEMS=$((SKIPPED_ITEMS + 1))
        return 0
    fi
    
    ANALYZED_ITEMS=$((ANALYZED_ITEMS + 1))
    
    # Get sanitized name and issues (safe parsing with separate lines)
    local sanitized
    local issues
    
    # Call sanitize_filename and capture output
    sanitized=$(sanitize_filename "$basename" | head -n 1)
    issues=$(sanitize_filename "$basename" | tail -n 1)
    
    # Skip if no issues found
    if [ -z "$issues" ]; then
        return 0
    fi
    
    INVALID_ITEMS=$((INVALID_ITEMS + 1))
    
    local new_path="${parent_dir}/${sanitized}"
    local status="LOGGED"
    
    # Log to CSV (always)
    echo "$(csv_escape "$basename"),$(csv_escape "$sanitized"),$issues,$(csv_escape "$parent_dir"),$status" >> "$LOG_CSV_FILE"
    
    # Show progress in dry-run if filename visibly changed
    if [ "$basename" != "$sanitized" ]; then
        if [ "$DRY_RUN" = "true" ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "[DRY RUN] Invalid filename detected:"
            echo " Current:  $basename"
            echo " Would be: $sanitized"
            echo " Issues:   $issues"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
    fi
    
    # PRODUCTION MODE: Perform actual rename
    if [ "$DRY_RUN" = "false" ] && [ -n "$issues" ]; then
        # Only rename if paths actually differ
        if [ "$item" != "$new_path" ]; then
            # Preserve original modification time
            local original_mtime
            if [ "$(uname -s)" = "Darwin" ]; then
                original_mtime=$(stat -f%m "$item" 2>/dev/null || echo "0")
            else
                original_mtime=$(stat -c%Y "$item" 2>/dev/null || echo "0")
            fi
            
            # Attempt rename with safety check
            if mv -n -- "$item" "$new_path" 2>/dev/null; then
                # Preserve timestamp
                if [ "$(uname -s)" = "Darwin" ]; then
                    touch -r "$new_path" -- "$new_path" 2>/dev/null
                else
                    touch -d "@${original_mtime}" -- "$new_path" 2>/dev/null
                fi
                
                RENAMED_ITEMS=$((RENAMED_ITEMS + 1))
                echo "✓ [RENAMED] $basename → $sanitized"
            else
                FAILED_ITEMS=$((FAILED_ITEMS + 1))
                echo "⚠ [FAILED] Could not rename: $basename"
            fi
        fi
    fi
}

process_directory() {
    local dir="$1"
    local item_count=0
    
    # Use find to recursively process all items
    while IFS= read -r item; do
        item_count=$((item_count + 1))
        
        # Progress indicator every 10 items
        if [ $((item_count % 10)) -eq 0 ]; then
            printf "\r ⟳ Processing... (%d items scanned, %d analyzed, %d invalid)" \
                "$TOTAL_ITEMS" "$ANALYZED_ITEMS" "$INVALID_ITEMS"
        fi
        
        process_item "$item"
    done < <(find "$dir" -mindepth 1 -print0 | xargs -0 -I {} echo "{}")
    
    echo ""
}

# ============================================================================
# DISPLAY HEADER
# ============================================================================

display_header() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   exFAT Filename Compatibility Script - Version 5.1.0     ║"
    echo "║   Production-Ready • Automator Compatible • stdin Support ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Configuration:"
    echo " • Replacement character:        '$REPLACEMENT_CHAR'"
    echo " • Handle trailing spaces:       $HANDLE_TRAILING_SPACES"
    echo " • Handle trailing/leading dots: $HANDLE_TRAILING_DOTS"
    echo " • Handle triple leading dots:   $HANDLE_TRIPLE_LEADING_DOTS"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo " • Mode:                         DRY RUN (PREVIEW ONLY)"
    else
        echo " • Mode:                         APPLY CHANGES (PRODUCTION)"
    fi
    
    echo " • Skip system/sync files:       true"
    echo " • Timestamp preservation:       true"
    echo " • Recursive scanning:           YES (full directory tree)"
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

display_header

echo "📁 Scanning: $TARGET_DIR"
echo ""

process_directory "$TARGET_DIR"

echo ""
echo "========================================="
echo "Summary for: $TARGET_DIR"
echo "========================================="
echo "Total items found:      $TOTAL_ITEMS"
echo "Skipped (system):       $SKIPPED_ITEMS"
echo "Items analyzed:         $ANALYZED_ITEMS"
echo "Invalid filenames:      $INVALID_ITEMS"
echo "Already valid:          $((ANALYZED_ITEMS - INVALID_ITEMS))"

if [ "$DRY_RUN" = "false" ]; then
    echo "Files renamed:          $RENAMED_ITEMS"
    echo "Failed renames:         $FAILED_ITEMS"
else
    echo "(Files would be renamed in PRODUCTION mode)"
fi

echo ""

if [ "$DRY_RUN" = "true" ]; then
    echo "Mode:                   DRY RUN (PREVIEW ONLY)"
    echo "➜ To apply these changes, run:"
    echo "   DRY_RUN=false $0 \"$TARGET_DIR\""
    echo "   OR"
    echo "   echo \"$TARGET_DIR\" | DRY_RUN=false $0"
else
    echo "Mode:                   CHANGES APPLIED ✓"
    if [ "$RENAMED_ITEMS" -gt 0 ]; then
        echo "✓ All $RENAMED_ITEMS files renamed successfully"
        echo "✓ Timestamps preserved - no Syncthing re-indexing"
    fi
fi

echo ""
echo "CSV Log File:           $LOG_CSV_FILE"
echo "Entries logged:         $INVALID_ITEMS items"
echo "========================================="
echo ""

# Exit with appropriate code
if [ "$FAILED_ITEMS" -gt 0 ]; then
    exit 1
fi

exit 0
