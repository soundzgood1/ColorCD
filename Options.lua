-- ColorCD: Options window — SoundzKey style with purple accent

-- ── Palette ───────────────────────────────────────────────────────────────────
local PURPLE = { 0.65, 0.20, 1.00, 1.0 }
local BG     = { 0.06, 0.06, 0.09, 0.97 }
local TITLE  = { 0.09, 0.09, 0.13, 1.0 }
local BTN    = { 0.15, 0.15, 0.19, 1.0 }
local PRESS  = { 0.07, 0.07, 0.10, 1.0 }
local BORD   = { 0.28, 0.28, 0.35, 1.0 }

-- ── Widget helpers ────────────────────────────────────────────────────────────
local function ApplyBorder(f, c)
    c = c or BORD
    local r, g, b, a = c[1], c[2], c[3], c[4] or 1
    local top = f:CreateTexture(nil, "BORDER"); top:SetColorTexture(r, g, b, a)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    local bot = f:CreateTexture(nil, "BORDER"); bot:SetColorTexture(r, g, b, a)
    bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(1)
    local lft = f:CreateTexture(nil, "BORDER"); lft:SetColorTexture(r, g, b, a)
    lft:SetPoint("TOPLEFT", 0, -1); lft:SetPoint("BOTTOMLEFT", 0, 1); lft:SetWidth(1)
    local rgt = f:CreateTexture(nil, "BORDER"); rgt:SetColorTexture(r, g, b, a)
    rgt:SetPoint("TOPRIGHT", 0, -1); rgt:SetPoint("BOTTOMRIGHT", 0, 1); rgt:SetWidth(1)
end

local function MakeBtn(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 90, h or 24)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(BTN[1], BTN[2], BTN[3], 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(PURPLE[1], PURPLE[2], PURPLE[3], 0.13)
    local lbl = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetAllPoints(); lbl:SetJustifyH("CENTER"); lbl:SetText(text)
    b.lbl = lbl
    b:SetScript("OnMouseDown", function() bg:SetColorTexture(PRESS[1], PRESS[2], PRESS[3], 1) end)
    b:SetScript("OnMouseUp",   function() bg:SetColorTexture(BTN[1],   BTN[2],   BTN[3],   1) end)
    b:SetScript("OnLeave",     function() bg:SetColorTexture(BTN[1],   BTN[2],   BTN[3],   1) end)
    ApplyBorder(b)
    return b
end

local function GradLine(parent, layer, y, r, g, b, a)
    local cNone = CreateColor(r, g, b, 0)
    local cFull = CreateColor(r, g, b, a)
    local tL = parent:CreateTexture(nil, layer)
    tL:SetTexture("Interface\\Buttons\\WHITE8x8")
    tL:SetGradient("HORIZONTAL", cNone, cFull)
    tL:SetHeight(1)
    tL:SetPoint("TOPLEFT",  parent, "TOPLEFT",  20, y)
    tL:SetPoint("TOPRIGHT", parent, "TOP",       0, y)
    local tR = parent:CreateTexture(nil, layer)
    tR:SetTexture("Interface\\Buttons\\WHITE8x8")
    tR:SetGradient("HORIZONTAL", cFull, cNone)
    tR:SetHeight(1)
    tR:SetPoint("TOPLEFT",  parent, "TOP",       0, y)
    tR:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, y)
end

local function SectionLabel(parent, text, y)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    lbl:SetText("|cffbb77ff" .. text .. "|r")
    GradLine(parent, "ARTWORK", y - 15, PURPLE[1], PURPLE[2], PURPLE[3], 0.45)
end

local function Div(parent, y)
    GradLine(parent, "ARTWORK", y, 0.20, 0.20, 0.27, 0.85)
end

local function MakeCheckbox(parent, label, y)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(22, 22)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    lbl:SetText(label)
    cb.lbl = lbl
    return cb
end

-- ── Window-level locals (referenced by OnShow) ────────────────────────────────
local win
local swatchTex
local cbEnable, cbMinimap

-- ── Main standalone window ────────────────────────────────────────────────────
local function BuildWindow()
    local M = 20  -- left content margin

    win = CreateFrame("Frame", "ColorCDMainFrame", UIParent)
    win:SetSize(390, 520)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    win:Hide()
    table.insert(UISpecialFrames, "ColorCDMainFrame")  -- Esc closes it

    -- Dark background
    local winBg = win:CreateTexture(nil, "BACKGROUND", nil, -1)
    winBg:SetAllPoints(); winBg:SetColorTexture(BG[1], BG[2], BG[3], BG[4])
    ApplyBorder(win, BORD)

    -- Purple accent stripe across the very top (3 px)
    local accent = win:CreateTexture(nil, "BORDER", nil, 1)
    accent:SetColorTexture(PURPLE[1], PURPLE[2], PURPLE[3], 1)
    accent:SetHeight(3)
    accent:SetPoint("TOPLEFT"); accent:SetPoint("TOPRIGHT")

    -- Title bar
    local titleBg = win:CreateTexture(nil, "BACKGROUND", nil, 0)
    titleBg:SetColorTexture(TITLE[1], TITLE[2], TITLE[3], 1)
    titleBg:SetHeight(36)
    titleBg:SetPoint("TOPLEFT"); titleBg:SetPoint("TOPRIGHT")

    local titleSep = win:CreateTexture(nil, "ARTWORK")
    titleSep:SetColorTexture(0.22, 0.22, 0.30, 1)
    titleSep:SetHeight(1)
    titleSep:SetPoint("TOPLEFT",  win, "TOPLEFT",  0, -36)
    titleSep:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, -36)

    -- CD icon in title bar
    local titleIcon = win:CreateTexture(nil, "OVERLAY")
    titleIcon:SetTexture("Interface\\AddOns\\ColorCD\\Media\\cd_icon.png")
    titleIcon:SetSize(20, 20)
    titleIcon:SetPoint("LEFT", win, "TOPLEFT", 12, -20)

    -- Title text
    local titleText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 7, 0)
    titleText:SetText("|cffbb77ffColorCD|r  |cff555566-- by soundz|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, win)
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -5, -5)
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY")
    closeX:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    closeX:SetPoint("CENTER")
    closeX:SetTextColor(PURPLE[1], PURPLE[2], PURPLE[3], 1)
    closeX:SetText("X")
    closeBtn:SetScript("OnEnter", function() closeX:SetTextColor(0.85, 0.55, 1.0, 1) end)
    closeBtn:SetScript("OnLeave", function() closeX:SetTextColor(PURPLE[1], PURPLE[2], PURPLE[3], 1) end)
    closeBtn:SetScript("OnClick", function() win:Hide() end)

    -- ── GENERAL ──────────────────────────────────────────────────────────────
    SectionLabel(win, "GENERAL", -50)

    cbEnable = MakeCheckbox(win, "Enable cooldown numbers", -76)
    cbEnable:SetScript("OnClick", function(self)
        ColorCD_DB.enabled = self:GetChecked() and true or false
        ColorCD.UpdateAllColors()
    end)

    Div(win, -106)

    -- ── COOLDOWN COLORS ────────────────────────────────────────────────────────
    SectionLabel(win, "COOLDOWN COLORS", -116)

    local colorSubtitle = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    colorSubtitle:SetPoint("TOPLEFT", win, "TOPLEFT", M, -138)
    colorSubtitle:SetWidth(350)
    colorSubtitle:SetJustifyH("LEFT")
    colorSubtitle:SetText("Pick the color your cooldown numbers should always show.")

    -- ── Live preview icon — a real action-button-style Cooldown widget driven
    -- through ColorCD's own InjectColor/ticker, so what you see here is exactly
    -- what a real ability on your bars would do. Renewing Mist just gives it a
    -- recognizable, colorful icon; it has no functional meaning.
    local previewBtn = CreateFrame("Button", "ColorCDPreviewButton", win)
    previewBtn:SetSize(50, 50)
    previewBtn:SetPoint("TOPLEFT", win, "TOPLEFT", M, -182)

    local previewBg = previewBtn:CreateTexture(nil, "BACKGROUND")
    previewBg:SetAllPoints(); previewBg:SetColorTexture(0, 0, 0, 1)

    local previewIcon = previewBtn:CreateTexture(nil, "ARTWORK")
    previewIcon:SetTexture("Interface\\Icons\\Ability_Monk_RenewingMists")
    previewIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    previewIcon:SetAllPoints()
    ApplyBorder(previewBtn, BORD)

    local previewCooldown = CreateFrame("Cooldown", "ColorCDPreviewCooldown", previewBtn, "CooldownFrameTemplate")
    previewCooldown:SetAllPoints()
    ColorCD.InjectColor(previewCooldown)

    local testBtn = MakeBtn(win, "Test Cooldown", 110, 26)
    testBtn:SetPoint("LEFT", previewBtn, "RIGHT", 14, -12)
    testBtn:SetScript("OnClick", function()
        previewCooldown:SetCooldown(GetTime(), 10)
    end)

    -- Anchored to the window, not to testBtn, and width-capped so it can never
    -- run past the window edge regardless of button position or text length.
    local previewHint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    previewHint:SetPoint("TOPLEFT", win, "TOPLEFT", M, -240)
    previewHint:SetWidth(350)
    previewHint:SetJustifyH("LEFT")
    previewHint:SetText("Just a preview — your action bars aren't affected.")

    -- Color swatch
    local colorSwatch = CreateFrame("Button", nil, win)
    colorSwatch:SetSize(36, 22)
    colorSwatch:SetPoint("TOPLEFT", win, "TOPLEFT", M, -266)
    swatchTex = colorSwatch:CreateTexture(nil, "BACKGROUND")
    swatchTex:SetAllPoints()
    ApplyBorder(colorSwatch)

    local colorLbl = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colorLbl:SetPoint("LEFT", colorSwatch, "RIGHT", 10, 0)
    colorLbl:SetText("Color")

    local function OpenColorPicker()
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local db = ColorCD.DB()
        local pR, pG, pB = db.colorR, db.colorG, db.colorB
        ColorPickerFrame:SetupColorPickerAndShow({
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                ColorCD_DB.colorR, ColorCD_DB.colorG, ColorCD_DB.colorB = r, g, b
                swatchTex:SetColorTexture(r, g, b, 1)
                ColorCD.UpdateAllColors()
            end,
            cancelFunc = function(prev)
                local r = (prev and prev.r) or pR
                local g = (prev and prev.g) or pG
                local b = (prev and prev.b) or pB
                ColorCD_DB.colorR, ColorCD_DB.colorG, ColorCD_DB.colorB = r, g, b
                swatchTex:SetColorTexture(r, g, b, 1)
                ColorCD.UpdateAllColors()
            end,
            hasOpacity = false,
            r = db.colorR, g = db.colorG, b = db.colorB,
        })
    end
    colorSwatch:SetScript("OnClick", OpenColorPicker)
    colorSwatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Color", 1, 1, 1)
        GameTooltip:AddLine("The color used for your cooldown numbers.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    colorSwatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Size and Font live here, right under Color, since they're the other
    -- general number-appearance settings.
    local sizeLbl = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLbl:SetPoint("TOPLEFT", win, "TOPLEFT", M, -294)
    sizeLbl:SetText("|cff888888Number Size|r")

    local fontSliderLock = false
    local fontSlider = CreateFrame("Slider", nil, win)
    fontSlider:SetSize(110, 14)
    fontSlider:SetPoint("LEFT", sizeLbl, "RIGHT", 8, 0)
    fontSlider:SetOrientation("HORIZONTAL")
    fontSlider:SetMinMaxValues(8, 32)
    fontSlider:SetValueStep(1)

    local sliderTrack = fontSlider:CreateTexture(nil, "BACKGROUND")
    sliderTrack:SetAllPoints()
    sliderTrack:SetColorTexture(0.12, 0.12, 0.16, 1)
    ApplyBorder(fontSlider)

    local sliderThumb = fontSlider:CreateTexture(nil, "OVERLAY")
    sliderThumb:SetSize(8, 20)
    sliderThumb:SetColorTexture(PURPLE[1], PURPLE[2], PURPLE[3], 1)
    fontSlider:SetThumbTexture(sliderThumb)

    local sliderVal = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sliderVal:SetPoint("LEFT", fontSlider, "RIGHT", 8, 0)

    fontSlider:SetScript("OnValueChanged", function(self, val)
        if fontSliderLock then return end
        val = math.floor(val + 0.5)
        ColorCD_DB.fontSize = val
        sliderVal:SetText(val)
        ColorCD.UpdateAllColors()
    end)

    -- ── Font dropdown — built-in client fonts, plus every font registered
    -- with LibSharedMedia if some other loaded addon provides it.
    local fontLbl = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontLbl:SetPoint("TOPLEFT", win, "TOPLEFT", M, -322)
    fontLbl:SetText("|cff888888Font|r")

    local BUILTIN_FONTS = {
        { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
        { "Arial Narrow",  "Fonts\\ARIALN.TTF" },
        { "Morpheus",      "Fonts\\MORPHEUS.TTF" },
        { "Skurri",        "Fonts\\skurri.ttf" },
    }

    -- Some LSM-registered fonts (incomplete font packs, etc.) point at files
    -- that don't actually exist on disk — SetFont() throws on a missing file
    -- rather than failing gracefully, so validate before ever offering one.
    local fontValidator = CreateFont("ColorCDFontValidator")
    local function FontFileLoads(path)
        return path and pcall(fontValidator.SetFont, fontValidator, path, 12, "")
    end

    local function GetAvailableFonts()
        local list = { { "Default", nil } }  -- nil path = keep whatever face is already there
        local seen = {}
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local names = LSM:List("font") or {}
            table.sort(names)
            for _, name in ipairs(names) do
                local path = LSM:Fetch("font", name, true)
                if FontFileLoads(path) then
                    table.insert(list, { name, path })
                    seen[name] = true
                end
            end
        end
        for _, entry in ipairs(BUILTIN_FONTS) do
            if not seen[entry[1]] and FontFileLoads(entry[2]) then
                table.insert(list, entry)
            end
        end
        return list
    end

    local fontPreviewObjs = {}
    local function GetFontPreviewObj(name, path)
        if not fontPreviewObjs[name] then
            local safeName = "ColorCDFontPreview_" .. name:gsub("%W", "_")
            local obj = _G[safeName] or CreateFont(safeName)
            if not pcall(obj.SetFont, obj, path or "Fonts\\FRIZQT__.TTF", 13, "") then
                obj:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
            end
            fontPreviewObjs[name] = obj
        end
        return fontPreviewObjs[name]
    end

    local FONT_BTN_W, ITEM_H, MAX_VISIBLE = 160, 20, 8

    local fontBtn = CreateFrame("Button", nil, win)
    fontBtn:SetSize(FONT_BTN_W, 22)
    fontBtn:SetPoint("LEFT", fontLbl, "RIGHT", 8, 0)
    local fbBg = fontBtn:CreateTexture(nil, "BACKGROUND")
    fbBg:SetAllPoints(); fbBg:SetColorTexture(0.08, 0.08, 0.11, 1)
    ApplyBorder(fontBtn)
    local fbHl = fontBtn:CreateTexture(nil, "HIGHLIGHT")
    fbHl:SetAllPoints(); fbHl:SetColorTexture(PURPLE[1], PURPLE[2], PURPLE[3], 0.13)
    local fbLabel = fontBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fbLabel:SetPoint("LEFT", fontBtn, "LEFT", 6, 0)
    fbLabel:SetPoint("RIGHT", fontBtn, "RIGHT", -16, 0)
    fbLabel:SetJustifyH("LEFT")
    local fbArrow = fontBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fbArrow:SetPoint("RIGHT", fontBtn, "RIGHT", -5, 0)
    fbArrow:SetText("|cff888888\226\150\188|r")

    -- Floating dropdown panel — parented to UIParent so it isn't clipped by
    -- the settings window's own bounds when the list is long.
    local fontDrop = CreateFrame("Frame", nil, UIParent)
    fontDrop:SetSize(FONT_BTN_W, ITEM_H * MAX_VISIBLE + 8)
    fontDrop:SetFrameStrata("TOOLTIP")
    fontDrop:Hide()
    local fdBg = fontDrop:CreateTexture(nil, "BACKGROUND")
    fdBg:SetAllPoints(); fdBg:SetColorTexture(BG[1], BG[2], BG[3], 1)
    ApplyBorder(fontDrop)

    local fontScroll = CreateFrame("ScrollFrame", nil, fontDrop)
    fontScroll:SetPoint("TOPLEFT", fontDrop, "TOPLEFT", 4, -4)
    fontScroll:SetPoint("BOTTOMRIGHT", fontDrop, "BOTTOMRIGHT", -4, 4)
    local fontScrollChild = CreateFrame("Frame", nil, fontScroll)
    fontScrollChild:SetWidth(FONT_BTN_W - 8)
    fontScroll:SetScrollChild(fontScrollChild)

    fontDrop:EnableMouseWheel(true)
    fontDrop:SetScript("OnMouseWheel", function(_, delta)
        local cur = fontScroll:GetVerticalScroll()
        local maxScroll = fontScroll:GetVerticalScrollRange()
        fontScroll:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - delta * 3 * ITEM_H)))
    end)

    local fontList = GetAvailableFonts()
    local fontItems = {}

    local function SelectFont(name, path)
        ColorCD_DB.fontName = name
        ColorCD_DB.fontPath = path
        fbLabel:SetText(name)
        for _, item in ipairs(fontItems) do item.sel:SetShown(item.name == name) end
        ColorCD.UpdateAllColors()
        fontDrop:Hide()
    end

    for i, entry in ipairs(fontList) do
        local name, path = entry[1], entry[2]
        local item = CreateFrame("Button", nil, fontScrollChild)
        item.name = name
        item:SetHeight(ITEM_H)
        item:SetPoint("TOPLEFT",  fontScrollChild, "TOPLEFT",  0, -(i - 1) * ITEM_H)
        item:SetPoint("TOPRIGHT", fontScrollChild, "TOPRIGHT", 0, -(i - 1) * ITEM_H)

        local hl = item:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(PURPLE[1], PURPLE[2], PURPLE[3], 0.25)

        local sel = item:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints(); sel:SetColorTexture(PURPLE[1], PURPLE[2], PURPLE[3], 0.4)
        sel:Hide()
        item.sel = sel

        local lbl = item:CreateFontString(nil, "OVERLAY")
        lbl:SetPoint("LEFT", item, "LEFT", 4, 0)
        lbl:SetFontObject(GetFontPreviewObj(name, path))
        lbl:SetTextColor(0.9, 0.9, 0.9)
        lbl:SetText(name)

        item:SetScript("OnClick", function() SelectFont(name, path) end)
        fontItems[i] = item
    end
    fontScrollChild:SetHeight(#fontList * ITEM_H)

    fontBtn:SetScript("OnClick", function()
        if fontDrop:IsShown() then
            fontDrop:Hide()
        else
            fontDrop:ClearAllPoints()
            fontDrop:SetPoint("TOPLEFT", fontBtn, "BOTTOMLEFT", 0, -2)
            fontDrop:Show()
        end
    end)
    win:HookScript("OnHide", function() fontDrop:Hide() end)

    Div(win, -352)

    -- ── MINIMAP ───────────────────────────────────────────────────────────────
    SectionLabel(win, "MINIMAP", -362)

    cbMinimap = MakeCheckbox(win, "Show minimap button", -388)
    cbMinimap:SetScript("OnClick", function(self)
        local show = self:GetChecked() and true or false
        ColorCD_DB.minimapHide = not show
        ColorCD.MinimapButton:SetVisible(show)
    end)

    Div(win, -420)

    -- ── ADVANCED ──────────────────────────────────────────────────────────────
    SectionLabel(win, "ADVANCED", -430)

    StaticPopupDialogs["COLORCD_RESET_CONFIRM"] = {
        text         = "Reset all ColorCD settings to defaults?\nThis will reload the UI.",
        button1      = "Reset",
        button2      = "Cancel",
        OnAccept     = function() ColorCD_DB = nil; ReloadUI() end,
        timeout      = 0,
        whileDead    = true,
        hideOnEscape = true,
    }

    local restoreBtn = MakeBtn(win, "Restore All Defaults", 160, 26)
    restoreBtn:SetPoint("TOPLEFT", win, "TOPLEFT", M, -458)
    restoreBtn:SetScript("OnClick", function()
        StaticPopup_Show("COLORCD_RESET_CONFIRM")
    end)

    -- Credits
    local credits = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    credits:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -M, 10)
    credits:SetText("|cff444455Feedback & Bugreports:|r  |cff666677Discord: soundz1|r")

    -- ── Sync all controls when window opens ───────────────────────────────────
    win:SetScript("OnShow", function()
        local db = ColorCD.DB()
        cbEnable:SetChecked(db.enabled)
        cbMinimap:SetChecked(not db.minimapHide)
        local fsz = db.fontSize or 0
        fontSliderLock = true
        fontSlider:SetValue(fsz > 0 and fsz or 14)
        fontSliderLock = false
        sliderVal:SetText(fsz > 0 and fsz or "auto")
        swatchTex:SetColorTexture(db.colorR, db.colorG, db.colorB, 1)
        fbLabel:SetText(db.fontName or "Default")
        for _, item in ipairs(fontItems) do item.sel:SetShown(item.name == (db.fontName or "Default")) end
    end)
end

-- ── Thin Blizzard Settings panel (Escape → Options → AddOns → ColorCD) ────────
local function BuildPanel()
    local panel = CreateFrame("Frame")
    panel.name  = "ColorCD"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cffbb77ffColorCD|r  |cffaaaaaa-- by soundz|r")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("|cffaaaaaaCustom-colored action bar cooldown numbers.|r")

    local divTex = panel:CreateTexture(nil, "ARTWORK")
    divTex:SetColorTexture(0.25, 0.25, 0.30, 0.6)
    divTex:SetHeight(1)
    divTex:SetPoint("TOPLEFT",  panel, "TOPLEFT",  16, -56)
    divTex:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -56)

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(200, 26)
    openBtn:SetText("Open ColorCD Settings")
    openBtn:SetPoint("TOPLEFT", 16, -80)
    openBtn:SetScript("OnClick", function() ColorCD.ToggleWindow() end)

    return panel
end

-- ── Public API (called by ColorCD.lua on PLAYER_LOGIN) ───────────────────────
function ColorCD.BuildUI()
    BuildWindow()
    local panel = BuildPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "ColorCD")
        Settings.RegisterAddOnCategory(cat)
    end
end

function ColorCD.ToggleWindow()
    if not win then return end
    if win:IsShown() then win:Hide() else win:Show() end
end
