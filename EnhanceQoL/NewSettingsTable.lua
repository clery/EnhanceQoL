local addonName, addon = ...

addon.variables.NewVersionTableEQOL = {

	-- Root category id from Settings/MainCategory.lua
	["EQOL_UI"] = true,

	-- Legacy/alias (can stay harmlessly)
	["EQOL_INTERFACE"] = true,

	-- Expandable section id in Settings/ClassBuffReminder.lua
	["EQOL_ClassBuffReminder"] = true,
	["EQOL_MapNavigation"] = true,
	["EQOL_CastbarsAndCooldowns"] = true,

	-- Feature setting keys
	["EQOL_classBuffReminderEnabled"] = true,
	["EQOL_xpBarEnabled"] = true,

	-- Map Navigation -> Square Minimap Stats -> Location
	["EQOL_squareMinimapStatsLocationShowZone"] = true,
}
