-- ============================================================
-- Star Wars: Expedition — Контроль фонарика (клиент)
-- modules/cl_flashlight.lua
-- ============================================================

if SERVER then return end

hook.Add("PlayerBindPress", "SWExp::FlashlightBind", function(ply, bind, pressed)
    print("[FL CL] bind=" .. tostring(bind) .. " pressed=" .. tostring(pressed))
    if bind ~= "impulse 100" then return end
    if not pressed then return true end

    print("[FL CL] Отправляю net на сервер")
    net.Start("SWExp::FlashlightToggle")
    net.SendToServer()

    return true
end)
