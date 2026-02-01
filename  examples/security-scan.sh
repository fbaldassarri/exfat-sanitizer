#!/bin/bash

# security-scan.sh
# Example: Maximum security scan for untrusted downloads
#
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
echo "Running maximum security scan..."
echo "Source: $SOURCE_DIR"
echo ""
echo "Security features enabled:"
echo "  ✅ Shell safety (removes \$, \`, &, ;, etc.)"
echo "  ✅ Unicode exploit detection (zero-width chars)"
echo "  ✅ Strict sanitization mode"
echo ""

FILESYSTEM=$FILESYSTEM \
SANITIZATION_MODE=$SANITIZATION_MODE \
CHECK_SHELL_SAFETY=$CHECK_SHELL_SAFETY \
CHECK_UNICODE_EXPLOITS=$CHECK_UNICODE_EXPLOITS \
DRY_RUN=$DRY_RUN \
./exfat-sanitizer-v11.1.0.sh "$SOURCE_DIR"

echo ""
echo "✅ Security scan complete"
echo ""
echo "Protections applied:"
echo "  ❌ file\$(cmd).txt → file__cmd_.txt (shell injection blocked)"
echo "  ❌ test​​​.pdf → test.pdf (zero-width chars removed)"
echo "  ❌ doc<script>.html → doc_script_.html (illegal chars removed)"
