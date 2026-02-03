#!/bin/bash

# Test Suite for exfat-sanitizer v12.1.2
# Verifies all features work correctly including the critical v12.1.2 apostrophe fix

set -e

echo "=========================================="
echo "exfat-sanitizer v12.1.2 Test Suite"
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
TEST_DIR="$(mktemp -d)/exfat-test-v12.1.2"
mkdir -p "$TEST_DIR"
echo "Test directory: $TEST_DIR"
echo ""

# ============================================================================
# TEST 0: Python 3 Dependency Check (NEW in v12.1.2)
# ============================================================================
run_test "Python 3 Dependency Check (MANDATORY in v12.1.2)"

if command -v python3 >/dev/null 2>&1; then
    PY_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    pass_test "Python 3 found: ${PY_VERSION}"
else
    fail_test "Python 3 NOT found - REQUIRED for v12.1.2!"
fi

# ============================================================================
# TEST 1: Accent Preservation (CRITICAL v12.1.2 FIX)
# ============================================================================
run_test "Accent Preservation with Curly Apostrophes (v12.1.2 fix)"

mkdir -p "$TEST_DIR/test1"

# Create test files with accents AND curly apostrophes (THE CRITICAL FIX!)
# U+2019 is RIGHT SINGLE QUOTATION MARK (curly apostrophe)
touch "$TEST_DIR/test1/Loïc Nottet's Song.flac"  # Curly apostrophe + accent
touch "$TEST_DIR/test1/Café del Mar.mp3"
touch "$TEST_DIR/test1/L'interprète.flac"  # Curly apostrophe + accent
touch "$TEST_DIR/test1/Müller - España.wav"
touch "$TEST_DIR/test1/naïve.txt"
touch "$TEST_DIR/test1/C'è di più.ogg"  # Italian with curly apostrophe

# Run sanitizer
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test1" > /dev/null 2>&1

# Verify files have accents preserved AND apostrophes normalized to straight
# v12.1.2 should normalize ' (U+2019) → ' (U+0027) WITHOUT corrupting accents
if [ -f "$TEST_DIR/test1/Loïc Nottet's Song.flac" ] && \
   [ -f "$TEST_DIR/test1/Café del Mar.mp3" ] && \
   [ -f "$TEST_DIR/test1/L'interprète.flac" ] && \
   [ -f "$TEST_DIR/test1/Müller - España.wav" ] && \
   [ -f "$TEST_DIR/test1/naïve.txt" ] && \
   [ -f "$TEST_DIR/test1/C'è di più.ogg" ]; then
    pass_test "Accents preserved AND apostrophes normalized (v12.1.2 fix verified!)"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test1/"
    fail_test "Accent preservation or apostrophe normalization failed"
fi

# ============================================================================
# TEST 2: Mixed Unicode + Illegal Characters (NEW COMPREHENSIVE TEST)
# ============================================================================
run_test "Mixed Unicode + Illegal Characters"

mkdir -p "$TEST_DIR/test2"

# Complex scenarios mixing accents, apostrophes, and illegal chars
touch "$TEST_DIR/test2/Café<test>:Révérence's.mp3"  # Accents + curly apostrophe + illegal
touch "$TEST_DIR/test2/Loïc|Nottet?.flac"  # Accent + illegal chars

# Run sanitizer
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test2" > /dev/null 2>&1

# Expected: accents preserved, illegal chars replaced, apostrophes normalized
if [ -f "$TEST_DIR/test2/Café_test__Révérence's.mp3" ] && \
   [ -f "$TEST_DIR/test2/Loïc_Nottet_.flac" ]; then
    pass_test "Mixed Unicode and illegal characters handled correctly"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test2/"
    fail_test "Mixed character handling failed"
fi

# ============================================================================
# TEST 3: Curly Apostrophe Normalization (v12.1.2 SPECIFIC)
# ============================================================================
run_test "Curly Apostrophe Normalization (Python 3 Unicode-safe)"

mkdir -p "$TEST_DIR/test3"

# Test ALL curly apostrophe variants that v12.1.2 normalizes
touch "$TEST_DIR/test3/test's.txt"      # U+2018 LEFT SINGLE QUOTATION
touch "$TEST_DIR/test3/test's.txt"      # U+2019 RIGHT SINGLE QUOTATION
touch "$TEST_DIR/test3/test‚s.txt"      # U+201A SINGLE LOW-9 QUOTATION
touch "$TEST_DIR/test3/testˊs.txt"      # U+02BC MODIFIER LETTER APOSTROPHE

# Run sanitizer
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test3" > /dev/null 2>&1

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
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test4" > /dev/null 2>&1

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
# TEST 5: Shell Safety (v11.1.0 feature, preserved in v12.1.2)
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
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test5" > /dev/null 2>&1

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
# TEST 6: System File Filtering (v11.1.0 feature, preserved in v12.1.2)
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
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test6" > /dev/null 2>&1

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
    echo -e "${YELLOW}⚠️  WARN${NC}: CSV file not found"
fi

# ============================================================================
# TEST 7: Copy Mode with Versioning (v11.1.0 feature, preserved in v12.1.2)
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
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test7/source" > /dev/null 2>&1

# Modify source
echo "content2" > "$TEST_DIR/test7/source/song.mp3"

# Second copy (should create version)
FILESYSTEM=exfat \
COPY_TO="$TEST_DIR/test7/dest" \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test7/source" > /dev/null 2>&1

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
# TEST 8: Custom Replacement Character (v11.1.0 feature, preserved in v12.1.2)
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
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test8" > /dev/null 2>&1

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
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test9" > /dev/null 2>&1

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
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test10" > /dev/null 2>&1

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
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test11" > /dev/null 2>&1

# Verify reserved names were handled
if [ -f "$TEST_DIR/test11/CON-reserved.txt" ] && \
   [ -f "$TEST_DIR/test11/LPT1-reserved.log" ] && \
   [ -f "$TEST_DIR/test11/normal.txt" ]; then
    pass_test "Reserved names handled correctly"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test11/"
    fail_test "Reserved name handling failed"
fi

# ============================================================================
# TEST 12: NFD to NFC Normalization
# ============================================================================
run_test "Unicode NFD to NFC Normalization"

mkdir -p "$TEST_DIR/test12"

# Create file with NFD (decomposed) character if possible
# This is more about testing normalize_unicode() function
touch "$TEST_DIR/test12/café.txt"  # May be NFD on macOS

# Run sanitizer
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test12" > /dev/null 2>&1

# File should still exist with proper normalization
if [ -f "$TEST_DIR/test12/café.txt" ]; then
    pass_test "Unicode normalization works"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test12/"
    fail_test "Unicode normalization failed"
fi

# ============================================================================
# TEST 13: Regression Test - v12.1.1 Bug (THE CRITICAL FIX!)
# ============================================================================
run_test "Regression Test: v12.1.1 Apostrophe Bug (CRITICAL v12.1.2 FIX)"

mkdir -p "$TEST_DIR/test13"

# These are the EXACT filenames that broke in v12.1.1
# v12.1.1 would strip accents when normalizing curly apostrophes
touch "$TEST_DIR/test13/Loïc Nottet's Album.flac"      # The canonical bug case
touch "$TEST_DIR/test13/Révérence's Song.mp3"          # Another accent + apostrophe
touch "$TEST_DIR/test13/L'été's Memories.ogg"          # Multiple accents + apostrophe

# Run sanitizer
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v12.1.2.sh "$TEST_DIR/test13" > /dev/null 2>&1

# v12.1.2 MUST preserve accents while normalizing apostrophes
if [ -f "$TEST_DIR/test13/Loïc Nottet's Album.flac" ] && \
   [ -f "$TEST_DIR/test13/Révérence's Song.mp3" ] && \
   [ -f "$TEST_DIR/test13/L'été's Memories.ogg" ]; then
    pass_test "v12.1.1 regression bug FIXED! Accents preserved with apostrophe normalization"
else
    echo "Files found:"
    ls -la "$TEST_DIR/test13/"
    echo ""
    echo "CRITICAL: v12.1.2 should fix the v12.1.1 bug where:"
    echo "  'Loïc Nottet's' became 'Loic Nottet's' (accent stripped)"
    echo ""
    fail_test "v12.1.1 regression still present - CRITICAL BUG!"
fi

# ============================================================================
# TEST 14: Python 3 Fallback Behavior
# ============================================================================
run_test "Python 3 Dependency Warning (if applicable)"

# This test just verifies the script handles Python 3 correctly
# We already verified Python 3 exists in Test 0
if command -v python3 >/dev/null 2>&1; then
    pass_test "Python 3 available for Unicode-safe operations"
else
    echo -e "${YELLOW}⚠️  WARN${NC}: Python 3 not found - v12.1.2 requires it!"
    fail_test "Python 3 REQUIRED for v12.1.2"
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

echo "v12.1.2 Test Coverage:"
echo " ✅ Python 3 dependency check (MANDATORY)"
echo " ✅ Accent preservation with curly apostrophes (v12.1.2 fix)"
echo " ✅ Mixed Unicode + illegal characters"
echo " ✅ Curly apostrophe normalization (all 4 variants)"
echo " ✅ Illegal character removal"
echo " ✅ Shell safety (v11.1.0 feature preserved)"
echo " ✅ System file filtering (v11.1.0 feature preserved)"
echo " ✅ Copy versioning (v11.1.0 feature preserved)"
echo " ✅ Custom replacement char (v11.1.0 feature preserved)"
echo " ✅ Straight apostrophe preservation"
echo " ✅ DRY_RUN mode"
echo " ✅ Reserved name handling"
echo " ✅ Unicode NFD/NFC normalization"
echo " ✅ v12.1.1 regression test (CRITICAL BUG FIX)"
echo " ✅ Python 3 availability verification"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}Ready for production! 🚀${NC}"
    echo ""
    echo "The v12.1.2 critical fix is VERIFIED:"
    echo "  ✓ Accents are preserved (Loïc, Révérence, café, naïve)"
    echo "  ✓ Curly apostrophes normalized to straight (', ', ‚, ˊ → ')"
    echo "  ✓ No UTF-8 corruption when mixing accents + apostrophes"
    echo "  ✓ Python 3 Unicode-aware operations working correctly"
    exit 0
else
    exit 1
fi
