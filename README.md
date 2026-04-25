English | [中文](README_zh.md)

# GrindSurvivors-QoL

A collection of quality-of-life (QoL) mods for the UE5 game **Grind Survivors**, built on the UE4SS mod framework.

This repository manages all mods and their shared dependencies in one place, making installation and updates simple.

## Mods

| Mod | Description |
|-----|-------------|
| **FreshPerksFirst** | In Infinity Mode, prevents already-owned perks from appearing in level-up choices until all perks in their category group are owned. Once a full category is learned, its perks re-enter the random pool. |
| **PickupRangeXpBoost** | Converts the current `Stat.PickupRange` boost relative to the base value into bonus XP using a configurable ratio. Displays the boost percentage and bonus XP in real-time on screen. |

## Installation

### Automatic Installation (Recommended)

1. Download the [latest source code](https://github.com/abevol/GrindSurvivors-QoL/archive/refs/heads/master.zip) and extract it.
2. Double-click `install.cmd` in the root folder.
3. Follow the prompts to select your game directory (usually `Grind Survivors/GrindSurvivors/Binaries/Win64/`).
4. The script will automatically download and install the **UE4SS mod framework** and configure all mods.

### Manual Installation

1. Ensure [UE4SS](https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases/tags/experimental-latest) (**experimental-latest** version) is installed.
2. Copy the entire `Mods/` folder to `Grind Survivors/GrindSurvivors/Binaries/Win64/ue4ss/Mods/`. The final structure should look like:
   ```
   ue4ss/Mods/
   ├── FreshPerksFirst/   # → from Mods/FreshPerksFirst/
   ├── PickupRangeXpBoost/ # → from Mods/PickupRangeXpBoost/
   └── shared/             # → from Mods/shared/
   ```
3. Open `Grind Survivors/GrindSurvivors/Binaries/Win64/ue4ss/Mods/mods.txt` and add the following lines to register each mod:
   ```text
   FreshPerksFirst : 1
   PickupRangeXpBoost : 1
   ```
4. Launch the game.

## Verification

1. Launch the game and start any level.
2. For **PickupRangeXpBoost**: check the top of the screen for an XP boost label (e.g. **"EXP + 70% (+3)"**).
3. For **FreshPerksFirst**: level up in Infinity Mode and verify that already-owned perks are filtered from choices.

---

## FreshPerksFirst

**Smart Perk Filtering for Infinity Mode.**

- Post-hooks on `LevelUpWidget:Activate` / `RerollPerks`
- Modifies `widget.Perks` TArray and updates SkillCard visuals
- Prevents duplicate perks until their entire category is mastered

### Console Commands

| Command | Description |
|---------|-------------|
| `fpf_status` | View current mod status |
| `fpf_debug` | Toggle debug logging |

---

## PickupRangeXpBoost

**Pickup Range → XP Boost Conversion.**

- Converts the current `Stat.PickupRange` boost relative to the base value (360) into bonus XP
- Formula: `Bonus XP = Base XP × (Current Stat.PickupRange - 360) / 360 × XP_CONVERSION_RATE`
- Default conversion ratio: `XP_CONVERSION_RATE = 1.0`
- Calculates and grants bonus XP in batches every 500ms
- Real-time on-screen display with color-coded boost levels

### Boost Examples (with default `XP_CONVERSION_RATE = 1.0`)

| PickupRange | XP Bonus | Bonus XP when gaining 10 XP |
|-------------|----------|-----------------------------|
| 360 | 0% | 0 |
| 540 | 50% | 5 |
| 720 | 100% | 10 |
| 1080 | 200% | 20 |

### Console Commands

| Command | Description |
|---------|-------------|
| `xpboost_status` | View current status (PickupRange, range boost, XP ratio, XP bonus, pending XP) |
| `xpboost_debug` | Toggle debug logging |
| `xpboost_ratio <value>` | Set the XP conversion ratio (`0` disables bonus XP, `1` keeps original behavior) |
| `xpboost_set <value>` | Manually set PickupRange (for testing) |
| `xpboost_test <amount>` | Manually add XP to the pending queue (default 10) |
| `xpboost_ui` | Toggle on-screen boost display |

### Configuration

Modify the constants at the top of `Mods/PickupRangeXpBoost/Scripts/main.lua`:

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `BASE_PICKUP_RANGE` | 360 | Base PickupRange value; values below this will not generate a bonus |
| `XP_CONVERSION_RATE` | 1.0 | Converts pickup range boost into XP bonus; can also be changed in-game via `xpboost_ratio` |
| `DEBUG_MODE` | false | Debug log toggle |

---

## Project Structure

```
GrindSurvivors-QoL/
├── AGENTS.md                   # Developer reference documentation
├── README.md                   # This file
├── README_zh.md                # Chinese user documentation
├── install.cmd                 # One-click installer launcher
├── install.ps1                 # One-click installer script
└── Mods/
    ├── FreshPerksFirst/        # Smart Perk Filtering mod
    │   └── Scripts/main.lua
    ├── PickupRangeXpBoost/     # XP Boost mod
    │   └── Scripts/main.lua
    └── shared/                 # Shared libraries
        ├── UEHelpers/
        ├── types/
        └── ...
```

## Dependencies

- **UE4SS** (experimental-latest): [Download](https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases/tags/experimental-latest)
- **UEHelpers**: Built-in UE4SS module (included in `Mods/shared/`)
