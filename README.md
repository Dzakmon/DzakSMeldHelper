# DzakSMeldHelper

A World of Warcraft retail addon that pops a defensive-ability reminder icon on screen when an enemy is casting one of a configurable list of spells **directly at you**.

The default counter-ability is **Shadowmeld** (spellId 58984) for Night Elves, and only shows when Shadowmeld is off cooldown. Both the watched-spell list and the race → counter-spell mapping are user-editable from the in-game settings panel.

> Originally built around Shadowmeld (hence the "SMeld" in the name), but the architecture supports any race-gated defensive — just add entries to the Counter Spells list.

---

## Installation

1. Clone or copy this folder into your WoW addons directory:
   ```
   World of Warcraft\_retail_\Interface\AddOns\DzakSMeldHelper\
   ```
2. Restart WoW or `/reload` if it was already running.
3. Verify it loaded: `/dsmh status` should print player name, race, and counter-spell info.

The addon ships with 13 default watched spells (sourced from `AbilitiesToSMeld.txt`) and one default counter-spell (Night Elf → Shadowmeld). Both lists are copied into SavedVariables on first run and become user-editable from then on.

---

## Usage

### Slash commands

| Command | Effect |
|---------|--------|
| `/dsmh` | Open the settings panel |
| `/dsmh test` | Force-show the icon (sanity check on position/size) |
| `/dsmh hide` | Hide the icon and clear active state |
| `/dsmh status` | Print enabled state, player, counter-spell, list sizes |
| `/dsmhdebug [on\|off]` | Toggle debug tracing (no arg = toggle) |

### Settings panel

`/dsmh` (or opening it from the Esc → Options → AddOns → DzakSMeldHelper menu) brings up a panel with three regions:

- **Enabled** — master on/off. When off, no detection runs and the icon stays hidden, but events remain registered so re-enabling is instant.
- **Watched Spells** — the dangerous spells. Type a spell ID, click **Add** (or press Enter). Each row shows the spell's icon, ID, and resolved name. Click **X** to remove a row. **Reset Defaults** restores the 13 spells defined in code.
- **Counter Spells** — race → spellId mappings. Type a spell ID and race token (e.g. `NightElf`), click **Add**. **Reset Defaults** restores the default Night Elf → Shadowmeld entry. The Race field defaults to your current character's race on open.

> Spell IDs that can't be resolved (Blizzard hasn't loaded them, or you typed a bad number) show `(unknown)` with a question-mark icon. They still work for matching — just useful to verify visually.

### Edit Mode anchor

The icon is parented to a movable anchor managed by LibEditMode.

1. Press **Esc → Edit Mode** (or `/editmode`).
2. Find **"DzakSMeldHelper Icon"** in the list of frames.
3. Drag it to your preferred spot. Position is saved to SavedVariables.

---

## How it works

### Detection

The detection logic is **self-contained** — it does not depend on the [TargetedSpells](https://www.curseforge.com/wow/addons/targeted-spells) addon being installed, even though the pattern is lifted from it.

For each enemy unit on a nameplate, the addon listens to:

- `UNIT_SPELLCAST_START`
- `UNIT_SPELLCAST_CHANNEL_START`
- `UNIT_SPELLCAST_EMPOWER_START`
- `NAME_PLATE_UNIT_ADDED` (catches casts already in progress when a nameplate appears)
- `UNIT_TARGET` (catches retargets mid-cast)

On any of those, it waits 0.2 seconds (so Blizzard's cast info / target name has time to populate), then checks:

1. Is the unit hostile, in combat, and not in your party? (`UnitIsIrrelevant`)
2. Is its current spell in your **Watched Spells** list?
3. Is its spell-target name your character's name? (`UnitSpellTargetName`)
4. Does your current race appear in **Counter Spells**?
5. Is the corresponding counter-spell off cooldown? (cooldowns ≤ 1.5s are treated as just the GCD)

If **all five** are true, the counter-spell's icon is shown at the anchor's location.

The icon is hidden again on `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_INTERRUPTED`, `_CHANNEL_STOP`, `_EMPOWER_STOP`, or `NAME_PLATE_UNIT_REMOVED` for the unit. Multiple simultaneous threats are tracked in an `activeThreats` set; the icon stays up until the last one clears.

### Why nameplates?

WoW only sends `UNIT_SPELLCAST_*` events for units you have a unit token for. Nameplate units (`nameplate1`, `nameplate2`, ...) are the only way to receive cast events from arbitrary enemies without targeting them. The CVar `nameplateShowOffscreen` (set to 1 by TargetedSpells) makes off-screen nameplates also fire events — recommended if you run this addon.

---

## File structure

```
DzakSMeldHelper/
  DzakSMeldHelper.toc      Addon manifest
  DzakSMeldHelper.lua      Defaults, DB seeding, detection, slash command
  Debug.lua                ns.Debug:print + /dsmhdebug
  Anchor.lua               LibEditMode anchor (ns.anchorFrame)
  Settings.lua             Blizzard Settings canvas panel
  AbilitiesToSMeld.txt     Canonical source of the watched-spell defaults
  Libs/
    LibStub/               Standard library loader
    LibEditMode/           Edit Mode integration library
  README.md                This file
```

### Load order (declared in the TOC, matters)

```
Libs\LibStub\LibStub.lua
Libs\LibEditMode\embed.xml
Debug.lua          ← must precede Anchor (Anchor uses ns.Debug)
Anchor.lua         ← creates ns.anchorFrame, must precede main (main parents icon to it)
DzakSMeldHelper.lua ← seeds DB, exposes ns.* helpers used by Settings
Settings.lua       ← uses ns.* helpers, sets ns.OpenSettings
```

---

## Data layout (`DzakSMeldHelperDB`)

```lua
DzakSMeldHelperDB = {
    enabled = true,           -- master on/off
    debug = false,            -- toggled by /dsmhdebug
    seeded = true,            -- set once after first-run seed; prevents re-seeding on update
    anchor = {                -- LibEditMode-managed icon position
        point = "CENTER",
        x = 0,
        y = 0,
        enabled = true,
    },
    watchedSpells = {         -- set keyed by spellId
        [388940] = true,
        [374352] = true,
        -- ... 11 more by default
    },
    counterSpells = {         -- array of { race, spellId } entries
        { race = "NightElf", spellId = 58984 },
    },
}
```

**About `seeded`:** when this flag is `true`, the addon does not copy code-level defaults into SavedVariables again. That means if a future version of the addon adds new entries to `ns.DEFAULT_WATCHED_SPELLS`, **existing users won't pick them up automatically**. This is intentional — the user has full control over their lists. Click **Reset Defaults** in the settings panel to pull the latest defaults from code.

---

## Extending

### Adding more watched spells

Either:

- **In-game (per-character):** open `/dsmh`, paste the spell ID, click Add.
- **In code (for everyone):** add the ID to `AbilitiesToSMeld.txt`, then mirror it into `ns.DEFAULT_WATCHED_SPELLS` in `DzakSMeldHelper.lua`. Existing users will need to click **Reset Defaults** to pick it up.

### Adding a defensive for another race

Open `/dsmh`, scroll to **Counter Spells**, enter the spell ID and the WoW race token (the one returned by `select(2, UnitRace("player"))` — e.g. `Human`, `Orc`, `Tauren`, `Dracthyr`, `NightElf`).

To bake it into the defaults, edit `ns.DEFAULT_COUNTER_SPELLS` in `DzakSMeldHelper.lua`:

```lua
ns.DEFAULT_COUNTER_SPELLS = {
    { race = "NightElf", spellId = 58984 }, -- Shadowmeld
    { race = "Dwarf",    spellId = 20594 }, -- Stoneform
    -- ...
}
```

### Class/spec gating

Currently only race gates the counter-spell. If you need class- or spec-aware defensives (e.g. a paladin's Divine Shield), extend the `counterSpells` entry shape with `class` and/or `specId` fields and update `GetCounterSpellForCurrentPlayer()` to compare them.

### Adding a public API

This addon does not currently expose anything outside its private namespace. If another addon needs to query state, follow the pattern in `C:\Repos\WoW\DandersFrames\API.lua` — declare explicit `DzakSMeldHelper_*` globals that wrap internal calls.

---

## Debugging

```
/dsmhdebug on
```

Then trigger a cast in-game. You'll see chat lines like:

```
[DSMH:detect] unit= nameplate3 spellId= 388940 watched= true target= YourName
[DSMH:show]   unit= nameplate3 spellId= 388940 counter= 58984
[DSMH:clear]  unit= nameplate3
```

The traces tell you exactly which check passed or failed. Common dead ends:

- `watched= nil` — you haven't added that spell ID to the Watched Spells list.
- `target= <someone else>` — the cast isn't on you. Not a bug.
- `skip - counter-spell 58984 on cooldown` — wait for it to come up; the addon won't suggest using something you can't.
- `skip - no counter-spell for race= <your race>` — add an entry in the settings panel.

Turn it back off with `/dsmhdebug off` when you're done.

---

## Lineage and credits

- **Detection pattern** is lifted from [TargetedSpells](https://www.curseforge.com/wow/addons/targeted-spells) by Xephyris-Blackrock-EU. The `UnitIsIrrelevant` filter, the 0.2-second cast-info delay, and the event list all mirror what TargetedSpells does. This addon does **not** depend on TargetedSpells being installed; we re-implement the same logic ourselves because TargetedSpells doesn't expose a public API.
- **Debug, Anchor, and Settings module patterns** come from `C:\Repos\WoW\DzakTools` — see the canonical template at `C:\Repos\WoW\DzakTools\Template\` if you want to scaffold a new addon from scratch.
- **LibEditMode** by birta — used as the anchor library. Bundled under `Libs\`.
- **DandersFrames** by Danders — referenced for its public-API pattern (`DandersFrames_*` globals), not currently integrated.

---

## Version

`0.3.0` (in-development, untested in-game as of this writing).

Bumping version requires touching three things: `DzakSMeldHelper.toc` (`## Version:`), this file (above), and the project memory entry at `C:\Users\jakub.malasek\.claude\projects\c--Repos-WoW-DzakSMeldHelper\memory\project_dzaksmeldhelper.md`.
