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
    if db.fontSize       == nil then db.fontSize       = 14    end
    if db.fontName       == nil then db.fontName       = "Default" end
    -- db.fontPath is intentionally left unset by default: nil means "keep
    -- whatever font face the number already has" (unchanged behavior).
    if db.minimapPos     == nil then db.minimapPos     = 220   end
    if db.minimapHide    == nil then db.minimapHide    = false end
    return db
end
ColorCD.DB = DB

-- ── Shared font application ──────────────────────────────────────────────────
-- Used by UpdateAllColors, InjectColor's initial apply, and the shared
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
        pcall(cd.SetHideCountdownNumbers, cd, false)
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
    -- permanently skipping this button.
    local nativeTxt = cd:GetCountdownFontString()
    if not nativeTxt then return end

    cd._ccdInjected = true
    ColorCD.cooldowns[#ColorCD.cooldowns + 1] = cd

    -- Ensure Blizzard's native countdown numbers are shown.
    -- SetHideCountdownNumbers is AllowedWhenUntainted only — skip during combat;
    -- the PLAYER_REGEN_ENABLED handler will catch any frames missed here.
    if not InCombatLockdown() then
        pcall(cd.SetHideCountdownNumbers, cd, false)
    end

    local db = DB()
    if db.enabled then
        nativeTxt:SetTextColor(db.colorR, db.colorG, db.colorB, 1)
    end
    ApplyFont(nativeTxt, db, db.fontSize or 0)

    -- Per-overlay ticker state lives directly on the FontString, read/written
    -- by the single shared ticker below — see the comment there for why this
    -- replaced a CreateFrame+OnUpdate per cooldown.
    nativeTxt._ccdLastSize     = db.fontSize or 0  -- tracks applied size/face to avoid redundant SetFont
    nativeTxt._ccdLastFontPath = db.fontPath

    ColorCD.overlays[#ColorCD.overlays + 1] = nativeTxt
end
ColorCD.InjectColor = InjectColor  -- exposed so Options.lua can drive the preview icon

-- ── Single shared ticker for every injected cooldown ─────────────────────────
-- Blizzard's cooldown widget periodically resets the countdown text back to its
-- default colour, so the colour has to be re-asserted rather than set once.
-- This used to be a CreateFrame+OnUpdate per cooldown; one shared ticker
-- replaced 100+ dispatches per rendered frame with a single one.
--
-- The shared ticker still re-applied SetTextColor to every overlay on every
-- tick, running or not: ~125 buttons on the default bars alone, ~100 times a
-- second, permanently. Blizzard's profiler put ColorCD's steady cost at about
-- 2ms per frame because of it. Skipping overlays that are not visible cuts
-- nearly all of that: a button with no cooldown running has no countdown text
-- to colour, and that is the overwhelming majority of them at any moment.
--
-- Do NOT try to skip the SetTextColor call by reading the current colour back
-- and comparing it. GetTextColor() on these FontStrings returns secret values
-- under 12.x, and comparing a secret raises "attempt to compare local 'r' (a
-- secret number value)" on every tick for every visible overlay. Caching what
-- we last set is no substitute either -- the whole reason this ticker exists is
-- that Blizzard changes the colour behind our back, so a cache would go stale
-- exactly when re-applying matters.
local ticker        = CreateFrame("Frame", nil, UIParent)
local tickerElapsed = 0
local TICK_INTERVAL = 0.01   -- ~100/s, shared across every overlay
ticker:SetScript("OnUpdate", function(_, dt)
    tickerElapsed = tickerElapsed + dt
    if tickerElapsed < TICK_INTERVAL then return end
    tickerElapsed = 0

    local overlays = ColorCD.overlays
    local db = DB()
    if not db.enabled then
        for i = 1, #overlays do
            local nativeTxt = overlays[i]
            if nativeTxt:IsVisible() then
                nativeTxt:SetTextColor(1, 1, 1, 1)
            end
        end
        return
    end

    local sz = db.fontSize or 0
    local cr, cg, cb = db.colorR, db.colorG, db.colorB
    for i = 1, #overlays do
        local nativeTxt = overlays[i]
        if nativeTxt:IsVisible() then
            if sz ~= nativeTxt._ccdLastSize or db.fontPath ~= nativeTxt._ccdLastFontPath then
                ApplyFont(nativeTxt, db, sz)
                nativeTxt._ccdLastSize     = sz
                nativeTxt._ccdLastFontPath = db.fontPath
            end
            nativeTxt:SetTextColor(cr, cg, cb, 1)
        end
    end
end)

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
-- fullScan gates the generic EnumerateFrames walk below (see its own comment)
-- — pass true for login/world-entry/combat-exit, false for high-frequency
-- events like UPDATE_BONUS_ACTIONBAR where the named-bar passes already give
-- full coverage cheaply.
local lastFullWalk = 0
-- True once the expensive walk has succeeded since the last loading screen.
-- New bar-addon frames only ever appear right after a loading screen (zone
-- change, relog, UI reload) — never mid-session just from leaving combat —
-- so once a walk has completed for the current world, PLAYER_REGEN_ENABLED
-- doesn't need to pay for another one. This is what previously turned every
-- arena/BG combat-exit into a 5000-frame EnumerateFrames walk.
local fullScanDone = false
-- ── Generic frame walk (fallback discovery) ──────────────────────────────────
-- Catches TukUI, Neuron, and any other bar addon the named passes above miss.
--
-- It is also the single most expensive thing this addon does, and Blizzard's
-- own profiler (C_AddOnProfiler, read via StutterAlert) measured what that
-- costs: 47 hitch frames averaging ~60ms with ColorCD accounting for ~61% of
-- the frame, 45 of them in cities, and the dominant signature was "no event
-- firing" -- i.e. the C_Timer.After(2, ...) rescan landing on a quiet frame and
-- burning the whole traversal there in one go.
--
-- Three changes so it is not paid for speculatively:
--   * NeedsGenericWalk() skips it when Blizzard's own bars are visible, since
--     the named passes already cover every button in that case;
--   * it runs in chunks across frames instead of all at once;
--   * fullScanDone (above) already limits it to once per loading screen.
local FRAMES_PER_CHUNK = 100
local MAX_FRAMES       = 5000
local CHUNK_DELAY      = 0.01   -- deliberately not 0: a zero-delay timer queued
                                -- from inside a timer callback can be picked up
                                -- by the same tick's processing pass, which
                                -- collapses the walk back into a single frame.
local walkInProgress = false

local function ContinueWalk(frame, n)
    -- Bail out if we entered combat mid-walk: GetAttribute on protected frames
    -- taints in combat, which is why the walk is combat-gated to begin with.
    if InCombatLockdown() then
        walkInProgress = false
        return
    end
    local processed = 0
    while frame and n < MAX_FRAMES and processed < FRAMES_PER_CHUNK do
        n = n + 1
        processed = processed + 1
        local ok, atype = pcall(frame.GetAttribute, frame, "type")
        if ok and atype == "action" and frame.cooldown then
            InjectColor(frame.cooldown)
        end
        frame = EnumerateFrames(frame)
    end
    if frame and n < MAX_FRAMES then
        if C_Timer then
            C_Timer.After(CHUNK_DELAY, function() ContinueWalk(frame, n) end)
        else
            ContinueWalk(frame, n)  -- no C_Timer: finish rather than stop short
        end
    else
        walkInProgress = false
    end
end

-- Blizzard's main bar being visible means the player is on the default bars,
-- which the named pass covers button for button. Bar addons that replace them
-- hide these frames.
local function NeedsGenericWalk()
    local ab1 = _G.ActionButton1
    if ab1 and ab1:IsShown() then return false end
    return true
end

local function StartGenericWalk()
    if walkInProgress or fullScanDone or InCombatLockdown() then return end
    if not EnumerateFrames or not NeedsGenericWalk() then return end
    if (GetTime() - lastFullWalk) < 3 then return end
    lastFullWalk   = GetTime()
    fullScanDone   = true
    walkInProgress = true
    ContinueWalk(EnumerateFrames(), 0)
end

local function ScanAndInject(fullScan)
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
    -- Fallback discovery for bar addons not named above.  Skipped entirely on
    -- Blizzard's own bars, at most once per loading screen, and chunked across
    -- frames when it does run -- see the StartGenericWalk block above.
    if fullScan then StartGenericWalk() end
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
        ScanAndInject(true)
        return
    end

    if event == "PLAYER_LOGIN" then
        DB()  -- populate defaults now that SavedVariables are available
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- New loading screen: bar addons may have rebuilt their frames.
        fullScanDone = false
    end

    -- Scan on login, world entry, and bonus bar changes (vehicle mounting etc.).
    -- UPDATE_BONUS_ACTIONBAR can fire repeatedly in quick succession (Druid
    -- form-shifting, vehicle mounts) — only give login/world-entry the
    -- expensive full generic-frame walk; that event gets the cheap named-bar
    -- passes only (see ScanAndInject's fullScan comment).
    ScanAndInject(event ~= "UPDATE_BONUS_ACTIONBAR")

    -- Delayed rescan: bar addons like ElvUI and Bartender4 finish building their
    -- buttons a frame or two after PLAYER_LOGIN / PLAYER_ENTERING_WORLD.
    -- If the timer fires in combat, fall back to PLAYER_REGEN_ENABLED for the
    -- generic walk (named-bar pass in ScanAndInject is always combat-safe).
    if C_Timer then
        C_Timer.After(2, function() ScanAndInject(true) end)
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
