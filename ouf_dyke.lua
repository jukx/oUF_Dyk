--[[
--
-- oUF Dyke (working title)
--
-- TODO:
--  - test all classes
--  - make rune power and balance druid resources work
--  - flesh out castbar (latency, other place/size...)
--  - use infoborder for something
--  - party frames
--  - nameplates
--  - maybe: buffs
--  - refactor a bit, remove magic numbers
--  - target castbar
--  - target health bg color by reaction
--
--  A note about color values:
--    Throughout this addon, color values are used as (unkeyed!) tables {r, g, b[, a]}.
--    When they are explicitly declared, they are written in the rgb-255 form,
--    but changed to Blizzard's rgb-1 form through normalizeColors() (right before being passed to API functions.
--    TODO: refactor this
--]]

--get addon data
local addonName, addon = ...
local helpers = addon.helpers

-- config
-- coordinates for spawning
local coordMainHealthX = -90
local coordMainHealthY = -120

local defaultBartex = [[Interface\AddOns\ouf_dyke\textures\statusbar]]
local defaultBordertex =  [[Interface\AddOns\ouf_dyke\textures\border]]
local innerShadowTexture =  [[Interface\AddOns\ouf_dyke\textures\inner_shadow]]
local defaultFont = [[Interface\AddOns\ouf_dyke\fonts\roboto-medium.ttf]]

local padding = 7
local outlineWidth = 1
local powerBarWidth = 240
local powerBarHeight = 10 
local castbarHeight = 30
local castbarWidth = 300

local defaultBarColor = {36, 35, 33}
local dykeColors = {
    power = {
        ["MANA"] = { r = 36/255, g = 110/255, b = 229/255 };
    }
}
-- end config

--
-- Custom oUF Tags
--
local function getStatus(unit)
	if(not UnitIsConnected(unit)) then
		return 'Offline'
	elseif(UnitIsGhost(unit)) then
		return 'Ghost'
	elseif(UnitIsDead(unit)) then
		return 'Dead'
	end
end

local function condenseNumber(value)
	if value >= 1e9 then
		return format('%.2fb', value / 1e9)
	elseif value >= 1e6 then
		return format('%.2fm', value / 1e6)
    elseif value >= 1e4 then
		return format('%.1fk', value / 1e3)
	else
		return value
	end
end

local function registerTag(tagname, events, func)
    oUF.Tags.Methods[tagname] = func
    oUF.Tags.Events[tagname] = events
end

registerTag('dyke:status',  
            'UNIT_HEALTH PLAYER_UPDATE_RESTING UNIT_CONNECTION',
            function(unit)
                return getStatus(unit)
            end
    )

registerTag('dyke:perhp',  
            'UNIT_HEALTH_FREQUENT UNIT_MAXHEALTH',
            function(unit)
                local curhp = UnitHealth(unit)
                local maxhp = UnitHealthMax(unit)
                if unit == 'player' and (getStatus(unit) or curhp == maxhp) then return end
                local perc = 100 * curhp / maxhp
                return  format("%.0f%%", helpers.round(perc))
            end
    )

registerTag('dyke:maxhp',  
            'UNIT_HEALTH_FREQUENT UNIT_MAXHEALTH',
            function(unit)
                if getStatus(unit) then return end
                local maxhp = UnitHealthMax(unit)
                if UnitHealth(unit) ~= maxhp then
                    return condenseNumber(maxhp)
                end
            end
    )

registerTag('dyke:curhp',  
            'UNIT_HEALTH_FREQUENT UNIT_MAXHEALTH',
            function(unit)
                local curhp = UnitHealth(unit)
                local maxhp = UnitHealthMax(unit)
                if unit == 'player' and (getStatus(unit) or curhp == maxhp) then return end
                return condenseNumber(curhp)
            end
    )


--
-- Functions
--

-- Style functions

local function normalizeColors(tuple)
    for i=1,3 do
        tuple[i] = tuple[i]/255 
    end

    return tuple
end

local function addBorder(frame, thickness, color, texture)
    if color then color = normalizeColors(color) else color = {0, 0, 0} end
    local border = CreateFrame("Frame", nil, frame)
    local backdrop = {
        edgeFile = texture or defaultBordertex,
        edgeSize = thickness,
        insets = { left=thickness, right=thickness, top=thickness, bottom=thickness }
    }

    local framelevel = math.max(0, (frame:GetFrameLevel()-1 or 0))
    border:SetFrameLevel(framelevel)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -thickness, thickness)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", thickness, -thickness)
    border:SetBackdrop(backdrop)
    border:SetBackdropBorderColor(unpack(color))

    return border
end

local function addMainBorder(frame, borderColor)
    border1 = addBorder(frame, 1)
    border2 = addBorder(border1, 1, borderColor or {100, 100, 100}) 
    border3 = addBorder(border2, 1)
    frame.InfoBorder = border2
    frame.setInfoBorderColor = function(self, color)
        if color then color = normalizeColors(color) else color = {0, 0, 0} end
        self.InfoBorder:SetBackdropBorderColor(unpack(color))
    end
end

local function addInnerShadow(frame, width)
    local shadow = CreateFrame("Frame", nil, frame)
    local backdrop = {
        edgeFile = innerShadowTexture,
        edgeSize = width or 16,
    }

    shadow:SetPoint("TOPLEFT", frame, "TOPLEFT")
    shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    shadow:SetBackdrop(backdrop)

    return shadow
end

local function setInfoBorderColorByThreat(frame) 
    if(UnitDetailedThreatSituation("player", frame.unit)) then
        frame:setInfoBorderColor({255, 0, 0})
    else
        frame:setInfoBorderColor({100, 100, 100})
    end
end

local function CreateStatusBar(self, color, bgColor, borderColor, drawShadow, shadowWidth)
    -- color - rgb triple of values ranging from 0 - 255 
    if color then color = normalizeColors(color) end
    if bgColor then bgColor = normalizeColors(bgColor) end
        
    if not bartex then
        bartex = defaultBartex
    end

    local bar = CreateFrame("StatusBar", nil, self)      
    bar:SetStatusBarTexture(bartex)
    bar:SetStatusBarColor(unpack(color))

    if bgColor then
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(unpack(bgColor))
        bg:SetAllPoints()
        bar.bg = bg 
    end

    addBorder(bar, outlineWidth)  -- add outline to any statusbar

    if drawShadow then
        addInnerShadow(bar, shadowWidth)
    end

    return bar
end

-- Create Text
local function createText(frame,font,size,align,outline)
    textframe = CreateFrame("Frame", nil, frame)
    textframe:SetAllPoints()
    local text = textframe:CreateFontString(nil, "ARTWORK") --"BORDER", "OVERLAY"

    if outline then
        outline = "THICKOUTLINE"
    else
        outline = nil
    end
    text:SetFont(font or defaultFont, size or 14, outline)
    text:SetJustifyH(align or "LEFT")
    return text
end

local function getBarBgColor(unit)
    local color
    if UnitPlayerControlled(unit) then
        local _, class = UnitClass(unit) 
        color = oUF.colors.class[class] 
    else
        color = {0.5, 0.5, 0.5}
    end 

    if color then
        color = helpers.multVec(color, 255)
    else
        color = {0, 255, 0}
    end
    color[4] = 0.8

    return color
end

local function getPowerBarColor(unit)
    local powerToken
    local color = {}
    _, powerToken = UnitPowerType(unit);
    powerToken = powerToken or 'MANA' 
    local color_ = dykeColors.power[powerToken] or PowerBarColor[powerToken]

    -- change color table from keyed by letter to keyed by index
    for i, key in pairs({'r', 'g', 'b'}) do 
        color[i] = color_[key] * 255 
        color[i] = color_[key] * 0.8 
    end

    return color
end

--
-- Creation Functions
--

-- Create health statusbar func
local function CreateHealthBar(frame, unit, height) 
    local barColor = helpers.table_clone(defaultBarColor)
    local bgColor = getBarBgColor(unit)
    local health = CreateStatusBar(frame, barColor, bgColor, nil, true)
    health:SetAllPoints()
    if height then
        health:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', 0, -height)
    end
    health.UpdateColor = updateHealthColor
    return health 
end

-- Create Health Text
local function CreateHealthText(frame)
    local text = createText(frame.Health, nil, nil)

    text:SetPoint("CENTER", frame.Health, "CENTER")
    frame:Tag(text, '[dyke:status][dyke:curhp][ >dyke:perhp]')
end

-- Create Health Text
local function CreateNameText(frame)
    local text = createText(frame.Health, nil, nil)

    text:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", 2, -2)
    frame:Tag(text, '[name]')
end

--create power statusbar func
local function CreatePowerBar(frame, unit)
    local color = getPowerBarColor(unit)

    local power = CreateStatusBar(frame, color, {0, 0, 0, 0.5}, nil, true, 4)
    power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -outlineWidth)
    power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    power.UpdateColor = updatePowerColor

    return power
end

-- Create Power Text
local function CreatePowerText(frame)
    local text = createText(frame.Power, nil, 14)

    text:SetPoint("CENTER", frame.Power, "CENTER")
    frame:Tag(text, '[perpp<%]')
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Create class power statusbar
local function CreateClassPower(frame)
		ClassPower = {}
        --ClassPower.UpdateColor = function() end

		for index = 1, 11 do -- have to create an extra to force __max to be different from UnitPowerMax
            local bar = CreateStatusBar(frame, {255, 255, 255}, {0, 0, 0, 0.5})

            singletonWidth = (frame.Power:GetWidth() - 4) / 5  -- make ClassPowerBar 1/5 the width of the Power Bar... is this correct for something else than rogues/locks?
            bar:SetHeight(15)
            bar:SetWidth(singletonWidth)

			if(index > 1) then
				bar:SetPoint('LEFT', ClassPower[index - 1], 'RIGHT', 1, 0)
			else
				bar:SetPoint('BOTTOMLEFT', frame.Power, 'TOPLEFT', 0, 1)
			end

			if(index > 5) then
				bar:SetFrameLevel(bar:GetFrameLevel() + 1)
			end

			ClassPower[index] = bar
		end
        return ClassPower
end

-- Create cast bar
local function CreateCastBar(frame)
    local castbar = CreateStatusBar(frame, {184, 150, 0}, {0, 0, 0, 0.5}, nil, true, 8)

    return castbar
end

local function CreateCastBarText(frame)
    local text = createText(frame.Castbar)

    text:SetPoint("CENTER", frame.Castbar, "CENTER")
    frame.Castbar.Text = text
end


--
-- Update functions
--

function updateHealthColor (self, unit, cur, max) 
    local bgColor
    if unit == 'player' then
        local perc = cur / max
        local c1 = {255, 0, 0}
        local c2 = {226, 209, 124}
        bgColor = helpers.addVec(helpers.multVec(c2, perc), helpers.multVec(c1, 1 - perc))  -- TODO describe what this does 
    elseif unit == 'target' then
        bgColor = getBarBgColor(unit)
    end

    bgColor[4] = 0.8
    bgColor = normalizeColors(bgColor)
    self.bg:SetColorTexture(unpack(bgColor))
end

function updatePowerColor(self, unit) 
    local color = getPowerBarColor(unit)
    self:SetStatusBarColor(unpack(color))
end 

function updatePowerBarVisibility(frame) 
    local unit = 'target'
    if UnitPlayerControlled(unit) or UnitPowerType(unit) ~= 1 then
        local ycoord = frame:GetHeight() - (powerBarHeight + outlineWidth)
        frame.Health:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', 0, -ycoord)
        frame.Power:Show()
    else
        frame.Health:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT')
        frame.Power:Hide()
    end
end

--
-- Event handlers
--

local function threatHandler(frame)
    setInfoBorderColorByThreat(frame)
end

local function powerBarHandler(frame)
    updatePowerBarVisibility(frame)
end

-- Create Style
local function StyleFunc(frame, unit) 
    frame:SetSize(200,60) 
	frame:RegisterForClicks('AnyUp')  -- to enable rightclick menu
    addMainBorder(frame) 

    if unit == 'player' then
        frame.Health = CreateHealthBar(frame, unit)
        frame.Power = CreatePowerBar(frame, unit)
        frame.Power:SetPoint("TOPLEFT", nil, "CENTER", -powerBarWidth/2, coordMainHealthY + padding + powerBarHeight)
        frame.Power:SetPoint("BOTTOMRIGHT", nil, "CENTER", powerBarWidth/2, coordMainHealthY + padding)
        frame.PowerText = CreatePowerText(frame)
        frame.ClassPower = CreateClassPower(frame)
        frame.Castbar = CreateCastBar(frame)
        frame.Castbar:SetPoint("TOPLEFT", nil, "CENTER", coordMainHealthX + padding, coordMainHealthY)
        frame.Castbar:SetPoint("BOTTOMRIGHT", nil, "CENTER", -coordMainHealthX - padding, coordMainHealthY - castbarHeight)
        frame.CastbarText = CreateCastBarText(frame)
    elseif unit == 'target' then
        frame.Health = CreateHealthBar(frame, unit)
        frame.Power = CreatePowerBar(frame, unit)
        frame.Castbar = CreateCastBar(frame)
        frame.Castbar:SetPoint("TOPLEFT", nil, "CENTER", -castbarWidth/2, 200 + castbarHeight)
        frame.Castbar:SetPoint("BOTTOMRIGHT", nil, "CENTER", castbarWidth/2, 200)
        frame.CastbarText = CreateCastBarText(frame)

        frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", threatHandler)
        frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE", threatHandler) 
		frame:RegisterEvent('PLAYER_TARGET_CHANGED', threatHandler)
        frame:RegisterEvent('UNIT_TARGET')
        frame:HookScript("OnEvent", powerBarHandler)
    end

    CreateHealthText(frame)
    CreateNameText(frame)
end

-- Register style with oUF
oUF:RegisterStyle(addonName.."style", StyleFunc)

-- Set up oUF factory
oUF:Factory(function(self)
    self:SetActiveStyle(addonName.."style") 
    self:Spawn("player", addonName.."PlayerFrame"):SetPoint("TOPRIGHT", nil, "CENTER", coordMainHealthX, coordMainHealthY) 
    self:Spawn("target", addonName.."TargetFrame"):SetPoint("TOPLEFT", nil, "CENTER", -coordMainHealthX, coordMainHealthY)
end)
