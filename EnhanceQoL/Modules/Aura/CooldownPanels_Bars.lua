local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Aura = addon.Aura or {}
addon.Aura.CooldownPanels = addon.Aura.CooldownPanels or {}
local CooldownPanels = addon.Aura.CooldownPanels
local Helper = CooldownPanels.helper or {}
local Api = Helper.Api or {}
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")
local LSM = LibStub("LibSharedMedia-3.0", true)

CooldownPanels.Bars = CooldownPanels.Bars or {}
local Bars = CooldownPanels.Bars
if Bars._eqolSupplementLoaded == true then return end
Bars._eqolSupplementLoaded = true

local CreateFrame = CreateFrame
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local tonumber = tonumber
local tostring = tostring
local type = type
local ipairs = ipairs
local pairs = pairs
local format = string.format
local CooldownFrame_Clear = CooldownFrame_Clear
local floor = math.floor
local min = math.min
local max = math.max
local next = next
local strfind = string.find
local unpack = table.unpack or unpack
local wipe = table.wipe or function(tbl)
	for key in pairs(tbl) do
		tbl[key] = nil
	end
end

Bars.DISPLAY_MODE = Bars.DISPLAY_MODE or {
	BUTTON = "BUTTON",
	BAR = "BAR",
}

Bars.BAR_MODE = Bars.BAR_MODE or {
	COOLDOWN = "COOLDOWN",
	CHARGES = "CHARGES",
	STACKS = "STACKS",
}

Bars.DEFAULTS = Bars.DEFAULTS or {
	displayMode = Bars.DISPLAY_MODE.BUTTON,
	barMode = Bars.BAR_MODE.COOLDOWN,
	barSpan = 2,
	barWidth = 0,
	barHeight = 26,
	barTexture = "SOLID",
	barColor = { 0.98, 0.74, 0.22, 0.96 },
	barBackgroundColor = { 0.05, 0.05, 0.05, 0.82 },
	barBorderColor = { 0.85, 0.85, 0.85, 0.90 },
	barBorderTexture = "DEFAULT",
	barBorderOffset = 0,
	barBorderSize = 1,
	barOffsetX = 0,
	barOffsetY = 0,
	barOrientation = "HORIZONTAL",
	barSegmentDirection = "HORIZONTAL",
	barSegmentReverse = false,
	barProcGlowColor = { 0.35, 0.75, 1.00, 0.95 },
	barShowIcon = true,
	barShowLabel = true,
	barShowValueText = true,
	barIconSize = 0,
	barIconPosition = "LEFT",
	barIconOffsetX = 0,
	barIconOffsetY = 0,
	barChargesSegmented = false,
	barChargesGap = 2,
	barLabelFont = "",
	barLabelSize = 11,
	barLabelStyle = "OUTLINE",
	barLabelColor = { 1.00, 1.00, 1.00, 0.95 },
	barValueFont = "",
	barValueSize = 11,
	barValueStyle = "OUTLINE",
	barValueColor = { 1.00, 0.95, 0.75, 0.95 },
}

Bars.COLORS = Bars.COLORS or {
	COOLDOWN = { 0.98, 0.74, 0.22, 0.96 },
	CHARGES = { 0.24, 0.64, 1.00, 0.96 },
	STACKS = { 0.30, 0.88, 0.46, 0.96 },
	Background = { 0.05, 0.05, 0.05, 0.82 },
	Border = { 0.85, 0.85, 0.85, 0.90 },
	Label = { 1.00, 1.00, 1.00, 0.95 },
	Value = { 1.00, 0.95, 0.75, 0.95 },
	Reserved = { 0.95, 0.82, 0.25, 0.80 },
}

local BAR_TEXTURE_DEFAULT = "DEFAULT"
local BAR_BORDER_TEXTURE_DEFAULT = "DEFAULT"
local BAR_HEIGHT_MIN = 5
local BAR_HEIGHT_MAX = 2000
local BAR_WIDTH_MIN = 5
local BAR_WIDTH_MAX = 2000
local BAR_BORDER_SIZE_MIN = 0
local BAR_BORDER_SIZE_MAX = 64
local BAR_BORDER_OFFSET_MIN = -64
local BAR_BORDER_OFFSET_MAX = 64
local BAR_OFFSET_MIN = -2000
local BAR_OFFSET_MAX = 2000
local BAR_ICON_SIZE_MIN = 8
local BAR_ICON_SIZE_MAX = 128
local BAR_ICON_POSITION_LEFT = "LEFT"
local BAR_ICON_POSITION_RIGHT = "RIGHT"
local BAR_ICON_POSITION_TOP = "TOP"
local BAR_ICON_POSITION_BOTTOM = "BOTTOM"
local BAR_ORIENTATION_HORIZONTAL = "HORIZONTAL"
local BAR_ORIENTATION_VERTICAL = "VERTICAL"
local BAR_CHARGES_GAP_MIN = 0
local BAR_CHARGES_GAP_MAX = 2000
local BAR_FONT_SIZE_MIN = 6
local BAR_FONT_SIZE_MAX = 64
local BAR_TEXTURE_MENU_HEIGHT = 220
local BAR_STATUS_INTERPOLATION_IMMEDIATE = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
local BAR_STATUS_TIMER_DIRECTION_ELAPSED = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0
local getBarColor
local normalizeBarEntry
local refreshPanelContext
local refreshStandaloneEntryDialogForBars
local inferChargeBaseCount
local getDisplayedCharges
local getChargeBarProgress
local getChargeBarValueText
local sweepChargeDurationObjects
local setStatusBarImmediateValue
local setStatusBarTimerDuration
local getChargeSegmentDescriptors
local setBooleanAlpha
local shouldShowChargeSegmentFill
local refreshChargeBarRuntimeState

local function getSettingType()
	local lib = addon.EditModeLib or (addon.EditMode and addon.EditMode.lib)
	return lib and lib.SettingType or nil
end

local function normalizeId(value) return tonumber(value) end
local function isSecretValue(value) return Api.issecretvalue and Api.issecretvalue(value) end
local function hasTextValue(value)
	if type(value) ~= "string" then return false end
	if isSecretValue(value) then return true end
	return value ~= ""
end

local function getTextValue(value)
	if type(value) ~= "string" then return nil end
	if isSecretValue(value) then return value end
	if value ~= "" then return value end
	return nil
end

local function safeNumber(value)
	if type(value) == "number" and not isSecretValue(value) then return value end
	if type(value) == "string" then
		if isSecretValue(value) then return nil end
		if value == "" then return nil end
		local numeric = tonumber(value)
		if numeric then return numeric end
	end
	return nil
end

local function getDebugText(value)
	if type(value) ~= "string" then return nil end
	if isSecretValue(value) then return "<secret:string>" end
	return value
end

local function getBarsDebugStore()
	local root = nil
	if CooldownPanels.GetRoot then
		root = CooldownPanels:GetRoot()
	elseif CooldownPanels.EnsureDB then
		root = CooldownPanels:EnsureDB()
	end
	if type(root) ~= "table" then return nil end
	if type(root._eqolBarsDebug) ~= "table" then
		root._eqolBarsDebug = {
			enabled = true,
			maxEntries = 4000,
			nextIndex = 1,
			count = 0,
			seq = 0,
			logs = {},
		}
	end
	local store = root._eqolBarsDebug
	if store.enabled == nil then store.enabled = true end
	if type(store.maxEntries) ~= "number" or store.maxEntries < 100 then store.maxEntries = 4000 end
	if type(store.nextIndex) ~= "number" or store.nextIndex < 1 then store.nextIndex = 1 end
	if type(store.count) ~= "number" or store.count < 0 then store.count = 0 end
	if type(store.seq) ~= "number" or store.seq < 0 then store.seq = 0 end
	if type(store.logs) ~= "table" then store.logs = {} end
	return store
end

local function getDebugValue(value)
	if value == nil then return nil end
	if isSecretValue(value) then return "<secret:" .. type(value) .. ">" end
	local valueType = type(value)
	if valueType == "boolean" or valueType == "number" or valueType == "string" then return value end
	return "<" .. valueType .. ">"
end

local function writeBarsDebug(stage, payload)
	local store = getBarsDebugStore()
	if not (store and store.enabled == true) then return end
	local entry = {
		seq = (store.seq or 0) + 1,
		t = (Api.GetTime and Api.GetTime()) or GetTime() or 0,
		stage = tostring(stage or "?"),
		combat = InCombatLockdown and InCombatLockdown() == true or false,
	}
	store.seq = entry.seq
	if type(payload) == "table" then
		for key, value in pairs(payload) do
			entry[key] = getDebugValue(value)
		end
	end
	local index = store.nextIndex or 1
	store.logs[index] = entry
	index = index + 1
	if index > store.maxEntries then index = 1 end
	store.nextIndex = index
	store.count = min((store.count or 0) + 1, store.maxEntries)
end

local function isSafeLessThan(a, b)
	local lhs = safeNumber(a)
	local rhs = safeNumber(b)
	if not (lhs and rhs) then return false end
	return lhs < rhs
end

local function isLikelyFilePath(value)
	if not hasTextValue(value) or isSecretValue(value) then return false end
	return strfind(value, "[/\\]") ~= nil
end

local function clamp(value, minimum, maximum)
	if value < minimum then return minimum end
	if value > maximum then return maximum end
	return value
end

local function getStoredBoolean(entry, field, fallback)
	if type(entry) == "table" and type(entry[field]) == "boolean" then return entry[field] == true end
	return fallback == true
end

local function getCellKey(column, row) return tostring(column) .. ":" .. tostring(row) end

local function pixelSnap(value, effectiveScale)
	local _, screenHeight = GetPhysicalScreenSize()
	local scale = effectiveScale or (UIParent and UIParent.GetScale and UIParent:GetScale()) or 1
	if screenHeight and screenHeight > 0 and scale and scale > 0 then
		local pixelMultiplier = (768 / screenHeight) / scale
		return floor((value / pixelMultiplier) + 0.5) * pixelMultiplier
	end
	return floor(value + 0.5)
end

local function durationToText(value)
	local seconds = safeNumber(value)
	if not seconds then return nil end
	if seconds < 0 then seconds = 0 end
	if seconds < 10 then
		return format("%.1f", seconds)
	end
	return format("%.0f", seconds)
end

local function getCooldownText(icon)
	local cooldown = icon and icon.cooldown or nil
	if not (cooldown and cooldown.GetCountdownFontString) then return nil end
	local fontString = cooldown:GetCountdownFontString()
	if not fontString or not fontString.GetText then return nil end
	local text = fontString:GetText()
	return getTextValue(text)
end

local function getDefaultBarColorForMode(mode)
	local r, g, b, a = getBarColor(mode)
	return { r, g, b, a }
end

local function normalizeBarTexture(value, fallback)
	local texture = getTextValue(value)
	if texture then return texture end
	texture = getTextValue(fallback)
	if texture then return texture end
	return BAR_TEXTURE_DEFAULT
end

local function normalizeBarBorderTexture(value, fallback)
	local texture = getTextValue(value)
	if texture then return texture end
	texture = getTextValue(fallback)
	if texture then return texture end
	return BAR_BORDER_TEXTURE_DEFAULT
end

local function normalizeBarHeight(value, fallback)
	return Helper.ClampInt(value, BAR_HEIGHT_MIN, BAR_HEIGHT_MAX, fallback or Bars.DEFAULTS.barHeight)
end

local function normalizeBarWidth(value, fallback)
	return Helper.ClampInt(value, 0, BAR_WIDTH_MAX, fallback or Bars.DEFAULTS.barWidth)
end

local function normalizeBarBorderSize(value, fallback)
	return Helper.ClampInt(value, BAR_BORDER_SIZE_MIN, BAR_BORDER_SIZE_MAX, fallback or Bars.DEFAULTS.barBorderSize)
end

local function normalizeBarBorderOffset(value, fallback)
	return Helper.ClampInt(value, BAR_BORDER_OFFSET_MIN, BAR_BORDER_OFFSET_MAX, fallback or 0)
end

local function normalizeBarOffset(value, fallback)
	return Helper.ClampInt(value, BAR_OFFSET_MIN, BAR_OFFSET_MAX, fallback or 0)
end

local function normalizeBarOrientation(value, fallback)
	local orientation = type(value) == "string" and string.upper(value) or nil
	if orientation == BAR_ORIENTATION_VERTICAL then return BAR_ORIENTATION_VERTICAL end
	if orientation == BAR_ORIENTATION_HORIZONTAL then return BAR_ORIENTATION_HORIZONTAL end
	return fallback or Bars.DEFAULTS.barOrientation
end

local function normalizeBarSegmentDirection(value, fallback)
	local direction = type(value) == "string" and string.upper(value) or nil
	if direction == BAR_ORIENTATION_VERTICAL then return BAR_ORIENTATION_VERTICAL end
	if direction == BAR_ORIENTATION_HORIZONTAL then return BAR_ORIENTATION_HORIZONTAL end
	return fallback or Bars.DEFAULTS.barSegmentDirection
end

local function normalizeBarIconPosition(value, fallback)
	local position = type(value) == "string" and string.upper(value) or nil
	if position == BAR_ICON_POSITION_TOP then return BAR_ICON_POSITION_TOP end
	if position == BAR_ICON_POSITION_BOTTOM then return BAR_ICON_POSITION_BOTTOM end
	if position == BAR_ICON_POSITION_RIGHT then return BAR_ICON_POSITION_RIGHT end
	if position == BAR_ICON_POSITION_LEFT then return BAR_ICON_POSITION_LEFT end
	return fallback or Bars.DEFAULTS.barIconPosition
end

local function normalizeBarIconSize(value, fallback)
	return Helper.ClampInt(value, 0, BAR_ICON_SIZE_MAX, fallback or 0)
end

local function normalizeBarIconOffset(value, fallback)
	local range = Helper.OFFSET_RANGE or 500
	return Helper.ClampInt(value, -range, range, fallback or 0)
end

local function normalizeBarChargesGap(value, fallback)
	return Helper.ClampInt(value, BAR_CHARGES_GAP_MIN, BAR_CHARGES_GAP_MAX, fallback or Bars.DEFAULTS.barChargesGap)
end

local function normalizeBarFont(value, fallback)
	if type(value) == "string" then return value end
	if type(fallback) == "string" then return fallback end
	return ""
end

local function normalizeBarFontSize(value, fallback)
	return Helper.ClampInt(value, BAR_FONT_SIZE_MIN, BAR_FONT_SIZE_MAX, fallback or 11)
end

local function normalizeBarFontStyle(value, fallback)
	return Helper.NormalizeFontStyleChoice(value, fallback or "OUTLINE")
end

local function resolveBarTexture(value)
	local texture = normalizeBarTexture(value, BAR_TEXTURE_DEFAULT)
	if texture == "SOLID" then return "Interface\\Buttons\\WHITE8x8" end
	if texture == BAR_TEXTURE_DEFAULT then return "Interface\\TargetingFrame\\UI-StatusBar" end
	if LSM and LSM.Fetch then
		local fetched = LSM:Fetch("statusbar", texture, true)
		if hasTextValue(fetched) then return fetched end
	end
	if isLikelyFilePath(texture) then return texture end
	return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function resolveBarBorderTexture(value)
	local key = normalizeBarBorderTexture(value, BAR_BORDER_TEXTURE_DEFAULT)
	local ufHelper = addon.Aura and addon.Aura.UFHelper
	if ufHelper and ufHelper.resolveBorderTexture then return ufHelper.resolveBorderTexture(key) end
	if not hasTextValue(key) or isSecretValue(key) or key == BAR_BORDER_TEXTURE_DEFAULT then return "Interface\\Buttons\\WHITE8x8" end
	if LSM and LSM.Fetch then
		local fetched = LSM:Fetch("border", key, true)
		if hasTextValue(fetched) then return fetched end
	end
	if isLikelyFilePath(key) then return key end
	return "Interface\\Buttons\\WHITE8x8"
end

local function getBarTextureOptions()
	local list = {}
	local seen = {}
	local function add(value, label)
		local key = tostring(value or ""):lower()
		if key == "" or seen[key] then return end
		seen[key] = true
		list[#list + 1] = {
			value = value,
			label = label or value,
		}
	end
	add(BAR_TEXTURE_DEFAULT, _G.DEFAULT or "Default")
	add("SOLID", "Solid")
	local names = addon.functions and addon.functions.GetLSMMediaNames and addon.functions.GetLSMMediaNames("statusbar") or {}
	local hash = addon.functions and addon.functions.GetLSMMediaHash and addon.functions.GetLSMMediaHash("statusbar") or {}
	for index = 1, #names do
		local name = names[index]
		local path = hash[name]
		if hasTextValue(path) then add(name, tostring(name)) end
	end
	return list
end

local function getBarBorderTextureOptions()
	local list = {}
	local seen = {}
	local function add(value, label)
		local key = tostring(value or ""):lower()
		if key == "" or seen[key] then return end
		seen[key] = true
		list[#list + 1] = {
			value = value,
			label = label or value,
		}
	end
	add(BAR_BORDER_TEXTURE_DEFAULT, _G.DEFAULT or "Default")
	local names = addon.functions and addon.functions.GetLSMMediaNames and addon.functions.GetLSMMediaNames("border") or {}
	local hash = addon.functions and addon.functions.GetLSMMediaHash and addon.functions.GetLSMMediaHash("border") or {}
	for index = 1, #names do
		local name = names[index]
		local path = hash[name]
		if hasTextValue(path) then add(name, tostring(name)) end
	end
	return list
end

local function getBarEntry(panelId, entryId)
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	local panel = CooldownPanels.GetPanel and CooldownPanels:GetPanel(panelId) or nil
	local entry = panel and panel.entries and panel.entries[entryId] or nil
	return panel, entry
end

local function mutateBarEntry(panelId, entryId, mutator, reopenDialog)
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	local panel, entry = getBarEntry(panelId, entryId)
	if not (panel and entry) then return nil, nil end
	if type(mutator) == "function" then mutator(entry, panel) end
	normalizeBarEntry(entry)
	refreshPanelContext(panelId)
	refreshStandaloneEntryDialogForBars(panelId, entryId, reopenDialog == true)
	return panel, entry
end

local function getBarModeColor(entry, mode)
	return Helper.NormalizeColor(entry and entry.barColor, getDefaultBarColorForMode(mode))
end

local function getBarTextureSelection(entry)
	local texture = entry and entry.barTexture or nil
	return normalizeBarTexture(texture, Bars.DEFAULTS.barTexture)
end

local function getEntryBarModeLabel(mode)
	if mode == Bars.BAR_MODE.CHARGES then return L["CooldownPanelBarModeCharges"] or "Charges" end
	if mode == Bars.BAR_MODE.STACKS then return L["CooldownPanelBarModeStacks"] or "Stacks" end
	return L["CooldownPanelBarModeCooldown"] or "Cooldown"
end

local function normalizeDisplayMode(value, fallback)
	local mode = type(value) == "string" and string.upper(value) or nil
	if mode == Bars.DISPLAY_MODE.BAR then return Bars.DISPLAY_MODE.BAR end
	if mode == Bars.DISPLAY_MODE.BUTTON then return Bars.DISPLAY_MODE.BUTTON end
	return fallback or Bars.DEFAULTS.displayMode
end

local function normalizeBarMode(value, fallback)
	local mode = type(value) == "string" and string.upper(value) or nil
	if mode == Bars.BAR_MODE.CHARGES then return Bars.BAR_MODE.CHARGES end
	if mode == Bars.BAR_MODE.STACKS then return Bars.BAR_MODE.STACKS end
	if mode == Bars.BAR_MODE.COOLDOWN then return Bars.BAR_MODE.COOLDOWN end
	return fallback or Bars.DEFAULTS.barMode
end

local function normalizeBarSpan(value, fallback)
	local span = tonumber(value)
	return clamp(floor((span or fallback or Bars.DEFAULTS.barSpan) + 0.5), 1, 4)
end

local function getRuntimeState()
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	CooldownPanels.runtime.cooldownPanelBars = CooldownPanels.runtime.cooldownPanelBars or {
		activeBars = setmetatable({}, { __mode = "k" }),
		stackMaxByEntryKey = {},
		chargeMaxByEntryKey = {},
		chargeLastNonGCDCooldownActiveByEntryKey = {},
		chargeLastNonGCDCooldownDurationByEntryKey = {},
	}
	return CooldownPanels.runtime.cooldownPanelBars
end

local function getEntryResolvedType(entry)
	if not entry then return nil, nil end
	local resolvedType = entry.type
	local macro = nil
	if resolvedType == "MACRO" and CooldownPanels.ResolveMacroEntry then
		macro = CooldownPanels.ResolveMacroEntry(entry)
		resolvedType = macro and macro.kind or resolvedType
	end
	return resolvedType, macro
end

local function supportsBarMode(entry, mode)
	if not entry then return false end
	local resolvedType = getEntryResolvedType(entry)
	if mode == Bars.BAR_MODE.CHARGES or mode == Bars.BAR_MODE.STACKS then
		return entry.type == "SPELL"
	end
	return resolvedType == "SPELL" or resolvedType == "ITEM" or entry.type == "MACRO" or resolvedType == "CDM_AURA"
end

local function isBarProcGlowActive(resolvedType, spellId)
	if resolvedType ~= "SPELL" or not spellId then return false end
	local runtime = CooldownPanels.runtime
	local overlayGlowSpells = runtime and runtime.overlayGlowSpells or nil
	return overlayGlowSpells and overlayGlowSpells[spellId] == true or false
end

normalizeBarEntry = function(entry)
	if type(entry) ~= "table" then return end
	entry.displayMode = normalizeDisplayMode(entry.displayMode, Bars.DEFAULTS.displayMode)
	entry.barMode = normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode)
	entry.barSpan = normalizeBarSpan(entry.barSpan, Bars.DEFAULTS.barSpan)
	entry.barWidth = normalizeBarWidth(entry.barWidth, Bars.DEFAULTS.barWidth)
	entry.barHeight = normalizeBarHeight(entry.barHeight, Bars.DEFAULTS.barHeight)
	entry.barTexture = normalizeBarTexture(entry.barTexture, Bars.DEFAULTS.barTexture)
	entry.barColor = Helper.NormalizeColor(entry.barColor, getDefaultBarColorForMode(entry.barMode))
	entry.barBackgroundColor = Helper.NormalizeColor(entry.barBackgroundColor, Bars.DEFAULTS.barBackgroundColor)
	entry.barBorderColor = Helper.NormalizeColor(entry.barBorderColor, Bars.DEFAULTS.barBorderColor)
	entry.barBorderTexture = normalizeBarBorderTexture(entry.barBorderTexture, Bars.DEFAULTS.barBorderTexture)
	entry.barBorderOffset = normalizeBarBorderOffset(entry.barBorderOffset, Bars.DEFAULTS.barBorderOffset)
	entry.barBorderSize = normalizeBarBorderSize(entry.barBorderSize, Bars.DEFAULTS.barBorderSize)
	entry.barOffsetX = normalizeBarOffset(entry.barOffsetX, Bars.DEFAULTS.barOffsetX)
	entry.barOffsetY = normalizeBarOffset(entry.barOffsetY, Bars.DEFAULTS.barOffsetY)
	entry.barOrientation = normalizeBarOrientation(entry.barOrientation, Bars.DEFAULTS.barOrientation)
	entry.barSegmentDirection = normalizeBarSegmentDirection(entry.barSegmentDirection, Bars.DEFAULTS.barSegmentDirection)
	entry.barSegmentReverse = getStoredBoolean(entry, "barSegmentReverse", Bars.DEFAULTS.barSegmentReverse)
	entry.barProcGlowColor = Helper.NormalizeColor(entry.barProcGlowColor, Bars.DEFAULTS.barProcGlowColor)
	entry.barShowIcon = getStoredBoolean(entry, "barShowIcon", Bars.DEFAULTS.barShowIcon)
	entry.barShowLabel = getStoredBoolean(entry, "barShowLabel", Bars.DEFAULTS.barShowLabel)
	entry.barShowValueText = getStoredBoolean(entry, "barShowValueText", Bars.DEFAULTS.barShowValueText)
	entry.barIconSize = normalizeBarIconSize(entry.barIconSize, Bars.DEFAULTS.barIconSize)
	entry.barIconPosition = normalizeBarIconPosition(entry.barIconPosition, Bars.DEFAULTS.barIconPosition)
	entry.barIconOffsetX = normalizeBarIconOffset(entry.barIconOffsetX, Bars.DEFAULTS.barIconOffsetX)
	entry.barIconOffsetY = normalizeBarIconOffset(entry.barIconOffsetY, Bars.DEFAULTS.barIconOffsetY)
	entry.barChargesSegmented = getStoredBoolean(entry, "barChargesSegmented", Bars.DEFAULTS.barChargesSegmented)
	entry.barChargesGap = normalizeBarChargesGap(entry.barChargesGap, Bars.DEFAULTS.barChargesGap)
	entry.barLabelFont = normalizeBarFont(entry.barLabelFont, Bars.DEFAULTS.barLabelFont)
	entry.barLabelSize = normalizeBarFontSize(entry.barLabelSize, Bars.DEFAULTS.barLabelSize)
	entry.barLabelStyle = normalizeBarFontStyle(entry.barLabelStyle, Bars.DEFAULTS.barLabelStyle)
	entry.barLabelColor = Helper.NormalizeColor(entry.barLabelColor, Bars.DEFAULTS.barLabelColor)
	entry.barValueFont = normalizeBarFont(entry.barValueFont, Bars.DEFAULTS.barValueFont)
	entry.barValueSize = normalizeBarFontSize(entry.barValueSize, Bars.DEFAULTS.barValueSize)
	entry.barValueStyle = normalizeBarFontStyle(entry.barValueStyle, Bars.DEFAULTS.barValueStyle)
	entry.barValueColor = Helper.NormalizeColor(entry.barValueColor, Bars.DEFAULTS.barValueColor)
	if entry.displayMode == Bars.DISPLAY_MODE.BAR and not supportsBarMode(entry, entry.barMode) then
		entry.barMode = Bars.BAR_MODE.COOLDOWN
		if not supportsBarMode(entry, entry.barMode) then entry.displayMode = Bars.DISPLAY_MODE.BUTTON end
	end
end

local function getEntryLabel(entry)
	if not entry then return nil end
	local resolvedType, macro = getEntryResolvedType(entry)
	if resolvedType == "SPELL" then
		local spellId = tonumber((macro and macro.spellID) or entry.spellID)
		if spellId and Api.GetSpellInfoFn then
			local name = Api.GetSpellInfoFn(spellId)
			if hasTextValue(name) then return name end
		end
	elseif resolvedType == "ITEM" then
		local itemId = tonumber((macro and macro.itemID) or entry.itemID)
		if itemId then
			if C_Item and C_Item.GetItemNameByID then
				local name = C_Item.GetItemNameByID(itemId)
				if hasTextValue(name) then return name end
			end
			if GetItemInfo then
				local name = GetItemInfo(itemId)
				if hasTextValue(name) then return name end
			end
		end
	elseif resolvedType == "CDM_AURA" and CooldownPanels.CDMAuras and CooldownPanels.CDMAuras.GetEntryName then
		return CooldownPanels.CDMAuras:GetEntryName(entry)
	elseif entry.type == "MACRO" then
		if Api.GetMacroInfo then
			local macroId = tonumber(entry.macroID)
			if macroId then
				local name = Api.GetMacroInfo(macroId)
				if hasTextValue(name) then return name end
			end
		end
		if hasTextValue(entry.macroName) then return entry.macroName end
	end
	if CooldownPanels.GetEntryStandaloneTitle then return CooldownPanels:GetEntryStandaloneTitle(entry) end
	return nil
end

local function getSlotIndexByEntryId(cache)
	local map = cache and cache._eqolBarsSlotIndexByEntryId or nil
	if map then return map end
	map = {}
	if cache and type(cache.slotEntryIds) == "table" then
		for slotIndex = 1, cache.slotCount or #cache.slotEntryIds do
			local entryId = cache.slotEntryIds[slotIndex]
			if entryId ~= nil and map[entryId] == nil then map[entryId] = slotIndex end
		end
	end
	cache._eqolBarsSlotIndexByEntryId = map
	return map
end

local function getAnchorCellFromCache(cache, entryId, entry)
	if not (cache and entryId and entry) then return nil end
	local column = Helper.NormalizeSlotCoordinate(entry.slotColumn)
	local row = Helper.NormalizeSlotCoordinate(entry.slotRow)
	if column and row then return column, row end
	local slotIndex = getSlotIndexByEntryId(cache)[entryId]
	local columns = cache.boundsColumns or 0
	if slotIndex and columns > 0 then
		return ((slotIndex - 1) % columns) + 1, floor((slotIndex - 1) / columns) + 1
	end
	return nil
end

local function getEntryBaseSlotSize(panel, entry)
	local layout = panel and panel.layout or nil
	local layoutSize = Helper.ClampInt(layout and layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.iconSize or 36)
	if entry and entry.iconSizeUseGlobal == false then return Helper.ClampInt(entry.iconSize, 12, 128, layoutSize) end
	return layoutSize
end

local function getDesiredBarSpan(panel, entry)
	if not entry then return 1 end
	local configuredWidth = normalizeBarWidth(entry.barWidth, Bars.DEFAULTS.barWidth)
	local configuredSpan = normalizeBarSpan(entry.barSpan, Bars.DEFAULTS.barSpan)
	local offsetX = normalizeBarOffset(entry.barOffsetX, Bars.DEFAULTS.barOffsetX)
	local slotSize = getEntryBaseSlotSize(panel, entry)
	local spacing = Helper.ClampInt(panel and panel.layout and panel.layout.spacing, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.spacing or 2)
	local cellWidth = max(1, slotSize + spacing)
	local bodyWidth = configuredWidth and configuredWidth > 0 and configuredWidth or max(slotSize, (slotSize * configuredSpan) + (max(configuredSpan - 1, 0) * spacing))
	if normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode) == Bars.BAR_MODE.CHARGES and getStoredBoolean(entry, "barChargesSegmented", Bars.DEFAULTS.barChargesSegmented) then
		if normalizeBarSegmentDirection(entry.barSegmentDirection, Bars.DEFAULTS.barSegmentDirection) == BAR_ORIENTATION_HORIZONTAL then
			bodyWidth = (bodyWidth * 2) + normalizeBarChargesGap(entry.barChargesGap, Bars.DEFAULTS.barChargesGap)
		end
	end
	local rightExtent = max(slotSize, max(0, offsetX) + bodyWidth)
	return max(1, floor((rightExtent + cellWidth - 1) / cellWidth))
end

local function getHorizontalSegmentReservationColumns(panel, entry, anchorColumn, maxEndColumn)
	if not (panel and entry and anchorColumn and maxEndColumn) then return nil, nil end
	local mode = normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode)
	local configuredWidth = normalizeBarWidth(entry.barWidth, Bars.DEFAULTS.barWidth)
	local configuredSpan = normalizeBarSpan(entry.barSpan, Bars.DEFAULTS.barSpan)
	local slotSize = getEntryBaseSlotSize(panel, entry)
	local spacing = Helper.ClampInt(panel and panel.layout and panel.layout.spacing, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.spacing or 2)
	local cellWidth = max(1, slotSize + spacing)
	local gap = normalizeBarChargesGap(entry.barChargesGap, Bars.DEFAULTS.barChargesGap)
	local offsetX = normalizeBarOffset(entry.barOffsetX, Bars.DEFAULTS.barOffsetX)
	local segmentedHorizontal = mode == Bars.BAR_MODE.CHARGES and getStoredBoolean(entry, "barChargesSegmented", Bars.DEFAULTS.barChargesSegmented) == true
		and normalizeBarSegmentDirection(entry.barSegmentDirection, Bars.DEFAULTS.barSegmentDirection) == BAR_ORIENTATION_HORIZONTAL
	local bodyWidth = configuredWidth and configuredWidth > 0 and configuredWidth or max(slotSize, (slotSize * configuredSpan) + (max(configuredSpan - 1, 0) * spacing))
	local columns = {}
	local seen = {}

	local function addColumn(column)
		if column and column >= 1 and column <= maxEndColumn and seen[column] ~= true then
			seen[column] = true
			columns[#columns + 1] = column
		end
	end

	local function addPixelRange(startPixel, endPixel)
		local startOffset = floor(startPixel / cellWidth) + 1
		local endOffset = floor(max(startPixel, endPixel - 1) / cellWidth) + 1
		for offset = startOffset, endOffset do
			addColumn(anchorColumn + offset - 1)
		end
	end

	local visualSpan
	if segmentedHorizontal then
		addPixelRange(offsetX, offsetX + bodyWidth)
		addPixelRange(offsetX + bodyWidth + gap, offsetX + (bodyWidth * 2) + gap)
		visualSpan = max(1, floor((max(slotSize, max(0, offsetX) + (bodyWidth * 2) + gap) + cellWidth - 1) / cellWidth))
	else
		addPixelRange(offsetX, offsetX + bodyWidth)
		visualSpan = max(1, floor((max(slotSize, max(0, offsetX) + bodyWidth) + cellWidth - 1) / cellWidth))
	end

	if #columns == 0 then return nil, visualSpan end
	table.sort(columns)
	return columns, visualSpan
end

local function getBaseOccupantAtCell(cache, entry, column, row)
	if not (cache and entry and column and row) then return nil end
	local key = getCellKey(column, row)
	local groupId = Helper.NormalizeFixedGroupId(entry.fixedGroupId)
	if groupId and cache.groupById then
		local group = cache.groupById[groupId]
		if group and CooldownPanels.IsFixedGroupStatic and CooldownPanels:IsFixedGroupStatic(group) then
			local cells = cache.entryAtStaticGroupCell and cache.entryAtStaticGroupCell[group.id] or nil
			return cells and cells[key] or nil
		end
		return nil
	end
	return cache.entryAtUngroupedCell and cache.entryAtUngroupedCell[key] or nil
end

local function getReservationSignature(panel)
	local buffer = {}
	local layout = panel and panel.layout or nil
	buffer[#buffer + 1] = tostring(Helper.ClampInt(layout and layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.iconSize or 36))
	buffer[#buffer + 1] = tostring(Helper.ClampInt(layout and layout.spacing, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.spacing or 2))
	for _, entryId in ipairs(panel and panel.order or {}) do
		local entry = panel.entries and panel.entries[entryId] or nil
		if entry then
			buffer[#buffer + 1] = tostring(entryId)
			buffer[#buffer + 1] = normalizeDisplayMode(entry.displayMode, Bars.DEFAULTS.displayMode)
			buffer[#buffer + 1] = normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode)
			buffer[#buffer + 1] = tostring(normalizeBarSpan(entry.barSpan, Bars.DEFAULTS.barSpan))
			buffer[#buffer + 1] = tostring(normalizeBarWidth(entry.barWidth, Bars.DEFAULTS.barWidth))
			buffer[#buffer + 1] = tostring(normalizeBarOffset(entry.barOffsetX, Bars.DEFAULTS.barOffsetX))
			buffer[#buffer + 1] = tostring(getStoredBoolean(entry, "barChargesSegmented", Bars.DEFAULTS.barChargesSegmented))
			buffer[#buffer + 1] = tostring(normalizeBarChargesGap(entry.barChargesGap, Bars.DEFAULTS.barChargesGap))
			buffer[#buffer + 1] = tostring(normalizeBarSegmentDirection(entry.barSegmentDirection, Bars.DEFAULTS.barSegmentDirection))
			buffer[#buffer + 1] = tostring(Helper.NormalizeFixedGroupId(entry.fixedGroupId) or "")
			buffer[#buffer + 1] = tostring(Helper.NormalizeSlotCoordinate(entry.slotColumn) or "")
			buffer[#buffer + 1] = tostring(Helper.NormalizeSlotCoordinate(entry.slotRow) or "")
		end
	end
	return table.concat(buffer, "|")
end

local function augmentFixedLayoutCache(panel, cache)
	if not (panel and cache and Helper.IsFixedLayout and Helper.IsFixedLayout(panel.layout)) then return cache end
	local signature = getReservationSignature(panel)
	if cache._eqolBarsReservationSignature == signature then return cache end

	local reservedOwnerByCell = cache._eqolBarsReservedOwnerByCell or {}
	local reservedOwnerByIndex = cache._eqolBarsReservedOwnerByIndex or {}
	local effectiveSpanByEntryId = cache._eqolBarsEffectiveSpanByEntryId or {}
	local anchorCellByEntryId = cache._eqolBarsAnchorCellByEntryId or {}

	wipe(reservedOwnerByCell)
	wipe(reservedOwnerByIndex)
	wipe(effectiveSpanByEntryId)
	wipe(anchorCellByEntryId)
	cache._eqolBarsSlotIndexByEntryId = nil
	getSlotIndexByEntryId(cache)

	local boundsColumns = cache.boundsColumns or 0
	for _, entryId in ipairs(panel.order or {}) do
		local entry = panel.entries and panel.entries[entryId] or nil
		if entry and normalizeDisplayMode(entry.displayMode, Bars.DEFAULTS.displayMode) == Bars.DISPLAY_MODE.BAR then
			local mode = normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode)
			if supportsBarMode(entry, mode) then
				local column, row = getAnchorCellFromCache(cache, entryId, entry)
				local effectiveSpan = 1
				if column and row then
					anchorCellByEntryId[entryId] = { column = column, row = row }
					local maxEndColumn = boundsColumns
					local groupId = Helper.NormalizeFixedGroupId(entry.fixedGroupId)
					if groupId and cache.groupById then
						local group = cache.groupById[groupId]
						if group then
							if CooldownPanels.IsFixedGroupStatic and CooldownPanels:IsFixedGroupStatic(group) and row >= group.row and row <= (group.row + group.rows - 1) then
								maxEndColumn = min(maxEndColumn, group.column + group.columns - 1)
							else
								maxEndColumn = column
							end
						end
					end
					local wantedSpan = getDesiredBarSpan(panel, entry)
					local reservedColumns, visualSpan = getHorizontalSegmentReservationColumns(panel, entry, column, maxEndColumn)
					if reservedColumns then
						effectiveSpan = min(maxEndColumn - column + 1, visualSpan or wantedSpan or 1)
						for index = 1, #reservedColumns do
							local reservedColumn = reservedColumns[index]
							if reservedColumn ~= column then
								local occupantId = getBaseOccupantAtCell(cache, entry, reservedColumn, row)
								local reservedKey = getCellKey(reservedColumn, row)
								local reservedOwner = reservedOwnerByCell[reservedKey]
								if not ((occupantId and occupantId ~= entryId) or (reservedOwner and reservedOwner ~= entryId)) then
									reservedOwnerByCell[reservedKey] = entryId
									if boundsColumns > 0 then reservedOwnerByIndex[((row - 1) * boundsColumns) + reservedColumn] = entryId end
								end
							end
						end
					elseif maxEndColumn > column and wantedSpan > 1 then
						for candidateColumn = column + 1, min(maxEndColumn, column + wantedSpan - 1) do
							local occupantId = getBaseOccupantAtCell(cache, entry, candidateColumn, row)
							local reservedKey = getCellKey(candidateColumn, row)
							local reservedOwner = reservedOwnerByCell[reservedKey]
							if (occupantId and occupantId ~= entryId) or (reservedOwner and reservedOwner ~= entryId) then
								break
							end
							effectiveSpan = effectiveSpan + 1
						end
						for reservedColumn = column + 1, column + effectiveSpan - 1 do
							local reservedKey = getCellKey(reservedColumn, row)
							reservedOwnerByCell[reservedKey] = entryId
							if boundsColumns > 0 then reservedOwnerByIndex[((row - 1) * boundsColumns) + reservedColumn] = entryId end
						end
					end
				end
				effectiveSpanByEntryId[entryId] = effectiveSpan
			end
		end
	end

	cache._eqolBarsReservationSignature = signature
	cache._eqolBarsReservedOwnerByCell = reservedOwnerByCell
	cache._eqolBarsReservedOwnerByIndex = reservedOwnerByIndex
	cache._eqolBarsEffectiveSpanByEntryId = effectiveSpanByEntryId
	cache._eqolBarsAnchorCellByEntryId = anchorCellByEntryId
	return cache
end

local function getReservedOwnerForCell(panel, column, row, skipEntryId)
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	if not (panel and column and row) then return nil end
	local cache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	cache = augmentFixedLayoutCache(panel, cache)
	local ownerId = cache and cache._eqolBarsReservedOwnerByCell and cache._eqolBarsReservedOwnerByCell[getCellKey(column, row)] or nil
	if ownerId and ownerId ~= skipEntryId then return ownerId, panel.entries and panel.entries[ownerId] or nil end
	return nil
end

local function isAnchorCell(panel, entryId, column, row)
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	entryId = normalizeId(entryId)
	if not (panel and entryId and column and row) then return false end
	local cache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	cache = augmentFixedLayoutCache(panel, cache)
	local anchor = cache and cache._eqolBarsAnchorCellByEntryId and cache._eqolBarsAnchorCellByEntryId[entryId] or nil
	return anchor and anchor.column == column and anchor.row == row or false
end

local function getEffectiveBarSpan(panel, entryId)
	local panelEntryId = normalizeId(entryId)
	if not (panel and panelEntryId) then return 1 end
	local cache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	cache = augmentFixedLayoutCache(panel, cache)
	return cache and cache._eqolBarsEffectiveSpanByEntryId and cache._eqolBarsEffectiveSpanByEntryId[panelEntryId] or 1
end

getBarColor = function(mode)
	local color = Bars.COLORS[mode] or Bars.COLORS.COOLDOWN
	return color[1], color[2], color[3], color[4]
end

local function ensureBarUpdater()
	return nil
end

local function trackBarAnimation(barFrame)
	return
end

local function stopBarAnimation(barFrame)
	local runtime = getRuntimeState()
	if runtime.activeBars then runtime.activeBars[barFrame] = nil end
	if Bars.updateFrame and Bars.updateFrame.Hide then Bars.updateFrame:Hide() end
end

local function applyStatusBarTexture(statusBar, texturePath)
	if not statusBar then return end
	local resolvedTexture = texturePath or "Interface\\TargetingFrame\\UI-StatusBar"
	if statusBar._eqolStatusBarTexturePath ~= resolvedTexture then
		statusBar:SetStatusBarTexture(resolvedTexture)
		statusBar._eqolStatusBarTexturePath = resolvedTexture
	end
	local texture = statusBar:GetStatusBarTexture()
	if texture ~= statusBar._eqolStatusBarTexture then
		if texture and texture.SetSnapToPixelGrid then
			texture:SetSnapToPixelGrid(false)
			texture:SetTexelSnappingBias(0)
		end
		statusBar._eqolStatusBarTexture = texture
	end
end

local function applyStatusBarOrientation(statusBar, orientation)
	if not (statusBar and statusBar.SetOrientation) then return end
	local resolvedOrientation = type(orientation) == "string" and string.upper(orientation) or nil
	if resolvedOrientation ~= BAR_ORIENTATION_VERTICAL then resolvedOrientation = BAR_ORIENTATION_HORIZONTAL end
	if statusBar._eqolOrientation ~= resolvedOrientation then
		statusBar:SetOrientation(resolvedOrientation)
		statusBar._eqolOrientation = resolvedOrientation
	end
end

local function applyBackdropFrame(frame, edgeFile, edgeSize)
	if not frame then return end
	local resolvedEdge = hasTextValue(edgeFile) and not isSecretValue(edgeFile) and edgeFile or "Interface\\Buttons\\WHITE8x8"
	local resolvedSize = max(edgeSize or 0, 1)
	local signature = resolvedEdge .. "|" .. tostring(edgeSize or 0)
	if frame._eqolBackdropSignature == signature then return end
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = resolvedEdge,
		edgeSize = resolvedSize,
	})
	frame._eqolBackdropSignature = signature
end

local function ensureBarSegment(frame, index)
	frame.segments = frame.segments or {}
	local segment = frame.segments[index]
	if segment then return segment end
	segment = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
	segment:SetClampedToScreen(false)
	segment:SetMovable(false)
	segment:EnableMouse(false)
	segment.fill = CreateFrame("StatusBar", nil, segment)
	segment.fill:SetPoint("TOPLEFT", segment, "TOPLEFT", 0, 0)
	segment.fill:SetPoint("BOTTOMRIGHT", segment, "BOTTOMRIGHT", 0, 0)
	segment.fill:SetMinMaxValues(0, 1)
	segment.fill:SetValue(0)
	applyStatusBarTexture(segment.fill, "Interface\\TargetingFrame\\UI-StatusBar")
	segment.fillBg = segment.fill:CreateTexture(nil, "BACKGROUND")
	segment.fillBg:SetAllPoints(segment.fill)
	segment.fillBg:SetTexture("Interface\\Buttons\\WHITE8x8")
	segment.fillBg:SetVertexColor(0, 0, 0, 0.35)
	segment.borderOverlay = CreateFrame("Frame", nil, segment, "BackdropTemplate")
	segment.borderOverlay:SetClampedToScreen(false)
	segment.borderOverlay:SetMovable(false)
	segment.borderOverlay:EnableMouse(false)
	segment.hitHandle = CreateFrame("Button", nil, segment)
	segment.hitHandle:SetAllPoints(segment)
	segment.hitHandle:EnableMouse(false)
	segment.hitHandle:Hide()
	segment:Hide()
	frame.segments[index] = segment
	return segment
end

local function clearCooldownFrame(frame)
	if not frame then return end
	if frame.Clear then
		frame:Clear()
	elseif CooldownFrame_Clear then
		CooldownFrame_Clear(frame)
	else
		frame:Hide()
	end
	frame._eqolDurationObject = nil
end

local function ensureBarCooldownGate(frame)
	if frame._eqolCooldownGate then return frame._eqolCooldownGate end
	local gate = CreateFrame("Cooldown", nil, frame.body or frame, "CooldownFrameTemplate")
	gate:SetAllPoints(frame.body or frame)
	if gate.SetDrawSwipe then gate:SetDrawSwipe(false) end
	if gate.SetDrawEdge then gate:SetDrawEdge(false) end
	if gate.SetDrawBling then gate:SetDrawBling(false) end
	if gate.SetHideCountdownNumbers then gate:SetHideCountdownNumbers(true) end
	if gate.SetAlpha then gate:SetAlpha(0) end
	if gate.EnableMouse then gate:EnableMouse(false) end
	gate:Hide()
	frame._eqolCooldownGate = gate
	return gate
end

local function setCooldownFrameDuration(frame, durationObject)
	if not frame then return false end
	if durationObject and frame.SetCooldownFromDurationObject then
		if frame._eqolDurationObject ~= durationObject then
			clearCooldownFrame(frame)
			frame:SetCooldownFromDurationObject(durationObject)
			frame._eqolDurationObject = durationObject
		end
		return true
	end
	if frame._eqolDurationObject ~= nil then clearCooldownFrame(frame) end
	return false
end

local function hideUnusedBarSegments(frame, firstIndex)
	if not (frame and frame.segments) then return end
	for index = firstIndex or 1, #frame.segments do
		local segment = frame.segments[index]
		if segment then segment:Hide() end
	end
end

local function ensureBarFrame(icon)
	if icon._eqolBarsFrame then return icon._eqolBarsFrame end
	local parent = (icon.slotAnchor and icon.slotAnchor:GetParent()) or icon:GetParent() or UIParent
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetClampedToScreen(false)
	frame:SetMovable(false)
	frame:EnableMouse(false)

	frame.body = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	frame.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	applyBackdropFrame(frame.body, "Interface\\Buttons\\WHITE8x8", 1)
	frame.body:SetBackdropColor(unpack(Bars.COLORS.Background))
	frame.body:SetBackdropBorderColor(unpack(Bars.COLORS.Border))
	frame.borderOverlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.borderOverlay:SetClampedToScreen(false)
	frame.borderOverlay:SetMovable(false)
	frame.borderOverlay:EnableMouse(false)

	frame.fill = CreateFrame("StatusBar", nil, frame.body)
	frame.fill:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, 0)
	frame.fill:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", 0, 0)
	frame.fill:SetMinMaxValues(0, 1)
	frame.fill:SetValue(0)
	applyStatusBarTexture(frame.fill, "Interface\\TargetingFrame\\UI-StatusBar")

	frame.fillBg = frame.fill:CreateTexture(nil, "BACKGROUND")
	frame.fillBg:SetAllPoints(frame.fill)
	frame.fillBg:SetTexture("Interface\\Buttons\\WHITE8x8")
	frame.fillBg:SetVertexColor(0, 0, 0, 0.35)

	frame.iconOverlay = CreateFrame("Frame", nil, frame)
	frame.iconOverlay:SetAllPoints(frame)
	frame.iconOverlay:EnableMouse(false)

	frame.icon = frame.iconOverlay:CreateTexture(nil, "OVERLAY")
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.icon:Hide()

	frame.textOverlay = CreateFrame("Frame", nil, frame)
	frame.textOverlay:SetAllPoints(frame)
	frame.textOverlay:EnableMouse(false)

	frame.hitHandle = CreateFrame("Button", nil, frame)
	frame.hitHandle:SetAllPoints(frame)
	frame.hitHandle:SetFrameStrata(frame:GetFrameStrata() or parent:GetFrameStrata())
	frame.hitHandle:SetFrameLevel((frame:GetFrameLevel() or parent:GetFrameLevel()) + 20)
	frame.hitHandle:EnableMouse(false)
	frame.hitHandle:Hide()

	frame.label = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.label:SetJustifyH("LEFT")
	frame.label:SetTextColor(unpack(Bars.COLORS.Label))
	frame.label:SetShadowOffset(1, -1)
	frame.label:Hide()

	frame.value = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.value:SetJustifyH("RIGHT")
	frame.value:SetTextColor(unpack(Bars.COLORS.Value))
	frame.value:SetShadowOffset(1, -1)
	frame.value:Hide()

	frame.segments = {}
	frame._eqolBarState = nil
	frame._eqolSegmentCount = 0
	frame:Hide()
	icon._eqolBarsFrame = frame
	return frame
end

Bars.HideForwardHitHandle = function(hitHandle)
	if not hitHandle then return end
	hitHandle:EnableMouse(false)
	hitHandle:Hide()
	hitHandle:SetScript("OnEnter", nil)
	hitHandle:SetScript("OnLeave", nil)
	hitHandle:SetScript("OnDragStart", nil)
	hitHandle:SetScript("OnDragStop", nil)
	hitHandle:SetScript("OnReceiveDrag", nil)
	hitHandle:SetScript("OnMouseUp", nil)
	hitHandle._eqolForwardHandle = nil
end

Bars.ConfigureForwardHitHandle = function(hitHandle, anchorFrame, forwardHandle)
	if not (hitHandle and anchorFrame and forwardHandle and forwardHandle.IsShown and forwardHandle:IsShown()) then
		Bars.HideForwardHitHandle(hitHandle)
		return
	end
	hitHandle:ClearAllPoints()
	hitHandle:SetAllPoints(anchorFrame)
	hitHandle:SetFrameStrata(anchorFrame:GetFrameStrata())
	hitHandle:SetFrameLevel(anchorFrame:GetFrameLevel() + 20)
	hitHandle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	hitHandle:RegisterForDrag("LeftButton")
	hitHandle:EnableMouse(true)
	hitHandle:Show()
	hitHandle._eqolForwardHandle = forwardHandle
	hitHandle:SetScript("OnEnter", function(self)
		local handle = self and self._eqolForwardHandle or nil
		local script = handle and handle.GetScript and handle:GetScript("OnEnter") or nil
		if script then script(handle) end
	end)
	hitHandle:SetScript("OnLeave", function(self)
		local handle = self and self._eqolForwardHandle or nil
		local script = handle and handle.GetScript and handle:GetScript("OnLeave") or nil
		if script then script(handle) end
	end)
	hitHandle:SetScript("OnDragStart", function(self)
		local handle = self and self._eqolForwardHandle or nil
		local script = handle and handle.GetScript and handle:GetScript("OnDragStart") or nil
		if script then script(handle) end
	end)
	hitHandle:SetScript("OnDragStop", function(self)
		local handle = self and self._eqolForwardHandle or nil
		local script = handle and handle.GetScript and handle:GetScript("OnDragStop") or nil
		if script then script(handle) end
	end)
	hitHandle:SetScript("OnReceiveDrag", function(self)
		local handle = self and self._eqolForwardHandle or nil
		local script = handle and handle.GetScript and handle:GetScript("OnReceiveDrag") or nil
		if script then script(handle) end
	end)
	hitHandle:SetScript("OnMouseUp", function(self, btn)
		local handle = self and self._eqolForwardHandle or nil
		local script = handle and handle.GetScript and handle:GetScript("OnMouseUp") or nil
		if script then script(handle, btn) end
	end)
end

Bars.StopFreeMove = function(commit)
	local runtime = getRuntimeState()
	local move = runtime and runtime.barFreeMove or nil
	if not move then return false end
	if move.hitHandle and move.hitHandle.SetScript then move.hitHandle:SetScript("OnUpdate", nil) end
	if move.barFrame and move.slotAnchor then
		move.barFrame:ClearAllPoints()
		move.barFrame:SetPoint("LEFT", move.slotAnchor, "LEFT", move.currentOffsetX or move.startOffsetX or 0, move.currentOffsetY or move.startOffsetY or 0)
	end
	runtime.barFreeMove = nil
	if commit == true and move.panelId and move.entryId then
		local targetOffsetX = normalizeBarOffset(move.currentOffsetX, move.startOffsetX or Bars.DEFAULTS.barOffsetX)
		local targetOffsetY = normalizeBarOffset(move.currentOffsetY, move.startOffsetY or Bars.DEFAULTS.barOffsetY)
		if targetOffsetX ~= move.startOffsetX or targetOffsetY ~= move.startOffsetY then
			mutateBarEntry(move.panelId, move.entryId, function(entry)
				entry.barOffsetX = targetOffsetX
				entry.barOffsetY = targetOffsetY
			end)
			return true
		end
	end
	return false
end

Bars.StartFreeMove = function(hitHandle, barFrame, icon)
	local state = barFrame and barFrame._eqolBarState or nil
	local panelId = state and normalizeId(state.panelId) or nil
	local entryId = state and normalizeId(state.entryId) or nil
	if not (hitHandle and barFrame and icon and panelId and entryId) then return false end
	local panel = CooldownPanels.GetPanel and CooldownPanels:GetPanel(panelId) or nil
	if not (panel and Helper.IsFixedLayout and Helper.IsFixedLayout(panel.layout)) then return false end
	if not (CooldownPanels.IsPanelLayoutEditActive and CooldownPanels:IsPanelLayoutEditActive(panelId)) then return false end
	local cursorX, cursorY = nil, nil
	if CooldownPanels.GetCursorPositionOnUIParent then cursorX, cursorY = CooldownPanels:GetCursorPositionOnUIParent() end
	if not (cursorX and cursorY) then return false end
	local runtime = getRuntimeState()
	runtime.barFreeMove = {
		hitHandle = hitHandle,
		barFrame = barFrame,
		slotAnchor = icon.slotAnchor or icon,
		panelId = panelId,
		entryId = entryId,
		startCursorX = cursorX,
		startCursorY = cursorY,
		startOffsetX = normalizeBarOffset(state.barOffsetX, Bars.DEFAULTS.barOffsetX),
		startOffsetY = normalizeBarOffset(state.barOffsetY, Bars.DEFAULTS.barOffsetY),
		currentOffsetX = normalizeBarOffset(state.barOffsetX, Bars.DEFAULTS.barOffsetX),
		currentOffsetY = normalizeBarOffset(state.barOffsetY, Bars.DEFAULTS.barOffsetY),
	}
	hitHandle:SetScript("OnUpdate", function(self)
		local activeRuntime = getRuntimeState()
		local move = activeRuntime and activeRuntime.barFreeMove or nil
		if not move or move.hitHandle ~= self then
			self:SetScript("OnUpdate", nil)
			return
		end
		local currentCursorX, currentCursorY = nil, nil
		if CooldownPanels.GetCursorPositionOnUIParent then currentCursorX, currentCursorY = CooldownPanels:GetCursorPositionOnUIParent() end
		if not (currentCursorX and currentCursorY) then return end
		move.currentOffsetX = normalizeBarOffset(move.startOffsetX + (currentCursorX - move.startCursorX), move.startOffsetX)
		move.currentOffsetY = normalizeBarOffset(move.startOffsetY + (currentCursorY - move.startCursorY), move.startOffsetY)
		if move.barFrame and move.slotAnchor then
			move.barFrame:ClearAllPoints()
			move.barFrame:SetPoint("LEFT", move.slotAnchor, "LEFT", move.currentOffsetX, move.currentOffsetY)
			if move.barFrame._eqolBarState then
				move.barFrame._eqolBarState.barOffsetX = move.currentOffsetX
				move.barFrame._eqolBarState.barOffsetY = move.currentOffsetY
			end
		end
	end)
	return true
end

Bars.ConfigureFreeMoveHandle = function(hitHandle, barFrame, icon)
	if not hitHandle then return end
	local forwardHandle = hitHandle._eqolForwardHandle
	local originalStart = hitHandle.GetScript and hitHandle:GetScript("OnDragStart") or nil
	local originalStop = hitHandle.GetScript and hitHandle:GetScript("OnDragStop") or nil
	hitHandle:SetScript("OnDragStart", function(self)
		if IsShiftKeyDown and IsShiftKeyDown() then
			if originalStart then originalStart(self) end
			return
		end
		self._eqolBarsFreeMoveActive = Bars.StartFreeMove(self, barFrame, icon) == true
		if self._eqolBarsFreeMoveActive ~= true and originalStart then originalStart(self) end
	end)
	hitHandle:SetScript("OnDragStop", function(self)
		if self._eqolBarsFreeMoveActive == true then
			self._eqolBarsFreeMoveActive = nil
			Bars.StopFreeMove(true)
			return
		end
		if originalStop then originalStop(self) end
	end)
	if forwardHandle then
		hitHandle._eqolForwardHandle = forwardHandle
	end
end

local function hideBarHitHandle(barFrame)
	if not barFrame then return end
	Bars.HideForwardHitHandle(barFrame.hitHandle)
	if barFrame.segments then
		for index = 1, #barFrame.segments do
			local segment = barFrame.segments[index]
			if segment and segment.hitHandle then Bars.HideForwardHitHandle(segment.hitHandle) end
		end
	end
end

local function applyFontStringStyle(fontString, fontValue, sizeValue, styleValue, colorValue, fallbackPath, fallbackSize, fallbackStyle)
	if not fontString then return end
	local fontPath = Helper.ResolveFontPath(fontValue, fallbackPath)
	local fontSize = normalizeBarFontSize(sizeValue, fallbackSize)
	local fontStyleChoice = normalizeBarFontStyle(styleValue, fallbackStyle)
	local fontStyle = Helper.NormalizeFontStyle(fontStyleChoice, fallbackStyle) or ""
	if fontString.SetFont then
		local applied = fontString:SetFont(fontPath, fontSize, fontStyle)
		if applied == false then fontString:SetFont(STANDARD_TEXT_FONT, fontSize, fontStyle) end
	end
	local color = Helper.NormalizeColor(colorValue, { 1, 1, 1, 1 })
	if fontString.SetTextColor then fontString:SetTextColor(color[1], color[2], color[3], color[4]) end
	if fontString.SetShadowOffset then fontString:SetShadowOffset(1, -1) end
end

local function ensureModeButton(icon)
	if icon._eqolBarsModeButton then return icon._eqolBarsModeButton end
	local parent = icon.layoutHandle or icon.slotAnchor or icon
	local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
	button:SetSize(24, 12)
	button:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	button:SetBackdropColor(0, 0, 0, 0.80)
	button:SetBackdropBorderColor(0.95, 0.82, 0.25, 0.95)
	button:SetFrameStrata(parent:GetFrameStrata() or icon:GetFrameStrata())
	button:SetFrameLevel((parent:GetFrameLevel() or icon:GetFrameLevel()) + 50)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.text:SetPoint("CENTER")
	button.text:SetTextColor(1, 0.90, 0.30, 1)
	button:Hide()
	icon._eqolBarsModeButton = button
	return button
end

local function hideBarPresentation(icon)
	local barFrame = icon and icon._eqolBarsFrame or nil
	if barFrame then
		local runtime = getRuntimeState()
		local move = runtime and runtime.barFreeMove or nil
		if move and move.barFrame == barFrame then Bars.StopFreeMove(false) end
		stopBarAnimation(barFrame)
		barFrame._eqolBarState = nil
		Bars.ClearBarValueTextUpdater(barFrame)
		hideBarHitHandle(barFrame)
		barFrame:Hide()
	end
	if not icon then return end
	icon._eqolBarsReservedOwnerId = nil
	icon._eqolBarsReservedSlot = nil
end

local function hideEditorBarDragPreview(editor)
	if not (editor and editor.dragIcon) then return end
	local dragIcon = editor.dragIcon
	local previewFrame = dragIcon._eqolBarsFrame
	if previewFrame then
		local runtime = getRuntimeState()
		local move = runtime and runtime.barFreeMove or nil
		if move and move.barFrame == previewFrame then Bars.StopFreeMove(false) end
		stopBarAnimation(previewFrame)
		previewFrame._eqolBarState = nil
		Bars.ClearBarValueTextUpdater(previewFrame)
		previewFrame:Hide()
	end
	if dragIcon.texture then
		dragIcon.texture:SetAlpha(1)
		dragIcon.texture:Show()
	end
	if editor._eqolBarsDragSourceFrame then
		editor._eqolBarsDragSourceFrame:SetAlpha(editor._eqolBarsDragSourceAlpha or 1)
	end
	if editor._eqolBarsDragIconWidth and editor._eqolBarsDragIconHeight then
		dragIcon:SetSize(editor._eqolBarsDragIconWidth, editor._eqolBarsDragIconHeight)
	end
	editor._eqolBarsDragSourceFrame = nil
	editor._eqolBarsDragSourceAlpha = nil
	editor._eqolBarsDragIconWidth = nil
	editor._eqolBarsDragIconHeight = nil
	dragIcon._eqolBaseSlotSize = nil
end

Bars.ClearBarValueTextUpdater = function(barFrame)
	if not barFrame then return end
	barFrame._eqolValueTextProvider = nil
	barFrame._eqolValueTextElapsed = nil
	if barFrame:GetScript("OnUpdate") then barFrame:SetScript("OnUpdate", nil) end
end

Bars.ConfigureBarValueTextUpdater = function(barFrame, state)
	if not barFrame then return end
	local provider = state and state.showValueText and state.liveValueTextProvider or nil
	if type(provider) ~= "function" then
		Bars.ClearBarValueTextUpdater(barFrame)
		return
	end

	barFrame._eqolValueTextProvider = provider
	barFrame._eqolValueTextElapsed = 0
	local initialText = provider()
	if initialText ~= nil and barFrame.value then barFrame.value:SetText(initialText) end
	barFrame:SetScript("OnUpdate", function(self, elapsed)
		if not (self._eqolValueTextProvider and self.value and self.value.IsShown and self.value:IsShown()) then return end
		self._eqolValueTextElapsed = (self._eqolValueTextElapsed or 0) + (elapsed or 0)
		if self._eqolValueTextElapsed < 0.05 then return end
		self._eqolValueTextElapsed = 0
		local text = self._eqolValueTextProvider()
		if text ~= nil then self.value:SetText(text) end
	end)
end

local function showEditorBarDragPreview(panelId, panel, entryId, entry, sourceIcon)
	if not (entry and sourceIcon and panel) then return end
	local editor = getEditor and getEditor() or nil
	if not (editor and editor.dragIcon) then return end
	local state = buildBarState(panelId, entryId, entry, sourceIcon, true) or buildBarState(panelId, entryId, entry, sourceIcon, false)
	if not state then return end
	local dragIcon = editor.dragIcon
	if not editor._eqolBarsDragIconWidth or not editor._eqolBarsDragIconHeight then
		editor._eqolBarsDragIconWidth, editor._eqolBarsDragIconHeight = dragIcon:GetSize()
	end
	dragIcon._eqolBaseSlotSize = safeNumber(sourceIcon._eqolBaseSlotSize) or (sourceIcon.GetWidth and sourceIcon:GetWidth()) or 36
	local previewFrame = ensureBarFrame(dragIcon)
	layoutBarFrame(previewFrame, dragIcon, getEffectiveBarSpan(panel, entryId), panel.layout, state)
	stopBarAnimation(previewFrame)
	if dragIcon.texture then
		dragIcon.texture:SetAlpha(0)
		dragIcon.texture:Hide()
	end
	local previewWidth, previewHeight = previewFrame:GetSize()
	if previewWidth and previewHeight then dragIcon:SetSize(previewWidth, previewHeight) end
	if sourceIcon._eqolBarsFrame then
		editor._eqolBarsDragSourceFrame = sourceIcon._eqolBarsFrame
		editor._eqolBarsDragSourceAlpha = sourceIcon._eqolBarsFrame:GetAlpha()
		sourceIcon._eqolBarsFrame:SetAlpha(0.35)
	end
end

local function configureBarDragPreview(panelId, panel, icon, actualEntryId, slotColumn, slotRow)
	local handle = icon and icon.layoutHandle or nil
	if not (handle and panel and actualEntryId) then return end
	if not (Helper.IsFixedLayout and Helper.IsFixedLayout(panel.layout)) then return end
	if not isAnchorCell(panel, actualEntryId, slotColumn, slotRow) then return end
	local entry = panel.entries and panel.entries[actualEntryId] or nil
	if not entry or normalizeDisplayMode(entry.displayMode, Bars.DEFAULTS.displayMode) ~= Bars.DISPLAY_MODE.BAR then return end
	local originalStart = handle:GetScript("OnDragStart")
	local originalStop = handle:GetScript("OnDragStop")
	if originalStart then
		handle:SetScript("OnDragStart", function(self, ...)
			originalStart(self, ...)
			showEditorBarDragPreview(panelId, panel, actualEntryId, entry, icon)
		end)
	end
	if originalStop then
		handle:SetScript("OnDragStop", function(self, ...)
			hideEditorBarDragPreview(getEditor and getEditor() or nil)
			originalStop(self, ...)
			hideEditorBarDragPreview(getEditor and getEditor() or nil)
		end)
	end
end

local function applyReservedGhost(icon, ownerEntry, slotColumn, slotRow)
	if not icon then return end
	if icon.texture then
		icon.texture:SetShown(false)
		icon.texture:SetAlpha(0)
	end
	if icon.cooldown then icon.cooldown:Hide() end
	if icon.count then icon.count:Hide() end
	if icon.charges then icon.charges:Hide() end
	if icon.keybind then icon.keybind:Hide() end
	if icon.stateTexture then icon.stateTexture:Hide() end
	if icon.stateTextureSecond then icon.stateTextureSecond:Hide() end
	if icon.staticText then
		icon.staticText:SetText("")
		icon.staticText:Hide()
	end
	icon._eqolBarsReservedSlot = true
	icon._eqolPreviewCellColumn = slotColumn
	icon._eqolPreviewCellRow = slotRow
end

local function applyNativeSuppression(icon)
	if not icon then return end
	if icon.texture then
		icon.texture:SetShown(false)
		icon.texture:SetAlpha(0)
	end
	if icon.cooldown then icon.cooldown:Hide() end
	if icon.count then icon.count:Hide() end
	if icon.charges then icon.charges:Hide() end
	if icon.keybind then icon.keybind:Hide() end
	if icon.stateTexture then icon.stateTexture:Hide() end
	if icon.stateTextureSecond then icon.stateTextureSecond:Hide() end
	if icon.staticText then icon.staticText:Hide() end
	if icon.previewSoundBorder then icon.previewSoundBorder:Hide() end
	CooldownPanels.HidePreviewGlowBorder(icon)
	CooldownPanels.StopAllIconGlows(icon)
end

local function getStackSessionMax(entryKey, observedValue, preview)
	local runtime = getRuntimeState()
	local maxByKey = runtime.stackMaxByEntryKey or {}
	runtime.stackMaxByEntryKey = maxByKey
	local currentMax = maxByKey[entryKey]
	local observed = safeNumber(observedValue)
	if observed then
		local baseline = preview and 5 or 3
		currentMax = max(currentMax or baseline, observed)
		maxByKey[entryKey] = currentMax
	end
	return currentMax or (preview and 5 or 3)
end

local function getResolvedSpellId(entry, macro)
	local spellId = tonumber((macro and macro.spellID) or entry.spellID)
	if not spellId then return nil end
	if CooldownPanels.ResolveKnownSpellVariantID then
		spellId = CooldownPanels:ResolveKnownSpellVariantID(spellId) or spellId
	end
	return spellId
end

local function getResolvedItemId(entry, macro)
	local itemId = tonumber((macro and macro.itemID) or entry.itemID)
	if not itemId then return nil end
	if CooldownPanels.ResolveEntryItemID then itemId = CooldownPanels.ResolveEntryItemID(entry, itemId) end
	return itemId
end

local function getCooldownProgress(startTime, duration, rate)
	local start = safeNumber(startTime)
	local total = safeNumber(duration)
	if not (start and total and total > 0) then return nil end
	local now = (Api.GetTime and Api.GetTime()) or GetTime()
	local modifier = safeNumber(rate) or 1
	return clamp(((now - start) * modifier) / total, 0, 1)
end

local function getDurationObjectRemaining(durationObject)
	if not (durationObject and durationObject.GetRemainingDuration) then return nil end
	return safeNumber(durationObject.GetRemainingDuration(durationObject, Api.DurationModifierRealTime))
end

local function getDurationObjectTotal(durationObject)
	if not (durationObject and durationObject.GetTotalDuration) then return nil end
	return safeNumber(durationObject.GetTotalDuration(durationObject, Api.DurationModifierRealTime))
end

local function getDurationObjectElapsedProgress(durationObject)
	local remaining = getDurationObjectRemaining(durationObject)
	local total = getDurationObjectTotal(durationObject)
	if not (remaining and total and total > 0) then return nil end
	return clamp(1 - (remaining / total), 0, 1)
end

setBooleanAlpha = function(target, condition, onAlpha, offAlpha)
	if not target then return end
	if target.SetAlphaFromBoolean then
		target:SetAlphaFromBoolean(condition, onAlpha, offAlpha)
	elseif target.SetAlpha then
		if isSecretValue(condition) then
			target:SetAlpha(offAlpha or 0)
		else
			target:SetAlpha(condition and (onAlpha or 1) or (offAlpha or 0))
		end
	end
end

shouldShowChargeSegmentFill = function(state, index)
	if type(index) ~= "number" or index <= 1 then return true end
	if type(state) ~= "table" then return true end
	if state.lastNonGCDCooldownActive ~= true then return true end
	local cooldownDurationObject = state.lastNonGCDCooldownDurationObject
	if not cooldownDurationObject then return false end
	if cooldownDurationObject.IsZero then return cooldownDurationObject:IsZero() end
	local remaining = getDurationObjectRemaining(cooldownDurationObject)
	if remaining == nil then return false end
	return remaining <= 0
end

sweepChargeDurationObjects = function(state)
	if type(state) ~= "table" then return end
	local chargeRemaining = getDurationObjectRemaining(state.chargeDurationObject)
	if chargeRemaining ~= nil and chargeRemaining <= 0 then state.chargeDurationObject = nil end
	local cooldownRemaining = getDurationObjectRemaining(state.cooldownDurationObject)
	if cooldownRemaining ~= nil and cooldownRemaining <= 0 then state.cooldownDurationObject = nil end
end

setStatusBarImmediateValue = function(statusBar, value)
	if not statusBar then return end
	if statusBar.SetMinMaxValues then statusBar:SetMinMaxValues(0, 1, BAR_STATUS_INTERPOLATION_IMMEDIATE) end
	if statusBar.SetValue then statusBar:SetValue(clamp(value or 0, 0, 1), BAR_STATUS_INTERPOLATION_IMMEDIATE) end
	if statusBar.SetToTargetValue then statusBar:SetToTargetValue() end
	statusBar._eqolTimerDurationObject = nil
	statusBar._eqolTimerDurationKey = nil
	statusBar._eqolTimerDirection = nil
end

setStatusBarTimerDuration = function(statusBar, durationObject, cacheKey, direction)
	if not (statusBar and durationObject and statusBar.SetTimerDuration) then return false end
	local appliedKey = cacheKey or durationObject
	local appliedDirection = direction or BAR_STATUS_TIMER_DIRECTION_ELAPSED
	if statusBar._eqolTimerDurationKey ~= appliedKey or statusBar._eqolTimerDirection ~= appliedDirection then
		if statusBar.SetMinMaxValues then statusBar:SetMinMaxValues(0, 1, BAR_STATUS_INTERPOLATION_IMMEDIATE) end
		statusBar:SetTimerDuration(durationObject, BAR_STATUS_INTERPOLATION_IMMEDIATE, appliedDirection)
		statusBar._eqolTimerDurationObject = durationObject
		statusBar._eqolTimerDurationKey = appliedKey
		statusBar._eqolTimerDirection = appliedDirection
	end
	return true
end

inferChargeBaseCount = function(state, maxCharges)
	if type(state) ~= "table" then return nil end
	local numericMax = safeNumber(maxCharges)
	if not (numericMax and numericMax > 0) then return nil end
	if state.cooldownDurationObject ~= nil and state.cooldownGCD ~= true then return 0 end
	if state.chargeDurationObject ~= nil then return max(numericMax - 1, 0) end
	return numericMax
end

getDisplayedCharges = function(icon)
	return safeNumber(icon and icon.charges and icon.charges.GetText and icon.charges:GetText())
end

local function getChargeSessionMax(entryKey, observedMax, observedCurrent, hasRecharge, preview)
	local runtime = getRuntimeState()
	local maxByKey = runtime.chargeMaxByEntryKey or {}
	runtime.chargeMaxByEntryKey = maxByKey
	local currentMax = maxByKey[entryKey]
	local safeObservedMax = safeNumber(observedMax)
	if safeObservedMax and safeObservedMax > 0 then
		currentMax = max(currentMax or safeObservedMax, safeObservedMax)
		maxByKey[entryKey] = currentMax
	end
	local safeObservedCurrent = safeNumber(observedCurrent)
	if currentMax and currentMax > 0 then return currentMax end
	local fallback = preview and 3 or 1
	if hasRecharge then
		fallback = max(fallback, 2)
		if safeObservedCurrent then fallback = max(fallback, safeObservedCurrent + 1) end
	end
	if safeObservedCurrent then fallback = max(fallback, safeObservedCurrent) end
	return fallback
end

local function getChargeCooldownCache(entryKey)
	local runtime = getRuntimeState()
	local activeByKey = runtime.chargeLastNonGCDCooldownActiveByEntryKey or {}
	local durationByKey = runtime.chargeLastNonGCDCooldownDurationByEntryKey or {}
	runtime.chargeLastNonGCDCooldownActiveByEntryKey = activeByKey
	runtime.chargeLastNonGCDCooldownDurationByEntryKey = durationByKey
	if not entryKey then return activeByKey, durationByKey, false, nil end
	return activeByKey, durationByKey, activeByKey[entryKey] == true, durationByKey[entryKey]
end

refreshChargeBarRuntimeState = function(state, icon)
	if type(state) ~= "table" then return state end
	local spellId = safeNumber(state.spellId)
	if not spellId then return state end

	local chargesInfo = CooldownPanels.GetCachedSpellChargesInfo and CooldownPanels:GetCachedSpellChargesInfo(spellId) or nil
	local chargeDurationObject = CooldownPanels.GetCachedSpellChargeDurationObject and CooldownPanels:GetCachedSpellChargeDurationObject(spellId) or nil
	local rawCooldownDurationObject = CooldownPanels.GetCachedSpellCooldownDurationObject and CooldownPanels:GetCachedSpellCooldownDurationObject(spellId) or nil
	local cooldownDurationObject = rawCooldownDurationObject
	local cooldownRemaining = getDurationObjectRemaining(cooldownDurationObject)
	if cooldownRemaining ~= nil and cooldownRemaining <= 0 then
		cooldownDurationObject = nil
		cooldownRemaining = nil
	end

	local cooldownStart, cooldownDuration, cooldownEnabled, cooldownRate, cooldownGCD, cooldownIsActive = 0, 0, false, 1, nil, false
	if CooldownPanels.GetCachedSpellCooldownInfo then
		cooldownStart, cooldownDuration, cooldownEnabled, cooldownRate, cooldownGCD, cooldownIsActive =
			CooldownPanels:GetCachedSpellCooldownInfo(spellId)
	end

	local chargeInfoActive = CooldownPanels.IsChargeInfoActive and CooldownPanels.IsChargeInfoActive(chargesInfo) or false
	local cooldownInfoActive =
		CooldownPanels.IsSpellCooldownInfoActive and CooldownPanels.IsSpellCooldownInfoActive(cooldownIsActive, cooldownEnabled, cooldownStart, cooldownDuration) or false

	local displayedCharges = chargesInfo and safeNumber(chargesInfo.currentCharges) or getDisplayedCharges(icon)
	if displayedCharges ~= nil then state.currentCharges = displayedCharges end

	local entryKey = state.entryKey
	local activeByKey, durationByKey, cachedCooldownActive, cachedCooldownDurationObject = getChargeCooldownCache(entryKey)
	if entryKey and cooldownGCD ~= true then
		cachedCooldownActive = cooldownInfoActive == true
		cachedCooldownDurationObject = cachedCooldownActive and rawCooldownDurationObject or nil
		activeByKey[entryKey] = cachedCooldownActive
		durationByKey[entryKey] = cachedCooldownDurationObject
	end

	local maxCharges = chargesInfo and safeNumber(chargesInfo.maxCharges) or safeNumber(state.maxCharges)
	local hasRecharge = chargeInfoActive == true or cachedCooldownActive == true
	maxCharges = getChargeSessionMax(entryKey, maxCharges, displayedCharges, hasRecharge, false)
	local displayedChargePolicy = nil
	if entryKey and maxCharges == 2 and displayedCharges ~= nil then
		if displayedCharges <= 0 and chargeInfoActive == true then
			cachedCooldownActive = true
			activeByKey[entryKey] = true
			displayedChargePolicy = "force_zero_state"
		elseif displayedCharges >= 1 then
			cachedCooldownActive = false
			cachedCooldownDurationObject = nil
			activeByKey[entryKey] = false
			durationByKey[entryKey] = nil
			displayedChargePolicy = "force_ready_state"
		end
	end

	local rechargeStart = chargesInfo and safeNumber(chargesInfo.cooldownStartTime) or nil
	local rechargeDuration = chargesInfo and safeNumber(chargesInfo.cooldownDuration) or nil
	local rechargeRate = chargesInfo and (safeNumber(chargesInfo.chargeModRate) or 1) or 1
	local rechargeProgress = getDurationObjectElapsedProgress(chargeDurationObject)
	if rechargeProgress == nil and cachedCooldownActive ~= true and cooldownGCD ~= true then
		rechargeProgress = getDurationObjectElapsedProgress(cooldownDurationObject)
	end
	if rechargeProgress == nil and displayedCharges and maxCharges and rechargeStart and rechargeDuration and rechargeDuration > 0 and isSafeLessThan(displayedCharges, maxCharges) then
		local now = (Api.GetTime and Api.GetTime()) or GetTime()
		rechargeProgress = clamp((now - rechargeStart) * rechargeRate / rechargeDuration, 0, 1)
	end

	state.chargesInfo = chargesInfo
	state.chargeInfoActive = chargeInfoActive == true
	state.maxCharges = maxCharges
	state.chargeDurationObject = chargeInfoActive == true and chargeDurationObject or nil
	state.rawCooldownDurationObject = rawCooldownDurationObject
	state.cooldownDurationObject = cooldownGCD ~= true and cooldownInfoActive == true and cooldownDurationObject or nil
	state.cooldownRemaining = cooldownRemaining
	state.cooldownGCD = cooldownGCD == true
	state.cooldownInfoActive = cooldownInfoActive == true
	state.lastNonGCDCooldownActive = cachedCooldownActive == true
	state.lastNonGCDCooldownDurationObject = cachedCooldownDurationObject
	state.rechargeStart = rechargeStart
	state.rechargeDuration = rechargeDuration
	state.rechargeRate = rechargeRate
	state.rechargeProgress = rechargeProgress or 0
	state.animate = state.chargeInfoActive == true
		or state.lastNonGCDCooldownActive == true
		or ((rechargeStart and rechargeDuration and rechargeDuration > 0) and true or false)
	if state.preview ~= true then
		writeBarsDebug("refreshChargeState", {
			panelId = state.panelId,
			entryId = state.entryId,
			spellId = state.spellId,
			entryKey = state.entryKey,
			iconChargeText = icon and icon.charges and icon.charges.GetText and getDebugText(icon.charges:GetText()) or nil,
			iconCooldownText = getCooldownText(icon),
			displayedCharges = displayedCharges,
			maxCharges = maxCharges,
			chargesInfoIsActive = chargesInfo and chargesInfo.isActive,
			chargeInfoActive = chargeInfoActive == true,
			chargeDurationObject = chargeDurationObject ~= nil,
			chargeRemaining = getDurationObjectRemaining(chargeDurationObject),
			cooldownApiIsActive = cooldownIsActive,
			cooldownInfoActive = cooldownInfoActive == true,
			cooldownGCD = cooldownGCD == true,
			rawCooldownDurationObject = rawCooldownDurationObject ~= nil,
			rawCooldownRemaining = getDurationObjectRemaining(rawCooldownDurationObject),
			cachedCooldownActive = cachedCooldownActive == true,
			cachedCooldownRemaining = getDurationObjectRemaining(cachedCooldownDurationObject),
			rechargeStart = rechargeStart,
			rechargeDuration = rechargeDuration,
			rechargeProgress = rechargeProgress,
			displayedChargePolicy = displayedChargePolicy,
		})
	end
	return state
end

getChargeBarProgress = function(state)
	if type(state) ~= "table" then return 0 end
	sweepChargeDurationObjects(state)
	local currentCharges = safeNumber(state.currentCharges)
	local maxCharges = safeNumber(state.maxCharges)
	local baseCharges = currentCharges
	if baseCharges == nil then baseCharges = inferChargeBaseCount(state, maxCharges) end
	local rechargeProgress = getDurationObjectElapsedProgress(state.chargeDurationObject)
	if rechargeProgress == nil and state.cooldownGCD ~= true then
		rechargeProgress = getDurationObjectElapsedProgress(state.cooldownDurationObject)
	end
	if rechargeProgress == nil then
		local rechargeStart = safeNumber(state.rechargeStart)
		local rechargeDuration = safeNumber(state.rechargeDuration)
		if rechargeStart and rechargeDuration and rechargeDuration > 0 then
			local now = (Api.GetTime and Api.GetTime()) or GetTime()
			local rechargeRate = safeNumber(state.rechargeRate) or 1
			rechargeProgress = clamp(((now - rechargeStart) * rechargeRate) / rechargeDuration, 0, 1)
		else
			rechargeProgress = clamp(safeNumber(state.rechargeProgress) or 0, 0, 1)
		end
	end
	state.rechargeProgress = rechargeProgress
	if baseCharges and maxCharges and maxCharges > 0 then
		local progress = baseCharges / maxCharges
		if rechargeProgress > 0 and baseCharges < maxCharges then progress = (baseCharges + rechargeProgress) / maxCharges end
		return clamp(progress, 0, 1)
	end
	if rechargeProgress > 0 and maxCharges and maxCharges > 0 then
		local inferredBase = inferChargeBaseCount(state, maxCharges) or 0
		return clamp((inferredBase + rechargeProgress) / maxCharges, 0, 1)
	end
	if rechargeProgress > 0 then return clamp(rechargeProgress, 0, 1) end
	if baseCharges and baseCharges > 0 then return 1 end
	return (state.chargeInfoActive == true or state.cooldownGCD == true) and 1 or 0
end

getChargeBarValueText = function(icon, currentCharges, maxCharges)
	local current = safeNumber(currentCharges)
	local maximum = safeNumber(maxCharges)
	if current and maximum and maximum > 0 then return format("%d/%d", current, maximum) end
	return icon and icon.charges and icon.charges.GetText and icon.charges:GetText() or nil
end

getChargeSegmentDescriptors = function(state, segmentCount)
	local descriptors = {}
	segmentCount = clamp(tonumber(segmentCount) or safeNumber(state and state.maxCharges) or 1, 1, 20)
	for index = 1, segmentCount do
		descriptors[index] = { value = 0, durationObject = nil }
	end
	if type(state) ~= "table" then return descriptors end

	sweepChargeDurationObjects(state)
	if segmentCount == 2 then
		local cooldownActive = state.lastNonGCDCooldownActive == true
		local cooldownDurationObject = state.lastNonGCDCooldownDurationObject
		local chargeActive = state.chargeInfoActive == true and state.chargeDurationObject ~= nil
		descriptors[1].value = 1
		descriptors[2].value = 1
		if cooldownActive then
			if cooldownDurationObject then
				descriptors[1].durationObject = cooldownDurationObject
			else
				descriptors[1].value = 0
			end
		end
		if chargeActive then
			descriptors[2].durationObject = state.chargeDurationObject
		end
		if state.preview ~= true then
			writeBarsDebug("chargeDescriptors", {
				panelId = state.panelId,
				entryId = state.entryId,
				spellId = state.spellId,
				displayedCharges = state.currentCharges,
				maxCharges = state.maxCharges,
				cooldownActive = cooldownActive,
				chargeActive = chargeActive,
				seg1Value = descriptors[1].value,
				seg1Timer = descriptors[1].durationObject ~= nil,
				seg1Remaining = getDurationObjectRemaining(descriptors[1].durationObject),
				seg2Value = descriptors[2].value,
				seg2Timer = descriptors[2].durationObject ~= nil,
				seg2Remaining = getDurationObjectRemaining(descriptors[2].durationObject),
			})
		end
		return descriptors
	end

	local maxCharges = safeNumber(state.maxCharges) or segmentCount
	local currentCharges = safeNumber(state.currentCharges)
	if currentCharges == nil then currentCharges = inferChargeBaseCount(state, maxCharges) end
	currentCharges = clamp(currentCharges or 0, 0, segmentCount)

	local hasCooldownTimer = state.cooldownDurationObject ~= nil and state.cooldownGCD ~= true
	local hasChargeTimer = state.chargeDurationObject ~= nil

	for index = 1, segmentCount do
		local descriptor = descriptors[index]
		if index <= currentCharges then
			descriptor.value = 1
		elseif index == (currentCharges + 1) and currentCharges < segmentCount and hasChargeTimer then
			descriptor.durationObject = state.chargeDurationObject
		elseif index == 1 and currentCharges <= 0 and hasCooldownTimer then
			descriptor.durationObject = state.cooldownDurationObject
		else
			descriptor.value = 0
		end
	end

	return descriptors
end

local function buildBarState(panelId, entryId, entry, icon, preview)
	if not entry then return nil end
	local displayMode = normalizeDisplayMode(entry.displayMode, Bars.DEFAULTS.displayMode)
	if displayMode ~= Bars.DISPLAY_MODE.BAR then return nil end

	local mode = normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode)
	if not supportsBarMode(entry, mode) then return nil end

	local resolvedType, macro = getEntryResolvedType(entry)
	local resolvedSpellId = resolvedType == "SPELL" and getResolvedSpellId(entry, macro) or nil
	local label = getEntryLabel(entry)
	local texture = icon and icon.texture and icon.texture.GetTexture and icon.texture:GetTexture() or nil
	local progress = 1
	local valueText = nil
	local animate = false
	local state = {
		mode = mode,
		label = label,
		texture = texture,
		preview = preview == true,
		showIcon = getStoredBoolean(entry, "barShowIcon", Bars.DEFAULTS.barShowIcon),
		showLabel = getStoredBoolean(entry, "barShowLabel", Bars.DEFAULTS.barShowLabel),
		showValueText = getStoredBoolean(entry, "barShowValueText", Bars.DEFAULTS.barShowValueText),
		progress = 1,
		icon = icon,
		panelId = panelId,
		entryId = entryId,
		fillDurationObject = nil,
		timerDirection = BAR_STATUS_TIMER_DIRECTION_ELAPSED,
		liveValueTextProvider = nil,
		barWidth = normalizeBarWidth(entry.barWidth, Bars.DEFAULTS.barWidth),
		barHeight = normalizeBarHeight(entry.barHeight, Bars.DEFAULTS.barHeight),
		barOffsetX = normalizeBarOffset(entry.barOffsetX, Bars.DEFAULTS.barOffsetX),
		barOffsetY = normalizeBarOffset(entry.barOffsetY, Bars.DEFAULTS.barOffsetY),
		orientation = normalizeBarOrientation(entry.barOrientation, Bars.DEFAULTS.barOrientation),
		segmentDirection = normalizeBarSegmentDirection(entry.barSegmentDirection, Bars.DEFAULTS.barSegmentDirection),
		segmentReverse = getStoredBoolean(entry, "barSegmentReverse", Bars.DEFAULTS.barSegmentReverse),
		barTexture = resolveBarTexture(entry.barTexture),
		fillColor = getBarModeColor(entry, mode),
		backgroundColor = Helper.NormalizeColor(entry.barBackgroundColor, Bars.DEFAULTS.barBackgroundColor),
		borderColor = Helper.NormalizeColor(entry.barBorderColor, Bars.DEFAULTS.barBorderColor),
		procGlowColor = Helper.NormalizeColor(entry.barProcGlowColor, Bars.DEFAULTS.barProcGlowColor),
		procGlowActive = isBarProcGlowActive(resolvedType, resolvedSpellId),
		borderTexture = resolveBarBorderTexture(entry.barBorderTexture),
		borderOffset = normalizeBarBorderOffset(entry.barBorderOffset, Bars.DEFAULTS.barBorderOffset),
		borderSize = normalizeBarBorderSize(entry.barBorderSize, Bars.DEFAULTS.barBorderSize),
		iconSize = normalizeBarIconSize(entry.barIconSize, Bars.DEFAULTS.barIconSize),
		iconPosition = normalizeBarIconPosition(entry.barIconPosition, Bars.DEFAULTS.barIconPosition),
		iconOffsetX = normalizeBarIconOffset(entry.barIconOffsetX, Bars.DEFAULTS.barIconOffsetX),
		iconOffsetY = normalizeBarIconOffset(entry.barIconOffsetY, Bars.DEFAULTS.barIconOffsetY),
		segmentedCharges = mode == Bars.BAR_MODE.CHARGES and getStoredBoolean(entry, "barChargesSegmented", Bars.DEFAULTS.barChargesSegmented),
		chargesGap = normalizeBarChargesGap(entry.barChargesGap, Bars.DEFAULTS.barChargesGap),
		labelFont = normalizeBarFont(entry.barLabelFont, Bars.DEFAULTS.barLabelFont),
		labelSize = normalizeBarFontSize(entry.barLabelSize, Bars.DEFAULTS.barLabelSize),
		labelStyle = normalizeBarFontStyle(entry.barLabelStyle, Bars.DEFAULTS.barLabelStyle),
		labelColor = Helper.NormalizeColor(entry.barLabelColor, Bars.DEFAULTS.barLabelColor),
		valueFont = normalizeBarFont(entry.barValueFont, Bars.DEFAULTS.barValueFont),
		valueSize = normalizeBarFontSize(entry.barValueSize, Bars.DEFAULTS.barValueSize),
		valueStyle = normalizeBarFontStyle(entry.barValueStyle, Bars.DEFAULTS.barValueStyle),
		valueColor = Helper.NormalizeColor(entry.barValueColor, Bars.DEFAULTS.barValueColor),
		spellId = resolvedSpellId,
	}

	if preview then
		if mode == Bars.BAR_MODE.COOLDOWN then
			state.progress = 0.42
			state.valueText = getCooldownText(icon) or "12.4"
		elseif mode == Bars.BAR_MODE.CHARGES then
			local currentCharges = safeNumber(icon and icon.charges and icon.charges.GetText and icon.charges:GetText())
			state.currentCharges = currentCharges or 1
			state.maxCharges = state.segmentedCharges == true and 2 or max(state.currentCharges or 0, 3)
			state.rechargeProgress = 0.48
			state.progress = clamp((state.currentCharges or 0) / state.maxCharges, 0, 1)
			if state.currentCharges < state.maxCharges then
				state.progress = clamp((state.currentCharges + state.rechargeProgress) / state.maxCharges, 0, 1)
			end
			state.valueText = format("%d/%d", state.currentCharges or 0, state.maxCharges)
		else
			local stackValue = safeNumber(icon and icon.count and icon.count.GetText and icon.count:GetText())
			local stackMax = getStackSessionMax(Helper.GetEntryKey(panelId, entryId), stackValue or 3, true)
			state.progress = clamp((stackValue or 3) / max(stackMax, 1), 0, 1)
			state.valueText = tostring(stackValue or 3)
		end
		return state
	end

	if mode == Bars.BAR_MODE.COOLDOWN then
		if resolvedType == "SPELL" then
			local spellId = resolvedSpellId
			if spellId and CooldownPanels.GetCachedSpellCooldownInfo then
				local durationObject = CooldownPanels.GetCachedSpellCooldownDurationObject and CooldownPanels:GetCachedSpellCooldownDurationObject(spellId) or nil
				local startTime, duration, enabled, rate, _, isActive = CooldownPanels:GetCachedSpellCooldownInfo(spellId)
				if CooldownPanels.IsSpellCooldownInfoActive and CooldownPanels.IsSpellCooldownInfoActive(isActive, enabled, startTime, duration) then
					progress = getCooldownProgress(startTime, duration, rate) or 0
					valueText = durationToText(max(0, (safeNumber(duration) or 0) - (((Api.GetTime and Api.GetTime()) or GetTime()) - (safeNumber(startTime) or 0)) * (safeNumber(rate) or 1)))
					animate = progress < 1
					state.startTime = safeNumber(startTime)
					state.duration = safeNumber(duration)
					state.rate = safeNumber(rate) or 1
					state.fillDurationObject = durationObject
				else
					progress = 1
				end
			end
		elseif resolvedType == "ITEM" or resolvedType == "MACRO" then
			local itemId = getResolvedItemId(entry, macro)
			if itemId then
				local startTime, duration, enabled
				if Api.GetItemCooldownFn then startTime, duration, enabled = Api.GetItemCooldownFn(itemId) end
				if enabled ~= false and enabled ~= 0 and safeNumber(duration) and safeNumber(duration) > 0 then
					progress = getCooldownProgress(startTime, duration, 1) or 0
					valueText = durationToText(max(0, (safeNumber(duration) or 0) - (((Api.GetTime and Api.GetTime()) or GetTime()) - (safeNumber(startTime) or 0))))
					animate = progress < 1
					state.startTime = safeNumber(startTime)
					state.duration = safeNumber(duration)
					state.rate = 1
				else
					progress = 1
				end
			end
			elseif resolvedType == "CDM_AURA" and CooldownPanels.CDMAuras and CooldownPanels.CDMAuras.BuildRuntimeData then
				local runtimeData = CooldownPanels.CDMAuras:BuildRuntimeData(panelId, entryId, entry, nil, nil)
				if runtimeData and runtimeData.buffName then
					state.label = runtimeData.buffName
					state.texture = runtimeData.iconTextureID or state.texture
				end
				if runtimeData and runtimeData.durationActive == true and runtimeData.cooldownDurationObject ~= nil then
					local remaining = getDurationObjectRemaining(runtimeData.cooldownDurationObject)
					local total = getDurationObjectTotal(runtimeData.cooldownDurationObject)
					progress = (remaining and total and total > 0) and clamp(remaining / total, 0, 1) or 0
					valueText = durationToText(getDurationObjectRemaining(runtimeData.cooldownDurationObject))
					animate = true
					state.fillDurationObject = runtimeData.cooldownDurationObject
					state.timerDirection = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
					state.liveValueTextProvider = function()
						return durationToText(getDurationObjectRemaining(runtimeData.cooldownDurationObject))
					end
					state.startTime = safeNumber(runtimeData.cooldownStart)
					state.duration = safeNumber(runtimeData.cooldownDuration)
					state.rate = safeNumber(runtimeData.cooldownRate) or 1
				elseif runtimeData and runtimeData.active == true then
					local fallbackProgress = getCooldownProgress(runtimeData.cooldownStart, runtimeData.cooldownDuration, runtimeData.cooldownRate)
					local fallbackRemaining = max(
						0,
						(safeNumber(runtimeData.cooldownDuration) or 0)
							- (((Api.GetTime and Api.GetTime()) or GetTime()) - (safeNumber(runtimeData.cooldownStart) or 0)) * (safeNumber(runtimeData.cooldownRate) or 1)
					)
					progress = fallbackProgress and clamp(1 - fallbackProgress, 0, 1) or ((safeNumber(runtimeData.cooldownDuration) or 0) > 0 and 1 or 0)
					valueText = fallbackProgress and durationToText(fallbackRemaining) or nil
					animate = fallbackProgress ~= nil and fallbackProgress < 1 or false
					state.timerDirection = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
					state.liveValueTextProvider = fallbackProgress and function()
						local remaining = max(
							0,
							(safeNumber(runtimeData.cooldownDuration) or 0)
								- (((Api.GetTime and Api.GetTime()) or GetTime()) - (safeNumber(runtimeData.cooldownStart) or 0)) * (safeNumber(runtimeData.cooldownRate) or 1)
						)
						return durationToText(remaining)
					end or nil
					state.startTime = safeNumber(runtimeData.cooldownStart)
					state.duration = safeNumber(runtimeData.cooldownDuration)
					state.rate = safeNumber(runtimeData.cooldownRate) or 1
				else
					progress = 1
				end
		end
		state.sourceText = function() return getCooldownText(icon) end
	elseif mode == Bars.BAR_MODE.CHARGES then
		local spellId = resolvedSpellId
		if spellId and CooldownPanels.GetCachedSpellChargesInfo then
			state.entryKey = Helper.GetEntryKey(panelId, entryId)
			refreshChargeBarRuntimeState(state, icon)
			progress = getChargeBarProgress(state)
			valueText = getChargeBarValueText(icon, state.currentCharges, state.maxCharges)
			animate = state.animate == true
		end
	else
		local entryKey = Helper.GetEntryKey(panelId, entryId)
		local stackValue = nil
		if icon and icon.count and icon.count.GetText then stackValue = safeNumber(icon.count:GetText()) end
		if stackValue == nil then
			local shared = CooldownPanels.runtime
			stackValue = safeNumber(shared and shared.actionDisplayCounts and shared.actionDisplayCounts[entryKey] or nil)
		end
		local stackMax = getStackSessionMax(entryKey, stackValue, false)
		if stackValue and stackMax > 0 then
			progress = clamp(stackValue / stackMax, 0, 1)
			valueText = tostring(stackValue)
		else
			progress = 1
		end
	end

	state.progress = progress or 0
	state.valueText = valueText or getCooldownText(icon) or nil
	state.animate = animate == true
	return state
end

local function layoutBarFrame(barFrame, icon, span, layout, state)
	if not (barFrame and icon) then return end
	local slotAnchor = icon.slotAnchor or icon
	local slotSize = safeNumber(icon._eqolBaseSlotSize) or slotAnchor:GetWidth() or 36
	local spacing = Helper.ClampInt(layout and layout.spacing, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.spacing or 2)
	local maxWidth = (slotSize * span) + (max(span - 1, 0) * spacing)
	local configuredWidth = normalizeBarWidth(state and state.barWidth, Bars.DEFAULTS.barWidth)
	local resolvedWidth = configuredWidth > 0 and min(maxWidth, max(BAR_WIDTH_MIN, configuredWidth)) or maxWidth
	local width = pixelSnap(resolvedWidth, slotAnchor.GetEffectiveScale and slotAnchor:GetEffectiveScale() or nil)
	local height = pixelSnap(normalizeBarHeight(state and state.barHeight, max(16, floor(slotSize * 0.72))), slotAnchor.GetEffectiveScale and slotAnchor:GetEffectiveScale() or nil)
	local offsetX = normalizeBarOffset(state and state.barOffsetX, Bars.DEFAULTS.barOffsetX)
	local offsetY = normalizeBarOffset(state and state.barOffsetY, Bars.DEFAULTS.barOffsetY)
	local orientation = normalizeBarOrientation(state and state.orientation, Bars.DEFAULTS.barOrientation)
	local useChargeSegments = state.mode == Bars.BAR_MODE.CHARGES and state.segmentedCharges == true and safeNumber(state.maxCharges) == 2
	local segmentCount = useChargeSegments and 2 or 0
	local gap = useChargeSegments and normalizeBarChargesGap(state.chargesGap, Bars.DEFAULTS.barChargesGap) or 0
	local segmentDirection = useChargeSegments and normalizeBarSegmentDirection(state.segmentDirection, Bars.DEFAULTS.barSegmentDirection) or BAR_ORIENTATION_HORIZONTAL
	local segmentReverse = useChargeSegments and state.segmentReverse == true or false
	local parent = slotAnchor:GetParent() or icon:GetParent() or UIParent
	if barFrame:GetParent() ~= parent then barFrame:SetParent(parent) end
	barFrame:ClearAllPoints()
	barFrame:SetPoint("LEFT", slotAnchor, "LEFT", offsetX, offsetY)
	barFrame:SetFrameStrata((icon.overlay and icon.overlay:GetFrameStrata()) or icon:GetFrameStrata())
	barFrame:SetFrameLevel(((icon.overlay and icon.overlay:GetFrameLevel()) or icon:GetFrameLevel()) + 2)
	if barFrame.body then
		barFrame.body:SetFrameStrata(barFrame:GetFrameStrata())
		barFrame.body:SetFrameLevel(barFrame:GetFrameLevel() + 1)
	end
	if barFrame.fill then barFrame.fill:SetFrameLevel((barFrame.body and barFrame.body:GetFrameLevel() or barFrame:GetFrameLevel()) + 1) end
	if barFrame.borderOverlay then
		barFrame.borderOverlay:SetFrameStrata(barFrame:GetFrameStrata())
		barFrame.borderOverlay:SetFrameLevel((barFrame.body and barFrame.body:GetFrameLevel() or barFrame:GetFrameLevel()) + 2)
	end
	if barFrame.iconOverlay then
		barFrame.iconOverlay:SetFrameStrata(barFrame:GetFrameStrata())
		barFrame.iconOverlay:SetFrameLevel(barFrame:GetFrameLevel() + 5)
	end
	if barFrame.textOverlay then
		barFrame.textOverlay:ClearAllPoints()
		barFrame.textOverlay:SetPoint("TOPLEFT", barFrame.body, "TOPLEFT", 0, 0)
		barFrame.textOverlay:SetPoint("BOTTOMRIGHT", barFrame.body, "BOTTOMRIGHT", 0, 0)
		barFrame.textOverlay:SetFrameStrata(barFrame:GetFrameStrata())
		barFrame.textOverlay:SetFrameLevel(barFrame:GetFrameLevel() + 6)
	end

	local borderSize = normalizeBarBorderSize(state and state.borderSize, Bars.DEFAULTS.barBorderSize)
	local fillTexturePath = state and state.barTexture or resolveBarTexture(Bars.DEFAULTS.barTexture)
	local borderTexturePath = state and state.borderTexture or resolveBarBorderTexture(Bars.DEFAULTS.barBorderTexture)
	applyStatusBarTexture(barFrame.fill, fillTexturePath)
	applyStatusBarOrientation(barFrame.fill, orientation)
	barFrame.fillBg:SetTexture(fillTexturePath)

	local fillColor = Helper.NormalizeColor(state and state.fillColor, getDefaultBarColorForMode(state and state.mode or Bars.BAR_MODE.COOLDOWN))
	local backgroundColor = Helper.NormalizeColor(state and state.backgroundColor, Bars.DEFAULTS.barBackgroundColor)
	local borderColor = Helper.NormalizeColor(state and state.borderColor, Bars.DEFAULTS.barBorderColor)
	if state and state.procGlowActive == true then
		fillColor = Helper.NormalizeColor(state.procGlowColor, fillColor)
		borderColor = Helper.NormalizeColor(state.procGlowColor, borderColor)
	end
	local outerPadding = 2
	local iconSpacing = 4
	local iconSize = state.showIcon and max(12, min(width, height) - (outerPadding * 2)) or 0
	local configuredIconSize = normalizeBarIconSize(state and state.iconSize, Bars.DEFAULTS.barIconSize)
	if configuredIconSize > 0 then iconSize = pixelSnap(configuredIconSize, slotAnchor.GetEffectiveScale and slotAnchor:GetEffectiveScale() or nil) end
	local iconArea = state.showIcon and (iconSize + iconSpacing) or 0
	local iconPosition = normalizeBarIconPosition(state and state.iconPosition, Bars.DEFAULTS.barIconPosition)
	local bodyLeft = outerPadding + ((state.showIcon and iconPosition == BAR_ICON_POSITION_LEFT) and iconArea or 0)
	local bodyRight = outerPadding + ((state.showIcon and iconPosition == BAR_ICON_POSITION_RIGHT) and iconArea or 0)
	local bodyTop = outerPadding + ((state.showIcon and iconPosition == BAR_ICON_POSITION_TOP) and iconArea or 0)
	local bodyBottom = outerPadding + ((state.showIcon and iconPosition == BAR_ICON_POSITION_BOTTOM) and iconArea or 0)
	local bodyWidth = max(1, width)
	local bodyHeight = max(1, height)
	local frameWidth = bodyLeft + bodyWidth + bodyRight
	local frameHeight = bodyTop + bodyHeight + bodyBottom

	if useChargeSegments then
		if segmentDirection == BAR_ORIENTATION_VERTICAL then
			frameHeight = pixelSnap(bodyTop + bodyBottom + (height * segmentCount) + (max(segmentCount - 1, 0) * gap), slotAnchor.GetEffectiveScale and slotAnchor:GetEffectiveScale() or nil)
			bodyHeight = max(1, frameHeight - bodyTop - bodyBottom)
		else
			frameWidth = pixelSnap(bodyLeft + bodyRight + (width * segmentCount) + (max(segmentCount - 1, 0) * gap), slotAnchor.GetEffectiveScale and slotAnchor:GetEffectiveScale() or nil)
			bodyWidth = max(1, frameWidth - bodyLeft - bodyRight)
		end
	end

	barFrame:SetSize(frameWidth, frameHeight)

	barFrame.body:ClearAllPoints()
	barFrame.body:SetPoint("TOPLEFT", barFrame, "TOPLEFT", bodyLeft, -bodyTop)
	barFrame.body:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -bodyRight, bodyBottom)
	applyBackdropFrame(barFrame.body, borderTexturePath, borderSize)
	barFrame.body:SetBackdropColor(0, 0, 0, 0)
	barFrame.body:SetBackdropBorderColor(0, 0, 0, 0)
	barFrame.fillBg:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
	local borderOffset = normalizeBarBorderOffset(state and state.borderOffset, Bars.DEFAULTS.barBorderOffset)
	barFrame.fill:ClearAllPoints()
	barFrame.fill:SetPoint("TOPLEFT", barFrame.body, "TOPLEFT", 0, 0)
	barFrame.fill:SetPoint("BOTTOMRIGHT", barFrame.body, "BOTTOMRIGHT", 0, 0)
	if barFrame.borderOverlay then
		if borderSize > 0 then
			barFrame.borderOverlay:ClearAllPoints()
			barFrame.borderOverlay:SetPoint("TOPLEFT", barFrame.body, "TOPLEFT", -borderOffset, borderOffset)
			barFrame.borderOverlay:SetPoint("BOTTOMRIGHT", barFrame.body, "BOTTOMRIGHT", borderOffset, -borderOffset)
			applyBackdropFrame(barFrame.borderOverlay, borderTexturePath, borderSize)
			barFrame.borderOverlay:SetBackdropColor(0, 0, 0, 0)
			barFrame.borderOverlay:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
			barFrame.borderOverlay:Show()
		else
			barFrame.borderOverlay:Hide()
		end
	end

	if state.showIcon and state.texture then
		barFrame.icon:ClearAllPoints()
		if iconPosition == BAR_ICON_POSITION_RIGHT then
			barFrame.icon:SetPoint("RIGHT", barFrame, "RIGHT", -outerPadding + (state.iconOffsetX or 0), state.iconOffsetY or 0)
		elseif iconPosition == BAR_ICON_POSITION_TOP then
			barFrame.icon:SetPoint("TOP", barFrame, "TOP", state.iconOffsetX or 0, -(outerPadding) + (state.iconOffsetY or 0))
		elseif iconPosition == BAR_ICON_POSITION_BOTTOM then
			barFrame.icon:SetPoint("BOTTOM", barFrame, "BOTTOM", state.iconOffsetX or 0, outerPadding + (state.iconOffsetY or 0))
		else
			barFrame.icon:SetPoint("LEFT", barFrame, "LEFT", outerPadding + (state.iconOffsetX or 0), state.iconOffsetY or 0)
		end
		barFrame.icon:SetSize(iconSize, iconSize)
		barFrame.icon:SetTexture(state.texture)
		barFrame.icon:Show()
	else
		barFrame.icon:Hide()
	end

	local labelDefaultFontPath, labelDefaultFontSize, labelDefaultFontStyle = Helper.GetCountFontDefaults(icon and icon:GetParent() or nil)
	local valueDefaultFontPath, valueDefaultFontSize, valueDefaultFontStyle = labelDefaultFontPath, labelDefaultFontSize, labelDefaultFontStyle
	if CooldownPanels.GetCooldownFontDefaults then
		valueDefaultFontPath, valueDefaultFontSize, valueDefaultFontStyle = CooldownPanels:GetCooldownFontDefaults(icon and icon:GetParent() or nil)
	end
	if useChargeSegments then
		local segmentAxisSize = segmentDirection == BAR_ORIENTATION_VERTICAL and bodyHeight or bodyWidth
		local totalGapSize = max(segmentCount - 1, 0) * gap
		local segmentPrimarySize = max(1, floor((segmentAxisSize - totalGapSize) / segmentCount))
		local remainingPixels = max(0, segmentAxisSize - ((segmentPrimarySize * segmentCount) + totalGapSize))
		Bars.HideForwardHitHandle(barFrame.hitHandle)
		barFrame.fill:Hide()
		barFrame.fillBg:Hide()
		if barFrame.borderOverlay then barFrame.borderOverlay:Hide() end
		for index = 1, segmentCount do
			local segment = ensureBarSegment(barFrame, index)
			local visualIndex = segmentReverse and (segmentCount - index + 1) or index
			local extraPixel = index <= remainingPixels and 1 or 0
			local primarySize = segmentPrimarySize + extraPixel
			local primaryOffset = (visualIndex - 1) * (segmentPrimarySize + gap) + min(visualIndex - 1, remainingPixels)
			segment:ClearAllPoints()
			if segmentDirection == BAR_ORIENTATION_VERTICAL then
				segment:SetPoint("TOPLEFT", barFrame.body, "TOPLEFT", 0, -primaryOffset)
				segment:SetSize(bodyWidth, primarySize)
			else
				segment:SetPoint("TOPLEFT", barFrame.body, "TOPLEFT", primaryOffset, 0)
				segment:SetSize(primarySize, bodyHeight)
			end
			segment:SetFrameStrata(barFrame:GetFrameStrata())
			segment:SetFrameLevel((barFrame.body and barFrame.body:GetFrameLevel() or barFrame:GetFrameLevel()) + 1)
			applyBackdropFrame(segment, borderTexturePath, borderSize)
			segment:SetBackdropColor(0, 0, 0, 0)
			segment:SetBackdropBorderColor(0, 0, 0, 0)
			applyStatusBarTexture(segment.fill, fillTexturePath)
			applyStatusBarOrientation(segment.fill, orientation)
			segment.fill:SetFrameLevel(segment:GetFrameLevel() + 1)
			segment.fill:ClearAllPoints()
			segment.fill:SetPoint("TOPLEFT", segment, "TOPLEFT", 0, 0)
			segment.fill:SetPoint("BOTTOMRIGHT", segment, "BOTTOMRIGHT", 0, 0)
			segment.fillBg:SetTexture(fillTexturePath)
			segment.fillBg:SetVertexColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
			segment.fill:SetStatusBarColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
			if segment.borderOverlay then
				segment.borderOverlay:SetFrameStrata(barFrame:GetFrameStrata())
				segment.borderOverlay:SetFrameLevel(segment:GetFrameLevel() + 2)
				if borderSize > 0 then
					segment.borderOverlay:ClearAllPoints()
					segment.borderOverlay:SetPoint("TOPLEFT", segment, "TOPLEFT", -borderOffset, borderOffset)
					segment.borderOverlay:SetPoint("BOTTOMRIGHT", segment, "BOTTOMRIGHT", borderOffset, -borderOffset)
					applyBackdropFrame(segment.borderOverlay, borderTexturePath, borderSize)
					segment.borderOverlay:SetBackdropColor(0, 0, 0, 0)
					segment.borderOverlay:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
					segment.borderOverlay:Show()
				else
					segment.borderOverlay:Hide()
				end
			end
			Bars.ConfigureForwardHitHandle(segment.hitHandle, segment, icon and icon.layoutHandle or nil)
			Bars.ConfigureFreeMoveHandle(segment.hitHandle, barFrame, icon)
			segment:Show()
		end
		hideUnusedBarSegments(barFrame, segmentCount + 1)
		barFrame._eqolSegmentCount = segmentCount
		local gateDurationObject = state.lastNonGCDCooldownActive == true and state.lastNonGCDCooldownDurationObject or nil
		local gateCooldown = ensureBarCooldownGate(barFrame)
		setCooldownFrameDuration(gateCooldown, gateDurationObject)
		local gateActive = gateCooldown and gateCooldown.IsShown and gateCooldown:IsShown() or false
		local previousGateActive = barFrame._eqolChargeGateActive == true
		if gateActive ~= previousGateActive then
			if gateActive then
				barFrame._eqolSegment1Generation = (barFrame._eqolSegment1Generation or 0) + 1
			else
				barFrame._eqolSegment2Generation = (barFrame._eqolSegment2Generation or 0) + 1
			end
			barFrame._eqolChargeGateActive = gateActive
		end
		local segment1Alpha = nil
		local segment2Alpha = nil
		for index = 1, segmentCount do
			local segment = barFrame.segments and barFrame.segments[index] or nil
			if segment and segment.fill then
				if index == 1 then
					if gateActive and gateDurationObject then
						setStatusBarTimerDuration(segment.fill, gateDurationObject, "seg1:" .. tostring(barFrame._eqolSegment1Generation or 0))
					else
						setStatusBarImmediateValue(segment.fill, 1)
					end
				elseif gateActive then
					setStatusBarImmediateValue(segment.fill, 0)
				elseif state.chargeInfoActive == true and state.chargeDurationObject ~= nil then
					setStatusBarTimerDuration(segment.fill, state.chargeDurationObject, "seg2:" .. tostring(barFrame._eqolSegment2Generation or 0))
				else
					setStatusBarImmediateValue(segment.fill, 1)
				end
				local fillTexture = segment.fill.GetStatusBarTexture and segment.fill:GetStatusBarTexture() or nil
				if fillTexture and fillTexture.SetAlpha then fillTexture:SetAlpha(1) end
				local alpha = fillTexture and fillTexture.GetAlpha and fillTexture:GetAlpha() or nil
				if index == 1 then
					segment1Alpha = alpha
				elseif index == 2 then
					segment2Alpha = alpha
				end
			end
		end
		if state.preview ~= true then
			writeBarsDebug("layoutChargeSegments", {
				panelId = state.panelId,
				entryId = state.entryId,
				spellId = state.spellId,
				displayedCharges = state.currentCharges,
				maxCharges = state.maxCharges,
				cooldownGCD = state.cooldownGCD == true,
				lastNonGCDCooldownActive = state.lastNonGCDCooldownActive == true,
				gateActive = gateActive == true,
				segmentReverse = segmentReverse == true,
				seg1Alpha = segment1Alpha,
				seg2Alpha = segment2Alpha,
				iconChargeText = icon and icon.charges and icon.charges.GetText and getDebugText(icon.charges:GetText()) or nil,
				iconCooldownText = getCooldownText(icon),
			})
		end
	else
		hideUnusedBarSegments(barFrame, 1)
		barFrame._eqolSegmentCount = 0
		barFrame.fill:Show()
		barFrame.fillBg:Show()
		barFrame.fill:SetStatusBarColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
		if not setStatusBarTimerDuration(barFrame.fill, state.fillDurationObject, nil, state.timerDirection) then
			barFrame.fill:SetMinMaxValues(0, 1)
			setStatusBarImmediateValue(barFrame.fill, state.progress or 0)
		end
		Bars.ConfigureForwardHitHandle(barFrame.hitHandle, barFrame.body, icon and icon.layoutHandle or nil)
		Bars.ConfigureFreeMoveHandle(barFrame.hitHandle, barFrame, icon)
	end

	local textInset = 4
	local maxValueWidth = max(24, bodyWidth - (textInset * 2))
	local reserveValueWidth = state.showValueText and min(max(48, floor(bodyWidth * 0.38)), maxValueWidth) or 0
	if state.showLabel and state.label then
		applyFontStringStyle(barFrame.label, state.labelFont, state.labelSize, state.labelStyle, state.labelColor, labelDefaultFontPath, labelDefaultFontSize, labelDefaultFontStyle)
		barFrame.label:ClearAllPoints()
		if orientation == BAR_ORIENTATION_VERTICAL then
			barFrame.label:SetJustifyH("CENTER")
			barFrame.label:SetPoint("TOPLEFT", barFrame.body, "TOPLEFT", textInset, -textInset)
			barFrame.label:SetPoint("TOPRIGHT", barFrame.body, "TOPRIGHT", -textInset, -textInset)
		else
			barFrame.label:SetJustifyH("LEFT")
			barFrame.label:SetPoint("LEFT", barFrame.body, "LEFT", textInset, 0)
			barFrame.label:SetPoint("RIGHT", barFrame.body, "RIGHT", state.showValueText and -(textInset + reserveValueWidth) or -textInset, 0)
		end
		barFrame.label:SetText(state.label)
		barFrame.label:Show()
	else
		barFrame.label:Hide()
	end
	if state.showValueText and state.valueText then
		applyFontStringStyle(barFrame.value, state.valueFont, state.valueSize, state.valueStyle, state.valueColor, valueDefaultFontPath, valueDefaultFontSize, valueDefaultFontStyle)
		barFrame.value:ClearAllPoints()
		if orientation == BAR_ORIENTATION_VERTICAL then
			barFrame.value:SetJustifyH("CENTER")
			barFrame.value:SetPoint("BOTTOMLEFT", barFrame.body, "BOTTOMLEFT", textInset, textInset)
			barFrame.value:SetPoint("BOTTOMRIGHT", barFrame.body, "BOTTOMRIGHT", -textInset, textInset)
		else
			barFrame.value:SetJustifyH("RIGHT")
			barFrame.value:SetWidth(state.showLabel and reserveValueWidth or 0)
			barFrame.value:SetPoint("RIGHT", barFrame.body, "RIGHT", -textInset, 0)
			if not state.showLabel then
				barFrame.value:SetPoint("LEFT", barFrame.body, "LEFT", textInset, 0)
			end
		end
		barFrame.value:SetText(state.valueText)
		barFrame.value:Show()
	else
		barFrame.value:Hide()
	end
	Bars.ConfigureBarValueTextUpdater(barFrame, state)
	barFrame:SetAlpha(icon:GetAlpha())
	barFrame._eqolBarState = state
	barFrame:Show()
end

refreshPanelContext = function(panelId)
	local panel = CooldownPanels.GetPanel and CooldownPanels:GetPanel(panelId) or nil
	if not panel then return end
	if Helper.InvalidateFixedLayoutCache then Helper.InvalidateFixedLayoutCache(panel) end
	if CooldownPanels.RefreshPanelForCurrentEditContext then
		CooldownPanels:RefreshPanelForCurrentEditContext(panelId, true)
	else
		if CooldownPanels.RefreshPanel then CooldownPanels:RefreshPanel(panelId) end
		if CooldownPanels.IsEditorOpen and CooldownPanels:IsEditorOpen() and CooldownPanels.RefreshEditor then CooldownPanels:RefreshEditor() end
	end
end

local function updateStandaloneEntryDialogForBars(panelId, entryId)
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	if not (panelId and entryId and CooldownPanels.GetLayoutEntryStandaloneMenuState) then return false end
	local state = CooldownPanels:GetLayoutEntryStandaloneMenuState(false)
	local activeDialog = state and state.dialog or nil
	if not (state and activeDialog and normalizeId(state.panelId) == panelId and normalizeId(state.entryId) == entryId) then return false end
	local _, entry = getBarEntry(panelId, entryId)
	local title = entry and CooldownPanels.GetEntryStandaloneTitle and CooldownPanels:GetEntryStandaloneTitle(entry) or nil
	if activeDialog.context and title then activeDialog.context.title = title end
	if activeDialog.Title and title then activeDialog.Title:SetText(title) end
	if activeDialog.UpdateSettings then activeDialog:UpdateSettings() end
	if activeDialog.UpdateButtons then activeDialog:UpdateButtons() end
	if activeDialog.Layout then activeDialog:Layout() end
	return true
end

local function isStandaloneDialogDragActive()
	if type(IsMouseButtonDown) ~= "function" then return false end
	return IsMouseButtonDown("LeftButton") == true
end

local function scheduleStandaloneEntryDialogUpdate(panelId, entryId)
	if not (panelId and entryId) then return end
	Bars._eqolPendingDialogRefresh = Bars._eqolPendingDialogRefresh or {}
	local key = tostring(panelId) .. ":" .. tostring(entryId)
	if Bars._eqolPendingDialogRefresh[key] then return end
	if not (C_Timer and C_Timer.After) then
		updateStandaloneEntryDialogForBars(panelId, entryId)
		return
	end
	Bars._eqolPendingDialogRefresh[key] = true
	C_Timer.After(0, function()
		Bars._eqolPendingDialogRefresh[key] = nil
		if isStandaloneDialogDragActive() then
			scheduleStandaloneEntryDialogUpdate(panelId, entryId)
			return
		end
		updateStandaloneEntryDialogForBars(panelId, entryId)
	end)
end

refreshStandaloneEntryDialogForBars = function(panelId, entryId, reopen)
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	if not (panelId and entryId and CooldownPanels.GetLayoutEntryStandaloneMenuState and CooldownPanels.HideLayoutEntryStandaloneMenu and CooldownPanels.OpenLayoutEntryStandaloneMenu) then
		return
	end
	local state = CooldownPanels:GetLayoutEntryStandaloneMenuState(false)
	if not state or normalizeId(state.panelId) ~= panelId or normalizeId(state.entryId) ~= entryId then return end
	if reopen ~= true then
		if isStandaloneDialogDragActive() then
			scheduleStandaloneEntryDialogUpdate(panelId, entryId)
			return
		end
		if updateStandaloneEntryDialogForBars(panelId, entryId) then return end
	end
	local anchorFrame = state.anchorFrame or state.dialog or state.hostFrame
	CooldownPanels:HideLayoutEntryStandaloneMenu(panelId)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if CooldownPanels.IsPanelLayoutEditActive and not CooldownPanels:IsPanelLayoutEditActive(panelId) then return end
			CooldownPanels:OpenLayoutEntryStandaloneMenu(panelId, entryId, anchorFrame)
		end)
	else
		CooldownPanels:OpenLayoutEntryStandaloneMenu(panelId, entryId, anchorFrame)
	end
end

local function setEntryDisplayMode(panelId, entryId, displayMode, barMode)
	mutateBarEntry(panelId, entryId, function(entry)
		entry.displayMode = normalizeDisplayMode(displayMode, Bars.DEFAULTS.displayMode)
		if entry.displayMode == Bars.DISPLAY_MODE.BAR and barMode then entry.barMode = normalizeBarMode(barMode, entry.barMode or Bars.DEFAULTS.barMode) end
		if entry.displayMode == Bars.DISPLAY_MODE.BAR and type(entry.barColor) ~= "table" then entry.barColor = getDefaultBarColorForMode(entry.barMode) end
	end, true)
end

local function setEntryBarMode(panelId, entryId, barMode)
	mutateBarEntry(panelId, entryId, function(entry)
		entry.displayMode = Bars.DISPLAY_MODE.BAR
		entry.barMode = normalizeBarMode(barMode, entry.barMode or Bars.DEFAULTS.barMode)
		if type(entry.barColor) ~= "table" then entry.barColor = getDefaultBarColorForMode(entry.barMode) end
	end)
end

local function setEntryBarWidth(panelId, entryId, width)
	mutateBarEntry(panelId, entryId, function(entry)
		entry.barWidth = normalizeBarWidth(width, entry.barWidth or Bars.DEFAULTS.barWidth)
	end)
end

local function setEntryBarSpan(panelId, entryId, span)
	mutateBarEntry(panelId, entryId, function(entry, panel)
		entry.barSpan = normalizeBarSpan(span, entry.barSpan or Bars.DEFAULTS.barSpan)
		local slotSize = getEntryBaseSlotSize(panel, entry)
		local spacing = Helper.ClampInt(panel and panel.layout and panel.layout.spacing, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.spacing or 2)
		entry.barWidth = max(slotSize, (slotSize * entry.barSpan) + (max(entry.barSpan - 1, 0) * spacing))
	end)
end

local function toggleEntryBarFlag(panelId, entryId, field)
	mutateBarEntry(panelId, entryId, function(entry)
		entry[field] = entry[field] ~= true
	end)
end

local function setEntryBarBoolean(panelId, entryId, field, value)
	mutateBarEntry(panelId, entryId, function(entry)
		entry[field] = value == true
	end)
end

local function setEntryBarField(panelId, entryId, field, value)
	mutateBarEntry(panelId, entryId, function(entry)
		entry[field] = value
	end)
end

local function showBarModeMenu(owner, panelId, entryId)
	if not (owner and Api.MenuUtil and Api.MenuUtil.CreateContextMenu) then return end
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	local panel = CooldownPanels.GetPanel and CooldownPanels:GetPanel(panelId) or nil
	local entry = panel and panel.entries and panel.entries[entryId] or nil
	if not entry then return end
	normalizeBarEntry(entry)

	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_COOLDOWN_PANEL_BAR_MODE")
		rootDescription:CreateTitle(getEntryLabel(entry) or (L["CooldownPanelBars"] or "Bars"))
		rootDescription:CreateButton(L["CooldownPanelSwitchToButton"] or "Switch to Button", function()
			setEntryDisplayMode(panelId, entryId, Bars.DISPLAY_MODE.BUTTON)
		end)
		rootDescription:CreateDivider()
		rootDescription:CreateTitle(L["CooldownPanelMode"] or "Mode")
		rootDescription:CreateRadio(getEntryBarModeLabel(Bars.BAR_MODE.COOLDOWN), function()
			return normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode) == Bars.BAR_MODE.COOLDOWN
		end, function()
			setEntryBarMode(panelId, entryId, Bars.BAR_MODE.COOLDOWN)
		end)
		if supportsBarMode(entry, Bars.BAR_MODE.CHARGES) then
			rootDescription:CreateRadio(getEntryBarModeLabel(Bars.BAR_MODE.CHARGES), function()
				return normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode) == Bars.BAR_MODE.CHARGES
			end, function()
				setEntryBarMode(panelId, entryId, Bars.BAR_MODE.CHARGES)
			end)
		end
		if supportsBarMode(entry, Bars.BAR_MODE.STACKS) then
			rootDescription:CreateRadio(getEntryBarModeLabel(Bars.BAR_MODE.STACKS), function()
				return normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode) == Bars.BAR_MODE.STACKS
			end, function()
				setEntryBarMode(panelId, entryId, Bars.BAR_MODE.STACKS)
			end)
		end
		rootDescription:CreateDivider()
		rootDescription:CreateTitle(L["CooldownPanelBarSpan"] or "Span")
		for span = 1, 4 do
			rootDescription:CreateRadio(format("%d %s", span, span == 1 and (L["CooldownPanelSlotType"] or "Slot"):lower() or (L["CooldownPanelSlotTypePlural"] or "Slots"):lower()), function()
				return normalizeBarSpan(entry.barSpan, Bars.DEFAULTS.barSpan) == span
			end, function()
				setEntryBarSpan(panelId, entryId, span)
			end)
		end
		rootDescription:CreateDivider()
		rootDescription:CreateCheckbox(L["CooldownPanelBarShowIcon"] or "Show icon", function() return entry.barShowIcon == true end, function()
			toggleEntryBarFlag(panelId, entryId, "barShowIcon")
		end)
		rootDescription:CreateCheckbox(L["CooldownPanelBarShowLabel"] or "Show label", function() return entry.barShowLabel == true end, function()
			toggleEntryBarFlag(panelId, entryId, "barShowLabel")
		end)
		rootDescription:CreateCheckbox(L["CooldownPanelBarShowValueText"] or "Show value", function() return entry.barShowValueText == true end, function()
			toggleEntryBarFlag(panelId, entryId, "barShowValueText")
		end)
	end)
end

local function configureModeButton(panelId, panel, icon, actualEntryId, mappedEntryId, slotColumn, slotRow)
	if icon and icon._eqolBarsModeButton then icon._eqolBarsModeButton:Hide() end
end

Bars.SuppressIconLayoutHandles = function(icon)
	if not icon then return end
	if icon.layoutHandle and icon.layoutHandle.EnableMouse then icon.layoutHandle:EnableMouse(false) end
	if icon.slotAnchorHandle and icon.slotAnchorHandle.EnableMouse then icon.slotAnchorHandle:EnableMouse(false) end
end

local function applyBarsToPanel(panelId, preview)
	local panel = CooldownPanels.GetPanel and CooldownPanels:GetPanel(panelId) or nil
	if not panel then return end
	panel.layout = panel.layout or {}
	local fixedLayout = Helper.IsFixedLayout and Helper.IsFixedLayout(panel.layout) or false
	local cache = fixedLayout and Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	cache = augmentFixedLayoutCache(panel, cache)
	local runtime = CooldownPanels.runtime and CooldownPanels.runtime[panelId] or nil
	local frame = runtime and runtime.frame or nil
	if not frame or not frame.icons then return end

	local layoutEditActive = CooldownPanels.IsPanelLayoutEditActive and CooldownPanels:IsPanelLayoutEditActive(panelId) or false
	for _, icon in ipairs(frame.icons) do
		local entryId = normalizeId(icon.entryId)
		local slotColumn = Helper.NormalizeSlotCoordinate(icon._eqolPreviewCellColumn or icon._eqolLayoutSlotColumn)
		local slotRow = Helper.NormalizeSlotCoordinate(icon._eqolPreviewCellRow or icon._eqolLayoutSlotRow)
		local entry = entryId and panel.entries and panel.entries[entryId] or nil
		local displayMode = entry and normalizeDisplayMode(entry.displayMode, Bars.DEFAULTS.displayMode) or Bars.DISPLAY_MODE.BUTTON
		local reservedOwnerId = nil
		if not entryId and fixedLayout and slotColumn and slotRow then
			reservedOwnerId = select(1, getReservedOwnerForCell(panel, slotColumn, slotRow))
		end
		local reservedEntry = reservedOwnerId and panel.entries and panel.entries[reservedOwnerId] or nil
		local barFrame = ensureBarFrame(icon)
		hideBarPresentation(icon)

		if entry and displayMode == Bars.DISPLAY_MODE.BAR and fixedLayout and isAnchorCell(panel, entryId, slotColumn, slotRow) then
			local state = buildBarState(panelId, entryId, entry, icon, preview)
			local span = getEffectiveBarSpan(panel, entryId)
			if state then
				applyNativeSuppression(icon)
				layoutBarFrame(barFrame, icon, span, panel.layout, state)
				stopBarAnimation(barFrame)
			end
		elseif layoutEditActive and fixedLayout and not entry and reservedOwnerId and reservedEntry then
			applyReservedGhost(icon, reservedEntry, slotColumn, slotRow)
		elseif icon and icon.staticText and icon._eqolBarsReservedSlot then
			icon.staticText:Hide()
		end
	end
end

local originalCreateEntry = Helper.CreateEntry
Helper.CreateEntry = function(entryType, idValue, defaults)
	local entry = originalCreateEntry(entryType, idValue, defaults)
	normalizeBarEntry(entry)
	return entry
end

local originalNormalizeEntry = Helper.NormalizeEntry
Helper.NormalizeEntry = function(entry, defaults)
	originalNormalizeEntry(entry, defaults)
	normalizeBarEntry(entry)
end

local originalGetFixedLayoutCache = Helper.GetFixedLayoutCache
if originalGetFixedLayoutCache then
	Helper.GetFixedLayoutCache = function(panel)
		return augmentFixedLayoutCache(panel, originalGetFixedLayoutCache(panel))
	end
end

local originalBuildFixedSlotEntryIds = Helper.BuildFixedSlotEntryIds
if originalBuildFixedSlotEntryIds then
	Helper.BuildFixedSlotEntryIds = function(panel, filterFn, includePreviewPadding)
		local slotEntryIds, count, columns, rows = originalBuildFixedSlotEntryIds(panel, filterFn, includePreviewPadding)
		if panel and filterFn == nil and includePreviewPadding ~= true then
			local cache = originalGetFixedLayoutCache and originalGetFixedLayoutCache(panel) or nil
			augmentFixedLayoutCache(panel, cache)
		end
		return slotEntryIds, count, columns, rows
	end
end

local originalGetEntryAtUngroupedFixedCell = CooldownPanels.GetEntryAtUngroupedFixedCell
function CooldownPanels:GetEntryAtUngroupedFixedCell(panel, column, row, skipEntryId)
	local ownerId, ownerEntry = getReservedOwnerForCell(panel, column, row, skipEntryId)
	if ownerId then return ownerId, ownerEntry end
	return originalGetEntryAtUngroupedFixedCell(self, panel, column, row, skipEntryId)
end

local originalGetEntryAtStaticGroupCell = CooldownPanels.GetEntryAtStaticGroupCell
function CooldownPanels:GetEntryAtStaticGroupCell(panel, groupId, column, row, skipEntryId)
	local ownerId, ownerEntry = getReservedOwnerForCell(panel, column, row, skipEntryId)
	if ownerId then
		local ownerGroupId = ownerEntry and Helper.NormalizeFixedGroupId(ownerEntry.fixedGroupId) or nil
		if ownerGroupId == Helper.NormalizeFixedGroupId(groupId) then return ownerId, ownerEntry end
	end
	return originalGetEntryAtStaticGroupCell(self, panel, groupId, column, row, skipEntryId)
end

local originalUpdatePreviewIcons = CooldownPanels.UpdatePreviewIcons
function CooldownPanels:UpdatePreviewIcons(panelId, countOverride)
	originalUpdatePreviewIcons(self, panelId, countOverride)
	applyBarsToPanel(panelId, true)
end

local originalUpdateRuntimeIcons = CooldownPanels.UpdateRuntimeIcons
function CooldownPanels:UpdateRuntimeIcons(panelId)
	originalUpdateRuntimeIcons(self, panelId)
	writeBarsDebug("updateRuntimeIcons", { panelId = panelId })
	applyBarsToPanel(panelId, false)
end

local originalConfigureEditModePanelIcon = CooldownPanels.ConfigureEditModePanelIcon
function CooldownPanels:ConfigureEditModePanelIcon(panelId, icon, entryId, slotColumn, slotRow)
	local panel = self.GetPanel and self:GetPanel(panelId) or nil
	local fixedLayout = panel and Helper.IsFixedLayout and Helper.IsFixedLayout(panel.layout) or false
	local mappedEntryId = normalizeId(entryId)
	local reservedOwnerId = nil
	local reservedEntry = nil
	if mappedEntryId == nil and fixedLayout then
		reservedOwnerId = select(1, getReservedOwnerForCell(panel, slotColumn, slotRow))
		if reservedOwnerId then
			reservedEntry = panel and panel.entries and panel.entries[reservedOwnerId] or nil
			mappedEntryId = reservedOwnerId
			icon._eqolBarsReservedOwnerId = reservedOwnerId
			icon._eqolBarsReservedSlot = true
		else
			icon._eqolBarsReservedOwnerId = nil
			icon._eqolBarsReservedSlot = nil
		end
	else
		icon._eqolBarsReservedOwnerId = nil
		icon._eqolBarsReservedSlot = nil
	end
	originalConfigureEditModePanelIcon(self, panelId, icon, mappedEntryId, slotColumn, slotRow)
	local mappedEntry = mappedEntryId and panel and panel.entries and panel.entries[mappedEntryId] or nil
	if fixedLayout and mappedEntry and normalizeDisplayMode(mappedEntry.displayMode, Bars.DEFAULTS.displayMode) == Bars.DISPLAY_MODE.BAR and isAnchorCell(panel, mappedEntryId, slotColumn, slotRow) then
		Bars.SuppressIconLayoutHandles(icon)
	elseif fixedLayout and normalizeId(entryId) == nil and reservedOwnerId and reservedEntry then
		Bars.SuppressIconLayoutHandles(icon)
	end
	configureModeButton(panelId, panel, icon, normalizeId(entryId), mappedEntryId, slotColumn, slotRow)
	configureBarDragPreview(panelId, panel, icon, normalizeId(entryId), slotColumn, slotRow)
end

local function normalizeCDMAuraAlwaysShowModeValue(value, fallback)
	local mode = type(value) == "string" and string.upper(value) or nil
	if mode == "SHOW" or mode == "DESATURATE" or mode == "HIDE" then return mode end
	return fallback or "HIDE"
end

local function getStandaloneBarEntry(panelId, entryId)
	local panel, entry = getBarEntry(panelId, entryId)
	if entry then normalizeBarEntry(entry) end
	return panel, entry
end

local function getStandaloneBarFontValue(value)
	if CooldownPanels.GetFontDropdownValue then return CooldownPanels:GetFontDropdownValue(value) end
	if hasTextValue(value) then return value end
	if CooldownPanels.GetGlobalFontConfigKey then return CooldownPanels:GetGlobalFontConfigKey() end
	return "__EQOL_GLOBAL_FONT__"
end

local function getStandaloneBarVisibility(panelId, entryId, field)
	local panel, entry = getStandaloneBarEntry(panelId, entryId)
	local layout = panel and panel.layout or nil
	if entry and entry.cooldownVisibilityUseGlobal == false then return entry[field] == true end
	return layout and layout[field] == true or false
end

local function getStandaloneBarCDMAuraMode(panelId, entryId)
	local panel, entry = getStandaloneBarEntry(panelId, entryId)
	local layout = panel and panel.layout or nil
	local fallback = layout and layout.cdmAuraAlwaysShowMode or "HIDE"
	if entry and entry.cdmAuraAlwaysShowUseGlobal == false then return normalizeCDMAuraAlwaysShowModeValue(entry.cdmAuraAlwaysShowMode, fallback) end
	return normalizeCDMAuraAlwaysShowModeValue(fallback, "HIDE")
end

local function createBarStandaloneSettingsContext(panelId, entryId)
	local SettingType = getSettingType()
	local panel, entry = getStandaloneBarEntry(panelId, entryId)
	if not (SettingType and panel and entry) then return nil end

	local runtime = CooldownPanels.runtime and CooldownPanels.runtime[normalizeId(panelId)] or nil
	local hostFrame = runtime and runtime.frame or nil
	local labelDefaultFontPath, labelDefaultFontSize, labelDefaultFontStyle = Helper.GetCountFontDefaults(hostFrame)
	local valueDefaultFontPath, valueDefaultFontSize, valueDefaultFontStyle = labelDefaultFontPath, labelDefaultFontSize, labelDefaultFontStyle
	if CooldownPanels.GetCooldownFontDefaults then
		valueDefaultFontPath, valueDefaultFontSize, valueDefaultFontStyle = CooldownPanels:GetCooldownFontDefaults(hostFrame)
	end

	return {
		panelId = panelId,
		entryId = entryId,
		SettingType = SettingType,
		labelDefaultFontPath = labelDefaultFontPath,
		labelDefaultFontSize = labelDefaultFontSize,
		labelDefaultFontStyle = labelDefaultFontStyle,
		valueDefaultFontPath = valueDefaultFontPath,
		valueDefaultFontSize = valueDefaultFontSize,
		valueDefaultFontStyle = valueDefaultFontStyle,
	}
end

local function getStandaloneBarContextPanelEntry(ctx)
	return getStandaloneBarEntry(ctx.panelId, ctx.entryId)
end

local function getStandaloneBarContextEntry(ctx)
	local _, entry = getStandaloneBarContextPanelEntry(ctx)
	return entry
end

local function appendBarStandaloneAppearanceSettings(settings, ctx)
	local panelId = ctx.panelId
	local entryId = ctx.entryId
	local SettingType = ctx.SettingType

	settings[#settings + 1] = {
		name = L["CooldownPanelBars"] or "Bars",
		kind = SettingType.Collapsible,
		id = "eqolCooldownPanelStandaloneBar",
		defaultCollapsed = false,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelMode"] or "Mode",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBar",
		height = 140,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarMode(currentEntry and currentEntry.barMode, Bars.DEFAULTS.barMode)
		end,
		set = function(_, value) setEntryBarMode(panelId, entryId, value) end,
		generator = function(_, root)
			local currentEntry = getStandaloneBarContextEntry(ctx)
			if not currentEntry then return end
			for _, option in ipairs({
				{ value = Bars.BAR_MODE.COOLDOWN, label = getEntryBarModeLabel(Bars.BAR_MODE.COOLDOWN) },
				{ value = Bars.BAR_MODE.CHARGES, label = getEntryBarModeLabel(Bars.BAR_MODE.CHARGES) },
				{ value = Bars.BAR_MODE.STACKS, label = getEntryBarModeLabel(Bars.BAR_MODE.STACKS) },
			}) do
				if supportsBarMode(currentEntry, option.value) then
					root:CreateRadio(option.label, function()
						local refreshedEntry = getStandaloneBarContextEntry(ctx)
						return normalizeBarMode(refreshedEntry and refreshedEntry.barMode, Bars.DEFAULTS.barMode) == option.value
					end, function()
						setEntryBarMode(panelId, entryId, option.value)
					end)
				end
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarWidth"] or "Bar width",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBar",
		minValue = BAR_WIDTH_MIN,
		maxValue = BAR_WIDTH_MAX,
		valueStep = 1,
		allowInput = true,
		get = function()
			local panelRef, entryRef = getStandaloneBarContextPanelEntry(ctx)
			local configuredWidth = normalizeBarWidth(entryRef and entryRef.barWidth, Bars.DEFAULTS.barWidth)
			if configuredWidth > 0 then return configuredWidth end
			local slotSize = getEntryBaseSlotSize(panelRef, entryRef)
			local spacing = Helper.ClampInt(panelRef and panelRef.layout and panelRef.layout.spacing, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.spacing or 2)
			local span = normalizeBarSpan(entryRef and entryRef.barSpan, Bars.DEFAULTS.barSpan)
			return max(slotSize, (slotSize * span) + (max(span - 1, 0) * spacing))
		end,
		set = function(_, value) setEntryBarWidth(panelId, entryId, value) end,
		formatter = function(value) return tostring(Helper.ClampInt(value, BAR_WIDTH_MIN, BAR_WIDTH_MAX, BAR_WIDTH_MIN)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarHeight"] or "Bar height",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBar",
		minValue = BAR_HEIGHT_MIN,
		maxValue = BAR_HEIGHT_MAX,
		valueStep = 1,
		allowInput = true,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarHeight(currentEntry and currentEntry.barHeight, Bars.DEFAULTS.barHeight)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barHeight", Helper.ClampInt(value, BAR_HEIGHT_MIN, BAR_HEIGHT_MAX, Bars.DEFAULTS.barHeight)) end,
		formatter = function(value) return tostring(Helper.ClampInt(value, BAR_HEIGHT_MIN, BAR_HEIGHT_MAX, Bars.DEFAULTS.barHeight)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarOrientation"] or "Bar orientation",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBar",
		height = 120,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarOrientation(currentEntry and currentEntry.barOrientation, Bars.DEFAULTS.barOrientation)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barOrientation", normalizeBarOrientation(value, Bars.DEFAULTS.barOrientation)) end,
		generator = function(_, root)
			for _, option in ipairs({
				{ value = BAR_ORIENTATION_HORIZONTAL, label = L["CooldownPanelBarOrientationHorizontal"] or "Horizontal" },
				{ value = BAR_ORIENTATION_VERTICAL, label = L["CooldownPanelBarOrientationVertical"] or "Vertical" },
			}) do
				root:CreateRadio(option.label, function()
					local currentEntry = getStandaloneBarContextEntry(ctx)
					return normalizeBarOrientation(currentEntry and currentEntry.barOrientation, Bars.DEFAULTS.barOrientation) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "barOrientation", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarOffsetX"] or "Bar X",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBar",
		minValue = BAR_OFFSET_MIN,
		maxValue = BAR_OFFSET_MAX,
		valueStep = 1,
		allowInput = true,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarOffset(currentEntry and currentEntry.barOffsetX, Bars.DEFAULTS.barOffsetX)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barOffsetX", normalizeBarOffset(value, Bars.DEFAULTS.barOffsetX)) end,
		formatter = function(value) return tostring(normalizeBarOffset(value, Bars.DEFAULTS.barOffsetX)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarOffsetY"] or "Bar Y",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBar",
		minValue = BAR_OFFSET_MIN,
		maxValue = BAR_OFFSET_MAX,
		valueStep = 1,
		allowInput = true,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarOffset(currentEntry and currentEntry.barOffsetY, Bars.DEFAULTS.barOffsetY)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barOffsetY", normalizeBarOffset(value, Bars.DEFAULTS.barOffsetY)) end,
		formatter = function(value) return tostring(normalizeBarOffset(value, Bars.DEFAULTS.barOffsetY)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarTexture"] or "Bar texture",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBar",
		height = BAR_TEXTURE_MENU_HEIGHT,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getBarTextureSelection(currentEntry)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barTexture", value) end,
		generator = function(_, root)
			for _, option in ipairs(getBarTextureOptions()) do
				root:CreateRadio(option.label, function()
					local currentEntry = getStandaloneBarContextEntry(ctx)
					return getBarTextureSelection(currentEntry) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "barTexture", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarColor"] or "Bar color",
		kind = SettingType.Color,
		parentId = "eqolCooldownPanelStandaloneBar",
		hasOpacity = true,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			local color = getBarModeColor(currentEntry, normalizeBarMode(currentEntry and currentEntry.barMode, Bars.DEFAULTS.barMode))
			return { r = color[1], g = color[2], b = color[3], a = color[4] }
		end,
		set = function(_, value)
			local currentEntry = getStandaloneBarContextEntry(ctx)
			local fallback = getDefaultBarColorForMode(normalizeBarMode(currentEntry and currentEntry.barMode, Bars.DEFAULTS.barMode))
			setEntryBarField(panelId, entryId, "barColor", Helper.NormalizeColor(value, fallback))
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarProcGlowColor"] or "Proc glow color",
		kind = SettingType.Color,
		parentId = "eqolCooldownPanelStandaloneBar",
		hasOpacity = true,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			local color = Helper.NormalizeColor(currentEntry and currentEntry.barProcGlowColor, Bars.DEFAULTS.barProcGlowColor)
			return { r = color[1], g = color[2], b = color[3], a = color[4] }
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barProcGlowColor", Helper.NormalizeColor(value, Bars.DEFAULTS.barProcGlowColor)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarBackgroundColor"] or "Background color",
		kind = SettingType.Color,
		parentId = "eqolCooldownPanelStandaloneBar",
		hasOpacity = true,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			local color = Helper.NormalizeColor(currentEntry and currentEntry.barBackgroundColor, Bars.DEFAULTS.barBackgroundColor)
			return { r = color[1], g = color[2], b = color[3], a = color[4] }
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barBackgroundColor", Helper.NormalizeColor(value, Bars.DEFAULTS.barBackgroundColor)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarBorderSize"] or "Border size",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBar",
		minValue = BAR_BORDER_SIZE_MIN,
		maxValue = BAR_BORDER_SIZE_MAX,
		valueStep = 1,
		allowInput = true,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarBorderSize(currentEntry and currentEntry.barBorderSize, Bars.DEFAULTS.barBorderSize)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barBorderSize", Helper.ClampInt(value, BAR_BORDER_SIZE_MIN, BAR_BORDER_SIZE_MAX, Bars.DEFAULTS.barBorderSize)) end,
		formatter = function(value) return tostring(Helper.ClampInt(value, BAR_BORDER_SIZE_MIN, BAR_BORDER_SIZE_MAX, Bars.DEFAULTS.barBorderSize)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarBorderOffset"] or (L["Border offset"] or "Border offset"),
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBar",
		minValue = BAR_BORDER_OFFSET_MIN,
		maxValue = BAR_BORDER_OFFSET_MAX,
		valueStep = 1,
		allowInput = true,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarBorderSize(currentEntry and currentEntry.barBorderSize, Bars.DEFAULTS.barBorderSize) <= 0
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarBorderOffset(currentEntry and currentEntry.barBorderOffset, Bars.DEFAULTS.barBorderOffset)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barBorderOffset", normalizeBarBorderOffset(value, Bars.DEFAULTS.barBorderOffset)) end,
		formatter = function(value) return tostring(normalizeBarBorderOffset(value, Bars.DEFAULTS.barBorderOffset)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarBorderTexture"] or "Border texture",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBar",
		height = BAR_TEXTURE_MENU_HEIGHT,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarBorderSize(currentEntry and currentEntry.barBorderSize, Bars.DEFAULTS.barBorderSize) <= 0
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarBorderTexture(currentEntry and currentEntry.barBorderTexture, Bars.DEFAULTS.barBorderTexture)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barBorderTexture", value) end,
		generator = function(_, root)
			for _, option in ipairs(getBarBorderTextureOptions()) do
				root:CreateRadio(option.label, function()
					local currentEntry = getStandaloneBarContextEntry(ctx)
					return normalizeBarBorderTexture(currentEntry and currentEntry.barBorderTexture, Bars.DEFAULTS.barBorderTexture) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "barBorderTexture", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarBorderColor"] or "Border color",
		kind = SettingType.Color,
		parentId = "eqolCooldownPanelStandaloneBar",
		hasOpacity = true,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarBorderSize(currentEntry and currentEntry.barBorderSize, Bars.DEFAULTS.barBorderSize) <= 0
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			local color = Helper.NormalizeColor(currentEntry and currentEntry.barBorderColor, Bars.DEFAULTS.barBorderColor)
			return { r = color[1], g = color[2], b = color[3], a = color[4] }
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barBorderColor", Helper.NormalizeColor(value, Bars.DEFAULTS.barBorderColor)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarChargesSegmented"] or "Segment charges",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBar",
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarMode(currentEntry and currentEntry.barMode, Bars.DEFAULTS.barMode) == Bars.BAR_MODE.CHARGES
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getStoredBoolean(currentEntry, "barChargesSegmented", Bars.DEFAULTS.barChargesSegmented)
		end,
		set = function(_, value) setEntryBarBoolean(panelId, entryId, "barChargesSegmented", value) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarChargesGap"] or "Charges gap",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBar",
		minValue = BAR_CHARGES_GAP_MIN,
		maxValue = BAR_CHARGES_GAP_MAX,
		valueStep = 1,
		allowInput = true,
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarMode(currentEntry and currentEntry.barMode, Bars.DEFAULTS.barMode) == Bars.BAR_MODE.CHARGES
		end,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not getStoredBoolean(currentEntry, "barChargesSegmented", Bars.DEFAULTS.barChargesSegmented)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarChargesGap(currentEntry and currentEntry.barChargesGap, Bars.DEFAULTS.barChargesGap)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barChargesGap", normalizeBarChargesGap(value, Bars.DEFAULTS.barChargesGap)) end,
		formatter = function(value) return tostring(normalizeBarChargesGap(value, Bars.DEFAULTS.barChargesGap)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarSegmentDirection"] or "Segment direction",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBar",
		height = 120,
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarMode(currentEntry and currentEntry.barMode, Bars.DEFAULTS.barMode) == Bars.BAR_MODE.CHARGES
		end,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not getStoredBoolean(currentEntry, "barChargesSegmented", Bars.DEFAULTS.barChargesSegmented)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarSegmentDirection(currentEntry and currentEntry.barSegmentDirection, Bars.DEFAULTS.barSegmentDirection)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barSegmentDirection", normalizeBarSegmentDirection(value, Bars.DEFAULTS.barSegmentDirection)) end,
		generator = function(_, root)
			for _, option in ipairs({
				{ value = BAR_ORIENTATION_HORIZONTAL, label = L["CooldownPanelBarOrientationHorizontal"] or "Horizontal" },
				{ value = BAR_ORIENTATION_VERTICAL, label = L["CooldownPanelBarOrientationVertical"] or "Vertical" },
			}) do
				root:CreateRadio(option.label, function()
					local currentEntry = getStandaloneBarContextEntry(ctx)
					return normalizeBarSegmentDirection(currentEntry and currentEntry.barSegmentDirection, Bars.DEFAULTS.barSegmentDirection) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "barSegmentDirection", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarSegmentReverse"] or "Reverse segment order",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBar",
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarMode(currentEntry and currentEntry.barMode, Bars.DEFAULTS.barMode) == Bars.BAR_MODE.CHARGES
		end,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not getStoredBoolean(currentEntry, "barChargesSegmented", Bars.DEFAULTS.barChargesSegmented)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getStoredBoolean(currentEntry, "barSegmentReverse", Bars.DEFAULTS.barSegmentReverse)
		end,
		set = function(_, value) setEntryBarBoolean(panelId, entryId, "barSegmentReverse", value) end,
	}
end

local function appendBarStandaloneTextSettings(settings, ctx)
	local panelId = ctx.panelId
	local entryId = ctx.entryId
	local SettingType = ctx.SettingType
	local labelDefaultFontPath = ctx.labelDefaultFontPath
	local labelDefaultFontSize = ctx.labelDefaultFontSize
	local labelDefaultFontStyle = ctx.labelDefaultFontStyle
	local valueDefaultFontPath = ctx.valueDefaultFontPath
	local valueDefaultFontSize = ctx.valueDefaultFontSize
	local valueDefaultFontStyle = ctx.valueDefaultFontStyle

	settings[#settings + 1] = {
		name = L["CooldownPanelBarTextHeader"] or "Text",
		kind = SettingType.Collapsible,
		id = "eqolCooldownPanelStandaloneBarText",
		defaultCollapsed = false,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarShowIcon"] or "Show icon",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBarText",
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getStoredBoolean(currentEntry, "barShowIcon", Bars.DEFAULTS.barShowIcon)
		end,
		set = function(_, value) setEntryBarBoolean(panelId, entryId, "barShowIcon", value) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarIconSize"] or (L["CooldownPanelIconSize"] or "Icon size"),
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBarText",
		minValue = BAR_ICON_SIZE_MIN,
		maxValue = BAR_ICON_SIZE_MAX,
		valueStep = 1,
		allowInput = true,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not getStoredBoolean(currentEntry, "barShowIcon", Bars.DEFAULTS.barShowIcon)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			local configuredSize = normalizeBarIconSize(currentEntry and currentEntry.barIconSize, Bars.DEFAULTS.barIconSize)
			if configuredSize > 0 then return configuredSize end
			local currentHeight = normalizeBarHeight(currentEntry and currentEntry.barHeight, Bars.DEFAULTS.barHeight)
			return max(BAR_ICON_SIZE_MIN, currentHeight - 4)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barIconSize", normalizeBarIconSize(value, Bars.DEFAULTS.barIconSize)) end,
		formatter = function(value) return tostring(Helper.ClampInt(value, BAR_ICON_SIZE_MIN, BAR_ICON_SIZE_MAX, BAR_ICON_SIZE_MIN)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarIconPosition"] or "Icon position",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBarText",
		height = 120,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not getStoredBoolean(currentEntry, "barShowIcon", Bars.DEFAULTS.barShowIcon)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarIconPosition(currentEntry and currentEntry.barIconPosition, Bars.DEFAULTS.barIconPosition)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barIconPosition", normalizeBarIconPosition(value, Bars.DEFAULTS.barIconPosition)) end,
		generator = function(_, root)
			for _, option in ipairs({
				{ value = BAR_ICON_POSITION_LEFT, label = L["Left"] or "Left" },
				{ value = BAR_ICON_POSITION_RIGHT, label = L["Right"] or "Right" },
				{ value = BAR_ICON_POSITION_TOP, label = L["CooldownPanelBarIconPositionTop"] or "Top" },
				{ value = BAR_ICON_POSITION_BOTTOM, label = L["CooldownPanelBarIconPositionBottom"] or "Bottom" },
			}) do
				root:CreateRadio(option.label, function()
					local currentEntry = getStandaloneBarContextEntry(ctx)
					return normalizeBarIconPosition(currentEntry and currentEntry.barIconPosition, Bars.DEFAULTS.barIconPosition) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "barIconPosition", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarIconOffsetX"] or "Icon X",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBarText",
		minValue = -(Helper.OFFSET_RANGE or 500),
		maxValue = Helper.OFFSET_RANGE or 500,
		valueStep = 1,
		allowInput = true,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not getStoredBoolean(currentEntry, "barShowIcon", Bars.DEFAULTS.barShowIcon)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarIconOffset(currentEntry and currentEntry.barIconOffsetX, Bars.DEFAULTS.barIconOffsetX)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barIconOffsetX", normalizeBarIconOffset(value, Bars.DEFAULTS.barIconOffsetX)) end,
		formatter = function(value) return tostring(normalizeBarIconOffset(value, Bars.DEFAULTS.barIconOffsetX)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarIconOffsetY"] or "Icon Y",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBarText",
		minValue = -(Helper.OFFSET_RANGE or 500),
		maxValue = Helper.OFFSET_RANGE or 500,
		valueStep = 1,
		allowInput = true,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not getStoredBoolean(currentEntry, "barShowIcon", Bars.DEFAULTS.barShowIcon)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarIconOffset(currentEntry and currentEntry.barIconOffsetY, Bars.DEFAULTS.barIconOffsetY)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barIconOffsetY", normalizeBarIconOffset(value, Bars.DEFAULTS.barIconOffsetY)) end,
		formatter = function(value) return tostring(normalizeBarIconOffset(value, Bars.DEFAULTS.barIconOffsetY)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarShowLabel"] or "Show label",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBarText",
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getStoredBoolean(currentEntry, "barShowLabel", Bars.DEFAULTS.barShowLabel)
		end,
		set = function(_, value) setEntryBarBoolean(panelId, entryId, "barShowLabel", value) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarShowValueText"] or "Show value",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBarText",
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getStoredBoolean(currentEntry, "barShowValueText", Bars.DEFAULTS.barShowValueText)
		end,
		set = function(_, value) setEntryBarBoolean(panelId, entryId, "barShowValueText", value) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarLabelFont"] or "Label font",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBarText",
		height = 220,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.barShowLabel == true)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getStandaloneBarFontValue(currentEntry and currentEntry.barLabelFont)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barLabelFont", value) end,
		generator = function(_, root)
			for _, option in ipairs(Helper.GetFontOptions(labelDefaultFontPath)) do
				root:CreateRadio(option.label, function()
					local currentEntry = getStandaloneBarContextEntry(ctx)
					return getStandaloneBarFontValue(currentEntry and currentEntry.barLabelFont) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "barLabelFont", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarLabelStyle"] or "Label style",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBarText",
		height = 120,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.barShowLabel == true)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarFontStyle(currentEntry and currentEntry.barLabelStyle, labelDefaultFontStyle)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barLabelStyle", Helper.NormalizeFontStyleChoice(value, labelDefaultFontStyle)) end,
		generator = function(_, root)
			for _, option in ipairs(Helper.FontStyleOptions) do
				root:CreateRadio(option.label, function()
					local currentEntry = getStandaloneBarContextEntry(ctx)
					return normalizeBarFontStyle(currentEntry and currentEntry.barLabelStyle, labelDefaultFontStyle) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "barLabelStyle", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarLabelSize"] or "Label size",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBarText",
		minValue = BAR_FONT_SIZE_MIN,
		maxValue = BAR_FONT_SIZE_MAX,
		valueStep = 1,
		allowInput = true,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.barShowLabel == true)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarFontSize(currentEntry and currentEntry.barLabelSize, labelDefaultFontSize)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barLabelSize", Helper.ClampInt(value, BAR_FONT_SIZE_MIN, BAR_FONT_SIZE_MAX, labelDefaultFontSize)) end,
		formatter = function(value) return tostring(Helper.ClampInt(value, BAR_FONT_SIZE_MIN, BAR_FONT_SIZE_MAX, labelDefaultFontSize)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarLabelColor"] or "Label color",
		kind = SettingType.Color,
		parentId = "eqolCooldownPanelStandaloneBarText",
		hasOpacity = true,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.barShowLabel == true)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			local color = Helper.NormalizeColor(currentEntry and currentEntry.barLabelColor, Bars.DEFAULTS.barLabelColor)
			return { r = color[1], g = color[2], b = color[3], a = color[4] }
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barLabelColor", Helper.NormalizeColor(value, Bars.DEFAULTS.barLabelColor)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarValueFont"] or "Value font",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBarText",
		height = 220,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.barShowValueText == true)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getStandaloneBarFontValue(currentEntry and currentEntry.barValueFont)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barValueFont", value) end,
		generator = function(_, root)
			for _, option in ipairs(Helper.GetFontOptions(valueDefaultFontPath)) do
				root:CreateRadio(option.label, function()
					local currentEntry = getStandaloneBarContextEntry(ctx)
					return getStandaloneBarFontValue(currentEntry and currentEntry.barValueFont) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "barValueFont", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarValueStyle"] or "Value style",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBarText",
		height = 120,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.barShowValueText == true)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarFontStyle(currentEntry and currentEntry.barValueStyle, valueDefaultFontStyle)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barValueStyle", Helper.NormalizeFontStyleChoice(value, valueDefaultFontStyle)) end,
		generator = function(_, root)
			for _, option in ipairs(Helper.FontStyleOptions) do
				root:CreateRadio(option.label, function()
					local currentEntry = getStandaloneBarContextEntry(ctx)
					return normalizeBarFontStyle(currentEntry and currentEntry.barValueStyle, valueDefaultFontStyle) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "barValueStyle", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarValueSize"] or "Value size",
		kind = SettingType.Slider,
		parentId = "eqolCooldownPanelStandaloneBarText",
		minValue = BAR_FONT_SIZE_MIN,
		maxValue = BAR_FONT_SIZE_MAX,
		valueStep = 1,
		allowInput = true,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.barShowValueText == true)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return normalizeBarFontSize(currentEntry and currentEntry.barValueSize, valueDefaultFontSize)
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barValueSize", Helper.ClampInt(value, BAR_FONT_SIZE_MIN, BAR_FONT_SIZE_MAX, valueDefaultFontSize)) end,
		formatter = function(value) return tostring(Helper.ClampInt(value, BAR_FONT_SIZE_MIN, BAR_FONT_SIZE_MAX, valueDefaultFontSize)) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelBarValueColor"] or "Value color",
		kind = SettingType.Color,
		parentId = "eqolCooldownPanelStandaloneBarText",
		hasOpacity = true,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.barShowValueText == true)
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			local color = Helper.NormalizeColor(currentEntry and currentEntry.barValueColor, Bars.DEFAULTS.barValueColor)
			return { r = color[1], g = color[2], b = color[3], a = color[4] }
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "barValueColor", Helper.NormalizeColor(value, Bars.DEFAULTS.barValueColor)) end,
	}
end

local function appendBarStandaloneVisibilitySettings(settings, ctx)
	local panelId = ctx.panelId
	local entryId = ctx.entryId
	local SettingType = ctx.SettingType

	settings[#settings + 1] = {
		name = L["CooldownPanelBarVisibilityHeader"] or (L["Display"] or "Display"),
		kind = SettingType.Collapsible,
		id = "eqolCooldownPanelStandaloneBarVisibility",
		defaultCollapsed = true,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelAlwaysShow"] or "Always show",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBarVisibility",
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getEntryResolvedType(currentEntry) == "ITEM"
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return currentEntry and currentEntry.alwaysShow ~= false or false
		end,
		set = function(_, value) setEntryBarBoolean(panelId, entryId, "alwaysShow", value) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelOverwritePanelCDMAuraAlwaysShow"] or "Overwrite panel tracked aura display",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBarVisibility",
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getEntryResolvedType(currentEntry) == "CDM_AURA"
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return currentEntry and currentEntry.cdmAuraAlwaysShowUseGlobal == false or false
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "cdmAuraAlwaysShowUseGlobal", value ~= true) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelCDMAuraAlwaysShowMode"] or "Tracked aura display",
		kind = SettingType.Dropdown,
		parentId = "eqolCooldownPanelStandaloneBarVisibility",
		height = 180,
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getEntryResolvedType(currentEntry) == "CDM_AURA"
		end,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.cdmAuraAlwaysShowUseGlobal == false)
		end,
		get = function() return getStandaloneBarCDMAuraMode(panelId, entryId) end,
		set = function(_, value) setEntryBarField(panelId, entryId, "cdmAuraAlwaysShowMode", normalizeCDMAuraAlwaysShowModeValue(value, "HIDE")) end,
		generator = function(_, root)
			for _, option in ipairs(CooldownPanels.GetCDMAuraAlwaysShowOptions and CooldownPanels:GetCDMAuraAlwaysShowOptions() or {}) do
				root:CreateRadio(option.label, function()
					return getStandaloneBarCDMAuraMode(panelId, entryId) == option.value
				end, function()
					setEntryBarField(panelId, entryId, "cdmAuraAlwaysShowMode", option.value)
				end)
			end
		end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBarVisibility",
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getEntryResolvedType(currentEntry) ~= "CDM_AURA"
		end,
		get = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return currentEntry and currentEntry.cooldownVisibilityUseGlobal == false or false
		end,
		set = function(_, value) setEntryBarField(panelId, entryId, "cooldownVisibilityUseGlobal", value ~= true) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelHideOnCooldown"] or "Hide on cooldown",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBarVisibility",
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getEntryResolvedType(currentEntry) ~= "CDM_AURA"
		end,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.cooldownVisibilityUseGlobal == false)
		end,
		get = function() return getStandaloneBarVisibility(panelId, entryId, "hideOnCooldown") end,
		set = function(_, value) setEntryBarBoolean(panelId, entryId, "hideOnCooldown", value) end,
	}
	settings[#settings + 1] = {
		name = L["CooldownPanelShowOnCooldown"] or "Show on cooldown",
		kind = SettingType.Checkbox,
		parentId = "eqolCooldownPanelStandaloneBarVisibility",
		isShown = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return getEntryResolvedType(currentEntry) ~= "CDM_AURA"
		end,
		disabled = function()
			local currentEntry = getStandaloneBarContextEntry(ctx)
			return not (currentEntry and currentEntry.cooldownVisibilityUseGlobal == false)
		end,
		get = function() return getStandaloneBarVisibility(panelId, entryId, "showOnCooldown") end,
		set = function(_, value) setEntryBarBoolean(panelId, entryId, "showOnCooldown", value) end,
	}
end

local function buildBarStandaloneSettings(panelId, entryId)
	local ctx = createBarStandaloneSettingsContext(panelId, entryId)
	if not ctx then return nil end
	local settings = {}
	appendBarStandaloneAppearanceSettings(settings, ctx)
	appendBarStandaloneTextSettings(settings, ctx)
	appendBarStandaloneVisibilitySettings(settings, ctx)
	return settings
end

local function buildStandaloneDialogButtons(panelId, entryId, existingButtons)
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	local panel, entry = getStandaloneBarEntry(panelId, entryId)
	if not (panel and entry and Helper.IsFixedLayout and Helper.IsFixedLayout(panel.layout)) then return existingButtons end

	local buttons = {}
	local displayMode = normalizeDisplayMode(entry.displayMode, Bars.DEFAULTS.displayMode)
	buttons[#buttons + 1] = {
		text = displayMode == Bars.DISPLAY_MODE.BAR and (L["CooldownPanelSwitchToButton"] or "Switch to Button") or (L["CooldownPanelSwitchToBar"] or "Switch to Bar"),
		click = function()
			if normalizeDisplayMode(entry.displayMode, Bars.DEFAULTS.displayMode) == Bars.DISPLAY_MODE.BAR then
				setEntryDisplayMode(panelId, entryId, Bars.DISPLAY_MODE.BUTTON)
			else
				setEntryDisplayMode(panelId, entryId, Bars.DISPLAY_MODE.BAR, normalizeBarMode(entry.barMode, Bars.DEFAULTS.barMode))
			end
		end,
	}
	for _, button in ipairs(existingButtons or {}) do
		buttons[#buttons + 1] = button
	end
	return buttons
end

local originalOpenLayoutEntryStandaloneMenu = CooldownPanels.OpenLayoutEntryStandaloneMenu
function CooldownPanels:OpenLayoutEntryStandaloneMenu(panelId, entryId, anchorFrame)
	local lib = addon.EditModeLib
	if not (lib and lib.ShowStandaloneSettingsDialog) then return originalOpenLayoutEntryStandaloneMenu(self, panelId, entryId, anchorFrame) end

	local originalShowStandaloneSettingsDialog = lib.ShowStandaloneSettingsDialog
	lib.ShowStandaloneSettingsDialog = function(editModeLib, frame, options)
		local resolvedOptions = options or {}
		resolvedOptions.buttons = buildStandaloneDialogButtons(panelId, entryId, resolvedOptions.buttons)
		local panel, entry = getStandaloneBarEntry(panelId, entryId)
		if panel and entry and Helper.IsFixedLayout and Helper.IsFixedLayout(panel.layout) and normalizeDisplayMode(entry.displayMode, Bars.DEFAULTS.displayMode) == Bars.DISPLAY_MODE.BAR then
			local settings = buildBarStandaloneSettings(panelId, entryId)
			if settings then
				resolvedOptions.settings = settings
				resolvedOptions.settingsMaxHeight = max(resolvedOptions.settingsMaxHeight or 0, 640)
			end
		end
		return originalShowStandaloneSettingsDialog(editModeLib, frame, resolvedOptions)
	end

	local ok, result = pcall(originalOpenLayoutEntryStandaloneMenu, self, panelId, entryId, anchorFrame)
	lib.ShowStandaloneSettingsDialog = originalShowStandaloneSettingsDialog
	if not ok then error(result) end

	local state = self.GetLayoutEntryStandaloneMenuState and self:GetLayoutEntryStandaloneMenuState(false) or nil
	if state and normalizeId(state.panelId) == normalizeId(panelId) and normalizeId(state.entryId) == normalizeId(entryId) then
		state.anchorFrame = anchorFrame
	end
	return result
end
