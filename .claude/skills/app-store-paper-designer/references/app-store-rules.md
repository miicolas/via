# App Store Screenshot Rules

Reference date: 2026-08-20

This file provides a safe fallback. If internet access is available at export time, verify the latest official Apple requirements before final delivery.

## Screenshot count

Apple currently accepts:
- 1 to 10 screenshots per device family.

## Accepted formats

Apple currently accepts:
- `.jpeg`
- `.jpg`
- `.png`

Final screenshots must not contain alpha channels or transparency.

## iPhone 6.9-inch accepted portrait sizes

At the reference date, Apple lists these accepted portrait sizes for 6.9-inch iPhone screenshots:

- 1260 × 2736
- 1290 × 2796
- 1320 × 2868

The skill defaults to:
- **1290 × 2796**

unless the user requests another accepted target.

## Other iPhone sizes

Apple supports additional sizes for other display classes.

Do not guess them from memory if the user requests a specific current device class. Verify against Apple's current screenshot specifications.

## Source of truth

Official Apple documentation:

https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Export discipline

Before export:
- every screenshot in one set should use the same target dimensions,
- use RGB output,
- remove transparency,
- avoid unintended metadata or alpha,
- inspect the actual exported files, not only the Paper canvas.
