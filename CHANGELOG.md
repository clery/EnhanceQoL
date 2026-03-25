# Changelog

## [9.10.0] - 2026-03-25

### ✨ Added

- Group Frames (Party / Raid / Main Tanks / Main Assists): Added optional `Smooth fill` toggles for the health and power bars in Edit Mode, matching the existing smooth bar behavior used on other EQoL bar modules.

### 🐛 Fixed

- Cooldown Panels (CDM Auras): Fixed aura cooldown rendering falling back to deprecated legacy cooldown APIs when `C_UnitAuras.GetAuraDuration()` did not provide a duration object. CDM aura panels now only use `SetCooldownFromDurationObject()` for aura-driven cooldowns.
- Unit Frames (Player / Target / ToT / Focus / Boss): Fixed highlight borders using the outer frame bounds instead of the actual health-bar border area. Highlights now align with the visible bar border again and no longer render partially behind it.

---

## [9.9.4] - 2026-03-24

### 🐛 Fixed

- Missing locale

---

## [9.9.3] - 2026-03-24

### 🐛 Fixed

- Group Frames (Party / Raid / Edit Mode): Fixed the action buttons at the bottom of the settings panel using an uneven layout. They now use a consistent grid and the panel height behaves more cleanly when many options are visible.
- Group Frames (Party / Raid / Edit Mode): Fixed `Hover`, `Target`, and `Aggro highlight` borders not showing anymore, including their sample preview.

---

## [9.9.2] - 2026-03-24

### 🐛 Fixed

- Cooldown Panels (Items / Healthstones): Fixed `Show item uses` not updating immediately after enabling it on item entries.
- Unit Frames (Boss): Highlight color wasn't working correctly

---

## [9.9.1] - 2026-03-24

### 🐛 Fixed

- Group Finder (Party Keystone): Fixed party keystone sharing continuing in the background even while the option was turned off.

## [9.9.0] - 2026-03-24

### ✨ Added

- Shared Media: 6 new border assets in midnight style
- UI / Bars & Resources: Added a standalone `Total Absorb Tracker` for the player. It can be positioned in Edit Mode and supports custom icon, text, and border settings.
- UI / Nameplates: Added Blizzard default nameplate enhancements with aura click-through and optional enemy color coding by unit type, including configurable `Boss`, `Mini-boss`, `Caster`, `Melee`, and `Trivial` colors.
- Unit Frames (Player / Target / Focus): Added incoming heal bars to the regular unit frames. The feature can now be adjusted there just like on the group frames.
- Group Frames (Party / Raid): Added an optional `Aggro highlight` border in Edit Mode with `All` / `Only non-tanks` mode, sample preview, configurable texture/layer/size/offset, and adjustable color (default orange).
- Cooldown Panels (Spells): Added an optional `Hide when no resource` setting, so spells can stay hidden until you have enough resource again. This can be set for a whole panel or adjusted per entry.
- GCD Bar: Added an optional Blizzard `XPBarAnim-OrangeSpark` overlay that tracks the active fill edge, so the bar can be hidden for a spark-only look over resource bars.
- GCD Bar: Added a configurable `Frame strata` setting in Edit Mode, matching the standalone castbar layering controls and persisting correctly through Edit Mode hydration.
- Unit Frames (Target): Added `Show group number` unit-status settings to the target unit frame, matching the existing player-frame option set.

### 🔄 Changed

- GCD Bar: Lowered the minimum configurable bar height from `6` to `1`.
- Unit Frames / Group Frames (Aura max): Lowered the minimum configurable aura count to `1` for buff, debuff, and external displays, so boss and group frames can be limited to a single aura.
- Group Frames (Party / Raid): Improved the overall performance of group-frame updates, especially for custom raid sorting. Larger roster and layout updates should now feel noticeably smoother.
- Group Frames (Party / Raid): Made group-frame refreshes more stable during sort and roster changes, so frames keep their layout more reliably while the order updates in the background.

### 🐛 Fixed

- Group Finder (Raider.IO applicant link): Fixed the LFG applicant context-menu URL builder for cross-realm names so Raider.IO profile links no longer pick up the player's own realm, and skip link generation entirely when the applicant identity is secret.
- Group Finder (Applicants / secret values): Hardened applicant sorting, ignore highlighting, and applicant-cover tweaks against secret LFG data so raid listings no longer spam taint errors when Group Finder updates while restricted content is active.
- Gear & Upgrades (Equipment Flyout): Added a separate item-level position setting for equipment flyouts and stopped reusing the Character Frame `Outside` placement there, so upgrade/replace comparisons no longer end up in confusing off-slot positions.
- Unit Frames (Player): Fixed the player-frame name sometimes staying empty after login or loading screens by refreshing the label again when the EQoL frame is shown and once more after entering the world.
- Unit Frames / Group Frames: Main group anchors and secure headers are now clamped to the screen so moved layouts cannot be dragged off-screen as easily.
- Minimap (Instance Difficulty Indicator): Stopped overriding the Blizzard difficulty icon until the EQoL text-replacement option is actually enabled, and restore the default indicator correctly when that option is turned off again.
- Square Minimap / Instance Difficulty: Delves now show `D<tier>` (for example `D8`) on the minimap difficulty indicator instead of falling back to the full `Delves` label.
- Resource Bars (Warlock / Soul Shards): Fixed `Use custom color at maximum` getting stuck after entering dungeons because the Soul Shard max-value refresh could switch between raw and non-raw power ranges.
- Resource Bars (Runic Power / Maelstrom): Fixed protected Midnight values still using absolute threshold-color handling. Both resource types now use the percent-based secret threshold path instead of absolute threshold colors.
- Group Frames (Raid / Dynamic Scaling): Fixed `Level` text and `Group <number>` indicators growing with `Preserve content size`. Those two labels now keep their normal size while the slider still compensates the rest of the raid-frame content.
- Group Frames (Raid / Edit Mode Preview): Fixed grouped raid preview resolving against the current live raid subgroup layout instead of the requested sample size, so preview blocks now stay correct while already inside a raid.
- Questing & Cinematics (Quest Automation): Reverted the split auto accept / turn-in / gossip workflow after the new model proved unreliable. Quest automation now uses the previous combined `Automatically accept and complete quests` setting again, while keeping the Retail-compatible gossip selection path.
- Questing & Cinematics (Auto Gossip / Quest Turn-In): Fixed mixed quest-and-gossip NPCs immediately jumping into RP dialogue even while quest turn-in automation was off. Auto gossip no longer overrides quest interactions, and single-option gossip only auto-continues when no quest entries are present.
- Questing & Cinematics (Auto Accept / Turn-In): Fixed stale pending auto-accept quest state causing modifier-based quest turn-ins to close the quest frame instead of completing the hand-in, and leaving later quest interactions stuck in the same broken state.
- Questing & Cinematics (Auto Gossip Settings): Fixed the broken `Configured gossip IDs` picker causing Blizzard Settings type errors. Gossip IDs are now managed via `/eqol aag <id>` and `/eqol rag <id>` instead.

### ❌ Removed

- Dialogs & Confirmations: Removed the `Replace enchant` auto-confirm option because it could block enchant replacements instead of helping.
