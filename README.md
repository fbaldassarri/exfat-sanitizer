# exfat-sanitizer

**Cross-Platform Filename Sanitizer for exFAT, FAT32, APFS, NTFS, HFS+, and Universal Compatibility**

[![Version](https://img.shields.io/badge/version-9.0.2.2-blue.svg)](https://github.com/fbaldassarri/exfat-sanitizer/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-brightgreen.svg)](https://www.gnu.org/software/bash/)

A production-ready bash script that sanitizes filenames and directory names to ensure compatibility across multiple filesystems. Ideal for audio libraries, media collections, and cross-platform file management.

## 🚀 Features

### Core Capabilities
- **Multi-Filesystem Support**: exFAT, FAT32, APFS, NTFS, HFS+, Universal
- **Three Sanitization Modes**: Strict, Conservative, Permissive
- **Dry Run Mode**: Preview all changes before applying them
- **Comprehensive Logging**: CSV export with detailed change tracking
- **Tree Export**: Optional directory structure visualization
- **Copy Mode**: Sanitize files to a new destination
- **Collision Detection**: Prevents filename conflicts
- **Path Length Validation**: Ensures compatibility with filesystem limits
- **System File Filtering**: Automatically skips `.DS_Store`, `Thumbs.db`, and other system files

### Safety Features
- **Shell Safety Checks**: Removes dangerous shell metacharacters (`$`, `` ` ``, `&`, `;`, etc.)
- **Unicode Exploit Detection**: Optional removal of zero-width and bidirectional characters
- **Normalization Detection**: Identifies NFC/NFD Unicode differences
- **Reserved Name Handling**: Properly handles Windows/DOS reserved names (CON, PRN, AUX, etc.)
- **Atomic Operations**: Safe renaming with rollback on failure

### Character Coverage
- **Universal Forbidden**: `< > : " / \ | ? * NUL`
- **FAT32-Specific**: `+ , ; = [ ] ÷ ×`
- **Control Characters**: `0x00-0x1F`, `0x7F` (security-critical)
- **Unicode Line Separators**: `U+000A`, `U+000D`, `U+0085`, `U+2028`, `U+2029`
- **Shell Metacharacters**: `$ ` & ; # ~ ^ ! ( )` (optional)
- **Path Length Limits**: 260 chars (FAT32/exFAT), 255 chars (others)

## 📋 Requirements

- **Bash**: Version 4.0 or higher
- **Standard Unix Tools**: `find`, `sed`, `grep`, `awk`, `mv`, `cp`
- **macOS**: Preinstalled
- **Linux**: Usually preinstalled
- **Windows**: WSL, Git Bash, or Cygwin

## 📦 Installation

### Quick Install

```bash
# Download the script
curl -O https://raw.githubusercontent.com/fbaldassarri/exfat-sanitizer/main/exfat-sanitizer-v9.0.2.2.sh

# Make it executable
chmod +x exfat-sanitizer-v9.0.2.2.sh

# Run with dry-run (safe preview)
./exfat-sanitizer-v9.0.2.2.sh /path/to/your/files
```

### Clone Repository

```bash
git clone https://github.com/fbaldassarri/exfat-sanitizer.git
cd exfat-sanitizer
chmod +x exfat-sanitizer-v9.0.2.2.sh
```

## 🎯 Usage

### Basic Syntax

```bash
FILESYSTEM=<filesystem> SANITIZATION_MODE=<mode> DRY_RUN=<true|false> \
  ./exfat-sanitizer-v9.0.2.2.sh <directory>
```

### Common Use Cases

#### 1. **Sanitize Audio Library for exFAT USB Drive**
```bash
# Preview changes first (dry run)
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=true \
  ./exfat-sanitizer-v9.0.2.2.sh /Users/username/Music

# Apply changes after reviewing
FILESYSTEM=exfat SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v9.0.2.2.sh /Users/username/Music
```

#### 2. **Clean FAT32 Drive (Legacy Compatibility)**
```bash
FILESYSTEM=fat32 SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v9.0.2.2.sh /Volumes/USB_DRIVE
```

#### 3. **Optimize for macOS APFS**
```bash
FILESYSTEM=apfs SANITIZATION_MODE=conservative DRY_RUN=false \
  ./exfat-sanitizer-v9.0.2.2.sh ~/Documents
```

#### 4. **Maximum Security (Untrusted Sources)**
```bash
FILESYSTEM=universal SANITIZATION_MODE=strict \
  CHECK_SHELL_SAFETY=true DRY_RUN=false \
  ./exfat-sanitizer-v9.0.2.2.sh ~/Downloads
```

#### 5. **Generate Directory Tree Report**
```bash
FILESYSTEM=exfat GENERATE_TREE=true DRY_RUN=true \
  ./exfat-sanitizer-v9.0.2.2.sh /path/to/directory
```

#### 6. **Copy to New Destination with Sanitization**
```bash
FILESYSTEM=exfat COPY_TO=/Volumes/Backup \
  COPY_BEHAVIOR=version DRY_RUN=false \
  ./exfat-sanitizer-v9.0.2.2.sh /Users/username/Music
```

## ⚙️ Configuration Options

### Filesystem Types
| Filesystem | Description | Use Case |
|------------|-------------|----------|
| `exfat` | exFAT restrictions | Modern USB drives, SD cards |
| `fat32` | FAT32 restrictions | Older USB drives, legacy compatibility |
| `apfs` | APFS restrictions | macOS native (Sonoma+) |
| `ntfs` | NTFS restrictions | Windows compatibility |
| `hfsplus` | HFS+ restrictions | Legacy macOS |
| `universal` | Most restrictive | Unknown destination (default) |

### Sanitization Modes
| Mode | Description | Recommended For |
|------|-------------|-----------------|
| `strict` | Removes all problematic chars including shell-dangerous | Maximum compatibility, security-critical |
| `conservative` | Removes only officially-forbidden chars per filesystem | Balanced approach (recommended) |
| `permissive` | Removes only universal forbidden chars | Speed-optimized, minimal changes |

### Safety Options
| Option | Default | Description |
|--------|---------|-------------|
| `CHECK_SHELL_SAFETY` | `true` | Remove shell metacharacters |
| `CHECK_UNICODE_EXPLOITS` | `false` | Remove zero-width, bidirectional chars |
| `CHECK_NORMALIZATION` | `false` | Detect NFC/NFD differences |

### Copy Mode Options
| Option | Default | Description |
|--------|---------|-------------|
| `COPY_TO` | (empty) | Destination directory for copying |
| `COPY_BEHAVIOR` | `skip` | Conflict resolution: `skip`, `overwrite`, `version` |

### Other Options
| Option | Default | Description |
|--------|---------|-------------|
| `DRY_RUN` | `true` | Preview changes without modifying |
| `REPLACEMENT_CHAR` | `_` | Character for replacing forbidden chars |
| `GENERATE_TREE` | `false` | Export directory tree structure |

## 📊 Output Files

### CSV Log File
Format: `sanitizer_<filesystem>_<timestamp>.csv`

Columns:
- **Type**: File or Directory
- **Old Name**: Original filename
- **New Name**: Sanitized filename
- **Issues**: Detected problems (e.g., `FAT32_Specific`, `Path too long`)
- **Path**: Parent directory path
- **Path Length**: Full path character count
- **Status**: `RENAMED`, `LOGGED`, or `FAILED`
- **Copy_Status**: `COPIED`, `SKIPPED`, `FAILED`, or `N/A`

### Tree CSV File (Optional)
Format: `tree_<filesystem>_<timestamp>.csv`

Columns:
- **Type**: File or Directory
- **Name**: Item name
- **Path**: Relative path from root
- **Depth**: Directory nesting level
- **Has Children**: `Yes` or `No`

### Console Log File
Format: `sanitizer_<filesystem>_<timestamp>.<mode>.log`

Contains:
- Configuration summary
- Progress updates
- Final statistics
- Warnings and errors

## 🛡️ System Files Automatically Skipped

The following system files are **never processed** and **will not appear in CSV output**:

- `.DS_Store` (macOS Finder metadata)
- `.stfolder` (Syncthing)
- `.sync.ffs_db`, `.sync.ffsdb` (FreeFileSync)
- `.Spotlight-V100` (macOS Spotlight)
- `Thumbs.db` (Windows thumbnail cache)
- `.stignore` (Syncthing ignore)
- `.gitignore` (Git ignore)
- `.sync` (Generic sync metadata)

## 🔍 Understanding Path Length Issues

### Filesystem Limits
- **FAT32/exFAT**: 260 characters (Windows-style limit for compatibility)
- **APFS/NTFS/HFS+**: 255 characters (component name limit)
- **Universal Mode**: 260 characters (most restrictive)

### Common Causes of Long Paths
1. **Deep directory nesting** (e.g., Artist > Album > Disc > Track)
2. **Long album or artist names** (especially with featured artists)
3. **Remix/version descriptions** (e.g., "Radio Edit", "Live at...")
4. **Multiple featured artists** (e.g., "feat. Artist1, Artist2, Artist3")

### Solutions
1. **Shorten directory names**: Use abbreviations
2. **Flatten structure**: Reduce nesting levels
3. **Abbreviate descriptions**: "RM2023" instead of "Remastered 2023"
4. **Limit featured artists**: "feat. Various" instead of listing all

## 📈 Performance

### Benchmarks (tested on macOS)
- **3,555 files + 368 directories**: ~15-30 seconds (dry run)
- **CSV generation**: Minimal overhead (<1% performance impact)
- **Tree export**: Additional 5-10 seconds for large directories

### Optimization Tips
- Use `permissive` mode for faster processing when safety isn't critical
- Disable `CHECK_SHELL_SAFETY` if targeting non-shell environments
- Use `DRY_RUN=true` first to identify high-impact areas

## 🐛 Troubleshooting

### Common Issues

**Issue: "Permission denied" errors**
```bash
# Solution: Run with appropriate permissions
sudo ./exfat-sanitizer-v9.0.2.2.sh /path/to/directory
```

**Issue: "Insufficient disk space" in copy mode**
```bash
# Solution: Check available space
df -h /destination/path
```

**Issue: Path too long warnings**
```bash
# Solution: Manually shorten long directory names first
# Or use a different filesystem with longer path support
```

**Issue: Files not renamed in dry run**
```bash
# Solution: This is expected! Dry run only previews changes
# Set DRY_RUN=false to actually apply changes
```

### Debug Mode
```bash
# Enable bash debug output
bash -x ./exfat-sanitizer-v9.0.2.2.sh /path/to/directory 2>&1 | tee debug.log
```

## 🔄 Version History

### v9.0.2.2 (2026-01-09)
- **Bugfix**: System file filtering now properly excludes `.DS_Store`, `Thumbs.db`, etc.
- **Enhancement**: System files no longer appear in CSV output
- **Improvement**: Cleaner console output without system file processing messages

### v9.0.0 (2026-01-07)
- Production-ready implementation
- Multi-filesystem support (exFAT, FAT32, APFS, NTFS, HFS+, Universal)
- Three sanitization modes (strict, conservative, permissive)
- Copy mode with conflict resolution
- Tree export functionality
- Comprehensive safety features

### v8.0.2 (2026-01-05)
- Enhanced CSV logging
- Path length validation
- Collision detection improvements

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow existing code style and structure
- Add comments for complex logic
- Test with multiple filesystem types
- Update README with new features
- Include example usage for new options

## 💡 Tips & Best Practices

### For Audio Libraries
```bash
# Recommended: Conservative mode for music collections
FILESYSTEM=exfat SANITIZATION_MODE=conservative \
  CHECK_SHELL_SAFETY=false DRY_RUN=false \
  ./exfat-sanitizer-v9.0.2.2.sh ~/Music
```

### For Maximum Compatibility
```bash
# Use universal mode when targeting unknown destinations
FILESYSTEM=universal SANITIZATION_MODE=strict \
  DRY_RUN=false ./exfat-sanitizer-v9.0.2.2.sh /path/to/files
```

### For Safe Testing
```bash
# Always run dry run first, then review CSV output
FILESYSTEM=exfat DRY_RUN=true ./exfat-sanitizer-v9.0.2.2.sh ~/Documents
# Review: sanitizer_exfat_YYYYMMDD_HHMMSS.csv
# Apply: DRY_RUN=false ./exfat-sanitizer-v9.0.2.2.sh ~/Documents
```

## 🔗 Resources

- [exFAT Specification](https://docs.microsoft.com/en-us/windows/win32/fileio/exfat-specification)
- [FAT32 Specification](https://en.wikipedia.org/wiki/File_Allocation_Table)
- [APFS Reference](https://developer.apple.com/documentation/foundation/file_system)
- [NTFS Specification](https://docs.microsoft.com/en-us/windows/win32/fileio/filesystem-functionality-comparison)

## ❓ FAQ

**Q: Will this delete my files?**  
A: No. The script only renames files and directories. In dry run mode (default), nothing is modified at all.

**Q: Can I undo changes?**  
A: The CSV log contains both old and new names, allowing manual reversal if needed. Consider copying files first using `COPY_TO` option.

**Q: Does this work on Windows?**  
A: Yes, with WSL (Windows Subsystem for Linux), Git Bash, or Cygwin.

**Q: What's the difference between exfat and universal mode?**  
A: `exfat` applies exFAT-specific rules. `universal` applies the most restrictive rules for maximum compatibility with all filesystems.

**Q: How do I handle 56 path length issues found?**  
A: Review the CSV file, identify files with "Path too long" issues, and manually shorten directory or file names before running the script.

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/fbaldassarri/exfat-sanitizer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/fbaldassarri/exfat-sanitizer/discussions)

## 🌟 Acknowledgments

Developed for cross-platform audio library management and tested extensively with high-resolution audio collections (WAV 32-bit/192kHz).

---

**Made with ❤️ for the audio enthusiast community**
