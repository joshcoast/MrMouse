# Mouse Jiggler

A modern macOS menu-bar app that periodically nudges your mouse cursor to keep
the computer awake — a clean Swift/SwiftUI rewrite of the classic
[Jiggler](https://www.sticksoftware.com/software/Jiggler.html) utility.

---

## Features

| Feature | Details |
|---------|---------|
| **Menu-bar only** | No Dock icon; completely out of the way |
| **Live status** | Icon pulses while active; static when idle |
| **Configurable interval** | 15 s · 30 s · 1 min · 2 min · 5 min · 10 min |
| **Dual sleep prevention** | Moves the cursor **and** holds an `IOPMAssertion` (no display sleep) |
| **Persisted preference** | Last-used interval survives restarts via `UserDefaults` |
| **Zero permissions needed** | Uses `CGWarpMouseCursorPosition` — no Accessibility access required |

---

## Requirements

| Tool | Version |
|------|---------|
| macOS | 13 Ventura or later |
| Xcode | 15 or later |
| Swift | 5.9 or later |

---

## Build

### Option A — Xcode GUI

1. Open `MouseJiggler.xcodeproj` in Xcode.
2. Select the **MouseJiggler** scheme and your Mac as destination.
3. Press **⌘R** to build and run, or **⌘B** to build only.

### Option B — Xcode CLI

```bash
xcodebuild -project MouseJiggler.xcodeproj \
           -scheme MouseJiggler \
           -configuration Release \
           -derivedDataPath build
```

The finished `.app` lands in `build/Build/Products/Release/MouseJiggler.app`.

---

## Icon

The source artwork is `icon.svg` — a computer mouse with vibrating arcs on a
deep-violet gradient background.

Generate all required PNG sizes (needs `librsvg` or Inkscape):

```bash
brew install librsvg   # one-time setup
chmod +x generate_icons.sh
./generate_icons.sh
```

The script writes the PNGs into
`MouseJiggler/Assets.xcassets/AppIcon.appiconset/` and Xcode picks them up
automatically on the next build.

---

## How it works

```
Timer fires every N seconds
  └─ CGEvent(source:nil).location   — read current cursor position
  └─ CGWarpMouseCursorPosition()    — nudge ±1 px (alternating direction)
  └─ 50 ms later: warp back to origin
  └─ CGAssociateMouseAndMouseCursorPosition(1)  — re-lock hardware input
```

Alongside cursor movement the app holds an
`IOPMAssertionTypeNoDisplaySleep` power assertion, giving belt-and-suspenders
protection against the screen saver and display sleep.

---

## Project layout

```
MouseJiggler/
├── MouseJiggler.xcodeproj/
│   └── project.pbxproj
├── MouseJiggler/
│   ├── MouseJigglerApp.swift   — @main SwiftUI App + MenuBarExtra
│   ├── JigglerManager.swift    — ObservableObject: timer, cursor warp, IOPM
│   ├── MenuView.swift          — SwiftUI menu content
│   ├── Info.plist              — LSUIElement = YES (no Dock icon)
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/
├── icon.svg                    — Source artwork (1024×1024)
├── generate_icons.sh           — SVG → PNG converter
└── README.md
```

---

## License

MIT — do whatever you like with it.
