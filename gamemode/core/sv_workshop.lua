-- core/sv_workshop.lua
-- Автоматически добавляет всем игрокам на загрузку контент
-- из активных воркшоп-аддонов сервера.
--
-- Принцип: при инициализации сервера перебираем все подключённые
-- аддоны через engine.GetAddons() и регистрируем их через
-- resource.AddWorkshop(), чтобы клиент скачал их перед входом.

hook.Add('Initialize', 'SWExp::WorkshopLoad', function()
    for _, v in pairs(engine.GetAddons()) do
        -- engine.GetAddons() возвращает wsid для воркшоп-аддонов,
        -- для локальных аддонов wsid может отсутствовать — берём числовую часть из пути файла
        local wsid = v.wsid and v.wsid or string.gsub(tostring(v.file), '%D', '')

        if wsid and wsid ~= '' then
            resource.AddWorkshop(wsid)
        end
    end

    MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Воркшоп-контент зарегистрирован для загрузки игрокам.\n')
end)