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
CooldownPanels.helper = CooldownPanels.helper or {}
local Helper = CooldownPanels.helper
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")
local LSM = LibStub("LibSharedMedia-3.0", true)

Helper.Api = Helper.Api or {}
local Api = Helper.Api

Api.GetItemInfoInstantFn = C_Item and C_Item.GetItemInfoInstant
Api.GetItemIconByID = C_Item and C_Item.GetItemIconByID
Api.GetItemCooldownFn = C_Item and C_Item.GetItemCooldown
Api.GetItemSpell = C_Item and C_Item.GetItemSpell
Api.GetInventoryItemID = GetInventoryItemID
Api.GetInventoryItemCooldown = GetInventoryItemCooldown
Api.GetInventorySlotInfo = GetInventorySlotInfo
Api.GetActionInfo = GetActionInfo
Api.GetActionText = C_ActionBar and C_ActionBar.GetActionText
Api.GetCursorInfo = GetCursorInfo
Api.GetCursorPosition = GetCursorPosition
Api.ClearCursor = ClearCursor
Api.DoesSpellExist = C_Spell and C_Spell.DoesSpellExist
Api.GetSpellInfoFn = GetSpellInfo
Api.GetSpellCooldownInfo = C_Spell and C_Spell.GetSpellCooldown or GetSpellCooldown
Api.GetSpellCooldownDuration = C_Spell and C_Spell.GetSpellCooldownDuration
Api.GetSpellChargesInfo = C_Spell and C_Spell.GetSpellCharges
Api.GetAuraDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration
Api.GetBaseSpell = C_Spell and C_Spell.GetBaseSpell
Api.GetOverrideSpell = C_Spell and C_Spell.GetOverrideSpell
Api.GetSpellPowerCost = C_Spell and C_Spell.GetSpellPowerCost
Api.EnableSpellRangeCheck = C_Spell and C_Spell.EnableSpellRangeCheck
Api.IsSpellUsableFn = C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
Api.IsSpellPassiveFn = C_Spell and C_Spell.IsSpellPassive or IsPassiveSpell
Api.GetAssistedCombatNextSpell = C_AssistedCombat and C_AssistedCombat.GetNextCastSpell
Api.GetAssistedCombatRotationSpells = C_AssistedCombat and C_AssistedCombat.GetRotationSpells
Api.GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo
Api.GetFilenameFromFileDataID = C_Texture and C_Texture.GetFilenameFromFileDataID
Api.IsSpellKnown = function(spellId, includeOverrides)
	if not spellId then return false end
	if not (C_SpellBook and C_SpellBook.IsSpellInSpellBook) then return true end
	local spellBank = Enum and Enum.SpellBookSpellBank
	local playerBank = (spellBank and spellBank.Player) or 0
	local petBank = (spellBank and spellBank.Pet) or 1
	if C_SpellBook.IsSpellInSpellBook(spellId, playerBank, includeOverrides) then return true end
	if C_SpellBook.IsSpellInSpellBook(spellId, petBank, includeOverrides) then return true end
	return false
end
Api.GetMacroInfo = GetMacroInfo
Api.GetMacroSpell = GetMacroSpell
Api.GetMacroItem = GetMacroItem
Api.GetMacroIndexByName = GetMacroIndexByName
Api.IsEquippedItem = C_Item.IsEquippedItem
Api.GetTime = GetTime
Api.MenuUtil = MenuUtil
Api.issecretvalue = _G.issecretvalue
Api.DurationModifierRealTime = Enum and Enum.DurationTimeModifier and Enum.DurationTimeModifier.RealTime

function Api.GetItemCount(itemID, includeBank, includeUses, includeReagentBank, includeAccountBank)
	if not itemID then return 0 end
	if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID, includeBank, includeUses, includeReagentBank, includeAccountBank) end
	return 0
end

Helper.DirectionOptions = {
	{ value = "LEFT", label = _G.HUD_EDIT_MODE_SETTING_BAGS_DIRECTION_LEFT or _G.LEFT or "Left" },
	{ value = "RIGHT", label = _G.HUD_EDIT_MODE_SETTING_BAGS_DIRECTION_RIGHT or _G.RIGHT or "Right" },
	{ value = "UP", label = _G.HUD_EDIT_MODE_SETTING_BAGS_DIRECTION_UP or _G.UP or "Up" },
	{ value = "DOWN", label = _G.HUD_EDIT_MODE_SETTING_BAGS_DIRECTION_DOWN or _G.DOWN or "Down" },
}
Helper.LayoutModeOptions = {
	{ value = "GRID", label = L["CooldownPanelLayoutModeGrid"] or "Grid" },
	{ value = "FIXED", label = L["CooldownPanelLayoutModeFixed"] or "Fixed slots" },
	{ value = "RADIAL", label = L["CooldownPanelLayoutModeRadial"] or "Radial" },
}
Helper.AnchorOptions = {
	{ value = "TOPLEFT", label = L["Top Left"] or "Top Left" },
	{ value = "TOP", label = L["Top"] or "Top" },
	{ value = "TOPRIGHT", label = L["Top Right"] or "Top Right" },
	{ value = "LEFT", label = L["Left"] or "Left" },
	{ value = "CENTER", label = L["Center"] or "Center" },
	{ value = "RIGHT", label = L["Right"] or "Right" },
	{ value = "BOTTOMLEFT", label = L["Bottom Left"] or "Bottom Left" },
	{ value = "BOTTOM", label = L["Bottom"] or "Bottom" },
	{ value = "BOTTOMRIGHT", label = L["Bottom Right"] or "Bottom Right" },
}
Helper.GrowthPointOptions = {
	{ value = "TOPLEFT", label = L["Left"] or "Left" },
	{ value = "TOP", label = L["Center"] or "Center" },
	{ value = "TOPRIGHT", label = L["Right"] or "Right" },
}
Helper.FontStyleOptions = {
	{ value = "NONE", label = L["None"] or "None" },
	{ value = "OUTLINE", label = L["Outline"] or "Outline" },
	{ value = "THICKOUTLINE", label = L["Thick Outline"] or "Thick Outline" },
	{ value = "MONOCHROMEOUTLINE", label = L["Monochrome Outline"] or "Monochrome Outline" },
}

-- need for static text hide on CD
local curveFake = C_CurveUtil:CreateCurve()
curveFake:SetType(Enum.LuaCurveType.Step)
curveFake:AddPoint(0, 0)
curveFake:AddPoint(0.5, 0)
curveFake:AddPoint(0.51, 1)
Helper.FakeCurve = curveFake

local function normalizeCDMAuraAlwaysShowMode(value, fallback)
	local mode = type(value) == "string" and string.upper(value) or nil
	if mode == "SHOW" or mode == "DESATURATE" or mode == "HIDE" then return mode end
	return fallback or "HIDE"
end

Helper.PANEL_LAYOUT_DEFAULTS = {
	iconSize = 36,
	spacing = 2,
	layoutMode = "GRID",
	fixedSlotCount = 0,
	fixedGridColumns = 0,
	fixedGridRows = 0,
	direction = "RIGHT",
	wrapCount = 0,
	wrapDirection = "DOWN",
	growthPoint = "TOPLEFT",
	radialRadius = 80,
	radialRotation = 0,
	radialArcDegrees = 360,
	strata = "MEDIUM",
	rangeOverlayEnabled = false,
	rangeOverlayColor = { 1, 0.1, 0.1, 0.35 },
	procGlowEnabled = true,
	hideGlowOutOfCombat = false,
	readyGlowStyle = "MARCHING_ANTS",
	readyGlowColor = { 1, 0.82, 0.2, 1 },
	pandemicGlowColor = { 1, 0.82, 0.2, 1 },
	readyGlowInset = 0,
	readyGlowDuration = 0,
	readyGlowCheckPower = false,
	noDesaturation = false,
	cdmAuraAlwaysShowMode = "HIDE",
	checkPower = false,
	hideWhenNoResource = false,
	powerTintColor = { 0.5, 0.5, 1, 1 },
	unusableTintColor = { 0.6, 0.6, 0.6, 1 },
	opacityOutOfCombat = 1,
	opacityInCombat = 1,
	hideInVehicle = false,
	hideInPetBattle = false,
	hideInClientScene = true,
	hideOnCooldown = false,
	showOnCooldown = false,
	showIconTexture = true,
	iconBorderEnabled = false,
	iconBorderTexture = "DEFAULT",
	iconBorderSize = 1,
	iconBorderOffset = 0,
	iconBorderColor = { 0, 0, 0, 0.8 },
	stackAnchor = "BOTTOMRIGHT",
	stackX = -1,
	stackY = 1,
	stackFontSize = 12,
	stackFontStyle = "OUTLINE",
	stackColor = { 1, 1, 1, 1 },
	chargesAnchor = "TOP",
	chargesX = 0,
	chargesY = -1,
	chargesFontSize = 12,
	chargesFontStyle = "OUTLINE",
	chargesColor = { 1, 1, 1, 1 },
	chargesHideWhenZero = false,
	keybindsEnabled = false,
	keybindsIgnoreItems = false,
	keybindAnchor = "TOPLEFT",
	keybindX = 2,
	keybindY = -2,
	keybindFontSize = 10,
	keybindFontStyle = "OUTLINE",
	cooldownDrawEdge = true,
	cooldownDrawBling = true,
	cooldownDrawSwipe = true,
	cooldownGcdDrawEdge = false,
	cooldownGcdDrawBling = false,
	cooldownGcdDrawSwipe = false,
	cooldownTextColor = { 1, 1, 1, 1 },
	staticTextFont = "",
	staticTextSize = 12,
	staticTextStyle = "OUTLINE",
	staticTextColor = { 1, 1, 1, 1 },
	staticTextAnchor = "CENTER",
	staticTextX = 0,
	staticTextY = 0,
	showChargesCooldown = false,
	showTooltips = false,
}

Helper.ENTRY_DEFAULTS = {
	alwaysShow = true,
	cdmAuraAlwaysShowUseGlobal = true,
	cdmAuraAlwaysShowMode = "HIDE",
	hideIcon = false,
	iconSizeUseGlobal = true,
	iconSize = 36,
	iconOffsetX = 0,
	iconOffsetY = 0,
	showCooldown = true,
	showCooldownText = true,
	showCharges = false,
	showStacks = false,
	stackStyleUseGlobal = true,
	stackAnchor = "BOTTOMRIGHT",
	stackX = -1,
	stackY = 1,
	stackFont = "",
	stackFontSize = 12,
	stackFontStyle = "OUTLINE",
	stackColor = { 1, 1, 1, 1 },
	chargesStyleUseGlobal = true,
	chargesAnchor = "TOP",
	chargesX = 0,
	chargesY = -1,
	chargesFont = "",
	chargesFontSize = 12,
	chargesFontStyle = "OUTLINE",
	chargesColor = { 1, 1, 1, 1 },
	showItemUses = false,
	showWhenEmpty = false,
	useHighestRank = false,
	showWhenNoCooldown = false,
	showWhenMissing = false,
	showIconTextureUseGlobal = true,
	cooldownVisualsUseGlobal = true,
	showChargesCooldown = false,
	cooldownDrawEdge = true,
	cooldownDrawBling = true,
	cooldownDrawSwipe = true,
	cooldownGcdDrawEdge = false,
	cooldownGcdDrawBling = false,
	cooldownGcdDrawSwipe = false,
	cooldownTextUseGlobal = true,
	noDesaturationUseGlobal = true,
	noDesaturation = false,
	checkPowerUseGlobal = true,
	checkPower = false,
	hideWhenNoResourceUseGlobal = true,
	hideWhenNoResource = false,
	glowReady = false,
	readyGlowCheckPower = false,
	pandemicGlow = false,
	pandemicGlowColor = nil,
	procGlowEnabled = true,
	procGlowUseGlobal = true,
	glowUseGlobal = true,
	glowDuration = 0,
	soundReady = false,
	soundReadyFile = "None",
	staticText = "",
	staticTextShowOnCooldown = false,
	staticTextUseGlobal = true,
	staticTextFont = "",
	staticTextSize = 12,
	staticTextStyle = "OUTLINE",
	staticTextColor = { 1, 1, 1, 1 },
	staticTextAnchor = "CENTER",
	staticTextX = 0,
	staticTextY = 0,
	stateTextureInput = "",
	stateTextureScale = 1,
	stateTextureWidth = 1,
	stateTextureHeight = 1,
	stateTextureAngle = 0,
	stateTextureDouble = false,
	stateTextureMirror = false,
	stateTextureMirrorSecond = true,
	stateTextureSpacingX = 0,
	stateTextureSpacingY = 0,
}

Helper.DEFAULT_PREVIEW_COUNT = 6
Helper.MAX_PREVIEW_COUNT = 200
Helper.PREVIEW_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
Helper.PREVIEW_ICON_SIZE = 36
Helper.PREVIEW_COUNT_FONT_MIN = 12
Helper.OFFSET_RANGE = 200
Helper.SPACING_RANGE = 200
Helper.STATE_TEXTURE_SPACING_RANGE = 2000
Helper.GLOW_INSET_RANGE = 20
Helper.RADIAL_RADIUS_RANGE = 600
Helper.RADIAL_ROTATION_RANGE = 360
Helper.RADIAL_ARC_DEGREES_MIN = 15
Helper.RADIAL_ARC_DEGREES_MAX = 360
Helper.EXAMPLE_COOLDOWN_PERCENT = 0.55
Helper.GLOW_STYLE_OPTIONS = {
	{ value = "MARCHING_ANTS", labelKey = "CooldownPanelGlowStyleMarchingAnts", fallback = "Marching ants" },
	{ value = "FLASH", labelKey = "CooldownPanelGlowStyleFlash", fallback = "Flash" },
	{ value = "BLIZZARD", labelKey = "CooldownPanelGlowStyleBlizzard", fallback = "Blizzard" },
}
Helper.VALID_DIRECTIONS = {
	RIGHT = true,
	LEFT = true,
	UP = true,
	DOWN = true,
}

function Helper.NormalizeGlowStyle(style, fallback)
	local normalized = type(style) == "string" and strupper(style) or nil
	if normalized == "BLIZZARD" or normalized == "CLASSIC" or normalized == "BUTTON_GLOW" then return "BLIZZARD" end
	if normalized == "MARCHING_ANTS" or normalized == "MARCHINGANTS" or normalized == "ANTS" then return "MARCHING_ANTS" end
	if normalized == "FLASH" then return "FLASH" end
	local normalizedFallback = type(fallback) == "string" and strupper(fallback) or nil
	if normalizedFallback == "BLIZZARD" or normalizedFallback == "CLASSIC" or normalizedFallback == "BUTTON_GLOW" then return "BLIZZARD" end
	if normalizedFallback == "FLASH" then return "FLASH" end
	if normalizedFallback == "MARCHING_ANTS" or normalizedFallback == "MARCHINGANTS" or normalizedFallback == "ANTS" then return "MARCHING_ANTS" end
	return Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle or "MARCHING_ANTS"
end

function Helper.NormalizeGlowInset(value, fallback) return Helper.ClampInt(value, -Helper.GLOW_INSET_RANGE, Helper.GLOW_INSET_RANGE, fallback) end

function Helper.NormalizeTextureInput(value)
	if type(value) ~= "string" then return "" end
	if strtrim then return strtrim(value) end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Helper.ResolveTextureInput(value)
	local input = Helper.NormalizeTextureInput(value)
	if input == "" then return nil end

	local fileDataID = tonumber(input)
	if fileDataID and fileDataID > 0 and math.floor(fileDataID) == fileDataID then
		if Api.GetFilenameFromFileDataID then
			local ok, filename = pcall(Api.GetFilenameFromFileDataID, fileDataID)
			if ok and type(filename) == "string" and filename ~= "" then return "FILEID", fileDataID, filename end
			return nil
		end
		return "FILEID", fileDataID
	end

	if Api.GetAtlasInfo then
		local ok, info = pcall(Api.GetAtlasInfo, input)
		if ok and info then return "ATLAS", input, info end
	end

	return nil
end

Helper.VALID_LAYOUT_MODES = {
	GRID = true,
	FIXED = true,
	RADIAL = true,
}
local STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
Helper.STRATA_ORDER = STRATA_ORDER
Helper.VALID_STRATA = {}
for _, strata in ipairs(STRATA_ORDER) do
	Helper.VALID_STRATA[strata] = true
end
Helper.VALID_ANCHORS = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}
Helper.VALID_FONT_STYLE = {
	NONE = true,
	OUTLINE = true,
	THICKOUTLINE = true,
	MONOCHROMEOUTLINE = true,
}
Helper.GENERIC_ANCHORS = {
	EQOL_ANCHOR_PLAYER = {
		label = L["UFPlayerFrame"] or _G.HUD_EDIT_MODE_PLAYER_FRAME_LABEL or "Player Frame",
		blizz = "PlayerFrame",
		uf = "EQOLUFPlayerFrame",
		ufKey = "player",
	},
	EQOL_ANCHOR_TARGET = {
		label = L["UFTargetFrame"] or _G.HUD_EDIT_MODE_TARGET_FRAME_LABEL or "Target Frame",
		blizz = "TargetFrame",
		uf = "EQOLUFTargetFrame",
		ufKey = "target",
	},
	EQOL_ANCHOR_TARGETTARGET = {
		label = L["UFToTFrame"] or "Target of Target",
		blizz = "TargetFrameToT",
		uf = "EQOLUFToTFrame",
		ufKey = "targettarget",
	},
	EQOL_ANCHOR_FOCUS = {
		label = L["UFFocusFrame"] or _G.HUD_EDIT_MODE_FOCUS_FRAME_LABEL or "Focus Frame",
		blizz = "FocusFrame",
		uf = "EQOLUFFocusFrame",
		ufKey = "focus",
	},
	EQOL_ANCHOR_PET = {
		label = L["UFPetFrame"] or _G.HUD_EDIT_MODE_PET_FRAME_LABEL or "Pet Frame",
		blizz = "PetFrame",
		uf = "EQOLUFPetFrame",
		ufKey = "pet",
	},
	EQOL_ANCHOR_BOSS = {
		label = L["UFBossFrame"] or _G.HUD_EDIT_MODE_BOSS_FRAMES_LABEL or "Boss Frame",
		blizz = "BossTargetFrameContainer",
		uf = "EQOLUFBossContainer",
		ufKey = "boss",
	},
}
Helper.GENERIC_ANCHOR_ORDER = {
	"EQOL_ANCHOR_PLAYER",
	"EQOL_ANCHOR_TARGET",
	"EQOL_ANCHOR_TARGETTARGET",
	"EQOL_ANCHOR_FOCUS",
	"EQOL_ANCHOR_PET",
	"EQOL_ANCHOR_BOSS",
}
Helper.GENERIC_ANCHOR_BY_FRAME = {
	PlayerFrame = "EQOL_ANCHOR_PLAYER",
	EQOLUFPlayerFrame = "EQOL_ANCHOR_PLAYER",
	TargetFrame = "EQOL_ANCHOR_TARGET",
	EQOLUFTargetFrame = "EQOL_ANCHOR_TARGET",
	TargetFrameToT = "EQOL_ANCHOR_TARGETTARGET",
	EQOLUFToTFrame = "EQOL_ANCHOR_TARGETTARGET",
	FocusFrame = "EQOL_ANCHOR_FOCUS",
	EQOLUFFocusFrame = "EQOL_ANCHOR_FOCUS",
	PetFrame = "EQOL_ANCHOR_PET",
	EQOLUFPetFrame = "EQOL_ANCHOR_PET",
	BossTargetFrameContainer = "EQOL_ANCHOR_BOSS",
	EQOLUFBossContainer = "EQOL_ANCHOR_BOSS",
}

function Helper.ClampNumber(value, minValue, maxValue, fallback)
	local num = tonumber(value)
	if num == nil then return fallback end
	if minValue ~= nil and num < minValue then return minValue end
	if maxValue ~= nil and num > maxValue then return maxValue end
	return num
end

function Helper.ClampInt(value, minValue, maxValue, fallback)
	local num = Helper.ClampNumber(value, minValue, maxValue, fallback)
	if num == nil then return nil end
	return math.floor(num + 0.5)
end

function Helper.NormalizeDirection(direction, fallback)
	if direction and Helper.VALID_DIRECTIONS[direction] then return direction end
	if fallback and Helper.VALID_DIRECTIONS[fallback] then return fallback end
	return "RIGHT"
end

function Helper.NormalizeLayoutMode(value, fallback)
	if type(value) == "string" then
		local upper = string.upper(value)
		if Helper.VALID_LAYOUT_MODES[upper] then return upper end
	end
	if type(fallback) == "string" then
		local upper = string.upper(fallback)
		if Helper.VALID_LAYOUT_MODES[upper] then return upper end
	end
	return "GRID"
end

function Helper.IsFixedLayout(layout) return Helper.NormalizeLayoutMode(layout and layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode) == "FIXED" end

function Helper.NormalizeSlotIndex(value, fallback)
	local num = Helper.ClampInt(value, 1, 200, fallback)
	if num == nil or num < 1 then return nil end
	return num
end

function Helper.NormalizeFixedSlotCount(value, fallback)
	local num = Helper.ClampInt(value, 0, 200, fallback)
	if num == nil or num < 0 then return 0 end
	return num
end

function Helper.NormalizeSlotCoordinate(value, fallback)
	local num = Helper.ClampInt(value, 1, 200, fallback)
	if num == nil or num < 1 then return nil end
	return num
end

function Helper.NormalizeFixedGridSize(value, fallback)
	local num = Helper.ClampInt(value, 0, 40, fallback)
	if num == nil or num < 0 then return 0 end
	return num
end

function Helper.NormalizeFixedGroupMode(value, fallback)
	local mode = type(value) == "string" and string.upper(value) or nil
	if mode == "STATIC" or mode == "DYNAMIC" then return mode end
	return fallback or "DYNAMIC"
end

function Helper.GetFixedGroupMode(group)
	if type(group) ~= "table" then return "DYNAMIC" end
	return Helper.NormalizeFixedGroupMode(group.mode, "DYNAMIC")
end

function Helper.FixedGroupUsesStaticSlots(group)
	if type(group) == "table" and type(group._eqolIsStatic) == "boolean" then return group._eqolIsStatic == true end
	return Helper.GetFixedGroupMode(group) == "STATIC"
end

function Helper.NormalizeFixedGroupIconSize(value)
	local size = Helper.ClampInt(value, 12, 128, nil)
	if size == nil then return nil end
	return size
end

function Helper.NormalizeFixedGroupLayoutOverrides(value)
	if type(value) ~= "table" then return nil end
	local normalized = {}
	local iconOffsetX = Helper.ClampInt(value.iconOffsetX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
	local iconOffsetY = Helper.ClampInt(value.iconOffsetY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
	if iconOffsetX ~= 0 then normalized.iconOffsetX = iconOffsetX end
	if iconOffsetY ~= 0 then normalized.iconOffsetY = iconOffsetY end
	if type(value.procGlowEnabled) == "boolean" then normalized.procGlowEnabled = value.procGlowEnabled == true end
	if type(value.hideGlowOutOfCombat) == "boolean" then normalized.hideGlowOutOfCombat = value.hideGlowOutOfCombat == true end
	if value.procGlowStyle ~= nil then normalized.procGlowStyle = Helper.NormalizeGlowStyle(value.procGlowStyle, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle) end
	if value.procGlowInset ~= nil then normalized.procGlowInset = Helper.NormalizeGlowInset(value.procGlowInset, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0) end
	if type(value.readyGlowCheckPower) == "boolean" then normalized.readyGlowCheckPower = value.readyGlowCheckPower == true end
	if value.readyGlowStyle ~= nil then normalized.readyGlowStyle = Helper.NormalizeGlowStyle(value.readyGlowStyle, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle) end
	if value.readyGlowInset ~= nil then normalized.readyGlowInset = Helper.NormalizeGlowInset(value.readyGlowInset, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0) end
	if value.readyGlowColor ~= nil then normalized.readyGlowColor = Helper.NormalizeColor(value.readyGlowColor, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor) end
	if value.pandemicGlowStyle ~= nil then normalized.pandemicGlowStyle = Helper.NormalizeGlowStyle(value.pandemicGlowStyle, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle) end
	if value.pandemicGlowInset ~= nil then normalized.pandemicGlowInset = Helper.NormalizeGlowInset(value.pandemicGlowInset, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0) end
	if value.pandemicGlowColor ~= nil then
		normalized.pandemicGlowColor = Helper.NormalizeColor(
			value.pandemicGlowColor,
			Helper.PANEL_LAYOUT_DEFAULTS.pandemicGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor
		)
	end
	if not next(normalized) then return nil end
	return normalized
end

local function getFixedGridDefaultColumns(panel)
	if type(panel) ~= "table" then return 4 end
	local layout = type(panel.layout) == "table" and panel.layout or nil
	local configured = Helper.NormalizeFixedGridSize(layout and layout.fixedGridColumns, 0)
	if configured > 0 then return configured end
	local wrapCount = Helper.ClampInt(layout and layout.wrapCount, 0, 40, Helper.PANEL_LAYOUT_DEFAULTS.wrapCount or 0)
	if wrapCount and wrapCount > 0 then return wrapCount end
	local entryCount = type(panel.order) == "table" and #panel.order or 0
	if entryCount <= 0 then return 4 end
	if entryCount <= 4 then return entryCount end
	return math.min(math.max(math.ceil(math.sqrt(entryCount)), 4), 12)
end

local function getFixedCellKey(column, row) return tostring(column) .. ":" .. tostring(row) end

function Helper.NormalizeFixedGroupId(value)
	if type(value) == "number" then value = tostring(math.floor(value)) end
	if type(value) ~= "string" then return nil end
	if strtrim then
		value = strtrim(value)
	else
		value = value:match("^%s*(.-)%s*$")
	end
	if value == "" then return nil end
	return value
end

function Helper.NormalizeFixedGroups(layout)
	if type(layout) ~= "table" then return {} end
	local source = layout.fixedGroups
	if type(source) ~= "table" then
		source = {}
		layout.fixedGroups = source
		return source
	end
	local seen = {}
	local fallbackIndex = 1
	local writeIndex = 1
	for i = 1, #source do
		local group = source[i]
		if type(group) == "table" then
			local id = Helper.NormalizeFixedGroupId(group.id)
			if not id then id = "group" .. tostring(fallbackIndex) end
			while seen[id] do
				fallbackIndex = fallbackIndex + 1
				id = "group" .. tostring(fallbackIndex)
			end
			local column = Helper.NormalizeSlotCoordinate(group.column)
			local row = Helper.NormalizeSlotCoordinate(group.row)
			local columns = Helper.NormalizeFixedGridSize(group.columns, 0)
			local rows = Helper.NormalizeFixedGridSize(group.rows, 0)
			if column and row and columns > 0 and rows > 0 then
				local name = type(group.name) == "string" and group.name or ""
				if strtrim then
					name = strtrim(name)
				else
					name = name:match("^%s*(.-)%s*$")
				end
				if name == "" then name = "Group " .. tostring(fallbackIndex) end
				if writeIndex ~= i then
					source[writeIndex] = group
					source[i] = nil
				end
				group.id = id
				group.name = name
				group.column = column
				group.row = row
				group.columns = columns
				group.rows = rows
				group.mode = Helper.NormalizeFixedGroupMode(group.mode, "DYNAMIC")
				group._eqolIsStatic = group.mode == "STATIC"
				group._eqolCapacity = columns * rows
				group.iconSize = Helper.NormalizeFixedGroupIconSize(group.iconSize)
				group.layoutOverrides = Helper.NormalizeFixedGroupLayoutOverrides(group.layoutOverrides)
				group._eqolDynamicTargetIndices = nil
				seen[id] = true
				writeIndex = writeIndex + 1
			end
			fallbackIndex = fallbackIndex + 1
		end
	end
	for i = writeIndex, #source do
		source[i] = nil
	end
	layout.fixedGroups = source
	return source
end

function Helper.InvalidateFixedLayoutCache(panel)
	if type(panel) ~= "table" then return end
	panel._eqolFixedLayoutCache = nil
end

function Helper.GetFixedGroupById(panelOrLayout, groupId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if not groupId then return nil end
	if type(panelOrLayout) == "table" and type(panelOrLayout.entries) == "table" and type(panelOrLayout.order) == "table" then
		local cache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panelOrLayout) or nil
		local group = cache and cache.groupById and cache.groupById[groupId] or nil
		if group then return group, cache and cache.groupIndexById and cache.groupIndexById[groupId] or nil end
	end
	local layout = panelOrLayout
	if type(panelOrLayout) == "table" and type(panelOrLayout.layout) == "table" then layout = panelOrLayout.layout end
	local groups = Helper.NormalizeFixedGroups(layout)
	for i = 1, #groups do
		local group = groups[i]
		if group and group.id == groupId then return group, i end
	end
	return nil
end

function Helper.GetFixedGroupCapacity(group)
	if type(group) ~= "table" then return 0 end
	if type(group._eqolCapacity) == "number" then return group._eqolCapacity end
	local columns = Helper.NormalizeFixedGridSize(group.columns, 0)
	local rows = Helper.NormalizeFixedGridSize(group.rows, 0)
	if columns <= 0 or rows <= 0 then return 0 end
	return columns * rows
end

function Helper.GetFixedGridCapacity(panel)
	if type(panel) ~= "table" then return 0 end
	local layout = type(panel.layout) == "table" and panel.layout or nil
	local columns = Helper.NormalizeFixedGridSize(layout and layout.fixedGridColumns, 0)
	local rows = Helper.NormalizeFixedGridSize(layout and layout.fixedGridRows, 0)
	if columns <= 0 or rows <= 0 then return 0 end
	return columns * rows
end

function Helper.GetFixedGroupAtCell(panelOrLayout, column, row, ignoreGroupId)
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	ignoreGroupId = Helper.NormalizeFixedGroupId(ignoreGroupId)
	if not (column and row) then return nil end
	if type(panelOrLayout) == "table" and type(panelOrLayout.entries) == "table" and type(panelOrLayout.order) == "table" and ignoreGroupId == nil then
		local cache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panelOrLayout) or nil
		local group = cache and cache.groupAtCell and cache.groupAtCell[getFixedCellKey(column, row)] or nil
		if group then
			local groupId = group and group.id or nil
			return group, groupId and cache and cache.groupIndexById and cache.groupIndexById[groupId] or nil
		end
	end
	local layout = panelOrLayout
	if type(panelOrLayout) == "table" and type(panelOrLayout.layout) == "table" then layout = panelOrLayout.layout end
	local groups = Helper.NormalizeFixedGroups(layout)
	for i = 1, #groups do
		local group = groups[i]
		if group and group.id ~= ignoreGroupId then
			local right = group.column + group.columns - 1
			local bottom = group.row + group.rows - 1
			if column >= group.column and column <= right and row >= group.row and row <= bottom then return group, i end
		end
	end
	return nil
end

function Helper.GetFixedGroupLocalIndex(group, column, row)
	if type(group) ~= "table" then return nil end
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	if not (column and row) then return nil end
	local relativeColumn = column - group.column + 1
	local relativeRow = row - group.row + 1
	if relativeColumn < 1 or relativeRow < 1 or relativeColumn > group.columns or relativeRow > group.rows then return nil end
	return ((relativeRow - 1) * group.columns) + relativeColumn
end

function Helper.SyncEntryFixedGroupIconState(panelOrLayout, entry, resolvedGroup)
	if type(entry) ~= "table" then return nil end
	local group = type(resolvedGroup) == "table" and resolvedGroup or Helper.GetFixedGroupById(panelOrLayout, entry.fixedGroupId)
	local groupIconSize = group and Helper.NormalizeFixedGroupIconSize(group.iconSize) or nil
	if group and groupIconSize ~= nil then
		if entry.fixedGroupIconSizeInherited ~= true then
			entry.fixedGroupIconSizePrevUseGlobal = entry.iconSizeUseGlobal
			entry.fixedGroupIconSizePrev = entry.iconSize
		end
		entry.iconSizeUseGlobal = false
		entry.iconSize = groupIconSize
		entry.fixedGroupIconSizeInherited = true
	elseif entry.fixedGroupIconSizeInherited == true then
		local previousUseGlobal = entry.fixedGroupIconSizePrevUseGlobal
		if type(previousUseGlobal) == "boolean" then
			entry.iconSizeUseGlobal = previousUseGlobal
		else
			entry.iconSizeUseGlobal = true
		end
		entry.iconSize = entry.fixedGroupIconSizePrev
		entry.fixedGroupIconSizeInherited = nil
		entry.fixedGroupIconSizePrevUseGlobal = nil
		entry.fixedGroupIconSizePrev = nil
	else
		entry.fixedGroupIconSizeInherited = nil
		entry.fixedGroupIconSizePrevUseGlobal = nil
		entry.fixedGroupIconSizePrev = nil
	end
	return group
end

function Helper.GetFixedLayoutCache(panel)
	if type(panel) ~= "table" or type(panel.entries) ~= "table" or type(panel.order) ~= "table" then return nil end
	panel.layout = type(panel.layout) == "table" and panel.layout or {}
	local layout = panel.layout
	local cache = panel._eqolFixedLayoutCache
	local groupsRef = type(layout.fixedGroups) == "table" and layout.fixedGroups or nil
	if
		cache
		and cache.layoutRef == layout
		and cache.groupsRef == groupsRef
		and cache.entriesRef == panel.entries
		and cache.orderRef == panel.order
		and cache.orderCount == #panel.order
		and cache.groupCount == (groupsRef and #groupsRef or 0)
		and cache.fixedGridColumns == layout.fixedGridColumns
		and cache.fixedGridRows == layout.fixedGridRows
		and cache.wrapCount == layout.wrapCount
	then
		return cache
	end

	local fixedGroups = Helper.NormalizeFixedGroups(layout)
	local fixedGroupById = {}
	local fixedGroupIndexById = {}
	local fixedGroupAtCell = {}
	local groupEntryIds = {}
	local dynamicGroupEntries = {}
	local entryAtUngroupedCell = {}
	local entryAtStaticGroupCell = {}
	local placedEntries = {}
	local configuredColumns = Helper.NormalizeFixedGridSize(layout.fixedGridColumns, 0)
	local configuredRows = Helper.NormalizeFixedGridSize(layout.fixedGridRows, 0)
	local used = {}
	local groupStates = {}
	local columns = getFixedGridDefaultColumns(panel)
	local nextIndex = 1
	local maxColumn = 0
	local maxRow = 0

	local function isWithinGrid(column, row)
		if not (column and row) then return false end
		if configuredColumns > 0 and column > configuredColumns then return false end
		if configuredRows > 0 and row > configuredRows then return false end
		return true
	end

	local function claimNextFreeCell()
		while true do
			local column = ((nextIndex - 1) % columns) + 1
			local row = math.floor((nextIndex - 1) / columns) + 1
			if configuredRows > 0 and row > configuredRows then return nil end
			nextIndex = nextIndex + 1
			local key = getFixedCellKey(column, row)
			if isWithinGrid(column, row) and not used[key] then return column, row end
		end
	end

	local function claimNextFreeGroupCell(groupState)
		local group = groupState and groupState.group or nil
		if not group then return nil end
		for groupRow = group.row, group.row + group.rows - 1 do
			for groupColumn = group.column, group.column + group.columns - 1 do
				local key = getFixedCellKey(groupColumn, groupRow)
				if isWithinGrid(groupColumn, groupRow) and not groupState.used[key] then return groupColumn, groupRow end
			end
		end
		return nil
	end

	for i = 1, #fixedGroups do
		local group = fixedGroups[i]
		if group then
			local right = group.column + group.columns - 1
			local bottom = group.row + group.rows - 1
			fixedGroupById[group.id] = group
			fixedGroupIndexById[group.id] = i
			groupEntryIds[group.id] = {}
			entryAtStaticGroupCell[group.id] = {}
			if right > columns then columns = right end
			if right > maxColumn then maxColumn = right end
			if bottom > maxRow then maxRow = bottom end
			groupStates[group.id] = {
				group = group,
				used = {},
			}
			for groupRow = group.row, bottom do
				for groupColumn = group.column, right do
					local key = getFixedCellKey(groupColumn, groupRow)
					fixedGroupAtCell[key] = group
					used[key] = true
				end
			end
		end
	end

	for _, entryId in ipairs(panel.order) do
		local entry = panel.entries[entryId]
		if entry then
			local groupId = Helper.NormalizeFixedGroupId(entry.fixedGroupId)
			local group = groupId and fixedGroupById[groupId] or nil
			if group then
				entry.fixedGroupId = group.id
				Helper.SyncEntryFixedGroupIconState(layout, entry, group)
				groupEntryIds[group.id][#groupEntryIds[group.id] + 1] = entryId
				if Helper.FixedGroupUsesStaticSlots(group) then
					local groupState = groupStates[group.id]
					local column = Helper.NormalizeSlotCoordinate(entry.slotColumn)
					local row = Helper.NormalizeSlotCoordinate(entry.slotRow)
					local key = (column and row) and getFixedCellKey(column, row) or nil
					local withinGroup = key ~= nil
						and column >= group.column
						and column <= (group.column + group.columns - 1)
						and row >= group.row
						and row <= (group.row + group.rows - 1)
						and isWithinGrid(column, row)
						and not groupState.used[key]
					if not withinGroup then
						column = nil
						row = nil
						key = nil
					end
					if not (column and row) then
						column, row = claimNextFreeGroupCell(groupState)
						key = (column and row) and getFixedCellKey(column, row) or nil
					end
					if key then
						groupState.used[key] = true
						entry.slotColumn = column
						entry.slotRow = row
						entry.slotIndex = nil
						entryAtStaticGroupCell[group.id][key] = entryId
						placedEntries[#placedEntries + 1] = {
							entryId = entryId,
							column = column,
							row = row,
						}
					else
						entry.slotColumn = nil
						entry.slotRow = nil
						entry.slotIndex = nil
					end
				else
					entry.slotIndex = nil
					local dynamicEntries = dynamicGroupEntries[group.id]
					if not dynamicEntries then
						dynamicEntries = {}
						dynamicGroupEntries[group.id] = dynamicEntries
					end
					dynamicEntries[#dynamicEntries + 1] = entryId
				end
			else
				entry.fixedGroupId = nil
				Helper.SyncEntryFixedGroupIconState(layout, entry, nil)
				local column = Helper.NormalizeSlotCoordinate(entry.slotColumn)
				local row = Helper.NormalizeSlotCoordinate(entry.slotRow)
				local key = (column and row) and getFixedCellKey(column, row) or nil
				if key and (used[key] or not isWithinGrid(column, row)) then
					column = nil
					row = nil
					key = nil
				end
				if not (column and row) then
					local slot = Helper.NormalizeSlotIndex(entry.slotIndex)
					if slot then
						local derivedColumn = ((slot - 1) % columns) + 1
						local derivedRow = math.floor((slot - 1) / columns) + 1
						local derivedKey = getFixedCellKey(derivedColumn, derivedRow)
						if isWithinGrid(derivedColumn, derivedRow) and not used[derivedKey] then
							column = derivedColumn
							row = derivedRow
							key = derivedKey
						end
					end
				end
				if not (column and row) then
					column, row = claimNextFreeCell()
					key = (column and row) and getFixedCellKey(column, row) or nil
				end
				if key then
					used[key] = true
					entry.slotColumn = column
					entry.slotRow = row
					entry.slotIndex = ((row - 1) * columns) + column
					entryAtUngroupedCell[key] = entryId
					placedEntries[#placedEntries + 1] = {
						entryId = entryId,
						column = column,
						row = row,
					}
					if entry.slotColumn > maxColumn then maxColumn = entry.slotColumn end
					if entry.slotRow > maxRow then maxRow = entry.slotRow end
					if entry.slotIndex >= nextIndex then nextIndex = entry.slotIndex + 1 end
				else
					entry.slotColumn = nil
					entry.slotRow = nil
					entry.slotIndex = nil
				end
			end
		end
	end

	local boundsColumns = configuredColumns > 0 and configuredColumns or maxColumn
	local boundsRows = configuredRows > 0 and configuredRows or maxRow
	local slotCount = 0
	local slotEntryIds = {}
	if not (boundsColumns <= 0 and boundsRows <= 0) then
		if boundsColumns <= 0 then boundsColumns = 1 end
		if boundsRows <= 0 then boundsRows = 1 end
		slotCount = boundsColumns * boundsRows
		for i = 1, #fixedGroups do
			local group = fixedGroups[i]
			if group and not Helper.FixedGroupUsesStaticSlots(group) then
				local capacity = Helper.GetFixedGroupCapacity(group)
				local targetIndices = group._eqolDynamicTargetIndices or {}
				for groupIndex = 1, capacity do
					local column = group.column + ((groupIndex - 1) % group.columns)
					local row = group.row + math.floor((groupIndex - 1) / group.columns)
					if column <= boundsColumns and row <= boundsRows then
						targetIndices[groupIndex] = ((row - 1) * boundsColumns) + column
					else
						targetIndices[groupIndex] = nil
					end
				end
				for groupIndex = capacity + 1, #targetIndices do
					targetIndices[groupIndex] = nil
				end
				group._eqolDynamicTargetIndices = targetIndices
			elseif group then
				group._eqolDynamicTargetIndices = nil
			end
		end
		for i = 1, #placedEntries do
			local placed = placedEntries[i]
			local column = placed.column
			local row = placed.row
			if column and row and column <= boundsColumns and row <= boundsRows then slotEntryIds[((row - 1) * boundsColumns) + column] = placed.entryId end
		end
		for i = 1, #fixedGroups do
			local group = fixedGroups[i]
			local list = group and not Helper.FixedGroupUsesStaticSlots(group) and dynamicGroupEntries[group.id] or nil
			if list then
				local targetIndices = group._eqolDynamicTargetIndices
				local limit = math.min(targetIndices and #targetIndices or 0, #list)
				for groupIndex = 1, limit do
					local targetIndex = targetIndices[groupIndex]
					if targetIndex then slotEntryIds[targetIndex] = list[groupIndex] end
				end
			end
		end
	end

	cache = {
		layoutRef = layout,
		groupsRef = layout.fixedGroups,
		entriesRef = panel.entries,
		orderRef = panel.order,
		orderCount = #panel.order,
		groupCount = #fixedGroups,
		fixedGridColumns = layout.fixedGridColumns,
		fixedGridRows = layout.fixedGridRows,
		wrapCount = layout.wrapCount,
		groups = fixedGroups,
		groupById = fixedGroupById,
		groupIndexById = fixedGroupIndexById,
		groupAtCell = fixedGroupAtCell,
		groupEntryIds = groupEntryIds,
		dynamicGroupEntries = dynamicGroupEntries,
		entryAtUngroupedCell = entryAtUngroupedCell,
		entryAtStaticGroupCell = entryAtStaticGroupCell,
		placedEntries = placedEntries,
		maxColumn = maxColumn,
		maxRow = maxRow,
		boundsColumns = boundsColumns,
		boundsRows = boundsRows,
		slotCount = slotCount,
		slotEntryIds = slotEntryIds,
	}
	panel._eqolFixedLayoutCache = cache
	return cache
end

function Helper.EnsureFixedSlotAssignments(panel)
	local cache = Helper.GetFixedLayoutCache(panel)
	if not cache then return 0, 0 end
	return cache.maxColumn or 0, cache.maxRow or 0
end

function Helper.GetAssignedFixedSlotCount(panel)
	if type(panel) ~= "table" then return 0 end
	local cache = Helper.GetFixedLayoutCache(panel)
	if not cache then return 0 end
	local maxColumn = cache.maxColumn or 0
	local maxRow = cache.maxRow or 0
	local columns = Helper.NormalizeFixedGridSize(panel.layout and panel.layout.fixedGridColumns, 0)
	if columns <= 0 then columns = math.max(maxColumn, 1) end
	if maxRow <= 0 then return 0 end
	return maxRow * columns
end

function Helper.GetFixedGridBounds(panel, includePreviewPadding)
	if type(panel) ~= "table" then return 0, 0 end
	local cache = Helper.GetFixedLayoutCache(panel)
	local columns = cache and cache.boundsColumns or 0
	local rows = cache and cache.boundsRows or 0
	if columns <= 0 and rows <= 0 then return 0, 0 end
	if columns <= 0 then columns = 1 end
	if rows <= 0 then rows = 1 end
	if includePreviewPadding then
		local paddedColumns = columns + 1
		local paddedRows = rows + 1
		if paddedColumns * paddedRows <= (Helper.MAX_PREVIEW_COUNT or 200) then
			columns = paddedColumns
			rows = paddedRows
		elseif columns * paddedRows <= (Helper.MAX_PREVIEW_COUNT or 200) then
			rows = paddedRows
		elseif paddedColumns * rows <= (Helper.MAX_PREVIEW_COUNT or 200) then
			columns = paddedColumns
		end
	end
	return columns, rows
end

function Helper.GetFixedSlotCount(panel, includeDefaultPreview)
	if type(panel) ~= "table" then
		if includeDefaultPreview then return Helper.DEFAULT_PREVIEW_COUNT end
		return 0
	end
	local columns, rows = Helper.GetFixedGridBounds(panel, false)
	local count = columns * rows
	if count <= 0 and includeDefaultPreview then return Helper.DEFAULT_PREVIEW_COUNT end
	return count
end

function Helper.BuildFixedSlotEntryIds(panel, filterFn, includePreviewPadding)
	if type(panel) ~= "table" or type(panel.entries) ~= "table" or type(panel.order) ~= "table" then return nil, 0, 0, 0 end
	local cache = Helper.GetFixedLayoutCache(panel)
	local columns, rows = Helper.GetFixedGridBounds(panel, includePreviewPadding == true)
	local count = columns * rows
	local slotEntryIds = {}
	if count <= 0 then return slotEntryIds, 0, columns, rows end
	if type(filterFn) ~= "function" and includePreviewPadding ~= true and cache and cache.boundsColumns == columns and cache.boundsRows == rows then return cache.slotEntryIds, cache.slotCount, columns, rows end
	local groups = cache and cache.groups or Helper.NormalizeFixedGroups(panel.layout)
	local dynamicGroupEntries = {}
	if type(filterFn) ~= "function" and cache and cache.dynamicGroupEntries then
		dynamicGroupEntries = cache.dynamicGroupEntries
		for i = 1, #(cache.placedEntries or {}) do
			local placed = cache.placedEntries[i]
			local column = placed and placed.column or nil
			local row = placed and placed.row or nil
			if column and row and column <= columns and row <= rows then slotEntryIds[((row - 1) * columns) + column] = placed.entryId end
		end
	else
	for _, entryId in ipairs(panel.order) do
		local entry = panel.entries[entryId]
		if entry and (type(filterFn) ~= "function" or filterFn(entry, entryId) ~= false) then
			local groupId = Helper.NormalizeFixedGroupId(entry.fixedGroupId)
			local group = groupId and Helper.GetFixedGroupById(panel, groupId) or nil
			if group then
				if Helper.FixedGroupUsesStaticSlots(group) then
					local column = Helper.NormalizeSlotCoordinate(entry.slotColumn)
					local row = Helper.NormalizeSlotCoordinate(entry.slotRow)
					if
						column
						and row
						and column <= columns
						and row <= rows
						and column >= group.column
						and column <= (group.column + group.columns - 1)
						and row >= group.row
						and row <= (group.row + group.rows - 1)
					then
						slotEntryIds[((row - 1) * columns) + column] = entryId
					end
				else
					local list = dynamicGroupEntries[group.id]
					if not list then
						list = {}
						dynamicGroupEntries[group.id] = list
					end
					list[#list + 1] = entryId
				end
			else
				local column = Helper.NormalizeSlotCoordinate(entry.slotColumn)
				local row = Helper.NormalizeSlotCoordinate(entry.slotRow)
				if column and row and column <= columns and row <= rows then slotEntryIds[((row - 1) * columns) + column] = entryId end
			end
		end
	end
	end
	for i = 1, #groups do
		local group = groups[i]
		local list = group and not Helper.FixedGroupUsesStaticSlots(group) and dynamicGroupEntries[group.id] or nil
		if list then
			local usePreparedTargets = cache and cache.boundsColumns == columns and cache.boundsRows == rows and group._eqolDynamicTargetIndices
			if usePreparedTargets then
				local targetIndices = group._eqolDynamicTargetIndices
				local limit = math.min(targetIndices and #targetIndices or 0, #list)
				for groupIndex = 1, limit do
					local targetIndex = targetIndices[groupIndex]
					if targetIndex and targetIndex <= count then slotEntryIds[targetIndex] = list[groupIndex] end
				end
			else
				local capacity = Helper.GetFixedGroupCapacity(group)
				local limit = math.min(capacity, #list)
				for groupIndex = 1, limit do
					local column = group.column + ((groupIndex - 1) % group.columns)
					local row = group.row + math.floor((groupIndex - 1) / group.columns)
					if column <= columns and row <= rows then slotEntryIds[((row - 1) * columns) + column] = list[groupIndex] end
				end
			end
		end
	end
	return slotEntryIds, count, columns, rows
end

function Helper.NormalizeStrata(strata, fallback)
	if type(strata) == "string" then
		local upper = string.upper(strata)
		if Helper.VALID_STRATA[upper] then return upper end
	end
	if type(fallback) == "string" then
		local upper = string.upper(fallback)
		if Helper.VALID_STRATA[upper] then return upper end
	end
	return "MEDIUM"
end

function Helper.NormalizeColor(value, fallback)
	local ref = fallback or { 1, 1, 1, 1 }
	if type(value) ~= "table" then return { ref[1], ref[2], ref[3], ref[4] } end
	local r = value.r or value[1] or ref[1] or 1
	local g = value.g or value[2] or ref[2] or 1
	local b = value.b or value[3] or ref[3] or 1
	local a = value.a
	if a == nil then a = value[4] end
	if a == nil then a = ref[4] end
	if a == nil then a = 1 end
	if r < 0 then
		r = 0
	elseif r > 1 then
		r = 1
	end
	if g < 0 then
		g = 0
	elseif g > 1 then
		g = 1
	end
	if b < 0 then
		b = 0
	elseif b > 1 then
		b = 1
	end
	if a < 0 then
		a = 0
	elseif a > 1 then
		a = 1
	end
	return { r, g, b, a }
end

function Helper.ResolveColor(value, fallback)
	local ref = fallback or { 1, 1, 1, 1 }
	local r, g, b, a
	if type(value) == "table" then
		r = value.r or value[1] or ref[1] or 1
		g = value.g or value[2] or ref[2] or 1
		b = value.b or value[3] or ref[3] or 1
		a = value.a
		if a == nil then a = value[4] end
	else
		r = ref[1] or 1
		g = ref[2] or 1
		b = ref[3] or 1
		a = ref[4]
	end
	if a == nil then a = ref[4] end
	if a == nil then a = 1 end
	if r < 0 then
		r = 0
	elseif r > 1 then
		r = 1
	end
	if g < 0 then
		g = 0
	elseif g > 1 then
		g = 1
	end
	if b < 0 then
		b = 0
	elseif b > 1 then
		b = 1
	end
	if a < 0 then
		a = 0
	elseif a > 1 then
		a = 1
	end
	return r, g, b, a
end

function Helper.NormalizeAnchor(anchor, fallback)
	if anchor and Helper.VALID_ANCHORS[anchor] then return anchor end
	if fallback and Helper.VALID_ANCHORS[fallback] then return fallback end
	return "CENTER"
end

function Helper.NormalizeGrowthPoint(value, fallback)
	local anchor = Helper.NormalizeAnchor(value, fallback)
	if anchor == "TOP" or anchor == "CENTER" or anchor == "BOTTOM" then return "TOP" end
	if anchor == "TOPRIGHT" or anchor == "RIGHT" or anchor == "BOTTOMRIGHT" then return "TOPRIGHT" end
	return "TOPLEFT"
end

function Helper.NormalizeRelativeFrameName(value)
	if type(value) ~= "string" or value == "" then return "UIParent" end
	if Helper.GENERIC_ANCHORS[value] then return value end
	local mapped = Helper.GENERIC_ANCHOR_BY_FRAME[value]
	if mapped then return mapped end
	return value
end

function Helper.NormalizeFontStyle(style, fallback)
	if style == nil then style = fallback end
	if style == nil then return nil end
	if style == "" or style == "NONE" then return "" end
	if style == "MONOCHROMEOUTLINE" or style == "OUTLINE,MONOCHROME" or style == "MONOCHROME,OUTLINE" then return "OUTLINE,MONOCHROME" end
	return style
end

function Helper.NormalizeFontStyleChoice(style, fallback)
	if style == nil then style = fallback end
	if style == nil or style == "" then return "NONE" end
	if style == "OUTLINE,MONOCHROME" or style == "MONOCHROME,OUTLINE" then return "MONOCHROMEOUTLINE" end
	if Helper.VALID_FONT_STYLE[style] then return style end
	return "NONE"
end

function Helper.NormalizeOpacity(value, fallback)
	local resolvedFallback = fallback
	if resolvedFallback == nil then resolvedFallback = 1 end
	local num = Helper.ClampNumber(value, 0, 1, resolvedFallback)
	if num == nil then return resolvedFallback end
	return num
end

function Helper.ResolveFontPath(value, fallback)
	local useGlobalConfig = false
	if addon.functions and addon.functions.IsGlobalFontConfigValue and addon.functions.IsGlobalFontConfigValue(value) then
		useGlobalConfig = true
		value = nil
	end
	if addon.functions and addon.functions.IsGlobalFontConfigValue and addon.functions.IsGlobalFontConfigValue(fallback) then fallback = nil end
	if type(value) == "string" and value ~= "" then return value end
	if useGlobalConfig and addon.functions and addon.functions.GetGlobalDefaultFontFace then
		local globalFace = addon.functions.GetGlobalDefaultFontFace()
		if type(globalFace) == "string" and globalFace ~= "" then return globalFace end
	end
	if type(fallback) == "string" and fallback ~= "" then return fallback end
	if addon.functions and addon.functions.GetGlobalDefaultFontFace then return addon.functions.GetGlobalDefaultFontFace() end
	return STANDARD_TEXT_FONT
end

function Helper.GetCountFontDefaults(frame)
	if frame then
		local icon = frame.icons and frame.icons[1]
		if icon and icon.count and icon.count.GetFont then return icon.count:GetFont() end
	end
	local fallback = (addon.functions and addon.functions.GetGlobalDefaultFontFace and addon.functions.GetGlobalDefaultFontFace())
		or (addon.variables and addon.variables.defaultFont)
		or (LSM and LSM:Fetch("font", LSM.DefaultMedia.font))
		or STANDARD_TEXT_FONT
	return fallback, 12, "OUTLINE"
end

function Helper.GetChargesFontDefaults(frame)
	if frame then
		local icon = frame.icons and frame.icons[1]
		if icon and icon.charges and icon.charges.GetFont then return icon.charges:GetFont() end
	end
	return Helper.GetCountFontDefaults()
end

function Helper.GetFontOptions(defaultPath)
	local list = {}
	local seen = {}
	local globalFontKey = addon.functions and addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or "__EQOL_GLOBAL_FONT__"
	local globalFontLabel = addon.functions and addon.functions.GetGlobalFontConfigLabel and addon.functions.GetGlobalFontConfigLabel() or "Use global font config"
	local function add(path, label)
		if type(path) ~= "string" or path == "" then return end
		local key = string.lower(path)
		if seen[key] then return end
		seen[key] = true
		list[#list + 1] = { value = path, label = label }
	end
	local names = addon.functions and addon.functions.GetLSMMediaNames and addon.functions.GetLSMMediaNames("font") or {}
	local hash = addon.functions and addon.functions.GetLSMMediaHash and addon.functions.GetLSMMediaHash("font") or {}
	for i = 1, #names do
		local name = names[i]
		local path = hash[name]
		add(path, tostring(name))
	end
	if defaultPath then add(defaultPath, DEFAULT) end
	table.insert(list, 1, { value = globalFontKey, label = globalFontLabel })
	return list
end

function Helper.Utf8Iter(str) return (str or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") end

function Helper.Utf8Len(str)
	local len = 0
	for _ in Helper.Utf8Iter(str) do
		len = len + 1
	end
	return len
end

function Helper.Utf8Sub(str, i, j)
	str = str or ""
	if str == "" then return "" end
	i = i or 1
	j = j or -1
	if i < 1 then i = 1 end
	local len = Helper.Utf8Len(str)
	if j < 0 then j = len + j + 1 end
	if j > len then j = len end
	if i > j then return "" end
	local pos = 1
	local startByte, endByte
	local idx = 0
	for char in Helper.Utf8Iter(str) do
		idx = idx + 1
		if idx == i then startByte = pos end
		if idx == j then
			endByte = pos + #char - 1
			break
		end
		pos = pos + #char
	end
	return str:sub(startByte or 1, endByte or #str)
end

function Helper.EllipsizeFontString(fontString, text, maxWidth)
	if not fontString or maxWidth <= 0 then return text end
	text = text or ""
	fontString:SetText(text)
	if fontString:GetStringWidth() <= maxWidth then return text end
	local ellipsis = "..."
	fontString:SetText(ellipsis)
	if fontString:GetStringWidth() > maxWidth then return ellipsis end
	local length = Helper.Utf8Len(text)
	local low, high = 1, length
	local best = ellipsis
	while low <= high do
		local mid = math.floor((low + high) / 2)
		local candidate = Helper.Utf8Sub(text, 1, mid) .. ellipsis
		fontString:SetText(candidate)
		if fontString:GetStringWidth() <= maxWidth then
			best = candidate
			low = mid + 1
		else
			high = mid - 1
		end
	end
	return best
end

function Helper.SetButtonTextEllipsized(button, text)
	if not button then return end
	local fontString = button.Text or button:GetFontString()
	if not fontString then
		button:SetText(text or "")
		return
	end
	local maxWidth = (button:GetWidth() or 0) - 12
	if maxWidth <= 0 then
		button:SetText(text or "")
		return
	end
	fontString:SetWidth(maxWidth)
	if fontString.SetMaxLines then fontString:SetMaxLines(1) end
	if fontString.SetWordWrap then fontString:SetWordWrap(false) end
	button:SetText(Helper.EllipsizeFontString(fontString, text or "", maxWidth))
end

function Helper.CreateLabel(parent, text, size, style)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetText(text or "")
	label:SetFont((addon.variables and addon.variables.defaultFont) or label:GetFont(), size or 12, style or "OUTLINE")
	label:SetTextColor(1, 0.82, 0, 1)
	return label
end

function Helper.CreateButton(parent, text, width, height)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetText(text or "")
	btn:SetSize(width or 120, height or 22)
	return btn
end

function Helper.CreateEditBox(parent, width, height)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(width or 120, height or 22)
	box:SetAutoFocus(false)
	box:SetFontObject(GameFontHighlightSmall)
	return box
end

function Helper.CreateCheck(parent, text)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb.Text:SetText(text or "")
	cb.Text:SetTextColor(1, 1, 1, 1)
	return cb
end

function Helper.CreateSlider(parent, width, minValue, maxValue, step)
	local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	slider:SetMinMaxValues(minValue or 0, maxValue or 1)
	slider:SetValueStep(step or 1)
	slider:SetObeyStepOnDrag(true)
	slider:SetWidth(width or 180)
	if slider.Low then slider.Low:SetText(tostring(minValue or 0)) end
	if slider.High then slider.High:SetText(tostring(maxValue or 1)) end
	return slider
end

function Helper.CreateRowButton(parent, height)
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	row:SetHeight(height or 28)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints(row)
	row.bg:SetColorTexture(0, 0, 0, 0.2)
	row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
	row.highlight:SetAllPoints(row)
	row.highlight:SetColorTexture(1, 1, 1, 0.06)
	return row
end

local function spellHasCharges(spellId)
	if not spellId then return false end
	if not (C_Spell and C_Spell.GetSpellCharges) then return false end
	local info = C_Spell.GetSpellCharges(spellId)
	if type(info) ~= "table" then return false end
	local issecretvalue = _G.issecretvalue
	if issecretvalue then
		if issecretvalue(info) then return false end
		if info.currentCharges ~= nil and issecretvalue(info.currentCharges) then return false end
		if info.maxCharges ~= nil and issecretvalue(info.maxCharges) then return false end
	end
	local maxCharges = info.maxCharges
	if type(maxCharges) ~= "number" then return false end
	return maxCharges > 1
end

function Helper.CopyTableShallow(source)
	local result = {}
	if source then
		for k, v in pairs(source) do
			result[k] = v
		end
	end
	return result
end

function Helper.CopyTableDeep(source, seen)
	if type(source) ~= "table" then return source end
	if addon.functions and addon.functions.copyTable then return addon.functions.copyTable(source) end
	if CopyTable then return CopyTable(source) end
	seen = seen or {}
	if seen[source] then return seen[source] end
	local result = {}
	seen[source] = result
	for key, value in pairs(source) do
		local copiedKey = type(key) == "table" and Helper.CopyTableDeep(key, seen) or key
		result[copiedKey] = Helper.CopyTableDeep(value, seen)
	end
	return result
end

function Helper.NormalizeBool(value, fallback)
	if value == nil then return fallback end
	return value and true or false
end

function Helper.GetNextNumericId(map, start)
	local maxId = tonumber(start) or 0
	if map then
		for key in pairs(map) do
			local num = tonumber(key)
			if num and num > maxId then maxId = num end
		end
	end
	return maxId + 1
end

function Helper.CreateRoot()
	return {
		version = 1,
		panels = {},
		order = {},
		selectedPanel = nil,
		defaults = {
			layout = Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS),
			entry = Helper.CopyTableShallow(Helper.ENTRY_DEFAULTS),
		},
	}
end

function Helper.NormalizeRoot(root)
	if type(root) ~= "table" then return Helper.CreateRoot() end
	if type(root.version) ~= "number" then root.version = 1 end
	if type(root.panels) ~= "table" then root.panels = {} end
	if type(root.order) ~= "table" then root.order = {} end
	if type(root.defaults) ~= "table" then root.defaults = {} end
	if type(root.defaults.layout) ~= "table" then
		root.defaults.layout = Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	else
		for key, value in pairs(Helper.PANEL_LAYOUT_DEFAULTS) do
			if root.defaults.layout[key] == nil then root.defaults.layout[key] = value end
		end
	end
	if type(root.defaults.entry) ~= "table" then
		root.defaults.entry = Helper.CopyTableShallow(Helper.ENTRY_DEFAULTS)
	else
		for key, value in pairs(Helper.ENTRY_DEFAULTS) do
			if root.defaults.entry[key] == nil then root.defaults.entry[key] = value end
		end
	end
	root.defaults.entry.alwaysShow = Helper.ENTRY_DEFAULTS.alwaysShow
	root.defaults.entry.showCooldown = Helper.ENTRY_DEFAULTS.showCooldown
	root.defaults.entry.showCooldownText = Helper.ENTRY_DEFAULTS.showCooldownText
	root.defaults.entry.showCharges = Helper.ENTRY_DEFAULTS.showCharges
	root.defaults.entry.showStacks = Helper.ENTRY_DEFAULTS.showStacks
	root.defaults.entry.glowReady = Helper.ENTRY_DEFAULTS.glowReady
	root.defaults.entry.readyGlowCheckPower = Helper.ENTRY_DEFAULTS.readyGlowCheckPower
	root.defaults.entry.pandemicGlow = Helper.ENTRY_DEFAULTS.pandemicGlow
	root.defaults.entry.checkPower = Helper.ENTRY_DEFAULTS.checkPower
	root.defaults.entry.checkPowerUseGlobal = Helper.ENTRY_DEFAULTS.checkPowerUseGlobal
	root.defaults.entry.hideWhenNoResource = Helper.ENTRY_DEFAULTS.hideWhenNoResource
	root.defaults.entry.hideWhenNoResourceUseGlobal = Helper.ENTRY_DEFAULTS.hideWhenNoResourceUseGlobal
	root.defaults.entry.procGlowEnabled = Helper.ENTRY_DEFAULTS.procGlowEnabled
	root.defaults.entry.procGlowUseGlobal = Helper.ENTRY_DEFAULTS.procGlowUseGlobal
	root.defaults.entry.glowDuration = Helper.ENTRY_DEFAULTS.glowDuration
	root.defaults.entry.soundReady = Helper.ENTRY_DEFAULTS.soundReady
	root.defaults.entry.soundReadyFile = Helper.ENTRY_DEFAULTS.soundReadyFile
	return root
end

function Helper.NormalizePanel(panel, defaults)
	if type(panel) ~= "table" then return end
	defaults = defaults or {}
	local layoutDefaults = defaults.layout or Helper.PANEL_LAYOUT_DEFAULTS
	if type(panel.layout) ~= "table" then panel.layout = {} end
	local hadKeybindsEnabled = panel.layout.keybindsEnabled
	local hadChargesCooldown = panel.layout.showChargesCooldown
	for key, value in pairs(layoutDefaults) do
		if panel.layout[key] == nil then panel.layout[key] = value end
	end
	panel.layout.fixedSlotCount = Helper.NormalizeFixedSlotCount(panel.layout.fixedSlotCount, layoutDefaults.fixedSlotCount or Helper.PANEL_LAYOUT_DEFAULTS.fixedSlotCount or 0)
	panel.layout.fixedGridColumns = Helper.NormalizeFixedGridSize(panel.layout.fixedGridColumns, layoutDefaults.fixedGridColumns or Helper.PANEL_LAYOUT_DEFAULTS.fixedGridColumns or 0)
	panel.layout.fixedGridRows = Helper.NormalizeFixedGridSize(panel.layout.fixedGridRows, layoutDefaults.fixedGridRows or Helper.PANEL_LAYOUT_DEFAULTS.fixedGridRows or 0)
	Helper.NormalizeFixedGroups(panel.layout)
	panel.layout.spacing = Helper.ClampInt(panel.layout.spacing, 0, Helper.SPACING_RANGE or 200, layoutDefaults.spacing or Helper.PANEL_LAYOUT_DEFAULTS.spacing or 2)
	panel.layout.radialArcDegrees = Helper.ClampInt(
		panel.layout.radialArcDegrees,
		Helper.RADIAL_ARC_DEGREES_MIN or 15,
		Helper.RADIAL_ARC_DEGREES_MAX or 360,
		layoutDefaults.radialArcDegrees or Helper.PANEL_LAYOUT_DEFAULTS.radialArcDegrees or 360
	)
	panel.layout.procGlowEnabled = panel.layout.procGlowEnabled ~= false
	panel.layout.hideGlowOutOfCombat = panel.layout.hideGlowOutOfCombat == true
	if panel.layout.procGlowStyle ~= nil then panel.layout.procGlowStyle = Helper.NormalizeGlowStyle(panel.layout.procGlowStyle, nil) end
	if panel.layout.procGlowInset ~= nil then panel.layout.procGlowInset = Helper.NormalizeGlowInset(panel.layout.procGlowInset, nil) end
	panel.layout.readyGlowStyle = Helper.NormalizeGlowStyle(panel.layout.readyGlowStyle, layoutDefaults.readyGlowStyle or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle)
	panel.layout.pandemicGlowStyle =
		Helper.NormalizeGlowStyle(panel.layout.pandemicGlowStyle, layoutDefaults.pandemicGlowStyle or panel.layout.readyGlowStyle or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle)
	panel.layout.readyGlowColor = Helper.NormalizeColor(panel.layout.readyGlowColor, layoutDefaults.readyGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor)
	panel.layout.readyGlowInset = Helper.NormalizeGlowInset(panel.layout.readyGlowInset, layoutDefaults.readyGlowInset or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0)
	panel.layout.pandemicGlowInset =
		Helper.NormalizeGlowInset(panel.layout.pandemicGlowInset, layoutDefaults.pandemicGlowInset or panel.layout.readyGlowInset or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0)
	panel.layout.pandemicGlowColor = Helper.NormalizeColor(
		panel.layout.pandemicGlowColor,
		layoutDefaults.pandemicGlowColor or panel.layout.readyGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.pandemicGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor
	)
	panel.layout.readyGlowDuration = 0
	panel.layout.readyGlowCheckPower = panel.layout.readyGlowCheckPower == true
	panel.layout.noDesaturation = panel.layout.noDesaturation == true
	panel.layout.hideWhenNoResource = panel.layout.hideWhenNoResource == true
	panel.layout.cdmAuraAlwaysShowMode =
		normalizeCDMAuraAlwaysShowMode(panel.layout.cdmAuraAlwaysShowMode, layoutDefaults.cdmAuraAlwaysShowMode or Helper.PANEL_LAYOUT_DEFAULTS.cdmAuraAlwaysShowMode or "HIDE")
	panel.layout.stackColor = Helper.NormalizeColor(panel.layout.stackColor, layoutDefaults.stackColor or Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 })
	panel.layout.chargesColor = Helper.NormalizeColor(panel.layout.chargesColor, layoutDefaults.chargesColor or Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 })
	panel.layout.chargesHideWhenZero = panel.layout.chargesHideWhenZero == true
	panel.layout.cooldownTextColor = Helper.NormalizeColor(panel.layout.cooldownTextColor, layoutDefaults.cooldownTextColor or Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor)
	if panel.layout.cooldownTextFont ~= nil and type(panel.layout.cooldownTextFont) ~= "string" then panel.layout.cooldownTextFont = nil end
	if panel.layout.cooldownTextSize ~= nil then panel.layout.cooldownTextSize = Helper.ClampInt(panel.layout.cooldownTextSize, 6, 64, 12) end
	if panel.layout.cooldownTextStyle ~= nil then panel.layout.cooldownTextStyle = Helper.NormalizeFontStyleChoice(panel.layout.cooldownTextStyle, "NONE") end
	if panel.layout.cooldownTextX ~= nil then panel.layout.cooldownTextX = Helper.ClampInt(panel.layout.cooldownTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0) end
	if panel.layout.cooldownTextY ~= nil then panel.layout.cooldownTextY = Helper.ClampInt(panel.layout.cooldownTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0) end
	if type(panel.layout.staticTextFont) ~= "string" then panel.layout.staticTextFont = layoutDefaults.staticTextFont or Helper.PANEL_LAYOUT_DEFAULTS.staticTextFont or "" end
	panel.layout.staticTextSize = Helper.ClampInt(panel.layout.staticTextSize, 6, 64, layoutDefaults.staticTextSize or Helper.PANEL_LAYOUT_DEFAULTS.staticTextSize or 12)
	panel.layout.staticTextStyle = Helper.NormalizeFontStyleChoice(panel.layout.staticTextStyle, layoutDefaults.staticTextStyle or Helper.PANEL_LAYOUT_DEFAULTS.staticTextStyle or "OUTLINE")
	panel.layout.staticTextColor = Helper.NormalizeColor(panel.layout.staticTextColor, layoutDefaults.staticTextColor or Helper.PANEL_LAYOUT_DEFAULTS.staticTextColor or { 1, 1, 1, 1 })
	panel.layout.staticTextAnchor = Helper.NormalizeAnchor(panel.layout.staticTextAnchor, layoutDefaults.staticTextAnchor or Helper.PANEL_LAYOUT_DEFAULTS.staticTextAnchor or "CENTER")
	panel.layout.staticTextX = Helper.ClampInt(panel.layout.staticTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layoutDefaults.staticTextX or Helper.PANEL_LAYOUT_DEFAULTS.staticTextX or 0)
	panel.layout.staticTextY = Helper.ClampInt(panel.layout.staticTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layoutDefaults.staticTextY or Helper.PANEL_LAYOUT_DEFAULTS.staticTextY or 0)
	if type(panel.anchor) ~= "table" then panel.anchor = {} end
	local anchor = panel.anchor
	if anchor.point == nil then anchor.point = panel.point or "CENTER" end
	if anchor.relativePoint == nil then anchor.relativePoint = anchor.point end
	if anchor.x == nil then anchor.x = panel.x or 0 end
	if anchor.y == nil then anchor.y = panel.y or 0 end
	if not anchor.relativeFrame or anchor.relativeFrame == "" then anchor.relativeFrame = "UIParent" end
	if panel.point == nil then panel.point = "CENTER" end
	if panel.x == nil then panel.x = 0 end
	if panel.y == nil then panel.y = 0 end
	panel.point = anchor.point or panel.point
	panel.x = anchor.x or panel.x
	panel.y = anchor.y or panel.y
	if type(panel.entries) ~= "table" then panel.entries = {} end
	if type(panel.order) ~= "table" then panel.order = {} end
	if panel.enabled == nil then panel.enabled = true end
	if type(panel.name) ~= "string" or panel.name == "" then panel.name = "Cooldown Panel" end
	if Helper.IsFixedLayout(panel.layout) then
		local maxColumn, maxRow = Helper.EnsureFixedSlotAssignments(panel)
		if panel.layout.fixedGridColumns <= 0 and maxColumn > 0 then panel.layout.fixedGridColumns = math.max(panel.layout.fixedGridColumns, maxColumn) end
		if panel.layout.fixedGridRows <= 0 and maxRow > 0 then panel.layout.fixedGridRows = math.max(panel.layout.fixedGridRows, maxRow) end
	end
	if hadKeybindsEnabled == nil or hadChargesCooldown == nil then
		for _, entry in pairs(panel.entries) do
			if entry then
				if hadKeybindsEnabled == nil and entry.showKeybinds == true then panel.layout.keybindsEnabled = true end
				if hadChargesCooldown == nil and entry.showChargesCooldown == true then panel.layout.showChargesCooldown = true end
				if (hadKeybindsEnabled ~= nil or panel.layout.keybindsEnabled == true) and (hadChargesCooldown ~= nil or panel.layout.showChargesCooldown == true) then break end
			end
		end
	end
end

function Helper.NormalizeEntry(entry, defaults)
	if type(entry) ~= "table" then return end
	local hadShowCharges = entry.showCharges ~= nil
	local hadShowStacks = entry.showStacks ~= nil
	defaults = defaults or {}
	local entryDefaults = defaults.entry or {}
	for key, value in pairs(entryDefaults) do
		if entry[key] == nil then entry[key] = value end
	end
	for key, value in pairs(Helper.ENTRY_DEFAULTS) do
		if entry[key] == nil then entry[key] = value end
	end
	if entry.alwaysShow == nil then entry.alwaysShow = true end
	if entry.showCooldown == nil then entry.showCooldown = true end
	if entry.type == "ITEM" and entry.showItemCount == nil then entry.showItemCount = true end
	if entry.type == "SPELL" then
		if not hadShowCharges then entry.showCharges = spellHasCharges(entry.spellID) end
		if not hadShowStacks then entry.showStacks = false end
	elseif entry.type == "CDM_AURA" then
		local cdmAuras = CooldownPanels and CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.NormalizeEntry then cdmAuras:NormalizeEntry(entry, defaults) end
	elseif entry.type == "MACRO" then
		entry.macroID = tonumber(entry.macroID)
		if type(entry.macroName) == "string" and strtrim then entry.macroName = strtrim(entry.macroName) end
		if type(entry.macroName) ~= "string" or entry.macroName == "" then entry.macroName = nil end
	elseif entry.type == "STANCE" then
		if CooldownPanels and CooldownPanels.NormalizeStanceEntry then CooldownPanels:NormalizeStanceEntry(entry) end
		entry.showWhenMissing = entry.showWhenMissing == true
	end
	entry.glowDuration = 0
	local hasLegacySharedProcGlowVisual = entry.type == "SPELL" and (entry.glowStyle ~= nil or entry.glowInset ~= nil)
	if hasLegacySharedProcGlowVisual then
		if entry.procGlowStyle == nil then entry.procGlowStyle = entry.glowStyle end
		if entry.procGlowInset == nil then entry.procGlowInset = entry.glowInset end
	end
	if entry.glowStyle ~= nil then entry.glowStyle = Helper.NormalizeGlowStyle(entry.glowStyle, nil) end
	if entry.pandemicGlowStyle ~= nil then entry.pandemicGlowStyle = Helper.NormalizeGlowStyle(entry.pandemicGlowStyle, nil) end
	if entry.procGlowStyle ~= nil then entry.procGlowStyle = Helper.NormalizeGlowStyle(entry.procGlowStyle, nil) end
	if entry.glowInset ~= nil then entry.glowInset = Helper.NormalizeGlowInset(entry.glowInset, nil) end
	if entry.pandemicGlowInset ~= nil then entry.pandemicGlowInset = Helper.NormalizeGlowInset(entry.pandemicGlowInset, nil) end
	if entry.procGlowInset ~= nil then entry.procGlowInset = Helper.NormalizeGlowInset(entry.procGlowInset, nil) end
	if type(entry.pandemicGlow) ~= "boolean" then entry.pandemicGlow = Helper.ENTRY_DEFAULTS.pandemicGlow end
	if type(entry.hideIcon) ~= "boolean" then entry.hideIcon = Helper.ENTRY_DEFAULTS.hideIcon end
	if type(entry.iconSizeUseGlobal) ~= "boolean" then entry.iconSizeUseGlobal = true end
	entry.iconSize = Helper.ClampInt(entry.iconSize, 12, 128, Helper.ENTRY_DEFAULTS.iconSize or Helper.PANEL_LAYOUT_DEFAULTS.iconSize or 36)
	entry.iconOffsetX = Helper.ClampInt(entry.iconOffsetX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.iconOffsetX or 0)
	entry.iconOffsetY = Helper.ClampInt(entry.iconOffsetY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.iconOffsetY or 0)
	if type(entry.showIconTextureUseGlobal) ~= "boolean" then entry.showIconTextureUseGlobal = true end
	if type(entry.stackStyleUseGlobal) ~= "boolean" then entry.stackStyleUseGlobal = true end
	entry.stackAnchor = Helper.NormalizeAnchor(entry.stackAnchor, Helper.ENTRY_DEFAULTS.stackAnchor or Helper.PANEL_LAYOUT_DEFAULTS.stackAnchor or "BOTTOMRIGHT")
	entry.stackX = Helper.ClampInt(entry.stackX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.stackX or 0)
	entry.stackY = Helper.ClampInt(entry.stackY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.stackY or 0)
	if type(entry.stackFont) ~= "string" then entry.stackFont = Helper.ENTRY_DEFAULTS.stackFont or "" end
	entry.stackFontSize = Helper.ClampInt(entry.stackFontSize, 6, 64, Helper.ENTRY_DEFAULTS.stackFontSize or Helper.PANEL_LAYOUT_DEFAULTS.stackFontSize or 12)
	entry.stackFontStyle = Helper.NormalizeFontStyleChoice(entry.stackFontStyle, Helper.ENTRY_DEFAULTS.stackFontStyle or Helper.PANEL_LAYOUT_DEFAULTS.stackFontStyle or "OUTLINE")
	entry.stackColor = Helper.NormalizeColor(entry.stackColor, Helper.ENTRY_DEFAULTS.stackColor or Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 })
	if type(entry.chargesStyleUseGlobal) ~= "boolean" then entry.chargesStyleUseGlobal = true end
	entry.chargesAnchor = Helper.NormalizeAnchor(entry.chargesAnchor, Helper.ENTRY_DEFAULTS.chargesAnchor or Helper.PANEL_LAYOUT_DEFAULTS.chargesAnchor or "TOP")
	entry.chargesX = Helper.ClampInt(entry.chargesX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.chargesX or 0)
	entry.chargesY = Helper.ClampInt(entry.chargesY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.chargesY or 0)
	if type(entry.chargesFont) ~= "string" then entry.chargesFont = Helper.ENTRY_DEFAULTS.chargesFont or "" end
	entry.chargesFontSize = Helper.ClampInt(entry.chargesFontSize, 6, 64, Helper.ENTRY_DEFAULTS.chargesFontSize or Helper.PANEL_LAYOUT_DEFAULTS.chargesFontSize or 12)
	entry.chargesFontStyle = Helper.NormalizeFontStyleChoice(entry.chargesFontStyle, Helper.ENTRY_DEFAULTS.chargesFontStyle or Helper.PANEL_LAYOUT_DEFAULTS.chargesFontStyle or "OUTLINE")
	entry.chargesColor = Helper.NormalizeColor(entry.chargesColor, Helper.ENTRY_DEFAULTS.chargesColor or Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 })
	if type(entry.cooldownVisualsUseGlobal) ~= "boolean" then entry.cooldownVisualsUseGlobal = true end
	if type(entry.showChargesCooldown) ~= "boolean" then entry.showChargesCooldown = Helper.ENTRY_DEFAULTS.showChargesCooldown end
	if type(entry.cooldownDrawEdge) ~= "boolean" then entry.cooldownDrawEdge = Helper.ENTRY_DEFAULTS.cooldownDrawEdge end
	if type(entry.cooldownDrawBling) ~= "boolean" then entry.cooldownDrawBling = Helper.ENTRY_DEFAULTS.cooldownDrawBling end
	if type(entry.cooldownDrawSwipe) ~= "boolean" then entry.cooldownDrawSwipe = Helper.ENTRY_DEFAULTS.cooldownDrawSwipe end
	if type(entry.cooldownGcdDrawEdge) ~= "boolean" then entry.cooldownGcdDrawEdge = Helper.ENTRY_DEFAULTS.cooldownGcdDrawEdge end
	if type(entry.cooldownGcdDrawBling) ~= "boolean" then entry.cooldownGcdDrawBling = Helper.ENTRY_DEFAULTS.cooldownGcdDrawBling end
	if type(entry.cooldownGcdDrawSwipe) ~= "boolean" then entry.cooldownGcdDrawSwipe = Helper.ENTRY_DEFAULTS.cooldownGcdDrawSwipe end
	if type(entry.cooldownTextUseGlobal) ~= "boolean" then entry.cooldownTextUseGlobal = true end
	if type(entry.noDesaturationUseGlobal) ~= "boolean" then entry.noDesaturationUseGlobal = true end
	if type(entry.noDesaturation) ~= "boolean" then entry.noDesaturation = Helper.ENTRY_DEFAULTS.noDesaturation end
	if type(entry.checkPowerUseGlobal) ~= "boolean" then entry.checkPowerUseGlobal = Helper.ENTRY_DEFAULTS.checkPowerUseGlobal end
	if type(entry.checkPower) ~= "boolean" then entry.checkPower = Helper.ENTRY_DEFAULTS.checkPower end
	if type(entry.hideWhenNoResourceUseGlobal) ~= "boolean" then entry.hideWhenNoResourceUseGlobal = Helper.ENTRY_DEFAULTS.hideWhenNoResourceUseGlobal end
	if type(entry.hideWhenNoResource) ~= "boolean" then entry.hideWhenNoResource = Helper.ENTRY_DEFAULTS.hideWhenNoResource end
	if type(entry.readyGlowCheckPower) ~= "boolean" then entry.readyGlowCheckPower = Helper.ENTRY_DEFAULTS.readyGlowCheckPower end
	if type(entry.procGlowEnabled) ~= "boolean" then entry.procGlowEnabled = Helper.ENTRY_DEFAULTS.procGlowEnabled end
	if type(entry.procGlowUseGlobal) ~= "boolean" then
		entry.procGlowUseGlobal = (hasLegacySharedProcGlowVisual or entry.procGlowStyle ~= nil or entry.procGlowInset ~= nil or entry.procGlowEnabled ~= Helper.ENTRY_DEFAULTS.procGlowEnabled)
				and false
			or Helper.ENTRY_DEFAULTS.procGlowUseGlobal
	end
	if type(entry.glowUseGlobal) ~= "boolean" then
		entry.glowUseGlobal = entry.glowDuration == (Helper.ENTRY_DEFAULTS.glowDuration or 0)
			and entry.glowColor == nil
			and entry.glowStyle == nil
			and entry.glowInset == nil
			and entry.pandemicGlowColor == nil
			and entry.pandemicGlowStyle == nil
			and entry.pandemicGlowInset == nil
	end
	if type(entry.soundReady) ~= "boolean" then entry.soundReady = Helper.ENTRY_DEFAULTS.soundReady end
	if type(entry.soundReadyFile) ~= "string" or entry.soundReadyFile == "" then entry.soundReadyFile = Helper.ENTRY_DEFAULTS.soundReadyFile end
	if type(entry.staticText) ~= "string" then entry.staticText = Helper.ENTRY_DEFAULTS.staticText end
	if type(entry.staticTextShowOnCooldown) ~= "boolean" then entry.staticTextShowOnCooldown = Helper.ENTRY_DEFAULTS.staticTextShowOnCooldown end
	if type(entry.staticTextUseGlobal) ~= "boolean" then
		local defaultStaticColor = Helper.ENTRY_DEFAULTS.staticTextColor or { 1, 1, 1, 1 }
		local currentStaticColor = Helper.NormalizeColor(entry.staticTextColor, defaultStaticColor)
		local normalizedDefaultStaticColor = Helper.NormalizeColor(defaultStaticColor, defaultStaticColor)
		local usesDefaultStaticStyle = (type(entry.staticTextFont) ~= "string" or entry.staticTextFont == "")
			and Helper.ClampInt(entry.staticTextSize, 6, 64, Helper.ENTRY_DEFAULTS.staticTextSize or 12) == (Helper.ENTRY_DEFAULTS.staticTextSize or 12)
			and Helper.NormalizeFontStyleChoice(entry.staticTextStyle, Helper.ENTRY_DEFAULTS.staticTextStyle or "OUTLINE") == (Helper.ENTRY_DEFAULTS.staticTextStyle or "OUTLINE")
			and currentStaticColor[1] == normalizedDefaultStaticColor[1]
			and currentStaticColor[2] == normalizedDefaultStaticColor[2]
			and currentStaticColor[3] == normalizedDefaultStaticColor[3]
			and currentStaticColor[4] == normalizedDefaultStaticColor[4]
			and Helper.NormalizeAnchor(entry.staticTextAnchor, Helper.ENTRY_DEFAULTS.staticTextAnchor or "CENTER") == (Helper.ENTRY_DEFAULTS.staticTextAnchor or "CENTER")
			and Helper.ClampInt(entry.staticTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.staticTextX or 0) == (Helper.ENTRY_DEFAULTS.staticTextX or 0)
			and Helper.ClampInt(entry.staticTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.staticTextY or 0) == (Helper.ENTRY_DEFAULTS.staticTextY or 0)
		entry.staticTextUseGlobal = usesDefaultStaticStyle
	end
	if type(entry.staticTextFont) ~= "string" then entry.staticTextFont = Helper.ENTRY_DEFAULTS.staticTextFont end
	entry.staticTextSize = Helper.ClampInt(entry.staticTextSize, 6, 64, Helper.ENTRY_DEFAULTS.staticTextSize or 12)
	entry.staticTextStyle = Helper.NormalizeFontStyleChoice(entry.staticTextStyle, Helper.ENTRY_DEFAULTS.staticTextStyle or "OUTLINE")
	entry.staticTextColor = Helper.NormalizeColor(entry.staticTextColor, Helper.ENTRY_DEFAULTS.staticTextColor or { 1, 1, 1, 1 })
	entry.staticTextAnchor = Helper.NormalizeAnchor(entry.staticTextAnchor, Helper.ENTRY_DEFAULTS.staticTextAnchor or "CENTER")
	entry.staticTextX = Helper.ClampInt(entry.staticTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.staticTextX or 0)
	entry.staticTextY = Helper.ClampInt(entry.staticTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.ENTRY_DEFAULTS.staticTextY or 0)
	entry.stateTextureInput = Helper.NormalizeTextureInput(entry.stateTextureInput)
	entry.stateTextureScale = Helper.ClampNumber(entry.stateTextureScale, 0.1, 8, Helper.ENTRY_DEFAULTS.stateTextureScale or 1)
	entry.stateTextureWidth = Helper.ClampNumber(entry.stateTextureWidth, 0.1, 8, Helper.ENTRY_DEFAULTS.stateTextureWidth or 1)
	entry.stateTextureHeight = Helper.ClampNumber(entry.stateTextureHeight, 0.1, 8, Helper.ENTRY_DEFAULTS.stateTextureHeight or 1)
	entry.stateTextureAngle = Helper.ClampNumber(entry.stateTextureAngle, 0, 360, Helper.ENTRY_DEFAULTS.stateTextureAngle or 0)
	entry.stateTextureDouble = entry.stateTextureDouble == true
	entry.stateTextureMirror = entry.stateTextureMirror == true
	if type(entry.stateTextureMirrorSecond) ~= "boolean" then entry.stateTextureMirrorSecond = Helper.ENTRY_DEFAULTS.stateTextureMirrorSecond == true end
	entry.stateTextureSpacingX = Helper.ClampInt(entry.stateTextureSpacingX, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, Helper.ENTRY_DEFAULTS.stateTextureSpacingX or 0)
	entry.stateTextureSpacingY = Helper.ClampInt(entry.stateTextureSpacingY, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, Helper.ENTRY_DEFAULTS.stateTextureSpacingY or 0)
	if entry.stateTextureInput == "" then
		entry.stateTextureType = nil
		entry.stateTextureAtlas = nil
		entry.stateTextureFileID = nil
	else
		local resolvedType, resolvedValue = Helper.ResolveTextureInput(entry.stateTextureInput)
		if resolvedType == "ATLAS" then
			entry.stateTextureType = "ATLAS"
			entry.stateTextureAtlas = resolvedValue
			entry.stateTextureFileID = nil
		elseif resolvedType == "FILEID" then
			entry.stateTextureType = "FILEID"
			entry.stateTextureFileID = resolvedValue
			entry.stateTextureAtlas = nil
		else
			entry.stateTextureType = nil
			entry.stateTextureAtlas = nil
			entry.stateTextureFileID = nil
		end
	end
	if entry.cooldownTextFont ~= nil and type(entry.cooldownTextFont) ~= "string" then entry.cooldownTextFont = nil end
	if entry.cooldownTextSize ~= nil then entry.cooldownTextSize = Helper.ClampInt(entry.cooldownTextSize, 6, 64, 12) end
	if entry.cooldownTextStyle ~= nil then entry.cooldownTextStyle = Helper.NormalizeFontStyleChoice(entry.cooldownTextStyle, "NONE") end
	if entry.cooldownTextColor ~= nil then entry.cooldownTextColor = Helper.NormalizeColor(entry.cooldownTextColor, Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor) end
	if entry.cooldownTextX ~= nil then entry.cooldownTextX = Helper.ClampInt(entry.cooldownTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0) end
	if entry.cooldownTextY ~= nil then entry.cooldownTextY = Helper.ClampInt(entry.cooldownTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0) end
	if entry.glowColor ~= nil then entry.glowColor = Helper.NormalizeColor(entry.glowColor, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor) end
	if entry.pandemicGlowColor ~= nil then entry.pandemicGlowColor = Helper.NormalizeColor(entry.pandemicGlowColor, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor) end
	entry.slotIndex = Helper.NormalizeSlotIndex(entry.slotIndex)
	entry.slotColumn = Helper.NormalizeSlotCoordinate(entry.slotColumn)
	entry.slotRow = Helper.NormalizeSlotCoordinate(entry.slotRow)
	entry.fixedGroupId = Helper.NormalizeFixedGroupId(entry.fixedGroupId)
end

function Helper.SyncOrder(order, map)
	if type(order) ~= "table" or type(map) ~= "table" then return end
	local cleaned = {}
	local seen = {}
	for _, id in ipairs(order) do
		if map[id] and not seen[id] then
			seen[id] = true
			cleaned[#cleaned + 1] = id
		end
	end
	for id in pairs(map) do
		if not seen[id] then cleaned[#cleaned + 1] = id end
	end
	for i = 1, #order do
		order[i] = nil
	end
	for i = 1, #cleaned do
		order[i] = cleaned[i]
	end
end

function Helper.CreatePanel(name, defaults)
	defaults = defaults or {}
	local layoutDefaults = defaults.layout or Helper.PANEL_LAYOUT_DEFAULTS
	local layout = Helper.CopyTableShallow(layoutDefaults)
	local globalFontKey = addon.functions and addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or "__EQOL_GLOBAL_FONT__"
	if layout.stackFont == nil or layout.stackFont == "" then layout.stackFont = globalFontKey end
	if layout.chargesFont == nil or layout.chargesFont == "" then layout.chargesFont = globalFontKey end
	if layout.keybindFont == nil or layout.keybindFont == "" then layout.keybindFont = globalFontKey end
	if layout.cooldownTextFont == nil or layout.cooldownTextFont == "" then layout.cooldownTextFont = globalFontKey end
	if layout.staticTextFont == nil or layout.staticTextFont == "" then layout.staticTextFont = globalFontKey end
	layout.fixedGroups = {}
	return {
		name = (type(name) == "string" and name ~= "" and name) or "Cooldown Panel",
		enabled = true,
		point = "CENTER",
		x = 0,
		y = 0,
		anchor = {
			point = "CENTER",
			relativePoint = "CENTER",
			relativeFrame = "UIParent",
			x = 0,
			y = 0,
		},
		layout = layout,
		entries = {},
		order = {},
	}
end

function Helper.CreateEntry(entryType, idValue, defaults)
	defaults = defaults or {}
	local entryDefaults = defaults.entry or {}
	local entry = Helper.CopyTableShallow(entryDefaults)
	for key, value in pairs(Helper.ENTRY_DEFAULTS) do
		if entry[key] == nil then entry[key] = value end
	end
	entry.type = entryType
	if entryType == "SPELL" then
		entry.spellID = tonumber(idValue)
		entry.showCharges = spellHasCharges(entry.spellID)
		entry.showStacks = false
	elseif entryType == "CDM_AURA" then
		local cdmAuras = CooldownPanels and CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.CreateEntryData then
			local created = cdmAuras:CreateEntryData(idValue, nil, defaults)
			if type(created) == "table" then
				for key, value in pairs(created) do
					entry[key] = value
				end
				entry.type = "CDM_AURA"
			end
		end
	elseif entryType == "ITEM" then
		entry.itemID = tonumber(idValue)
		if entry.showItemCount == nil then entry.showItemCount = true end
	elseif entryType == "SLOT" then
		entry.slotID = tonumber(idValue)
	elseif entryType == "STANCE" then
		entry.stanceID = type(idValue) == "string" and string.upper(idValue) or nil
		if CooldownPanels and CooldownPanels.NormalizeStanceEntry then CooldownPanels:NormalizeStanceEntry(entry) end
		entry.alwaysShow = false
		entry.showWhenMissing = false
		entry.showCooldown = false
		entry.showCooldownText = false
		entry.glowReady = false
		entry.soundReady = false
	elseif entryType == "MACRO" then
		entry.macroID = tonumber(idValue)
	end
	return entry
end

function Helper.GetEntryKey(panelId, entryId) return tostring(panelId) .. ":" .. tostring(entryId) end

function Helper.NormalizeDisplayCount(value)
	if value == nil then return nil end
	if issecretvalue and issecretvalue(value) then return value end
	if value == "" then return nil end
	return value
end

function Helper.HasDisplayCount(value)
	if value == nil then return false end
	if issecretvalue and issecretvalue(value) then return true end
	return value ~= ""
end

Helper.Keybinds = Helper.Keybinds or {}
local Keybinds = Helper.Keybinds

local DEFAULT_ACTION_BUTTON_NAMES = {
	"ActionButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
	"MultiBarLeftButton",
	"MultiBarRightButton",
	"MultiBar5Button",
	"MultiBar6Button",
	"MultiBar7Button",
}

local THIRD_PARTY_ACTION_BUTTON_PREFIXES = {
	{ prefix = "DominosActionButton", count = 180 },
	{ prefix = "BT4Button", count = 180 },
	{ prefix = "MultiBarRightActionButton", count = 12 },
	{ prefix = "MultiBarLeftActionButton", count = 12 },
	{ prefix = "MultiBarBottomRightActionButton", count = 12 },
	{ prefix = "MultiBarBottomLeftActionButton", count = 12 },
	{ prefix = "MultiBar5ActionButton", count = 12 },
	{ prefix = "MultiBar6ActionButton", count = 12 },
	{ prefix = "MultiBar7ActionButton", count = 12 },
}

local ELVUI_ACTION_BARS = 15
local ELVUI_ACTION_BUTTONS = 12

local GetItemInfoInstantFn = C_Item and C_Item.GetItemInfoInstant
local GetOverrideSpell = C_Spell and C_Spell.GetOverrideSpell
local GetInventoryItemID = GetInventoryItemID
local GetActionDisplayCount = C_ActionBar and C_ActionBar.GetActionDisplayCount
local GetMacroIndexByName = GetMacroIndexByName
local GetMacroInfo = GetMacroInfo
local FindSpellActionButtons = C_ActionBar and C_ActionBar.FindSpellActionButtons
local issecretvalue = _G.issecretvalue
local RangeIndicatorText = RANGE_INDICATOR
local DotIndicatorText = "\226\151\143"
local strtrimFn = strtrim

local function getEffectiveSpellId(spellId)
	local id = tonumber(spellId)
	if not id then return nil end
	if GetOverrideSpell then
		local overrideId = GetOverrideSpell(id)
		if type(overrideId) == "number" and overrideId > 0 then return overrideId end
	end
	return id
end

local function getRoot()
	if CooldownPanels and CooldownPanels.GetRoot then return CooldownPanels:GetRoot() end
	return nil
end

local function getRuntime(panelId)
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime[panelId]
	if not runtime then
		runtime = {}
		CooldownPanels.runtime[panelId] = runtime
	end
	return runtime
end

local function getActionSlotForSpell(spellId)
	if not spellId then return nil end
	if ActionButtonUtil and ActionButtonUtil.GetActionButtonBySpellID then
		local button = ActionButtonUtil.GetActionButtonBySpellID(spellId, false, false)
		if button and button.action then return button.action end
	end
	if FindSpellActionButtons then
		local slots = FindSpellActionButtons(spellId)
		if type(slots) == "table" and slots[1] then return slots[1] end
	end
	return nil
end

local function getActionDisplayCountForSpell(spellId)
	if not GetActionDisplayCount then return nil end
	local slot = getActionSlotForSpell(spellId)
	if not slot then return nil end
	return GetActionDisplayCount(slot)
end

function Helper.GetActionDisplayCountForSpell(spellId)
	if not spellId then return nil end
	return Helper.NormalizeDisplayCount(getActionDisplayCountForSpell(spellId))
end

local function getButtonActionSlot(button)
	if not button then return nil end
	local slot = tonumber(button.action)
	if not slot and button.GetAttribute then slot = tonumber(button:GetAttribute("action")) end
	if slot and slot > 0 then return slot end
	return nil
end

local function eachActionButton(callback)
	if type(callback) ~= "function" then return end
	local seen = {}
	local function visit(button)
		if not button or seen[button] then return end
		seen[button] = true
		callback(button)
	end

	for _, info in ipairs(THIRD_PARTY_ACTION_BUTTON_PREFIXES) do
		for i = 1, info.count do
			visit(_G[info.prefix .. i])
		end
	end

	for bar = 1, ELVUI_ACTION_BARS do
		for buttonIndex = 1, ELVUI_ACTION_BUTTONS do
			visit(_G["ElvUI_Bar" .. bar .. "Button" .. buttonIndex])
		end
	end

	local buttonNames = (ActionButtonUtil and ActionButtonUtil.ActionBarButtonNames) or DEFAULT_ACTION_BUTTON_NAMES
	local buttonCount = NUM_ACTIONBAR_BUTTONS or 12
	for _, prefix in ipairs(buttonNames) do
		for i = 1, buttonCount do
			visit(_G[prefix .. i])
		end
	end
end

local function normalizeBindingText(text)
	if type(text) ~= "string" then return nil end
	if strtrimFn then text = strtrimFn(text) end
	if text == "" or text == DotIndicatorText or text == RangeIndicatorText then return nil end
	return text
end

local function getDisplayedHotKeyText(button)
	if not button then return nil end
	local hotKey = button.HotKey
	if not (hotKey and hotKey.GetText) then return nil end
	return normalizeBindingText(hotKey:GetText())
end

function Helper.UpdateActionDisplayCountsForSpell(spellId, baseSpellId)
	if not GetActionDisplayCount then return false end
	local id = tonumber(spellId)
	local baseId = tonumber(baseSpellId)
	local runtime = CooldownPanels.runtime
	local index = runtime and runtime.spellIndex
	if not index then return false end

	local panels = {}
	if id and index[id] then
		for panelId in pairs(index[id]) do
			panels[panelId] = true
		end
	end
	if baseId and index[baseId] then
		for panelId in pairs(index[baseId]) do
			panels[panelId] = true
		end
	end
	if not next(panels) then return false end

	runtime.actionDisplayCounts = runtime.actionDisplayCounts or {}
	local cache = runtime.actionDisplayCounts

	for panelId in pairs(panels) do
		local panel = CooldownPanels:GetPanel(panelId)
		if panel and panel.entries then
			local runtimePanel = getRuntime(panelId)
			local entryToIcon = runtimePanel.entryToIcon
			local needsRefresh = false
			for entryId, entry in pairs(panel.entries) do
				if entry and entry.type == "SPELL" and entry.showStacks == true and entry.spellID then
					local entrySpellId = entry.spellID
					local effectiveId = getEffectiveSpellId(entrySpellId)
					local matches = (id and (entrySpellId == id or effectiveId == id)) or (baseId and (entrySpellId == baseId or effectiveId == baseId))
					if matches then
						local displayCount = Helper.GetActionDisplayCountForSpell(effectiveId) or (effectiveId ~= entrySpellId and Helper.GetActionDisplayCountForSpell(entrySpellId) or nil)
						cache[Helper.GetEntryKey(panelId, entryId)] = displayCount

						local icon = entryToIcon and entryToIcon[entryId]
						if icon then
							if displayCount ~= nil then
								icon.count:SetText(displayCount)
								icon.count:Show()
							else
								icon.count:Hide()
								needsRefresh = true
							end
						else
							if displayCount ~= nil then needsRefresh = true end
						end
					end
				end
			end
			if needsRefresh then
				if CooldownPanels:GetPanel(panelId) then CooldownPanels:RefreshPanel(panelId) end
			end
		end
	end
	return true
end

local function getActionButtonSlotMap()
	local runtime = CooldownPanels.runtime or {}
	if runtime._eqolActionButtonSlotMap then return runtime._eqolActionButtonSlotMap end
	local map = {}
	eachActionButton(function(button)
		local slot = getButtonActionSlot(button)
		if slot and map[slot] == nil then map[slot] = button end
	end)
	runtime._eqolActionButtonSlotMap = map
	CooldownPanels.runtime = runtime
	return map
end

local function getBindingTextForButton(button)
	if not button then return nil end
	local key = nil
	if GetBindingKey then
		if button.bindingAction then key = GetBindingKey(button.bindingAction) end
		if not key and button.commandName then key = GetBindingKey(button.commandName) end
		if not key and type(button.config) == "table" and button.config.keyBoundTarget then key = GetBindingKey(button.config.keyBoundTarget) end
		if not key and button.GetName then
			local name = button:GetName()
			if name and name ~= "" then key = GetBindingKey("CLICK " .. name .. ":LeftButton") end
		end
	end
	local text = key and GetBindingText and GetBindingText(key, 1)
	text = normalizeBindingText(text)
	if not text then text = getDisplayedHotKeyText(button) end
	return text
end

local function formatKeybindText(text)
	if type(text) ~= "string" or text == "" then return text end
	local labels = addon and addon.ActionBarLabels
	if labels and labels.ShortenHotkeyText then return labels.ShortenHotkeyText(text) end
	return text
end

local function getBindingTextForActionSlot(slot)
	if not slot then return nil end
	local map = getActionButtonSlotMap()
	local text = map and getBindingTextForButton(map[slot])
	if text then return text end
	if GetBindingKey then
		local buttons = NUM_ACTIONBAR_BUTTONS or 12
		local index = ((slot - 1) % buttons) + 1
		local key = GetBindingKey("ACTIONBUTTON" .. index)
		text = key and GetBindingText and GetBindingText(key, 1)
		text = normalizeBindingText(text)
		return text
	end
	return nil
end

local function getBindingTextForSpell(spellId)
	if not spellId then return nil end
	local text = nil
	if ActionButtonUtil and ActionButtonUtil.GetActionButtonBySpellID then
		text = getBindingTextForButton(ActionButtonUtil.GetActionButtonBySpellID(spellId, false, false))
		if text then return text end
	end
	if FindSpellActionButtons then
		local slots = FindSpellActionButtons(spellId)
		if type(slots) == "table" then
			local seen = {}
			for _, slot in ipairs(slots) do
				if slot and not seen[slot] then
					seen[slot] = true
					text = getBindingTextForActionSlot(slot)
					if text then return text end
				end
			end
			for key, value in pairs(slots) do
				local slot = nil
				if type(value) == "number" then
					slot = value
				elseif value == true and type(key) == "number" then
					slot = key
				end
				if slot and not seen[slot] then
					seen[slot] = true
					text = getBindingTextForActionSlot(slot)
					if text then return text end
				end
			end
		end
	end
	return nil
end

local function buildKeybindLookup()
	local runtime = CooldownPanels.runtime or {}
	if runtime._eqolKeybindLookup then return runtime._eqolKeybindLookup end
	local lookup = {
		item = {},
		macro = {},
		macroName = {},
	}
	local getMacroItem = GetMacroItem

	eachActionButton(function(button)
		local slot = getButtonActionSlot(button)
		if not slot then return end
		local keyText = getBindingTextForButton(button)
		if not keyText and GetBindingKey then
			local buttons = NUM_ACTIONBAR_BUTTONS or 12
			local index = ((slot - 1) % buttons) + 1
			local key = GetBindingKey("ACTIONBUTTON" .. index)
			keyText = key and GetBindingText and GetBindingText(key, 1)
			keyText = normalizeBindingText(keyText)
		end
		if not (keyText and GetActionInfo) then return end
		local actionType, actionId = GetActionInfo(slot)
		if actionType == "item" and actionId then
			if not lookup.item[actionId] then lookup.item[actionId] = keyText end
		elseif actionType == "macro" and actionId then
			if not lookup.macro[actionId] then lookup.macro[actionId] = keyText end
			if GetMacroInfo then
				local macroName = GetMacroInfo(actionId)
				if type(macroName) == "string" and macroName ~= "" and not lookup.macroName[macroName] then lookup.macroName[macroName] = keyText end
			end
			if getMacroItem then
				local macroItem = getMacroItem(actionId)
				if macroItem then
					local itemId
					if type(macroItem) == "number" then
						itemId = macroItem
					elseif GetItemInfoInstantFn then
						itemId = GetItemInfoInstantFn(macroItem)
					end
					if itemId and not lookup.item[itemId] then lookup.item[itemId] = keyText end
				end
			end
		end
	end)

	runtime._eqolKeybindLookup = lookup
	CooldownPanels.runtime = runtime
	return lookup
end

function Keybinds.InvalidateCache()
	if not CooldownPanels.runtime then return end
	CooldownPanels.runtime._eqolActionButtonSlotMap = nil
	CooldownPanels.runtime._eqolKeybindLookup = nil
	CooldownPanels.runtime._eqolKeybindCache = nil
end

function Keybinds.MarkPanelsDirty()
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	CooldownPanels.runtime.keybindPanelsDirty = true
end

function Keybinds.RebuildPanels()
	local root = getRoot()
	if not root or not root.panels then return nil end
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	local panels = {}
	for panelId, panel in pairs(root.panels) do
		local layout = panel and panel.layout
		if panel and panel.enabled ~= false and layout and layout.keybindsEnabled == true then panels[panelId] = true end
	end
	runtime.keybindPanels = panels
	runtime.keybindPanelsDirty = nil
	return panels
end

function Keybinds.HasPanels()
	local runtime = CooldownPanels.runtime
	if not runtime then return false end
	local panels = (runtime.keybindPanelsDirty or runtime.keybindPanels == nil) and Keybinds.RebuildPanels() or runtime.keybindPanels
	return panels ~= nil and next(panels) ~= nil
end

function Keybinds.RefreshPanels()
	local runtime = CooldownPanels.runtime
	if not runtime then return false end
	local panels = (runtime.keybindPanelsDirty or not runtime.keybindPanels) and Keybinds.RebuildPanels() or runtime.keybindPanels
	if not panels or not next(panels) then return false end
	for panelId in pairs(panels) do
		if CooldownPanels.GetPanel and CooldownPanels.RefreshPanel then
			if CooldownPanels:GetPanel(panelId) then CooldownPanels:RefreshPanel(panelId) end
		end
	end
	return true
end

function Keybinds.RequestRefresh(cause)
	local runtime = CooldownPanels.runtime
	if not runtime then return end
	if not Keybinds.HasPanels() then return end
	if cause then runtime.keybindRefreshCause = cause end
	if runtime.keybindRefreshPending then return end
	runtime.keybindRefreshPending = true
	C_Timer.After(0.1, function()
		runtime.keybindRefreshPending = nil
		if not Keybinds.HasPanels() then return end
		runtime.keybindRefreshCauseActive = runtime.keybindRefreshCause
		runtime.keybindRefreshCause = nil
		Keybinds.InvalidateCache()
		Keybinds.RefreshPanels()
		runtime.keybindRefreshCauseActive = nil
	end)
end

function Keybinds.GetEntryKeybindText(entry, layout)
	if not entry then return nil end
	if layout and layout.keybindsIgnoreItems == true and (entry.type == "ITEM" or entry.type == "SLOT") then return nil end
	local runtime = CooldownPanels.runtime or {}
	runtime._eqolKeybindCache = runtime._eqolKeybindCache or {}
	local slotItemId
	if entry.type == "SLOT" and entry.slotID then slotItemId = GetInventoryItemID and GetInventoryItemID("player", entry.slotID) end
	local effectiveSpellId = entry.type == "SPELL" and getEffectiveSpellId(entry.spellID) or nil
	local cacheValue = effectiveSpellId or entry.spellID or entry.itemID or entry.slotID or entry.macroID or entry.macroName or ""
	local cacheKey = tostring(entry.type) .. ":" .. tostring(cacheValue) .. ":" .. tostring(slotItemId or "")
	local cached = runtime._eqolKeybindCache[cacheKey]
	if cached ~= nil then return cached or nil end

	local text = nil
	if entry.type == "SPELL" and entry.spellID then
		local spellId = effectiveSpellId or entry.spellID
		text = getBindingTextForSpell(spellId)
		if not text and effectiveSpellId and effectiveSpellId ~= entry.spellID then text = getBindingTextForSpell(entry.spellID) end
	elseif entry.type == "ITEM" and entry.itemID then
		local lookup = buildKeybindLookup()
		text = lookup.item and lookup.item[entry.itemID]
	elseif entry.type == "SLOT" and slotItemId then
		local lookup = buildKeybindLookup()
		text = lookup.item and lookup.item[slotItemId]
	elseif entry.type == "MACRO" then
		local lookup = buildKeybindLookup()
		local macroId = tonumber(entry.macroID)
		local macroName = type(entry.macroName) == "string" and entry.macroName or nil
		if macroId and lookup.macro then text = lookup.macro[macroId] end
		if not text and macroName and lookup.macroName then text = lookup.macroName[macroName] end
		if not text and macroName and GetMacroIndexByName and lookup.macro then
			local resolvedId = GetMacroIndexByName(macroName)
			if type(resolvedId) == "number" and resolvedId > 0 then text = lookup.macro[resolvedId] end
		end
	end

	text = formatKeybindText(text)
	runtime._eqolKeybindCache[cacheKey] = text or false
	CooldownPanels.runtime = runtime
	return text
end

function CooldownPanels:RequestPanelRefresh(panelId)
	if not panelId then return end
	self.runtime = self.runtime or {}
	local rt = self.runtime

	rt._eqolPanelRefreshQueue = rt._eqolPanelRefreshQueue or {}
	rt._eqolPanelRefreshQueue[panelId] = true

	if rt._eqolPanelRefreshPending then return end
	rt._eqolPanelRefreshPending = true

	C_Timer.After(0, function()
		local runtime = CooldownPanels.runtime
		if not runtime then return end
		runtime._eqolPanelRefreshPending = nil

		local q = runtime._eqolPanelRefreshQueue
		if not q then return end

		for id in pairs(q) do
			q[id] = nil
			if CooldownPanels:GetPanel(id) then CooldownPanels:RefreshPanel(id) end
		end
	end)
end
