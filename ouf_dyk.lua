-- Get addon data
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
local defaultBartex = [[Interface\AddOns\ouf_dyk\textures\statusbar]]
local defaultBordertex =  [[Interface\AddOns\ouf_dyk\textures\border]]
local innerShadowTexture =  [[Interface\AddOns\ouf_dyk\textures\inner_shadow]]
local defaultFont = [[Interface\AddOns\ouf_dyk\fonts\roboto-medium.ttf]]

-- Measures
local defaultFrameSize = {200, 48}
local defaultFrameSizeParty = {160, 28}
local defaultFrameSizePet = {150, 20}
local defaultFrameSizeBoss = {180, 25}
local defaultFrameSizeTargetTarget = {120, 25}
local defaultNameplateFrameSize = {120, 18}
local padding = 7  -- between frames
local outlineWidth = 1

local powerBarWidth = 240
local powerBarHeight = 10
local castbarHeight = 30
local castbarWidth = 300
local defaultClassPowerBarHeight = 15
local defaultPartyPowerBarHeight = 4
local defaultAltPowerBarHeight = 20

local defaultPowerBarFontSize = 14
local defaultCastBarFontSize = 14
local defaultCastBarFontSizeSmall = 11
local defaultNameplateFontSize = 10

-- Colors
local defaultBarColor = {26, 25, 23}
local dykColors = {
    power = {
        ['MANA'] = { r = 36/255, g = 110/255, b = 229/255 },
    },
    reaction = {
    }
}

local defaultInfoBorderColor = {100, 100, 100}
local defaultBorderColor = {0, 0, 0}
local defaultAggroInfoBorderColor = {255, 0, 0}
local defaultTargetBarBgColor = {167, 167, 167}
local defaultFallbackTargetBarBgColor = {0, 255, 0}
local defaultPowerBarTintMultiplier = 0.8
local defaultPowerBarBgColor = {0, 0, 0, 0.5}
local defaultBaseClassPowerColor = {255, 255, 255}  -- it's being colored by class color by oUF
local defaultClassPowerBarBgColor = {0, 0, 0, 0.5}
local defaultCastBarColor = {184, 150, 0}
local defaultCastBarBgColor = {0, 0, 0, 0.5}
local defaultHealthBarBgGradientColor1 = {255, 0, 0, 1}
local defaultHealthBarBgGradientColor2 = {167, 167, 167, 0.4}
local defaultHealthBarBgAlpha = 0.4
local defaultEliteColor = {255, 215, 0}

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

local function getColor(color)
    local newColor = {}
    for i=1,3 do
        newColor[i] = color[i]/255
    end
    if color[4] then newColor[4] = color[4] end  -- alpha channel

    return newColor
end

local function registerTag(tagname, events, func)
    oUF.Tags.Methods[tagname] = func
    oUF.Tags.Events[tagname] = events
end

registerTag('dyk:status',
            'UNIT_HEALTH PLAYER_UPDATE_RESTING UNIT_CONNECTION',
            function(unit)
                return getStatus(unit)
            end
    )

registerTag('dyk:perhp',
            'UNIT_HEALTH_FREQUENT UNIT_MAXHEALTH',
            function(unit)
                if getStatus(unit) then return end
                local curhp = UnitHealth(unit)
                local maxhp = UnitHealthMax(unit)
                if unit == 'player' and (getStatus(unit) or curhp == maxhp) then return end
                local perc = 100 * curhp / maxhp
                return  format("%.0f%%", helpers.round(perc))
            end
    )

registerTag('dyk:maxhp',
            'UNIT_HEALTH_FREQUENT UNIT_MAXHEALTH',
            function(unit)
                if getStatus(unit) then return end
                local maxhp = UnitHealthMax(unit)
                if UnitHealth(unit) ~= maxhp then
                    return condenseNumber(maxhp)
                end
            end
    )

registerTag('dyk:curhp',
            'UNIT_HEALTH_FREQUENT UNIT_MAXHEALTH',
            function(unit)
                if getStatus(unit) then return end
                local curhp = UnitHealth(unit)
                local maxhp = UnitHealthMax(unit)
                if unit == 'player' and (getStatus(unit) or curhp == maxhp) then return end
                return condenseNumber(curhp)
            end
    )

registerTag('dyk:shortname',
            'UNIT_NAME_UPDATE',
            function(unit, r)
                local name = UnitName(r or unit)
                if #name > 8 then
                    name = name:sub(0, 7) .. '...'
                end
                return name
            end
    )

registerTag('dyk:elitecolor',
            'UNIT_NAME_UPDATE',
            function(unit)
                local class = UnitClassification(unit)
                if class == 'elite' then
                    return Hex(getColor(defaultEliteColor))
                end
            end
    )

--
-- Functions
--

-- Style functions

local function addBorder(frame, thickness, color, texture)
    color = color or getColor(defaultBorderColor)

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
    local border1 = addBorder(frame, 1)
    local border2 = addBorder(border1, 1, borderColor or getColor(defaultInfoBorderColor))
    addBorder(border2, 1)
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

local function getClassOrReactionColor(unit)
    local color
    if UnitPlayerControlled(unit) then
        local _, class = UnitClass(unit)
        color = oUF.colors.class[class]
    else
        local reaction = UnitReaction(unit, 'player')
        color = dykColors['reaction'][reaction] or oUF.colors.reaction[reaction]
        --color = oUF.colors.reaction[reaction]
    end

    return color
end

local function CreateStatusBar(args)
    local frame = args.frame
    local color = args.color
    local bgColor = args.bgColor
    local borderColor = args.borderColor
    local drawShadow = args.drawShadow
    local shadowWidth = args.shadowWidth
    local noBorders = args.noBorders
    local bartex = defaultBartex

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetStatusBarTexture(bartex)
    bar:SetStatusBarColor(unpack(color))

    if bgColor then
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(unpack(bgColor))
        bg:SetAllPoints()
        bar.bg = bg
    end

    if not noBorders then
        frame.BaseBorder = addBorder(bar, outlineWidth, borderColor)  -- add outline to any statusbar
    end

    if drawShadow then
        addInnerShadow(bar, shadowWidth)
    end

    return bar
end

-- Create Text
local function createText(args)
    local frame = args.frame
    local font = args.font
    local size = args.size
    local align = args.align
    local outline = args.outline
    local shadow = args.shadow

    local textframe = CreateFrame("Frame", nil, frame)
    textframe:SetAllPoints()

    local text = textframe:CreateFontString(nil, "ARTWORK") --"BORDER", "OVERLAY"
    text:SetFont(font or defaultFont, size or 14, outline)
    text:SetJustifyH(align or "LEFT")

    if shadow then
        text:SetShadowOffset(1,-1)
    end

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

    color[4] = defaultHealthBarBgAlpha

    return color
end

local function getPowerBarColor(unit)
    local color = {}
    local powerId, powerToken = UnitPowerType(unit);
    powerToken = powerToken or 'MANA'
    local color_ = dykColors.power[powerToken] or PowerBarColor[powerId]

    if not color_ then
        print("Error:")
        print("Target:", unit)
        print("Power:", powerToken)
        color_ = {r=1, b=1, g=1}
    end

    -- change color table from keyed by letter to keyed by index
    for i, key in pairs({'r', 'g', 'b'}) do
        color[i] = color_[key] * defaultPowerBarTintMultiplier
    end

    return color
end

local function createFloatingFrame(frame)
    local float = CreateFrame("StatusBar", nil, frame)
    float:SetFrameLevel(float:GetFrameLevel() + 2)

    return float
end

--
-- Creation Functions
--

-- Create health statusbar func
local function CreateHealthBar(frame, unit)
    local barColor = getColor(defaultBarColor)
    local bgColor = getBarBgColor(unit)

    local health
    if frame.unittype == 'nameplate' then
        health = CreateStatusBar{frame=frame, color=barColor, bgColor=bgColor, drawShadow=true, shadowWidth=4}
        health.frequentUpdates = true
    else
        health = CreateStatusBar{frame=frame, color=barColor, bgColor=bgColor, drawShadow=true}
    end

    health:SetAllPoints()

    return health
end

local function createHealthPrediction(frame)
    -- Position and size
    local myBar = CreateStatusBar{frame=frame.Health, color=getColor{100, 255, 0, 0.6}, bgColor={0, 0, 0, 0}, borderColor={0, 0, 0, 0}}
    myBar:SetPoint('TOP')
    myBar:SetPoint('BOTTOM')
    myBar:SetPoint('LEFT', frame.Health:GetStatusBarTexture(), 'RIGHT')
    myBar:SetWidth(200)

    local otherBar = CreateStatusBar{frame=frame.Health, color=getColor{100, 255, 0, 0.6}, bgColor={0, 0, 0, 0}, borderColor={0, 0, 0, 0}}
    otherBar:SetPoint('TOP')
    otherBar:SetPoint('BOTTOM')
    otherBar:SetPoint('LEFT', myBar:GetStatusBarTexture(), 'RIGHT')
    otherBar:SetWidth(200)

    local absorbBar = CreateStatusBar{frame=frame.Health, color=getColor{255, 255, 255, 0.5}, bgColor={0, 0, 0, 0}, borderColor={0, 0, 0, 0}}
    absorbBar:SetPoint('TOP')
    absorbBar:SetPoint('BOTTOM')
    absorbBar:SetPoint('LEFT', otherBar:GetStatusBarTexture(), 'RIGHT')
    absorbBar:SetWidth(200)

    local healAbsorbBar = CreateFrame('StatusBar', nil, frame.Health)
    healAbsorbBar:SetPoint('TOP')
    healAbsorbBar:SetPoint('BOTTOM')
    healAbsorbBar:SetPoint('RIGHT', frame.Health:GetStatusBarTexture())
    healAbsorbBar:SetWidth(200)
    healAbsorbBar:SetReverseFill(true)

    local overAbsorb = CreateStatusBar{frame=frame.InfoBorder, color=getColor{255, 255, 255, 0.8}, bgColor={0, 0, 0, 0}, borderColor={0, 0, 0, 0}}
    overAbsorb:SetPoint('TOPLEFT', frame.InfoBorder, 'TOPRIGHT', -1, 0)
    overAbsorb:SetPoint('BOTTOMRIGHT', frame.InfoBorder)

    -- Register with oUF
    frame.HealthPrediction = {
        myBar = myBar,
        otherBar = otherBar,
        absorbBar = absorbBar,
        healAbsorbBar = healAbsorbBar,
        overAbsorb = overAbsorb,
        maxOverflow = 1.1,
    }
end

local function CreateHealthText(args)
    local frame = args.frame
    local anchor = args.anchor or {"CENTER", frame, "CENTER", 0, -2}
    local tag = args.tag or '[dyk:status][dyk:curhp][ >dyk:perhp]'
    local classColor = args.classColor
    args.frame = frame.Health

    local text = createText(args)
    text:SetPoint(unpack(anchor))

    if classColor then
        tag = "[raidcolor]" .. tag
    end
    frame:Tag(text, tag)

    return text
end

local function CreateNameText(args)
    local frame = args.frame
    local anchor = args.anchor or {"TOP", frame.Health, "TOP", 0, -2}
    local tag = args.tag or '[name]'
    local classColor = args.classColor
    args.frame = frame.Health

    local text = createText(args)
    text:SetPoint(unpack(anchor))

    if classColor then
        tag = "[raidcolor]" .. tag
    end
    frame:Tag(text, tag)

    return text
end

local function CreatePowerBar(frame, unit)
    local power = CreateStatusBar{frame=frame, color=getPowerBarColor(unit), bgColor=getColor(defaultPowerBarBgColor), drawShadow=true, shadowWidth=4}
    power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -outlineWidth)
    power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

    return power
end

-- Create Power Text
local function CreatePowerText(frame)
    local text = createText{frame=frame.Power, size=defaultPowerBarFontSize, shadow=true}

    text:SetPoint("CENTER", frame.Power, "CENTER")
    frame:Tag(text, '[perpp<%]')
end

-- Create class power statusbar
local function CreateClassPower(frame, maxClasspower)
    local classPower = {}
    maxClasspower = maxClasspower or 5  -- make ClassPowerBar 1/5 the width of the Power Bar... is this correct for something else than rogues/locks?
    local singletonWidth = math.floor((powerBarWidth - (maxClasspower - 1)) / maxClasspower)

    for index = 1, maxClasspower do -- have to create an extra to force __max to be different from UnitPowerMax
        local bar = CreateStatusBar{frame=frame, color=getColor(defaultBaseClassPowerColor), bgColor=getColor(defaultClassPowerBarBgColor), drawShadow=true, shadowWidth=2}

        bar:SetSize(singletonWidth, defaultClassPowerBarHeight)

        bar:SetPoint('BOTTOMLEFT', frame.Power, 'TOPLEFT', (index - 1) * (singletonWidth + 1), 1)
        if index == maxClasspower then
            bar:SetPoint('TOPRIGHT', frame.Power, 'TOPRIGHT', 0, defaultClassPowerBarHeight + 1)
        end

        classPower[index] = bar
    end

    return classPower
end

local function CreateAdditionalPowerBar(frame)
    local power = CreateStatusBar{frame=frame, color={1, 1, 1}, bgColor=getColor(defaultPowerBarBgColor), drawShadow=true, shadowWidth=1}
    power:SetPoint("TOPLEFT", frame.Power, "TOPLEFT", 0, 1)
    power:SetPoint("BOTTOMRIGHT", frame.Power, "TOPRIGHT", 0, 3)

    return power
end

local function CreateAlternativePowerBar(frame)
    local power = CreateStatusBar{frame=frame, color={1, 0.7, 0}, bgColor=getColor(defaultPowerBarBgColor), drawShadow=true, shadowWidth=4}

    return power
end

-- Create cast bar
local function CreateCastBar(frame, unit, drawShadow, noBorders)
    drawShadow = drawShadow or true
    local castbar = CreateStatusBar{frame=frame, color=getColor(defaultCastBarColor), bgColor=getColor(defaultCastBarBgColor), drawShadow=drawShadow or true,
                                    shadowWidth=8, noBorders=noBorders or false}

    if unit == 'player' then
        local SafeZone = castbar:CreateTexture(nil, 'OVERLAY')
        castbar.SafeZone = SafeZone
    elseif unit == 'target' then
        local shield = addBorder(castbar, 5, getColor({150, 150, 150}))
        castbar.Shield = shield
    end

    return castbar
end

local function CreateCastBarText(frame, size)
    local text = createText{frame=frame.Castbar, size=size}

    text:SetPoint("CENTER", frame.Castbar, "CENTER")

    return text
end

local function createInfoBorderIndicator(frame)
    local indicatorFrame = CreateFrame("Frame", nil, frame)

    return indicatorFrame
end

local function CreateBuffs(args)
    local frame = args.frame
    local buffsize = args.buffsize
    local disableMouse = args.disableMouse
    local anchor2 = args.anchor

    local Buffs = CreateFrame("Frame", nil, frame)

    buffsize = buffsize or 20
    buffspacing = 1
    if anchor2 == 'RIGHT' then
        Buffs:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 1)
        Buffs:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT",  2 + 8*buffsize + 7*buffspacing, 1 -2*buffsize - buffspacing)
    else
        Buffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -3, -4)
        Buffs:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT",  -3 + 8*buffsize + 7*buffspacing, -4 - 2*buffsize - buffspacing)
    end
    Buffs.disableMouse = disableMouse
    Buffs.size = buffsize
    Buffs.spacing = buffspacing
    Buffs['growth-y'] = 'DOWN'
    Buffs.initialAnchor = 'TOPLEFT'

    return Buffs
end

local function CreateStaggerBar(frame)
    local stagger = CreateStatusBar{frame=frame, color={1, 1, 1}, bgColor={1, 1, 1, 0.3}, drawShadow=true, shadowWidth=2}
    stagger:SetPoint('BOTTOMLEFT', frame.Power, 'TOPLEFT', 0, 1)
    stagger:SetPoint('TOPRIGHT', frame.Power, 'TOPRIGHT', 0, 1 + 15)

    return stagger
end


--
-- Update functions
--

local function updateHealthColor(self, unit, cur, max)
    local bgColor

    if unit == 'player' then
        if UnitIsDeadOrGhost(unit) then
            bgColor = getColor(defaultTargetBarBgColor)
            bgColor[4] = defaultHealthBarBgAlpha
        else
            local c1 = getColor(defaultHealthBarBgGradientColor1)
            local c2 = getColor(defaultHealthBarBgGradientColor2)
            local upperLim = 0.8
            local lowerLim = 0.2
            local perc = cur / max
            perc = math.min(upperLim, math.max(lowerLim, perc))
            local redRatio = 1 - (perc - lowerLim) / (upperLim - lowerLim)
            bgColor = helpers.addVec(helpers.multVec(c2, 1 - redRatio), helpers.multVec(c1, redRatio))  -- TODO describe what this does
        end
    else
        bgColor = getBarBgColor(unit)
    end

    self.bg:SetColorTexture(unpack(bgColor))
end

local function updatePowerColor(self, unit)
    local color = getPowerBarColor(unit)
    self:SetStatusBarColor(unpack(color))
end

local function updatePowerBarVisibility(frame)
    local unit = 'target'

    if not UnitIsDeadOrGhost(unit) and (UnitPlayerControlled(unit) or UnitPowerType(unit) ~= 1) then
        local ycoord = frame:GetHeight() - (powerBarHeight + outlineWidth)
        frame.Health:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', 0, -ycoord)
        frame.Power:Show()
    else
        frame.Health:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT')
        frame.Power:Hide()
    end
end

local function updateTargetPower(frame)
    updatePowerBarVisibility(frame:GetParent())
end

local function updateTargetInfoborderColor(frame)
    local unit = 'target'
    local color = getClassOrReactionColor(unit)

    if color then
        frame:setInfoBorderColor(color)
    end
end

local function updateNameplate(frame, event, unit)
    local color = getClassOrReactionColor(unit)

    if color then
        frame.NameText:SetTextColor(unpack(color))
        color = {color[1], color[2], color[3], 0.4}
        frame.Health.bg:SetColorTexture(unpack(color))
    end
end

local function updateCastBar(frame, unit, name)
    local font = frame.Text:GetFont() or defaultFont
    if #name > 18 then
        frame.Text:SetFont(font, defaultCastBarFontSizeSmall)
    else
        frame.Text:SetFont(font, defaultCastBarFontSize)
    end
end

local function updatePartyHealth(frame, unit)
    local color = getClassOrReactionColor(unit)

    if color then
        color = {color[1], color[2], color[3], 0.4}
        frame.bg:SetColorTexture(unpack(color))
    end
end

local function auraIconHook(frame, unit, button)
    if not (button.isDebuff and not button.isPlayer) then
        return true
    end
end

--
-- Event handlers
--

local function threatHandler(frame)
    setInfoBorderColorByThreat(frame)
end

local function targetChangedHandler(frame, event)
    if event == 'PLAYER_TARGET_CHANGED' or event == 'UNIT_TARGET' then
        updateTargetInfoborderColor(frame)
        setInfoBorderColorByThreat(frame)
    end
end

local function updateInfoBorderCombatColor(frame)
    local combatColor

    if frame.CombatIndicator.status then
        if frame.ThreatIndicator.status then
            combatColor = {1, 0, 0}
        else
            combatColor = {1, 1, 1}
        end
    else
        combatColor = getColor(defaultInfoBorderColor)
    end

    frame:setInfoBorderColor(combatColor)
end

local function updateThreat(frame, unit, status)
    if not status then return end

    local unitFrame = frame:GetParent()

    if tonumber(status) >= 2 then
        frame.status = true
    else
        frame.status = false
    end

    updateInfoBorderCombatColor(unitFrame)
end

local function updateCombat(frame, inCombat)
    local unitFrame = frame:GetParent()

    if inCombat then
        frame.status = true
    else
        frame.status = false
    end

    updateInfoBorderCombatColor(unitFrame)
end

-- Create Style
local function StyleFunc(frame, unit)
	frame:RegisterForClicks('AnyUp')  -- to enable rightclick menu

    if unit == 'player' then
        addMainBorder(frame)
        frame:SetSize(unpack(defaultFrameSize))

        frame.Health = CreateHealthBar(frame, unit)
        frame.Health.UpdateColor = updateHealthColor
        frame.Power = CreatePowerBar(frame, unit)
        frame.Power:SetPoint("TOPLEFT", nil, "CENTER", -powerBarWidth/2, coordMainHealthY + padding + powerBarHeight)
        frame.Power:SetPoint("BOTTOMRIGHT", nil, "CENTER", powerBarWidth/2, coordMainHealthY + padding)
        frame.Power.UpdateColor = updatePowerColor
        frame.PowerText = CreatePowerText(frame)
        frame.ClassPower = CreateClassPower(frame)
        frame.AdditionalPower = CreateAdditionalPowerBar(frame)
        frame.AdditionalPower.colorPower = true
        frame.AlternativePower = CreateAlternativePowerBar(frame)
        frame.AlternativePower:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", -2, defaultAltPowerBarHeight + padding)
        frame.AlternativePower:SetPoint("BOTTOMRIGHT", frame.Power, "BOTTOMLEFT", -padding, 0)
        frame.Castbar = CreateCastBar(frame, unit)
        frame.Castbar:SetPoint("TOPLEFT", nil, "CENTER", coordMainHealthX + padding, coordMainHealthY)
        frame.Castbar:SetPoint("BOTTOMRIGHT", nil, "CENTER", -coordMainHealthX - padding, coordMainHealthY - castbarHeight)
        frame.Castbar.Text = CreateCastBarText(frame)
        frame.Castbar.PostCastStart = updateCastBar
        frame.ThreatIndicator = createInfoBorderIndicator(frame)
        frame.ThreatIndicator.PostUpdate = updateThreat
        frame.CombatIndicator = createInfoBorderIndicator(frame)
        frame.CombatIndicator.PostUpdate = updateCombat

        createHealthPrediction(frame)
        CreateHealthText{frame=frame, shadow=true}
        CreateNameText{frame=frame, shadow=true}

        if (select(2, UnitClass('player')) == 'DEATHKNIGHT') then
            frame.Runes = CreateClassPower(frame, 6)
            frame.Runes.colorSpec = true
        elseif (select(2, UnitClass('player')) == 'MONK') then
            frame.Stagger = CreateStaggerBar(frame)
            frame.Stagger.bg.multiplier = 0.5
        end

    elseif unit == 'target' then
        addMainBorder(frame)
        frame:SetSize(unpack(defaultFrameSize))
        frame.Health = CreateHealthBar(frame, unit)
        frame.Power = CreatePowerBar(frame, unit)
        frame.Power.PreUpdate = updateTargetPower
        frame.AlternativePower = CreateAlternativePowerBar(frame)
        frame.AlternativePower:SetPoint("TOPRIGHT", frame.Health, "TOPRIGHT", 2, defaultAltPowerBarHeight + padding)
        frame.AlternativePower:SetPoint("BOTTOMLEFT", ouf_dyk_PlayerFrame.Power, "BOTTOMRIGHT", padding , 0)

        createHealthPrediction(frame)
        frame.Health.UpdateColor = updateHealthColor
        frame.Power.UpdateColor = updatePowerColor
        CreateHealthText{frame=frame, shadow=true}
        CreateNameText{frame=frame, shadow=true, tag='[dyk:elitecolor][name]'}
        frame.Auras = CreateBuffs{frame=frame}

        frame.Castbar = CreateCastBar(frame, unit)
        frame.Castbar:SetPoint("TOPLEFT", nil, "CENTER", -castbarWidth/2, coordTargetCastBarY + castbarHeight)
        frame.Castbar:SetPoint("BOTTOMRIGHT", nil, "CENTER", castbarWidth/2, coordTargetCastBarY)
        frame.Castbar.Text = CreateCastBarText(frame)

        frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", threatHandler)
        frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE", threatHandler)
		frame:RegisterEvent('PLAYER_TARGET_CHANGED', threatHandler)
		frame:RegisterEvent('PLAYER_TARGET_CHANGED', targetChangedHandler)
        frame:RegisterEvent('UNIT_TARGET', targetChangedHandler, unitless)
        frame:HookScript("OnEvent", targetChangedHandler)

    end

	if unit == 'targettarget' then
        frame:SetPoint('TOPLEFT', ouf_dyk_TargetFrame, 'TOPRIGHT', padding, 0)
        frame:SetSize(unpack(defaultFrameSizeTargetTarget))
        frame.Health = CreateHealthBar(frame, unit)
        frame.Health:SetAllPoints()

        frame.Health.UpdateColor = updateHealthColor
        CreateHealthText{frame=frame, size=12, shadow=true, anchor={"RIGHT", frame.Health, "RIGHT", -2, 0}, tag='[ >dyk:perhp]'}
        frame.NameText = CreateNameText{frame=frame, size=12, shadow=true, anchor={"LEFT", frame.Health, "LEFT", 2, 0}, tag='[dyk:shortname]'}
	end

	if unit == 'pet' then
        frame:SetPoint('TOPLEFT', ouf_dyk_PlayerFrame, 'BOTTOMLEFT', 0, -padding)
        frame:SetSize(unpack(defaultFrameSizePet))
        frame.Health = CreateHealthBar(frame, unit)
        frame.Health:SetAllPoints()

        frame.Health.UpdateColor = updateHealthColor
        CreateHealthText{frame=frame, size=12, shadow=true, anchor={"RIGHT", frame.Health, "RIGHT", -2, 0}, tag='[ >dyk:perhp]'}
        frame.NameText = CreateNameText{frame=frame, size=12, shadow=true, anchor={"LEFT", frame.Health, "LEFT", 2, 0}, tag='[dyk:elitecolor][name]'}
	end

	if unit:sub(1, 4) == 'boss' then
        frame:SetSize(unpack(defaultFrameSizeBoss))
        frame.Health = CreateHealthBar(frame, unit)
        frame.Health:SetAllPoints()

        frame.Health.UpdateColor = updateHealthColor
        CreateHealthText{frame=frame, size=12, shadow=true, anchor={"RIGHT", frame.Health, "RIGHT", -2, 0}, tag='[ >dyk:perhp]'}
        frame.NameText = CreateNameText{frame=frame, size=12, shadow=true, anchor={"LEFT", frame.Health, "LEFT", 2, 0}, tag='[dyk:elitecolor][name]'}
	end
end

local function PartyStyleFunc(frame, unit)
	frame:RegisterForClicks('AnyUp')  -- to enable rightclick menu

    frame:SetSize(unpack(defaultFrameSizeParty))
    frame.Health = CreateHealthBar(frame, unit)
    frame.Health:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, defaultPartyPowerBarHeight)
    frame.Health.PostUpdate = updatePartyHealth
    frame.Power = CreatePowerBar(frame, unit)

    createHealthPrediction(frame)
    frame.Health.UpdateColor = updateHealthColor
    frame.Power.UpdateColor = updatePowerColor
    CreateHealthText{frame=frame, anchor={"RIGHT", frame.Health, "RIGHT", -2, -1}, tag='[ >dyk:perhp]'}
    frame.NameText = CreateNameText{frame=frame, size=12, classColor=true, anchor={"LEFT", frame.Health, "LEFT", 2, 0}}
    frame.Auras = CreateBuffs{frame=frame, buffsize=16, disableMouse=true, anchor='RIGHT'}
end

local function NamePlateStyleFunc(frame, unit)
    frame:SetSize(unpack(defaultNameplateFrameSize))
    frame:SetPoint('CENTER')
    frame.unittype = 'nameplate'
    frame.Float = createFloatingFrame(frame)

    frame.Health = CreateHealthBar(frame, unit)
    frame.NameText = CreateNameText{frame=frame, size=defaultNameplateFontSize, align='CENTER', shadow=true, anchor={"CENTER", frame.Health, "TOP", 0, -2}}
    frame.Auras = CreateBuffs{frame=frame, buffsize=16, disableMouse=true}
    frame.Auras.CustomFilter = auraIconHook

    local RaidIcon = frame.Float:CreateTexture(nil, 'OVERLAY')
    RaidIcon:SetPoint('CENTER', frame, 'RIGHT', 0, 0)
    RaidIcon:SetSize(16, 16)
    frame.RaidTargetIndicator = RaidIcon

    frame.Castbar = CreateCastBar(frame.Float, unit, false)
    frame.Castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 2)
    frame.Castbar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    frame.Castbar.Text = CreateCastBarText(frame, 8)
end

-- Register style with oUF
oUF:RegisterStyle(addonName.."_Style", StyleFunc)
oUF:RegisterStyle(addonName.."_PartyStyle", PartyStyleFunc)
oUF:RegisterStyle(addonName.."_NameplateStyle", NamePlateStyleFunc)

-- Set up oUF factory
oUF:Factory(function(self)
    self:SetActiveStyle(addonName.."_Style")
    self:Spawn("player", "ouf_dyk_PlayerFrame"):SetPoint("TOPRIGHT", nil, "CENTER", coordMainHealthX, coordMainHealthY)
    self:Spawn("target", "ouf_dyk_TargetFrame"):SetPoint("TOPLEFT", nil, "CENTER", -coordMainHealthX, coordMainHealthY)
    self:Spawn("targettarget", "ouf_dyk_TargetFrame")
    self:Spawn("pet", "ouf_dyk_PetFrame")

    for i = 1, 5 do
		local boss = self:Spawn('boss' .. i, "ouf_dyk_BossFrame" .. i)

		if i == 1 then
			boss:SetPoint('TOPRIGHT', nil, 'TOPRIGHT', -300, -220)
		else
			boss:SetPoint('TOP', _G['ouf_dyk_BossFrame' .. i - 1], 'BOTTOM', 0, -6)
		end
	end

    self:SetActiveStyle(addonName.."_PartyStyle")
	self:SpawnHeader(nil, nil, 'custom [group:party] show; [@raid3,exists] show; [@raid26,exists] hide; hide',
		'showParty', true,
		'showRaid', true,
		'yOffset', -10,
		'groupBy', 'ASSIGNEDROLE',
		'groupingOrder', 'TANK,HEALER,DAMAGER',
		'oUF-initialConfigFunction', [[
			self:SetHeight(19)
			self:SetWidth(126)
		]]
	):SetPoint('TOPLEFT', 10, -10)

    self:SetActiveStyle(addonName.."_NameplateStyle")
    local nameplateCvars = {
        nameplateMinAlpha = 0.5,
        nameplateMaxAlpha = 0.8,
        nameplateSelectedScale = 1.1,
    }
    self:SpawnNamePlates(addonName, updateNameplate, nameplateCvars)
end)
