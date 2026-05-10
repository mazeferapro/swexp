-- Star Wars: Expedition
-- modules/cl_postprocess.lua

if not CLIENT then return end

local cv_colormod = CreateClientConVar('swexp_colormod', '0', true, false,
    'Включить цветокоррекцию и bloom', 0, 1)

-- ============================================================
-- ШЕЙДЕР 1: GShader Library
-- ============================================================

local function EnableGShaderLib()
    RunConsoleCommand('r_shaderlib', '1')
end

local function DisableGShaderLib()
    RunConsoleCommand('r_shaderlib', '0')
end

-- ============================================================
-- ШЕЙДЕР 2: Physically Based Bloom
-- ============================================================

local function EnableBloom()
    RunConsoleCommand('pp_pbb',               '1')
    RunConsoleCommand('pp_pbb_sky',           '0')
    RunConsoleCommand('pp_pbb_treshold',      '1')
    RunConsoleCommand('pp_pbb_solftreshold',  '0.10')
    RunConsoleCommand('pp_pbb_tr_intensity',  '0.5')
    RunConsoleCommand('pp_pbb_r',             '255')
    RunConsoleCommand('pp_pbb_g',             '255')
    RunConsoleCommand('pp_pbb_b',             '255')
    RunConsoleCommand('pp_pbb_colormultiply', '0.1')
    RunConsoleCommand('pp_pbb_scale_x',       '1')
    RunConsoleCommand('pp_pbb_scale_y',       '1')
    RunConsoleCommand('pp_pbb_scale_z',       '1')
    RunConsoleCommand('pp_pbb_iterations',    '10')
    RunConsoleCommand('pp_pbb_dirt',          '0')
    RunConsoleCommand('pp_pbb_intensity',     '0.5')
    RunConsoleCommand('pp_pbb_strength',      '0.15')
    RunConsoleCommand('pp_pbb_chromatic',     '0')
    RunConsoleCommand('pp_pbb_chroma_r',      '0.05')
    RunConsoleCommand('pp_pbb_chroma_g',      '-0.05')
    RunConsoleCommand('pp_pbb_chroma_b',      '0')
    RunConsoleCommand('pp_pbb_format',        '0')
end

local function DisableBloom()
    RunConsoleCommand('pp_pbb', '0')
end

SWExp.EnableBloom  = EnableBloom
SWExp.DisableBloom = DisableBloom

-- ============================================================
-- ШЕЙДЕР 3: Изменение цвета
-- Используем встроенную систему GMod (pp_colormod_* конвары).
-- ColorPicker хранит 0-255, GMod умножает addr/addg/addb на 0.02
-- и mulr/mulg/mulb на 0.1 перед передачей шейдеру.
-- R=4 → 4 * 0.02 = 0.08 в шейдере (корректный жёлтый оттенок)
-- ============================================================

local function EnableColorMod()
    RunConsoleCommand('pp_colormod',            '1')
    RunConsoleCommand('pp_colormod_brightness', '-0.08')
    RunConsoleCommand('pp_colormod_contrast',   '1.20')
    RunConsoleCommand('pp_colormod_color',      '0.70')
    RunConsoleCommand('pp_colormod_inv',        '0')
    -- Добавочный цвет R=4, G=4, B=2 (хранятся как 0-255)
    RunConsoleCommand('pp_colormod_addr',       '4')
    RunConsoleCommand('pp_colormod_addg',       '4')
    RunConsoleCommand('pp_colormod_addb',       '2')
    -- Цвет множителя R=0, G=0, B=0
    RunConsoleCommand('pp_colormod_mulr',       '0')
    RunConsoleCommand('pp_colormod_mulg',       '0')
    RunConsoleCommand('pp_colormod_mulb',       '0')
end

local function DisableColorMod()
    RunConsoleCommand('pp_colormod', '0')
end

-- ============================================================
-- Автоприменение настройки при входе на сервер
-- Уважаем сохранённое значение convar swexp_colormod (FCVAR_ARCHIVE),
-- а не насильно включаем эффекты при каждом заходе.
-- ============================================================

local function ApplyColorMod(bEnabled)
    if bEnabled then
        EnableGShaderLib()
        EnableBloom()
        EnableColorMod()
    else
        DisableBloom()
        DisableColorMod()
        DisableGShaderLib()
    end
end

hook.Add('InitPostEntity', 'SWExp::AutoEnablePostProcess', function()
    timer.Simple(1, function()
        ApplyColorMod(cv_colormod:GetBool())
    end)
end)

-- При смене значения convar (через F4-меню или из консоли) сразу
-- применяем новое состояние, не дожидаясь следующего захода.
cvars.AddChangeCallback('swexp_colormod', function(_, _, sNew)
    ApplyColorMod(tobool(sNew))
end, 'SWExp::ColorModToggle')
