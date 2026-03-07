#!/bin/bash

# exfat-sanitizer v12.1.6 

set -o pipefail

SCRIPT_VERSION="12.1.6"
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

# Safety features
CHECK_SHELL_SAFETY="${CHECK_SHELL_SAFETY:=false}"
CHECK_UNICODE_EXPLOITS="${CHECK_UNICODE_EXPLOITS:=false}"

# Unicode handling
NORMALIZE_APOSTROPHES="${NORMALIZE_APOSTROPHES:=true}"
PRESERVE_UNICODE="${PRESERVE_UNICODE:=true}"
EXTENDED_CHARSET="${EXTENDED_CHARSET:=true}"

# Debug mode (added in v12.1.3)
DEBUG_UNICODE="${DEBUG_UNICODE:=false}"

# Interactive mode (added in v12.1.5)
# When true, prompts operator for each rename decision
INTERACTIVE="${INTERACTIVE:=false}"

# ============================================================================
# DEPENDENCY VALIDATION
# ============================================================================

check_dependencies() {
	local missing=()
	local warnings=()

	if ! command -v python3 >/dev/null 2>&1; then
		missing+=("python3")
	fi

	if ! command -v perl >/dev/null 2>&1; then
		warnings+=("perl")
	fi

	if ! command -v python3 >/dev/null 2>&1 && ! command -v perl >/dev/null 2>&1; then
		echo "❌ ERROR: UTF-8 character extraction requires Python3 or Perl" >&2
		echo "" >&2
		echo "Without these dependencies:" >&2
		echo "  - Multi-byte UTF-8 characters (accents) will be CORRUPTED" >&2
		echo "  - French (ï, ê), German (ü, ö), Italian (à, è) will be LOST" >&2
		echo "" >&2
		echo "Install with:" >&2
		echo "  macOS:  brew install python3" >&2
		echo "  Ubuntu: sudo apt install python3" >&2
		echo "" >&2
		echo "Aborting to prevent data loss." >&2
		return 1
	fi

	if [ ${#warnings[@]} -gt 0 ]; then
		echo "⚠️  Note: Optional dependency missing: ${warnings[*]}" >&2
		echo "   (Perl provides fallback UTF-8 support if Python3 fails)" >&2
	fi

	if command -v python3 >/dev/null 2>&1; then
		local py_version=$(python3 --version 2>&1 | cut -d' ' -f2)
		echo "✅ UTF-8 Support: Python ${py_version}" >&2
	elif command -v perl >/dev/null 2>&1; then
		local perl_version=$(perl --version 2>&1 | grep -o 'v[0-9.]*' | head -1)
		echo "✅ UTF-8 Support: Perl ${perl_version}" >&2
	fi

	return 0
}

# ============================================================================
# UNICODE NORMALIZATION - FIXED in v12.1.3
# ============================================================================

normalize_unicode() {
	local text="$1"
	local result=""

	# Method 1: Python3 (most reliable)
	if command -v python3 >/dev/null 2>&1; then
		result=$(python3 -c "import sys, unicodedata; print(unicodedata.normalize('NFC', sys.stdin.read().strip()))" <<< "$text" 2>/dev/null)
		if [ $? -eq 0 ] && [ -n "$result" ]; then
			echo "$result"
			return 0
		fi
	fi

	# Method 2: uconv (ICU tools)
	if command -v uconv >/dev/null 2>&1; then
		result=$(echo "$text" | uconv -f UTF-8 -t UTF-8 -x NFC 2>/dev/null)
		if [ $? -eq 0 ] && [ -n "$result" ]; then
			echo "$result"
			return 0
		fi
	fi

	# Method 3: Perl (fallback)
	if command -v perl >/dev/null 2>&1; then
		result=$(perl -CS -MUnicode::Normalize -ne 'print NFC($_)' <<< "$text" 2>/dev/null)
		if [ $? -eq 0 ] && [ -n "$result" ]; then
			echo "$result"
			return 0
		fi
	fi

	# Method 4: iconv (last resort - doesn't normalize but preserves UTF-8)
	if command -v iconv >/dev/null 2>&1; then
		result=$(echo "$text" | iconv -f UTF-8 -t UTF-8 2>/dev/null)
		if [ $? -eq 0 ] && [ -n "$result" ]; then
			echo "$result"
			return 0
		fi
	fi

	# Fallback: return original (no normalization)
	echo "$text"
}

# ============================================================================
# SYSTEM FILE FILTERING
# ============================================================================

should_skip_system_file() {
	local item="$1"
	case "$item" in
		.DS_Store|.stfolder|.sync.ffs_db|.sync.ffsdb|.Spotlight-V100|Thumbs.db|.stignore|.gitignore|.sync)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

# ============================================================================
# CHARACTER SANITIZATION FUNCTIONS
# ============================================================================

get_illegal_chars() {
	local fs="$1"
	case "$fs" in
		fat32|exfat|universal)
			echo '"*/:<>?\|'
			;;
		ntfs)
			echo '"*/:<>?\|'
			;;
		apfs)
			echo ':/'
			;;
		hfsplus)
			echo ':/'
			;;
		*)
			echo '"*/:<>?\|'
			;;
	esac
}

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
# COPY MODE FUNCTIONS
# ============================================================================

handle_file_conflict() {
	local dest_file="$1"
	local behavior="$2"

	if [ ! -e "$dest_file" ]; then
		return 0
	fi

	case "$behavior" in
		skip)
			return 1
			;;
		overwrite)
			rm -f "$dest_file" 2>/dev/null
			return 0
			;;
		version)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

copy_file() {
	local source="$1"
	local dest_dir="$2"
	local dest_filename="$3"
	local behavior="$4"
	local dest_file="$dest_dir/$dest_filename"

	if ! handle_file_conflict "$dest_file" "$behavior"; then
		if [ "$behavior" = "version" ] && [ -e "$dest_file" ]; then
			local base="${dest_file%.*}"
			local ext="${dest_file##*.}"
			local version=1
			while [ -e "$base-v$version.$ext" ]; do
				((version++))
			done
			dest_file="$base-v$version.$ext"
		else
			return 1
		fi
	fi

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
	echo "Type|Name|Path|Depth" > "$output_file"

	local _tree_depth=0

	_process_tree_recursive() {
		local current_path="$1"
		local depth="${2:-0}"
		local item

		for item in "$current_path"/*; do
			[ -e "$item" ] || continue

			local name=$(basename "$item")
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
# PHASE 2: PROCESS DIRECTORY
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

# ============================================================================
# UTF-8 Character Extraction
# ============================================================================

extract_utf8_chars() {
	local text="$1"

	# Method 1: Python3 with explicit UTF-8 preservation
	if command -v python3 >/dev/null 2>&1; then
		python3 -c "
import sys
text = sys.stdin.read().strip()
try:
	text.encode('utf-8')
	for c in text:
		print(c)
except UnicodeEncodeError:
	sys.exit(1)
" <<< "$text" 2>/dev/null && return
	fi

	# Method 2: Perl
	if command -v perl >/dev/null 2>&1; then
		perl -CSD -ne 'print "$_
" for split //' <<< "$text" 2>/dev/null && return
	fi

	# Method 3: Fallback (will break UTF-8)
	echo "⚠️  WARNING: Using grep fallback - UTF-8 may be corrupted!" >&2
	echo "$text" | grep -o .
}

# ============================================================================
# Unicode-aware Apostrophe Normalization (from v12.1.2)
# ============================================================================

normalize_apostrophes() {
	local text="$1"

	if [ "$NORMALIZE_APOSTROPHES" != "true" ]; then
		echo "$text"
		return
	fi

	# Use Python for safe Unicode handling with explicit code points
	if command -v python3 >/dev/null 2>&1; then
		python3 -c "
import sys
text = sys.stdin.read().strip()

# Map curly apostrophes/quotes to straight apostrophe
# Using explicit Unicode code points to avoid any ambiguity
replacements = {
	'\u2018': "'",  # LEFT SINGLE QUOTATION MARK
	'\u2019': "'",  # RIGHT SINGLE QUOTATION MARK
	'\u201A': "'",  # SINGLE LOW-9 QUOTATION MARK
	'\u02BC': "'",  # MODIFIER LETTER APOSTROPHE
}

for old, new in replacements.items():
	text = text.replace(old, new)

print(text)
" <<< "$text" 2>/dev/null && return
	fi

	# Fallback: If Python unavailable, skip normalization to avoid corruption
	# Better to keep curly apostrophes than corrupt Unicode characters
	echo "$text"
}

# ============================================================================
# Character Checking Logic
# ============================================================================

is_illegal_char() {
	local char="$1"
	local illegal_chars="$2"

	# Check each illegal character explicitly
	case "$char" in
		'"') [[ "$illegal_chars" == *'"'* ]] && return 0 ;;
		'*') [[ "$illegal_chars" == *'*'* ]] && return 0 ;;
		'/') [[ "$illegal_chars" == *'/'* ]] && return 0 ;;
		':') [[ "$illegal_chars" == *':'* ]] && return 0 ;;
		'<') [[ "$illegal_chars" == *'<'* ]] && return 0 ;;
		'>') [[ "$illegal_chars" == *'>'* ]] && return 0 ;;
		'?') [[ "$illegal_chars" == *'?'* ]] && return 0 ;;
		'\') [[ "$illegal_chars" == *'\'* ]] && return 0 ;;
		'|') [[ "$illegal_chars" == *'|'* ]] && return 0 ;;
	esac

	return 1  # Character is NOT illegal - PRESERVE IT
}

# ============================================================================
# FILENAME VALIDATION (for interactive mode)
# ============================================================================

validate_filename() {
	local name="$1"
	local filesystem="$2"
	local illegal_chars=$(get_illegal_chars "$filesystem")
	local found_illegal=""

	while IFS= read -r char; do
		[ -z "$char" ] && continue
		if is_illegal_char "$char" "$illegal_chars"; then
			found_illegal="${found_illegal}${char} "
		fi
	done < <(extract_utf8_chars "$name")

	if [ -n "$found_illegal" ]; then
		echo "$found_illegal"
		return 1
	fi
	return 0
}

# ============================================================================
# INTERACTIVE RENAME PROMPT (added in v12.1.5)
# ============================================================================
# Reads from /dev/tty to avoid conflicts with stdin-consuming pipelines
# (extract_utf8_chars | while read). This ensures terminal input works
# regardless of script's stdin state.

interactive_prompt() {
	local original="$1"
	local suggested="$2"
	local type="$3"
	local filesystem="$4"

	local chosen=""

	while true; do
		echo "" >/dev/tty
		echo "── Interactive Rename ──────────────────────" >/dev/tty
		echo "  Type:      $type" >/dev/tty
		echo "  Current:   $original" >/dev/tty
		echo "  Suggested: $suggested" >/dev/tty
		echo "────────────────────────────────────────────" >/dev/tty
		echo -n "  Enter new name (or press Enter to accept suggested): " >/dev/tty

		IFS= read -r chosen </dev/tty

		# Empty input = accept suggested name
		if [ -z "$chosen" ]; then
			chosen="$suggested"
		fi

		# Validate against filesystem illegal characters
		local illegal_found
		illegal_found=$(validate_filename "$chosen" "$filesystem")
		if [ $? -ne 0 ]; then
			echo "  ⚠️  Invalid! Illegal characters for $filesystem found: $illegal_found" >/dev/tty
			echo "  Please try again." >/dev/tty
			continue
		fi

		# Check for reserved names on FAT32/universal
		if [ "$filesystem" = "fat32" ] || [ "$filesystem" = "universal" ]; then
			local basename_only="${chosen%.*}"
			if is_reserved_name "$basename_only"; then
				echo "  ⚠️  '$basename_only' is a Windows reserved name (CON, PRN, AUX, etc.)" >/dev/tty
				echo "  Please try again." >/dev/tty
				continue
			fi
		fi

		# Check for empty name after stripping leading/trailing spaces and dots
		local trimmed=$(echo "$chosen" | sed 's/^[[:space:].]*//;s/[[:space:].]*$//')
		if [ -z "$trimmed" ]; then
			echo "  ⚠️  Name cannot be empty or consist only of spaces/dots." >/dev/tty
			echo "  Please try again." >/dev/tty
			continue
		fi

		break
	done

	echo "$chosen"
}

# ============================================================================
# MAIN SANITIZATION FUNCTION - REWRITTEN in v12.1.6 (Python pipeline)
# ============================================================================

sanitize_filename() {
	local name="$1"
	local mode="$2"
	local filesystem="$3"

	# Normalize apostrophes BEFORE processing (from v12.1.2)
	# Uses Unicode-aware Python implementation instead of bash globs
	if [ "$NORMALIZE_APOSTROPHES" = "true" ]; then
		name=$(normalize_apostrophes "$name")
	fi

	local illegal_chars=$(get_illegal_chars "$filesystem")
	local sanitized=""

	# 🔴 FIX v12.1.5: Entire character-level sanitization now runs in Python
	# Previous approach (extract_utf8_chars | while read in bash) lost multibyte
	# characters like È (U+00C8) when bytes were split during bash pipe processing.
	# Moving ALL character checks into Python ensures Unicode integrity.
	if command -v python3 >/dev/null 2>&1; then
		sanitized=$(python3 -c "
import sys

text = sys.stdin.read().strip()
illegal_chars = sys.argv[1]
mode = sys.argv[2]
replacement = sys.argv[3]
check_shell_safety = sys.argv[4] == 'true'
check_unicode_exploits = sys.argv[5] == 'true'

# Shell-dangerous characters (when CHECK_SHELL_SAFETY is enabled)
shell_dangerous = set('\$\`&;#~^!()')

# Zero-width characters (when CHECK_UNICODE_EXPLOITS is enabled)
zero_width = {'\u200B', '\u200C', '\u200D', '\uFEFF'}

result = []
for c in text:
    cp = ord(c)

    # Control characters (ASCII 0-31, 127): drop in conservative/permissive, replace in strict
    if cp < 32 or cp == 127:
        if mode == 'strict':
            result.append(replacement)
        continue

    # Shell-dangerous characters (if enabled)
    if check_shell_safety and c in shell_dangerous:
        result.append(replacement)
        continue

    # Zero-width characters (if enabled)
    if check_unicode_exploits and c in zero_width:
        continue

    # Filesystem illegal characters
    if c in illegal_chars:
        if mode in ('strict', 'conservative'):
            result.append(replacement)
        # In permissive mode, illegal chars are dropped
        continue

    # Character is legal — PRESERVE IT
    result.append(c)

sanitized = ''.join(result)

# Remove leading/trailing spaces and dots
sanitized = sanitized.strip(' .')

print(sanitized)
" "$illegal_chars" "$mode" "$REPLACEMENT_CHAR" "$CHECK_SHELL_SAFETY" "$CHECK_UNICODE_EXPLOITS" <<< "$name" 2>/dev/null)

		if [ $? -ne 0 ] || [ -z "$sanitized" ]; then
			# Python failed or result is empty — fall through to bash fallback
			sanitized=""
		fi
	fi

	# Bash fallback: only used if Python is unavailable or fails
	# ⚠️  WARNING: This path may lose multibyte Unicode characters!
	if [ -z "$sanitized" ]; then
		echo "⚠️  WARNING: Using bash fallback for sanitization - UTF-8 may be affected!" >&2
		while IFS= read -r char; do
			[ -z "$char" ] && continue

			if [ ${#char} -eq 1 ]; then
				local ascii=$(printf '%d' "'$char" 2>/dev/null || echo 32)
				if [ "$ascii" -lt 32 ] || [ "$ascii" -eq 127 ]; then
					if [ "$mode" = "strict" ]; then
						sanitized="${sanitized}${REPLACEMENT_CHAR}"
					fi
					continue
				fi
			fi

			if [ "$CHECK_SHELL_SAFETY" = "true" ]; then
				case "$char" in
					'$'|'`'|'&'|';'|'#'|'~'|'^'|'!'|'('|')')
						sanitized="${sanitized}${REPLACEMENT_CHAR}"
						continue
						;;
				esac
			fi

			if ! is_illegal_char "$char" "$illegal_chars"; then
				sanitized="$sanitized$char"
			else
				if [ "$mode" = "strict" ] || [ "$mode" = "conservative" ]; then
					sanitized="${sanitized}${REPLACEMENT_CHAR}"
				fi
			fi
		done < <(extract_utf8_chars "$name")

		sanitized=$(echo "$sanitized" | sed 's/^[[:space:].]*//;s/[[:space:].]*$//')
	fi

	# Handle empty result
	if [ -z "$sanitized" ]; then
		sanitized="unnamed_file"
	fi

	# Check for reserved names (FAT32/exFAT/NTFS/universal)
	if [ "$filesystem" = "fat32" ] || [ "$filesystem" = "exfat" ] || [ "$filesystem" = "ntfs" ] || [ "$filesystem" = "universal" ]; then
		local basename_only="${sanitized%.*}"
		if is_reserved_name "$basename_only"; then
			sanitized="_${sanitized}"
		fi
	fi

	echo "$sanitized"
}

# ============================================================================
# MAIN PROCESSING - Updated in v12.1.6 (interactive mode + Python pipeline)
# ============================================================================

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
			should_skip_system_file "$name" && continue

			local relative_path="${item#$source_dir/}"
			local type="File"

			if [ -d "$item" ]; then
				type="Directory"
			fi

			((_total_scanned++))

			if should_ignore "$relative_path" "$IGNORE_FILE"; then
				echo "$type|$name|$name|-|$relative_path|${#relative_path}|IGNORED|NA|match" >> "$output_file"
				((_total_ignored++))

				if [ "$type" = "Directory" ]; then
					_process_items_recursive "$item"
				fi
				continue
			fi

			# 🔴 FIX v12.1.3: Normalize the original name FIRST
			# This ensures NFD from filesystem becomes NFC for comparison
			local name_nfc=$(normalize_unicode "$name")

			# Sanitize using the NFC-normalized name
			local sanitized=$(sanitize_filename "$name_nfc" "$SANITIZATION_MODE" "$FILESYSTEM")

			# 🔴 FIX v12.1.3: Normalize BOTH strings to NFC before comparison
			# This prevents NFD!=NFC false positives
			local name_normalized=$(normalize_unicode "$name_nfc")
			local sanitized_normalized=$(normalize_unicode "$sanitized")

			# Debug output (if enabled)
			if [ "$DEBUG_UNICODE" = "true" ]; then
				echo "DEBUG: Original: '$name' → NFC: '$name_nfc'" >&2
				echo "DEBUG: Sanitized: '$sanitized' → NFC: '$sanitized_normalized'" >&2
				if [ "$name_normalized" != "$sanitized_normalized" ]; then
					echo "DEBUG: MISMATCH DETECTED" >&2
				fi
			fi

			local copy_status="NA"

			# Compare normalized strings
			if [ "$sanitized_normalized" != "$name_normalized" ]; then
				local final_name="$sanitized"

				# Interactive mode: prompt operator for the new name
				if [ "$INTERACTIVE" = "true" ]; then
					final_name=$(interactive_prompt "$name" "$sanitized" "$type" "$FILESYSTEM")
				fi

				echo "$type|$name|$final_name|-|$relative_path|${#relative_path}|RENAMED|$copy_status|-" >> "$output_file"
				((_total_renamed++))

				if [ "$DRY_RUN" != "true" ]; then
					local new_path="$(dirname "$item")/$final_name"
					if [ -e "$new_path" ] && [ "$new_path" != "$item" ]; then
						echo "$type|$name|$final_name|COLLISION|$relative_path|${#relative_path}|FAILED|NA|-" >> "$output_file"
					else
						mv "$item" "$new_path" 2>/dev/null || true
						item="$new_path"
					fi
				fi
			else
				echo "$type|$name|$name|-|$relative_path|${#relative_path}|LOGGED|$copy_status|-" >> "$output_file"
			fi

			if [ -n "$COPY_TO" ] && [ "$type" = "File" ]; then
				local dest_dir="$COPY_TO/$(dirname "$relative_path")"
				mkdir -p "$dest_dir" 2>/dev/null

				if [ "$DRY_RUN" != "true" ]; then
					if copy_file "$item" "$dest_dir" "${final_name:-$sanitized}" "$COPY_BEHAVIOR"; then
						copy_status="COPIED"
						((_total_copied++))
					else
						copy_status="SKIPPED"
						((_total_skipped++))
					fi
				fi
			fi

			if [ "$type" = "Directory" ]; then
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
		echo "Usage: $SCRIPT_NAME [OPTIONS] <directory>"
		echo ""
		echo "v12.1.6 — Python-Based Sanitization + Interactive Mode"
		echo ""
		echo "   ✅ Full Python sanitization pipeline — native Unicode safety"
		echo "   ✅ All accented characters preserved (à è é ì ò ù ï ê â ä ö ü È)"
		echo "   ✅ Apostrophes preserved on all filesystems"
		echo "   ✅ Interactive mode (INTERACTIVE=true) for operator-driven renames"
		echo "   ✅ NFD/NFC normalization — no false RENAMED on macOS"
		echo "   ✅ Reserved name detection (CON, PRN, AUX, NUL, COM1-9, LPT1-9)"
		echo ""
		echo "Environment Variables:"
		echo "  FILESYSTEM=fat32|exfat|ntfs|apfs|universal|hfsplus (default: fat32)"
		echo "  SANITIZATION_MODE=strict|conservative|permissive (default: conservative)"
		echo "  DRY_RUN=true|false (default: true)"
		echo "  COPY_TO=<path> (optional)"
		echo "  COPY_BEHAVIOR=skip|overwrite|version (default: skip)"
		echo "  IGNORE_FILE=<path> (default: ~/.exfat-sanitizer-ignore)"
		echo "  GENERATE_TREE=true|false (default: false)"
		echo "  REPLACEMENT_CHAR=<char> (default: _)"
		echo ""
		echo "Safety Options:"
		echo "  CHECK_SHELL_SAFETY=true|false (default: false)"
		echo "  CHECK_UNICODE_EXPLOITS=true|false (default: false)"
		echo ""
		echo "Unicode Handling:"
		echo "  PRESERVE_UNICODE=true|false (default: true)"
		echo "  NORMALIZE_APOSTROPHES=true|false (default: true)"
		echo "  EXTENDED_CHARSET=true|false (default: true)"
		echo "  DEBUG_UNICODE=true|false (default: false) - Added in v12.1.3"
		echo ""
		echo "Interactive Mode:"
		echo "  INTERACTIVE=true|false (default: false)"
		echo "    When enabled, prompts operator for each rename decision."
		echo "    Shows current name and auto-suggested replacement."
		echo "    Validates operator input against filesystem rules."
		echo "    Works with DRY_RUN=true (preview) or DRY_RUN=false (apply)."
		echo ""
		return 1
	fi

	local target_dir="$1"

	if [ ! -d "$target_dir" ]; then
		echo "Error: Directory not found: $target_dir" >&2
		return 1
	fi

	echo "========== EXFAT-SANITIZER v$SCRIPT_VERSION =========="
	echo "✅ v12.1.6: Python-based sanitization — full Unicode safety + interactive mode"
	echo "Scanning: $target_dir"
	echo "Filesystem: $FILESYSTEM"
	echo "Sanitization Mode: $SANITIZATION_MODE"
	echo "Dry Run: $DRY_RUN"
	echo "Preserve Unicode: $PRESERVE_UNICODE"
	echo "Normalize Apostrophes: $NORMALIZE_APOSTROPHES"
	echo "Extended Charset: $EXTENDED_CHARSET"
	echo "Interactive Mode: $INTERACTIVE"
	if [ "$INTERACTIVE" = "true" ]; then
		echo "  → You will be prompted for each rename decision"
		if [ "$DRY_RUN" = "true" ]; then
			echo "  → DRY_RUN is ON: choices will be logged but NOT applied"
		fi
	fi
	echo ""

	if ! check_dependencies; then
		return 1
	fi

	echo ""

	if [ "$GENERATE_TREE" = "true" ]; then
		local tree_file=$(generate_tree_snapshot "$target_dir")
		echo "✅ Tree Snapshot: $tree_file"
	fi

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
	echo "v12.1.6: Python sanitization pipeline — all accents and apostrophes preserved ✅"
	echo "Expected: RENAMED only for files with filesystem-illegal characters"
	echo "Expected: LOGGED (not RENAMED) for all accented characters (È, è, à, ì, ò, ù, ï, ê)"
}

main "$@"
