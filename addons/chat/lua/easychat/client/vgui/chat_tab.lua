include("easychat/client/vgui/richtextx.lua")
include("easychat/client/vgui/textentryx.lua")
include("easychat/client/vgui/textentry_legacy.lua")
include("easychat/client/vgui/emote_picker.lua")
include("easychat/client/vgui/color_picker.lua")

local NEW_LINE_PATTERN = "\n"
local EC_LEGACY_ENTRY = GetConVar("easychat_legacy_entry")
local EC_LEGACY_TEXT = GetConVar("easychat_legacy_text")

local MAIN_TAB = {
	Init = function(self)
		local can_use_cef = EasyChat.CanUseCEFFeatures()
		local use_new_richtext = (EC_LEGACY_TEXT and not EC_LEGACY_TEXT:GetBool()) or not EC_LEGACY_TEXT
		self.RichText = self:Add((can_use_cef and use_new_richtext) and "RichTextX" or "RichText")
		if not can_use_cef or not use_new_richtext then
			self.RichText.AppendImageURL = function(self, url) end
		end

		-- ПРИМЕНЯЕМ ШРИФТ SWUI К ИСТОРИИ ЧАТА
		self.RichText.PerformLayout = function(pnl)
			pnl:SetFontInternal("SWUI.Body")
			pnl:SetUnderlineFont("SWUI.Body")
			pnl:SetFGColor(SWUI and SWUI.Colors.TextHi or Color(228, 244, 255))
		end

		local last_color = self.RichText:GetFGColor()
		local old_insert_color_change = self.RichText.InsertColorChange
		self.RichText.InsertColorChange = function(pnl, r, g, b, a)
			last_color = istable(r) and Color(r.r, r.g, r.b) or Color(r, g, b)
			old_insert_color_change(pnl, last_color.r, last_color.g, last_color.b, last_color.a)
		end
		self.RichText.GetLastColorChange = function(pnl) return last_color end

		-- КНОПКА ПЕРЕКЛЮЧЕНИЯ РЕЖИМА ЧАТА (Say, OOC, PM)
		self.BtnSwitch = self:Add("DButton")
		self.BtnSwitch:SetText("Say")
		self.BtnSwitch:SetFont("SWUI.Small")
		self.BtnSwitch:SetTall(28)
		self.BtnSwitch:SetCursor('hand')

		local old_font_size = draw.GetFontHeight("SWUI.Small")
		self.BtnSwitch.Think = function(btn)
			local cur_mode = EasyChat.GetCurrentMode()
			local cur_text = btn:GetText()
			local cur_font_size = draw.GetFontHeight("SWUI.Small")
			if cur_font_size ~= old_font_size or cur_text ~= cur_mode.Name then
				old_font_size = cur_font_size
				btn:SetText(string.upper(cur_mode.Name))
				btn:SizeToContentsX(30)
				btn:InvalidateParent()
			end
		end

		self.BtnSwitch.DoClick = function()
			if SWUI then SWUI.PlaySound(SWUI.Sounds.Click) end
			local next_mode = EasyChat.Mode + 1
			EasyChat.Mode = next_mode > EasyChat.ModeCount and 0 or next_mode
		end

		self.BtnSwitch.DoRightClick = function()
			if SWUI then SWUI.PlaySound(SWUI.Sounds.Hover) end
			local switch_menu = DermaMenu()
			for mode_index, mode in pairs(EasyChat.Modes) do
				switch_menu:AddOption(string.upper(mode.Name), function()
					EasyChat.Mode = mode_index
				end)
			end
			switch_menu:AddSpacer()
			switch_menu:AddOption("Отмена", function() switch_menu:Remove() end)
			switch_menu:Open()
		end

		-- ПОЛЕ ВВОДА
		local use_new_text_entry = (EC_LEGACY_ENTRY and not EC_LEGACY_ENTRY:GetBool()) or not EC_LEGACY_ENTRY
		self.TextEntry = self:Add((can_use_cef and use_new_text_entry) and "TextEntryX" or "TextEntryLegacy")
		self.TextEntry:SetPlaceholderText("Ввод сообщения...")

		local function on_key_code_typed(_, key_code)
			if key_code == KEY_ENTER or key_code == KEY_PAD_ENTER then
				self.TextEntry:OnEnter()
			end
		end

		hook.Add("GUIMousePressed", self, function() if not IsValid(self) then return end end)
		hook.Add("VGUIMousePressed", self, function() if not IsValid(self) then return end end)
		hook.Add("ECClosed", self, function() if not IsValid(self) then return end end)

		-- СТИЛИЗАЦИЯ ПОЛЯ И КНОПКИ ПОД SWUI
		local placeholder_col = SWUI and SWUI.Colors.TextDim or Color(58, 96, 112)
		local text_col = SWUI and SWUI.Colors.TextHi or Color(228, 244, 255)
		local bg_col = Color(0, 0, 0, 150)
		local border_col = SWUI and SWUI.Colors.Border or Color(26, 51, 72)

		self.TextEntry:SetPlaceholderColor(placeholder_col)

		if can_use_cef and use_new_text_entry then
			self.TextEntry:SetBackgroundColor(bg_col)
			self.TextEntry:SetBorderColor(border_col)
			self.TextEntry:SetTextColor(text_col)
		else
			self.TextEntry.Paint = function(_, w, h)
				draw.RoundedBox(4, 0, 0, w, h, bg_col)
				surface.SetDrawColor(border_col)
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			local text_entry_fix = self:Add("DPanel")
			text_entry_fix:SetMouseInputEnabled(false)
			text_entry_fix:SetKeyboardInputEnabled(false)
			text_entry_fix:SetZPos(9999)

			self.TextEntry.PerformLayout = function(_, w, h)
				local tb_x, tb_y = self.TextEntry:GetPos()
				text_entry_fix:SetPos(tb_x, tb_y + 4)
				text_entry_fix:SetWide(self.TextEntry:GetWide())
				text_entry_fix:SetTall(self.TextEntry:GetTall() - 4)
			end

			local selection_color = SWUI and Color(SWUI.Colors.Accent.r, SWUI.Colors.Accent.g, SWUI.Colors.Accent.b, 100) or Color(0, 184, 255, 100)
			text_entry_fix.Paint = function()
				self.TextEntry:DrawTextEntryText(text_col, selection_color, text_col)
			end
		end

		-- Отрисовка кнопки переключения режима
		self.BtnSwitch:SetTextColor(SWUI and SWUI.Colors.TextHi or color_white)
		self.BtnSwitch.Paint = function(btn, w, h)
			local hov = btn:IsHovered()
			local bg = hov and Color(0, 40, 65) or Color(11, 15, 20)
			local brd = hov and (SWUI and SWUI.Colors.BorderHi or Color(42, 96, 128)) or (SWUI and SWUI.Colors.Border or Color(26, 51, 72))
			local acc = SWUI and SWUI.Colors.Accent or Color(0, 184, 255)

			draw.RoundedBox(4, 0, 0, w, h, bg)
			surface.SetDrawColor(brd)
			surface.DrawOutlinedRect(0, 0, w, h, 1)

			-- Акцентная полоска слева
			surface.SetDrawColor(acc)
			surface.DrawRect(0, 4, 3, h - 8)
		end
		self.BtnSwitch.OnCursorEntered = function()
			if SWUI then SWUI.PlaySound(SWUI.Sounds.Hover, 0.4) end
		end
	end,
	
	ComputeNewLineCount = function(self)
		local _, line_count = self.TextEntry:GetText():gsub(NEW_LINE_PATTERN, "\n")
		surface.SetFont("SWUI.Body") -- Изменено на правильный шрифт расчета ширины
		local tw, _ = surface.GetTextSize(self.TextEntry:GetText())
		line_count = line_count + math.floor(tw / self.TextEntry:GetWide())
		return math.min(28 + (line_count * 14), 100)
	end,
	
	PerformLayout = function(self, w, h)
		local text_entry_height = self:ComputeNewLineCount()
		local old_richtext_height = self.RichText:GetTall()
		
		-- Убираем дикие отступы снизу
		self.RichText:SetSize(w, h - (text_entry_height + 4))
		self.RichText:SetPos(0, 0)
		if self.RichText:GetTall() ~= old_richtext_height then
			self.RichText:GotoTextEnd()
		end

		self.TextEntry:SetSize(w - self.BtnSwitch:GetWide() - 4, text_entry_height)
		self.TextEntry:SetPos(self.BtnSwitch:GetWide() + 4, h - text_entry_height)

		self.BtnSwitch:SetPos(0, h - text_entry_height)
	end,
	
	OnRemove = function(self)
		hook.Remove("GUIMousePressed", self)
		hook.Remove("VGUIMousePressed", self)
		hook.Remove("ECClosed", self)
	end
}

vgui.Register("ECChatTab", MAIN_TAB, "DPanel")