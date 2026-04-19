-- ============================================================================
-- sh_carspawnconfig.lua - Shared конфигурация системы спавнера SWExp
-- ============================================================================

SWExp = SWExp or {}
SWExp.CarDealer = SWExp.CarDealer or {}

-- Хранилище количества техники в гараже (пул) [vehicle_class] = count
SWExp.CarDealer.VehiclePool = SWExp.CarDealer.VehiclePool or {}

-- Дефолтные значения, если машина не настроена
SWExp.CarDealer.DefaultSettings = {
    materialCost = 50, -- Стоимость производства в материалах
    techLevel = 1,     -- Требуемый ТЛ
    createRank = 'TRP',-- Минимальный ранг (ID) для создания
    spawnRank = 'TRP'  -- Минимальный ранг (ID) для спавна из гаража
}

-- Функция для получения настроек машины
function SWExp.CarDealer:GetVehicleSettings(vehicleClass)
    if NextRPCarList then
        for _, carData in pairs(NextRPCarList) do
            if carData.class == vehicleClass then
                return {
                    materialCost = carData.materialCost or self.DefaultSettings.materialCost,
                    techLevel    = carData.techLevel or self.DefaultSettings.techLevel,
                    createRank   = carData.createRank or self.DefaultSettings.createRank,
                    spawnRank    = carData.spawnRank or self.DefaultSettings.spawnRank
                }
            end
        end
    end
    -- BUG-12 FIX: возвращаем копию, а не ссылку, чтобы вызывающий код не мог
    -- случайно изменить глобальные настройки по умолчанию
    return {
        materialCost = self.DefaultSettings.materialCost,
        techLevel    = self.DefaultSettings.techLevel,
        createRank   = self.DefaultSettings.createRank,
        spawnRank    = self.DefaultSettings.spawnRank
    }
end

function SWExp.CarDealer:GetVehicleCount(vehicleClass)
    return self.VehiclePool[vehicleClass] or 0
end