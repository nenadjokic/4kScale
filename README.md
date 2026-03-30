# 4kScale

Pixel-perfect UI scaling for World of Warcraft on 4K, ultrawide, and Retina displays.

![WoW](https://img.shields.io/badge/WoW-Midnight%2012.x-blueviolet)
![Version](https://img.shields.io/badge/version-1.0.0-blue)

## The Problem

WoW's built-in UI scale slider maxes out around 0.64, which is too large for high-resolution monitors. On 4K and Retina displays, the UI wastes precious screen space. Setting scale via CVars causes taint and breaks secure frames.

## The Solution

4kScale uses `UIParent:SetScale()` with deferred execution to safely scale the UI without taint. It saves your preferred scale per resolution, so switching between a laptop screen and an external monitor just works.

## Features

- **Per-resolution profiles** — automatically applies the right scale when you switch monitors
- **Smart suggestions** — detects your display (MacBook, 4K, ultrawide) and recommends an optimal scale
- **Monitor profiles dropdown** — presets for MacBook Air/Pro, 4K 24"-40", ultrawide, 1440p
- **Quick presets** — Compact (0.40), Small (0.45), Medium (0.64), Large (0.80), Default (1.00)
- **Auto-apply on login** — set it once, forget about it
- **Taint-safe** — never touches `SetCVar("uiScale")`, only uses safe `UIParent:SetScale()`
- **Combat-safe** — defers scale changes until you leave combat
- **Resolution change detection** — notifies you when resolution changes (dock/undock)
- **Slash commands** — full control from the chat box
- **Custom minimap button** — draggable, with tooltip showing current scale info
- **Premium UI** — custom toggle switches, cyan accent design, visual scale bar

## Slash Commands

| Command | Description |
|---------|-------------|
| `/4kuhd` | Open settings panel |
| `/4kuhd 0.45` | Set scale to 0.45 |
| `/4kuhd auto` | Apply recommended scale for your display |
| `/4kuhd reset` | Reset scale to 1.0 |
| `/4kuhd info` | Show resolution, scale, and recommendation |
| `/4kuhd minimap` | Show minimap button |
| `/4kuhd minimap hide` | Hide minimap button |

## Recommended Scales

| Display | Resolution | Suggested |
|---------|-----------|-----------|
| MacBook Air 13" | 2560x1664 | 0.64 |
| MacBook Pro 14" | 3024x1964 | 0.60 |
| MacBook Pro 16" | 3456x2234 | 0.55 |
| 24" 4K | 3840x2160 | 0.64 |
| 27" 4K | 3840x2160 | 0.58 |
| 32" 4K | 3840x2160 | 0.53 |
| 34" Ultrawide | 3440x1440 | 0.71 |
| 1440p 27" | 2560x1440 | 0.85 |

## Installation

1. Download the latest release from [GitHub Releases](../../releases) or [CurseForge](https://www.curseforge.com/wow/addons/4kscale)
2. Extract `4kScale` folder into `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW or `/reload`
4. Click the minimap button or type `/4kuhd`

## How It Works

WoW's reference UI height is 768 pixels. The pixel-perfect scale for any resolution is `768 / screen_height`. However, this value is often too small for comfortable reading on smaller physical screens (e.g., 0.39 on a 14" laptop). 4kScale provides smart recommendations that balance pixel density with readability based on your display type.

Scale is applied via `UIParent:SetScale()` deferred through `C_Timer.After(0)` to break any taint chain. Changes are skipped during combat lockdown and retried when combat ends.
