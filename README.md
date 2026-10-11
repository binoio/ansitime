# ANSI QuickLook

Native macOS Finder Quick Look plugin and standalone viewer for ANSI art (`.ans`, `.asc`, `.diz`).

Renders BBS and ANSI graphics with authentic character-cell fidelity using the embedded [fTelnet](https://www.ftelnet.ca) engine and IBM Code Page 437 bitmap fonts, completely eliminating the need to spin up a local Python HTTP server or browser.

Presented on [bino.io](https://bino.io) • Source code on [GitHub](https://github.com/binoio/ansi-quicklook)

---

## Features

- **Finder Quick Look Preview**: Highlight any `.ans`, `.asc`, or `.diz` file in macOS Finder and tap **Spacebar** to immediately preview BBS art.
- **Authentic BBS Rendering**: Accurate VGA 16-color palette and IBM PC Code Page 437 glyphs powered by fTelnet.
- **In-Memory Zero-Latency Engine**: Embeds JS and font bitmaps directly in-memory, completely solving browser canvas tainting (`file://` CORS issues) without running local web servers or opening network ports.
- **SAUCE v00.5 Auto-Detection**:
  - Automatically parses title, author, group, date, and dimensions.
  - Automatically sizes screen rows (e.g. 25-row vs 50-row vs custom height) so tall art never truncates.
  - Strips EOF (`0x1A`) and SAUCE metadata cleanly before feeding character stream.
- **Standalone Companion App**:
  - Drag-and-drop or open any ANSI file.
  - Toggle between 25-row, 50-row, or auto height.
  - Switch between classic IBM 9x16 (with authentic box-drawing character duplication) and 8x16 font rendering.
  - Slide-out SAUCE metadata inspector.
  - Export rendered art directly to high-resolution PNG or plain text.
- **Automatic Updates**: Integrated [Sparkle](https://sparkle-project.org/) framework updater.

---

## Quick Start

### Build & Run Locally

```zsh
./scripts/run.zsh
```

This builds the host app, embeds the Quick Look extension, installs it to `~/Applications`, registers the extension with macOS LaunchServices and `pluginkit`, refreshes `quicklookd`, and launches the app.

---

## Finder Spacebar Preview

1. Select any `.ans` or `.asc` file in Finder.
2. Press the **Spacebar**.
3. Quick Look will display the authentic fTelnet BBS render in Finder.

*Note:* If Quick Look extensions are restricted on your Mac, enable it in:
**System Settings → Privacy & Security → Extensions → Quick Look → ANSI QuickLook**.

You can also force macOS to refresh its Quick Look cache:
```zsh
qlmanage -r && qlmanage -r cache
```

---

## Development & Automation Scripts

ANSI QuickLook includes macOS `zsh` scripts for development, testing, and distribution:

| Script | Purpose |
|---|---|
| `scripts/build.zsh` | Generates Xcode project via `xcodegen` and compiles release binaries into `build/ANSI QuickLook.app`. |
| `scripts/run.zsh` | Builds, registers with LaunchServices and `pluginkit`, and launches the app. |
| `scripts/test.zsh` | Runs native unit and integration tests (or containerized tests via `--docker`). |
| `scripts/notarize.zsh` | Deep-signs with Developer ID, packages release archive, submits to Apple Notary Service, and staples ticket. |

---

## Automated & Containerized Testing

The core parser and rendering engine (`AnsiCore`) is decoupled from AppKit, allowing tests to run natively on macOS or in Linux containers for CI without consuming macOS GitHub Actions runners:

```zsh
# Run locally on macOS
./scripts/test.zsh

# Run inside a Linux container (Docker)
./scripts/test.zsh --docker
# Or via docker compose directly:
docker compose run --rm test
```

### Xcode Cloud CI/CD

Xcode Cloud workflow support is scaffolded in `ci_scripts/ci_post_clone.sh` to install `xcodegen` and generate the project during automated builds.
