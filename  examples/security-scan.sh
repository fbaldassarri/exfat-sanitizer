#!/bin/bash

# Security Scan using exfat-sanitizer v12.1.4
# Maximum security for untrusted files (downloads, email attachments, etc.)

# Configuration
FILESYSTEM=universal
SANITIZATION_MODE=strict
CHECK_SHELL_SAFETY=true
CHECK_UNICODE_EXPLOITS=true
DRY_RUN=false

# Source directory (change this to your downloads directory)
SOURCE_DIR="$HOME/Downloads"

echo "Running maximum security scan (v12.1.4)..."
echo "Source: $SOURCE_DIR"
echo ""
echo "Security features enabled:"
echo "  🔒 Shell safety (removes $, \`, &, ;, etc.)"
echo "  🔒 Unicode exploit detection (zero-width chars)"
echo "  🔒 Strict sanitization mode"
echo "  🔒 Python 3 Unicode-safe operations (v12.1.4)"
echo "  🔒 Correct character classification (v12.1.4 fix)"
echo ""

FILESYSTEM=$FILESYSTEM \
  SANITIZATION_MODE=$SANITIZATION_MODE \
  CHECK_SHELL_SAFETY=$CHECK_SHELL_SAFETY \
  CHECK_UNICODE_EXPLOITS=$CHECK_UNICODE_EXPLOITS \
  DRY_RUN=$DRY_RUN \
  ./exfat-sanitizer-v12.1.4.sh "$SOURCE_DIR"

echo ""
echo "Security scan complete"
echo ""
echo "Protections applied:"
echo "  file\$(cmd).txt → file__cmd_.txt  (shell injection blocked)"
echo "  test‌.pdf → test.pdf  (zero-width chars removed)"
echo "  doc:new.txt → doc_new.txt  (illegal chars removed)"
echo ""
echo "v12.1.4 improvements:"
echo "  ✅ Accents preserved even with apostrophes"
echo "  ✅ No UTF-8 corruption during sanitization"
echo "  ✅ Python 3 Unicode-aware normalization"
echo "  ✅ Fixed inverted if/else logic in character classification"
echo "  ✅ NFD→NFC normalization prevents false renames"
