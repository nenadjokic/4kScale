-- 4kScale: Pixel-perfect UI scaling for 4K/ultrawide monitors
-- Author: Nenad

local ADDON_NAME = "4kScale"
local UI_MIN_SCALE = 0.20
local UI_MAX_SCALE = 1.00
local ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Spyglass_03"
local ACCENT = "00CCFF"   -- cyan accent color
local PREFIX = "|cFF" .. ACCENT .. "4kScale:|r "

-- ============================================================
-- SAVED VARIABLES
-- ============================================================

local defaults = {
    autoApply = true,
    minimapAngle = 4.2,
    minimapHidden = false,
    profiles = {},       -- ["3024x1964"] = 0.45
}

local db

local function GetDB()
    if not FourKScaleDB then FourKScaleDB = {} end
    for k, v in pairs(defaults) do
        if FourKScaleDB[k] == nil then
            FourKScaleDB[k] = v
        end
    end
    if not FourKScaleDB.profiles then FourKScaleDB.profiles = {} end
    db = FourKScaleDB
    return db
end

-- ============================================================
-- RESOLUTION DETECTION
-- ============================================================

local function GetResolutionInfo()
    local w, h
    if GetPhysicalScreenSize then
        w, h = GetPhysicalScreenSize()
    end
    if (not w or w <= 0) and GetScreenResolutions then
        local idx = GetCurrentResolution()
        if idx and idx > 0 then
            local res = select(idx, GetScreenResolutions())
            if res then
                w, h = res:match("^(%d+)x(%d+)$")
                w, h = tonumber(w), tonumber(h)
            end
        end
    end
    if not w or w <= 0 then
        local cv = GetCVar("gxWindowedResolution") or GetCVar("gxResolution") or ""
        w, h = cv:match("^(%d+)x(%d+)$")
        w, h = tonumber(w), tonumber(h)
    end
    if not w or not h or w <= 0 or h <= 0 then
        return "unknown", 0, 0
    end
    return w .. "x" .. h, w, h
end

local function GetPixelPerfectScale(height)
    if not height or height <= 0 then return nil end
    return 768 / height
end

-- Smart recommended scale based on resolution and typical monitor sizes
local function GetRecommendedScale(w, h)
    if not w or not h or h <= 0 then return nil, nil end
    local pp = 768 / h
    -- Detect monitor type by resolution and recommend comfortable scale
    -- MacBook Pro 14" (3024x1964 or similar ~3k Retina)
    if w >= 2800 and w <= 3200 and h >= 1800 and h <= 2000 then
        return 0.60, "Laptop 14\""
    end
    -- MacBook Pro 16" (3456x2234)
    if w >= 3400 and w <= 3500 and h >= 2200 and h <= 2300 then
        return 0.55, "Laptop 16\""
    end
    -- 4K (3840x2160) - could be 27" or 32"
    if w >= 3800 and w <= 3900 and h >= 2100 and h <= 2200 then
        return 0.58, "4K Monitor"
    end
    -- Ultrawide 3440x1440
    if w >= 3400 and w <= 3500 and h >= 1400 and h <= 1500 then
        return 0.71, "Ultrawide"
    end
    -- 1440p (2560x1440)
    if w >= 2500 and w <= 2600 and h >= 1400 and h <= 1500 then
        return 0.85, "1440p"
    end
    -- 1080p
    if h >= 1000 and h <= 1100 then
        return 1.00, "1080p"
    end
    -- Generic: use pixel-perfect but clamp to at least 0.45
    return math.max(pp, 0.45), nil
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Round(v, decimals)
    local m = 10 ^ (decimals or 4)
    return math.floor(v * m + 0.5) / m
end

-- ============================================================
-- SCALE APPLICATION (taint-safe)
-- ============================================================

local pendingApply = false

local function ApplyScale(desired)
    desired = Clamp(desired, UI_MIN_SCALE, UI_MAX_SCALE)
    C_Timer.After(0, function()
        if InCombatLockdown and InCombatLockdown() then
            pendingApply = true
            return
        end
        UIParent:SetScale(desired)
        pendingApply = false
    end)
end

local function GetCurrentScale()
    return UIParent:GetScale()
end

local function GetSavedScale()
    local key, w, h = GetResolutionInfo()
    local s = db.profiles[key]
    s = tonumber(s)
    if not s or s <= 0 then return nil, key, w, h end
    return s, key, w, h
end

local function SaveAndApply(value)
    value = Clamp(Round(value, 4), UI_MIN_SCALE, UI_MAX_SCALE)
    local key = GetResolutionInfo()
    db.profiles[key] = value
    ApplyScale(value)
    return value, key
end

-- ============================================================
-- UI HELPERS
-- ============================================================

-- ============================================================
-- UI HELPERS (premium design layer)
-- ============================================================

-- 1-pixel horizontal rule
local function CreateDivider(parent, yOffset)
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  parent, "TOPLEFT",  1, yOffset)
    div:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, yOffset)
    div:SetColorTexture(0.0, 0.75, 1.0, 0.12)
    return div
end

-- Section caption (small all-caps label used as section heading)
local function CreateCaption(parent, text, xOff, yOffset)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOffset)
    lbl:SetText(text)
    lbl:SetTextColor(0.35, 0.42, 0.50)
    return lbl
end

-- Custom toggle switch: returns { frame, :SetChecked(bool), :GetChecked(), .OnChange }
local function CreateToggle(parent)
    local TW, TH = 30, 14
    local KS = TH - 2

    local hit = CreateFrame("Button", nil, parent)
    hit:SetSize(TW + 6, TH + 10)

    local track = hit:CreateTexture(nil, "BACKGROUND")
    track:SetSize(TW, TH)
    track:SetPoint("CENTER", 0, 0)
    track:SetColorTexture(0.11, 0.12, 0.17, 1.0)

    local trackOn = hit:CreateTexture(nil, "BORDER")
    trackOn:SetSize(TW, TH)
    trackOn:SetPoint("CENTER", 0, 0)
    trackOn:SetColorTexture(0.0, 0.78, 1.0, 0.0)

    local knob = hit:CreateTexture(nil, "OVERLAY")
    knob:SetSize(KS, KS)
    knob:SetColorTexture(0.40, 0.41, 0.46, 1.0)

    local checked = false
    local function Redraw()
        if checked then
            trackOn:SetColorTexture(0.0, 0.75, 1.0, 0.40)
            knob:SetColorTexture(0.0, 0.84, 1.0, 1.0)
            knob:SetPoint("CENTER", hit, "CENTER",  (TW / 2) - (KS / 2) - 1, 0)
        else
            trackOn:SetColorTexture(0.0, 0.75, 1.0, 0.0)
            knob:SetColorTexture(0.38, 0.39, 0.44, 1.0)
            knob:SetPoint("CENTER", hit, "CENTER", -(TW / 2) + (KS / 2) + 1, 0)
        end
    end

    local obj = { frame = hit }
    function obj:SetChecked(v) checked = not not v; Redraw() end
    function obj:GetChecked() return checked end
    hit:SetScript("OnClick", function()
        checked = not checked; Redraw()
        if obj.OnChange then obj.OnChange(checked) end
    end)
    Redraw()
    return obj
end

-- Custom backdrop-style button with explicit color control
local function MakeFlatBtn(parent, w, h, bgR, bgG, bgB, brR, brG, brB)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    btn:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(bgR, bgG, bgB, 1.0)
    btn:SetBackdropBorderColor(brR, brG, brB, 1.0)
    return btn
end

-- ============================================================
-- OPTIONS PANEL
-- ============================================================

local optionsFrame

local function CreateOptionsFrame()
    if optionsFrame then return optionsFrame end

    -- Layout constants
    local PW     = 300     -- panel width
    local PH     = 374     -- panel height
    local HH     = 38      -- header height
    local PAD    = 14      -- horizontal padding
    local CR, CG, CB = 0.0, 0.80, 1.0   -- cyan accent

    -- ── Root frame ────────────────────────────────────────────────────────
    local f = CreateFrame("Frame", "FourKScaleOptions", UIParent, "BackdropTemplate")
    f:SetSize(PW, PH)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    -- Near-black body, tight muted border
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.052, 0.056, 0.088, 0.97)
    f:SetBackdropBorderColor(0.09, 0.10, 0.15, 1.0)

    -- ── Header band ───────────────────────────────────────────────────────
    local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
    hdr:SetSize(PW - 2, HH)
    hdr:SetPoint("TOPLEFT", 1, -1)
    hdr:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    hdr:SetBackdropColor(0.030, 0.034, 0.060, 1.0)

    -- Header bottom separator (dim cyan line)
    local hdrSep = hdr:CreateTexture(nil, "OVERLAY")
    hdrSep:SetHeight(1)
    hdrSep:SetPoint("BOTTOMLEFT",  0, 0)
    hdrSep:SetPoint("BOTTOMRIGHT", 0, 0)
    hdrSep:SetColorTexture(CR, CG, CB, 0.28)

    -- Left accent stripe (solid 3px cyan)
    local stripe = hdr:CreateTexture(nil, "OVERLAY")
    stripe:SetSize(3, HH)
    stripe:SetPoint("TOPLEFT", 0, 0)
    stripe:SetColorTexture(CR, CG, CB, 1.0)

    -- Header icon (cyan-tinted)
    local hdrIcon = hdr:CreateTexture(nil, "ARTWORK")
    hdrIcon:SetSize(18, 18)
    hdrIcon:SetPoint("LEFT", 3 + 10, 0)
    hdrIcon:SetTexture(ICON_TEXTURE)
    hdrIcon:SetVertexColor(CR, CG, CB, 1.0)

    -- Title
    local titleTxt = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleTxt:SetPoint("LEFT", hdrIcon, "RIGHT", 7, 0)
    titleTxt:SetText("|cFF00CCFF4kScale|r")

    -- Subtitle (muted)
    local subTxt = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subTxt:SetPoint("LEFT", titleTxt, "RIGHT", 8, -1)
    subTxt:SetText("|cFF253545pixel-perfect scaling|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, hdr)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", -6, 0)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("|cFF555566x|r")
    closeBtn:SetScript("OnClick",  function() f:Hide() end)
    closeBtn:SetScript("OnEnter",  function() closeTxt:SetText("|cFFFF5566x|r") end)
    closeBtn:SetScript("OnLeave",  function() closeTxt:SetText("|cFF555566x|r") end)

    -- ── Resolution row ────────────────────────────────────────────────────
    local RES_Y = -(HH + 10)

    CreateCaption(f, "RESOLUTION", PAD, RES_Y)

    local resValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resValue:SetPoint("TOPRIGHT", -PAD, RES_Y)
    resValue:SetJustifyH("RIGHT")
    f.resValue = resValue

    -- Current scale (small, right of resolution label)
    local curScaleLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    curScaleLbl:SetPoint("TOPRIGHT", resValue, "BOTTOMRIGHT", 0, -2)
    curScaleLbl:SetJustifyH("RIGHT")
    curScaleLbl:SetTextColor(0.38, 0.44, 0.50)
    f.curScaleLbl = curScaleLbl

    CreateDivider(f, RES_Y - 14)

    -- ── Toggle rows ───────────────────────────────────────────────────────
    local T1_Y = RES_Y - 24
    local T2_Y = T1_Y - 25

    local autoToggle = CreateToggle(f)
    autoToggle.frame:SetPoint("TOPRIGHT", -PAD, T1_Y)
    local autoLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoLbl:SetPoint("TOPLEFT", PAD, T1_Y - 1)
    autoLbl:SetText("Auto-apply on login")
    autoLbl:SetTextColor(0.76, 0.78, 0.82)
    f.autoToggle = autoToggle

    local mmToggle = CreateToggle(f)
    mmToggle.frame:SetPoint("TOPRIGHT", -PAD, T2_Y)
    local mmLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmLbl:SetPoint("TOPLEFT", PAD, T2_Y - 1)
    mmLbl:SetText("Minimap button")
    mmLbl:SetTextColor(0.76, 0.78, 0.82)
    f.mmToggle = mmToggle

    CreateDivider(f, T2_Y - 15)

    -- ── Scale section ─────────────────────────────────────────────────────
    local SC_Y = T2_Y - 25

    CreateCaption(f, "UI SCALE", PAD, SC_Y)

    -- Large readout (current value, right-aligned, cyan)
    local scReadout = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    scReadout:SetPoint("TOPRIGHT", -PAD, SC_Y)
    scReadout:SetJustifyH("RIGHT")
    scReadout:SetTextColor(CR, CG, CB)
    f.scReadout = scReadout

    -- Progress bar track (dark) + fill (cyan)
    local TRACK_Y = SC_Y - 17
    local TRACK_H = 5
    local TRACK_W = PW - PAD * 2

    local barTrack = f:CreateTexture(nil, "ARTWORK")
    barTrack:SetSize(TRACK_W, TRACK_H)
    barTrack:SetPoint("TOPLEFT", PAD, TRACK_Y)
    barTrack:SetColorTexture(0.08, 0.09, 0.14, 1.0)

    local barFill = f:CreateTexture(nil, "OVERLAY")
    barFill:SetHeight(TRACK_H)
    barFill:SetPoint("TOPLEFT", PAD, TRACK_Y)
    barFill:SetColorTexture(CR, CG, CB, 0.70)
    f.barFill  = barFill
    f.TRACK_W  = TRACK_W

    -- Invisible slider (sits over the bar, handles drag input)
    local slider = CreateFrame("Slider", "FourKScaleSlider", f, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", PAD - 4, TRACK_Y - 4)
    slider:SetSize(TRACK_W + 8, 17)
    slider:SetMinMaxValues(UI_MIN_SCALE, UI_MAX_SCALE)
    slider:SetValueStep(0.005)
    slider:SetObeyStepOnDrag(true)
    slider:SetAlpha(0.001)
    FourKScaleSliderLow:SetText("")
    FourKScaleSliderHigh:SetText("")
    FourKScaleSliderText:SetText("")
    f.slider = slider

    -- Pixel-perfect / recommendation hint (below bar)
    local ppHint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ppHint:SetPoint("TOPLEFT", PAD, TRACK_Y - 12)
    ppHint:SetTextColor(0.30, 0.36, 0.44)
    f.ppHint = ppHint

    -- Numeric input box
    local INPUT_Y = TRACK_Y - 28
    local input = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    input:SetSize(68, 22)
    input:SetPoint("TOPLEFT", PAD, INPUT_Y)
    input:SetAutoFocus(false)
    input:SetMaxLetters(6)
    input:SetJustifyH("CENTER")
    f.input = input

    local inputHint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inputHint:SetPoint("LEFT", input, "RIGHT", 7, 0)
    inputHint:SetTextColor(0.26, 0.31, 0.38)
    inputHint:SetText("[Enter] to set")

    CreateDivider(f, INPUT_Y - 28)

    -- ── Preset buttons (5-column single row) ─────────────────────────────
    local PR_Y  = INPUT_Y - 34
    local BPAD  = 4
    local PRESETS = {
        { label = "Compact",  scale = 0.40 },
        { label = "Small",    scale = 0.45 },
        { label = "Medium",   scale = 0.64 },
        { label = "Large",    scale = 0.80 },
        { label = "Default",  scale = 1.00 },
    }
    local BTN_W = math.floor((PW - PAD * 2 - BPAD * (#PRESETS - 1)) / #PRESETS)
    local BTN_H = 24

    CreateCaption(f, "PRESETS", PAD, PR_Y)

    local presetButtons = {}
    local syncing = false        -- forward-declare (used by SetSliderValue closure)
    local SetSliderValue         -- forward-declare so preset OnClick closures can reference it

    for i, preset in ipairs(PRESETS) do
        local xOff = PAD + (i - 1) * (BTN_W + BPAD)
        local btn  = MakeFlatBtn(f, BTN_W, BTN_H,
            0.07, 0.08, 0.12,     -- bg
            0.12, 0.14, 0.20)     -- border
        btn:SetPoint("TOPLEFT", xOff, PR_Y - 12)

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("CENTER")
        lbl:SetText(preset.label)
        lbl:SetTextColor(0.62, 0.67, 0.76)
        btn.label = lbl
        btn.presetScale = preset.scale

        -- Cyan top accent line (hidden by default)
        local acTop = btn:CreateTexture(nil, "OVERLAY")
        acTop:SetHeight(1)
        acTop:SetPoint("TOPLEFT",  2, -2)
        acTop:SetPoint("TOPRIGHT", -2, -2)
        acTop:SetColorTexture(CR, CG, CB, 0.0)
        btn.acTop = acTop

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.10, 0.12, 0.18, 1.0)
            self:SetBackdropBorderColor(0.18, 0.22, 0.34, 1.0)
            lbl:SetTextColor(0.88, 0.92, 0.98)
            acTop:SetColorTexture(CR, CG, CB, 0.65)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(preset.label, CR, CG, CB)
            GameTooltip:AddLine(string.format("Sets scale to %.2f", preset.scale), 0.70, 0.70, 0.70, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.07, 0.08, 0.12, 1.0)
            self:SetBackdropBorderColor(0.12, 0.14, 0.20, 1.0)
            lbl:SetTextColor(0.62, 0.67, 0.76)
            acTop:SetColorTexture(CR, CG, CB, 0.0)
            GameTooltip:Hide()
        end)
        btn:SetScript("OnClick", function(self)
            SetSliderValue(self.presetScale)
        end)

        presetButtons[i] = btn
    end
    f.presetButtons = presetButtons

    CreateDivider(f, PR_Y - 12 - BTN_H - 8)

    -- ── Action buttons (2 rows) ──────────────────────────────────────────
    local BTN_ROW_Y = 10   -- bottom row offset
    local BTN_ROW2_Y = 42  -- top row offset

    -- Bottom row: Save+Apply (wide, cyan)
    local SAVE_W = PW - PAD * 2

    local applyBtn = MakeFlatBtn(f, SAVE_W, 26,
        0.0, 0.14, 0.22,
        CR * 0.60, CG * 0.60, CB * 0.60)
    applyBtn:SetPoint("BOTTOMLEFT", PAD, BTN_ROW_Y)
    local applyLbl = applyBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    applyLbl:SetPoint("CENTER")
    applyLbl:SetText("Save + Apply")
    applyLbl:SetTextColor(CR, CG, CB)
    applyBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.0, 0.20, 0.30, 1.0)
        self:SetBackdropBorderColor(CR, CG, CB, 1.0)
    end)
    applyBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.0, 0.14, 0.22, 1.0)
        self:SetBackdropBorderColor(CR * 0.60, CG * 0.60, CB * 0.60, 1.0)
    end)

    -- Top row: Suggested | Profiles | Reset
    local INNER_W = PW - PAD * 2
    local SUG_W = math.floor(INNER_W * 0.40)
    local PROF_W = math.floor(INNER_W * 0.33)
    local RST_W = INNER_W - SUG_W - PROF_W - BPAD * 2

    -- Suggested button (green-tinted, auto-detects monitor)
    local sugBtn = MakeFlatBtn(f, SUG_W, 24,
        0.05, 0.14, 0.07,
        0.12, 0.35, 0.15)
    sugBtn:SetPoint("BOTTOMLEFT", PAD, BTN_ROW2_Y)
    local sugLbl = sugBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sugLbl:SetPoint("CENTER")
    sugLbl:SetTextColor(0.30, 0.90, 0.38)
    f.sugBtn = sugBtn
    f.sugLbl = sugLbl
    sugBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.07, 0.20, 0.09, 1.0)
        self:SetBackdropBorderColor(0.18, 0.55, 0.22, 1.0)
    end)
    sugBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.05, 0.14, 0.07, 1.0)
        self:SetBackdropBorderColor(0.12, 0.35, 0.15, 1.0)
    end)

    -- Profiles dropdown button (cyan outline)
    local recBtn = MakeFlatBtn(f, PROF_W, 24,
        0.06, 0.08, 0.12,
        0.10, 0.20, 0.28)
    recBtn:SetPoint("BOTTOMLEFT", PAD + SUG_W + BPAD, BTN_ROW2_Y)
    local recLbl = recBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recLbl:SetPoint("CENTER")
    recLbl:SetText("Profiles v")
    recLbl:SetTextColor(0.5, 0.7, 0.8)
    recBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.08, 0.12, 0.18, 1.0)
        self:SetBackdropBorderColor(0.15, 0.35, 0.50, 1.0)
    end)
    recBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.06, 0.08, 0.12, 1.0)
        self:SetBackdropBorderColor(0.10, 0.20, 0.28, 1.0)
    end)

    -- ── Monitor profiles dropdown ─────────────────────────────────────────
    local MONITOR_PROFILES = {
        { header = "MacBook" },
        { label = "MacBook Air 13\"",      scale = 0.64 },
        { label = "MacBook Pro 14\"",      scale = 0.60 },
        { label = "MacBook Pro 16\"",      scale = 0.55 },
        { header = "4K Monitors (3840x2160)" },
        { label = "24\" 4K",               scale = 0.64 },
        { label = "27\" 4K",               scale = 0.58 },
        { label = "32\" 4K",               scale = 0.53 },
        { label = "40\"+ 4K",              scale = 0.45 },
        { header = "Ultrawide" },
        { label = "34\" UWQHD (3440x1440)", scale = 0.71 },
        { label = "38\" UW (3840x1600)",    scale = 0.60 },
        { header = "Other" },
        { label = "1440p 27\"",            scale = 0.85 },
        { label = "1080p",                 scale = 1.00 },
        { label = "Pixel-Perfect",         scale = nil },  -- special: calculated
    }

    local dropdown
    local function CreateDropdown()
        if dropdown then return dropdown end
        local ROW_H = 22
        local HDR_H = 20
        local DD_W = 220

        -- Count total height
        local totalH = 12  -- padding
        for _, item in ipairs(MONITOR_PROFILES) do
            totalH = totalH + (item.header and HDR_H or ROW_H)
        end
        totalH = totalH + 6

        local dd = CreateFrame("Frame", "FourKScaleDropdown", f, "BackdropTemplate")
        dd:SetSize(DD_W, totalH)
        dd:SetFrameStrata("TOOLTIP")
        dd:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        dd:SetBackdropColor(0.04, 0.04, 0.08, 0.97)
        dd:SetBackdropBorderColor(0.12, 0.35, 0.15, 0.8)

        local yOff = -6
        for _, item in ipairs(MONITOR_PROFILES) do
            if item.header then
                -- Section header
                local hdr = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                hdr:SetPoint("TOPLEFT", 10, yOff)
                hdr:SetText("|cFF" .. ACCENT .. item.header .. "|r")
                yOff = yOff - HDR_H
            else
                -- Clickable row
                local row = CreateFrame("Button", nil, dd)
                row:SetSize(DD_W - 8, ROW_H)
                row:SetPoint("TOPLEFT", 4, yOff)

                local rowBg = row:CreateTexture(nil, "BACKGROUND")
                rowBg:SetAllPoints()
                rowBg:SetColorTexture(0, 0, 0, 0)

                local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rowLabel:SetPoint("LEFT", 8, 0)
                rowLabel:SetText(item.label)
                rowLabel:SetTextColor(0.72, 0.76, 0.82)

                local rowScale = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                rowScale:SetPoint("RIGHT", -8, 0)
                if item.scale then
                    rowScale:SetText("|cFF888888" .. string.format("%.2f", item.scale) .. "|r")
                else
                    rowScale:SetText("|cFF888888auto|r")
                end

                row:SetScript("OnEnter", function()
                    rowBg:SetColorTexture(0.0, 0.4, 0.5, 0.25)
                    rowLabel:SetTextColor(1, 1, 1)
                end)
                row:SetScript("OnLeave", function()
                    rowBg:SetColorTexture(0, 0, 0, 0)
                    rowLabel:SetTextColor(0.72, 0.76, 0.82)
                end)
                row:SetScript("OnClick", function()
                    local s = item.scale
                    if not s then
                        -- Pixel-perfect
                        local _, _, h = GetResolutionInfo()
                        s = GetPixelPerfectScale(h)
                    end
                    if s then
                        SetSliderValue(s)
                    end
                    dd:Hide()
                end)
                yOff = yOff - ROW_H
            end
        end

        dd:SetScript("OnShow", function(self)
            -- Close on click outside
            self:SetScript("OnUpdate", function()
                if not self:IsMouseOver() and not recBtn:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                    self:Hide()
                end
            end)
        end)
        dd:SetScript("OnHide", function(self)
            self:SetScript("OnUpdate", nil)
        end)

        dd:Hide()
        dropdown = dd
        return dd
    end

    -- Reset (red-tinted)
    local resetBtn = MakeFlatBtn(f, RST_W, 24,
        0.14, 0.05, 0.05,
        0.36, 0.13, 0.13)
    resetBtn:SetPoint("BOTTOMRIGHT", -PAD, BTN_ROW2_Y)
    local resetLbl = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetLbl:SetPoint("CENTER")
    resetLbl:SetText("Reset")
    resetLbl:SetTextColor(0.80, 0.30, 0.30)
    resetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.07, 0.07, 1.0)
        self:SetBackdropBorderColor(0.58, 0.20, 0.20, 1.0)
        resetLbl:SetTextColor(1.0, 0.42, 0.42)
    end)
    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.14, 0.05, 0.05, 1.0)
        self:SetBackdropBorderColor(0.36, 0.13, 0.13, 1.0)
        resetLbl:SetTextColor(0.80, 0.30, 0.30)
    end)

    -- ── Scale display updater ─────────────────────────────────────────────
    local function UpdateReadout(val)
        -- Large cyan readout
        f.scReadout:SetText(string.format("%.4f", val))

        -- Progress bar fill width
        local fraction = (val - UI_MIN_SCALE) / (UI_MAX_SCALE - UI_MIN_SCALE)
        f.barFill:SetWidth(math.max(2, math.floor(fraction * f.TRACK_W)))

        -- Hint: pixel-perfect match or recommended scale
        local _, w, h = GetResolutionInfo()
        local pp  = GetPixelPerfectScale(h)
        local rec, monitorType = GetRecommendedScale(w, h)

        if pp and math.abs(val - Round(pp, 4)) < 0.0002 then
            f.ppHint:SetText("|cFF00CC55Pixel-perfect alignment|r")
        elseif rec then
            local diff = math.abs(val - Round(rec, 4))
            if diff < 0.0002 then
                local mt = monitorType and (" — " .. monitorType) or ""
                f.ppHint:SetText("|cFF30C84ASuggested for your screen" .. mt .. "|r")
            else
                local mt = monitorType and ("|cFF304048 " .. monitorType .. "|r  ") or ""
                f.ppHint:SetText(mt .. string.format(
                    "|cFF304048Suggested %.2f|r  pp |cFF304048%.4f|r", Round(rec, 2), Round(pp or 0, 4)))
            end
        elseif pp then
            local diff = math.abs(val - Round(pp, 4))
            f.ppHint:SetText(string.format(
                "|cFF304048Pixel-perfect: %.4f  delta %.4f|r", Round(pp, 4), diff))
        else
            f.ppHint:SetText("")
        end
    end

    -- Combined slider-value setter (avoids re-entrancy)
    -- Assigned here (not declared local again) so preset OnClick closures above can reach it
    SetSliderValue = function(val)
        syncing = true
        val = Round(Clamp(val, UI_MIN_SCALE, UI_MAX_SCALE), 4)
        slider:SetValue(val)
        input:SetText(string.format("%.4f", val))
        UpdateReadout(val)
        syncing = false
    end

    -- ── Slider <-> input sync ─────────────────────────────────────────────
    slider:SetScript("OnValueChanged", function(self, val)
        if syncing then return end
        syncing = true
        val = Round(val, 4)
        input:SetText(string.format("%.4f", val))
        UpdateReadout(val)
        syncing = false
    end)

    input:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then SetSliderValue(val) end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- ── Toggle callbacks ──────────────────────────────────────────────────
    autoToggle.OnChange = function(state) db.autoApply = state end
    mmToggle.OnChange   = function(state)
        db.minimapHidden = not state
        if db.minimapHidden then FourKScaleMinimapBtn:Hide()
        else FourKScaleMinimapBtn:Show() end
    end

    -- ── Action button callbacks ───────────────────────────────────────────
    applyBtn:SetScript("OnClick", function()
        local val = tonumber(input:GetText())
        if val then
            local applied, key = SaveAndApply(val)
            print(PREFIX .. "Applied |cFFFFFFFF" .. string.format("%.4f", applied) .. "|r for " .. key)
            -- Brief green flash as confirmation
            applyLbl:SetTextColor(0.0, 1.0, 0.55)
            C_Timer.After(0.55, function() applyLbl:SetTextColor(CR, CG, CB) end)
        end
    end)

    sugBtn:SetScript("OnClick", function()
        local _, w, h = GetResolutionInfo()
        local rec = GetRecommendedScale(w, h)
        if rec then
            SetSliderValue(rec)
            -- Auto-apply immediately
            local applied, key = SaveAndApply(rec)
            print(PREFIX .. "Applied suggested |cFFFFFFFF" .. string.format("%.4f", applied) .. "|r for " .. key)
            sugLbl:SetTextColor(0.0, 1.0, 0.55)
            C_Timer.After(0.55, function() sugLbl:SetTextColor(0.30, 0.90, 0.38) end)
        end
    end)

    recBtn:SetScript("OnClick", function()
        local dd = CreateDropdown()
        if dd:IsShown() then
            dd:Hide()
        else
            dd:ClearAllPoints()
            dd:SetPoint("BOTTOMLEFT", recBtn, "TOPLEFT", 0, 4)
            dd:Show()
        end
    end)

    resetBtn:SetScript("OnClick", function()
        local key = GetResolutionInfo()
        db.profiles[key] = nil
        ApplyScale(1.0)
        SetSliderValue(1.0)
        print(PREFIX .. "Reset scale for " .. key)
    end)

    -- ── Refresh (called every open) ───────────────────────────────────────
    function f:Refresh()
        local key, w, h = GetResolutionInfo()
        self.resValue:SetText("|cFFBBCCDD" .. key .. "|r")
        self.curScaleLbl:SetText("scale " .. string.format("%.4f", GetCurrentScale()))
        self.autoToggle:SetChecked(db.autoApply)
        self.mmToggle:SetChecked(not db.minimapHidden)
        local saved = db.profiles[key]
        SetSliderValue(Round(saved or GetCurrentScale(), 4))
        -- Update Suggested button label with detected monitor
        local rec, monitorType = GetRecommendedScale(w, h)
        if rec and monitorType then
            self.sugLbl:SetText(monitorType .. " " .. string.format("%.2f", rec))
        elseif rec then
            self.sugLbl:SetText("Suggested " .. string.format("%.2f", rec))
        else
            self.sugLbl:SetText("Suggested")
        end
    end

    -- ESC closes the panel
    tinsert(UISpecialFrames, "FourKScaleOptions")

    f:Hide()
    optionsFrame = f
    return f
end

local function ToggleOptions()
    local f = CreateOptionsFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Refresh()
        f:Show()
    end
end

-- ============================================================
-- MINIMAP BUTTON (custom, no libs)
-- ============================================================

local mmBtn

local function UpdateMinimapPosition(angle)
    if not mmBtn then return end
    local r = 104
    local x = math.cos(angle) * r
    local y = math.sin(angle) * r
    mmBtn:ClearAllPoints()
    mmBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function RestoreMinimapPosition()
    UpdateMinimapPosition(db.minimapAngle or defaults.minimapAngle)
end

local function CreateMinimapButton()
    if mmBtn then return mmBtn end

    local btn = CreateFrame("Button", "FourKScaleMinimapBtn", Minimap)
    btn:SetSize(33, 33)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetMovable(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture(ICON_TEXTURE)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(20, 20)
    highlight:SetPoint("TOPLEFT", 7, -6)
    highlight:SetColorTexture(1, 1, 1, 0.2)

    btn:SetScript("OnDragStart", function()
        btn:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            cx, cy = cx / s, cy / s
            local angle = math.atan2(cy - my, cx - mx)
            db.minimapAngle = angle
            UpdateMinimapPosition(angle)
        end)
    end)

    btn:SetScript("OnDragStop", function()
        btn:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ToggleOptions()
        elseif button == "RightButton" then
            -- Quick popup for scale input
            StaticPopupDialogs["FOURKSCALE_INPUT"] = {
                text = "|cFF00CCFF4kScale|r\nEnter UI scale (0.20 - 1.00):",
                button1 = "Apply",
                button2 = "Recommended",
                button3 = "Cancel",
                hasEditBox = true,
                editBoxWidth = 80,
                OnShow = function(self)
                    self.editBox:SetText(string.format("%.2f", GetCurrentScale()))
                    self.editBox:HighlightText()
                end,
                OnAccept = function(self)
                    local val = tonumber(self.editBox:GetText())
                    if val then
                        local applied, key = SaveAndApply(val)
                        print(PREFIX .. "Applied |cFFFFFFFF" .. string.format("%.4f", applied) .. "|r for " .. key)
                    end
                end,
                OnCancel = function()
                    local _, w, h = GetResolutionInfo()
                    local rec = GetRecommendedScale(w, h)
                    if rec then
                        local applied, key = SaveAndApply(rec)
                        print(PREFIX .. "Applied recommended |cFFFFFFFF" .. string.format("%.4f", applied) .. "|r for " .. key)
                    end
                end,
                OnAlt = function() end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("FOURKSCALE_INPUT")
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cFF00CCFF4k|cFFFFFFFFScale|r")
        local key, w, h = GetResolutionInfo()
        local pp = GetPixelPerfectScale(h)
        local rec, monitorType = GetRecommendedScale(w, h)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Resolution:", "|cFFFFFFFF" .. key .. "|r")
        GameTooltip:AddDoubleLine("Current scale:", string.format("|cFFFFFFFF%.4f|r", GetCurrentScale()))
        if pp then
            GameTooltip:AddDoubleLine("Pixel-perfect:", string.format("|cFF888888%.4f|r", pp))
        end
        if rec then
            local label = monitorType and (" (" .. monitorType .. ")") or ""
            GameTooltip:AddDoubleLine("Recommended:", string.format("|cFF00FF00%.2f|r", rec) .. label)
        end
        local saved = db.profiles[key]
        if saved then
            GameTooltip:AddDoubleLine("Saved:", string.format("|cFFFFD100%.4f|r", saved))
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF888888Left-click:|r Settings", 1, 1, 1)
        GameTooltip:AddLine("|cFF888888Right-click:|r Quick input", 1, 1, 1)
        GameTooltip:AddLine("|cFF888888Drag:|r Reposition", 1, 1, 1)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    mmBtn = btn
    return btn
end

-- ============================================================
-- ADDON COMPARTMENT
-- ============================================================

function FourKScale_OnAddonCompartmentClick(_, button)
    if button == "LeftButton" then
        ToggleOptions()
    elseif button == "RightButton" then
        local _, w, h = GetResolutionInfo()
        local rec = GetRecommendedScale(w, h)
        if rec then
            local applied, key = SaveAndApply(rec)
            print(PREFIX .. "Applied recommended |cFFFFFFFF" .. string.format("%.4f", applied) .. "|r for " .. key)
        end
    end
end

function FourKScale_OnAddonCompartmentEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFF00CCFF4k|cFFFFFFFFScale|r")
    GameTooltip:AddLine("|cFF888888Left:|r Settings  |cFF888888Right:|r Recommended scale", 1, 1, 1)
    GameTooltip:Show()
end

function FourKScale_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

-- ============================================================
-- EDIT MODE POSITION HELPER (v1.1.0)
-- ============================================================
-- Companion to Blizzard's Edit Mode. Snap zones drift at low UI
-- scale; this gives pixel-precise X/Y control on the selected
-- system, sidestepping snap entirely.

local emHelper                  -- the floating helper panel
local selectedSystem            -- currently selected EditMode system (a frame)
local emHooksInstalled = false

local function GetSystemXY(system)
    if not system or not system.GetPoint then return 0, 0 end
    local point, _, _, x, y = system:GetPoint(1)
    if not point then return 0, 0 end
    return x or 0, y or 0
end

local function SetSystemXY(system, newX, newY)
    if not system or InCombatLockdown() then return false end
    local point, relativeTo, relativePoint = system:GetPoint(1)
    if not point then return false end
    system:ClearAllPoints()
    system:SetPoint(point, relativeTo or UIParent, relativePoint or point, newX, newY)
    -- Tell EditMode the position changed so it persists with the layout
    if system.OnSystemPositionChange then
        pcall(system.OnSystemPositionChange, system)
    end
    if EditModeManagerFrame and EditModeManagerFrame.GetActiveLayoutInfo and EditModeManagerFrame.UpdateLayoutInfo then
        local layoutInfo = EditModeManagerFrame:GetActiveLayoutInfo()
        if layoutInfo then
            pcall(EditModeManagerFrame.UpdateLayoutInfo, EditModeManagerFrame, layoutInfo)
        end
    end
    return true
end

local function NudgeBy(dx, dy)
    if not selectedSystem then return end
    local x, y = GetSystemXY(selectedSystem)
    SetSystemXY(selectedSystem, x + dx, y + dy)
    if emHelper then emHelper:Refresh() end
end

local function CenterH()
    if not selectedSystem then return end
    local _, y = GetSystemXY(selectedSystem)
    SetSystemXY(selectedSystem, 0, y)
    if emHelper then emHelper:Refresh() end
end

local function CenterV()
    if not selectedSystem then return end
    local x = GetSystemXY(selectedSystem)
    SetSystemXY(selectedSystem, x, 0)
    if emHelper then emHelper:Refresh() end
end

local function MakeEmBtn(parent, w, h, label, lblColor)
    local b = MakeFlatBtn(parent, w, h, 0.07, 0.08, 0.12, 0.12, 0.14, 0.20)
    local lbl = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetText(label)
    local lr, lg, lb = 0.62, 0.67, 0.76
    if lblColor then lr, lg, lb = lblColor[1], lblColor[2], lblColor[3] end
    lbl:SetTextColor(lr, lg, lb)
    b:SetScript("OnEnter", function(s)
        s:SetBackdropColor(0.10, 0.12, 0.18, 1.0)
        s:SetBackdropBorderColor(0.18, 0.22, 0.34, 1.0)
        lbl:SetTextColor(0.92, 0.96, 1.0)
    end)
    b:SetScript("OnLeave", function(s)
        s:SetBackdropColor(0.07, 0.08, 0.12, 1.0)
        s:SetBackdropBorderColor(0.12, 0.14, 0.20, 1.0)
        lbl:SetTextColor(lr, lg, lb)
    end)
    return b
end

local function CreateEditModeHelper()
    if emHelper then return emHelper end

    local PW, PH = 290, 190
    local HH = 30
    local PAD = 12
    local CR, CG, CB = 0.0, 0.80, 1.0

    local f = CreateFrame("Frame", "FourKScaleEditHelper", UIParent, "BackdropTemplate")
    f:SetSize(PW, PH)
    f:SetPoint("BOTTOMRIGHT", -60, 200)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.052, 0.056, 0.088, 0.97)
    f:SetBackdropBorderColor(0.09, 0.10, 0.15, 1.0)

    -- Header
    local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
    hdr:SetSize(PW - 2, HH)
    hdr:SetPoint("TOPLEFT", 1, -1)
    hdr:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    hdr:SetBackdropColor(0.030, 0.034, 0.060, 1.0)

    local stripe = hdr:CreateTexture(nil, "OVERLAY")
    stripe:SetSize(3, HH)
    stripe:SetPoint("TOPLEFT", 0, 0)
    stripe:SetColorTexture(CR, CG, CB, 1.0)

    local hdrSep = hdr:CreateTexture(nil, "OVERLAY")
    hdrSep:SetHeight(1)
    hdrSep:SetPoint("BOTTOMLEFT", 0, 0)
    hdrSep:SetPoint("BOTTOMRIGHT", 0, 0)
    hdrSep:SetColorTexture(CR, CG, CB, 0.28)

    local titleTxt = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleTxt:SetPoint("LEFT", 12, 0)
    titleTxt:SetText("|cFF00CCFF4kScale|r |cFF888888Position Helper|r")

    local closeBtn = CreateFrame("Button", nil, hdr)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", -6, 0)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("|cFF555566x|r")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeTxt:SetText("|cFFFF5566x|r") end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetText("|cFF555566x|r") end)

    -- Selected frame name (or hint when nothing selected)
    local nameLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLbl:SetPoint("TOPLEFT", PAD, -(HH + 8))
    nameLbl:SetPoint("TOPRIGHT", -PAD, -(HH + 8))
    nameLbl:SetJustifyH("LEFT")
    nameLbl:SetWordWrap(false)
    f.nameLbl = nameLbl

    -- Row layout
    local ROW1_Y = -(HH + 30)   -- X row
    local ROW2_Y = -(HH + 56)   -- Y row

    local xLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xLbl:SetPoint("TOPLEFT", PAD, ROW1_Y)
    xLbl:SetText("X:")
    xLbl:SetTextColor(0.76, 0.78, 0.82)

    local xInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    xInput:SetSize(56, 20)
    xInput:SetPoint("LEFT", xLbl, "RIGHT", 6, 0)
    xInput:SetAutoFocus(false)
    xInput:SetMaxLetters(7)
    xInput:SetJustifyH("CENTER")
    f.xInput = xInput

    local yLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yLbl:SetPoint("TOPLEFT", PAD, ROW2_Y)
    yLbl:SetText("Y:")
    yLbl:SetTextColor(0.76, 0.78, 0.82)

    local yInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    yInput:SetSize(56, 20)
    yInput:SetPoint("LEFT", yLbl, "RIGHT", 6, 0)
    yInput:SetAutoFocus(false)
    yInput:SetMaxLetters(7)
    yInput:SetJustifyH("CENTER")
    f.yInput = yInput

    local function ApplyFromInputs()
        if not selectedSystem then return end
        local x = tonumber(xInput:GetText())
        local y = tonumber(yInput:GetText())
        if x and y then
            SetSystemXY(selectedSystem, x, y)
            f:Refresh()
        end
    end

    xInput:SetScript("OnEnterPressed", function(self) ApplyFromInputs(); self:ClearFocus() end)
    xInput:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Refresh() end)
    yInput:SetScript("OnEnterPressed", function(self) ApplyFromInputs(); self:ClearFocus() end)
    yInput:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Refresh() end)

    -- Nudge buttons (-10, -1, +1, +10) for X and Y
    local nudgeW, nudgeH, nudgeGap = 28, 20, 3

    local function PlaceNudgeRow(anchorTo, dxAxis, dyAxis)
        local prev = anchorTo
        local nudges = { -10, -1, 1, 10 }
        for i, n in ipairs(nudges) do
            local label = (n > 0 and "+" or "") .. tostring(n)
            -- positive accent color for + and muted for -
            local color = n > 0 and { 0.55, 0.78, 0.55 } or { 0.78, 0.55, 0.55 }
            local b = MakeEmBtn(f, nudgeW, nudgeH, label, color)
            if prev == anchorTo then
                b:SetPoint("LEFT", prev, "RIGHT", 12, 0)
            else
                b:SetPoint("LEFT", prev, "RIGHT", nudgeGap, 0)
            end
            b:SetScript("OnClick", function() NudgeBy(n * dxAxis, n * dyAxis) end)
            prev = b
        end
    end

    PlaceNudgeRow(xInput, 1, 0)
    PlaceNudgeRow(yInput, 0, 1)

    -- Center H / Center V row
    local cBtnY = 14
    local cBtnW = math.floor((PW - PAD * 2 - 6) / 2)

    local centerH = MakeEmBtn(f, cBtnW, 22, "Center H", { 0.5, 0.7, 0.85 })
    centerH:SetPoint("BOTTOMLEFT", PAD, cBtnY)
    centerH:SetScript("OnClick", CenterH)

    local centerV = MakeEmBtn(f, cBtnW, 22, "Center V", { 0.5, 0.7, 0.85 })
    centerV:SetPoint("BOTTOMLEFT", PAD + cBtnW + 6, cBtnY)
    centerV:SetScript("OnClick", CenterV)

    -- Refresh from selectedSystem
    function f:Refresh()
        if selectedSystem then
            local x, y = GetSystemXY(selectedSystem)
            xInput:SetText(string.format("%d", math.floor(x + 0.5)))
            yInput:SetText(string.format("%d", math.floor(y + 0.5)))
            local name = selectedSystem.systemNameString
                      or (selectedSystem.GetName and selectedSystem:GetName())
                      or "Frame"
            nameLbl:SetText("|cFF00CCFFSelected:|r |cFFFFFFFF" .. name .. "|r")
        else
            xInput:SetText("")
            yInput:SetText("")
            nameLbl:SetText("|cFF888888Click any Edit Mode frame to select|r")
        end
    end

    f:Hide()
    emHelper = f
    return f
end

local function SetupEditModeHooks()
    if emHooksInstalled then return true end
    if not EditModeManagerFrame then return false end

    if EditModeManagerFrame.SelectSystem then
        hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(_, system)
            selectedSystem = system
            if emHelper and emHelper:IsShown() then emHelper:Refresh() end
        end)
    end
    if EditModeManagerFrame.ClearSelectedSystem then
        hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
            selectedSystem = nil
            if emHelper and emHelper:IsShown() then emHelper:Refresh() end
        end)
    end

    EditModeManagerFrame:HookScript("OnShow", function()
        local h = CreateEditModeHelper()
        h:Show()
        h:Refresh()
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        if emHelper then emHelper:Hide() end
        selectedSystem = nil
    end)

    emHooksInstalled = true
    return true
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================

SLASH_FOURKSCALE1 = "/4kuhd"
SLASH_FOURKSCALE2 = "/4kscale"
SlashCmdList["FOURKSCALE"] = function(msg)
    msg = (msg or ""):trim():lower()

    if msg == "" then
        ToggleOptions()
        return
    end

    if msg == "auto" or msg == "pp" or msg == "pixel" then
        local _, w, h = GetResolutionInfo()
        local rec = GetRecommendedScale(w, h)
        if rec then
            local applied, key = SaveAndApply(rec)
            print(PREFIX .. "Recommended |cFFFFFFFF" .. string.format("%.4f", applied) .. "|r for " .. key)
        else
            print(PREFIX .. "Cannot detect resolution.")
        end
        return
    end

    if msg == "reset" then
        local key = GetResolutionInfo()
        db.profiles[key] = nil
        ApplyScale(1.0)
        print(PREFIX .. "Reset scale for " .. key)
        return
    end

    if msg == "info" or msg == "status" then
        local key, w, h = GetResolutionInfo()
        local pp = GetPixelPerfectScale(h)
        local saved = db.profiles[key]
        local rec, monitorType = GetRecommendedScale(w, h)
        print(PREFIX .. "Resolution: |cFFFFFFFF" .. key .. "|r")
        print(PREFIX .. "Current scale: |cFFFFFFFF" .. string.format("%.4f", GetCurrentScale()) .. "|r")
        if pp then print(PREFIX .. "Pixel-perfect: |cFF888888" .. string.format("%.4f", pp) .. "|r") end
        if rec then
            local label = monitorType and (" (" .. monitorType .. ")") or ""
            print(PREFIX .. "Recommended: |cFF00FF00" .. string.format("%.2f", rec) .. "|r" .. label)
        end
        if saved then print(PREFIX .. "Saved: |cFFFFD100" .. string.format("%.4f", saved) .. "|r") end
        print(PREFIX .. "Auto-apply: " .. (db.autoApply and "|cFF00FF00ON|r" or "|cFFFF4444OFF|r"))
        return
    end

    if msg == "minimap" or msg == "minimap show" then
        db.minimapHidden = false
        if mmBtn then mmBtn:Show(); RestoreMinimapPosition() end
        print(PREFIX .. "Minimap icon shown.")
        return
    end

    if msg == "minimap hide" then
        db.minimapHidden = true
        if mmBtn then mmBtn:Hide() end
        print(PREFIX .. "Minimap icon hidden. Use |cFFFFFFFF/4kuhd minimap|r to show.")
        return
    end

    if msg == "edit" or msg == "editmode" then
        if InCombatLockdown() then
            print(PREFIX .. "Cannot open Edit Mode in combat.")
            return
        end
        if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_EditMode") then
            UIParentLoadAddOn("Blizzard_EditMode")
        end
        if not EditModeManagerFrame then
            print(PREFIX .. "Edit Mode not available on this client.")
            return
        end
        ShowUIPanel(EditModeManagerFrame)
        return
    end

    local val = tonumber(msg)
    if val then
        local applied, key = SaveAndApply(val)
        print(PREFIX .. "Applied |cFFFFFFFF" .. string.format("%.4f", applied) .. "|r for " .. key)
        return
    end

    print("|cFF00CCFF4kScale|r commands:")
    print("  |cFFFFFFFF/4kuhd|r - Open settings panel")
    print("  |cFFFFFFFF/4kuhd 0.45|r - Set scale directly")
    print("  |cFFFFFFFF/4kuhd auto|r - Apply recommended scale")
    print("  |cFFFFFFFF/4kuhd reset|r - Reset to default (1.0)")
    print("  |cFFFFFFFF/4kuhd info|r - Show resolution & scale info")
    print("  |cFFFFFFFF/4kuhd edit|r - Open Edit Mode + Position Helper")
    print("  |cFFFFFFFF/4kuhd minimap|r / |cFFFFFFFF minimap hide|r")
end

-- ============================================================
-- EVENT HANDLER
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

local loginApplied = false

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            GetDB()
            CreateMinimapButton()
            RestoreMinimapPosition()
            if db.minimapHidden then
                mmBtn:Hide()
            end
            -- Try Edit Mode hooks now; will retry on Blizzard_EditMode load if not ready
            if EditModeManagerFrame then SetupEditModeHooks() end
        elseif arg1 == "Blizzard_EditMode" then
            SetupEditModeHooks()
        end

    elseif event == "PLAYER_LOGIN" then
        if db.autoApply then
            local s = GetSavedScale()
            if s then
                ApplyScale(s)
                loginApplied = true
            end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if db.autoApply and not loginApplied then
            local s = GetSavedScale()
            if s then ApplyScale(s) end
        end
        loginApplied = false

    elseif event == "DISPLAY_SIZE_CHANGED" then
        if db.autoApply then
            C_Timer.After(0.5, function()
                local s = GetSavedScale()
                if s then
                    ApplyScale(s)
                else
                    -- New resolution detected, suggest recommended
                    local _, w, h = GetResolutionInfo()
                    local rec, monitorType = GetRecommendedScale(w, h)
                    if rec then
                        local label = monitorType and (" (" .. monitorType .. ")") or ""
                        print(PREFIX .. "New resolution detected. Recommended: |cFF00FF00" .. string.format("%.2f", rec) .. "|r" .. label)
                        print(PREFIX .. "Use |cFFFFFFFF/4kuhd auto|r to apply or |cFFFFFFFF/4kuhd|r to configure.")
                    end
                end
            end)
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then
            local s = GetSavedScale()
            if s then ApplyScale(s) end
        end
    end
end)
