# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✓         |

VirtualDisplayKit supports **macOS 13 and later** on Apple Silicon and
Intel Macs.

## Reporting a vulnerability

If you discover a security issue, please report it privately rather than
opening a public issue.

- **Email:** dustin.nielson@gmail.com
- **Subject line:** `[VirtualDisplayKit security] <short description>`

Please include:
- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Your name and contact for follow-up (or indicate anonymity preference)

You can expect an initial acknowledgment within 5 business days.

## Private API disclosure

VirtualDisplayKit relies on Apple's private `CGVirtualDisplay` API, declared
in `CGVirtualDisplayPrivate.h`. This has significant implications:

- **Not officially supported by Apple** — behavior may change between macOS
  versions without notice.
- **App Store incompatibility** — applications using private APIs are at
  risk of App Store review rejection. Do not use this library in App Store
  submissions unless you have independently validated the risk.
- **Direct distribution only** — intended use cases are internal tools,
  development utilities, digital signage systems, and direct-distribution
  (non-MAS) applications.
- **Private API changes are not treated as security issues** in this
  project. They are handled as compatibility issues via regular release
  channels.

## Scope

Security issues in scope:
- Vulnerabilities in VirtualDisplayKit's own code (e.g., memory safety,
  incorrect sandbox assumptions)
- Dependency vulnerabilities (the package has no external Swift package
  dependencies; this is limited to system framework usage)

Out of scope:
- Issues in the underlying Apple private APIs
- Issues in DeskPad or other upstream projects (report those upstream)
- General concerns about private API usage (see disclosure above)
