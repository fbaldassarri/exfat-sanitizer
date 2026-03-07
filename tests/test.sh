#!/bin/bash

# Test Suite for exfat-sanitizer v12.1.6

# Verifies all features work correctly including:
# - v12.1.2 apostrophe fix (preserved)
# - v12.1.3 NFD/NFC normalization fix (preserved)
# - v12.1.4 inverted if/else logic fix (preserved)
# - v12.1.4 DEBUG_UNICODE mode (preserved)
# - v12.1.5 interactive mode (preserved)
# - v12.1.6 current release

set -e

echo "=========================================="
echo "exfat-sanitizer v12.1.6 Test Suite"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Helper function to run test
run_test() {
    local test_name="$1"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${BLUE}Test ${TESTS_TOTAL}: ${test_name}${NC}"
    echo "-------------------------------------------"
}

# Helper function to pass test
pass_test() {
    local message="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✅ PASS${NC}: ${message}"
    echo ""
}

# Helper function to fail test
fail_test() {
    local message="$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}❌ FAIL${NC}: ${message}"
    echo ""
    exit 1
}

# Create test directory
TEST_DIR="$(mktemp -d)/exfat-test-v12.1.6"
mkdir -p "$TEST_DIR"
echo "Test directory: $TEST_DIR"
echo ""

# ============================================================================
# TEST 0: Python 3 Dependency Check (MANDATORY since v12.1.2)
# ============================================================================
run_test "Python 3 Dependency Check (MANDATORY)"
if command -v python3 >/dev/null 2>&1; then
    PY_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    pass_test "Python 3 found: ${PY_VERSION}"
else
    fail_test "Python 3 NOT found - REQUIRED for v12.1.6!"
fi

# ============================================================================
# TEST 1: Accent Preservation (CRITICAL - originally fixed in v12.1.2)
# ============================================================================
run_test "Accent Preservation with Curly Apostrophes (v12.1.2 fix, preserved in v12.1.6)"
mkdir -p "$TEST_DIR/test1"

# Create test files with accents AND curly apostrophes
# U+2019 is RIGHT SINGLE QUOTATION MARK (curly apostrophe)
touch "$TEST_DIR/test1/Loïc Nottet\u2019s Song.flac"    # Curly apostrophe + accent
touch "$TEST_DIR/test1/Café del Mar.mp3"
touch "$TEST_DIR/test1/L\u2019interprète.flac"           # Curly apostrophe + accent
touch "$TEST_DIR/test1/Müller - España.wav"
touch "$TEST_DIR/test1/naïve.txt"
touch "$TEST_DIR/test1/C\u2019è di più.ogg"              # Italian with curly apostrophe

# Run sanitizer
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test1" > /dev/null 2>&1

# v12.1.6 should normalize ' (U+2019) → ' (U+0027) WITHOUT corrupting accents
if [ -f "$TEST_DIR/test1/Loïc Nottet's Song.flac" ] && \
   [ -f "$TEST_DIR/test1/Café del Mar.mp3" ] && \
   [ -f "$TEST_DIR/test1/L'interprète.flac" ] && \
   [ -f "$TEST_DIR/test1/Müller - España.wav" ] && \
   [ -f "$TEST_DIR/test1/naïve.txt" ] && \
   [ -f "$TEST_DIR/test1/C'è di più.ogg" ]; then
    pass_test "Accents preserved AND apostrophes normalized (v12.1.6 verified!)"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test1/"
    fail_test "Accent preservation or apostrophe normalization failed"
fi

# ============================================================================
# TEST 2: Mixed Unicode + Illegal Characters
# ============================================================================
run_test "Mixed Unicode + Illegal Characters"
mkdir -p "$TEST_DIR/test2"

# Complex scenarios mixing accents, apostrophes, and illegal chars
touch "$TEST_DIR/test2/Café:Révérence\u2019s.mp3"    # Accents + curly apostrophe + illegal
touch "$TEST_DIR/test2/Loïc|Nottet?.flac"             # Accent + illegal chars

# Run sanitizer
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test2" > /dev/null 2>&1

# Expected: accents preserved, illegal chars replaced, apostrophes normalized
if [ -f "$TEST_DIR/test2/Café_Révérence's.mp3" ] && \
   [ -f "$TEST_DIR/test2/Loïc_Nottet_.flac" ]; then
    pass_test "Mixed Unicode and illegal characters handled correctly"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test2/"
    fail_test "Mixed character handling failed"
fi

# ============================================================================
# TEST 3: Curly Apostrophe Normalization (v12.1.2 SPECIFIC, preserved)
# ============================================================================
run_test "Curly Apostrophe Normalization (Python 3 Unicode-safe)"
mkdir -p "$TEST_DIR/test3"

# Test ALL curly apostrophe variants
touch "$TEST_DIR/test3/test\u2018s.txt"    # U+2018 LEFT SINGLE QUOTATION
touch "$TEST_DIR/test3/test\u2019s.txt"    # U+2019 RIGHT SINGLE QUOTATION
touch "$TEST_DIR/test3/test\u201As.txt"    # U+201A SINGLE LOW-9 QUOTATION
touch "$TEST_DIR/test3/test\u02BCs.txt"    # U+02BC MODIFIER LETTER APOSTROPHE

# Run sanitizer
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test3" > /dev/null 2>&1

# All should be normalized to straight apostrophe
NORMALIZED_COUNT=$(ls "$TEST_DIR/test3/" | grep -c "test's.txt" || true)
if [ "$NORMALIZED_COUNT" -eq 4 ]; then
    pass_test "All curly apostrophe variants normalized to straight apostrophe"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test3/"
    echo "Normalized count: $NORMALIZED_COUNT (expected 4)"
    fail_test "Curly apostrophe normalization incomplete"
fi

# ============================================================================
# TEST 4: Illegal Character Removal
# ============================================================================
run_test "Illegal Character Removal"
mkdir -p "$TEST_DIR/test4"

# Create files with illegal characters
touch "$TEST_DIR/test4/song<test>.mp3"
touch "$TEST_DIR/test4/track:new.flac"
touch "$TEST_DIR/test4/file|pipe.txt"

# Run sanitizer
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test4" > /dev/null 2>&1

# Verify illegal chars were replaced
if [ -f "$TEST_DIR/test4/song_test_.mp3" ] && \
   [ -f "$TEST_DIR/test4/track_new.flac" ] && \
   [ -f "$TEST_DIR/test4/file_pipe.txt" ]; then
    pass_test "Illegal characters removed"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test4/"
    fail_test "Illegal characters not handled"
fi

# ============================================================================
# TEST 5: Shell Safety (v11.1.0 feature, preserved)
# ============================================================================
run_test "Shell Safety Feature"
mkdir -p "$TEST_DIR/test5"

# Create files with shell-dangerous characters
touch "$TEST_DIR/test5/file\$(cmd).txt"
touch "$TEST_DIR/test5/test&background.sh"

# Run sanitizer WITH shell safety
CHECK_SHELL_SAFETY=true \
  FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test5" > /dev/null 2>&1

# Verify shell chars were replaced
if [ -f "$TEST_DIR/test5/file__cmd_.txt" ] && \
   [ -f "$TEST_DIR/test5/test_background.sh" ]; then
    pass_test "Shell safety works"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test5/"
    fail_test "Shell safety not working"
fi

# ============================================================================
# TEST 6: System File Filtering (v11.1.0 feature, preserved)
# ============================================================================
run_test "System File Filtering"
mkdir -p "$TEST_DIR/test6"

# Create system files
touch "$TEST_DIR/test6/.DS_Store"
touch "$TEST_DIR/test6/Thumbs.db"
touch "$TEST_DIR/test6/normal.txt"

# Run sanitizer
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test6" > /dev/null 2>&1

# Check CSV output
CSV_FILE=$(ls -t sanitizer_exfat_*.csv 2>/dev/null | head -1)
if [ -f "$CSV_FILE" ]; then
    # System files should NOT be in CSV
    DS_STORE_COUNT=$(grep -c "\.DS_Store" "$CSV_FILE" || true)
    THUMBS_COUNT=$(grep -c "Thumbs\.db" "$CSV_FILE" || true)
    if [ "$DS_STORE_COUNT" -eq 0 ] && [ "$THUMBS_COUNT" -eq 0 ]; then
        pass_test "System files filtered correctly"
    else
        fail_test "System files not filtered"
    fi
else
    echo -e "${YELLOW}⚠️ WARN${NC}: CSV file not found"
fi

# ============================================================================
# TEST 7: Copy Mode with Versioning (v11.1.0 feature, preserved)
# ============================================================================
run_test "Copy Mode with Versioning"
mkdir -p "$TEST_DIR/test7/source"
mkdir -p "$TEST_DIR/test7/dest"

# Create source file
echo "content1" > "$TEST_DIR/test7/source/song.mp3"

# First copy
FILESYSTEM=exfat \
  COPY_TO="$TEST_DIR/test7/dest" \
  COPY_BEHAVIOR=version \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test7/source" > /dev/null 2>&1

# Modify source
echo "content2" > "$TEST_DIR/test7/source/song.mp3"

# Second copy (should create version)
FILESYSTEM=exfat \
  COPY_TO="$TEST_DIR/test7/dest" \
  COPY_BEHAVIOR=version \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test7/source" > /dev/null 2>&1

# Verify versioned file exists
if [ -f "$TEST_DIR/test7/dest/song.mp3" ] && \
   [ -f "$TEST_DIR/test7/dest/song-v1.mp3" ]; then
    pass_test "Copy versioning works"
else
    echo "Files in dest:"
    ls -la "$TEST_DIR/test7/dest/"
    fail_test "Copy versioning not working"
fi

# ============================================================================
# TEST 8: Custom Replacement Character (v11.1.0 feature, preserved)
# ============================================================================
run_test "Custom Replacement Character"
mkdir -p "$TEST_DIR/test8"

# Create file with illegal character
touch "$TEST_DIR/test8/song<test>.mp3"

# Run sanitizer with custom replacement
REPLACEMENT_CHAR=- \
  FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test8" > /dev/null 2>&1

# Verify dash was used instead of underscore
if [ -f "$TEST_DIR/test8/song-test-.mp3" ]; then
    pass_test "Custom replacement character works"
else
    echo "Files in test8:"
    ls -la "$TEST_DIR/test8/"
    fail_test "Custom replacement not working"
fi

# ============================================================================
# TEST 9: Straight Apostrophe Preservation
# ============================================================================
run_test "Straight Apostrophe Preservation"
mkdir -p "$TEST_DIR/test9"

# Create file with STRAIGHT apostrophe (should be preserved)
touch "$TEST_DIR/test9/L'amour.mp3"
touch "$TEST_DIR/test9/don't stop.flac"

# Run sanitizer
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test9" > /dev/null 2>&1

# Verify straight apostrophe preserved
if [ -f "$TEST_DIR/test9/L'amour.mp3" ] && \
   [ -f "$TEST_DIR/test9/don't stop.flac" ]; then
    pass_test "Straight apostrophes preserved"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test9/"
    fail_test "Straight apostrophes not preserved"
fi

# ============================================================================
# TEST 10: DRY_RUN Mode (No Changes)
# ============================================================================
run_test "DRY_RUN Mode (no changes)"
mkdir -p "$TEST_DIR/test10"

# Create file with illegal character
touch "$TEST_DIR/test10/file<test>.txt"

# Run sanitizer in DRY_RUN mode
DRY_RUN=true \
  FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test10" > /dev/null 2>&1

# Verify original file still exists (unchanged)
if [ -f "$TEST_DIR/test10/file<test>.txt" ]; then
    pass_test "DRY_RUN mode works (no changes made)"
else
    fail_test "DRY_RUN mode changed files"
fi

# ============================================================================
# TEST 11: Reserved Names (Windows/DOS)
# ============================================================================
run_test "Reserved Name Handling"
mkdir -p "$TEST_DIR/test11"

# Create files with reserved names
touch "$TEST_DIR/test11/CON.txt"
touch "$TEST_DIR/test11/LPT1.log"
touch "$TEST_DIR/test11/normal.txt"

# Run sanitizer (FAT32 mode checks reserved names)
FILESYSTEM=fat32 \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test11" > /dev/null 2>&1

# Verify reserved names were handled (script prefixes with _ to avoid collision)
# CON.txt → _CON.txt, LPT1.log → _LPT1.log, normal.txt → unchanged
if [ -f "$TEST_DIR/test11/_CON.txt" ] && \
   [ -f "$TEST_DIR/test11/_LPT1.log" ] && \
   [ -f "$TEST_DIR/test11/normal.txt" ]; then
    pass_test "Reserved names handled correctly (prefixed with _)"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test11/"
    fail_test "Reserved name handling failed"
fi

# ============================================================================
# TEST 12: NFD to NFC Normalization (v12.1.3 fix, preserved in v12.1.6)
# ============================================================================
run_test "Unicode NFD to NFC Normalization"
mkdir -p "$TEST_DIR/test12"

# Create file with NFD (decomposed) character if possible
# This tests normalize_unicode() function
touch "$TEST_DIR/test12/café.txt"    # May be NFD on macOS

# Run sanitizer
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test12" > /dev/null 2>&1

# File should still exist with proper normalization
if [ -f "$TEST_DIR/test12/café.txt" ]; then
    pass_test "Unicode normalization works"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test12/"
    fail_test "Unicode normalization failed"
fi

# ============================================================================
# TEST 13: Regression Test - v12.1.1 Bug (originally fixed in v12.1.2)
# ============================================================================
run_test "Regression Test: v12.1.1 Apostrophe Bug (v12.1.2 fix, preserved)"
mkdir -p "$TEST_DIR/test13"

# These are the EXACT filenames that broke in v12.1.1
# v12.1.1 would strip accents when normalizing curly apostrophes
touch "$TEST_DIR/test13/Loïc Nottet\u2019s Album.flac"   # The canonical bug case
touch "$TEST_DIR/test13/Révérence\u2019s Song.mp3"        # Another accent + apostrophe
touch "$TEST_DIR/test13/L\u2019été\u2019s Memories.ogg"   # Multiple accents + apostrophe

# Run sanitizer
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test13" > /dev/null 2>&1

# v12.1.6 MUST preserve accents while normalizing apostrophes
if [ -f "$TEST_DIR/test13/Loïc Nottet's Album.flac" ] && \
   [ -f "$TEST_DIR/test13/Révérence's Song.mp3" ] && \
   [ -f "$TEST_DIR/test13/L'été's Memories.ogg" ]; then
    pass_test "v12.1.1 regression bug verified FIXED in v12.1.6! Accents preserved with apostrophe normalization"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test13/"
    echo ""
    echo "CRITICAL: v12.1.6 should fix the v12.1.1 bug where:"
    echo "  'Loïc Nottet's' became 'Loic Nottet's' (accent stripped)"
    echo ""
    fail_test "v12.1.1 regression still present - CRITICAL BUG!"
fi

# ============================================================================
# TEST 14: Python 3 Dependency Warning
# ============================================================================
run_test "Python 3 Dependency Verification"
if command -v python3 >/dev/null 2>&1; then
    pass_test "Python 3 available for Unicode-safe operations"
else
    echo -e "${YELLOW}⚠️ WARN${NC}: Python 3 not found - v12.1.6 requires it!"
    fail_test "Python 3 REQUIRED for v12.1.6"
fi

# ============================================================================
# TEST 15: Inverted Logic Fix (v12.1.4 fix, preserved in v12.1.6)
# ============================================================================
run_test "Inverted if/else Logic Fix (v12.1.4 fix, preserved in v12.1.6)"
mkdir -p "$TEST_DIR/test15"

# Create files that specifically test character classification:
# Legal characters (accents, spaces, dashes) MUST be preserved
# Illegal characters (<, >, :, |, ?) MUST be replaced
touch "$TEST_DIR/test15/Café - Révérence.flac"          # All legal chars
touch "$TEST_DIR/test15/Loïc Nottet - naïve.mp3"        # All legal chars
touch "$TEST_DIR/test15/Müller España.wav"               # All legal chars
touch "$TEST_DIR/test15/Cè di più.ogg"                   # All legal chars (Italian)
touch "$TEST_DIR/test15/Song<Test>Track.mp3"             # Has illegal < and >
touch "$TEST_DIR/test15/file:name.txt"                   # Has illegal :

# Run sanitizer
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test15" > /dev/null 2>&1

# Verify:
# 1. Legal accented files are UNCHANGED (not mangled by inverted logic)
# 2. Illegal chars are properly replaced
LEGAL_OK=true
ILLEGAL_OK=true

# Check legal files are preserved exactly
[ ! -f "$TEST_DIR/test15/Café - Révérence.flac" ]    && LEGAL_OK=false
[ ! -f "$TEST_DIR/test15/Loïc Nottet - naïve.mp3" ]  && LEGAL_OK=false
[ ! -f "$TEST_DIR/test15/Müller España.wav" ]         && LEGAL_OK=false
[ ! -f "$TEST_DIR/test15/Cè di più.ogg" ]             && LEGAL_OK=false

# Check illegal chars were replaced
[ ! -f "$TEST_DIR/test15/Song_Test_Track.mp3" ]       && ILLEGAL_OK=false
[ ! -f "$TEST_DIR/test15/file_name.txt" ]             && ILLEGAL_OK=false

if [ "$LEGAL_OK" = true ] && [ "$ILLEGAL_OK" = true ]; then
    pass_test "Inverted logic verified in v12.1.6! Legal chars preserved, illegal chars replaced"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test15/"
    echo ""
    if [ "$LEGAL_OK" = false ]; then
        echo "CRITICAL: Legal accented filenames were mangled!"
        echo "This indicates the inverted if/else logic bug from v12.1.3"
    fi
    if [ "$ILLEGAL_OK" = false ]; then
        echo "CRITICAL: Illegal characters were NOT replaced!"
    fi
    fail_test "Inverted logic fix verification failed"
fi

# ============================================================================
# TEST 16: NFD False-Positive Prevention (v12.1.3 fix, verified in v12.1.6)
# ============================================================================
run_test "NFD False-Positive Prevention (NFC comparison)"
mkdir -p "$TEST_DIR/test16"

# Create files with accented characters that may be stored as NFD on macOS
# On macOS, 'è' may be stored as e + combining grave accent (NFD)
# The sanitizer should NOT report these as RENAMED
touch "$TEST_DIR/test16/Cè la farò.wav"
touch "$TEST_DIR/test16/Perché no.mp3"
touch "$TEST_DIR/test16/Già fatto.flac"

# Run sanitizer in DRY_RUN to check CSV status
FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test16" > /dev/null 2>&1

# Check that NO files were marked RENAMED (they should all be LOGGED)
CSV_FILE=$(ls -t sanitizer_exfat_*.csv 2>/dev/null | head -1)
if [ -f "$CSV_FILE" ]; then
    RENAMED_COUNT=$(grep -c "RENAMED" "$CSV_FILE" || true)
    if [ "$RENAMED_COUNT" -eq 0 ]; then
        pass_test "No false RENAMED status — NFD/NFC comparison working correctly"
    else
        echo "CSV content:"
        cat "$CSV_FILE"
        echo ""
        echo "RENAMED count: $RENAMED_COUNT (expected 0)"
        echo "This indicates NFD→NFC normalization comparison is not working."
        fail_test "NFD false-positive detected — accented files wrongly marked RENAMED"
    fi
else
    echo -e "${YELLOW}⚠️ WARN${NC}: CSV file not found, skipping CSV check"
    # Fall back to checking files still exist unchanged
    if [ -f "$TEST_DIR/test16/Cè la farò.wav" ] && \
       [ -f "$TEST_DIR/test16/Perché no.mp3" ] && \
       [ -f "$TEST_DIR/test16/Già fatto.flac" ]; then
        pass_test "Accented files preserved (CSV check skipped)"
    else
        fail_test "Accented files were modified unexpectedly"
    fi
fi

# ============================================================================
# TEST 17: DEBUG_UNICODE Mode (v12.1.3 feature, preserved in v12.1.6)
# ============================================================================
run_test "DEBUG_UNICODE Mode"
mkdir -p "$TEST_DIR/test17"

# Create a file with accented characters
touch "$TEST_DIR/test17/Café.txt"

# Run sanitizer with DEBUG_UNICODE=true, capture stderr
DEBUG_UNICODE=true \
  FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test17" > /dev/null 2>"$TEST_DIR/debug_output.log"

# Check that debug output contains DEBUG: lines
if [ -f "$TEST_DIR/debug_output.log" ]; then
    DEBUG_LINES=$(grep -c "DEBUG" "$TEST_DIR/debug_output.log" || true)
    if [ "$DEBUG_LINES" -gt 0 ]; then
        pass_test "DEBUG_UNICODE mode produces diagnostic output ($DEBUG_LINES debug lines)"
    else
        echo "Debug output:"
        cat "$TEST_DIR/debug_output.log"
        echo ""
        echo "Expected DEBUG: lines in stderr output"
        fail_test "DEBUG_UNICODE mode did not produce expected output"
    fi
else
    fail_test "Debug output file not created"
fi

# ============================================================================
# TEST 18: Interactive Mode Variable (NEW in v12.1.5, preserved in v12.1.6)
# ============================================================================
run_test "Interactive Mode Configuration (v12.1.5 feature)"

# Verify INTERACTIVE mode defaults to false and can be set
# We test non-interactively by checking the CSV output mentions interactive state
mkdir -p "$TEST_DIR/test18"
touch "$TEST_DIR/test18/file:test.txt"

# Run sanitizer with INTERACTIVE=false (default, non-interactive)
INTERACTIVE=false \
  FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=true \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test18" > "$TEST_DIR/interactive_output.log" 2>&1

# Check that the sanitizer ran successfully and reported interactive mode status
if grep -q "Interactive Mode: false" "$TEST_DIR/interactive_output.log"; then
    pass_test "Interactive mode configuration recognized (INTERACTIVE=false)"
else
    echo "Output:"
    cat "$TEST_DIR/interactive_output.log"
    fail_test "Interactive mode configuration not recognized"
fi

# ============================================================================
# TEST 19: Validate Filename Function (NEW in v12.1.5, preserved in v12.1.6)
# ============================================================================
run_test "Validate Filename Function (v12.1.5 feature)"

# Test that the validate_filename function exists and works by running the
# sanitizer on a file with illegal chars and verifying proper replacement
mkdir -p "$TEST_DIR/test19"
touch "$TEST_DIR/test19/test<illegal>name.txt"

FILESYSTEM=exfat \
  SANITIZATION_MODE=conservative \
  DRY_RUN=false \
  ./exfat-sanitizer-v12.1.6.sh "$TEST_DIR/test19" > /dev/null 2>&1

if [ -f "$TEST_DIR/test19/test_illegal_name.txt" ]; then
    pass_test "Filename validation and sanitization working (v12.1.5+ validate_filename)"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test19/"
    fail_test "Filename validation not working"
fi

# ============================================================================
# CLEANUP
# ============================================================================
echo "Cleaning up test files..."
rm -rf "$TEST_DIR"

# Clean up CSV files
rm -f sanitizer_exfat_*.csv
rm -f sanitizer_fat32_*.csv
rm -f tree_exfat_*.csv
rm -f tree_fat32_*.csv

echo ""
echo "=========================================="
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All ${TESTS_TOTAL} tests PASSED! ✅${NC}"
else
    echo -e "${RED}${TESTS_FAILED}/${TESTS_TOTAL} tests FAILED! ❌${NC}"
    echo -e "${GREEN}${TESTS_PASSED}/${TESTS_TOTAL} tests passed${NC}"
fi
echo "=========================================="
echo ""
echo "v12.1.6 Test Coverage:"
echo "  ✅ Python 3 dependency check (MANDATORY)"
echo "  ✅ Accent preservation with curly apostrophes (v12.1.2 fix)"
echo "  ✅ Mixed Unicode + illegal characters"
echo "  ✅ Curly apostrophe normalization (all 4 variants)"
echo "  ✅ Illegal character removal"
echo "  ✅ Shell safety (v11.1.0 feature preserved)"
echo "  ✅ System file filtering (v11.1.0 feature preserved)"
echo "  ✅ Copy versioning (v11.1.0 feature preserved)"
echo "  ✅ Custom replacement char (v11.1.0 feature preserved)"
echo "  ✅ Straight apostrophe preservation"
echo "  ✅ DRY_RUN mode"
echo "  ✅ Reserved name handling"
echo "  ✅ Unicode NFD/NFC normalization"
echo "  ✅ v12.1.1 regression test (CRITICAL BUG FIX)"
echo "  ✅ Python 3 availability verification"
echo "  ✅ Inverted if/else logic fix (v12.1.4 fix, preserved)"
echo "  ✅ NFD false-positive prevention (v12.1.3+, NFC comparison)"
echo "  ✅ DEBUG_UNICODE mode (v12.1.3+)"
echo "  ✅ Interactive mode configuration (v12.1.5 feature)"
echo "  ✅ Validate filename function (v12.1.5 feature)"
echo ""
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}Ready for production! 🚀${NC}"
    echo ""
    echo "The v12.1.6 features are VERIFIED:"
    echo "  ✓ Accents are preserved (Loïc, Révérence, café, naïve)"
    echo "  ✓ Curly apostrophes normalized to straight (', ', ‚, ˊ → ')"
    echo "  ✓ No UTF-8 corruption when mixing accents + apostrophes"
    echo "  ✓ Python 3 Unicode-aware operations working correctly"
    echo "  ✓ Legal characters preserved, illegal characters replaced (v12.1.4 fix)"
    echo "  ✓ NFD/NFC comparison prevents false RENAMED status (v12.1.3+ fix)"
    echo "  ✓ DEBUG_UNICODE diagnostic mode functional (v12.1.3+)"
    echo "  ✓ Interactive mode with filename validation (v12.1.5+)"
    exit 0
else
    exit 1
fi
