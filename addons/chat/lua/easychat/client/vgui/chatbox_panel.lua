local surface_SetDrawColor = _G.surface.SetDrawColor
local surface_DrawRect = _G.surface.DrawRect
local matGradientUp = Material("gui/gradient_up")

-- Безопасное получение цвета из SWUI
local function getSWUIColor(key, fallback)
	if SWUI and SWUI.Colors and SWUI.Colors[key] then
		local c = SWUI.Colors[key]
		return Color(c.r or 255, c.g or 255, c.b or 255, c.a or 255)
	end
	return fallback
end

local CHATBOX = {
	Init = function(self)
		local frame = self

		self:ShowCloseButton(false)
		self:SetScreenLock(true)
		self:SetDraggable(true)
		self:SetSizable(true)
		self:SetDeleteOnClose(false)
		self:SetTitle("")

		if SWUI and SWUI.PlaySound and SWUI.Sounds then
			SWUI.PlaySound(SWUI.Sounds.Open)
		end

		self.BtnClose = self:Add("DButton")
		self.BtnMaxim = self:Add("DButton")
		
		-- ==========================================
		-- КАСТОМНАЯ СИСТЕМА ВКЛАДОК (С широкими кнопками!)
		-- ==========================================
		self.Tabs = self:Add("DPanel")
		self.Tabs.Items = {}
		self.Tabs.ActiveTab = nil
		
		self.Scroller = self.Tabs:Add("DHorizontalScroller")
		self.Scroller:SetOverlap(0)
		self.Tabs.tabScroller = self.Scroller 
		
		self.ContentPanel = self.Tabs:Add("DPanel")
		self.ContentPanel.Paint = function() end
		
		local R      = 8
		local TBAR_H = 38
		local BORDER = 1

		-- ==========================================
		-- Отрисовка подложки окна и TabBar
		-- ==========================================
		self.Paint = function(pnl, pw, ph)
			local accent = getSWUIColor("Accent", Color(0, 184, 255))
			local border = getSWUIColor("Border", Color(26, 51, 72))
			local panel2 = getSWUIColor("Panel2", Color(14, 19, 25))

			draw.RoundedBoxEx(R + BORDER, 0, 0, pw, ph, accent, true, true, false, false)
			draw.RoundedBoxEx(R, BORDER, BORDER, pw - BORDER * 2, ph - BORDER * 2, Color(6, 12, 18, 220), true, true, false, false)

			draw.RoundedBoxEx(R, BORDER, BORDER, pw - BORDER * 2, TBAR_H, panel2, true, true, false, false)
			
			surface.SetDrawColor(border)
			surface.DrawLine(BORDER, BORDER + TBAR_H - 1, pw - BORDER * 2, BORDER + TBAR_H - 1)
		end

		self.Tabs.Paint = function() end 

		self.Tabs.SetActiveTab = function(tabs, tabBtn)
			if tabs.ActiveTab == tabBtn then return end
			if IsValid(tabs.ActiveTab) then tabs.ActiveTab.Panel:SetVisible(false) end
			tabs.ActiveTab = tabBtn
			if IsValid(tabBtn) then tabBtn.Panel:SetVisible(true) end
		end

		self.Tabs.GetActiveTab = function(tabs) return tabs.ActiveTab end

		self.Tabs.SwitchToName = function(tabs, name)
			for _, item in ipairs(tabs.Items) do
				if item.Tab:GetText() == name then
					tabs:SetActiveTab(item.Tab)
					return item.Tab
				end
			end
		end

		self.Tabs.GetItems = function(tabs) return tabs.Items end

		-- ==========================================
		-- СОЗДАНИЕ САМИХ ВКЛАДОК
		-- ==========================================
		self.Tabs.AddSheet = function(tabs, label, panel, material, NoText, NoTooltip, Tooltip)
			if not IsValid(panel) then return end
			
			panel:SetParent(frame.ContentPanel)
			panel:Dock(FILL)
			panel:SetVisible(false)
			if panel.SetPaintBackground then panel:SetPaintBackground(false) end

			local tabBtn = vgui.Create("DButton", frame.Scroller)
			tabBtn.Panel = panel
			
			-- Задаем текст стандартно, чтобы GMod сам его нарисовал!
			tabBtn:SetFont("SWUI.Small")
			tabBtn:SetText(label or "Вкладка")
			
			-- Делаем кнопку широкой
			tabBtn:SizeToContentsX(32)
			tabBtn:SetTall(TBAR_H)
			
			local oldSetText = tabBtn.SetText
			tabBtn.SetText = function(btn, txt)
				oldSetText(btn, txt)
				btn:SizeToContentsX(32)
			end
			
			tabBtn.Paint = function(btn, bw, bh)
				local isActive = (tabs.ActiveTab == btn)
				local hov = btn:IsHovered()
				
				local c_accent = getSWUIColor("Accent", Color(0, 184, 255))
				local c_textHi = getSWUIColor("TextHi", color_white)
				
				
				-- Меняем цвет дефолтного текста GMod'а
				btn:SetTextColor((isActive or hov) and c_textHi or c_text)

				if hov and not isActive then
					surface.SetDrawColor(0, 40, 65, 120)
					surface.DrawRect(0, 0, bw, bh)
				end

				if isActive then
					-- Свечение снизу вверх
					surface.SetDrawColor(c_accent.r, c_accent.g, c_accent.b, 60)
					surface.SetMaterial(matGradientUp)
					surface.DrawTexturedRect(0, 0, bw, bh)

					-- Синяя линия обводки внизу
					surface.SetDrawColor(c_accent)
					surface.DrawRect(0, bh - 2, bw, 2)
				end
			end

			tabBtn.DoClick = function(btn)
				if SWUI then SWUI.PlaySound(SWUI.Sounds.Tab, 0.7) end
				tabs:SetActiveTab(btn)
			end
			
			tabBtn.OnCursorEntered = function() if SWUI then SWUI.PlaySound(SWUI.Sounds.Hover, 0.5) end end
			tabBtn.DoRightClick = function() end

			frame.Scroller:AddPanel(tabBtn)
			table.insert(tabs.Items, {Tab = tabBtn, Panel = panel})

			if #tabs.Items == 1 then
				tabs:SetActiveTab(tabBtn)
			end

			return {Tab = tabBtn, Panel = panel}
		end

		-- ==========================================
		-- Кнопки управления окном
		-- ==========================================
		local function SetupBtn(btn, symbol, hoverColor, clickColor)
			btn:SetSize(24, 24)
			btn:SetZPos(10)
			btn:SetText("")
			btn.Paint = function(b, bw, bh)
				local hov = b:IsHovered()
				draw.RoundedBox(4, 0, 0, bw, bh, hov and hoverColor or Color(25, 25, 25, 0))
				draw.SimpleText(symbol, 'SWUI.Header', bw / 2, bh / 2 - 2, hov and clickColor or Color(120, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			btn.OnCursorEntered = function() if SWUI then SWUI.PlaySound(SWUI.Sounds.Hover, 0.6) end end
		end

		SetupBtn(self.BtnClose, '×', Color(60, 16, 12), getSWUIColor("Red", Color(255, 50, 50)))
		self.BtnClose.DoClick = function()
			if SWUI then SWUI.PlaySound(SWUI.Sounds.Close) end
			frame:Close()
		end

		SetupBtn(self.BtnMaxim, '□', Color(0, 40, 65), getSWUIColor("Accent", Color(0, 184, 255)))
		self.BtnMaxim.IsFullScreen = false
		self.BtnMaxim.DoClick = function(btn)
			if SWUI then SWUI.PlaySound(SWUI.Sounds.Click) end
			if not btn.IsFullScreen then
				local x, y, w, h = frame:GetBounds()
				btn.Before = { x = x, y = y, w = w, h = h }
				frame:SetSize(ScrW(), ScrH())
				frame:SetPos(0, 0)
				btn.IsFullScreen = true
			else
				frame:SetPos(btn.Before.x, btn.Before.y)
				frame:SetSize(btn.Before.w, btn.Before.h)
				btn.IsFullScreen = false
			end
		end

		-- Логика перетаскивания окна
		self.Scroller.OnMousePressed = function(scroller)
			if scroller:IsHovered() then
				scroller.Dragging = { gui.MouseX() - frame.x, gui.MouseY() - frame.y }
				scroller:MouseCapture(true)
			end
		end

		self.Scroller.OnMouseReleased = function(scroller)
			scroller.Dragging = nil
			scroller:MouseCapture(false)
		end

		self.Scroller.Think = function(scroller)
			if scroller.Dragging then
				local mouse_x = math.Clamp(gui.MouseX(), 1, ScrW() - 1)
				local mouse_y = math.Clamp(gui.MouseY(), 1, ScrH() - 1)
				local x = mouse_x - scroller.Dragging[1]
				local y = mouse_y - scroller.Dragging[2]
				if frame:GetScreenLock() then
					x = math.Clamp(x, 0, ScrW() - frame:GetWide())
					y = math.Clamp(y, 0, ScrH() - frame:GetTall())
				end
				frame:SetPos(x, y)
			end
			scroller:SetCursor(scroller:IsHovered() and "sizeall" or "arrow")
		end
	end,
	
	PerformLayout = function(self, w, h)
		local BORDER = 1
		local TBAR_H = 38
		
		self.Tabs:SetPos(BORDER, BORDER)
		self.Tabs:SetSize(w - BORDER * 2, h - BORDER * 2) 
		
		self.Scroller:SetPos(0, 0)
		self.Scroller:SetSize(w - BORDER * 2 - 70, TBAR_H) 

		self.ContentPanel:SetPos(0, TBAR_H)
		self.ContentPanel:SetSize(w - BORDER * 2, h - BORDER * 2 - TBAR_H)
		
		self.BtnMaxim:SetPos(w - 60, BORDER + (TBAR_H / 2) - 12)
		self.BtnClose:SetPos(w - 30, BORDER + (TBAR_H / 2) - 12)
	end
}

vgui.Register("ECChatBox", CHATBOX, "DFrame")