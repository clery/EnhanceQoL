# Changelog

## [9.0.3] - 2026-03-16

### 🐛 Fixed

- Group Frames (Health / Absorb): Fixed reverse absorb rendering on party/raid frames at full health.

---

## [9.0.2] - 2026-03-15

### 🐛 Fixed

- Container Actions: Fixed `Automatically open Container items in bag` treating cosmetic appearance-learn items (`Use: Add this appearance to your Warband collection.`) like openable containers.
- Group Frames (Healer Buff Placement / Bar): Fixed BAR indicators not behaving like proper tracked buff timers. BAR style now supports a real timed drain animation based on the first active timed aura, with an optional `Reverse` toggle on top of the existing `Horizontal` / `Vertical` orientation.
- Group Frames (Portraits): Fixed `Extend border over portrait` creating a second portrait border on party/MT/MA frames. The portrait now sits inside the shared frame border like the regular Unit Frames, while non-portrait anchor positions stay unchanged.
- Unit Frames (Edit Mode / Show when): Fixed missing `Show when` visibility settings on player-scoped single unit frames (`Player`, `Target`, `Target of Target`, `Focus`, `Pet`), including separate Party/Raid and Flying/Skyriding conditions.

---

## [9.0.1] - 2026-03-15

### 🐛 Fixed

- Unit Frames (Edit Mode): Fixed single-frame `Offset X` / `Offset Y` position changes not updating live while Edit Mode was open.

---

## [9.0.0] - 2026-03-15

### ✨ Added

- Cooldown Panels (Cooldown text): Added panel-wide static `Cooldown text color` customization (`Edit Mode -> Cooldown text`) with opacity support.
- Cooldown Panels (Items): Added automatic rank-group support for Health/Combat Potions and Flasks/Fleeting Flasks. Item entries now store the lowest-rank ID as canonical and can still resolve to higher ranks.
- Cooldown Panels (Layout Edit): Added standalone panel settings access directly from Layout Edit, so advanced panel positioning/settings can be adjusted from the layout workflow without switching back to the right-side editor inspector.
- Cooldown Panels (Editor): Added collapsible panel grouping with persistent groups, drag-and-drop assignment/removal, panel and group context-menu actions, alphabetical group sorting, and a `Hide empty groups` panel-filter toggle.
- Cooldown Panels (Overlays): Added panel-wide `Ready glow color` customization (`Edit Mode -> Overlays`). Ready glows now use the configured panel color through the internal glow system.
- Cooldown Panels (Overlays): Added panel-wide `No desaturation` (`Edit Mode -> Overlays`) to keep icons fully colored while still tracking cooldown state.
- Cooldown Panels (Radial Layout): Added a configurable `Arc degrees` slider/input for radial panels, so icons can be distributed across custom arcs (for example semicircles) instead of always using a full `360°` circle.
- Cooldown Panels (State Textures): Added per-entry custom state textures for spells and tracked auras with atlas/FileDataID validation, live Layout Edit preview, click-through rendering, transform controls (`Scale`, `Width`, `Height`, `Angle`), and optional doubled/mirrored texture rendering with configurable spacing.
- Cooldown Panels (Tracked Buffs): Added support for tracking player buffs directly from Blizzard Cooldown Manager (`Buff Icon` / `Buff Bar`) via the new `Tracked Buff (CDM)` entry type.
- Group Frames (Border): Added an option to change the Strata and level of the border.
- Group Frames (Healer Buff Placement): Added per-indicator border controls for `Icon`/`Square` styles: `Indicator Border`, `Border Texture` (SharedMedia), `Border Size`, `Border Offset`, and `Border Color`.
- Group Frames (Incoming Heals): Added an optional incoming-heal prediction bar for group frames with configurable texture, color, opacity, and sample preview.
- Group Frames (Party / Growth): Added `Center vertical` and `Center horizontal` growth modes for center-outward party expansion from the anchor midpoint.
- Group Frames (Portraits): Added portrait support for Party/MT/MA frames with configurable side, square background, separator (toggle/size/texture/custom color), and optional `Extend border over portrait`.
- Group Frames (Range Fade): Added Edit Mode controls for `Range fade` (`Enable range fade`, `Out of range opacity`, `Offline opacity`) plus sample-frame preview states so in-range, out-of-range, and offline fading is directly visible in `Sample frames`.
- Group Frames (Role Icons): Added new role icon style `FRAME` using legacy atlas icons (`UI-Frame-TankIcon`, `UI-Frame-HealerIcon`, `UI-Frame-DpsIcon`).
- Unit Frames (Auras): Added `Cooldown text font` and `Cooldown text outline` options for buff/debuff duration text in all EQoL unit frames that currently expose aura settings (`Player`, `Target`, `Focus`, and `Boss`).
- Unit Frames (Health / Absorb): Added `Don't overflow health bar` (available when `Reverse fill` is enabled). When active, overflow rendering is suppressed so only the missing-health portion is shown; at full health no reverse-overflow absorb segment is visible.
- Unit Frames (Player / Target / Focus): Added a dedicated `Dispel indicator` overlay with its own expandable settings section (`Tint`, fill opacity/color, sample preview, and optional glow customization), based on the existing Group Frames dispel indicator behavior.
- Unit Frames (Secondary Power / Stagger): Added a dedicated top-level `Stagger colors` section so Brewmaster stagger color settings are no longer nested under `Secondary Power Bar`.
- Resource Bars (Hunter Survival): Added support for `Tip of the Spear` (`260286`) as an aura-based secondary resource bar.
- Resource Bars (Runes / Essence): `Separated offset` now renders real standalone segmented bars with individual backgrounds/borders, matching other segmented resources such as Holy Power and Maelstrom Weapon.
- Resource Bars (Text): Added a new `Current - Percent` text display option for supported bar types.
- Resource Bars (Threshold Colors): Added per-resource threshold color overrides with up to `10` configurable points (value + color), including Secret-safe handling for power types that expose secret values.
- Standalone Castbar: Added configurable `Reverse fill` in `Bar style`.
- Visibility & Fading: Added the missing `Hide while flying` visibility rule to the remaining settings/editors that already supported `Skyriding`, including Cooldown Viewer, Spell Activation Overlay and Action Bars.
- Square Minimap Stats: Added an optional `Tracking Button` element that reuses the Blizzard tracking dropdown on the minimap with configurable anchor, X/Y offset, and scale. While active, the default tracking slot stays hidden and the button can be positioned directly via Minimap Stats.
- Square Minimap Stats (Location): Added `Show subzone below zone` so zone and subzone can optionally render as two lines with the subzone shown beneath the zone.
- Square Minimap Stats (Time): Added a configurable `Left-click action` for the minimap time text so it can open the calendar directly instead of the stopwatch/time manager.
- Instant Messenger (Minimap Menu): Added a `Instant Chats` submenu to the existing EnhanceQoL minimap button. It lists all open whisper tabs, sorts unread conversations first, and lets you jump straight into a chat with the input box focused.
- Economy (Crafting Orders): Added a separate `Place Crafting Orders` section with an `Always set the filter for "Current expansion"` option, matching the existing Auction House behavior.
- Mythic+ (Teleports): Added the Engineering wormhole to Quel'Thalas to the teleport list.
- Mover: Added PvPMatchResults Frame
- Mouse Ring: Added a separate `Show cast progress outside combat` toggle so cast progress can stay visible even when `Show ring only in combat` is enabled.
- Sound: Added new mute toggles for `Abundance (Dundun talking head only)` and `Delves (Valeera in-combat comments)`.

### 🔄 Changed

- Cooldown Panels (Glow): Reworked panel glow handling to use the new internal glow system for Ready/Active/Pandemic visuals, including selectable glow styles, panel/entry glow-style overrides, and configurable glow insets.
- Cooldown Panels (Glow): Separated `Proc glow` visuals from `Glow when ready`, so panel defaults and per-entry overrides for proc glows can now be configured independently from ready glows.
- Cooldown Panels (Layout Edit): Moved the missing per-entry `Show stack count` and `Show charges` toggles into the existing `Stacks / Item Count` and `Charges` expandable sections instead of duplicating entry basics in a separate block.
- Unit Frames / Group Frames: Reworked the Single UF settings layout to match the Group Frames structure more closely, including split `Buffs` / `Debuffs` sections and clearer top-level ordering.
- Mythic+ (Random Hearthstones): Changed the preferred Hearthstone selector from single-choice to multi-select. Random Hearthstone can now pick from a custom 1:N subset of owned Hearthstones instead of either one fixed Hearthstone or the full pool.

### 🐛 Fixed

- Action Bars (Range Indicator / Keybind Font): Fixed out-of-range action buttons no longer turning red when `Change keybind font` was enabled. EQoL now preserves Blizzard's red range-indicator state instead of immediately restoring the custom hotkey color.
- Class Buff Reminder: Fixed reminders showing while your character is dead or a ghost.
- Cooldown Panels (Items): Fixed `Item uses` not updating immediately after using an item. Panels with `Show item uses` now refresh their item-use counts on `BAG_UPDATE_COOLDOWN` instead of only reflecting the correct value after a later reload.
- Cooldown Panels (Layout Edit): Fixed sliders and live style updates in the per-entry Layout Edit dialog so cooldown text size/color/offset and other previewed values no longer snap back to defaults while interacting with neighboring controls.
- Cooldown Panels (Ready Glow): Fixed inconsistent/stuck ready-glow behavior for Items and Slot-based Trinkets. Ready glow now initializes correctly on reload, clears reliably when cooldown starts, and stays in sync when toggling `Glow` or changing `Glow duration` in Edit Mode.
- Cooldown Panels (Spell States): Fixed `Check power` tinting and initial stack display for `SPELL` entries that rely on spell usability/action-display data instead of standard power-cost tables, so unusable spells and application-stack spells initialize correctly after reload.
- Cooldown Panels (State Textures): Fixed custom state textures layering/preview cleanup issues, including stale textures remaining after deleting entries or changing settings, and ensured the cooldown number stays above custom textures while the ghost icon remains visible in preview for positioning.
- Drink Macro: Rebuilt the drink list from current Wowhead tooltip data, removed dead `Well Fed` entries that were always ignored at runtime, corrected squished flat-mana values and current `%`-based drinks, kept `Managi Roll` health-only, and added missing Midnight drinks such as `Magister's Mead`, `Darkwell Draft`, `Dawnmosa`, `Sunwell Shot`, and `Dragonhawk Flight`.
- Economy (Craft Shopper): Fixed an intermittent error while tracking recipe reagents where some profession reagent slots could resolve without a valid item ID and crash the shopping-list rebuild.
- Economy (Craft Shopper): Fixed reagent-quality selection for tracked profession recipes after Blizzard's reagent-tier reduction. Craft Shopper now uses the highest available reagent quality instead of falling back to the lowest tier when only `min` / `max` qualities exist.
- Experience Bar: Fixed rested text values being capped to the XP remaining in the current level. Text modes now show the real banked rested XP from `GetXPExhaustion()`, while the overlay remains limited to the current level segment.
- Food Reminder: Fixed the mage-food leave button appearing in non-follower LFG dungeons. It now only shows inside follower dungeons.
- GCD Bar / SharedMedia: Fixed a login/reload issue where the bar could appear empty because late SharedMedia statusbar/border registrations were not reapplied to the frame.
- Group Frames (Arena / Skirmish): Fixed arena/skirmish matches using EQoL raid-style group frames instead of EQoL party frames when party frames should be shown.
- Group Frames (Aura Tooltip Anchors): Fixed inconsistent party/healer-buff aura tooltip positioning so aura tooltips now follow the same Edit Mode tooltip anchor behavior as the unit tooltip instead of mixing HUD-anchor and icon-anchor placement.
- Group Frames (Health): Fixed party/raid health values sometimes getting stuck on incorrect HP after zoning or other group-state changes.
- Group Frames (Health / Absorb): Fixed stale absorb overlays on shield refreshes where a new absorb could be applied before the previous one fully expired, causing party/raid frames to stop updating the absorb bar until a later change.
- Group Frames (Localization): Fixed multiple visible Group Frame settings labels and editor action buttons not using Aura locale keys, and added payload entries for all supported locales.
- Group Frames (Party Auras / Tooltips): Fixed dungeon tooltip flicker caused by party-frame aura updates repeatedly toggling aura-button mouse state while hovered, which could also disrupt other visible tooltips that shared the global `GameTooltip`.
- Ignore List: Fixed a Retail secret-value error while scanning party/raid members for ignored players.
- Instant Messenger (Whisper Focus): Unified conversation focusing when opening whispers from the chat edit box or outgoing whisper events. Battle.net whispers now consistently focus the correct conversation tab.
- Item Upgrades: Fixed upgrade indicators and upgrade-only checks suggesting off-armor-type gear (for example Cloth on Leather classes). Bag, merchant, and loot-toast upgrade checks now respect the current spec's actual armor proficiency.
- Items / Inventory (Bag Indicators): Fixed bag upgrade arrows not showing unless `Item level` was also enabled. Upgrade arrows on Blizzard bag frames now refresh independently from the bag item-level text.
- Minimap Button Bin: Fixed `GatherMatePin*` minimap pins being treated as minimap buttons, so they no longer appear in the Button Sink or its exclude list.
- Minimap Button Bin: Fixed `PlumberLandingPageMinimapButton` being collected into the Button Sink. The Plumber landing-page minimap button is now permanently excluded.
- Mythic+ (Party Keystone): Fixed an issue where opening the party keystone panel could trigger an error instead of showing the entries correctly.
- Resource Bars: Newly auto-enabled bars for fresh characters/specs no longer spawn on top of each other on first initialization; default anchors now stack vertically from the start.
- Resource Bars (Essence): Fixed Evoker Essence `Separated offset` behavior so the option no longer only inserts spacing into the legacy essence layout and instead uses the proper segmented renderer.
- Resource Bars (Gradient / Edit Mode): Fixed a Retail Lua error when switching from specs without resource bars to specs with them, especially on fresh characters. Gradient refreshes now skip protected/invalid bar colors instead of crashing when opening, moving, or configuring the bar.
- Resource Bars (Health / Absorb): Fixed vertical absorb rendering on health bars so the absorb segment now follows the bar orientation correctly instead of appearing as a horizontal strip across the bar.
- Resource Bars (Threshold Colors / Max Color): Fixed percent-based secret/curve resource bars (for example Fury) so `Use max color` no longer suppresses `Threshold colors`. Threshold colors now evaluate through a step color curve for protected percentage values, while `Max color` still applies cleanly at full resource.
- Resource Bars (Vertical Orientation): Fixed a bug where vertical bars could revert to horizontal sizing after being moved in Edit Mode because stale layout width/height values were written back into the bar config.
- Square Minimap Stats (Time): Fixed the minimap time text ignoring `Use 24-hour format` when switching to 12-hour mode. The cached render config now preserves disabled/default-on boolean values correctly, so the time display updates to the selected format.
- Sound: Fixed mute selections for direct sound groups so they are reapplied correctly after login or `/reload`.
- Unit Frames (Absorb Glow): Fixed absorb glow placement and clipping for reverse/overflow layouts. The glow is now anchored to the health-frame edge while being clipped to the health fill region.
- Unit Frames (Player / Target / Focus / Dispel Indicator): Fixed several follow-up issues in the new single-frame dispel indicator implementation, including wrong locale placement, a Blizzard overlay-orientation error on custom unit frames, stale clears on target/focus swaps, and target/focus indicators appearing on hostile units instead of friendly units only.

### ❌ Removed

- UI (Frames): Removed the `Unclamp Blizzard damage meter` option and its custom unclamp handling to avoid taint issues; Blizzard damage meter windows now use the default screen clamping again.
