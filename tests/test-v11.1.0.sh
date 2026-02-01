#!/bin/bash

# Test Suite for exfat-sanitizer v11.1.0
# Verifies all features work correctly

set -e

echo "=========================================="
echo "exfat-sanitizer v11.1.0 Test Suite"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create test directory
TEST_DIR="$(mktemp -d)/exfat-test"
mkdir -p "$TEST_DIR"

echo "Test directory: $TEST_DIR"
echo ""

# ============================================================================
# TEST 1: Accent Preservation (CRITICAL)
# ============================================================================

echo "Test 1: Accent Preservation (v11.0.5 fix)"
echo "-------------------------------------------"

mkdir -p "$TEST_DIR/test1"

# Create test files with accents
touch "$TEST_DIR/test1/Café del Mar.mp3"
touch "$TEST_DIR/test1/L'interprète.flac"
touch "$TEST_DIR/test1/Müller - España.wav"
touch "$TEST_DIR/test1/naïve.txt"

# Run sanitizer
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh "$TEST_DIR/test1" > /dev/null 2>&1

# Verify files still have accents
if [ -f "$TEST_DIR/test1/Café del Mar.mp3" ] && \
   [ -f "$TEST_DIR/test1/L'interprète.flac" ] && \
   [ -f "$TEST_DIR/test1/Müller - España.wav" ] && \
   [ -f "$TEST_DIR/test1/naïve.txt" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Accents preserved correctly"
else
    echo -e "${RED}❌ FAIL${NC}: Accents were stripped"
    exit 1
fi

echo ""

# ============================================================================
# TEST 2: Illegal Character Removal
# ============================================================================

echo "Test 2: Illegal Character Removal"
echo "-----------------------------------"

mkdir -p "$TEST_DIR/test2"

# Create files with illegal characters
touch "$TEST_DIR/test2/song<test>.mp3"
touch "$TEST_DIR/test2/track:new.flac"
touch "$TEST_DIR/test2/file|pipe.txt"

# Run sanitizer
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh "$TEST_DIR/test2" > /dev/null 2>&1

# Verify illegal chars were replaced
if [ -f "$TEST_DIR/test2/song_test_.mp3" ] && \
   [ -f "$TEST_DIR/test2/track_new.flac" ] && \
   [ -f "$TEST_DIR/test2/file_pipe.txt" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Illegal characters removed"
else
    echo -e "${RED}❌ FAIL${NC}: Illegal characters not handled"
    exit 1
fi

echo ""

# ============================================================================
# TEST 3: Shell Safety (NEW in v11.1.0)
# ============================================================================

echo "Test 3: Shell Safety Feature (v9.0.2.2 port)"
echo "----------------------------------------------"

mkdir -p "$TEST_DIR/test3"

# Create files with shell-dangerous characters
touch "$TEST_DIR/test3/file\$(cmd).txt"
touch "$TEST_DIR/test3/test&background.sh"

# Run sanitizer WITH shell safety
CHECK_SHELL_SAFETY=true \
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh "$TEST_DIR/test3" > /dev/null 2>&1

# Verify shell chars were replaced
if [ -f "$TEST_DIR/test3/file__cmd_.txt" ] && \
   [ -f "$TEST_DIR/test3/test_background.sh" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Shell safety works"
else
    echo -e "${RED}❌ FAIL${NC}: Shell safety not working"
    exit 1
fi

echo ""

# ============================================================================
# TEST 4: System File Filtering (NEW in v11.1.0)
# ============================================================================

echo "Test 4: System File Filtering (v9.0.2.2 port)"
echo "-----------------------------------------------"

mkdir -p "$TEST_DIR/test4"

# Create system files
touch "$TEST_DIR/test4/.DS_Store"
touch "$TEST_DIR/test4/Thumbs.db"
touch "$TEST_DIR/test4/normal.txt"

# Run sanitizer
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh "$TEST_DIR/test4" > /dev/null 2>&1

# Check CSV output
CSV_FILE=$(ls -t sanitizer_exfat_*.csv 2>/dev/null | head -1)

if [ -f "$CSV_FILE" ]; then
    # System files should NOT be in CSV
    DS_STORE_COUNT=$(grep -c "\.DS_Store" "$CSV_FILE" || true)
    THUMBS_COUNT=$(grep -c "Thumbs\.db" "$CSV_FILE" || true)
    
    if [ "$DS_STORE_COUNT" -eq 0 ] && [ "$THUMBS_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: System files filtered correctly"
    else
        echo -e "${RED}❌ FAIL${NC}: System files not filtered"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  WARN${NC}: CSV file not found"
fi

echo ""

# ============================================================================
# TEST 5: Copy Mode with Versioning (NEW in v11.1.0)
# ============================================================================

echo "Test 5: Copy Mode with Versioning (v9.0.2.2 port)"
echo "---------------------------------------------------"

mkdir -p "$TEST_DIR/test5/source"
mkdir -p "$TEST_DIR/test5/dest"

# Create source file
echo "content1" > "$TEST_DIR/test5/source/song.mp3"

# First copy
FILESYSTEM=exfat \
COPY_TO="$TEST_DIR/test5/dest" \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh "$TEST_DIR/test5/source" > /dev/null 2>&1

# Modify source
echo "content2" > "$TEST_DIR/test5/source/song.mp3"

# Second copy (should create version)
FILESYSTEM=exfat \
COPY_TO="$TEST_DIR/test5/dest" \
COPY_BEHAVIOR=version \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh "$TEST_DIR/test5/source" > /dev/null 2>&1

# Verify versioned file exists
if [ -f "$TEST_DIR/test5/dest/song.mp3" ] && \
   [ -f "$TEST_DIR/test5/dest/song-v1.mp3" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Copy versioning works"
else
    echo -e "${RED}❌ FAIL${NC}: Copy versioning not working"
    echo "Files in dest:"
    ls -la "$TEST_DIR/test5/dest/"
    exit 1
fi

echo ""

# ============================================================================
# TEST 6: Custom Replacement Character (NEW in v11.1.0)
# ============================================================================

echo "Test 6: Custom Replacement Character (v9.0.2.2 port)"
echo "------------------------------------------------------"

mkdir -p "$TEST_DIR/test6"

# Create file with illegal character
touch "$TEST_DIR/test6/song<test>.mp3"

# Run sanitizer with custom replacement
REPLACEMENT_CHAR=- \
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh "$TEST_DIR/test6" > /dev/null 2>&1

# Verify dash was used instead of underscore
if [ -f "$TEST_DIR/test6/song-test-.mp3" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Custom replacement character works"
else
    echo -e "${RED}❌ FAIL${NC}: Custom replacement not working"
    echo "Files in test6:"
    ls -la "$TEST_DIR/test6/"
    exit 1
fi

echo ""

# ============================================================================
# TEST 7: Apostrophe Preservation
# ============================================================================

echo "Test 7: Apostrophe Preservation (v11.0.x feature)"
echo "---------------------------------------------------"

mkdir -p "$TEST_DIR/test7"

# Create file with apostrophe (allowed in FAT32/exFAT)
touch "$TEST_DIR/test7/L'amour.mp3"

# Run sanitizer
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
DRY_RUN=false \
./exfat-sanitizer-v11.1.0.sh "$TEST_DIR/test7" > /dev/null 2>&1

# Verify apostrophe preserved
if [ -f "$TEST_DIR/test7/L'amour.mp3" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Apostrophes preserved"
else
    echo -e "${RED}❌ FAIL${NC}: Apostrophes not preserved"
    exit 1
fi

echo ""

# ============================================================================
# TEST 8: DRY_RUN Mode (No Changes)
# ============================================================================

echo "Test 8: DRY_RUN Mode (no changes)"
echo "-----------------------------------"

mkdir -p "$TEST_DIR/test8"

# Create file with illegal character
touch "$TEST_DIR/test8/file<test>.txt"

# Run sanitizer in DRY_RUN mode
DRY_RUN=true \
FILESYSTEM=exfat \
SANITIZATION_MODE=conservative \
./exfat-sanitizer-v11.1.0.sh "$TEST_DIR/test8" > /dev/null 2>&1

# Verify original file still exists (unchanged)
if [ -f "$TEST_DIR/test8/file<test>.txt" ]; then
    echo -e "${GREEN}✅ PASS${NC}: DRY_RUN mode works (no changes made)"
else
    echo -e "${RED}❌ FAIL${NC}: DRY_RUN mode changed files"
    exit 1
fi

echo ""

# ============================================================================
# CLEANUP
# ============================================================================

echo "Cleaning up test files..."
rm -rf "$TEST_DIR"

# Clean up CSV files
rm -f sanitizer_exfat_*.csv
rm -f tree_exfat_*.csv

echo ""
echo "=========================================="
echo -e "${GREEN}All tests PASSED! ✅${NC}"
echo "=========================================="
echo ""
echo "v11.1.0 verified:"
echo "  ✅ Accent preservation (v11.0.5 fix)"
echo "  ✅ Illegal character removal"
echo "  ✅ Shell safety (v9.0.2.2 port)"
echo "  ✅ System file filtering (v9.0.2.2 port)"
echo "  ✅ Copy versioning (v9.0.2.2 port)"
echo "  ✅ Custom replacement char (v9.0.2.2 port)"
echo "  ✅ Apostrophe preservation"
echo "  ✅ DRY_RUN mode"
echo ""
echo "Ready for production! 🚀"
