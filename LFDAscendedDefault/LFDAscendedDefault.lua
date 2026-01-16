local name = UnitName("player")
local _, class = UnitClass("player")
local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or { r=1, g=1, b=1 }
local classColor = string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
local lastOpenTime = 0
local AUTO_WINDOW = 1.0 -- seconds after opening where we "fight" the default

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00LFDAscended|r: Loaded. Welcome back "..classColor..name.."|r, enjoy not accidentally queuing heroic!")



local function GetDropdown()
  return _G["LFDQueueFrameTypeDropDown"]
      or _G["LFDDungeonTypeDropDown"]
      or _G["LFDQueueFrame_TypeDropDown"]
end

local function ClickAscendedInOpenMenu()
  -- Dropdown menus usually render into DropDownList1Button1..N
  for i = 1, 50 do
    local b = _G["DropDownList1Button"..i]
    if b and b:IsShown() then
      local t = _G["DropDownList1Button"..i.."NormalText"]
      local text = t and t:GetText()

      if type(text) == "string" then
        local lower = string.lower(text)

        -- Prefer a pure "ascended" option; avoid "random"
        if string.find(lower, "random", 1, true) and string.find(lower, "ascended", 1, true) then
          b:Click()
          CloseDropDownMenus()
          return true, text
        end
      end
    end
  end
  return false, nil
end

local function ForceAscendedOnce()
  local dd = GetDropdown()
  if not dd then return end

  local name = dd:GetName()
  local button = name and _G[name.."Button"]

  -- Open the dropdown list (so DropDownList buttons exist)
  if button and button.Click then
    button:Click()
  else
    -- Fallback attempt
    ToggleDropDownMenu(1, nil, dd)
  end

  -- Try to click the Ascended option
  local ok = ClickAscendedInOpenMenu()
  CloseDropDownMenus()
  return ok
end

local function ForceSoon()
  local tries = 0
  local f = CreateFrame("Frame")
  f:SetScript("OnUpdate", function(self, elapsed)
    tries = tries + 1

    -- Only try while LFD is visible
    if _G["LFDParentFrame"] and _G["LFDParentFrame"]:IsShown() then
      if ForceAscendedOnce() then
        -- If we succeeded, stop early
        self:SetScript("OnUpdate", nil)
        self:Hide()
        return
      end
    end

    if tries >= 25 then
      self:SetScript("OnUpdate", nil)
      self:Hide()
    end
  end)
end

local function ForceAfterOpen()
  local tries = 0
  local f = CreateFrame("Frame")
  f:SetScript("OnUpdate", function(self, elapsed)
    tries = tries + 1

    -- only run while the panel is open
    if _G["LFDParentFrame"] and _G["LFDParentFrame"]:IsShown() then
      if ForceAscendedOnce() then
        self:SetScript("OnUpdate", nil)
        self:Hide()
        return
      end
    end

    -- stop after a short burst
    if tries >= 40 then
      self:SetScript("OnUpdate", nil)
      self:Hide()
    end
  end)
end

-- Pressing "I" usually calls this
if type(_G["ToggleLFDParentFrame"]) == "function" then
  hooksecurefunc("ToggleLFDParentFrame", function()
    lastOpenTime = GetTime()
    ForceAfterOpen()
  end)
end

-- Backup: also run when the frame shows
if _G["LFDParentFrame"] then
  _G["LFDParentFrame"]:HookScript("OnShow", function()
    lastOpenTime = GetTime()
    ForceAfterOpen()
  end)
end

-- Re-apply Ascended if the server UI switches it back to Heroic
local reapplying = false

hooksecurefunc("UIDropDownMenu_SetText", function(frame, text)
  local dd = GetDropdown()
  if frame ~= dd then return end
  if type(text) ~= "string" then return end

  -- Only enrouce right after opening; don't fight manual choices
  if (GetTime() - lastOpenTime) > AUTO_WINDOW then return end


  local lower = string.lower(text)

  -- If it ever gets set to a heroic option (and not already ascended), force ascended again.
  if (string.find(lower, "heroic", 1, true) or string.find(lower, "lich king", 1, true))
     and not string.find(lower, "ascended", 1, true) then

    -- prevent infinite recursion
    if reapplying then return end
    reapplying = true

    -- delay a tick so we win whatever code is currently running
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
      self:SetScript("OnUpdate", nil)
      ForceAfterOpen()
      reapplying = false
    end)
  end
end)



local function HookIt()
  if _G["LFDParentFrame"] then
    _G["LFDParentFrame"]:HookScript("OnShow", ForceSoon)
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
  if addon == "Blizzard_LFDUI" then
    HookIt()
  end
end)

if IsAddOnLoaded("Blizzard_LFDUI") then
  HookIt()
end

-- Manual test command
SLASH_LFDASC1 = "/lfdasc"
SlashCmdList["LFDASC"] = function()
  if ForceAscendedOnce() then
    print("LFD: selected Ascended (clicked from dropdown list).")
  else
    print("LFD: could not find an Ascended option in the open dropdown list.")
  end
end
