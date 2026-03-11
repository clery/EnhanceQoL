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

local glowStyleValues = {
	BLIZZARD = L["ClassBuffReminderGlowStyleBlizzard"] or "Blizzard",
	MARCHING_ANTS = L["ClassBuffReminderGlowStyleMarchingAnts"] or "Marching ants",
	FLASH = L["ClassBuffReminderGlowStyleFlash"] or "Flash",
}
local glowStyleOrder = { "BLIZZARD", "MARCHING_ANTS", "FLASH" }

local function normalizeGlowStyle(value)
	if Reminder and Reminder.NormalizeGlowStyle then return Reminder.NormalizeGlowStyle(value) end
	local normalized = type(value) == "string" and string.upper(value) or nil
	if normalized == "BLIZZARD" or normalized == "CLASSIC" or normalized == "BUTTON_GLOW" then return "BLIZZARD" end
	if normalized == "MARCHING_ANTS" or normalized == "MARCHINGANTS" or normalized == "ANTS" then return "MARCHING_ANTS" end
	if normalized == "FLASH" then return "FLASH" end
	return "MARCHING_ANTS"
end

local function normalizeGlowInset(value)
	if Reminder and Reminder.NormalizeGlowInset then return Reminder.NormalizeGlowInset(value) end
	local n = tonumber(value)
	if n == nil then n = defaults.glowInset or 0 end
	local range = Reminder and Reminder.GLOW_INSET_RANGE or 20
	if n < -range then n = -range end
	if n > range then n = range end
	if n < 0 then return math.ceil(n - 0.5) end
	return math.floor(n + 0.5)
end

local function openFlaskSettings()
	if addon.functions and addon.functions.OpenFlaskMacroSettings then
		addon.functions.OpenFlaskMacroSettings()
		return
	end

	if not (Settings and Settings.OpenToCategory) then return end
	local gameplayCategory = addon.SettingsLayout and addon.SettingsLayout.rootGAMEPLAY
	if not gameplayCategory then return end

	if InCombatLockdown and InCombatLockdown() then
		if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0, 0) end
		return
	end

	Settings.OpenToCategory(gameplayCategory:GetID(), "Flask Macro")
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

addon.functions.SettingsCreateCheckbox(cat, {
	var = DB_GLOW,
	text = L["ClassBuffReminderGlow"] or "Glow when missing",
	func = function(value)
		addon.db[DB_GLOW] = value == true
		refreshReminder()
	end,
	parentSection = expandable,
})

addon.functions.SettingsCreateDropdown(cat, {
	var = DB_GLOW_STYLE,
	text = L["ClassBuffReminderGlowStyle"] or "Glow style",
	default = defaults.glowStyle,
	list = glowStyleValues,
	order = glowStyleOrder,
	get = function() return normalizeGlowStyle(addon.db and addon.db[DB_GLOW_STYLE] or defaults.glowStyle) end,
	set = function(_, value)
		addon.db[DB_GLOW_STYLE] = normalizeGlowStyle(value)
		refreshReminder()
	end,
	parentSection = expandable,
	parentCheck = function() return addon.db and addon.db[DB_GLOW] == true end,
})

addon.functions.SettingsCreateSlider(cat, {
	var = DB_GLOW_INSET,
	text = L["ClassBuffReminderGlowInset"] or "Glow inset",
	default = defaults.glowInset,
	min = -(Reminder and Reminder.GLOW_INSET_RANGE or 20),
	max = Reminder and Reminder.GLOW_INSET_RANGE or 20,
	step = 1,
	get = function() return normalizeGlowInset(addon.db and addon.db[DB_GLOW_INSET] or defaults.glowInset) end,
	set = function(_, value)
		addon.db[DB_GLOW_INSET] = normalizeGlowInset(value)
		refreshReminder()
	end,
	formatter = function(value) return tostring(math.floor((tonumber(value) or defaults.glowInset or 0) + 0.5)) end,
	parentSection = expandable,
	parentCheck = function() return addon.db and addon.db[DB_GLOW] == true end,
})

addon.functions.SettingsCreateCheckbox(cat, {
	var = DB_TRACK_FLASKS,
	text = L["ClassBuffReminderTrackFlasks"] or "Track missing flask buff",
	desc = L["ClassBuffReminderTrackFlasksDesc"] or "Shows a flask reminder only when a matching flask is available in your bags.",
	func = function(value)
		addon.db[DB_TRACK_FLASKS] = value == true
		refreshReminder()
	end,
	parentSection = expandable,
})

addon.functions.SettingsCreateCheckbox(cat, {
	var = DB_TRACK_FLASKS_INSTANCE_ONLY,
	text = L["ClassBuffReminderTrackFlasksInstanceOnly"] or "Only in dungeons/raids",
	desc = L["ClassBuffReminderTrackFlasksInstanceOnlyDesc"] or "Limits flask reminder checks to dungeon and raid instances.",
	func = function(value)
		addon.db[DB_TRACK_FLASKS_INSTANCE_ONLY] = value == true
		refreshReminder()
	end,
	parentSection = expandable,
})

addon.functions.SettingsCreateText(cat, L["ClassBuffReminderFlaskSharedHint"] or "Flask preferences are shared with Flask Macro (Gameplay -> Macros & Consumables).", {
	parentSection = expandable,
})

addon.functions.SettingsCreateButton(cat, {
	var = "classBuffReminderOpenFlaskSettings",
	text = L["ClassBuffReminderOpenFlaskSettings"] or "Open Flask settings",
	desc = L["ClassBuffReminderOpenFlaskSettingsDesc"] or "Jumps to Gameplay -> Macros & Consumables and focuses Flask Macro settings.",
	func = openFlaskSettings,
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

	refreshReminder()
end
