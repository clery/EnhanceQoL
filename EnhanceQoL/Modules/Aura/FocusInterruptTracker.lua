local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Aura = addon.Aura or {}
addon.Aura.FocusInterruptTracker = addon.Aura.FocusInterruptTracker or {}
local Tracker = addon.Aura.FocusInterruptTracker

local L = LibStub("AceLocale-3.0"):GetLocale(parentAddonName)
local EditMode = addon.EditMode
local SettingType = EditMode and EditMode.lib and EditMode.lib.SettingType
local LSM = LibStub("LibSharedMedia-3.0", true)

local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local NONE = _G.NONE or "None"
local DEFAULT = _G.DEFAULT or "Default"
local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
local issecretvalue = _G.issecretvalue

local DB_KEY = "focusInterruptTracker"
local EDITMODE_ID = "focusInterruptTracker"
local GCD_SPELL_ID = 61304
local DEFAULT_PREVIEW_TEXT = "INTERRUPT"
local DEFAULT_PREVIEW_ICON = 132938
local DEFAULT_SETTINGS_MAX_HEIGHT = 900

local Helper = addon.Aura and addon.Aura.CooldownPanels and addon.Aura.CooldownPanels.helper
local Api = Helper and Helper.Api or {}
local GetSpellCooldownInfo = Api.GetSpellCooldownInfo or (C_Spell and C_Spell.GetSpellCooldown) or _G.GetSpellCooldown
local IsSpellKnown = Api.IsSpellKnown or function(spellId)
	if _G.IsPlayerSpell then return _G.IsPlayerSpell(spellId) end
	return spellId ~= nil
end

local ANCHOR_POINTS = {
	"TOPLEFT",
	"TOP",
	"TOPRIGHT",
	"LEFT",
	"CENTER",
	"RIGHT",
	"BOTTOMLEFT",
	"BOTTOM",
	"BOTTOMRIGHT",
}

local VALID_ANCHOR_POINTS = {}
for i = 1, #ANCHOR_POINTS do
	VALID_ANCHOR_POINTS[ANCHOR_POINTS[i]] = true
end

local OUTLINE_OPTIONS = {
	"NONE",
	"OUTLINE",
	"THICKOUTLINE",
	"MONOCHROMEOUTLINE",
}

local VALID_OUTLINES = {}
for i = 1, #OUTLINE_OPTIONS do
	VALID_OUTLINES[OUTLINE_OPTIONS[i]] = true
end

local DISPLAY_MODES = {
	TEXT = true,
	ICON = true,
}

local STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local VALID_STRATA = {}
for i = 1, #STRATA_ORDER do
	VALID_STRATA[STRATA_ORDER[i]] = true
end

local EXTERNAL_ANCHOR_ADDONS = {
	ElvUI = true,
	MidnightSimpleUnitFrames = true,
	UnhaltedUnitFrames = true,
}

local CLASS_INTERRUPT_SPELLS = {
	DEATHKNIGHT = { 47528 },
	DEMONHUNTER = { 183752 },
	DRUID = { 106839, 78675 },
	EVOKER = { 351338 },
	HUNTER = { 147362, 187707 },
	MAGE = { 2139 },
	MONK = { 116705 },
	PALADIN = { 96231 },
	PRIEST = { 15487 },
	ROGUE = { 1766 },
	SHAMAN = { 57994 },
	WARLOCK = { 19647 },
	WARRIOR = { 6552 },
}

local AUTO_ANCHOR_OPTIONS = {
	{
		value = "AUTO",
		label = L["FocusInterruptTrackerAnchorAuto"] or "Auto focus frame",
	},
	{
		value = "UIParent",
		label = "UIParent",
	},
	{
		value = "EQOLUFFocusFrame",
		label = L["FocusInterruptTrackerAnchorEQOL"] or "EQOL: Focus Frame",
	},
	{
		value = "FocusFrame",
		label = L["FocusInterruptTrackerAnchorBlizzard"] or "Blizzard: Focus Frame",
	},
	{
		value = "ElvUF_Focus",
		label = L["FocusInterruptTrackerAnchorElvUI"] or "ElvUI: Focus Frame",
		addonName = "ElvUI",
	},
	{
		value = "MSUF_focus",
		label = L["FocusInterruptTrackerAnchorMSUF"] or "MSUF: Focus Frame",
		addonName = "MidnightSimpleUnitFrames",
	},
	{
		value = "UUF_Focus",
		label = L["FocusInterruptTrackerAnchorUUF"] or "UUF: Focus Frame",
		addonName = "UnhaltedUnitFrames",
	},
}

Tracker.defaults = Tracker.defaults
	or {
		version = 1,
		enabled = false,
		displayMode = "TEXT",
		text = DEFAULT_PREVIEW_TEXT,
		textFont = addon.functions and addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or "__EQOL_GLOBAL_FONT__",
		textSize = 24,
		textOutline = "THICKOUTLINE",
		textColor = { 1, 0.15, 0.15, 1 },
		iconSize = 28,
		customIcon = nil,
		background = {
			enabled = false,
			color = { 0, 0, 0, 0.35 },
		},
		border = {
			enabled = false,
			texture = "DEFAULT",
			size = 1,
			offset = 0,
			color = { 0, 0, 0, 0.9 },
		},
		anchor = {
			point = "TOP",
			relativePoint = "BOTTOM",
			relativeFrame = "AUTO",
			x = 0,
			y = -10,
		},
		strata = "HIGH",
	}

local defaults = Tracker.defaults
local state = Tracker._state or {}
Tracker._state = state

local function copyValue(value)
	if type(value) ~= "table" then return value end
	if addon.functions and addon.functions.copyTable then return addon.functions.copyTable(value) end
	return CopyTable(value)
end

local function mergeDefaults(target, source)
	if type(target) ~= "table" or type(source) ~= "table" then return end
	for key, value in pairs(source) do
		if target[key] == nil then
			target[key] = copyValue(value)
		elseif type(target[key]) == "table" and type(value) == "table" then
			mergeDefaults(target[key], value)
		end
	end
end

local function trimString(value)
	if type(value) ~= "string" then return nil end
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	if value == "" then return nil end
	return value
end

local function normalizeAnchorPoint(value, fallback)
	local point = type(value) == "string" and string.upper(value) or nil
	if point and VALID_ANCHOR_POINTS[point] then return point end
	local fallbackPoint = type(fallback) == "string" and string.upper(fallback) or "CENTER"
	if VALID_ANCHOR_POINTS[fallbackPoint] then return fallbackPoint end
	return "CENTER"
end

local function normalizeOutline(value, fallback)
	local outline = type(value) == "string" and string.upper(value) or nil
	if outline and VALID_OUTLINES[outline] then return outline end
	local fallbackOutline = type(fallback) == "string" and string.upper(fallback) or "NONE"
	if VALID_OUTLINES[fallbackOutline] then return fallbackOutline end
	return "NONE"
end

local function normalizeDisplayMode(value, fallback)
	local mode = type(value) == "string" and string.upper(value) or nil
	if mode and DISPLAY_MODES[mode] then return mode end
	local fallbackMode = type(fallback) == "string" and string.upper(fallback) or "TEXT"
	if DISPLAY_MODES[fallbackMode] then return fallbackMode end
	return "TEXT"
end

local function normalizeStrata(value, fallback)
	local strata = type(value) == "string" and string.upper(value) or nil
	if strata and VALID_STRATA[strata] then return strata end
	local fallbackStrata = type(fallback) == "string" and string.upper(fallback) or "HIGH"
	if VALID_STRATA[fallbackStrata] then return fallbackStrata end
	return "HIGH"
end

local function clampNumber(value, minValue, maxValue, fallback)
	value = tonumber(value)
	if value == nil then value = fallback end
	value = tonumber(value) or 0
	if minValue ~= nil and value < minValue then value = minValue end
	if maxValue ~= nil and value > maxValue then value = maxValue end
	return value
end

local function clampInt(value, minValue, maxValue, fallback)
	return math.floor(clampNumber(value, minValue, maxValue, fallback) + 0.5)
end

local function normalizeColor(value, fallback)
	local color = type(value) == "table" and value or fallback or { 1, 1, 1, 1 }
	local r = color.r or color[1] or 1
	local g = color.g or color[2] or 1
	local b = color.b or color[3] or 1
	local a = color.a or color[4]
	if a == nil then a = 1 end
	return {
		clampNumber(r, 0, 1, 1),
		clampNumber(g, 0, 1, 1),
		clampNumber(b, 0, 1, 1),
		clampNumber(a, 0, 1, 1),
	}
end

local function normalizeCustomIcon(value)
	if value == nil then return nil end
	if type(value) == "number" then
		if value > 0 then return math.floor(value + 0.5) end
		return nil
	end
	local text = trimString(tostring(value))
	if not text then return nil end
	local numeric = tonumber(text)
	if numeric and numeric > 0 then return math.floor(numeric + 0.5) end
	return text
end

local function isLikelyFilePath(value)
	if type(value) ~= "string" or value == "" then return false end
	return value:find("/", 1, true) ~= nil or value:find("\\", 1, true) ~= nil
end

local function resolveBorderTexture(value)
	if value == "SOLID" then return "Interface\\Buttons\\WHITE8x8" end
	if not value or value == "" or value == "DEFAULT" then return "Interface\\Buttons\\WHITE8x8" end
	if LSM and LSM.Fetch then
		local texture = LSM:Fetch("border", value, true)
		if texture then return texture end
	end
	if isLikelyFilePath(value) then return value end
	return "Interface\\Buttons\\WHITE8x8"
end

local function getFontOptions()
	local options = {}
	local globalKey = addon.functions and addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or defaults.textFont
	local globalLabel = addon.functions and addon.functions.GetGlobalFontConfigLabel and addon.functions.GetGlobalFontConfigLabel() or "Use global font config"
	options[#options + 1] = {
		value = globalKey,
		label = globalLabel,
	}

	local mediaOptions = addon.functions and addon.functions.GetLSMMediaOptions and addon.functions.GetLSMMediaOptions("font") or {}
	for i = 1, #mediaOptions do
		options[#options + 1] = {
			value = mediaOptions[i].value,
			label = mediaOptions[i].label,
		}
	end

	return options
end

local function getBorderOptions()
	local options = {
		{ value = "DEFAULT", label = DEFAULT },
		{ value = "SOLID", label = "Solid" },
	}
	local mediaOptions = addon.functions and addon.functions.GetLSMMediaOptions and addon.functions.GetLSMMediaOptions("border") or {}
	for i = 1, #mediaOptions do
		options[#options + 1] = {
			value = mediaOptions[i].value,
			label = mediaOptions[i].label,
		}
	end
	return options
end

local function isEQOLFocusEnabled()
	local frames = addon.db and addon.db.ufFrames
	local focus = frames and frames.focus
	return focus and focus.enabled == true or false
end

local function hasAnchorFrame(option)
	if not option then return false end
	if option.value == "AUTO" or option.value == "UIParent" then return true end
	if option.addonName and IsAddOnLoaded and not IsAddOnLoaded(option.addonName) then return false end
	if option.value == "EQOLUFFocusFrame" and not isEQOLFocusEnabled() and not _G.EQOLUFFocusFrame then return false end
	return _G[option.value] ~= nil
end

local function getResolvedAutoAnchorTarget()
	local preferred = { "EQOLUFFocusFrame", "ElvUF_Focus", "MSUF_focus", "UUF_Focus", "FocusFrame" }
	for i = 1, #preferred do
		local key = preferred[i]
		if key == "EQOLUFFocusFrame" then
			if isEQOLFocusEnabled() and _G[key] then return key end
		elseif _G[key] then
			return key
		end
	end
	if _G.FocusFrame then return "FocusFrame" end
	return "UIParent"
end

function Tracker:GetConfig()
	addon.db = addon.db or {}
	local cfg = addon.db[DB_KEY]
	if type(cfg) ~= "table" then
		cfg = copyValue(defaults)
		addon.db[DB_KEY] = cfg
	end

	mergeDefaults(cfg, defaults)
	cfg.anchor = type(cfg.anchor) == "table" and cfg.anchor or {}
	cfg.background = type(cfg.background) == "table" and cfg.background or {}
	cfg.border = type(cfg.border) == "table" and cfg.border or {}
	mergeDefaults(cfg.anchor, defaults.anchor)
	mergeDefaults(cfg.background, defaults.background)
	mergeDefaults(cfg.border, defaults.border)

	cfg.enabled = cfg.enabled == true
	cfg.displayMode = normalizeDisplayMode(cfg.displayMode, defaults.displayMode)
	cfg.text = trimString(cfg.text) or DEFAULT_PREVIEW_TEXT
	cfg.textFont = cfg.textFont or defaults.textFont
	cfg.textSize = clampInt(cfg.textSize, 8, 96, defaults.textSize)
	cfg.textOutline = normalizeOutline(cfg.textOutline, defaults.textOutline)
	cfg.textColor = normalizeColor(cfg.textColor, defaults.textColor)
	cfg.iconSize = clampInt(cfg.iconSize, 8, 128, defaults.iconSize)
	cfg.customIcon = normalizeCustomIcon(cfg.customIcon)
	cfg.background.enabled = cfg.background.enabled == true
	cfg.background.color = normalizeColor(cfg.background.color, defaults.background.color)
	cfg.border.enabled = cfg.border.enabled == true
	cfg.border.texture = cfg.border.texture or defaults.border.texture
	cfg.border.size = clampInt(cfg.border.size, 1, 32, defaults.border.size)
	cfg.border.offset = clampInt(cfg.border.offset, -20, 20, defaults.border.offset)
	cfg.border.color = normalizeColor(cfg.border.color, defaults.border.color)
	cfg.anchor.point = normalizeAnchorPoint(cfg.anchor.point, defaults.anchor.point)
	cfg.anchor.relativePoint = normalizeAnchorPoint(cfg.anchor.relativePoint, defaults.anchor.relativePoint)
	cfg.anchor.relativeFrame = trimString(cfg.anchor.relativeFrame) or defaults.anchor.relativeFrame
	cfg.anchor.x = clampInt(cfg.anchor.x, -4096, 4096, defaults.anchor.x)
	cfg.anchor.y = clampInt(cfg.anchor.y, -4096, 4096, defaults.anchor.y)
	cfg.strata = normalizeStrata(cfg.strata, defaults.strata)

	return cfg
end

function Tracker:IsEnabled()
	local cfg = self:GetConfig()
	return cfg.enabled == true
end

function Tracker:ResolveAnchorTarget()
	local cfg = self:GetConfig()
	local target = cfg.anchor.relativeFrame
	if target == "AUTO" then target = getResolvedAutoAnchorTarget() end
	if target == nil or target == "" then target = "UIParent" end
	if target ~= "UIParent" and not _G[target] then
		if cfg.anchor.relativeFrame == "AUTO" then
			target = getResolvedAutoAnchorTarget()
		end
		if target ~= "UIParent" and not _G[target] then target = "UIParent" end
	end
	return target
end

function Tracker:ResolveAnchorFrame()
	local target = self:ResolveAnchorTarget()
	if target == "UIParent" then return UIParent end
	return _G[target] or UIParent
end

function Tracker:BuildLayoutRecordFromProfile()
	local cfg = self:GetConfig()
	return {
		point = cfg.anchor.point,
		relativePoint = cfg.anchor.relativePoint,
		x = cfg.anchor.x,
		y = cfg.anchor.y,
		anchorTarget = cfg.anchor.relativeFrame,
		displayMode = cfg.displayMode,
		text = cfg.text,
		textFont = cfg.textFont,
		textSize = cfg.textSize,
		textOutline = cfg.textOutline,
		textColor = copyValue(cfg.textColor),
		iconSize = cfg.iconSize,
		customIcon = cfg.customIcon,
		backgroundEnabled = cfg.background.enabled,
		backgroundColor = copyValue(cfg.background.color),
		borderEnabled = cfg.border.enabled,
		borderTexture = cfg.border.texture,
		borderSize = cfg.border.size,
		borderOffset = cfg.border.offset,
		borderColor = copyValue(cfg.border.color),
		strata = cfg.strata,
	}
end

local function seedEditModeRecordFromProfile(record)
	if type(record) ~= "table" then return end
	local source = Tracker:BuildLayoutRecordFromProfile()
	for key, value in pairs(source) do
		record[key] = value
	end
end

function Tracker:ResolveTextFont()
	local cfg = self:GetConfig()
	local fallback = (addon.functions and addon.functions.GetLocaleDefaultFontFace and addon.functions.GetLocaleDefaultFontFace()) or addon.variables.defaultFont or STANDARD_TEXT_FONT
	if addon.functions and addon.functions.ResolveFontFace then return addon.functions.ResolveFontFace(cfg.textFont, fallback) end
	return fallback
end

local function isSafeNumber(value)
	if type(value) ~= "number" then return false end
	if issecretvalue and issecretvalue(value) then return false end
	return value == value
end

local function applyNonInterruptibleAlpha(target, notInterruptible)
	if not target then return end
	if target.SetAlphaFromBoolean then
		target:SetAlphaFromBoolean(notInterruptible, 0, 1)
	elseif target.SetAlpha then
		if type(notInterruptible) == "boolean" then
			target:SetAlpha(notInterruptible and 0 or 1)
		else
			target:SetAlpha(1)
		end
	end
end

local function isSpellCooldownInfoActive(cooldownIsActive, cooldownEnabled, startTime, duration)
	if not (issecretvalue and issecretvalue(cooldownIsActive)) and type(cooldownIsActive) == "boolean" then return cooldownIsActive end
	if cooldownEnabled == false then return false end
	if not isSafeNumber(startTime) or not isSafeNumber(duration) then return false end
	if duration <= 0 or startTime <= 0 then return false end
	if not GetTime then return false end
	return (startTime + duration) > GetTime()
end

local function querySpellCooldown(spellId)
	if not spellId or not GetSpellCooldownInfo then
		return {
			isEnabled = false,
			isOnGCD = nil,
			isActive = false,
		}
	end

	local a, b, c, d = GetSpellCooldownInfo(spellId)
	if type(a) == "table" then
		return {
			isEnabled = a.isEnabled,
			isOnGCD = a.isOnGCD,
			isActive = a.isActive == true,
		}
	end

	local startTime = a or 0
	local duration = b or 0
	local isEnabled = c
	return {
		isEnabled = isEnabled,
		isOnGCD = nil,
		isActive = isSpellCooldownInfoActive(nil, isEnabled, startTime, duration),
	}
end

local function buildInterruptCandidates(classTag, specId)
	if classTag == "DRUID" then
		if specId == 102 then return { 78675, 106839 } end
		return { 106839, 78675 }
	end
	if classTag == "HUNTER" then
		if specId == 255 then return { 187707, 147362 } end
		return { 147362, 187707 }
	end
	return copyValue(CLASS_INTERRUPT_SPELLS[classTag] or {})
end

function Tracker:ResolveInterruptSpell()
	local classTag = select(2, UnitClass("player"))
	if type(classTag) ~= "string" or classTag == "" then return nil end

	local specId
	if GetSpecialization and GetSpecializationInfo then
		local specIndex = GetSpecialization()
		if specIndex then specId = GetSpecializationInfo(specIndex) end
	end

	local candidates = buildInterruptCandidates(classTag, specId)
	for i = 1, #candidates do
		local spellId = tonumber(candidates[i])
		if spellId and IsSpellKnown(spellId, true) then return spellId end
	end

	return nil
end

function Tracker:GetTrackedSpellCooldown()
	local spellId = self:ResolveInterruptSpell()
	if not spellId then return nil end
	local cooldown = querySpellCooldown(spellId)
	cooldown.spellId = spellId
	return cooldown
end

function Tracker:IsTrackedSpellReady(cooldown)
	if type(cooldown) ~= "table" or not cooldown.spellId then return false end
	if cooldown.isEnabled == false then return false end
	if cooldown.isActive == true then return false end
	if cooldown.isOnGCD == true then return false end
	if cooldown.isOnGCD == nil then
		local gcdInfo = querySpellCooldown(GCD_SPELL_ID)
		if gcdInfo.isActive == true then return false end
	end
	return true
end

function Tracker:GetFocusInterruptibleCast()
	if not UnitExists or UnitExists("focus") ~= true then return nil end

	local name, _, _, _, _, _, castId, notInterruptible, spellId = UnitCastingInfo("focus")
	if name then
		return {
			hasCast = true,
			spellId = spellId,
			rawNotInterruptible = notInterruptible,
			castId = castId,
		}
	end

	name, _, _, _, _, _, notInterruptible, spellId = UnitChannelInfo("focus")
	if name then
		return {
			hasCast = true,
			spellId = spellId,
			rawNotInterruptible = notInterruptible,
		}
	end

	return nil
end

function Tracker:ResolveDisplayIcon(spellId)
	local cfg = self:GetConfig()
	local customIcon = normalizeCustomIcon(cfg.customIcon)
	if customIcon ~= nil then return customIcon end
	if spellId and C_Spell and C_Spell.GetSpellTexture then
		local texture = C_Spell.GetSpellTexture(spellId)
		if texture then return texture end
	end
	if spellId and GetSpellTexture then
		local texture = GetSpellTexture(spellId)
		if texture then return texture end
	end
	return DEFAULT_PREVIEW_ICON
end

local function applyTexture(texture, value)
	if not texture then return end
	if type(value) == "string" and value:match("^atlas:") then
		texture:SetTexture(nil)
		texture:SetAtlas(value:sub(7), true)
		return
	end
	texture:SetAtlas(nil)
	texture:SetTexture(value)
end

function Tracker:EnsureFrame()
	if state.frame then return state.frame end

	local frame = CreateFrame("Frame", "EQOLFocusInterruptTracker", UIParent)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(false)

	frame.editBg = frame:CreateTexture(nil, "BACKGROUND")
	frame.editBg:SetAllPoints(frame)
	frame.editBg:SetColorTexture(0, 0, 0, 0.35)
	frame.editBg:Hide()

	frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	frame.bg:SetAllPoints(frame)
	frame.bg:Hide()

	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.border:SetFrameLevel((frame:GetFrameLevel() or 0) + 5)
	frame.border:Hide()

	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.text:SetJustifyH("CENTER")
	frame.text:SetJustifyV("MIDDLE")
	frame.text:SetWordWrap(false)

	state.frame = frame
	return frame
end

function Tracker:ApplyLayoutData(data)
	local cfg = self:GetConfig()
	local record = type(data) == "table" and data or {}

	if record.point ~= nil then cfg.anchor.point = normalizeAnchorPoint(record.point, cfg.anchor.point) end
	if record.relativePoint ~= nil then cfg.anchor.relativePoint = normalizeAnchorPoint(record.relativePoint, cfg.anchor.relativePoint) end
	if record.x ~= nil then cfg.anchor.x = clampInt(record.x, -4096, 4096, cfg.anchor.x) end
	if record.y ~= nil then cfg.anchor.y = clampInt(record.y, -4096, 4096, cfg.anchor.y) end
	if record.anchorTarget ~= nil then cfg.anchor.relativeFrame = trimString(record.anchorTarget) or "AUTO" end

	if record.displayMode ~= nil then cfg.displayMode = normalizeDisplayMode(record.displayMode, cfg.displayMode) end
	if record.text ~= nil then cfg.text = trimString(record.text) or DEFAULT_PREVIEW_TEXT end
	if record.textFont ~= nil then cfg.textFont = record.textFont or defaults.textFont end
	if record.textSize ~= nil then cfg.textSize = clampInt(record.textSize, 8, 96, cfg.textSize) end
	if record.textOutline ~= nil then cfg.textOutline = normalizeOutline(record.textOutline, cfg.textOutline) end
	if record.textColor ~= nil then cfg.textColor = normalizeColor(record.textColor, cfg.textColor) end

	if record.iconSize ~= nil then cfg.iconSize = clampInt(record.iconSize, 8, 128, cfg.iconSize) end
	if record.customIcon ~= nil then cfg.customIcon = normalizeCustomIcon(record.customIcon) end

	if record.backgroundEnabled ~= nil then cfg.background.enabled = record.backgroundEnabled == true end
	if record.backgroundColor ~= nil then cfg.background.color = normalizeColor(record.backgroundColor, cfg.background.color) end

	if record.borderEnabled ~= nil then cfg.border.enabled = record.borderEnabled == true end
	if record.borderTexture ~= nil then cfg.border.texture = record.borderTexture or defaults.border.texture end
	if record.borderSize ~= nil then cfg.border.size = clampInt(record.borderSize, 1, 32, cfg.border.size) end
	if record.borderOffset ~= nil then cfg.border.offset = clampInt(record.borderOffset, -20, 20, cfg.border.offset) end
	if record.borderColor ~= nil then cfg.border.color = normalizeColor(record.borderColor, cfg.border.color) end

	if record.strata ~= nil then cfg.strata = normalizeStrata(record.strata, cfg.strata) end

	local frame = state.frame
	if not frame then return end

	local resolvedAnchor = self:ResolveAnchorFrame()
	frame:SetFrameStrata(cfg.strata)
	frame:ClearAllPoints()
	frame:SetPoint(cfg.anchor.point, resolvedAnchor, cfg.anchor.relativePoint, cfg.anchor.x, cfg.anchor.y)

	frame.border:SetFrameStrata(frame:GetFrameStrata())
	frame.border:SetFrameLevel((frame:GetFrameLevel() or 0) + 5)

	local displayMode = cfg.displayMode
	local isText = displayMode == "TEXT"
	local previewSpell = self:ResolveInterruptSpell()
	local previewText = cfg.text or DEFAULT_PREVIEW_TEXT
	local width, height

	if isText then
		local fontPath = self:ResolveTextFont()
		local fontOutline = cfg.textOutline == "NONE" and "" or cfg.textOutline
		local ok = frame.text:SetFont(fontPath, cfg.textSize, fontOutline)
		if ok == false then frame.text:SetFont(STANDARD_TEXT_FONT, cfg.textSize, fontOutline) end
		local color = normalizeColor(cfg.textColor, defaults.textColor)
		frame.text:SetTextColor(color[1], color[2], color[3], color[4])
		frame.text:SetText(previewText)
		frame.text:Show()
		frame.icon:Hide()
		frame.border:Hide()
		width = math.max(math.floor((frame.text:GetStringWidth() or 0) + 14 + 0.5), 48)
		height = math.max(math.floor((frame.text:GetStringHeight() or 0) + 10 + 0.5), 20)
	else
		applyTexture(frame.icon, self:ResolveDisplayIcon(previewSpell))
		frame.icon:SetSize(cfg.iconSize, cfg.iconSize)
		frame.icon:Show()
		frame.text:Hide()
		width = cfg.iconSize
		height = cfg.iconSize

		if cfg.border.enabled then
			frame.border:SetBackdrop({
				edgeFile = resolveBorderTexture(cfg.border.texture),
				edgeSize = cfg.border.size,
				insets = { left = 0, right = 0, top = 0, bottom = 0 },
			})
			local borderColor = normalizeColor(cfg.border.color, defaults.border.color)
			frame.border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
			frame.border:SetBackdropColor(0, 0, 0, 0)
			frame.border:ClearAllPoints()
			frame.border:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", -cfg.border.offset, cfg.border.offset)
			frame.border:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", cfg.border.offset, -cfg.border.offset)
			frame.border:Show()
		else
			frame.border:SetBackdrop(nil)
			frame.border:Hide()
		end
	end

	frame:SetSize(width, height)
	if cfg.background.enabled then
		local bgColor = normalizeColor(cfg.background.color, defaults.background.color)
		frame.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
		frame.bg:Show()
	else
		frame.bg:Hide()
	end
	frame.editBg:SetShown(state.previewing == true)
end

function Tracker:Refresh()
	if not self:IsEnabled() then
		if state.frame then
			state.frame.editBg:Hide()
			state.frame:Hide()
		end
		return
	end

	local frame = self:EnsureFrame()
	self:ApplyLayoutData(self:BuildLayoutRecordFromProfile())

	local cooldown = self:GetTrackedSpellCooldown()
	local spellReady = self:IsTrackedSpellReady(cooldown)

	if state.previewing then
		frame:SetAlpha(1)
		frame:Show()
		return
	end

	if not spellReady then
		frame:Hide()
		return
	end

	local focusCast = self:GetFocusInterruptibleCast()
	if not focusCast then
		frame:Hide()
		return
	end
	local spellId = cooldown and cooldown.spellId or nil

	if self:GetConfig().displayMode == "ICON" then applyTexture(frame.icon, self:ResolveDisplayIcon(spellId)) end
	applyNonInterruptibleAlpha(frame, focusCast.rawNotInterruptible)
	frame:Show()
end

function Tracker:ShowEditModeHint(show)
	state.previewing = show == true
	if not self:IsEnabled() and show ~= true then
		if state.frame then
			state.frame.editBg:Hide()
			state.frame:Hide()
		end
		return
	end

	local frame = self:EnsureFrame()
	self:ApplyLayoutData(self:BuildLayoutRecordFromProfile())
	frame.editBg:SetShown(state.previewing == true)
	if state.previewing then
		frame:SetAlpha(1)
		frame:Show()
	else
		self:Refresh()
	end
end

function Tracker:EnsureEventFrame()
	if state.eventFrame then return state.eventFrame end

	local eventFrame = CreateFrame("Frame")
	eventFrame:SetScript("OnEvent", function(_, event, ...)
		if event == "ADDON_LOADED" then
			local loadedAddon = ...
			if not EXTERNAL_ANCHOR_ADDONS[loadedAddon] then return end
			Tracker:Refresh()
			return
		end

		if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UNIT_PET" then
			local unit = ...
			if unit ~= nil and unit ~= "player" then return end
			Tracker:Refresh()
			return
		end

		if event == "SPELLS_CHANGED" or event == "SPELL_UPDATE_COOLDOWN" or event == "PLAYER_FOCUS_CHANGED"
			or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
			or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
			Tracker:Refresh()
			return
		end

		local unit = ...
		if unit ~= "focus" then return end
		Tracker:Refresh()
	end)

	state.eventFrame = eventFrame
	return eventFrame
end

function Tracker:RegisterEvents()
	local frame = self:EnsureEventFrame()
	frame:UnregisterAllEvents()
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	frame:RegisterEvent("SPELLS_CHANGED")
	frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	frame:RegisterEvent("PLAYER_TALENT_UPDATE")
	frame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
	frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
	frame:RegisterUnitEvent("UNIT_PET", "player")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "focus")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "focus")
end

function Tracker:UnregisterEvents()
	if state.eventFrame then state.eventFrame:UnregisterAllEvents() end
end

function Tracker:UnregisterEditMode()
	if not state.editModeRegistered then return end
	if EditMode and EditMode.UnregisterFrame then EditMode:UnregisterFrame(EDITMODE_ID, false) end
	state.editModeRegistered = false
end

function Tracker:RegisterEditMode()
	if state.editModeRegistered or not (EditMode and EditMode.RegisterFrame) then return end

	local frame = self:EnsureFrame()
	local settings
	if SettingType then
		settings = {
			{
				name = L["Background"] or "Background",
				kind = SettingType.Collapsible,
				id = "focusInterruptTrackerBackground",
				defaultCollapsed = true,
			},
			{
				name = L["FocusInterruptTrackerBackgroundEnabled"] or "Use background",
				kind = SettingType.Checkbox,
				field = "backgroundEnabled",
				parentId = "focusInterruptTrackerBackground",
				get = function() return Tracker:GetConfig().background.enabled end,
				set = function(_, value) Tracker:ApplyLayoutData({ backgroundEnabled = value == true }) end,
			},
			{
				name = L["FocusInterruptTrackerBackgroundColor"] or "Background color",
				kind = SettingType.Color,
				field = "backgroundColor",
				parentId = "focusInterruptTrackerBackground",
				hasOpacity = true,
				get = function()
					local color = Tracker:GetConfig().background.color
					return { r = color[1], g = color[2], b = color[3], a = color[4] }
				end,
				set = function(_, value) Tracker:ApplyLayoutData({ backgroundColor = value }) end,
				isEnabled = function() return Tracker:GetConfig().background.enabled end,
			},
			{
				name = L["FocusInterruptTrackerAnchorHeader"] or "Anchor",
				kind = SettingType.Collapsible,
				id = "focusInterruptTrackerAnchor",
				defaultCollapsed = false,
			},
			{
				name = L["FocusInterruptTrackerAnchorTarget"] or "Anchor target",
				kind = SettingType.Dropdown,
				field = "anchorTarget",
				parentId = "focusInterruptTrackerAnchor",
				height = 180,
				get = function() return Tracker:GetConfig().anchor.relativeFrame end,
				set = function(_, value) Tracker:ApplyLayoutData({ anchorTarget = value }) end,
				generator = function(_, root)
					local current = Tracker:GetConfig().anchor.relativeFrame
					for i = 1, #AUTO_ANCHOR_OPTIONS do
						local option = AUTO_ANCHOR_OPTIONS[i]
						if option.value == current or hasAnchorFrame(option) then
							root:CreateRadio(option.label, function() return Tracker:GetConfig().anchor.relativeFrame == option.value end, function()
								Tracker:ApplyLayoutData({ anchorTarget = option.value })
							end)
						end
					end
				end,
			},
			{
				name = L["FocusInterruptTrackerStrata"] or "Frame strata",
				kind = SettingType.Dropdown,
				field = "strata",
				parentId = "focusInterruptTrackerAnchor",
				height = 180,
				get = function() return Tracker:GetConfig().strata end,
				set = function(_, value) Tracker:ApplyLayoutData({ strata = value }) end,
				generator = function(_, root)
					for i = 1, #STRATA_ORDER do
						local value = STRATA_ORDER[i]
						root:CreateRadio(value, function() return Tracker:GetConfig().strata == value end, function()
							Tracker:ApplyLayoutData({ strata = value })
						end)
					end
				end,
			},
			{
				name = L["FocusInterruptTrackerDisplayHeader"] or "Display",
				kind = SettingType.Collapsible,
				id = "focusInterruptTrackerDisplay",
				defaultCollapsed = false,
			},
			{
				name = L["FocusInterruptTrackerDisplayMode"] or "Display mode",
				kind = SettingType.Dropdown,
				field = "displayMode",
				parentId = "focusInterruptTrackerDisplay",
				height = 120,
				get = function() return Tracker:GetConfig().displayMode end,
				set = function(_, value) Tracker:ApplyLayoutData({ displayMode = value }) end,
				generator = function(_, root)
					root:CreateRadio(L["FocusInterruptTrackerModeText"] or "Text", function() return Tracker:GetConfig().displayMode == "TEXT" end, function()
						Tracker:ApplyLayoutData({ displayMode = "TEXT" })
					end)
					root:CreateRadio(L["FocusInterruptTrackerModeIcon"] or "Icon", function() return Tracker:GetConfig().displayMode == "ICON" end, function()
						Tracker:ApplyLayoutData({ displayMode = "ICON" })
					end)
				end,
			},
			{
				name = L["FocusInterruptTrackerTextHeader"] or "Text",
				kind = SettingType.Collapsible,
				id = "focusInterruptTrackerText",
				defaultCollapsed = true,
				isShown = function() return Tracker:GetConfig().displayMode == "TEXT" end,
			},
			{
				name = L["FocusInterruptTrackerText"] or "Tracker text",
				kind = SettingType.Input,
				field = "text",
				parentId = "focusInterruptTrackerText",
				inputWidth = 220,
				get = function() return Tracker:GetConfig().text end,
				set = function(_, value) Tracker:ApplyLayoutData({ text = value }) end,
				default = DEFAULT_PREVIEW_TEXT,
				maxChars = 32,
				isShown = function() return Tracker:GetConfig().displayMode == "TEXT" end,
			},
			{
				name = L["Text font"] or "Text font",
				kind = SettingType.Dropdown,
				field = "textFont",
				parentId = "focusInterruptTrackerText",
				height = 200,
				get = function() return Tracker:GetConfig().textFont end,
				set = function(_, value) Tracker:ApplyLayoutData({ textFont = value }) end,
				generator = function(_, root)
					local options = getFontOptions()
					for i = 1, #options do
						local option = options[i]
						root:CreateRadio(option.label, function() return Tracker:GetConfig().textFont == option.value end, function()
							Tracker:ApplyLayoutData({ textFont = option.value })
						end)
					end
				end,
				isShown = function() return Tracker:GetConfig().displayMode == "TEXT" end,
			},
			{
				name = L["Text size"] or "Text size",
				kind = SettingType.Slider,
				field = "textSize",
				parentId = "focusInterruptTrackerText",
				minValue = 8,
				maxValue = 96,
				valueStep = 1,
				allowInput = true,
				get = function() return Tracker:GetConfig().textSize end,
				set = function(_, value) Tracker:ApplyLayoutData({ textSize = value }) end,
				isShown = function() return Tracker:GetConfig().displayMode == "TEXT" end,
			},
			{
				name = L["Font outline"] or "Font outline",
				kind = SettingType.Dropdown,
				field = "textOutline",
				parentId = "focusInterruptTrackerText",
				height = 140,
				get = function() return Tracker:GetConfig().textOutline end,
				set = function(_, value) Tracker:ApplyLayoutData({ textOutline = value }) end,
				generator = function(_, root)
					for i = 1, #OUTLINE_OPTIONS do
						local value = OUTLINE_OPTIONS[i]
						root:CreateRadio(value == "NONE" and NONE or value, function() return Tracker:GetConfig().textOutline == value end, function()
							Tracker:ApplyLayoutData({ textOutline = value })
						end)
					end
				end,
				isShown = function() return Tracker:GetConfig().displayMode == "TEXT" end,
			},
			{
				name = L["Text color"] or "Text color",
				kind = SettingType.Color,
				field = "textColor",
				parentId = "focusInterruptTrackerText",
				hasOpacity = true,
				get = function()
					local color = Tracker:GetConfig().textColor
					return { r = color[1], g = color[2], b = color[3], a = color[4] }
				end,
				set = function(_, value) Tracker:ApplyLayoutData({ textColor = value }) end,
				isShown = function() return Tracker:GetConfig().displayMode == "TEXT" end,
			},
			{
				name = L["FocusInterruptTrackerIconHeader"] or "Icon",
				kind = SettingType.Collapsible,
				id = "focusInterruptTrackerIcon",
				defaultCollapsed = true,
				isShown = function() return Tracker:GetConfig().displayMode == "ICON" end,
			},
			{
				name = L["Icon size"] or "Icon size",
				kind = SettingType.Slider,
				field = "iconSize",
				parentId = "focusInterruptTrackerIcon",
				minValue = 8,
				maxValue = 128,
				valueStep = 1,
				allowInput = true,
				get = function() return Tracker:GetConfig().iconSize end,
				set = function(_, value) Tracker:ApplyLayoutData({ iconSize = value }) end,
				isShown = function() return Tracker:GetConfig().displayMode == "ICON" end,
			},
			{
				name = L["FocusInterruptTrackerCustomIcon"] or "Custom icon",
				kind = SettingType.Input,
				field = "customIcon",
				parentId = "focusInterruptTrackerIcon",
				inputWidth = 220,
				get = function()
					local value = Tracker:GetConfig().customIcon
					return value and tostring(value) or ""
				end,
				set = function(_, value) Tracker:ApplyLayoutData({ customIcon = value }) end,
				default = "",
				maxChars = 128,
				isShown = function() return Tracker:GetConfig().displayMode == "ICON" end,
			},
			{
				name = L["FocusInterruptTrackerBorderHeader"] or "Border",
				kind = SettingType.Collapsible,
				id = "focusInterruptTrackerBorder",
				defaultCollapsed = true,
				isShown = function() return Tracker:GetConfig().displayMode == "ICON" end,
			},
			{
				name = L["Use border"] or "Use border",
				kind = SettingType.Checkbox,
				field = "borderEnabled",
				parentId = "focusInterruptTrackerBorder",
				get = function() return Tracker:GetConfig().border.enabled end,
				set = function(_, value) Tracker:ApplyLayoutData({ borderEnabled = value == true }) end,
				isShown = function() return Tracker:GetConfig().displayMode == "ICON" end,
			},
			{
				name = L["Border texture"] or "Border texture",
				kind = SettingType.Dropdown,
				field = "borderTexture",
				parentId = "focusInterruptTrackerBorder",
				height = 180,
				get = function() return Tracker:GetConfig().border.texture end,
				set = function(_, value) Tracker:ApplyLayoutData({ borderTexture = value }) end,
				generator = function(_, root)
					local options = getBorderOptions()
					for i = 1, #options do
						local option = options[i]
						root:CreateRadio(option.label, function() return Tracker:GetConfig().border.texture == option.value end, function()
							Tracker:ApplyLayoutData({ borderTexture = option.value })
						end)
					end
				end,
				isEnabled = function() return Tracker:GetConfig().border.enabled end,
				isShown = function() return Tracker:GetConfig().displayMode == "ICON" end,
			},
			{
				name = L["Border size"] or "Border size",
				kind = SettingType.Slider,
				field = "borderSize",
				parentId = "focusInterruptTrackerBorder",
				minValue = 1,
				maxValue = 32,
				valueStep = 1,
				allowInput = true,
				get = function() return Tracker:GetConfig().border.size end,
				set = function(_, value) Tracker:ApplyLayoutData({ borderSize = value }) end,
				isEnabled = function() return Tracker:GetConfig().border.enabled end,
				isShown = function() return Tracker:GetConfig().displayMode == "ICON" end,
			},
			{
				name = L["Border offset"] or "Border offset",
				kind = SettingType.Slider,
				field = "borderOffset",
				parentId = "focusInterruptTrackerBorder",
				minValue = -20,
				maxValue = 20,
				valueStep = 1,
				allowInput = true,
				get = function() return Tracker:GetConfig().border.offset end,
				set = function(_, value) Tracker:ApplyLayoutData({ borderOffset = value }) end,
				isEnabled = function() return Tracker:GetConfig().border.enabled end,
				isShown = function() return Tracker:GetConfig().displayMode == "ICON" end,
			},
			{
				name = L["Border color"] or "Border color",
				kind = SettingType.Color,
				field = "borderColor",
				parentId = "focusInterruptTrackerBorder",
				hasOpacity = true,
				get = function()
					local color = Tracker:GetConfig().border.color
					return { r = color[1], g = color[2], b = color[3], a = color[4] }
				end,
				set = function(_, value) Tracker:ApplyLayoutData({ borderColor = value }) end,
				isEnabled = function() return Tracker:GetConfig().border.enabled end,
				isShown = function() return Tracker:GetConfig().displayMode == "ICON" end,
			},
		}
	end

	EditMode:RegisterFrame(EDITMODE_ID, {
		frame = frame,
		title = L["FocusInterruptTracker"] or "Focus Interrupt Tracker",
		layoutDefaults = self:BuildLayoutRecordFromProfile(),
		onApply = function(_, _, data)
			if not state.editModeHydrated then
				state.editModeHydrated = true
				local record = data or {}
				seedEditModeRecordFromProfile(record)
				Tracker:ApplyLayoutData(record)
				return
			end
			Tracker:ApplyLayoutData(data)
		end,
		onEnter = function() Tracker:ShowEditModeHint(true) end,
		onExit = function() Tracker:ShowEditModeHint(false) end,
		isEnabled = function() return Tracker:IsEnabled() end,
		settings = settings,
		relativeTo = function() return Tracker:ResolveAnchorFrame() end,
		allowDrag = true,
		settingsMaxHeight = DEFAULT_SETTINGS_MAX_HEIGHT,
		showOutsideEditMode = false,
		collapseExclusive = true,
		showReset = false,
		showSettingsReset = false,
		enableOverlayToggle = true,
	})

	state.editModeRegistered = true
end

function Tracker:OnSettingChanged(enabled)
	local cfg = self:GetConfig()
	cfg.enabled = enabled == true

	if cfg.enabled then
		self:EnsureFrame()
		self:RegisterEditMode()
		self:RegisterEvents()
		self:Refresh()
	else
		self:UnregisterEvents()
		self:UnregisterEditMode()
		state.previewing = false
		state.editModeHydrated = false
		if state.frame then
			state.frame.editBg:Hide()
			state.frame:Hide()
		end
	end

	if EditMode and EditMode.RefreshFrame then EditMode:RefreshFrame(EDITMODE_ID) end
end

return Tracker
