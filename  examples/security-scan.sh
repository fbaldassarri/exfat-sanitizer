#!/bin/bash

# security-scan.sh
# Example: Maximum security scan for untrusted downloads

# Use case: Sanitizing files from internet, email attachments, unknown sources
# Features: Removes shell-dangerous characters, zero-width Unicode exploits
# Security: Maximum protection against command injection and filename exploits

# Configuration
FILESYSTEM=universal
SANITIZATION_MODE=strict
CHECK_SHELL_SAFETY=true
CHECK_UNICODE_EXPLOITS=true
DRY_RUN=false

# Source directory (change this to your downloads directory)
SOURCE_DIR="$HOME/Downloads"

# Run sanitizer with maximum security
echo "Running maximum security scan (v12.1.2)..."
echo "Source: $SOURCE_DIR"
echo ""
echo "Security features enabled:"
echo " ✅ Shell safety (removes \$, \`, &, ;, etc.)"
echo " ✅ Unicode exploit detection (zero-width chars)"
echo " ✅ Strict sanitization mode"
echo " ✅ Python 3 Unicode-safe operations (v12.1.2)"
echo ""

FILESYSTEM=$FILESYSTEM \
SANITIZATION_MODE=$SANITIZATION_MODE \
CHECK_SHELL_SAFETY=$CHECK_SHELL_SAFETY \
CHECK_UNICODE_EXPLOITS=$CHECK_UNICODE_EXPLOITS \
DRY_RUN=$DRY_RUN \
./exfat-sanitizer-v12.1.2.sh "$SOURCE_DIR"

echo ""
echo "✅ Security scan complete"
echo ""
echo "Protections applied:"
echo " ❌ file\$(cmd).txt → file__cmd_.txt (shell injection blocked)"
echo " ❌ test​​​.pdf → test.pdf (zero-width chars removed)"
echo " ❌ doc<new>.txt → doc_new_.txt (illegal chars removed)"
echo ""
echo "v12.1.2 improvements:"
echo " ✅ Accents preserved even with apostrophes"
echo " ✅ No UTF-8 corruption during sanitization"
echo " ✅ Python 3 Unicode-aware normalization"
