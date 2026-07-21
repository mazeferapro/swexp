-- modules/armor_progression/cl_progression.lua
-- Клиентская сторона прокачки брони.
-- Меню открывается по клавише из F4 - Настройки - Прокачка брони.

if SERVER then return end

local ProgData = {}

netstream.Hook("SWExp::ArmorProgressionSync", function(data)
    ProgData = data or {}
    if IsValid(SWExp.ProgMenu and SWExp.ProgMenu.Frame) then
        SWExp.ProgMenu:RefreshRight()
        if IsValid(SWExp.ProgMenu.LeftPanel) then
            SWExp.ProgMenu.LeftPanel:InvalidateLayout(true)
        end
    end
end)

SWExp.ProgMenu = SWExp.ProgMenu or {}

local CLASS_ORDER = { "light", "medium", "heavy", "engineer", "medical" }

local CLASS_ICONS = {
    light    = "*",
    medium   = "o",
    heavy    = "+",
    engineer = "E",
    medical  = "M",
}

local WIN_W = 1060
local WIN_H = 640
local NAV_W = 200
local ROW_H = 28
local CNT_H = WIN_H - 44

local function GetClassData(cls)
    return ProgData[cls] or { xp = 0, level = 1 }
end

local function XPFrac(cls)
    local d    = GetClassData(cls)
    local lvl  = d.level or 1
    local xp   = d.xp   or 0
    local cfg  = SWExp.ArmorProgression
    local base = (cfg.Levels[lvl]     and cfg.Levels[lvl].xp)     or 0
    local nxt  = (cfg.Levels[lvl + 1] and cfg.Levels[lvl + 1].xp) or nil
    if not nxt then return 1 end
    local needed = nxt - base
    return needed > 0 and math.Clamp((xp - base) / needed, 0, 1) or 1
end

local function DrawXPBar(x, y, w, h, frac)
    draw.RoundedBox(2, x, y, w, h, Color(255, 255, 255, 18))
    local fw = math.max(4, math.floor(w * math.Clamp(frac, 0, 1)))
    draw.RoundedBox(2, x, y, fw, h, SWUI.Colors.Accent)
end

-- ============================================================
-- OPEN
-- ============================================================

function SWExp.ProgMenu:Open()
    if IsValid(self.Frame) then self.Frame:Close() end

    local active = IsValid(LocalPlayer()) and
                   LocalPlayer():GetNWString("SWExp_ArmorClass", "") or ""
    self.SelectedClass = (active ~= "") and active or CLASS_ORDER[1]

    local frame, content = SWUI.CreateWindow(
        "ПРОКАЧКА БРОНИ", WIN_W, WIN_H, nil, SWUI.Colors.Accent)
    self.Frame = frame

    local origClose = frame.Close
    frame.Close = function(s)
        if IsValid(SWExp.ProgMenu._Backdrop) then
            SWExp.ProgMenu._Backdrop:Remove()
            SWExp.ProgMenu._Backdrop = nil
        end
        SWUI.Animations.Presets.WindowClose(s, 0.25, function()
            if IsValid(s) then origClose(s) end
        end)
    end

    SWUI.Animations.Presets.WindowOpen(frame, 0.3)
    SWUI.PlaySound(SWUI.Sounds.Open)

    SWExp.ProgMenu._Backdrop = nil
    timer.Simple(0.2, function()
        if not IsValid(SWExp.ProgMenu.Frame) then return end
        local bd = vgui.Create("DPanel")
        bd:SetPos(0, 0)
        bd:SetSize(ScrW(), ScrH())
        bd:SetMouseInputEnabled(true)
        bd.Paint = function() end
        bd.OnMousePressed = function(s, btn)
            if btn ~= MOUSE_LEFT then return end
            if IsValid(SWExp.ProgMenu.Frame) then
                SWExp.ProgMenu.Frame:Close()
            end
            s:Remove()
            SWExp.ProgMenu._Backdrop = nil
        end
        SWExp.ProgMenu._Backdrop = bd
        if IsValid(SWExp.ProgMenu.Frame) then
            SWExp.ProgMenu.Frame:MoveToFront()
        end
    end)

    self:BuildLeft(content)
    self:BuildRight(content)
    self:RefreshRight()
end

-- ============================================================
-- LEFT NAV
-- ============================================================

function SWExp.ProgMenu:BuildLeft(content)
    local lp = vgui.Create("DPanel", content)
    lp:SetPos(0, 0)
    lp:SetSize(NAV_W, CNT_H)
    lp.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(10, 16, 22, 255))
        surface.SetDrawColor(SWUI.Colors.BorderHi)
        surface.DrawRect(w - 1, 0, 1, h)
    end
    self.LeftPanel = lp

    local btnH = math.floor((CNT_H - 12) / #CLASS_ORDER)

    for idx, cls in ipairs(CLASS_ORDER) do
        local btn = vgui.Create("DPanel", lp)
        btn:SetPos(0, 6 + (idx - 1) * btnH)
        btn:SetSize(NAV_W - 1, btnH - 2)
        btn:SetCursor("hand")
        btn._cls      = cls
        btn._hovAlpha = 0

        btn.OnCursorEntered = function(s)
            SWUI.PlaySound(SWUI.Sounds.Hover, 0.4)
            local t0, a0 = SysTime(), s._hovAlpha
            local function anim()
                if not IsValid(s) then return end
                local p = math.min((SysTime() - t0) / 0.15, 1)
                s._hovAlpha = Lerp(SWUI.Animations.Easing.OutQuad(p), a0, 1)
                if p < 1 then timer.Simple(0, anim) end
            end
            timer.Simple(0, anim)
        end

        btn.OnCursorExited = function(s)
            local t0, a0 = SysTime(), s._hovAlpha
            local function anim()
                if not IsValid(s) then return end
                local p = math.min((SysTime() - t0) / 0.2, 1)
                s._hovAlpha = Lerp(SWUI.Animations.Easing.OutQuad(p), a0, 0)
                if p < 1 then timer.Simple(0, anim) end
            end
            timer.Simple(0, anim)
        end

        btn.OnMousePressed = function(s, key)
            if key ~= MOUSE_LEFT then return end
            SWUI.PlaySound(SWUI.Sounds.Select)
            SWExp.ProgMenu.SelectedClass = s._cls
            SWExp.ProgMenu:RefreshRight()
        end

        btn.Paint = function(s, w, h)
            local sel      = (SWExp.ProgMenu.SelectedClass == s._cls)
            local equipped = IsValid(LocalPlayer()) and
                             LocalPlayer():GetNWString("SWExp_ArmorClass", "") == s._cls
            local hov      = s._hovAlpha

            if hov > 0 then
                surface.SetDrawColor(0, 40, 65, math.floor(180 * hov))
                surface.DrawRect(0, 0, w, h)
            end

            if sel then
                surface.SetDrawColor(SWUI.Colors.Accent)
                surface.DrawRect(0, 4, 3, h - 8)
            end

            local clsName = SWExp.ArmorProgression.ClassNames[s._cls] or s._cls
            local d       = GetClassData(s._cls)
            local lvl     = d.level or 1
            local lvlData = SWExp.ArmorProgression.Levels[lvl]
            local lvlName = lvlData and lvlData.name or ("Ур." .. lvl)

            local tc = sel and SWUI.Colors.TextHi or
                       (hov > 0.5 and SWUI.Colors.Text or SWUI.Colors.TextDim)

            SWUI.DrawText(clsName, "SWUI.Small", 14, 12, tc,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            SWUI.DrawText("Ур. " .. lvl .. "  " .. lvlName, "SWUI.Tiny", 14, 28,
                sel and SWUI.Colors.Accent or SWUI.Colors.TextDim,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            if equipped then
                SWUI.DrawText("надета", "SWUI.Tiny", w - 6, 12,
                    SWUI.Colors.Green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end

            DrawXPBar(12, h - 9, w - 24, 3, XPFrac(s._cls))

            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawRect(8, h - 1, w - 16, 1)
        end

        btn:SetAlpha(0)
        SWUI.FadeIn(btn, 0.3, idx * 0.05)
    end
end

-- ============================================================
-- RIGHT PANEL
-- ============================================================

function SWExp.ProgMenu:BuildRight(content)
    local rp = vgui.Create("DPanel", content)
    rp:SetPos(NAV_W, 0)
    rp:SetSize(WIN_W - NAV_W, CNT_H)
    rp.Paint = function() end
    self.RightPanel = rp
end

function SWExp.ProgMenu:RefreshRight()
    if not IsValid(self.RightPanel) then return end
    self.RightPanel:Clear()

    local cls    = self.SelectedClass or CLASS_ORDER[1]
    local d      = GetClassData(cls)
    local curLvl = d.level or 1
    local curXP  = d.xp   or 0
    local maxLvl = SWExp.ArmorProgression.MaxLevel
    local lvls   = SWExp.ArmorProgression.Levels
    local ccfg   = SWExp.ArmorProgression.ClassConfig[cls] or {}

    local clsName = SWExp.ArmorProgression.ClassNames[cls] or cls
    local lvlData = lvls[curLvl]
    local lvlName = lvlData and lvlData.name or ("Uroven " .. curLvl)

    local W = WIN_W - NAV_W
    local H = CNT_H
    local HDR_H = 88
    local COL_H = 22

    local hdr = vgui.Create("DPanel", self.RightPanel)
    hdr:SetPos(0, 0)
    hdr:SetSize(W, HDR_H)
    hdr.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, SWUI.Colors.Panel2)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawRect(0, h - 1, w, 1)

        SWUI.DrawText(clsName, "SWUI.Header", 14, 12, SWUI.Colors.TextHi,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SWUI.DrawText("Уровень " .. curLvl .. "  ·  " .. lvlName, "SWUI.Small",
            14, 40, SWUI.Colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local xpBase   = lvlData and lvlData.xp or 0
        local nxtData  = (curLvl < maxLvl) and lvls[curLvl + 1] or nil
        local xpNeeded = nxtData and (nxtData.xp - xpBase) or 0
        local xpLocal  = curXP - xpBase
        local frac     = xpNeeded > 0 and math.Clamp(xpLocal / xpNeeded, 0, 1) or 1

        DrawXPBar(14, 62, w - 28, 7, frac)

        local xpStr = curLvl >= maxLvl
            and "Максимальный уровень"
            or  string.format("%d / %d ОИ  →  Ур. %d", xpLocal, xpNeeded, curLvl + 1)
        SWUI.DrawText(xpStr, "SWUI.Tiny", 14 + (w - 28) / 2, 62 + 11,
            SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
    SWUI.FadeIn(hdr, 0.25)

    local colHdr = vgui.Create("DPanel", self.RightPanel)
    colHdr:SetPos(0, HDR_H)
    colHdr:SetSize(W, COL_H)
    colHdr.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(6, 10, 16, 255))
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawRect(0, h - 1, w, 1)
        local dm = SWUI.Colors.TextDim
        SWUI.DrawText("#",        "SWUI.Tiny", 8,     h/2, dm, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SWUI.DrawText("Название", "SWUI.Tiny", 34,    h/2, dm, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SWUI.DrawText("HP",       "SWUI.Tiny", w-390, h/2, dm, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SWUI.DrawText("Скорость", "SWUI.Tiny", w-330, h/2, dm, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SWUI.DrawText("Броня",    "SWUI.Tiny", w-255, h/2, dm, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SWUI.DrawText("Перк",     "SWUI.Tiny", w-185, h/2, dm, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local listY  = HDR_H + COL_H + 2
    local scroll = SWUI.CreateScrollList(self.RightPanel, 0, listY, W, H - listY)

    local layout = vgui.Create("DListLayout", scroll)
    layout:SetWide(W - 6)

    local deltas = {}
    for i = 1, maxLvl do
        local cur  = ccfg[i]   or {}
        local prev = ccfg[i-1] or { maxHP = 100, speedBonus = 0, armorBonus = 0 }
        deltas[i] = {
            hp  = (cur.maxHP      or 100) - (prev.maxHP      or 100),
            spd = (cur.speedBonus or 0)   - (prev.speedBonus or 0),
            arm = (cur.armorBonus or 0)   - (prev.armorBonus or 0),
        }
    end

    local scrollTarget = nil

    for i = 1, maxLvl do
        local isUnlocked = (i <= curLvl)
        local isCurrent  = (i == curLvl)
        local cfg_i      = ccfg[i] or {}
        local lvl_i      = lvls[i]
        local lname      = lvl_i and lvl_i.name or ("Ур." .. i)
        local delta      = deltas[i]

        local row = SWUI.Animated.CreateListRow(layout, ROW_H,
            isCurrent, not isUnlocked, nil)

        local basePaint = row.Paint
        row.Paint = function(s, w, h)
            basePaint(s, w, h)

            local tc = isCurrent  and SWUI.Colors.TextHi
                    or isUnlocked and SWUI.Colors.Text
                    or              SWUI.Colors.TextDim

            if isCurrent then
                surface.SetDrawColor(SWUI.Colors.Accent)
                surface.DrawRect(0, 0, 3, h)
                SWUI.DrawText("<<<", "SWUI.Tiny", 190, h/2,
                    SWUI.Colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            SWUI.DrawText(tostring(i), "SWUI.MonoSmall",
                8, h/2, isCurrent and SWUI.Colors.Accent or SWUI.Colors.TextDim,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            SWUI.DrawText(lname, "SWUI.Tiny", 34, h/2, tc,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            local hpStr = (i == 1) and tostring(cfg_i.maxHP or 100)
                       or delta.hp > 0 and ("+" .. delta.hp) or "-"
            local hpCol = (delta.hp > 0 and isUnlocked) and SWUI.Colors.Green or SWUI.Colors.TextDim
            SWUI.DrawText(hpStr, "SWUI.Tiny", w-390, h/2, hpCol,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            local spdStr = (i == 1) and "0%"
                        or delta.spd > 0.0005 and
                           string.format("+%.1f%%", delta.spd * 100) or "-"
            local spdCol = (delta.spd > 0.0005 and isUnlocked) and
                           SWUI.Colors.Accent or SWUI.Colors.TextDim
            SWUI.DrawText(spdStr, "SWUI.Tiny", w-330, h/2, spdCol,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            local armStr = (i == 1) and "0%"
                        or delta.arm > 0.01 and
                           string.format("+%.1f%%", delta.arm) or "-"
            local armCol = (delta.arm > 0.01 and isUnlocked) and
                           SWUI.Colors.Warn or SWUI.Colors.TextDim
            SWUI.DrawText(armStr, "SWUI.Tiny", w-255, h/2, armCol,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            if cfg_i.perk then
                local pname = cfg_i.perk
                if ArcCW and ArcCW.AttachmentTable and ArcCW.AttachmentTable[pname] then
                    pname = ArcCW.AttachmentTable[pname].PrintName or pname
                end
                local label = "* " .. pname
                local maxPerkW = 178
                surface.SetFont("SWUI.Tiny")
                if surface.GetTextSize(label) > maxPerkW then
                    while #label > 4 and surface.GetTextSize(label .. "...") > maxPerkW do
                        label = label:sub(1, -2)
                    end
                    label = label .. "..."
                end
                local pCol = isUnlocked and Color(255, 200, 40) or Color(90, 72, 20)
                SWUI.DrawText(label, "SWUI.Tiny", w-185, h/2, pCol,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        if i <= 20 then
            row:SetAlpha(0)
            SWUI.FadeIn(row, 0.25, i * 0.015)
        end

        if isCurrent then
            scrollTarget = math.max(0, (i - 4) * ROW_H)
        end
    end

    if scrollTarget then
        timer.Simple(0, function()
            if IsValid(scroll) then
                scroll:GetVBar():SetScroll(scrollTarget)
            end
        end)
    end
end

-- ============================================================
-- KEY BINDING (Think-based, avoids MakePopup phantom events)
-- ============================================================

local function GetProgKey()
    return cookie.GetNumber("swexp_key_armor_prog", KEY_NONE)
end

local _keyWasDown = false

hook.Add("Think", "SWExp_ProgMenu_Think", function()
    if not IsValid(LocalPlayer()) then return end

    local bound = GetProgKey()
    if bound == KEY_NONE then
        _keyWasDown = false
        return
    end

    local isDown = input.IsKeyDown(bound)

    if isDown and not _keyWasDown then
        local cs = LocalPlayer():GetNWString("swexp_callsign", "")
        if cs ~= "" then
            if IsValid(SWExp.ProgMenu.Frame) then
                SWExp.ProgMenu.Frame:Close()
            else
                SWExp.ProgMenu:Open()
            end
        end
    end

    _keyWasDown = isDown
end)

netstream.Hook("SWExp::CharSelected", function()
    ProgData = {}
    if IsValid(SWExp.ProgMenu and SWExp.ProgMenu.Frame) then
        SWExp.ProgMenu.Frame:Close()
    end
end)
