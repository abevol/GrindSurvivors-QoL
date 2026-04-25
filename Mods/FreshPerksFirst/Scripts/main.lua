--[[
    FreshPerksFirst - Smart Perk Filtering for Grind Survivors
    ================================================================
    In Infinity Mode, prevents already-owned perks from appearing in
    level-up choices until ALL perks in their category group are owned.
    Once a full category is learned, its perks re-enter the random pool.

    Mechanism: Post-hooks on LevelUpWidget:Activate / RerollPerks.
    Modifies widget.Perks TArray; UI refresh via native DisplayPerks().
]]

local UEHelpers = require("UEHelpers")

local MOD_NAME = "FreshPerksFirst"
---@type boolean
local DEBUG_MODE = true

---------------------------------------------------------------------------
-- Persistent state (survives level transitions, reset only on mod reload)
---------------------------------------------------------------------------
---@type boolean
local hooksRegistered = false
---@type string?
local gameModuleName = nil

---------------------------------------------------------------------------
-- Per-level state (reset on each level transition)
---------------------------------------------------------------------------
---@type UPerkSubsystem?
local perkSubsystem = nil
---@type boolean
local isInfinityMode = false
---@type boolean
local initialized = false

---@type table<string, string[]>   -- catTagName -> {perkTagName, ...}
local categoryIndex = {}
---@type table<string, string>     -- perkTagName -> catTagName
local perkToCategory = {}
---@type table<string, FGameplayTag>  -- perkTagName -> FGameplayTag (cached from PerkDataAsset)
local perkTagRefs = {}
---@type integer
local totalPerkCount = 0

---@type boolean
local inFilter = false

---------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------
---@param msg string
local function Log(msg)
    print(string.format("[%s] %s\n", MOD_NAME, msg))
end

---@param msg string
local function DebugLog(msg)
    if DEBUG_MODE then Log(msg) end
end

-- Only use guarded execution at scheduling/callback boundaries.
---@param scope string
---@param fn function
---@return boolean
local function RunBoundary(scope, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
        Log(string.format("%s: %s", scope, tostring(err)))
    end
    return ok
end

---@param tag FGameplayTag
---@return string?
local function GameplayTagToName(tag)
    if not tag or not tag.TagName then return nil end
    local tagName = tag.TagName:ToString()
    if type(tagName) ~= "string" or tagName == "" or tagName == "None" then
        return nil
    end
    return tagName
end

---@param text any
---@return string?
local function TextToString(text)
    if not text then return nil end
    if type(text) == "string" then return text end
    if text.ToString then
        local ok, s = pcall(function() return text:ToString() end)
        if ok and type(s) == "string" then return s end
    end
    return nil
end

---------------------------------------------------------------------------
-- Auto-discover UE module name from live game objects
---------------------------------------------------------------------------
---@return string?
local function DiscoverGameModule()
    if gameModuleName then return gameModuleName end
    for _, cls in ipairs({"PerkSubsystem", "GSGameMode", "LevelComponent"}) do
        local obj = FindFirstOf(cls)
        if obj and obj:IsValid() then
            local class = obj:GetClass()
            if class then
                local full = class:GetFullName()
                local mod = full:match("/Script/([^%.]+)%.")
                if mod then
                    gameModuleName = mod
                    Log("Game module: " .. mod)
                    return mod
                end
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Subsystem & mode helpers
---------------------------------------------------------------------------
---@return boolean
local function InitPerkSubsystem()
    if perkSubsystem and perkSubsystem:IsValid() then return true end
    perkSubsystem = FindFirstOf("PerkSubsystem")
    if not perkSubsystem or not perkSubsystem:IsValid() then
        perkSubsystem = nil
        return false
    end
    return true
end

---@return nil
local function CheckInfinityMode()
    for _, name in ipairs({"GSGameMode", "BP_GameMode_C"}) do
        ---@type AGSGameMode?
        local gm = FindFirstOf(name)
        if gm and gm:IsValid() then
            local val = gm.bInfinityMode
            if type(val) == "boolean" then
                isInfinityMode = val
                return
            end
        end
    end
    isInfinityMode = false
end

---------------------------------------------------------------------------
-- Build category -> perks index from PerkDataAsset
---------------------------------------------------------------------------
---@return boolean
local function BuildCategoryIndex()
    categoryIndex = {}
    perkToCategory = {}
    perkTagRefs = {}
    totalPerkCount = 0

    if not perkSubsystem or not perkSubsystem:IsValid() then return false end

    ---@type UPerkDataAsset?
    local dataAsset = perkSubsystem.PerkDataAsset
    if not dataAsset or not dataAsset:IsValid() then
        if perkSubsystem.GetPerkDataAsset then
            dataAsset = perkSubsystem:GetPerkDataAsset()
        end
    end
    if not dataAsset or not dataAsset:IsValid() then
        Log("PerkDataAsset not found")
        return false
    end

    local perks = dataAsset.Perks
    if not perks then return false end

    for i = 1, #perks do
        ---@type FPerk
        local perk = perks[i]
        if not perk then goto continue end

        local tag = perk.Tag
        local tagName = GameplayTagToName(tag)
        if not tagName then
            goto continue
        end

        local catTag = perk.CategoryTag
        local catName = GameplayTagToName(catTag) or "__uncategorized__"

        categoryIndex[catName] = categoryIndex[catName] or {}
        table.insert(categoryIndex[catName], tagName)
        perkToCategory[tagName] = catName
        perkTagRefs[tagName] = tag
        totalPerkCount = totalPerkCount + 1
        ::continue::
    end

    local catCount = 0
    for _ in pairs(categoryIndex) do catCount = catCount + 1 end
    Log(string.format("Index: %d categories, %d perks", catCount, totalPerkCount))

    if DEBUG_MODE then
        for cat, list in pairs(categoryIndex) do
            DebugLog(string.format("  [%s]: %d perks", cat, #list))
        end
    end

    return totalPerkCount > 0
end

---------------------------------------------------------------------------
-- Core filter logic
---------------------------------------------------------------------------

--- Check whether every perk in a category is already owned.
---@param catName string
---@return boolean
local function IsCategoryComplete(catName)
    local list = categoryIndex[catName]
    if not list or #list == 0 then return true end
    for _, tn in ipairs(list) do
        local t = perkTagRefs[tn]
        if t and not perkSubsystem:IsPerkOwned(t) then return false end
    end
    return true
end

---@param oldTagName string
---@param excludeSet table<string, boolean>
---@return string?
local function GetReplacementForPerk(oldTagName, excludeSet)
    local catName = perkToCategory[oldTagName]
    local candidates = {}

    if catName and categoryIndex[catName] and not IsCategoryComplete(catName) then
        for _, tn in ipairs(categoryIndex[catName]) do
            if not excludeSet[tn] then
                local t = perkTagRefs[tn]
                if t and not perkSubsystem:IsPerkOwned(t) then
                    table.insert(candidates, tn)
                end
            end
        end
    end

    if #candidates == 0 then
        for cn, list in pairs(categoryIndex) do
            if not IsCategoryComplete(cn) then
                for _, tn in ipairs(list) do
                    if not excludeSet[tn] then
                        local t = perkTagRefs[tn]
                        if t and not perkSubsystem:IsPerkOwned(t) then
                            table.insert(candidates, tn)
                        end
                    end
                end
            end
        end
    end

    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

---------------------------------------------------------------------------
-- Main filter: modify widget.Perks + refresh cards
---------------------------------------------------------------------------

---@param widget UWBP_LevelUp_C
local function FilterAndRefresh(widget)
    -- Guard: skip if not ready, not in Infinity mode, or already inside a filter pass
    if not initialized or not isInfinityMode then return end
    if not perkSubsystem or not perkSubsystem:IsValid() then return end
    if inFilter then return end
    if not widget or not widget:IsValid() then return end

    inFilter = true
    local perks = widget.Perks
    if not perks then
        inFilter = false
        return
    end

    local count = #perks
    if count == 0 then
        inFilter = false
        return
    end

    -- Step 1: Scan the current perk choices and identify which slots
    --         contain already-owned perks that need replacement.
    --         We only replace owned perks whose category is NOT yet complete
    --         (i.e., there are still unowned perks in that group).
    ---@type table<integer, string>
    local choices = {}
    ---@type table<string, boolean>
    local choiceSet = {}
    ---@type integer[]
    local toReplace = {}

    for i = 1, count do
        ---@type FGameplayTag
        local perkTag = perks[i]
        local tn = GameplayTagToName(perkTag)
        if tn then
            choices[i] = tn
            choiceSet[tn] = true
            local cat = perkToCategory[tn]
            if cat then
                local tag = perkTagRefs[tn]
                if tag and perkSubsystem:IsPerkOwned(tag)
                        and not IsCategoryComplete(cat) then
                    -- This perk is already owned AND its category still has
                    -- unowned perks → mark for replacement
                    table.insert(toReplace, i)
                end
            end
        end
    end

    DebugLog(string.format("Scan: %d choices, %d to replace", count, #toReplace))

    if #toReplace == 0 then
        inFilter = false
        DebugLog("No filtering needed")
        return
    end

    -- Step 2: For each slot marked for replacement, find a suitable
    --         unowned perk (preferring the same category) and write it
    --         into the `perks` TArray. Try three strategies for writing
    --         the FGameplayTag since the struct layout may vary.
    local replaced = 0
    for _, si in ipairs(toReplace) do
        local oldName = choices[si]
        local newName = GetReplacementForPerk(oldName, choiceSet)
        if not newName then goto next_slot end

        local newTag = perkTagRefs[newName]
        if not newTag then goto next_slot end

        -- Log the skill display name (human-readable) for both the old and new perk,
        -- so we can verify the replacement makes sense at a glance
        local oldInfo = perkSubsystem:GetPerkInfo(perks[si])
        local oldDisplayName = oldInfo and TextToString(oldInfo.DisplayName) or oldName
        local newInfo = perkSubsystem:GetPerkInfo(newTag)
        local newDisplayName = newInfo and TextToString(newInfo.DisplayName) or newName
        DebugLog(string.format("  Replace slot[%d]: displayName '%s' (%s) -> '%s' (%s)",
            si, oldDisplayName, oldName, newDisplayName, newName))

        -- Strategy 1: Direct assignment of the FGameplayTag struct
        local written = false

        perks[si] = newTag
        written = GameplayTagToName(perks[si]) == newName

        -- Strategy 2: If the struct was copied by value (UE struct semantics),
        --             try to overwrite the TagName field directly
        if not written and perks[si] and perks[si].TagName and newTag.TagName then
            perks[si].TagName = newTag.TagName
            written = GameplayTagToName(perks[si]) == newName
        end

        -- Strategy 3: Last resort - construct a new FName for the tag
        if not written and perks[si] and perks[si].TagName and FName then
            perks[si].TagName = FName(newName)
            written = GameplayTagToName(perks[si]) == newName
        end

        if not written then
            Log(string.format("WARNING: Perks[%d] write failed (all strategies). "
                .. "Card visual updated but SelectPerk may pick wrong perk.", si))
        end

        choiceSet[newName] = true
        replaced = replaced + 1
        DebugLog(string.format("    tag %s -> %s%s",
            oldName, newName, written and "" or " (visual only)"))
        ::next_slot::
    end

    -- Step 3: Apply the filtered perks to the UI via native DisplayPerks()
    if replaced > 0 then
        if widget.DisplayPerks then
            local ok, err = pcall(function() widget:DisplayPerks() end)
            if ok then
                Log("DisplayPerks() called")
            else
                Log("DisplayPerks() failed: " .. tostring(err))
            end
        else
            Log("DisplayPerks() unavailable on widget")
        end

        -- Recalc perk levels on the skill cards
        if widget.CalculateSkillCardsPerkLevel then
            local ok, err = pcall(function() widget:CalculateSkillCardsPerkLevel() end)
            if ok then
                DebugLog("CalculateSkillCardsPerkLevel() called")
            else
                Log("CalculateSkillCardsPerkLevel() failed: " .. tostring(err))
            end
        end
    end

    Log(string.format("Filtered %d/%d perks", replaced, #toReplace))
    inFilter = false
end

---------------------------------------------------------------------------
-- Hook registration (once per mod session)
---------------------------------------------------------------------------
---@return boolean
local function RegisterHooks()
    if hooksRegistered then return true end

    local mod = DiscoverGameModule()
    if not mod then
        Log("Cannot discover game module for hooks")
        return false
    end

    local activatePath = string.format("/Script/%s.LevelUpWidget:Activate", mod)
    local rerollPath   = string.format("/Script/%s.LevelUpWidget:RerollPerks", mod)

    -- Activate hook
    ---@diagnostic disable-next-line: param-type-mismatch
    RegisterHook(activatePath,
        function() end,
        ---@param Ctx RemoteUnrealParam<UWBP_LevelUp_C>
        function(Ctx)
            RunBoundary("Activate hook callback", function()
                local w = Ctx:get()
                if w and w:IsValid() then
                    FilterAndRefresh(w)
                end
            end)
        end)
    Log("Hooked: " .. activatePath)

    ---@diagnostic disable-next-line: param-type-mismatch
    RegisterHook(rerollPath,
        function() end,
        ---@param Ctx RemoteUnrealParam<UWBP_LevelUp_C>
        function(Ctx)
            RunBoundary("RerollPerks hook callback", function()
                local w = Ctx:get()
                if w and w:IsValid() then
                    FilterAndRefresh(w)
                end
            end)
        end)
    Log("Hooked: " .. rerollPath)

    hooksRegistered = true
    return true
end

---------------------------------------------------------------------------
-- Full initialization / reset
---------------------------------------------------------------------------
---@return boolean
local function FullInitialize()
    initialized = false

    if not InitPerkSubsystem() then
        DebugLog("Init deferred: PerkSubsystem not ready")
        return false
    end

    CheckInfinityMode()
    Log("Mode: " .. (isInfinityMode and "Infinity" or "Standard"))

    if not isInfinityMode then
        initialized = true
        return true
    end

    if not BuildCategoryIndex() then
        Log("Failed to build category index")
        return false
    end

    if not RegisterHooks() then
        Log("Hook registration failed - mod will not function")
        return false
    end

    initialized = true
    Log("Perk filtering active")
    return true
end

local function ResetLevelState()
    perkSubsystem = nil
    isInfinityMode = false
    initialized = false
    categoryIndex = {}
    perkToCategory = {}
    perkTagRefs = {}
    totalPerkCount = 0
    inFilter = false
end

---------------------------------------------------------------------------
-- Hot-reload recovery
---------------------------------------------------------------------------
local function TryInitMidGame()
    ---@type ABP_PlayerCharacter_C?
    local pc = FindFirstOf("BP_PlayerCharacter_C")
    if not pc or not pc:IsValid() then
        DebugLog("Not in game, skipping mid-game init")
        return
    end
    Log("Hot-reload detected mid-game, restoring state...")
    FullInitialize()
end

---------------------------------------------------------------------------
-- Event handlers
---------------------------------------------------------------------------
RegisterCustomEvent("OnGameLevelStarted", function(ContextParam)
    Log("Level started")
    ResetLevelState()
    ExecuteWithDelay(1000, function()
        RunBoundary("ExecuteWithDelay FullInitialize", FullInitialize)
    end)
end)

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
ExecuteInGameThread(function()
    Log("Mod loaded")
    RunBoundary("ExecuteInGameThread TryInitMidGame", TryInitMidGame)
end)

-- Fallback: retry init if early attempts failed
---@return boolean
LoopAsync(3000, function()
    RunBoundary("LoopAsync init retry", function()
        if not initialized then
            if FindFirstOf("PerkSubsystem") then
                FullInitialize()
            end
        end
    end)
    return false
end)

---------------------------------------------------------------------------
-- Console commands
---------------------------------------------------------------------------
---@param Cmd string
---@param Parts string[]
---@param Ar FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("freshperks_status", function(Cmd, Parts, Ar)
    Log(string.format("Infinity: %s | Init: %s | Hooks: %s",
        tostring(isInfinityMode), tostring(initialized), tostring(hooksRegistered)))

    local catCount = 0
    for _ in pairs(categoryIndex) do catCount = catCount + 1 end
    Log(string.format("Categories: %d | Total perks: %d", catCount, totalPerkCount))

    if isInfinityMode and initialized and perkSubsystem and perkSubsystem:IsValid() then
        for cat, list in pairs(categoryIndex) do
            local owned = 0
            for _, tn in ipairs(list) do
                local t = perkTagRefs[tn]
                if t and perkSubsystem:IsPerkOwned(t) then owned = owned + 1 end
            end
            Log(string.format("  [%s] %d/%d%s",
                cat, owned, #list, IsCategoryComplete(cat) and " COMPLETE" or ""))
        end
    end
    return true
end)

---@param Cmd string
---@param Parts string[]
---@param Ar FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("freshperks_debug", function(Cmd, Parts, Ar)
    DEBUG_MODE = not DEBUG_MODE
    Log("Debug: " .. (DEBUG_MODE and "ON" or "OFF"))
    return true
end)

---@param Cmd string
---@param Parts string[]
---@param Ar FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("freshperks_rebuild", function(Cmd, Parts, Ar)
    if InitPerkSubsystem() then
        BuildCategoryIndex()
    else
        Log("PerkSubsystem not available")
    end
    return true
end)

---@param Cmd string
---@param Parts string[]
---@param Ar FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("freshperks_test", function(Cmd, Parts, Ar)
    if not initialized or not isInfinityMode then
        Log("Not active (not in infinity mode or not initialized)")
        return true
    end
    if not perkSubsystem or not perkSubsystem:IsValid() then
        Log("PerkSubsystem unavailable")
        return true
    end

    ---@type UWBP_LevelUp_C?
    local widget = FindFirstOf("WBP_LevelUp_C")
    if not widget or not widget:IsValid() then
        Log("No LevelUpWidget active")
        return true
    end

    local perks = widget.Perks
    if not perks or #perks == 0 then
        Log("Widget has no perks")
        return true
    end

    Log("Current perk choices:")
    for i = 1, #perks do
        local tn = GameplayTagToName(perks[i])
        if tn then
            local cat = perkToCategory[tn] or "?"
            local owned = perkTagRefs[tn] and perkSubsystem:IsPerkOwned(perkTagRefs[tn])
            local catDone = cat ~= "?" and IsCategoryComplete(cat)
            local flag = (owned and not catDone) and " -> WOULD REPLACE" or ""
            Log(string.format("  [%d] %s  cat=%s  owned=%s  catDone=%s%s",
                i, tn, cat, tostring(owned), tostring(catDone), flag))
        end
    end
    return true
end)
