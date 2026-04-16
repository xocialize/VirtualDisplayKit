# Contributing to VirtualDisplayKit

Thanks for your interest in contributing! VirtualDisplayKit is a small,
focused Swift Package. Contributions of bug fixes, documentation improvements,
and new features are welcome — with the scope caveats below.

## Project scope

VirtualDisplayKit is intentionally narrow:

- **Platform:** macOS 13+ only (Apple Silicon primarily). No iOS, tvOS,
  watchOS, Linux, or Windows support is planned.
- **Language:** Swift 5.9+ with strict concurrency enabled.
- **Purpose:** Create and manage virtual displays via `CGVirtualDisplay`,
  expose them for preview, recording, and streaming.

Out of scope:
- Non-Apple platforms
- Alternative virtual display mechanisms (e.g., kext-based)
- Generic screen capture of real displays (use `ScreenCaptureKit` directly
  for that)

If you're unsure whether an idea fits, open an issue before writing code.

## Building

```bash
git clone https://github.com/Xocialize/VirtualDisplayKit.git
cd VirtualDisplayKit
swift build
```

The Swift Package itself has no external dependencies. It builds via SPM
directly.

The demo app lives in `Virtual Display.xcodeproj` — open it in Xcode,
set a development team in Signing & Capabilities, and run.

## Testing

```bash
swift test
```

Tests run on the Swift Package targets. The demo app is manual-verification.

## Code style

- Swift 5.9, strict concurrency (`-enable-upcoming-feature StrictConcurrency`)
- Follow [Apple's Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Prefer `async/await` and actors over completion handlers for new code
- Public APIs should have DocC-compatible doc comments

## Pull requests

1. Fork the repo and create a topic branch off `main`
2. Make your change in small, focused commits
3. Ensure `swift build` and `swift test` pass
4. Update `CHANGELOG.md` under the `[Unreleased]` heading
5. Open a PR with:
   - A clear description of what changed and why
   - Any testing you did manually (especially for display/recording changes
     that are hard to unit-test)

## Reporting bugs

Use the issue tracker. Please include:
- macOS version and hardware (Apple Silicon / Intel)
- Xcode version
- Minimal reproduction steps
- Any relevant Console logs

## Attribution

If you contribute code derived from another MIT-licensed project, please
update `ATTRIBUTION.md` to credit the source.
