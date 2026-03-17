local PvPTogether = _G.PvPTogether

if not PvPTogether then
	return
end

PvPTogether.optionControls = PvPTogether.optionControls or {}
local INHERIT_STYLE_DROPDOWN_VALUE = "__pvptogether_inherit_style__"

local function GetStyleDropdownLabel(optionKey)
	local configuredStyle = PvPTogether:GetOption(optionKey)
	if PvPTogether:IsNameplateStyle(configuredStyle) then
		return PvPTogether:GetNameplateStyleLabel(configuredStyle), configuredStyle
	end

	local globalStyle = PvPTogether:GetCurrentGlobalNameplateStyle()
	local globalStyleLabel = PvPTogether:GetNameplateStyleLabel(globalStyle)
	return "Inherit (Global: " .. globalStyleLabel .. ")", INHERIT_STYLE_DROPDOWN_VALUE
end

local function CreateCheckbox(parent, optionKey, labelText, tooltipText, x, y)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
	label:SetText(labelText)
	checkbox.Label = label

	if type(tooltipText) == "string" and tooltipText ~= "" then
		checkbox.tooltipText = tooltipText
	end

	checkbox:SetScript("OnClick", function(self)
		PvPTogether:SetOption(optionKey, self:GetChecked() == true)
		PvPTogether:RefreshOptionsWindow()
	end)

	return checkbox
end

local function CreateDropdown(parent, titleText, tooltipText, x, y, width, initializeMenu)
	if type(UIDropDownMenu_Initialize) ~= "function" or type(UIDropDownMenu_SetWidth) ~= "function" then
		return nil
	end

	local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	title:SetText(titleText)

	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -16, -2)
	dropdown.initializeMenu = initializeMenu
	dropdown.title = title
	dropdown.tooltipText = tooltipText

	UIDropDownMenu_SetWidth(dropdown, width or 200)
	UIDropDownMenu_Initialize(dropdown, initializeMenu)
	return dropdown
end

local function CreateStyleDropdown(parent, titleText, tooltipText, x, y, optionKey)
	return CreateDropdown(parent, titleText, tooltipText, x, y, 220, function(_, level)
		local inheritInfo = UIDropDownMenu_CreateInfo()
		local inheritLabel = GetStyleDropdownLabel(optionKey)
		inheritInfo.text = inheritLabel
		inheritInfo.value = INHERIT_STYLE_DROPDOWN_VALUE
		inheritInfo.checked = not PvPTogether:IsNameplateStyle(PvPTogether:GetOption(optionKey))
		inheritInfo.func = function()
			PvPTogether:SetOption(optionKey, nil)
			PvPTogether:RefreshOptionsWindow()
			CloseDropDownMenus()
		end
		UIDropDownMenu_AddButton(inheritInfo, level)

		for _, styleValue in ipairs(PvPTogether.nameplateStyleOrder) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = PvPTogether:GetNameplateStyleLabel(styleValue)
			info.value = styleValue
			info.checked = PvPTogether:GetOption(optionKey) == styleValue
			info.func = function()
				PvPTogether:SetOption(optionKey, styleValue)
				PvPTogether:RefreshOptionsWindow()
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)
end

local function ClampColorComponent(value, fallback)
	local numericValue = PvPTogether:SafeToNumber(value)
	if not numericValue then
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

local function GetColorOption(optionKey, fallbackColor)
	local configuredColor = PvPTogether:GetOption(optionKey)
	if type(configuredColor) ~= "table" then
		return {
			r = fallbackColor.r,
			g = fallbackColor.g,
			b = fallbackColor.b,
		}
	end

	return {
		r = ClampColorComponent(configuredColor.r, fallbackColor.r),
		g = ClampColorComponent(configuredColor.g, fallbackColor.g),
		b = ClampColorComponent(configuredColor.b, fallbackColor.b),
	}
end

local function CreateColorSwatch(parent, optionKey, labelText, tooltipText, fallbackColor, x, y)
	local swatchButton = CreateFrame("Button", nil, parent)
	swatchButton:SetSize(22, 22)
	swatchButton:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

	local border = swatchButton:CreateTexture(nil, "BORDER")
	border:SetAllPoints()
	border:SetColorTexture(0, 0, 0, 1)
	swatchButton.Border = border

	local colorTexture = swatchButton:CreateTexture(nil, "ARTWORK")
	colorTexture:SetPoint("TOPLEFT", swatchButton, "TOPLEFT", 1, -1)
	colorTexture:SetPoint("BOTTOMRIGHT", swatchButton, "BOTTOMRIGHT", -1, 1)
	swatchButton.ColorTexture = colorTexture

	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("LEFT", swatchButton, "RIGHT", 8, 0)
	label:SetText(labelText)
	swatchButton.Label = label

	if type(tooltipText) == "string" and tooltipText ~= "" then
		swatchButton.tooltipText = tooltipText
	end

	local function SetColorOption(r, g, b)
		PvPTogether:SetOption(optionKey, {
			r = ClampColorComponent(r, fallbackColor.r),
			g = ClampColorComponent(g, fallbackColor.g),
			b = ClampColorComponent(b, fallbackColor.b),
		})
		PvPTogether:RefreshOptionsWindow()
	end

	swatchButton:SetScript("OnClick", function()
		if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then
			PvPTogether:Print("Color picker is unavailable right now.")
			return
		end

		local currentColor = GetColorOption(optionKey, fallbackColor)
		local previousColor = {
			r = currentColor.r,
			g = currentColor.g,
			b = currentColor.b,
		}

		local info = {}
		info.r = currentColor.r
		info.g = currentColor.g
		info.b = currentColor.b
		info.hasOpacity = false
		info.swatchFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			SetColorOption(r, g, b)
		end
		info.cancelFunc = function()
			SetColorOption(previousColor.r, previousColor.g, previousColor.b)
		end
		ColorPickerFrame:SetupColorPickerAndShow(info)
	end)

	return swatchButton
end

local function RefreshDropdownControl(dropdown, labelText, selectedValue)
	if not dropdown then
		return
	end

	UIDropDownMenu_Initialize(dropdown, dropdown.initializeMenu)
	UIDropDownMenu_SetText(dropdown, labelText)
	if UIDropDownMenu_SetSelectedValue then
		UIDropDownMenu_SetSelectedValue(dropdown, selectedValue)
	end
end

local function SetDropdownEnabled(dropdown, enabled)
	if not dropdown then
		return
	end

	if UIDropDownMenu_EnableDropDown and UIDropDownMenu_DisableDropDown then
		if enabled then
			UIDropDownMenu_EnableDropDown(dropdown)
		else
			UIDropDownMenu_DisableDropDown(dropdown)
		end
	end

	dropdown:SetAlpha(enabled and 1 or 0.5)
	if dropdown.title then
		dropdown.title:SetAlpha(enabled and 1 or 0.5)
	end
end

local function RefreshColorSwatch(swatch, optionKey, fallbackColor)
	if not swatch or not swatch.ColorTexture then
		return
	end

	local color = GetColorOption(optionKey, fallbackColor)
	swatch.ColorTexture:SetColorTexture(color.r, color.g, color.b, 1)
end

local function SetColorSwatchEnabled(swatch, enabled)
	if not swatch then
		return
	end

	if swatch.SetEnabled then
		swatch:SetEnabled(enabled)
	end

	swatch:SetAlpha(enabled and 1 or 0.5)
	if swatch.Label then
		swatch.Label:SetAlpha(enabled and 1 or 0.5)
	end
	if swatch.ColorTexture then
		swatch.ColorTexture:SetAlpha(enabled and 1 or 0.5)
	end
end

function PvPTogether:RefreshOptionsWindow()
	local controls = self.optionControls or {}
	local enabled = self:GetOption("enabled") == true

	if controls.enabled then
		controls.enabled:SetChecked(enabled)
	end

	local partyStyleLabel, partySelectedValue = GetStyleDropdownLabel("partyMemberStyle")
	local friendlyStyleLabel, friendlySelectedValue = GetStyleDropdownLabel("friendlyPlayerStyle")
	local enemyStyleLabel, enemySelectedValue = GetStyleDropdownLabel("enemyPlayerStyle")
	local partyBorderEnabled = self:GetOption("partyMemberBorderEnabled") == true
	local friendlyBorderEnabled = self:GetOption("friendlyPlayerBorderEnabled") == true
	local enemyBorderEnabled = self:GetOption("enemyPlayerBorderEnabled") == true

	RefreshDropdownControl(controls.partyMemberStyle, partyStyleLabel, partySelectedValue)
	RefreshDropdownControl(controls.friendlyPlayerStyle, friendlyStyleLabel, friendlySelectedValue)
	RefreshDropdownControl(controls.enemyPlayerStyle, enemyStyleLabel, enemySelectedValue)

	SetDropdownEnabled(controls.partyMemberStyle, enabled)
	SetDropdownEnabled(controls.friendlyPlayerStyle, enabled)
	SetDropdownEnabled(controls.enemyPlayerStyle, enabled)

	if controls.partyMemberBorderEnabled then
		controls.partyMemberBorderEnabled:SetChecked(partyBorderEnabled)
		controls.partyMemberBorderEnabled:SetEnabled(enabled)
		if controls.partyMemberBorderEnabled.Label then
			controls.partyMemberBorderEnabled.Label:SetAlpha(enabled and 1 or 0.5)
		end
	end
	if controls.friendlyPlayerBorderEnabled then
		controls.friendlyPlayerBorderEnabled:SetChecked(friendlyBorderEnabled)
		controls.friendlyPlayerBorderEnabled:SetEnabled(enabled)
		if controls.friendlyPlayerBorderEnabled.Label then
			controls.friendlyPlayerBorderEnabled.Label:SetAlpha(enabled and 1 or 0.5)
		end
	end
	if controls.enemyPlayerBorderEnabled then
		controls.enemyPlayerBorderEnabled:SetChecked(enemyBorderEnabled)
		controls.enemyPlayerBorderEnabled:SetEnabled(enabled)
		if controls.enemyPlayerBorderEnabled.Label then
			controls.enemyPlayerBorderEnabled.Label:SetAlpha(enabled and 1 or 0.5)
		end
	end

	RefreshColorSwatch(
		controls.partyMemberBorderColor,
		"partyMemberBorderColor",
		self.DEFAULTS.partyMemberBorderColor
	)
	RefreshColorSwatch(
		controls.friendlyPlayerBorderColor,
		"friendlyPlayerBorderColor",
		self.DEFAULTS.friendlyPlayerBorderColor
	)
	RefreshColorSwatch(
		controls.enemyPlayerBorderColor,
		"enemyPlayerBorderColor",
		self.DEFAULTS.enemyPlayerBorderColor
	)

	SetColorSwatchEnabled(controls.partyMemberBorderColor, enabled and partyBorderEnabled)
	SetColorSwatchEnabled(controls.friendlyPlayerBorderColor, enabled and friendlyBorderEnabled)
	SetColorSwatchEnabled(controls.enemyPlayerBorderColor, enabled and enemyBorderEnabled)
end

function PvPTogether:OpenOptionsWindow()
	if not self.optionsFrame then
		self:InitializeOptionsWindow()
	end

	if not (Settings and Settings.OpenToCategory and self.optionsCategory and self.optionsCategory.GetID) then
		return false
	end

	Settings.OpenToCategory(self.optionsCategory:GetID())
	return true
end

function PvPTogether:InitializeOptionsWindow()
	if self.optionsFrame then
		return
	end

	if type(UIDropDownMenu_Initialize) ~= "function" and type(UIParentLoadAddOn) == "function" then
		pcall(UIParentLoadAddOn, "Blizzard_UIDropDownMenu")
	end

	local frame = CreateFrame("Frame", "PvPTogetherOptionsPanel")
	frame.name = "PvPTogether"

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
	title:SetText("PvPTogether")

	local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetText("Per-unit-type Blizzard nameplate style overrides.")

	local sectionTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	sectionTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -74)
	sectionTitle:SetText("Style by Unit Type")

	local sectionHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sectionHelp:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -8)
	sectionHelp:SetText("Choose from Blizzard's built-in nameplate styles for player unit types.")

	local partyMemberStyle = CreateStyleDropdown(
		frame,
		"Party Members",
		"Style used for party or raid member nameplates.",
		16,
		-120,
		"partyMemberStyle"
	)
	local partyMemberBorderEnabled = CreateCheckbox(
		frame,
		"partyMemberBorderEnabled",
		"Border Override",
		"Enable a custom border tint for party or raid member nameplates.",
		36,
		-188
	)
	local partyMemberBorderColor = CreateColorSwatch(
		frame,
		"partyMemberBorderColor",
		"Color",
		"Border tint color for party or raid member nameplates.",
		self.DEFAULTS.partyMemberBorderColor,
		320,
		-188
	)

	local friendlyPlayerStyle = CreateStyleDropdown(
		frame,
		"Friendly Players",
		"Style used for friendly player nameplates that are not in your party or raid.",
		16,
		-244,
		"friendlyPlayerStyle"
	)
	local friendlyPlayerBorderEnabled = CreateCheckbox(
		frame,
		"friendlyPlayerBorderEnabled",
		"Border Override",
		"Enable a custom border tint for non-group friendly player nameplates.",
		36,
		-312
	)
	local friendlyPlayerBorderColor = CreateColorSwatch(
		frame,
		"friendlyPlayerBorderColor",
		"Color",
		"Border tint color for non-group friendly player nameplates.",
		self.DEFAULTS.friendlyPlayerBorderColor,
		320,
		-312
	)

	local enemyPlayerStyle = CreateStyleDropdown(
		frame,
		"Enemy Players",
		"Style used for enemy player nameplates.",
		16,
		-368,
		"enemyPlayerStyle"
	)
	local enemyPlayerBorderEnabled = CreateCheckbox(
		frame,
		"enemyPlayerBorderEnabled",
		"Border Override",
		"Enable a custom border tint for enemy player nameplates.",
		36,
		-436
	)
	local enemyPlayerBorderColor = CreateColorSwatch(
		frame,
		"enemyPlayerBorderColor",
		"Color",
		"Border tint color for enemy player nameplates.",
		self.DEFAULTS.enemyPlayerBorderColor,
		320,
		-436
	)

	if not partyMemberStyle or not friendlyPlayerStyle or not enemyPlayerStyle then
		local missingDropdownWarning = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		missingDropdownWarning:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -170)
		missingDropdownWarning:SetWidth(680)
		missingDropdownWarning:SetJustifyH("LEFT")
		missingDropdownWarning:SetText("Dropdown UI is unavailable on this client build; style selectors could not be created.")
	end

	local warningText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	warningText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -488)
	warningText:SetWidth(680)
	warningText:SetJustifyH("LEFT")
	warningText:SetText("Changes are deferred until combat ends when needed to avoid taint-sensitive updates.")

	self.optionControls = {
		partyMemberStyle = partyMemberStyle,
		friendlyPlayerStyle = friendlyPlayerStyle,
		enemyPlayerStyle = enemyPlayerStyle,
		partyMemberBorderEnabled = partyMemberBorderEnabled,
		partyMemberBorderColor = partyMemberBorderColor,
		friendlyPlayerBorderEnabled = friendlyPlayerBorderEnabled,
		friendlyPlayerBorderColor = friendlyPlayerBorderColor,
		enemyPlayerBorderEnabled = enemyPlayerBorderEnabled,
		enemyPlayerBorderColor = enemyPlayerBorderColor,
	}

	frame:SetScript("OnShow", function()
		PvPTogether:RefreshOptionsWindow()
	end)

	self.optionsFrame = frame

	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
		self:Print("Settings API is unavailable; options could not be registered.")
		self.optionsCategory = nil
		return
	end

	local category = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name)
	Settings.RegisterAddOnCategory(category)
	self.optionsCategory = category
	self:RefreshOptionsWindow()
end
