# Changelog

## v1.1.0 (2026-05-19)

### New feature
- **Edit Mode Position Helper** — companion panel that appears when you open Blizzard's Edit Mode (`/editmode` or `/4kuhd edit`). At low UI scale, Edit Mode's snap zones drift and centering frames becomes painful. The helper sidesteps snap entirely by giving you direct pixel control on whichever system you've selected.
    - Type exact X and Y offsets, press Enter to apply
    - Nudge buttons: ±1 and ±10 pixels on each axis
    - Center H / Center V to zero one axis
    - Auto-shows when Edit Mode opens, auto-hides when it closes
    - Draggable, panel position remembered across the session

### Improvements
- New slash command `/4kuhd edit` opens Edit Mode and the Position Helper together
- Interface bumped to declare compatibility with WoW 12.0.5 and 12.0.7

## v1.0.0 (2026-03-30)

Initial release.

- Per-resolution UI scale profiles with auto-apply on login
- Smart display detection: MacBook Air/Pro, 4K monitors (24"-40"), ultrawide, 1440p
- Monitor profiles dropdown with recommended scales
- Quick presets: Compact, Small, Medium, Large, Default
- Taint-safe scaling via UIParent:SetScale() with deferred execution
- Combat-safe: defers changes until combat ends
- Resolution change detection with automatic profile switching
- Custom minimap button (draggable, with tooltip info)
- Addon Compartment (main menu) integration
- Slash commands: /4kuhd, /4kscale
- Premium UI with custom toggle switches, cyan accent theme, visual scale bar
