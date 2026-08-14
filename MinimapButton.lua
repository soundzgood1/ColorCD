-- ColorCD: Minimap button (no external library required)

local MINIMAP_RADIUS = 80   -- pixel distance from Minimap center

-- ── Button frame (created at load time; Minimap always exists) ────────────────
local btn = CreateFrame("Button", "ColorCDMinimapButton", Minimap)
btn:SetSize(16, 16)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
btn:RegisterForDrag("LeftButton")
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- CD icon texture
local iconTex = btn:CreateTexture(nil, "BACKGROUND")
iconTex:SetTexture("Interface\\AddOns\\ColorCD\\Media\\cd_icon.png")
iconTex:SetAllPoints(btn)


-- ── Position helper ───────────────────────────────────────────────────────────
local function UpdatePosition()
    local angle = math.rad(ColorCD_DB.minimapPos or 220)
    btn:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * MINIMAP_RADIUS,
        math.sin(angle) * MINIMAP_RADIUS)
end

-- ── Drag to reposition around the minimap ────────────────────────────────────
btn:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local scale  = UIParent:GetScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        ColorCD_DB.minimapPos = math.deg(math.atan2(cy - my, cx - mx))
        UpdatePosition()
    end)
end)

btn:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

-- ── Clicks ────────────────────────────────────────────────────────────────────
btn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        ColorCD.ToggleWindow()
    end
end)

-- ── Tooltip ───────────────────────────────────────────────────────────────────
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ColorCD", 0.65, 0.20, 1.0)
    GameTooltip:AddLine("Click: open settings", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag: reposition button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ── Public API (called by ColorCD.lua after PLAYER_LOGIN) ────────────────────
local MinimapButton = {}
ColorCD.MinimapButton = MinimapButton

function MinimapButton:Initialize()
    local db = ColorCD.DB()
    UpdatePosition()
    if db.minimapHide then
        btn:Hide()
    else
        btn:Show()
    end
end

function MinimapButton:SetVisible(visible)
    if visible then btn:Show() else btn:Hide() end
end
