-- ColorCD by soundz
-- Custom-colored action bar cooldown numbers.
-- Options UI accessible via minimap button, /colorcd, or /ccd.

-- ── Saved variable & shared table ────────────────────────────────────────────
ColorCD_DB = ColorCD_DB or {}

local ColorCD = {}
_G.ColorCD   = ColorCD

-- Native countdown FontStrings from each injected cooldown frame.
ColorCD.overlays  = {}
-- Cooldown frames; used by PLAYER_REGEN_ENABLED to re-apply show state.
ColorCD.cooldowns = {}

-- IsAddOnLoaded moved to C_AddOns in TWW 12.0.
local IsAddOnLoaded = IsAddOnLoaded or (C_AddOns and C_AddOns.IsAddOnLoaded)


-- ── Saved variable defaults ───────────────────────────────────────────────────
local function DB()
    local db = ColorCD_DB
    if db.enabled        == nil then db.enabled        = true  end
    if db.colorR         == nil then db.colorR         = 1.0   end  -- default: yellow
    if db.colorG         == nil then db.colorG         = 1.0   end
    if db.colorB         == nil then db.colorB         = 0.0   end
    if db.urg1R          == nil then db.urg1R          = 1.0   end  -- medium: orange
    if db.urg1G          == nil then db.urg1G          = 0.50  end
    if db.urg1B          == nil then db.urg1B          = 0.0   end
    if db.urg2R          == nil then db.urg2R          = 1.0   end  -- critical: red
    if db.urg2G          == nil then db.urg2G          = 0.15  end
    if db.urg2B          == nil then db.urg2B          = 0.15  end
    if db.urg1Enabled    == nil then db.urg1Enabled    = true  end
    if db.urg2Enabled    == nil then db.urg2Enabled    = true  end
    if db.urg1Threshold  == nil then db.urg1Threshold  = 5     end
    if db.urg2Threshold  == nil then db.urg2Threshold  = 2     end
    if db.fontSize       == nil then db.fontSize       = 14    end
    if db.fontName       == nil then db.fontName       = "Default" end
    -- db.fontPath is intentionally left unset by default: nil means "keep
    -- whatever font face the number already has" (unchanged behavior).
    if db.minimapPos     == nil then db.minimapPos     = 220   end
    if db.minimapHide    == nil then db.minimapHide    = false end
    return db
end
ColorCD.DB = DB

-- ── Parse Blizzard's own rendered countdown text ─────────────────────────────
-- Reading the displayed number (instead of reconstructing timing from
-- GetCooldownTimes/GetCooldownDisplayDuration) is immune to both the secret-
-- value taint AND to procs/talents that shorten a cooldown mid-flight —
-- Blizzard's own ticker already accounts for those, we just have to read it.
local function ParseRemainingSeconds(text)
    if not text or text == "" then return nil end
    text = text:gsub(",", ".")  -- some locales render decimals with a comma
    local min, sec = text:match("^(%d+):(%d+)$")
    if min then return tonumber(min) * 60 + tonumber(sec) end
    return tonumber(text)
end

-- ── Shared font application ──────────────────────────────────────────────────
-- Used by UpdateAllColors, InjectColor's initial apply, and the per-cooldown
-- ticker, so the face/size resolution logic lives in exactly one place.
local function ApplyFont(nativeTxt, db, sz)
    if sz <= 0 then return end
    local curFace, _, flags = nativeTxt:GetFont()
    local face = db.fontPath or curFace
    -- Fontmancer (and similar global font-replacers) hook SetFont on every
    -- FontString and re-apply their own chosen font immediately afterward.
    -- This flag is Fontmancer's own documented opt-out — only claim it when
    -- the user picked an explicit font here; "Default" should stay subject
    -- to whatever the global replacer would otherwise do.
    if db.fontPath then
        nativeTxt.IsFontmancerPreview = true
    else
        nativeTxt.IsFontmancerPreview = nil
    end
    -- Defensive: a saved font path could go bad (font-providing addon
    -- disabled/updated, incomplete font pack) after being validated in the
    -- options UI. SetFont() throws on a missing file, so fall back to
    -- whatever face was already there rather than breaking the ticker.
    if face and not pcall(nativeTxt.SetFont, nativeTxt, face, sz, flags or "") then
        nativeTxt:SetFont(curFace, sz, flags or "")
    end
end

-- ── Live color + font-size update ────────────────────────────────────────────
function ColorCD.UpdateAllColors()
    local db = DB()
    local sz = db.fontSize or 0
    for _, nativeTxt in ipairs(ColorCD.overlays) do
        if db.enabled then
            nativeTxt:SetTextColor(db.colorR, db.colorG, db.colorB, 1)
        else
            nativeTxt:SetTextColor(1, 1, 1, 1)
        end
        ApplyFont(nativeTxt, db, sz)
    end
end

-- ── Ensure countdown numbers are visible (only safe to call outside combat) ───
function ColorCD.ApplyShowNumbers()
    for _, cd in ipairs(ColorCD.cooldowns) do
        pcall(function() cd:SetHideCountdownNumbers(false) end)
    end
end

-- ── Cooldown frame injection ──────────────────────────────────────────────────
local function InjectColor(cd)
    if cd._ccdInjected then return end

    -- Grab the native FontString the cooldown frame already owns.
    -- GetCountdownFontString has no security restrictions and works in combat.
    -- Some frames (Bartender4/ElvUI buttons built late, pet/stance buttons that
    -- haven't had SetCooldown called yet) don't have this ready on first scan —
    -- leave _ccdInjected unset so a later rescan retries them instead of
    -- permanently skipping color/urgency for that button.
    local nativeTxt = cd:GetCountdownFontString()
    if not nativeTxt then return end

    cd._ccdInjected = true
    ColorCD.cooldowns[#ColorCD.cooldowns + 1] = cd

    -- Ensure Blizzard's native countdown numbers are shown.
    -- SetHideCountdownNumbers is AllowedWhenUntainted only — skip during combat;
    -- the PLAYER_REGEN_ENABLED handler will catch any frames missed here.
    if not InCombatLockdown() then
        pcall(function() cd:SetHideCountdownNumbers(false) end)
    end

    ColorCD.overlays[#ColorCD.overlays + 1] = nativeTxt

    local db = DB()
    if db.enabled then
        nativeTxt:SetTextColor(db.colorR, db.colorG, db.colorB, 1)
    end
    ApplyFont(nativeTxt, db, db.fontSize or 0)

    -- Ticker parented to UIParent (non-secure) so OnUpdate fires even in combat.
    local ticker       = CreateFrame("Frame", nil, UIParent)
    local elapsed      = 0
    local lastSize     = db.fontSize or 0  -- tracks applied size/face to avoid redundant SetFont
    local lastFontPath = db.fontPath
    -- True once the current countdown text has been observed above the GCD's
    -- ~1.5s ceiling, meaning it must be a real cooldown. Reset whenever the
    -- text goes blank (finished/idle).
    local trackingReal = false

    ticker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.01 then return end  -- ~100/s: effectively instant, still cheap
        elapsed = 0

        local db = DB()
        if not db.enabled then
            nativeTxt:SetTextColor(1, 1, 1, 1)
            return
        end

        local sz = db.fontSize or 0
        if sz ~= lastSize or db.fontPath ~= lastFontPath then
            ApplyFont(nativeTxt, db, sz)
            lastSize     = sz
            lastFontPath = db.fontPath
        end

        local remaining = nil

        -- Cooldown timing becomes a Blizzard "secret" value in combat
        -- (Midnight's anti-automation protection) — reading it throws
        -- regardless of which API is used, and once shortened by a proc
        -- mid-fight there's no reliable way to track it from outside anyway.
        -- Rather than guess, urgency simply doesn't apply during combat; the
        -- number just shows your Normal color for the whole fight. The
        -- InCombatLockdown() check alone isn't a hard guarantee (the secret
        -- flag can apparently be set slightly outside what that reports), so
        -- the read itself stays pcall-wrapped no matter what — never crash,
        -- just fall back to Normal color if it turns out to be restricted.
        if not InCombatLockdown() then
            local ok, r = pcall(function()
                return ParseRemainingSeconds(nativeTxt:GetText())
            end)
            if not ok then r = nil end
            if not r then
                trackingReal = false
            elseif r > 1.6 then
                trackingReal = true
            end
            if trackingReal then remaining = r end
        end

        if remaining then
            if db.urg2Enabled and remaining <= (db.urg2Threshold or 2) then
                nativeTxt:SetTextColor(db.urg2R, db.urg2G, db.urg2B, 1)
            elseif db.urg1Enabled and remaining <= (db.urg1Threshold or 5) then
                nativeTxt:SetTextColor(db.urg1R, db.urg1G, db.urg1B, 1)
            else
                nativeTxt:SetTextColor(db.colorR, db.colorG, db.colorB, 1)
            end
        else
            nativeTxt:SetTextColor(db.colorR, db.colorG, db.colorB, 1)
        end
    end)
end
ColorCD.InjectColor = InjectColor  -- exposed so Options.lua can drive the preview icon

-- ── Standard Blizzard action bar button list ──────────────────────────────────
local BLIZZARD_BARS = {
    { "ActionButton",              12 },
    { "MultiBarBottomLeftButton",  12 },
    { "MultiBarBottomRightButton", 12 },
    { "MultiBarRightButton",       12 },
    { "MultiBarLeftButton",        12 },
    { "MultiBar5Button",           12 },
    { "MultiBar6Button",           12 },
    { "MultiBar7Button",           12 },
    { "PetActionButton",           10 },
    { "StanceButton",              10 },
    { "PossessButton",              2 },
}

-- ── Full bar scan: Blizzard + third-party addons ──────────────────────────────
local function ScanAndInject()
    -- Standard Blizzard bars
    for _, bar in ipairs(BLIZZARD_BARS) do
        local prefix, count = bar[1], bar[2]
        for i = 1, count do
            local btn = _G[prefix .. i]
            if btn and btn.cooldown then InjectColor(btn.cooldown) end
        end
    end

    -- Override / vehicle bars
    for i = 1, 12 do
        local btn = _G["OverrideActionBarButton" .. i]
        if btn and btn.cooldown then InjectColor(btn.cooldown) end
    end

    -- Bartender4 (10 bars × 12 buttons = 120)
    for i = 1, 120 do
        local btn = _G["BT4Button" .. i]
        if btn and btn.cooldown then InjectColor(btn.cooldown) end
    end

    -- ElvUI (10 bars × 12 buttons)
    for bar = 1, 10 do
        for slot = 1, 12 do
            local btn = _G["ElvUI_Bar" .. bar .. "Button" .. slot]
            if btn and btn.cooldown then InjectColor(btn.cooldown) end
        end
    end

    -- Dominos (14 bars × 12 = 168 buttons)
    if IsAddOnLoaded and IsAddOnLoaded("Dominos") then
        for i = 1, 168 do
            local btn = _G["DominosActionButton" .. i]
            if btn and btn.cooldown then InjectColor(btn.cooldown) end
        end
    end

    -- Generic: walk all frames and look for action buttons with cooldowns.
    -- Catches TukUI, Neuron, and any other bar addon not covered above.
    -- GetAttribute on protected frames causes taint in combat — skip the walk
    -- entirely if we're locked down; the named-bar pass above is combat-safe.
    if not InCombatLockdown() then
        local frame = EnumerateFrames()
        local n = 0
        while frame and n < 5000 do
            n = n + 1
            local ok, atype = pcall(frame.GetAttribute, frame, "type")
            if ok and atype == "action" and frame.cooldown then
                InjectColor(frame.cooldown)
            end
            frame = EnumerateFrames(frame)
        end
    end
end

-- ── Initialisation ────────────────────────────────────────────────────────────
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        -- Re-apply show state and run any generic walk skipped during combat.
        ColorCD.ApplyShowNumbers()
        ScanAndInject()
        return
    end

    if event == "PLAYER_LOGIN" then
        DB()  -- populate defaults now that SavedVariables are available
    end

    -- Scan on login, world entry, and bonus bar changes (vehicle mounting etc.)
    ScanAndInject()

    -- Delayed rescan: bar addons like ElvUI and Bartender4 finish building their
    -- buttons a frame or two after PLAYER_LOGIN / PLAYER_ENTERING_WORLD.
    -- If the timer fires in combat, fall back to PLAYER_REGEN_ENABLED for the
    -- generic walk (named-bar pass in ScanAndInject is always combat-safe).
    if C_Timer then
        C_Timer.After(2, ScanAndInject)
    end

    if event == "PLAYER_LOGIN" then
        ColorCD.MinimapButton:Initialize()
        ColorCD.BuildUI()
    end
end)

-- ── Slash commands ────────────────────────────────────────────────────────────
SLASH_COLORCD1 = "/colorcd"
SLASH_COLORCD2 = "/ccd"
SlashCmdList["COLORCD"] = function()
    ColorCD.ToggleWindow()
end
