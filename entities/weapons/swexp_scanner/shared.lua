-- ============================================================
-- Star Wars: Expedition — Полевой сканер (shared)
-- weapons/swexp_scanner/shared.lua
-- ============================================================

SWEP.PrintName          = "Полевой сканер"
SWEP.Author             = "SWExp"
SWEP.Instructions       = "ЛКМ: Навести на объект и удерживать для сканирования"
SWEP.Category           = "SWEXP | Основное"
SWEP.Spawnable          = true
SWEP.AdminSpawnable     = true

-- Модели sci-fi пистолета
SWEP.ViewModel          = "models/weapons/sci-fi/v_sci_fi_pistol.mdl"
SWEP.WorldModel         = "models/weapons/sci-fi/w_sci_fi_pistol.mdl"

SWEP.HoldType           = "pistol"
SWEP.Weight             = 5
SWEP.AutoSwitchTo       = false
SWEP.AutoSwitchFrom     = false

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = ""

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = ""

SWEP.DrawAmmo              = false
SWEP.DrawCrosshair         = false

-- ============================================================
-- Параметры сканирования
-- ============================================================

SWEP.ScanRange    = 200    -- максимальная дистанция (ед.)
SWEP.ScanDuration = 3.0    -- время удержания для скана (сек)
SWEP.ScanCooldown = 5.0    -- кулдаун после успешного скана (сек)

-- ============================================================
-- NetworkVar: позволяет клиенту видеть состояние сканирования
-- ============================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool",  0, "Scanning")      -- идёт сканирование
    self:NetworkVar("Float", 0, "ScanProgress")  -- прогресс 0.0 – 1.0
    self:NetworkVar("Float", 1, "CooldownEnd")   -- когда закончится кулдаун
end

-- ============================================================
-- Инициализация
-- ============================================================

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)

    if SERVER then
        self:SetScanning(false)
        self:SetScanProgress(0)
        self:SetCooldownEnd(0)
        self.ScanStartTime = 0
        self.ScanTarget    = nil
    end
end

-- ============================================================
-- PrimaryAttack — логика обрабатывается в Think
-- ============================================================

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.1)
end

function SWEP:SecondaryAttack() end

-- ============================================================
-- Сброс при смене или потере оружия
-- ============================================================

function SWEP:Holster()
    if SERVER then self:_CancelScan() end
    return true
end

function SWEP:OnRemove()
    if SERVER then self:_CancelScan() end
end

function SWEP:Deploy()
    return true
end

-- ============================================================
-- Вспомогательные серверные методы
-- ============================================================

function SWEP:_CancelScan()
    self.ScanStartTime = 0
    self.ScanTarget    = nil
    self:SetScanning(false)
    self:SetScanProgress(0)
end

-- Трассировка + проверка дистанции → возвращает валидную цель или nil
function SWEP:_FindTarget()
    local owner = self:GetOwner()
    if not IsValid(owner) then return nil end

    local tr = owner:GetEyeTrace()
    if not IsValid(tr.Entity)                          then return nil end
    if tr.Entity:GetClass() ~= "swexp_research_point"  then return nil end
    if tr.Entity:GetNWBool("SWExp_Scanned")            then return nil end

    local dist = owner:GetPos():Distance(tr.Entity:GetPos())
    if dist > self.ScanRange then return nil end

    return tr.Entity
end

-- ============================================================
-- Think: основной игровой цикл сканирования (только SERVER)
-- ============================================================

function SWEP:Think()
    if not SERVER then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local now = CurTime()

    if owner:KeyDown(IN_ATTACK) then

        -- Проверяем кулдаун
        if now < self:GetCooldownEnd() then
            return
        end

        if self.ScanStartTime == 0 then
            -- Ищем новую цель
            local target = self:_FindTarget()
            if IsValid(target) then
                self.ScanStartTime = now
                self.ScanTarget    = target
                self:SetScanning(true)
                self:SetScanProgress(0)
                owner:EmitSound("ambient/machines/thumper_hit.wav", 60, 120, 0.6)
            end

        else
            -- Продолжаем текущее сканирование
            -- 1) Цель ещё жива?
            if not IsValid(self.ScanTarget) or
               self.ScanTarget:GetNWBool("SWExp_Scanned") then
                self:_CancelScan()
                return
            end

            -- 2) Прицел всё ещё на цели?
            local tr = owner:GetEyeTrace()
            if tr.Entity ~= self.ScanTarget then
                self:_CancelScan()
                owner:EmitSound("buttons/button10.wav", 65, 90)
                return
            end

            -- 3) Цель ещё в зоне досягаемости?
            local dist = owner:GetPos():Distance(self.ScanTarget:GetPos())
            if dist > self.ScanRange + 60 then
                self:_CancelScan()
                owner:EmitSound("buttons/button10.wav", 65, 90)
                return
            end

            -- 4) Обновляем прогресс
            local elapsed  = now - self.ScanStartTime
            local progress = math.Clamp(elapsed / self.ScanDuration, 0, 1)
            self:SetScanProgress(progress)

            -- 5) Сканирование завершено!
            if progress >= 1 then
                self.ScanTarget:DoScan(owner)
                self:SetCooldownEnd(now + self.ScanCooldown)
                owner:EmitSound("buttons/button14.wav", 70, 120)
                self:_CancelScan()
            end
        end

    else
        -- Кнопка отпущена
        if self.ScanStartTime ~= 0 then
            self:_CancelScan()
        end
    end
end
