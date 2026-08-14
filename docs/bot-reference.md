# MiniMeter - support reference

## What it is

MiniMeter shows a small draggable text display on your UI with your FPS, world latency (MS), and equipment durability. The values are color coded by configurable thresholds and update once per second. Hovering the text can open a micro menu with shortcuts to common game windows (character, professions, quest log, etc).

## Facts

| Item | Value |
|---|---|
| Addon version | 3.2.4 |
| Author | Verz |
| Interface versions (TOC) | 120100, 50504, 40402, 38002, 38000, 30405, 30300, 20506, 11509 (Retail and Classic clients) |
| Saved variables | MiniMeterDB (account-wide) |
| Slash commands | /minimeter, /mmeter (both open the options panel) |
| Options location | Game Menu -> Options -> AddOns -> MiniMeter |
| Bundled libraries | LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibQTip-1.0, MiniFramework |
| CurseForge project | minimeter (ID 1419348) |

Note: /mm is NOT a MiniMeter command; it is used by the MiniMarkers addon.

## Features

### The meter text

- Shows up to three parts, in this order: FPS, latency, durability. Each can be toggled independently.
- Default position: anchored below the Minimap (top of the text to the bottom of the Minimap, offset 0, -25). If the saved anchor frame no longer exists, it re-anchors to the screen (UIParent) instead.
- Updates every 1 second. The interval is stored in saved variables as UpdateInterval (default 1) but has no options UI control.
- FPS is your current framerate, rounded down.
- Latency is the world latency from the game's network stats, rounded down, in milliseconds.
- Durability is the combined current/max durability of all equipped items (shirt slot excluded), shown as a percent. If nothing with durability is equipped, the durability part is not shown at all even when enabled.

### Moving and locking

- Drag the text with the left mouse button to move it anywhere. The position is saved and the frame is clamped to the screen.
- The "Locked" checkbox stops it being dragged. Mouse input stays enabled while locked so the micro menu keeps working.

### Color coding

When "Enable Colors" is on, each value is colored by thresholds. When off, everything uses the default color (white).

| Value | Red (bad) | Yellow (ok) | Green (good) |
|---|---|---|---|
| FPS | 30 or less | 31 to 60 | above 60 |
| Latency (ms) | above 200 | 51 to 200 | 50 or less |
| Durability | 40% or less | 41% to 70% | above 70% |

Colors used: default white (255,255,255), bad red (231,76,60), ok yellow (241,196,15), good green (46,204,113). Thresholds and colors are stored in saved variables; there is no options UI to edit the threshold numbers or the colors themselves, only the on/off toggle.

### Micro menu

Hovering the meter text opens a menu (when "Enable Micro Menu" is on) with these entries, each opening the matching game window on click:

Character Info, Professions, Talents & Spellbook, Achievements, Quest Log, Housing Dashboard, Guild & Communities, Group Finder, Warband Collections, Adventure Guide, Game Menu.

- The menu will not open at all while you are in combat.
- Professions, Talents & Spellbook, and Game Menu also do nothing when clicked in combat.
- Housing Dashboard only works on clients that have the housing micro button.

## Settings

All settings are in the options panel, grouped under dividers. Changes to checkboxes, the slider, and the font apply immediately. Text format changes are saved as you edit and show up on the next 1-second update.

### Toggles

| Setting | Default | Effect |
|---|---|---|
| Enable Colors | On | Color values by thresholds; off = plain white text |
| Enable FPS | On | Show the FPS part |
| Enable Latency | On | Show the latency part |
| Enable Durability | On | Show the durability part |
| Locked | Off | Prevent dragging the text |
| Enable Micro Menu | On | Show the hover micro menu |
| Enable Text Outline | On | Outline on the font (sets font flag OUTLINE) |

### Size

| Setting | Default | Range |
|---|---|---|
| Size (slider, font size) | 18 | 4 to 50, step 1 |
| Font Style (dropdown) | Friz Quadrata (Fonts\FRIZQT__.TTF) | Any font registered with LibSharedMedia |

MiniMeter bundles about 45 fonts and registers them with LibSharedMedia, so they also appear in other addons that use shared media. Fonts registered by your other addons appear in MiniMeter's dropdown too.

### Text

Each part has an editable format string. The placeholder $value is replaced with the number. Example: "FPS: $value" becomes "FPS: 123".

| Setting | Default |
|---|---|
| FPS Text | `FPS: $value` |
| Latency Text | `MS: $value` |
| Durability Text | `\|A:repair:16:16\|a: $value%` (a repair icon, then the percent) |

### Reset

The "Reset" button (top right of the options panel) restores all settings to defaults after a Yes/No confirmation popup, then prints "MiniMeter - Settings reset to default." in chat. This also resets the position.

## Version-gated behavior

- The TOC supports both Retail and Classic clients. The micro menu entries call whatever the client provides (e.g. talents opens either the talent frame or the player spells frame depending on client).
- On clients where the Midnight expansion is current, the options panel cannot be opened during combat; the slash command does nothing until combat ends. On older clients it opens fine in combat.

## Troubleshooting

- "The text is gone / I can't find it": check that at least one of Enable FPS / Enable Latency / Enable Durability is on. The default spot is just below the minimap. If a minimap addon removed the frame it was anchored to, the text re-anchors to the screen and can end up at the screen edge. The Reset button restores the default position.
- "I can't drag it": untick "Locked" in the options. Drag with the left mouse button.
- "Everything is white / no colors": turn on "Enable Colors".
- "Durability isn't showing": it is hidden when nothing you have equipped has durability. Also check "Enable Durability".
- "The micro menu doesn't open": turn on "Enable Micro Menu". It never opens while you are in combat.
- "A menu entry does nothing": Professions, Talents & Spellbook, and Game Menu are blocked in combat. Housing Dashboard needs a client with the housing button.
- "My custom text lost the number": the format must contain $value; that token is replaced with the value.
- "/mm doesn't open MiniMeter": /mm belongs to MiniMarkers. Use /minimeter or /mmeter.
- "Options won't open in combat": expected on Midnight-era clients; leave combat first.
- "Font list is huge / has fonts I don't recognise": the list is every LibSharedMedia font, including ones registered by other addons.
