local PANEL = {
	CurrentValue = "",
	History = {},
	HistoryPos = 0,
	CaretPos = 0,
}

function PANEL:Init()
	self:SetFocusTopLevel(true)
	self:SetKeyboardInputEnabled(true)
	self:SetAllowLua(true)
	
	-- ПОДГРУЖАЕМ EXO 2, ОФОРМЛЯЕМ СКРОЛЛ И ЦВЕТА
	self:SetHTML([[<html>
		<body>
			<style>
				@import url('https://fonts.googleapis.com/css2?family=Exo+2:wght@400;500;600&display=swap');

				html, body {
					padding: 0;
					margin: 0;
					border: none;
					overflow: hidden;
					background: transparent;
				}

				::selection {
					background-color: rgba(0, 184, 255, 0.4); /* Цвет акцента SWUI */
					color: #ffffff;
				}

				::-webkit-scrollbar {
					display: none;
				}

				#text-entry {
					margin: 0;
					height: 100%;
					width: 100%;
					border: none;
					background: transparent;
					padding-left: 6px;
					padding-top: 6px;
					font-family: 'Exo 2', sans-serif;
					font-size: 16px;
					font-weight: 500;
					resize: none;
					outline: none;
					color: #e4f4ff; /* SWUI.Colors.TextHi */
					text-shadow: 1px 1px 2px rgba(0,0,0,0.8);
				}
			</style>
			<textarea
				id="text-entry"
				autocomplete="off"
				autocorrect="off"
				autocapitalize="off"
				spellcheck="false" />
		</body>
	</html>]])

	self:AddInternalCallback("OnChange", function(value, caret_pos)
		self.CurrentValue = value
		self.CaretPos = caret_pos
		self:OnChange()
		self:OnValueChange(value)
	end)

	self:AddInternalCallback("OnArrowUp", function(caret_pos)
		self.CaretPos = caret_pos
		self.HistoryPos = self.HistoryPos - 1
		self:UpdateFromHistory()
	end)

	self:AddInternalCallback("OnArrowDown", function(caret_pos)
		self.CaretPos = caret_pos
		self.HistoryPos = self.HistoryPos + 1
		self:UpdateFromHistory()
	end)

	self:AddInternalCallback("OnImagePaste", function(name, base64)
		self:OnImagePaste(name, base64)
	end)

	self:AddInternalCallback("OnEnter", function(caret_pos)
		self.CaretPos = caret_pos
		self:AddHistory(self:GetText())
		self.HistoryPos = 0
		self:OnEnter()
	end)

	self:AddInternalCallback("OnTab", function(caret_pos)
		self.CaretPos = caret_pos
		self:OnTab()
	end)

	self:AddInternalCallback("OnRightClick", function()
		if SWUI then SWUI.PlaySound(SWUI.Sounds.Hover) end
		local paste_menu = DermaMenu()
		paste_menu:AddOption("Вставить", function()
			self:QueueJavascript([[{
				let ev = new ClipboardEvent("paste");
				TEXT_ENTRY.dispatchEvent(ev);
			}]])
		end)
		paste_menu:AddSpacer()
		paste_menu:AddOption("Отмена", function() paste_menu:Remove() end)
		paste_menu:Open()
	end)

	self:AddInternalCallback("Debug", print)

	self:QueueJavascript([[
		const TEXT_ENTRY = document.getElementById("text-entry");
		TEXT_ENTRY.addEventListener("contextmenu", (_) => TextEntryX.OnRightClick());
		TEXT_ENTRY.addEventListener("paste", (ev) => {
			if (!ev.clipboardData && !window.clipboardData) return;
			let items = (ev.clipboardData || window.clipboardData).items;
			if (!items) return;

			for (let item of items) {
				if (item.type.match("^image/")) {
					let file = item.getAsFile();
					let reader = new FileReader();
					reader.onload = () => {
						let b64 = btoa(reader.result);
						TextEntryX.OnImagePaste(file.name, b64);
					};
					reader.readAsBinaryString(file);
					break;
				}
			}
		});
		TEXT_ENTRY.addEventListener("input", (ev) => TextEntryX.OnChange(ev.target.value, ev.target.selectionStart));
		TEXT_ENTRY.addEventListener("keydown", (ev) => {
			switch (ev.which) {
				case 9:
					ev.preventDefault();
					TextEntryX.OnTab(TEXT_ENTRY.selectionStart);
					return false;
				case 13:
					TextEntryX.OnEnter(TEXT_ENTRY.selectionStart);
					if (!ev.shiftKey) {
						ev.preventDefault();
						return false;
					}
					break;
				case 38:
					ev.preventDefault();
					TextEntryX.OnArrowUp(TEXT_ENTRY.selectionStart);
					return false;
				case 40:
					ev.preventDefault();
					TextEntryX.OnArrowDown(TEXT_ENTRY.selectionStart);
					return false;
				default:
					break;
			}
		});
		TEXT_ENTRY.click();
		TEXT_ENTRY.focus();
	]])

	-- Свои дефолтные цвета (переопределяются из chat_tab.lua, но на всякий случай)
	self:SetBackgroundColor(Color(0,0,0,120))
	self:SetTextColor(Color(228, 244, 255))
	self:SetBorderColor(Color(26, 51, 72))
	self:SetPlaceholderColor(Color(58, 96, 112))

	local old_KillFocus = self.KillFocus
	self.KillFocus = function(self)
		old_KillFocus(self)
		self:QueueJavascript([[
			if (document.activeElement != document.body) {
				document.activeElement.blur();
			}
		]])
	end

	local old_RequestFocus = self.RequestFocus
	self.RequestFocus = function(self)
		old_RequestFocus(self)
		self:QueueJavascript([[
			TEXT_ENTRY.click();
			TEXT_ENTRY.focus();
		]])
	end
end

function PANEL:AddInternalCallback(name, callback) self:AddFunction("TextEntryX", name, callback) end
function PANEL:UpdateFromHistory()
	local pos = self.HistoryPos
	if pos < 0 then pos = #self.History end
	if pos > #self.History then pos = 0 end
	local text = self.History[pos] or ""
	self:SetText(text)
	self:OnChange()
	self:OnValueChange(text)
	self.HistoryPos = pos
end
function PANEL:AddHistory(text)
	if not text or text == "" then return end
	table.RemoveByValue(self.History, text)
	table.insert(self.History, text)
end
function PANEL:GetCaretPos() return self.CaretPos end
function PANEL:SetCaretPos(offset)
	self:QueueJavascript(([[TEXT_ENTRY.selectionStart = %d; TEXT_ENTRY.selectionEnd = %d;]]):format(offset, offset))
	self.CaretPos = offset
end
function PANEL:GetText() return self.CurrentValue end
PANEL.GetValue = PANEL.GetText
function PANEL:SetText(text)
	text = text or ""
	self.CurrentValue = text
	self:QueueJavascript(([[TEXT_ENTRY.value = `%s`;]]):format(text:JavascriptSafe()))
end
PANEL.SetValue = PANEL.SetText

local function color_to_css(col) return ("rgba(%d, %d, %d, %d)"):format(col.r, col.g, col.b, col.a / 255) end

function PANEL:SetTextColor(col)
	self:QueueJavascript(([[TEXT_ENTRY.style.color = "%s";]]):format(color_to_css(col)))
	self.TextColor = col
end
function PANEL:SetPlaceholderText(text)
	self:QueueJavascript(([[TEXT_ENTRY.placeholder = `%s`;]]):format(text:JavascriptSafe()))
end
function PANEL:SetPlaceholderColor(col)
	self.PlaceholderColor = col
	self:QueueJavascript([[{
		let style = document.createElement("style");
		style.type = "text/css";
		style.innerHTML = "#text-entry::placeholder { color: ]] .. color_to_css(col)  .. [[; }";
		document.getElementsByTagName("head")[0].appendChild(style);
	}]])
end
function PANEL:SetCompletionText(text)
	if not text or text:Trim() == "" then self.CompletionText = nil else self.CompletionText = text end
end
function PANEL:GetTextColor() return self.TextColor end
function PANEL:SetBackgroundColor(col)
	self.BackgroundColor = col -- В HTML мы сделали фон прозрачным, поэтому тут только сохраняем переменную
end
function PANEL:GetBackgroundColor() return self.BackgroundColor end
function PANEL:SetBorderColor(col) self.BorderColor = col end
function PANEL:GetBorderColor() return self.BorderColor end

local surface_DisableClipping = _G.surface.DisableClipping
local surface_SetDrawColor = _G.surface.SetDrawColor
local surface_SetTextColor = _G.surface.SetTextColor
local surface_DrawOutlinedRect = _G.surface.DrawOutlinedRect
local surface_DrawRect = _G.surface.DrawRect
local surface_SetFont = _G.surface.SetFont
local surface_GetTextSize = _G.surface.GetTextSize
local surface_SetTextPos = _G.surface.SetTextPos
local surface_DrawText = _G.surface.DrawText
local string_format, string_find, string_sub = _G.string.format, _G.string.find, _G.string.sub

local should_blink = false
local blink_text = nil

function PANEL:TriggerBlink(text)
	should_blink = true
	blink_text = text
	timer.Create("ECTextEntryBlink", 2, 1, function()
		should_blink = false
		blink_text = nil
	end)
end

function PANEL:PaintOver(w, h)
	-- Рисуем фон и границу в стиле SWUI.DrawPanel
	draw.RoundedBox(4, 0, 0, w, h, self.BackgroundColor or Color(0,0,0,120))
	surface_SetDrawColor(self.BorderColor or Color(26,51,72))
	surface_DrawOutlinedRect(0, 0, w, h)

	if self.CompletionText then
		surface_SetTextColor(self.PlaceholderColor)
		surface_SetFont("SWUI.Body") -- ИСПОЛЬЗУЕМ ШРИФТ SWUI
		local cur_text_w = surface_GetTextSize(self.CurrentValue)
		local start_pos, end_pos = string_find(self.CompletionText, self.CurrentValue, 1, true)
		if start_pos == 1 then
			local sub_completion = string_sub(self.CompletionText, end_pos + 1)
			local _, completion_text_h = surface_GetTextSize(sub_completion)
			surface_SetTextPos(cur_text_w + 8, h / 2 - completion_text_h / 2)
			surface_DrawText(sub_completion)
		else
			local sub_completion = string_format("<< %s >>", self.CompletionText)
			local _, completion_text_h = surface_GetTextSize(sub_completion)
			surface_SetTextPos(cur_text_w + 20, h / 2 - completion_text_h / 2)
			surface_DrawText(sub_completion)
		end
	end

	if should_blink then
		local col_val = math.abs(math.sin(RealTime() * 10)) * 255
		surface_SetDrawColor(col_val, 0, 0, col_val)
		surface_DrawOutlinedRect(0, 0, w, h)
		if blink_text then
			surface_SetFont("SWUI.Small")
			local text_w, text_h = surface_GetTextSize(blink_text)
			local text_x, text_y = w / 2 - text_w / 2, - (text_h + 2)
			surface_DisableClipping(true)
				draw.RoundedBox(4, text_x - 4, text_y - 2, text_w + 8, text_h + 4, Color(150, 0, 0))
				surface_SetTextPos(text_x, text_y)
				surface_SetTextColor(color_white)
				surface_DrawText(blink_text)
			surface_DisableClipping(false)
		end
	end
end

function PANEL:OnTab() end
function PANEL:OnEnter() end
function PANEL:OnChange() end
function PANEL:OnValueChange(value) end
function PANEL:OnImagePaste(name, base64) end

vgui.Register("TextEntryX", PANEL, "DHTML")