# exFAT Filename Sanitizer

![Version](https://img.shields.io/badge/version-5.1.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)
![Bash](https://img.shields.io/badge/language-Bash-orange.svg)

A robust, POSIX-compliant bash script to recursively sanitize filenames and folder names for compatibility with exFAT file systems.

Perfect for preparing media libraries for external drives, SD cards, or cross-platform syncing (Syncthing, Dropbox, Nextcloud).

---

## 🚀 Features

*   **🛡 Safe by Default:** Starts in `DRY RUN` mode to preview changes without touching files.
*   **⚡️ Automator Compatible:** Supports standard input (`stdin`) for integration with macOS Automator and Shortcuts.
*   **🔄 Sync-Friendly:** Preserves original file modification timestamps to prevent re-indexing in tools like Syncthing.
*   **📝 Comprehensive Logging:** Generates a detailed CSV log of every detected issue and action taken.
*   **🧹 Deep Cleaning:**
    *   Replaces forbidden characters (`/`, `:`, `*`, `?`, `"`, `<`, `>`, `|`, `\`).
    *   Removes invisible control characters (0x00-0x1F).
    *   Trims leading/trailing spaces and dots.
    *   Fixes specific edge cases (like triple leading dots `...`).
*   **🚫 Smart Skipping:** Ignores system files (`.DS_Store`, `.stfolder`, `.Spotlight-V100`, etc.).

---

## 📦 Installation

1.  **Download the script:**
    ```bash
    mkdir -p ~/.local/bin
    curl -o ~/.local/bin/exfat-sanitizer https://raw.githubusercontent.com/fbaldassarri/exfat-sanitizer/main/exfat-sanitizer.sh
    ```

2.  **Make it executable:**
    ```bash
    chmod +x ~/.local/bin/exfat-sanitizer
    ```

3.  **Add to PATH (Optional):**
    Add `export PATH="$HOME/.local/bin:$PATH"` to your `.zshrc` or `.bashrc` if you haven't already.

---

## 🛠 Usage

The script uses environment variables for configuration. The most important one is `DRY_RUN`.

### 1. Dry Run (Preview Mode)
This is the default behavior. It scans the directory and reports what *would* happen.

```bash
exfat-sanitizer "/path/to/your/library"
# OR explicitly
DRY_RUN=true exfat-sanitizer "/path/to/your/library"
```

### 2. Production Mode (Apply Changes)
Actually renames the files.

```bash
DRY_RUN=false exfat-sanitizer "/path/to/your/library"
```

### 3. Using Standard Input (Pipes)
Useful for scripting or Automator.

```bash
echo "/path/to/your/library" | DRY_RUN=false exfat-sanitizer
```

### 4. Custom Replacement Character
Default replacement is an underscore `_`. You can change this:

```bash
REPLACEMENT_CHAR="-" exfat-sanitizer "/path/to/your/library"
```

---

## 🔍 What It Fixes

| Problem | Example Input | Result |
| :--- | :--- | :--- |
| **Colons** | `Song: Remix.mp3` | `Song_ Remix.mp3` |
| **Question Marks** | `What?.txt` | `What_.txt` |
| **Slashes** | `AC/DC` | `AC_DC` |
| **Quotes** | `"Hello".txt` | `Hello.txt` |
| **Trailing Space** | `Folder ` | `Folder` |
| **Trailing Dot** | `Image.jpg.` | `Image.jpg` |
| **Leading Dot** | `.Hidden` | `Hidden` |
| **Control Chars** | `File^M.txt` | `File.txt` |

---

## 🍏 macOS Automator Integration

You can create a "Quick Action" to clean folders directly from Finder.

1.  Open **Automator.app** and create a new **Quick Action**.
2.  Set "Workflow receives current" to **folders** in **Finder**.
3.  Add a **Run Shell Script** action.
    *   **Shell:** `/bin/bash`
    *   **Pass input:** `as arguments`
4.  Paste the following code:

```bash
# Path to your script
SCRIPT_PATH="$HOME/.local/bin/exfat-sanitizer"

if [ ! -f "$SCRIPT_PATH" ]; then
    osascript -e 'display alert "Error" message "Script not found at ~/.local/bin/exfat-sanitizer"'
    exit 1
fi

# Dialog to choose mode
CHOICE=$(osascript -e 'display dialog "Sanitize filenames for exFAT?" buttons {"Cancel", "Dry Run", "Apply Changes"} default button "Dry Run"' 2>&1)

if [[ $CHOICE == *"Apply Changes"* ]]; then
    export DRY_RUN=false
    MODE="Production"
elif [[ $CHOICE == *"Dry Run"* ]]; then
    export DRY_RUN=true
    MODE="Dry Run"
else
    exit 0
fi

# Run the script
"$SCRIPT_PATH" "$1" > /tmp/exfat_log.txt 2>&1

# Notify user
osascript -e "display notification \"$MODE complete. Check terminal or CSV for details.\" with title \"exFAT Sanitizer\""
```
5.  Save as **"Sanitize for exFAT"**.
6.  **Right-click** any folder in Finder > **Quick Actions** > **Sanitize for exFAT**.

---

## 🔄 Syncthing Integration

If you sync files between macOS/Linux and Android/Windows, filename conflicts are common.

This script includes a critical feature for Syncthing users: **Timestamp Preservation**.

When a file is renamed, the script touches the new filename with the *original* modification time. This prevents Syncthing from treating it as a "new" file, saving bandwidth and preventing re-indexing loops.

**Recommended Setup:**
Run this script via `cron` or `launchd` on your "Master" folder periodically to ensure all incoming files remain compliant.

---

## 📊 Logging

Every run generates a CSV file in the current directory: `exfat_sanitizer_YYYYMMDD_HHMMSS.csv`.

**Format:**
```csv
Old Name,New Name,Issues,Path,Status
"Song:Title.mp3","Song_Title.mp3",Colon(:),"/Music/Artist",RENAMED
"Bad<Name>.txt","Bad_Name_.txt","Less Than(<);Greater Than(>)","/Docs",FAILED
```

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## 📄 License

[MIT](LICENSE)
