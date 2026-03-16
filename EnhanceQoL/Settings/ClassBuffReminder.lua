local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local Reminder = addon.ClassBuffReminder

local cat = addon.SettingsLayout and addon.SettingsLayout.rootUI
if not (cat and addon.functions and addon.functions.SettingsCreateExpandableSection) then return end

local DB_ENABLED = "classBuffReminderEnabled"
local DB_SHOW_PARTY = "classBuffReminderShowParty"
local DB_SHOW_RAID = "classBuffReminderShowRaid"
local DB_SHOW_SOLO = "classBuffReminderShowSolo"
local DB_GLOW = "classBuffReminderGlow"
local DB_GLOW_STYLE = "classBuffReminderGlowStyle"
local DB_GLOW_INSET = "classBuffReminderGlowInset"
local DB_SOUND_ON_MISSING = "classBuffReminderSoundOnMissing"
local DB_MISSING_SOUND = "classBuffReminderMissingSound"
local DB_DISPLAY_MODE = "classBuffReminderDisplayMode"
local DB_GROWTH_DIRECTION = "classBuffReminderGrowthDirection"
local DB_GROWTH_FROM_CENTER = "classBuffReminderGrowthFromCenter"
local DB_TRACK_FLASKS = "classBuffReminderTrackFlasks"
local DB_TRACK_FLASKS_INSTANCE_ONLY = "classBuffReminderTrackFlasksInstanceOnly"
local DB_SCALE = "classBuffReminderScale"
local DB_ICON_SIZE = "classBuffReminderIconSize"
local DB_FONT_SIZE = "classBuffReminderFontSize"
local DB_ICON_GAP = "classBuffReminderIconGap"
local DB_XY_TEXT_SIZE = "classBuffReminderXYTextSize"
local DB_XY_TEXT_OUTLINE = "classBuffReminderXYTextOutline"
local DB_XY_TEXT_COLOR = "classBuffReminderXYTextColor"
local DB_XY_TEXT_OFFSET_X = "classBuffReminderXYTextOffsetX"
local DB_XY_TEXT_OFFSET_Y = "classBuffReminderXYTextOffsetY"
local LEGACY_DB_SOUND_DEBUG_TRACE = "classBuffReminderSoundDebugTrace"
local LEGACY_DB_SHOW_ICON = "classBuffReminderShowIcon"
local LEGACY_DB_ONLY_WHEN_MISSING = "classBuffReminderOnlyWhenMissing"

local defaults = (Reminder and Reminder.defaults)
	or {
		enabled = false,
		showParty = true,
		showRaid = true,
		showSolo = false,
		glow = true,
		glowStyle = "MARCHING_ANTS",
		glowInset = 0,
		soundOnMissing = false,
		missingSound = "",
		displayMode = "ICON_ONLY",
		growthDirection = "RIGHT",
		growthFromCenter = false,
		trackFlasks = false,
		trackFlasksInstanceOnly = false,
		scale = 1,
		iconSize = 64,
		fontSize = 13,
		iconGap = 6,
		xyTextSize = 13,
		xyTextOutline = "OUTLINE",
		xyTextColor = { r = 1, g = 1, b = 1, a = 1 },
		xyTextOffsetX = 0,
		xyTextOffsetY = 0,
	}
if defaults.glowStyle == nil then defaults.glowStyle = "MARCHING_ANTS" end
if defaults.glowInset == nil then defaults.glowInset = 0 end

local function refreshReminder()
	if Reminder and Reminder.OnSettingChanged then Reminder:OnSettingChanged() end
end

local expandable = addon.functions.SettingsCreateExpandableSection(cat, {
	name = L["Class Buff Reminder"] or "Class Buff Reminder",
	newTagID = "ClassBuffReminder",
	expanded = false,
	colorizeTitle = false,
})

addon.functions.SettingsCreateText(cat, L["ClassBuffReminderDesc"] or "Shows how many group members are missing the class buff your class can provide.", {
	parentSection = expandable,
})

addon.functions.SettingsCreateText(cat, "|cffffd700" .. (L["ClassBuffReminderEditModeHint"] or "Use Edit Mode to position the reminder.") .. "|r", {
	parentSection = expandable,
})

addon.functions.SettingsCreateCheckbox(cat, {
	var = DB_ENABLED,
	text = L["ClassBuffReminderEnable"] or "Enable class buff reminder",
	func = function(value)
		addon.db[DB_ENABLED] = value == true
		refreshReminder()
	end,
	parentSection = expandable,
})

function addon.functions.initClassBuffReminder()
	if not addon.functions or not addon.functions.InitDBValue then return end
	local init = addon.functions.InitDBValue

	init(DB_ENABLED, defaults.enabled)
	init(DB_SHOW_PARTY, defaults.showParty)
	init(DB_SHOW_RAID, defaults.showRaid)
	init(DB_SHOW_SOLO, defaults.showSolo)
	init(DB_GLOW, defaults.glow)
	init(DB_GLOW_STYLE, defaults.glowStyle)
	init(DB_GLOW_INSET, defaults.glowInset)
	init(DB_SOUND_ON_MISSING, defaults.soundOnMissing)
	init(DB_MISSING_SOUND, defaults.missingSound)
	init(DB_DISPLAY_MODE, defaults.displayMode)
	init(DB_GROWTH_DIRECTION, defaults.growthDirection)
	init(DB_GROWTH_FROM_CENTER, defaults.growthFromCenter)
	init(DB_TRACK_FLASKS, defaults.trackFlasks)
	init(DB_TRACK_FLASKS_INSTANCE_ONLY, defaults.trackFlasksInstanceOnly)
	init(DB_SCALE, defaults.scale)
	init(DB_ICON_SIZE, defaults.iconSize)
	init(DB_FONT_SIZE, defaults.fontSize)
	init(DB_ICON_GAP, defaults.iconGap)
	init(DB_XY_TEXT_SIZE, defaults.xyTextSize)
	init(DB_XY_TEXT_OUTLINE, defaults.xyTextOutline)
	init(DB_XY_TEXT_COLOR, defaults.xyTextColor)
	init(DB_XY_TEXT_OFFSET_X, defaults.xyTextOffsetX)
	init(DB_XY_TEXT_OFFSET_Y, defaults.xyTextOffsetY)
	if addon.db then addon.db[LEGACY_DB_SOUND_DEBUG_TRACE] = nil end
	if addon.db then addon.db[LEGACY_DB_SHOW_ICON] = nil end
	if addon.db then addon.db[LEGACY_DB_ONLY_WHEN_MISSING] = nil end

	refreshReminder()
end
