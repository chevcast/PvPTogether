local addonName, addonTable = ...

local PvPTogether = _G.PvPTogether or addonTable or {}
_G.PvPTogether = PvPTogether

local raw_issecretvalue = type(issecretvalue) == "function" and issecretvalue or nil

PvPTogether.addonName = addonName or "PvPTogether"

local STYLE_MODERN = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Modern or 0
local STYLE_THIN = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Thin or 1
local STYLE_BLOCK = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Block or 2
local STYLE_HEALTH_FOCUS = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.HealthFocus or 3
local STYLE_CAST_FOCUS = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.CastFocus or 4
local STYLE_LEGACY = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Legacy or 5

PvPTogether.nameplateStyleOrder = {
	STYLE_MODERN,
	STYLE_THIN,
	STYLE_BLOCK,
	STYLE_HEALTH_FOCUS,
	STYLE_CAST_FOCUS,
	STYLE_LEGACY,
}

PvPTogether.nameplateStyleLabels = {
	[STYLE_MODERN] = UNIT_NAMEPLATES_STYLE_MODERN or "Modern",
	[STYLE_THIN] = UNIT_NAMEPLATES_STYLE_THIN or "Thin",
	[STYLE_BLOCK] = UNIT_NAMEPLATES_STYLE_BLOCK or "Block",
	[STYLE_HEALTH_FOCUS] = UNIT_NAMEPLATES_STYLE_HEALTH_FOCUS or "Health Focus",
	[STYLE_CAST_FOCUS] = UNIT_NAMEPLATES_STYLE_CAST_FOCUS or "Cast Focus",
	[STYLE_LEGACY] = UNIT_NAMEPLATES_STYLE_LEGACY or "Legacy",
}

PvPTogether.DEFAULTS = {
	enabled = true,
	partyMemberBorderEnabled = false,
	partyMemberBorderColor = {
		r = 0.0,
		g = 1.0,
		b = 0.0,
	},
	friendlyPlayerBorderEnabled = false,
	friendlyPlayerBorderColor = {
		r = 0.0,
		g = 1.0,
		b = 1.0,
	},
	enemyPlayerBorderEnabled = false,
	enemyPlayerBorderColor = {
		r = 1.0,
		g = 0.0,
		b = 0.0,
	},
	styleSeeded = false,
	partyMemberStyleSeeded = false,
}

PvPTogether.isInitialized = PvPTogether.isInitialized or false
PvPTogether.hasLoggedIn = PvPTogether.hasLoggedIn or false
PvPTogether.isEnabled = PvPTogether.isEnabled or false
PvPTogether.db = PvPTogether.db or nil
PvPTogether.trackedNamePlateFrames = PvPTogether.trackedNamePlateFrames
	or setmetatable({}, { __mode = "k" })

local function IsNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

local function ClampColorComponent(value, fallback)
	local numericValue = PvPTogether:SafeToNumber(value)
	if numericValue == nil then
		return fallback
	end
	if numericValue < 0 then
		return 0
	end
	if numericValue > 1 then
		return 1
	end
	return numericValue
end

local function ColorsNearlyEqual(left, right)
	return math.abs((left or 0) - (right or 0)) < 0.001
end

local function ColorTablesEqual(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	return ColorsNearlyEqual(left.r, right.r) and ColorsNearlyEqual(left.g, right.g) and ColorsNearlyEqual(left.b, right.b)
end

function PvPTogether:IsSecretValue(value)
	if not raw_issecretvalue then
		return false
	end
	local ok, isSecret = pcall(raw_issecretvalue, value)
	return ok and isSecret and true or false
end

function PvPTogether:SafeToNumber(value)
	if self:IsSecretValue(value) then
		return nil
	end
	local ok, numericValue = pcall(tonumber, value)
	if not ok then
		return nil
	end
	if type(numericValue) ~= "number" then
		return nil
	end
	return numericValue
end

function PvPTogether:SafeToString(value, fallback)
	if self:IsSecretValue(value) then
		return fallback or ""
	end
	local ok, textValue = pcall(tostring, value)
	if not ok then
		return fallback or ""
	end
	return textValue
end

function PvPTogether:DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in pairs(value) do
		copy[key] = self:DeepCopy(item)
	end
	return copy
end

function PvPTogether:ApplyDefaults(destination, defaults)
	if type(destination) ~= "table" or type(defaults) ~= "table" then
		return destination
	end

	for key, defaultValue in pairs(defaults) do
		if destination[key] == nil then
			destination[key] = self:DeepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(destination[key]) == "table" then
			self:ApplyDefaults(destination[key], defaultValue)
		end
	end

	return destination
end

function PvPTogether:IsInCombatLockdown()
	if type(InCombatLockdown) ~= "function" then
		return false
	end

	local ok, inCombat = pcall(InCombatLockdown)
	return ok and inCombat and true or false
end

function PvPTogether:GetCurrentGlobalNameplateStyle()
	if C_CVar and type(C_CVar.GetCVar) == "function" then
		local rawValue = C_CVar.GetCVar("nameplateStyle")
		local numericStyle = self:SafeToNumber(rawValue)
		if numericStyle then
			numericStyle = math.floor(numericStyle + 0.5)
			if self:IsNameplateStyle(numericStyle) then
				return numericStyle
			end
		end
	end

	return STYLE_MODERN
end

function PvPTogether:IsNameplateStyle(value)
	local numericStyle = self:SafeToNumber(value)
	if numericStyle == nil then
		return false
	end
	numericStyle = math.floor(numericStyle + 0.5)

	for _, styleValue in ipairs(self.nameplateStyleOrder) do
		if styleValue == numericStyle then
			return true
		end
	end

	return false
end

function PvPTogether:NormalizeNameplateStyle(value, fallbackStyle)
	local fallback = fallbackStyle
	if not self:IsNameplateStyle(fallback) then
		fallback = STYLE_MODERN
	end

	if not self:IsNameplateStyle(value) then
		return fallback
	end
	return math.floor(value + 0.5)
end

function PvPTogether:GetNameplateStyleLabel(styleValue)
	local normalizedStyle = self:NormalizeNameplateStyle(styleValue, STYLE_MODERN)
	return self.nameplateStyleLabels[normalizedStyle] or ("Style " .. self:SafeToString(normalizedStyle, "?"))
end

function PvPTogether:GetConfiguredStyleForUnitKind(unitKind)
	if not self.db then
		return self:GetCurrentGlobalNameplateStyle()
	end

	local styleKey = nil
	if unitKind == "partyMember" then
		styleKey = "partyMemberStyle"
	elseif unitKind == "friendlyPlayer" then
		styleKey = "friendlyPlayerStyle"
	elseif unitKind == "enemyPlayer" then
		styleKey = "enemyPlayerStyle"
	end

	if not styleKey then
		return self:GetCurrentGlobalNameplateStyle()
	end

	local configuredStyle = self.db[styleKey]
	return self:NormalizeNameplateStyle(configuredStyle, self:GetCurrentGlobalNameplateStyle())
end

function PvPTogether:GetBorderOverrideOptionKeysForUnitKind(unitKind)
	if unitKind == "partyMember" then
		return "partyMemberBorderEnabled", "partyMemberBorderColor"
	end
	if unitKind == "friendlyPlayer" then
		return "friendlyPlayerBorderEnabled", "friendlyPlayerBorderColor"
	end
	if unitKind == "enemyPlayer" then
		return "enemyPlayerBorderEnabled", "enemyPlayerBorderColor"
	end
	return nil, nil
end

function PvPTogether:GetDefaultBorderColorForUnitKind(unitKind)
	local _, colorKey = self:GetBorderOverrideOptionKeysForUnitKind(unitKind)
	if colorKey and type(self.DEFAULTS[colorKey]) == "table" then
		return self.DEFAULTS[colorKey]
	end
	return {
		r = 1.0,
		g = 1.0,
		b = 1.0,
	}
end

function PvPTogether:NormalizeColorRGB(colorValue, fallbackColor)
	local fallback = type(fallbackColor) == "table" and fallbackColor or {
		r = 1.0,
		g = 1.0,
		b = 1.0,
	}

	if type(colorValue) ~= "table" then
		return {
			r = fallback.r,
			g = fallback.g,
			b = fallback.b,
		}
	end

	return {
		r = ClampColorComponent(colorValue.r, fallback.r),
		g = ClampColorComponent(colorValue.g, fallback.g),
		b = ClampColorComponent(colorValue.b, fallback.b),
	}
end

function PvPTogether:IsBorderColorOverrideEnabledForUnitKind(unitKind)
	local enabledKey = self:GetBorderOverrideOptionKeysForUnitKind(unitKind)
	if not enabledKey or not self.db then
		return false
	end
	return self.db[enabledKey] == true
end

function PvPTogether:GetConfiguredBorderColorForUnitKind(unitKind)
	local _, colorKey = self:GetBorderOverrideOptionKeysForUnitKind(unitKind)
	local fallbackColor = self:GetDefaultBorderColorForUnitKind(unitKind)
	if not colorKey or not self.db then
		return self:NormalizeColorRGB(nil, fallbackColor)
	end
	return self:NormalizeColorRGB(self.db[colorKey], fallbackColor)
end

function PvPTogether:InitializeDatabase()
	if type(_G.PvPTogetherDBChar) ~= "table" then
		_G.PvPTogetherDBChar = {}
	end

	self.db = _G.PvPTogetherDBChar
	self:ApplyDefaults(self.db, self.DEFAULTS)

	if self.db.styleSeeded ~= true then
		local globalStyle = self:GetCurrentGlobalNameplateStyle()
		if self.db.partyMemberStyle == nil then
			self.db.partyMemberStyle = globalStyle
		end
		if self.db.friendlyPlayerStyle == nil then
			self.db.friendlyPlayerStyle = globalStyle
		end
		if self.db.enemyPlayerStyle == nil then
			self.db.enemyPlayerStyle = globalStyle
		end
		self.db.styleSeeded = true
	end

	if self.db.partyMemberStyleSeeded ~= true then
		if self.db.partyMemberStyle == nil and self:IsNameplateStyle(self.db.friendlyPlayerStyle) then
			local fallbackGroupStyle = self:NormalizeNameplateStyle(
				self.db.friendlyPlayerStyle,
				self:GetCurrentGlobalNameplateStyle()
			)
			self.db.partyMemberStyle = fallbackGroupStyle
		end
		self.db.partyMemberStyleSeeded = true
	end

	local fallbackStyle = self:GetCurrentGlobalNameplateStyle()
	if self.db.partyMemberStyle ~= nil then
		self.db.partyMemberStyle = self:NormalizeNameplateStyle(self.db.partyMemberStyle, fallbackStyle)
	end
	if self.db.friendlyPlayerStyle ~= nil then
		self.db.friendlyPlayerStyle = self:NormalizeNameplateStyle(self.db.friendlyPlayerStyle, fallbackStyle)
	end
	if self.db.enemyPlayerStyle ~= nil then
		self.db.enemyPlayerStyle = self:NormalizeNameplateStyle(self.db.enemyPlayerStyle, fallbackStyle)
	end
	self.db.partyMemberBorderEnabled = self.db.partyMemberBorderEnabled == true
	self.db.friendlyPlayerBorderEnabled = self.db.friendlyPlayerBorderEnabled == true
	self.db.enemyPlayerBorderEnabled = self.db.enemyPlayerBorderEnabled == true
	self.db.partyMemberBorderColor =
		self:NormalizeColorRGB(self.db.partyMemberBorderColor, self.DEFAULTS.partyMemberBorderColor)
	self.db.friendlyPlayerBorderColor =
		self:NormalizeColorRGB(self.db.friendlyPlayerBorderColor, self.DEFAULTS.friendlyPlayerBorderColor)
	self.db.enemyPlayerBorderColor =
		self:NormalizeColorRGB(self.db.enemyPlayerBorderColor, self.DEFAULTS.enemyPlayerBorderColor)
	self.db.enabled = self.db.enabled ~= false
end

function PvPTogether:GetOption(optionKey)
	if not self.db then
		return nil
	end
	return self.db[optionKey]
end

function PvPTogether:SetOption(optionKey, value)
	if not self.db or not IsNonEmptyString(optionKey) then
		return false
	end

	local normalizedValue = value
	if optionKey == "enabled" then
		normalizedValue = value and true or false
	elseif
		optionKey == "partyMemberStyle"
		or optionKey == "friendlyPlayerStyle"
		or optionKey == "enemyPlayerStyle"
	then
		if value == nil then
			normalizedValue = nil
		else
			local fallbackStyle = self:GetCurrentGlobalNameplateStyle()
			normalizedValue = self:NormalizeNameplateStyle(value, fallbackStyle)
		end
	elseif
		optionKey == "partyMemberBorderEnabled"
		or optionKey == "friendlyPlayerBorderEnabled"
		or optionKey == "enemyPlayerBorderEnabled"
	then
		normalizedValue = value and true or false
	elseif optionKey == "partyMemberBorderColor" then
		normalizedValue = self:NormalizeColorRGB(value, self.DEFAULTS.partyMemberBorderColor)
	elseif optionKey == "friendlyPlayerBorderColor" then
		normalizedValue = self:NormalizeColorRGB(value, self.DEFAULTS.friendlyPlayerBorderColor)
	elseif optionKey == "enemyPlayerBorderColor" then
		normalizedValue = self:NormalizeColorRGB(value, self.DEFAULTS.enemyPlayerBorderColor)
	else
		return false
	end

	if type(normalizedValue) == "table" and type(self.db[optionKey]) == "table" then
		if ColorTablesEqual(self.db[optionKey], normalizedValue) then
			return false
		end
	elseif self.db[optionKey] == normalizedValue then
		return false
	end

	if type(normalizedValue) == "table" then
		self.db[optionKey] = self:DeepCopy(normalizedValue)
	else
		self.db[optionKey] = normalizedValue
	end

	if optionKey == "enabled" then
		if normalizedValue then
			self:Enable()
		else
			self:Disable()
		end
	elseif self.isEnabled and self.ReapplyAllNameplateStyles then
		self:ReapplyAllNameplateStyles("option:" .. optionKey)
		if self.ScheduleReapplyAllNameplateStyles then
			self:ScheduleReapplyAllNameplateStyles(0.02)
		end
	end

	return true
end

function PvPTogether:Print(message)
	local text = "|cff00ff98PvPTogether|r: " .. self:SafeToString(message, "")
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(text)
		return
	end
	print("PvPTogether:", self:SafeToString(message, ""))
end

function PvPTogether:RegisterSlashCommands()
	if self.slashCommandsRegistered then
		return
	end

	SLASH_PVPTOGETHER1 = "/pt"
	SLASH_PVPTOGETHER2 = "/pvptogether"
	SlashCmdList.PVPTOGETHER = function(message)
		local command = self:SafeToString(message, "")
		command = command:lower():gsub("^%s+", ""):gsub("%s+$", "")

		if command == "on" then
			self:SetOption("enabled", true)
			self:Print("Enabled.")
			return
		end
		if command == "off" then
			self:SetOption("enabled", false)
			self:Print("Disabled.")
			return
		end
		if command == "toggle" then
			self:SetOption("enabled", not self:GetOption("enabled"))
			self:Print(self:GetOption("enabled") and "Enabled." or "Disabled.")
			return
		end
		if not self:OpenOptionsWindow() then
			self:Print("Use /pt on, /pt off, or /pt toggle.")
		end
	end

	self.slashCommandsRegistered = true
end

function PvPTogether:Enable()
	if not self.hasLoggedIn or self.isEnabled then
		return
	end

	self.isEnabled = true

	if self.EnableNameplateModule then
		self:EnableNameplateModule()
	end
end

function PvPTogether:Disable()
	if not self.isEnabled then
		return
	end

	self.isEnabled = false

	if self.DisableNameplateModule then
		self:DisableNameplateModule()
	end
end

function PvPTogether:Initialize()
	if self.isInitialized then
		return
	end

	self:InitializeDatabase()
	self:RegisterSlashCommands()
	self.isInitialized = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, eventName, ...)
	if eventName == "ADDON_LOADED" then
		local loadedAddonName = ...
		if loadedAddonName == PvPTogether.addonName then
			PvPTogether:Initialize()
		end
	elseif eventName == "PLAYER_LOGIN" then
		PvPTogether.hasLoggedIn = true
		if not PvPTogether.isInitialized then
			PvPTogether:Initialize()
		end
		if PvPTogether.InitializeOptionsWindow then
			PvPTogether:InitializeOptionsWindow()
		end

		if PvPTogether:GetOption("enabled") then
			PvPTogether:Enable()
		end
	end
end)
