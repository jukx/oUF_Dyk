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
--  - fix bug: dyke.. registered event handler doesnt exist
--  - maybe: buffs
--  - maybe: loss of control timer?
--
--]]

--get addon data
local addonName, addon = ...
local helpers = addon.helpers

--
-- Config
--

-- Coordinates for spawning
local coordMainHealthX = -90
local coordMainHealthY = -120
local coordTargetCastBarY = 200

-- Media
local defaultBartex = [[Interface\AddOns\ouf_dyke\textures\statusbar]]
local defaultBordertex =  [[Interface\AddOns\ouf_dyke\textures\border]]
local innerShadowTexture =  [[Interface\AddOns\ouf_dyke\textures\inner_shadow]]
local defaultFont = [[Interface\AddOns\ouf_dyke\fonts\roboto-medium.ttf]]

-- Measures
local frameSize = {200, 60}
local padding = 7  -- between frames
local outlineWidth = 1

local powerBarWidth = 240
local powerBarHeight = 10 
local castbarHeight = 30
local castbarWidth = 300
local defaultClassPowerBarHeight = 15

local defaultPowerBarFontSize = 14

-- Colors
local defaultBarColor = {26, 25, 23}
local dykeColors = {
    power = {
        ["MANA"] = { r = 36/255, g = 110/255, b = 229/255 };
    }
}
local defaultInfoBorderColor = {100, 100, 100}
local defaultBorderColor = {0, 0, 0}
local defaultAggroInfoBorderColor = {255, 0, 0}
local defaultTargetBarBgColor = {128, 128, 128}
local defaultFallbackTargetBarBgColor = {0, 255, 0}
local defaultTargetBarBgAlpha = 0.8
local defaultPowerBarTintMultiplier = 0.8 
local defaultPowerBarBgColor = {0, 0, 0, 0.5}
local defaultBaseClassPowerColor = {255, 255, 255}  -- it's being colored by class color by oUF
local defaultClassPowerBarBgColor = {0, 0, 0, 0.5}
local defaultCastBarColor = {184, 150, 0}
local defaultCastBarBgColor = {0, 0, 0, 0.5}
local defaultHealthBarBgGradientColor1 = {255, 0, 0}
local defaultHealthBarBgGradientColor2 = {226, 209, 124}
local defaultHealthBarBgAlpha = 0.8

-- End config

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

local function getColor(color)
    newColor = {}
    for i=1,3 do
        newColor[i] = color[i]/255 
    end
    if color[4] then newColor[4] = color[4] end  -- alpha channel

    return newColor
end

local function addBorder(frame, thickness, color, texture)
    if not color then color = getColor(defaultBorderColor) end

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
    border2 = addBorder(border1, 1, borderColor or getColor(defaultInfoBorderColor)) 
    border3 = addBorder(border2, 1)
    frame.InfoBorder = border2
    frame.setInfoBorderColor = function(self, color)
        if not color then color = getColor(defaultInfoBorderColor) end
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
    if UnitDetailedThreatSituation("player", frame.unit) then
        frame:setInfoBorderColor(getColor(defaultAggroInfoBorderColor))
    end
end

local function CreateStatusBar(self, color, bgColor, borderColor, drawShadow, shadowWidth)
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
        color = getColor(defaultTargetBarBgColor)
    end 

    if not color then
        color = getColor(defaultFallbackTargetBarBgColor)
    end
    
    color[4] = defaultTargetBarBgAlpha

    return color
end

local function getPowerBarColor(unit)
    local powerToken
    local color = {}
    _, powerToken = UnitPowerType(unit);
    powerToken = powerToken or 'MANA' 
    local color_ = dykeColors.power[powerToken] or PowerBarColor[powerToken]

    -- change color table from keyed by letter to keyed by index
    if color_ then
        for i, key in pairs({'r', 'g', 'b'}) do 
            color[i] = color_[key] * defaultPowerBarTintMultiplier
        end
    else
        print("Error:")
        print("Target:", unit)
        print("Power:", powerToken)
    end

    return color
end

--
-- Creation Functions
--

-- Create health statusbar func
local function CreateHealthBar(frame, unit, height) 
    local barColor = getColor(defaultBarColor)
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

    local power = CreateStatusBar(frame, color, getColor(defaultPowerBarBgColor), nil, true, 4)
    power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -outlineWidth)
    power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    power.UpdateColor = updatePowerColor

    return power
end

-- Create Power Text
local function CreatePowerText(frame)
    local text = createText(frame.Power, nil, defaultPowerBarFontSize)

    text:SetPoint("CENTER", frame.Power, "CENTER")
    frame:Tag(text, '[perpp<%]')
end

local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Create class power statusbar
local function CreateClassPower(frame, maxClasspower)
		local classPower = {} 
        local maxClasspower = maxClasspower or 5  -- make ClassPowerBar 1/5 the width of the Power Bar... is this correct for something else than rogues/locks?  
        local singletonWidth = math.floor((powerBarWidth - (maxClasspower - 1)) / maxClasspower)

		for index = 1, maxClasspower do -- have to create an extra to force __max to be different from UnitPowerMax
            local bar = CreateStatusBar(frame, getColor(defaultBaseClassPowerColor), getColor(defaultClassPowerBarBgColor))

            bar:SetSize(singletonWidth, defaultClassPowerBarHeight)

            bar:SetPoint('BOTTOMLEFT', frame.Power, 'TOPLEFT', (index - 1) * (singletonWidth + 1), 1)
            if index == maxClasspower then
                bar:SetPoint('TOPRIGHT', frame.Power, 'TOPRIGHT', 0, defaultClassPowerBarHeight + 1)
			end

			classPower[index] = bar
		end

        return classPower
end

-- Create cast bar
local function CreateCastBar(frame)
    local castbar = CreateStatusBar(frame, getColor(defaultCastBarColor), getColor(defaultCastBarBgColor), nil, true, 8)

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

local function updateHealthColor(self, unit, cur, max) 
    local bgColor

    if unit == 'player' then
        local perc = cur / max
        local c1 = getColor(defaultHealthBarBgGradientColor1)
        local c2 = getColor(defaultHealthBarBgGradientColor2)
        bgColor = helpers.addVec(helpers.multVec(c2, perc), helpers.multVec(c1, 1 - perc))  -- TODO describe what this does 
    elseif unit == 'target' then
        bgColor = getBarBgColor(unit)
    end

    bgColor[4] = defaultHealthBarBgAlpha
    self.bg:SetColorTexture(unpack(bgColor))
end

local function updatePowerColor(self, unit) 
    local color = getPowerBarColor(unit)
    self:SetStatusBarColor(unpack(color))
end 

local function updatePowerBarVisibility(frame) 
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

local function updateTargetPowerBarInfoborderColor(frame)
    local unit = 'target'
    local color

    if UnitPlayerControlled(unit) then
        local _, class = UnitClass(unit) 
        color = oUF.colors.class[class] 
    else
        reaction = UnitReaction(unit, 'player')
        color = oUF.colors.reaction[reaction] 
    end 

    frame:setInfoBorderColor(color)
end

--
-- Event handlers
--

local function threatHandler(frame)
    setInfoBorderColorByThreat(frame)
end

local function targetPowerBarHandler(frame)
    updatePowerBarVisibility(frame)
    updateTargetPowerBarInfoborderColor(frame)
    setInfoBorderColorByThreat(frame)
end

-- Create Style
local function StyleFunc(frame, unit) 
    frame:SetSize(unpack(frameSize))
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

        if(select(2, UnitClass('player')) == 'DEATHKNIGHT') then
            frame.Runes = CreateClassPower(frame, 6)
            frame.Runes.colorSpec = true
        end 

        --frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", playerThreatHandler)
        --frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE", playerThreatHandler) 
        --frame:RegisterEvent("PLAYER_LEAVE_COMBAT", playerThreatHandler) 
    elseif unit == 'target' then
        frame.Health = CreateHealthBar(frame, unit)
        frame.Power = CreatePowerBar(frame, unit)
        frame.Castbar = CreateCastBar(frame)
        frame.Castbar:SetPoint("TOPLEFT", nil, "CENTER", -castbarWidth/2, coordTargetCastBarY + castbarHeight)
        frame.Castbar:SetPoint("BOTTOMRIGHT", nil, "CENTER", castbarWidth/2, coordTargetCastBarY)
        frame.CastbarText = CreateCastBarText(frame)

        frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", threatHandler)
        frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE", threatHandler) 
		frame:RegisterEvent('PLAYER_TARGET_CHANGED', threatHandler)
        frame:RegisterEvent('UNIT_TARGET')
        frame:HookScript("OnEvent", targetPowerBarHandler)
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
