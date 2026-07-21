-- ============================================================
-- Star Wars: Expedition — Система добычи материалов (клиент)
-- modules/cl_gathering.lua
--
-- Получает прогресс добычи с сервера и показывает уведомления.
-- HUD прогресс-бара и рендер частиц реализованы здесь.
-- ============================================================

if SERVER then return end

-- ============================================================
-- Уведомление о результате добычи
-- ============================================================

net.Receive("SWExp::Gather_Result", function()
    local success = net.ReadBool()
    local errMsg  = net.ReadString()
    local amount  = net.ReadInt(8)
    local name    = net.ReadString()

    if success then
        -- Используем систему уведомлений геймода (если есть)
        if SWExp and SWExp.Notify then
            SWExp.Notify(
                string.format("Добыто: %s ×%d → Сдайте на Ассемблере", name, amount),
                "success"
            )
        else
            -- Фоллбэк: стандартный chat
            chat.AddText(
                Color(100, 220, 100),
                string.format("[Добыча] +%d %s → Сдайте на Ассемблере", amount, name)
            )
        end

        -- Звук успеха на клиенте
        surface.PlaySound("buttons/button14.wav")

    else
        if SWExp and SWExp.Notify then
            SWExp.Notify(errMsg ~= "" and errMsg or "Ошибка добычи.", "error")
        else
            chat.AddText(
                Color(220, 80, 80),
                "[Добыча] " .. (errMsg ~= "" and errMsg or "Ошибка добычи.")
            )
        end
        surface.PlaySound("buttons/button10.wav")
    end
end)

print("[SWExp] Модуль добычи материалов (клиент) загружен.")
