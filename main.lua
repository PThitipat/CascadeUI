-- Cascade UI: https://github.com/biggaboy212/Cascade — docs https://biggaboy212.github.io/Cascade/
local function import(owner, repo, version, file)
	local tag = (version == "latest" and "latest/download" or "download/" .. version)
	return loadstring(
		game:HttpGetAsync(("https://github.com/%s/%s/releases/%s/%s"):format(owner, repo, tag, file)),
		file
	)()
end

local cascade = import("biggaboy212", "Cascade", "latest", "dist.luau")

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local minimizeKeybind = Enum.KeyCode.RightControl
local userInputService = UserInputService
local app
local folderName = "JinkX"
local configFileName = folderName .. "/SailorPiece.json"
local popBtn

getgenv().JinkX = getgenv().JinkX or {}
getgenv().JinkX.Configs = getgenv().JinkX.Configs or {
	["AutoFarm_Level"] = false,
	["BossFallbackEnabled"] = true,
	["SelectedMobTarget"] = {},
	["AutofarmSelectedMob"] = false,
	["AutoSkill_Wpn_Z"] = false,
	["AutoSkill_Wpn_X"] = false,
	["AutoSkill_Wpn_C"] = false,
	["AutoSkill_Wpn_V"] = false,
	["AutoSkill_Wpn_F"] = false,
	["AutoSkill_Fruit_Z"] = false,
	["AutoSkill_Fruit_X"] = false,
	["AutoSkill_Fruit_C"] = false,
	["AutoSkill_Fruit_V"] = false,
	["SelectWeapon_Multi"] = nil,
	["SpeedTween"] = 190,
	["AttackHeight"] = 15,
	["AutoHakiQuest"] = false,
	["SelectedChestNames"] = { "Common Chest" },
	["AutoOpenChest"] = false,
	["AutoStats_Melee"] = false,
	["AutoStats_Defense"] = false,
	["AutoStats_Sword"] = false,
	["AutoStats_Power"] = false,
	["StatPointsPerClick"] = 1,
}
getgenv().NoClip = getgenv().NoClip or false

function shallowCopy(t)
	local n = {}
	for k, v in pairs(t) do
		n[k] = v
	end
	return n
end

function SetConfig(key, value)
	getgenv().JinkX.Configs[key] = value
	SaveConfig()
end

function SaveConfig()
	if not isfolder(folderName) then
		makefolder(folderName)
	end
	local copy = shallowCopy(getgenv().JinkX.Configs)
	local json = HttpService:JSONEncode(copy)
	pcall(function()
		writefile(configFileName, json)
	end)
end

function LoadConfig()
	if isfile(configFileName) then
		local content = readfile(configFileName)
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(content)
		end)
		if ok and type(decoded) == "table" then
			for k, v in pairs(decoded) do
				getgenv().JinkX.Configs[k] = v
			end
			task.defer(function()
				app:Notification({
					Title = "JinkX Notification",
					Subtitle = "Config loaded successfully!",
					Icon = cascade.Symbols.checkmark,
					Duration = 5,
				})
			end)
		else
			task.defer(function()
				app:Notification({
					Title = "JinkX Warning!",
					Subtitle = "Failed to decode config",
					Icon = cascade.Symbols.xmark,
					Duration = 5,
				})
			end)
		end
	else
		if not isfolder(folderName) then
			makefolder(folderName)
		end
		local defaultConfig = getgenv().JinkX.Configs or {}
		writefile(configFileName, HttpService:JSONEncode(defaultConfig))
		task.defer(function()
			app:Notification({
				Title = "JinkX Notification",
				Subtitle = "No config found, created default config!",
				Icon = cascade.Symbols.plus,
				Duration = 5,
			})
		end)
	end
end

local function titledRow(parent: any, title: string, subtitle: string?)
	local row = parent:Row({
		SearchIndex = title,
	})
	row:Left():TitleStack({
		Title = title,
		Subtitle = subtitle,
	})
	return row
end

app = cascade.New({
	WindowPill = true,
	Theme = cascade.Themes.Dark,
	Accent = cascade.Accents.Pink,
})

LoadConfig()

local GameData = {}

function GameData.RequireModule(modulePath, timeout)
    timeout = timeout or 3
    local module = nil
    pcall(function()
        local current = ReplicatedStorage
        for segment in string.gmatch(modulePath, "[^%.]+") do
            current = current:WaitForChild(segment, timeout)
            if not current then
                return
            end
        end
        module = require(current)
    end)
    return module
end

function GameData.GetQuestConfig()
    return GameData.RequireModule("Modules.QuestConfig")
end

function GameData.GetNPCConfigs()
    return GameData.RequireModule("NPCConfigs")
end

function GameData.GetTravelConfig()
    return GameData.RequireModule("TravelConfig")
end

function GameData.GetPortalConfig()
    return GameData.RequireModule("PortalConfig")
end

GameData.Cached = {
    QuestMap = nil,
    UniqueLevels = nil,
    NpcTypeToIsland = nil,
    IslandToNpcTypes = nil,
}

function GameData.InvalidateCache()
    GameData.Cached.QuestMap = nil
    GameData.Cached.UniqueLevels = nil
    GameData.Cached.NpcTypeToIsland = nil
    GameData.Cached.IslandToNpcTypes = nil
end

function GameData.GetQuestMap()
    if GameData.Cached.QuestMap then
        return GameData.Cached.QuestMap, GameData.Cached.UniqueLevels
    end

    local QuestConfig = GameData.GetQuestConfig()
    if not QuestConfig or not QuestConfig.RepeatableQuests then
        return {}, {}
    end

    local questMap = {}
    local levels = {}

    for npcName, questData in pairs(QuestConfig.RepeatableQuests) do
        if questData and questData.requirements then
            for _, req in ipairs(questData.requirements) do
                if req.npcType then
                    local level = questData.recommendedLevel or 0
                    local npcType = req.npcType
                    local isBoss = string.find(string.lower(tostring(npcType)), "boss", 1, true) ~= nil

                    questMap[npcType] = {
                        npcType = npcType,
                        npcName = npcName,
                        level = level,
                        title = questData.title or npcName,
                        xp = questData.rewards and questData.rewards.xp or 0,
                        money = questData.rewards and questData.rewards.money or 0,
                        gems = questData.rewards and questData.rewards.gems or 0,
                        amount = req.amount or 1,
                        isBoss = isBoss,
                    }
                    table.insert(levels, level)
                end
            end
        end
    end

    table.sort(levels, function(a, b) return a < b end)
    local seen, unique = {}, {}
    for _, l in ipairs(levels) do
        if not seen[l] then
            seen[l] = true
            table.insert(unique, l)
        end
    end

    GameData.Cached.QuestMap = questMap
    GameData.Cached.UniqueLevels = unique
    return questMap, unique
end

function GameData.GetMobLogicalType(mobName)
    if type(mobName) ~= "string" then return nil end
    local logical = nil
    pcall(function()
        local NPCConfigs = GameData.GetNPCConfigs()
        if NPCConfigs and NPCConfigs.getType then
            logical = NPCConfigs.getType(mobName)
        end
    end)
    return logical
end

function GameData.GetZoneAtPosition(pos)
    local TravelConfig = GameData.GetTravelConfig()
    if not TravelConfig then return nil end

    if TravelConfig.GetZoneAt then
        return TravelConfig.GetZoneAt(pos)
    end

    if TravelConfig.Zones then
        for zoneName, zoneData in pairs(TravelConfig.Zones) do
            if zoneData.Center and zoneData.Size then
                local halfSize = zoneData.Size / 2
                local min = zoneData.Center - halfSize
                local max = zoneData.Center + halfSize

                if pos.X >= min.X and pos.X <= max.X
                    and pos.Y >= min.Y and pos.Y <= max.Y
                    and pos.Z >= min.Z and pos.Z <= max.Z then
                    return zoneName
                end
            end
        end
    end
    return nil
end

function GameData.BuildNpcTypeToIslandCache()
    if GameData.Cached.NpcTypeToIsland then
        return GameData.Cached.NpcTypeToIsland
    end

    local cache = {}
    local npcs = workspace:FindFirstChild("NPCs")

    if npcs then
        local function scanFolder(folder)
            for _, child in pairs(folder:GetChildren()) do
                if child:IsA("Model") then
                    local mobName = child.Name
                    local pos = GameData.GetModelPosition(child)

                    if pos then
                        local zoneName = GameData.GetZoneAtPosition(pos)

                        if zoneName then
                            local logicalType = GameData.GetMobLogicalType(mobName)
                            local npcType = logicalType or mobName:match("^(%D+)")

                            if npcType and npcType ~= "" and not cache[npcType] then
                                cache[npcType] = { zone = zoneName, mobName = mobName }
                            end
                        end
                    end
                elseif child:IsA("Folder") then
                    scanFolder(child)
                end
            end
        end
        scanFolder(npcs)
    end

    if next(cache) == nil then
        local QuestConfig = GameData.GetQuestConfig()
        local TravelConfig = GameData.GetTravelConfig()

        if QuestConfig and QuestConfig.RepeatableQuests and TravelConfig and TravelConfig.Zones then
            local zoneList = {}
            for zName, zData in pairs(TravelConfig.Zones) do
                if zData.Center then
                    local c = zData.Center
                    local dist = math.sqrt(c.X * c.X + c.Z * c.Z)
                    table.insert(zoneList, { name = zName, dist = dist })
                end
            end
            table.sort(zoneList, function(a, b) return a.dist < b.dist end)

            local questList = {}
            for npcName, qData in pairs(QuestConfig.RepeatableQuests) do
                if qData and qData.requirements and qData.recommendedLevel then
                    for _, req in ipairs(qData.requirements) do
                        if req.npcType then
                            table.insert(questList, {
                                npcType = req.npcType,
                                level = qData.recommendedLevel,
                            })
                        end
                    end
                end
            end
            table.sort(questList, function(a, b) return a.level < b.level end)

            local nQuest = #questList
            local nZone = #zoneList
            if nZone >= 1 and nQuest >= 1 then
                local ceilRatio = math.max(1, math.ceil(nQuest / nZone))
                for i, q in ipairs(questList) do
                    if not cache[q.npcType] then
                        local zoneIdx = math.min(math.floor((i - 1) / ceilRatio) + 1, nZone)
                        zoneIdx = math.max(1, zoneIdx)
                        cache[q.npcType] = {
                            zone = zoneList[zoneIdx].name,
                            fromQuestFallback = true,
                        }
                    end
                end
            end
        end
    end

    GameData.Cached.NpcTypeToIsland = cache
    return cache
end

function GameData.GetIslandForNpcType(npcType)
    local cache = GameData.BuildNpcTypeToIslandCache()

    if cache[npcType] then
        return cache[npcType].zone
    end

    local baseType = npcType:match("^(%D+)")
    if baseType and baseType ~= npcType and cache[baseType] then
        return cache[baseType].zone
    end

    return nil
end

function GameData.GetCurrentIslandFromPosition(pos)
    return GameData.GetZoneAtPosition(pos)
end

function GameData.GetModelPosition(model)
    if not model then return nil end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp.Position
    end
    local ok, pivot = pcall(function() return model:GetPivot() end)
    if ok and pivot then
        return pivot.Position
    end
    return nil
end

function GameData.GetPortalForIsland(islandName)
    local PortalConfig = GameData.GetPortalConfig()
    if not PortalConfig or not PortalConfig.Portals then
        return nil
    end

    for portalId, portalData in pairs(PortalConfig.Portals) do
        if portalData.IslandFolder == islandName then
            return {
                id = portalId,
                folder = portalData.IslandFolder,
                displayName = portalData.DisplayName,
            }
        end
    end
    return nil
end

function GameData.ForceUpdateCache()
    GameData.InvalidateCache()
    GameData.BuildNpcTypeToIslandCache()
end

local Utils = {}

function Utils.ShallowCopy(t)
    local n = {}
    for k, v in pairs(t) do n[k] = v end
    return n
end

function Utils.IsBossType(npcType)
    if type(npcType) ~= "string" then return false end
    return npcType:lower():find("boss", 1, true) ~= nil
end

function Utils.MobNameLooksLikeBoss(mobName)
    return string.find(string.lower(tostring(mobName)), "boss", 1, true) ~= nil
end

function Utils.MobNameMatchesNpcType(mobName, npcType)
    if type(mobName) ~= "string" or type(npcType) ~= "string" then return false end
    if mobName == npcType then return true end
    if #mobName <= #npcType then return false end
    if mobName:sub(1, #npcType) ~= npcType then return false end
    local rest = mobName:sub(#npcType + 1)
    return rest:match("^%d+$") ~= nil
end

function Utils.GetPlayerLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local lv = data:FindFirstChild("Level")
        if lv then
            return math.floor(tonumber(lv.Value) or 0)
        end
    end
    return 0
end

function Utils.GetSpeedTween()
    local val = getgenv().JinkX.Configs.SpeedTween or 190
    return math.clamp(val, 90, 200)
end

function Utils.GetAttackHeight()
    local val = getgenv().JinkX.Configs.AttackHeight or 15
    return math.clamp(val, 10, 20)
end

local Remotes = setmetatable({}, {
    __index = function(self, key)
        local remote = nil
        pcall(function()
            local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
            if remoteEvents then
                remote = remoteEvents:FindFirstChild(key)
            end

            if not remote then
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                if remotes then
                    remote = remotes:FindFirstChild(key)
                end
            end

            if not remote then
                remote = ReplicatedStorage:FindFirstChild(key)
            end
        end)

        self[key] = remote
        return remote
    end
})

Remotes.QuestAccept = nil
Remotes.QuestAbandon = nil
Remotes.AcceptQuest = nil
Remotes.AllocateStat = nil
Remotes.UseItem = nil
Remotes.RequestInventory = nil
Remotes.CombatRemote = nil

local Character = {}

function Character.Get()
    return LocalPlayer.Character
end

function Character.GetHRP()
    local char = Character.Get()
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Character.GetPosition()
    local hrp = Character.GetHRP()
    return hrp and hrp.Position or Vector3.zero
end

function Character.GetHumanoid()
    local char = Character.Get()
    return char and char:FindFirstChildOfClass("Humanoid")
end

function Character.IsAlive()
    local humanoid = Character.GetHumanoid()
    return humanoid and humanoid.Health > 0
end

function Character.GetAllParts()
    local char = Character.Get()
    if not char then return {} end

    local parts = {}
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(parts, child)
        end
    end
    return parts
end

function Character.EquipTool(tool)
    local humanoid = Character.GetHumanoid()
    if humanoid and tool and tool:IsA("Tool") then
        humanoid:EquipTool(tool)
        return true
    end
    return false
end

function Character.GetEquippedTool()
    local char = Character.Get()
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            return child
        end
    end
    return nil
end

function Character.GetEquippedFruitName()
    local tool = Character.GetEquippedTool()
    if tool then
        local name = tool.Name
        local knownFruits = { ["Quake"] = true, ["Flame"] = true, ["Light"] = true, ["Bomb"] = true, ["Invisible"] = true }
        if knownFruits[name] then
            return name
        end
    end
    return nil
end

function Character.GetToolByName(name)
    local char = Character.Get()
    local backpack = LocalPlayer.Backpack

    if char then
        local tool = char:FindFirstChild(name)
        if tool and tool:IsA("Tool") then return tool end
    end

    if backpack then
        local tool = backpack:FindFirstChild(name)
        if tool and tool:IsA("Tool") then return tool end
    end

    return nil
end

function Character.GetAllTools()
    local tools = {}
    local char = Character.Get()
    local backpack = LocalPlayer.Backpack

    local function addFrom(parent)
        if parent then
            for _, item in ipairs(parent:GetChildren()) do
                if item:IsA("Tool") and not tools[item.Name] then
                    tools[item.Name] = item
                end
            end
        end
    end

    addFrom(backpack)
    addFrom(char)
    return tools
end

local Quest = {}

local questState = {
    hasRepeatable = false,
    hasQuestline = false,
    repeatableData = nil,
    questlineData = nil,
}

local function setupQuestTracking()
    local success, err = pcall(function()
        local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
        if not remotes then return end
        
        local questUpdate = remotes:WaitForChild("QuestUIUpdate", 5)
        if questUpdate then
            questUpdate.OnClientEvent:Connect(function(action, data)
                data = data or {}
                
                if action == "accepted" or action == "restore" then
                    if data.questType == "repeatable" then
                        questState.hasRepeatable = true
                        questState.repeatableData = {
                            npcName = data.questNpcName,
                            progress = data.progress or {},
                        }
                    elseif data.questType == "questline" then
                        questState.hasQuestline = true
                        questState.questlineData = data
                    end
                elseif action == "abandoned" then
                    if data.questType == "repeatable" or not data.questType then
                        questState.hasRepeatable = false
                        questState.repeatableData = nil
                    end
                    if data.questType == "questline" or data.questlineId then
                        questState.hasQuestline = false
                        questState.questlineData = nil
                    end
                elseif action == "stageAdvanced" then
                    if questState.questlineData and questState.questlineData.questlineId == data.questlineId then
                        questState.questlineData = data
                    end
                elseif action == "questlineComplete" then
                    questState.hasQuestline = false
                    questState.questlineData = nil
                end
            end)
        end
        
        local questProgress = remotes:WaitForChild("QuestProgress", 5)
        if questProgress then
            questProgress.OnClientEvent:Connect(function(data)
                data = data or {}
                if data.questType == "repeatable" and questState.hasRepeatable then
                    if questState.repeatableData then
                        questState.repeatableData.progress = data.progress
                    end
                elseif data.questType == "questline" and questState.hasQuestline then
                    if questState.questlineData then
                        questState.questlineData.progress = data.progress
                        questState.questlineData.goal = data.goal
                        questState.questlineData.bossProgress = data.bossProgress
                    end
                end
            end)
        end
        
        local questComplete = remotes:WaitForChild("QuestComplete", 5)
        if questComplete then
            questComplete.OnClientEvent:Connect(function(data)
                if data.questType == "repeatable" then
                    questState.hasRepeatable = false
                    questState.repeatableData = nil
                end
            end)
        end
    end)
    
    if not success then
        warn("[QUEST] Tracking setup failed:", err)
    end
end

task.spawn(setupQuestTracking)

function Quest.GetCurrent()
    if questState.hasRepeatable and questState.repeatableData then
        local npcName = questState.repeatableData.npcName
        local progress = questState.repeatableData.progress or {}
        
        local currentKill, requiredKill = 0, 0
        for npcType, count in pairs(progress) do
            currentKill = currentKill + (tonumber(count) or 0)
        end
        
        local QuestConfig = GameData.GetQuestConfig()
        if QuestConfig and QuestConfig.RepeatableQuests then
            local qData = QuestConfig.RepeatableQuests[npcName]
            if qData and qData.requirements then
                for _, req in ipairs(qData.requirements) do
                    requiredKill = requiredKill + (req.amount or 0)
                end
            end
            
            if qData then
                return {
                    npcName = npcName,
                    npcType = qData.requirements and qData.requirements[1] and qData.requirements[1].npcType or "Unknown",
                    killCount = currentKill,
                    requiredKills = requiredKill,
                }
            end
        end
        
        return {
            npcName = npcName,
            npcType = "Unknown",
            killCount = currentKill,
            requiredKills = requiredKill,
        }
    end
    
    if questState.hasQuestline and questState.questlineData then
        return {
            npcName = questState.questlineData.questlineId,
            npcType = "Questline",
            killCount = questState.questlineData.progress or 0,
            requiredKills = questState.questlineData.goal or 1,
            isQuestline = true,
        }
    end
    
    return nil
end

function Quest.Complete()
    local success = false
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
        if remotes then
            local repeatRemote = remotes:WaitForChild("QuestRepeat", 8)
            if repeatRemote then
                local currentQ = Quest.GetCurrent()
                local npcName = currentQ and currentQ.npcName or "repeatable"
                repeatRemote:FireServer(npcName)
                success = true
                print("[QUEST] QuestRepeat fired for:", npcName)
            end
        end
    end)
    return success
end

function Quest.HasActive()
    return questState.hasRepeatable or questState.hasQuestline
end

function Quest.IsComplete(questData)
    if not questData then return false end
    return questData.killCount >= questData.requiredKills and questData.requiredKills > 0
end

function Quest.Accept(npcNameKey)
    npcNameKey = npcNameKey or "QuestNPC1"
    print("[QUEST] Accepting:", npcNameKey)

    local success = false
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
        if remotes then
            local qa = remotes:WaitForChild("QuestAccept", 8)
            if qa then
                qa:FireServer(npcNameKey)
                success = true
            end
        end
    end)

    if success then
        print("[QUEST] Accept SUCCESS:", npcNameKey)
        GameData.Cached.NpcTypeToIsland = nil
    else
        print("[QUEST] Accept FAILED:", npcNameKey)
    end

    task.wait(0.5)

    local current = Quest.GetCurrent()
    if current then
        print("[QUEST] Current quest:", current.npcType, current.npcName)
    end

    return success
end

function Quest.Abandon()
    local success = false
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
        if remotes then
            local abandon = remotes:WaitForChild("QuestAbandon", 8)
            if abandon then
                abandon:FireServer("repeatable")
                success = true
            end
        end
    end)
    return success
end

function Quest.FindBest(playerLevel)
    local questMap, _ = GameData.GetQuestMap()
    if not questMap then return nil, nil end

    local currentQuest, currentNpcType = nil, nil

    for npcType, quest in pairs(questMap) do
        if quest.level <= playerLevel then
            if not currentQuest or quest.level > currentQuest.level then
                currentQuest = quest
                currentNpcType = npcType
            elseif quest.level == currentQuest.level then
                local curBoss = currentQuest.isBoss == true
                local newBoss = quest.isBoss == true
                if curBoss and not newBoss then
                    currentQuest = quest
                    currentNpcType = npcType
                end
            end
        end
    end

    return currentQuest, currentNpcType
end

function Quest.FindNext(playerLevel)
    local questMap, _ = GameData.GetQuestMap()
    if not questMap then return nil, nil end

    local nextQuest, nextNpcType = nil, nil

    for npcType, quest in pairs(questMap) do
        if quest.level > playerLevel then
            if not nextQuest or quest.level < nextQuest.level then
                nextQuest = quest
                nextNpcType = npcType
            elseif quest.level == nextQuest.level then
                local curNB = nextQuest.isBoss == true
                local newNB = quest.isBoss == true
                if curNB and not newNB then
                    nextQuest = quest
                    nextNpcType = npcType
                end
            end
        end
    end

    return nextQuest, nextNpcType
end

function Quest.FindPreviousNonBoss(targetLevel)
    local questMap, _ = GameData.GetQuestMap()
    if not questMap then return nil, nil end

    local prevQuest, prevNpcType = nil, nil

    for npcType, quest in pairs(questMap) do
        if not quest.isBoss and quest.level < targetLevel then
            if not prevQuest or quest.level > prevQuest.level then
                prevQuest = quest
                prevNpcType = npcType
            end
        end
    end

    return prevQuest, prevNpcType
end

local MobSystem = {}

function MobSystem.GetNearby(quest, maxDistance)
    maxDistance = maxDistance or math.huge
    if not quest or not quest.npcType then return {} end

    local nearby = {}
    local isQuestBoss = Utils.IsBossType(quest.npcType)
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return nearby end

    local playerPos = Character.GetPosition()

    local function considerMob(mob)
        if not mob:IsA("Model") then return end

        local mobName = mob.Name
        local startsWithNpcType = mobName:find(quest.npcType, 1, true) == 1
        local configType = GameData.GetMobLogicalType(mobName)
        local typeMatchesQuest = (configType == quest.npcType)
        local isMobBoss = Utils.MobNameLooksLikeBoss(mobName)

        if startsWithNpcType or typeMatchesQuest then
            if (not isQuestBoss and isMobBoss) or (isQuestBoss and not isMobBoss) then
                return
            end

            local humanoid = mob:FindFirstChildOfClass("Humanoid")
            local mobPos = GameData.GetModelPosition(mob)

            if (humanoid and humanoid.Health > 0) or mobPos then
                local dist = mobPos and (mobPos - playerPos).Magnitude or 999999

                if dist <= maxDistance then
                    table.insert(nearby, { mob = mob, dist = dist, pos = mobPos })
                end
            end
        end
    end

    local function scanFolder(folder)
        for _, ch in pairs(folder:GetChildren()) do
            if ch:IsA("Folder") then
                scanFolder(ch)
            elseif ch:IsA("Model") then
                considerMob(ch)
            end
        end
    end

    scanFolder(npcs)
    table.sort(nearby, function(a, b) return a.dist < b.dist end)

    return nearby
end

function MobSystem.GetAliveCount(quest)
    local nearby = MobSystem.GetNearby(quest)
    return #nearby
end

function MobSystem.IsBossAlive(questNpcType)
    if not questNpcType then return false end
    if not Utils.IsBossType(questNpcType) then return false end

    local nearby = MobSystem.GetNearby({ npcType = questNpcType }, 500)
    return #nearby > 0
end

function MobSystem.IsQuestBossAlive(questNpcName)
    if not questNpcName then return false end
    local questMap, _ = GameData.GetQuestMap()
    if not questMap then return false end

    local targetNpcType = nil
    for npcType, qData in pairs(questMap) do
        if qData and qData.npcName == questNpcName and qData.isBoss then
            targetNpcType = npcType
            break
        end
    end
    if not targetNpcType then
        targetNpcType = questNpcName
    end

    local npcFolder = workspace:FindFirstChild("NPCs")
    if not npcFolder then
        return false
    end

    local function searchFolder(folder)
        for _, child in pairs(folder:GetChildren()) do
            if child:IsA("Model") and Utils.MobNameLooksLikeBoss(child.Name) then
                local childName = child.Name
                local matches = false
                if childName == targetNpcType then
                    matches = true
                elseif childName:find(targetNpcType, 1, true) == 1 then
                    matches = true
                elseif targetNpcType:find("Boss", 1, true) then
                    local baseType = targetNpcType:gsub("[Bb]oss", ""):gsub("Boss", "")
                    if baseType ~= targetNpcType and childName:find(baseType, 1, true) then
                        matches = true
                    end
                end
                if matches then
                    local hum = child:FindFirstChildOfClass("Humanoid")
                    return hum and hum.Health > 0
                end
            elseif child:IsA("Folder") then
                local found = searchFolder(child)
                if found then return found end
            end
        end
        return false
    end

    return searchFolder(npcFolder)
end

function MobSystem.ScanForQuest(targetLevel)
    local questMap, _ = GameData.GetQuestMap()
    if not questMap then return {} end

    local results = {}
    local playerPos = Character.GetPosition()

    local function findMobFolders()
        local folders = {}
        local npcs = workspace:FindFirstChild("NPCs")
        if npcs then table.insert(folders, npcs) end

        for _, child in pairs(workspace:GetChildren()) do
            if child:IsA("Folder")
                and child.Name ~= "Camera"
                and child.Name ~= "Terrain"
                and not string.find(child.Name, "TimedBossSpawn") then

                local hasMob = false
                for _, c in pairs(child:GetChildren()) do
                    if c:IsA("Model") and c:FindFirstChild("Humanoid") then
                        hasMob = true
                        break
                    end
                end

                if hasMob and not table.find(folders, child) then
                    table.insert(folders, child)
                end
            end
        end

        return folders
    end

    local function scanFolder(folder)
        if not folder then return end

        for _, obj in pairs(folder:GetChildren()) do
            if obj:IsA("Model") then
                local humanoid = obj:FindFirstChild("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart")

                if humanoid and hrp and humanoid.Health > 0 then
                    local pos = hrp.Position
                    local mobName = obj.Name
                    local matchedQuest, matchedType = nil, nil

                    local npcTypesSorted = {}
                    for nt in pairs(questMap) do
                        table.insert(npcTypesSorted, nt)
                    end
                    table.sort(npcTypesSorted, function(a, b) return #a > #b end)

                    for _, npcType in ipairs(npcTypesSorted) do
                        local quest = questMap[npcType]
                        if quest.level == targetLevel and Utils.MobNameMatchesNpcType(mobName, npcType) then
                            if Utils.MobNameLooksLikeBoss(mobName) and not Utils.IsBossType(npcType) then
                            else
                                matchedQuest, matchedType = quest, npcType
                                break
                            end
                        end
                    end

                    if matchedQuest then
                        if not results[matchedType] then
                            results[matchedType] = {
                                npcType = matchedType,
                                level = matchedQuest.level,
                                title = matchedQuest.title,
                                positions = {},
                            }
                        end

                        local dist = 0
                        if playerPos then
                            dist = math.floor((pos - playerPos).Magnitude)
                        end

                        table.insert(results[matchedType].positions, {
                            name = mobName,
                            model = obj,
                            dist = dist,
                        })
                    end
                end

                scanFolder(obj)
            elseif obj:IsA("Folder") then
                scanFolder(obj)
            end
        end
    end

    for _, folder in ipairs(findMobFolders()) do
        scanFolder(folder)
    end

    return results
end

local Teleport = {}

local cachedFolderToPortal = nil
local cachedZoneToPortal = nil

function Teleport.GetFolderToPortalMapping()
    if cachedFolderToPortal then return cachedFolderToPortal end
    cachedFolderToPortal = {}
    pcall(function()
        local portalConfig = require(ReplicatedStorage:WaitForChild("PortalConfig", 5))
        if portalConfig and portalConfig.Portals then
            for portalName, portalData in pairs(portalConfig.Portals) do
                if portalData.IslandFolder then
                    cachedFolderToPortal[portalData.IslandFolder] = portalName
                end
            end
        end
    end)
    return cachedFolderToPortal
end

function Teleport.GetZoneToPortalMapping()
    if cachedZoneToPortal then return cachedZoneToPortal end
    cachedZoneToPortal = {}
    local folderToPortal = Teleport.GetFolderToPortalMapping()
    for folderName, portalName in pairs(folderToPortal) do
        cachedZoneToPortal[folderName] = portalName
        local spaced = folderName:gsub("(%u)", " %1"):gsub("^ ", "")
        cachedZoneToPortal[spaced] = portalName
    end
    return cachedZoneToPortal
end

function Teleport.ConvertToPortalName(islandFolderName)
    if not islandFolderName then return nil end
    local folderToPortal = Teleport.GetFolderToPortalMapping()
    if folderToPortal[islandFolderName] then
        return folderToPortal[islandFolderName]
    end
    return islandFolderName:gsub("Island$", ""):gsub(" Island", "")
end

function Teleport.GetIslandZones()
    local zones = {}
    pcall(function()
        local travelConfig = require(ReplicatedStorage:WaitForChild("TravelConfig", 5))
        if travelConfig and travelConfig.Zones then
            zones = travelConfig.Zones
        end
    end)
    return zones
end

function Teleport.GetClosestIsland(npcPos)
    if not npcPos then return nil, nil end
    local zones = Teleport.GetIslandZones()

    for islandName, zoneData in pairs(zones) do
        if zoneData.Center and zoneData.Size then
            local center = zoneData.Center
            local halfSize = zoneData.Size / 2
            local minPos = center - halfSize
            local maxPos = center + halfSize
            if npcPos.X >= minPos.X and npcPos.X <= maxPos.X
                and npcPos.Y >= minPos.Y and npcPos.Y <= maxPos.Y
                and npcPos.Z >= minPos.Z and npcPos.Z <= maxPos.Z then
                return islandName, zoneData
            end
        end
    end

    local closest = nil
    local closestDist = math.huge
    local closestData = nil
    for islandName, zoneData in pairs(zones) do
        if zoneData.Center then
            local dist = (npcPos - zoneData.Center).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = islandName
                closestData = zoneData
            end
        end
    end

    if closest then
        print("[DEBUG-ISLAND] GetClosestIsland fallback:", closest, "dist:", closestDist)
    end
    return closest, closestData
end

local currentTween = nil
local lastPortalTpTime = 0
local PORTAL_TP_COOLDOWN = 1
local lastTeleportedIsland = nil
local lastSmartTweenTime = 0
local SMART_TWEEN_COOLDOWN = 0.1

function Teleport.CancelCurrentTween()
    if currentTween then
        pcall(function() currentTween:Cancel() end)
        currentTween = nil
    end
end

function Teleport.ToPosition(pos, heightOffset, lookAtPos)
    local char = Character.Get()
    if not char then return false end

    local humanoid = Character.GetHumanoid()
    if not humanoid or humanoid.Health <= 0 then return false end

    local hrp = Character.GetHRP()
    if not hrp then return false end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    local targetPos = pos
    local distance = (hrp.Position - targetPos).Magnitude
    local speed = Utils.GetSpeedTween()
    local dur = math.max(0.1, distance / speed)

    Teleport.CancelCurrentTween()

    local targetCFrame
    if lookAtPos then
        targetCFrame = CFrame.lookAt(targetPos, lookAtPos)
    else
        targetCFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0)
    end

    local tweenInfo = TweenInfo.new(dur, Enum.EasingStyle.Linear)
    currentTween = TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })
    currentTween:Play()
    return true
end

function Teleport.SmartTween(targetPos, lookAtPos, npcType)
    if typeof(targetPos) == "Instance" and targetPos:IsA("BasePart") then
        targetPos = targetPos.Position
    elseif typeof(targetPos) == "CFrame" then
        targetPos = targetPos.Position
    end

    local char = Character.Get()
    if not char then return false end

    local hrp = Character.GetHRP()
    if not hrp then return false end

    if not Character.IsAlive() then return false end

    local attackHeight = Utils.GetAttackHeight()

    local fromPos = hrp.Position
    local distDirect = (targetPos - fromPos).Magnitude

    local MELEE_THRESHOLD = 30

    if distDirect <= MELEE_THRESHOLD then
        hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, attackHeight, 0)
        return true
    end

    local targetNpcTypeIsland = nil
    if npcType then
        targetNpcTypeIsland = GameData.GetIslandForNpcType(npcType)
    end

    local currentIsland = GameData.GetCurrentIslandFromPosition(fromPos)
    local targetIsland = targetNpcTypeIsland or (npcType and GameData.GetIslandForNpcType(npcType))

    if targetIsland and currentIsland == targetIsland then
        Teleport.CancelCurrentTween()
        local attackCFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, attackHeight, 0)
        Teleport.ToPosition(attackCFrame.Position, nil, lookAtPos)
        return true
    end

    local zones = Teleport.GetIslandZones()
    local bestIsland = nil
    local bestIslandCenter = nil
    local bestDistSaving = -math.huge

    if targetNpcTypeIsland then
        local zoneData = zones and zones[targetNpcTypeIsland]
        bestIsland = targetNpcTypeIsland
        bestIslandCenter = (zoneData and zoneData.Center) or fromPos
        bestDistSaving = distDirect
        print("[SmartTween] npcType island:", targetNpcTypeIsland, "npcType:", tostring(npcType))
    end

    if not bestIsland then
        for islandName, zoneData in pairs(zones) do
            if zoneData.Center then
                local islandPos = zoneData.Center
                local distFromIslandToTarget = (islandPos - targetPos).Magnitude
                local distFromPlayerToIsland = (islandPos - fromPos).Magnitude

                if distFromIslandToTarget < distDirect
                    and distFromPlayerToIsland <= 2000 then
                    local saving = distDirect - distFromIslandToTarget
                    if saving > bestDistSaving then
                        bestDistSaving = saving
                        bestIsland = islandName
                        bestIslandCenter = islandPos
                    end
                end
            end
        end
    end

    if bestIsland and bestIslandCenter then
        if targetNpcTypeIsland and bestIsland == targetNpcTypeIsland then
            print("[SmartTween] portal ->", bestIsland, "(quest/npcType)")
        else
            print("[SmartTween] shortcut:", bestIsland, "saving:", math.floor(bestDistSaving), "studs")
        end
        Teleport.ToIsland(bestIsland)
        task.wait(0.9)

        char = Character.Get()
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        Teleport.CancelCurrentTween()

        if distDirect <= MELEE_THRESHOLD then
            hrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, attackHeight, 0)
            return true
        end

        local attackCFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, attackHeight, 0)
        local afterPos = hrp.Position
        local distAfterTp = (attackCFrame.Position - afterPos).Magnitude

        if distAfterTp > MELEE_THRESHOLD then
            Teleport.ToPosition(attackCFrame.Position, nil, lookAtPos)
        else
            hrp.CFrame = attackCFrame
        end
        return true
    end

    Teleport.CancelCurrentTween()
    local attackCFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, attackHeight, 0)
    Teleport.ToPosition(attackCFrame.Position, nil, lookAtPos)
    return true
end

function Teleport.ToIsland(islandName)
    if not islandName then return false end

    local zoneToPortal = Teleport.GetZoneToPortalMapping()
    local portalName = zoneToPortal[islandName]
    if not portalName then
        portalName = Teleport.ConvertToPortalName(islandName)
    end
    if not portalName then return false end

    local now = tick()
    if lastTeleportedIsland == portalName and (now - lastPortalTpTime) < 3 then
        return false
    end
    if now - lastPortalTpTime < PORTAL_TP_COOLDOWN then
        return false
    end

    pcall(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
        local tpPortal = remotes:WaitForChild("TeleportToPortal", 5)
        if tpPortal then
            tpPortal:FireServer(portalName)
            lastPortalTpTime = now
            lastTeleportedIsland = portalName
            print("[TELEPORT] Teleporting to:", portalName)
        end
    end)

    return true
end

function Teleport.ToNpc(npcType)
    local islandName = GameData.GetIslandForNpcType(npcType)
    if islandName then
        return Teleport.ToIsland(islandName)
    end
    return false
end

local Combat = {}

Combat.LastAttackTime = 0
Combat.AttackCooldown = 0.3
Combat.LastEquipTime = 0
Combat.EquipCooldown = 0.3
Combat.CurrentWeaponIndex = 1
Combat.LastEquippedCharId = nil
Combat.LastEquippedWeapons = {}

function Combat.FireAttack(targetPos)
    pcall(function()
        local combatRemote = game:GetService("ReplicatedStorage")
            :WaitForChild("CombatSystem")
            :WaitForChild("Remotes")
            :WaitForChild("RequestHit")
        if targetPos then
            combatRemote:FireServer(targetPos)
        else
            combatRemote:FireServer()
        end
    end)
end

Combat.FireNormalAttack = Combat.FireAttack

function Combat.Attack(pos)
    Combat.FireAttack(pos)
    return true
end

function Combat.GetAttackPosition(targetPos)
    local height = Utils.GetAttackHeight()
    return CFrame.new(0, height, 0) * CFrame.Angles(math.rad(-90), 0, 0)
end

function Combat.GetMouseTargetPos()
    local mouse = LocalPlayer:GetMouse()
    local ray = workspace:Raycast(mouse.UnitRay.Origin, mouse.UnitRay.Direction * 500, RaycastParams.new())
    return ray and ray.Position or mouse.UnitRay.Origin + mouse.UnitRay.Direction * 100
end

Combat.SkillCooldowns = {}
Combat.SkillCooldownTime = 0.35

function Combat.CastSkill(slot)
    slot = slot or 1
    local now = tick()
    local key = "slot_" .. slot

    if Combat.SkillCooldowns[key] and (now - Combat.SkillCooldowns[key]) < Combat.SkillCooldownTime then
        return false
    end

    pcall(function()
        local abilityRemote = ReplicatedStorage:FindFirstChild("AbilitySystem")
            and ReplicatedStorage.AbilitySystem:FindFirstChild("Remotes")
            and ReplicatedStorage.AbilitySystem.Remotes:FindFirstChild("RequestAbility")

        if abilityRemote then
            abilityRemote:FireServer(slot)
            Combat.SkillCooldowns[key] = now
        end
    end)

    return true
end

function Combat.CastFruitAbility(fruitName, keyCode)
    pcall(function()
        local fruitRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
            and ReplicatedStorage.RemoteEvents:FindFirstChild("FruitPowerRemote")

        if fruitRemote then
            fruitRemote:FireServer("UseAbility", {
                ["FruitPower"] = fruitName,
                ["KeyCode"] = keyCode,
                ["TargetPosition"] = Combat.GetMouseTargetPos(),
            })
        end
    end)
end

function Combat.AutoUseSkills()
    local cfg = getgenv().JinkX.Configs
    if not cfg then return end

    local now = tick()

    local wpnKeyToSlot = { ["Z"] = 1, ["X"] = 2, ["C"] = 3, ["V"] = 4, ["F"] = 5 }
    local wpnKeys = { "Z", "X", "C", "V", "F" }

    for _, key in ipairs(wpnKeys) do
        local cfgKey = "AutoSkill_Wpn_" .. key
        if cfg[cfgKey] then
            local slot = wpnKeyToSlot[key]
            Combat.CastSkill(slot)
        end
    end

    local fruitName = Character.GetEquippedFruitName()
    if fruitName then
        local fruitKeys = { "Z", "X", "C", "V" }
        for _, key in ipairs(fruitKeys) do
            local cfgKey = "AutoSkill_Fruit_" .. key
            if cfg[cfgKey] then
                Combat.CastFruitAbility(fruitName, Enum.KeyCode[key])
            end
        end
    end
end

Combat.CurrentWeaponIndex = 1
Combat.LastEquipTime = 0
Combat.EquipCooldown = 0.8
Combat.LastEquippedCharId = nil

function Combat.GetSelectedWeapons()
    local config = getgenv().JinkX.Configs.SelectWeapon_Multi
    if not config then return {} end

    local allTools = Character.GetAllTools()
    local allWeapons = {}
    for name in pairs(allTools) do
        table.insert(allWeapons, name)
    end
    table.sort(allWeapons)

    local selected = {}
    if type(config) == "string" then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(config)
        end)
        if ok and type(decoded) == "table" then
            config = decoded
        else
            return {}
        end
    end

    if type(config) == "table" then
        for _, v in ipairs(config) do
            if type(v) == "number" then
                local weaponName = allWeapons[v]
                if weaponName then
                    table.insert(selected, weaponName)
                end
            elseif type(v) == "string" then
                table.insert(selected, v)
            end
        end
    end

    return selected
end

function Combat.SmartEquipWeapons()
    pcall(function()
        local selected = Combat.GetSelectedWeapons()
        if not selected or #selected == 0 then return end

        local char = Character.Get()
        if not char then return end

        local humanoid = Character.GetHumanoid()
        if not humanoid or humanoid.Health <= 0 then return end

        local now = tick()
        local charId = char:GetFullName()

        local currentToolName = nil
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                currentToolName = tool.Name
                break
            end
        end

        if (now - Combat.LastEquipTime) >= Combat.EquipCooldown then
            Combat.CurrentWeaponIndex = (Combat.CurrentWeaponIndex % #selected) + 1

            if charId ~= Combat.LastEquippedCharId then
                Combat.CurrentWeaponIndex = 1
            end
        end

        local weaponToEquip = selected[Combat.CurrentWeaponIndex]

        if currentToolName == weaponToEquip then
            return
        end

        if charId ~= Combat.LastEquippedCharId then
            Combat.LastEquippedWeapons = {}
        end

        local tool = Character.GetToolByName(weaponToEquip)

        if tool then
            for _, oldTool in ipairs(char:GetChildren()) do
                if oldTool:IsA("Tool") then
                    oldTool.Parent = LocalPlayer.Backpack
                end
            end

            Character.EquipTool(tool)
            Combat.LastEquipTime = now
            Combat.LastEquippedCharId = charId
            Combat.LastEquippedWeapons[weaponToEquip] = true
        end
    end)
end

do
	local window = app:Window({
		Title = "JinkX",
		Subtitle = "https://discord.gg/XAfp5RsQ4M",
		Size = userInputService.TouchEnabled and UDim2.fromOffset(550, 325) or UDim2.fromOffset(850, 530),
	})

	userInputService.InputEnded:Connect(function(input, gameProcessedEvent)
		if input.KeyCode == minimizeKeybind and not gameProcessedEvent then
			window.Minimized = not window.Minimized
		end
	end)

	window.Destroying:Connect(function()
	end)

	do
		local section = window:Section({
			Disclosure = false,
			Title = "Sailor Piece",
		})

		do
			local tab = section:Tab({
				Selected = true,
				Title = "Main",
				Icon = cascade.Symbols.switch2,
			})

			do
				local form = tab:Form()

				do
					local row = titledRow(
						form,
						"Autofarm Level [1-Max]",
						"Auto farm mobs based on your current quest level."
					)

					row:Right():Toggle({
						Value = getgenv().JinkX.Configs.AutoFarm_Level,
						ValueChanged = function(self, value: boolean)
							getgenv().JinkX.Configs.AutoFarm_Level = value
							SaveConfig()
						end,
					})
				end

				do
					local row = titledRow(
						form,
						"Double Quest",
						"When boss is not spawned, switch to previous normal quest."
					)

					row:Right():Toggle({
						Value = getgenv().JinkX.Configs.BossFallbackEnabled ~= false,
						ValueChanged = function(self, value: boolean)
							getgenv().JinkX.Configs.BossFallbackEnabled = value
							SaveConfig()
						end,
					})
				end

				do
					local row = titledRow(
						form,
						"Select Mob Target",
						"Select a mob to farm. Toggle enables Auto Farm."
					)

					popBtn = row:Right():PopUpButton({
						Options = { "None" },
						Value = 1,
						ValueChanged = function(self, idx: number)
							local val = self.Options[idx]
							getgenv().JinkX.Configs.SelectedMobTarget = (val == "None" and nil or val)
							SaveConfig()
						end,
					})

				end

				do
					local row = titledRow(
						form,
						"Auto Farm Selected",
						"Run independently. Accepts & farms the selected mob only."
					)

					row:Right():Toggle({
						Value = getgenv().JinkX.Configs.AutofarmSelectedMob == true,
						ValueChanged = function(self, value: boolean)
							getgenv().JinkX.Configs.AutofarmSelectedMob = value
							SaveConfig()
						end,
					})
				end

				do
					local row = titledRow(
						form,
						"Auto Haki Quest",
						"Auto complete Haki questline (Kill 150 NPCs -> Z Ability 65x -> Punch 750x)"
					)

					row:Right():Toggle({
						Value = getgenv().JinkX.Configs.AutoHakiQuest == true,
						ValueChanged = function(self, value: boolean)
							getgenv().JinkX.Configs.AutoHakiQuest = value
							SaveConfig()
						end,
					})
				end

			local function GetSpeedTween()
				local val = getgenv().JinkX.Configs.SpeedTween or 190
				return math.clamp(val, 90, 200)
			end

			local function GetAttackHeight()
				local val = getgenv().JinkX.Configs.AttackHeight or 15
				return math.clamp(val, 10, 20)
			end

				do
					local speedRow = titledRow(
						form,
						"Tween Speed",
						"Speed for teleporting to monsters (90-200)."
					)
					local speedLabel = speedRow:Right():Label()
					speedLabel.Text = tostring(math.clamp(getgenv().JinkX.Configs.SpeedTween or 190, 90, 200))

					local speedSlider = speedRow:Right():Slider({
						Minimum = 90,
						Maximum = 200,
						Value = math.clamp(getgenv().JinkX.Configs.SpeedTween or 190, 90, 200),
						ValueChanged = function(self, value: number)
							local rounded = math.floor(value + 0.5)
							getgenv().JinkX.Configs.SpeedTween = rounded
							speedLabel.Text = tostring(rounded)
							SaveConfig()
						end,
					})
				end

				do
					local heightRow = titledRow(
						form,
						"Attack Height",
						"Height above target when attacking (10-20)."
					)
					local heightLabel = heightRow:Right():Label()
					heightLabel.Text = tostring(math.clamp(getgenv().JinkX.Configs.AttackHeight or 15, 10, 20))

					local heightSlider = heightRow:Right():Slider({
						Minimum = 10,
						Maximum = 30,
						Value = math.clamp(getgenv().JinkX.Configs.AttackHeight or 15, 10, 20),
						ValueChanged = function(self, value: number)
							local rounded = math.floor(value + 0.5)
							getgenv().JinkX.Configs.AttackHeight = rounded
							heightLabel.Text = tostring(rounded)
							SaveConfig()
						end,
					})
				end

				local AllocateStat = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("AllocateStat")

				getgenv().JinkX.Configs.AutoStats_Melee = getgenv().JinkX.Configs.AutoStats_Melee or false
				getgenv().JinkX.Configs.AutoStats_Defense = getgenv().JinkX.Configs.AutoStats_Defense or false
				getgenv().JinkX.Configs.AutoStats_Sword = getgenv().JinkX.Configs.AutoStats_Sword or false
				getgenv().JinkX.Configs.AutoStats_Power = getgenv().JinkX.Configs.AutoStats_Power or false
				getgenv().JinkX.Configs.StatPointsPerClick = getgenv().JinkX.Configs.StatPointsPerClick or 1

				local function AutoUpgradeStats()
					local Data = game:GetService("Players").LocalPlayer:FindFirstChild("Data")
					if not Data then return end
					local StatPoints = Data:FindFirstChild("StatPoints")
					if not StatPoints or StatPoints.Value <= 0 then return end

					local points = math.min(StatPoints.Value, getgenv().JinkX.Configs.StatPointsPerClick)

					if getgenv().JinkX.Configs.AutoStats_Melee then
						AllocateStat:FireServer("Melee", points)
					end
					if getgenv().JinkX.Configs.AutoStats_Defense then
						AllocateStat:FireServer("Defense", points)
					end
					if getgenv().JinkX.Configs.AutoStats_Sword then
						AllocateStat:FireServer("Sword", points)
					end
					if getgenv().JinkX.Configs.AutoStats_Power then
						AllocateStat:FireServer("Power", points)
					end
				end

				spawn(function()
					while true do
						task.wait(0.1)
						AutoUpgradeStats()
					end
				end)

				local statsTab = section:Tab({
					Selected = false,
					Title = "Stats",
					Icon = cascade.Symbols.bolt,
				})

				local statsForm = statsTab:Form()

				local inventoryTab = section:Tab({
					Selected = false,
					Title = "Inventory",
					Icon = cascade.Symbols.cube,
				})

				local inventoryForm = inventoryTab:Form()

				local bossTab = section:Tab({
					Selected = false,
					Title = "Boss",
					Icon = cascade.Symbols.bolt,
				})

				local bossForm = bossTab:Form()

				local questTab = section:Tab({
					Selected = false,
					Title = "Quest",
					Icon = cascade.Symbols.plus,
				})

				local questForm = questTab:Form()

				do
					getgenv().JinkX.Configs.AutoHakiQuest = getgenv().JinkX.Configs.AutoHakiQuest or false

					local hakiRow = titledRow(
						questForm,
						"Auto Haki Quest",
						"Auto accept & complete Haki questline (Path to Haki 1-3)"
					)

					hakiRow:Right():Toggle({
						Value = getgenv().JinkX.Configs.AutoHakiQuest,
						ValueChanged = function(self, value: boolean)
							getgenv().JinkX.Configs.AutoHakiQuest = value
							SaveConfig()
						end,
					})
				end

				local dungeonTab = section:Tab({
					Selected = false,
					Title = "Dungeon",
					Icon = cascade.Symbols.squareStack3dUp,
				})

				local dungeonForm = dungeonTab:Form()

				do
					local row = titledRow(statsForm, "Auto Stats Melee", "Automatically upgrade Melee stat.")
					row:Right():Toggle({
						Value = getgenv().JinkX.Configs.AutoStats_Melee,
						ValueChanged = function(self, value)
							getgenv().JinkX.Configs.AutoStats_Melee = value
							SaveConfig()
						end,
					})
				end

				do
					local row = titledRow(statsForm, "Auto Stats Defense", "Automatically upgrade Defense stat.")
					row:Right():Toggle({
						Value = getgenv().JinkX.Configs.AutoStats_Defense,
						ValueChanged = function(self, value)
							getgenv().JinkX.Configs.AutoStats_Defense = value
							SaveConfig()
						end,
					})
				end

				do
					local row = titledRow(statsForm, "Auto Stats Sword", "Automatically upgrade Sword stat.")
					row:Right():Toggle({
						Value = getgenv().JinkX.Configs.AutoStats_Sword,
						ValueChanged = function(self, value)
							getgenv().JinkX.Configs.AutoStats_Sword = value
							SaveConfig()
						end,
					})
				end

				do
					local row = titledRow(statsForm, "Auto Stats Power", "Automatically upgrade Power stat.")
					row:Right():Toggle({
						Value = getgenv().JinkX.Configs.AutoStats_Power,
						ValueChanged = function(self, value)
							getgenv().JinkX.Configs.AutoStats_Power = value
							SaveConfig()
						end,
					})
				end

				do
					local row = titledRow(statsForm, "Points Per Click", "How many stat points to spend each tick.")
					local pointsLabel = row:Right():Label()
					pointsLabel.Text = tostring(getgenv().JinkX.Configs.StatPointsPerClick)

					row:Right():Slider({
						Minimum = 1,
						Maximum = 50,
						Value = getgenv().JinkX.Configs.StatPointsPerClick,
						ValueChanged = function(self, value)
							local rounded = math.floor(value + 0.5)
							getgenv().JinkX.Configs.StatPointsPerClick = rounded
							pointsLabel.Text = tostring(rounded)
							SaveConfig()
						end,
					})
				end

				local inventoryForm = inventoryTab:Form()

				do
					local row = titledRow(
						inventoryForm,
						"Select Chest Types",
						"Select chest types to auto open."
					)

					local chestOptions = {
						"Common Chest",
						"Rare Chest",
						"Epic Chest",
						"Legendary Chest",
						"Mythical Chest",
						"Secret Chest"
					}

					local CONFIG_KEY_CHEST = "SelectedChestNames"

					local function savedChestNamesToIndices(list)
						local saved = getgenv().JinkX.Configs[CONFIG_KEY_CHEST]
						if not saved or type(saved) ~= "table" then return nil end
						local indices = {}
						for _, name in ipairs(saved) do
							for i, opt in ipairs(list) do
								if opt == name then
									indices[#indices + 1] = i
									break
								end
							end
						end
						return #indices > 0 and indices or nil
					end

					local function mergeSavedChestsIntoList(currentList)
						local saved = getgenv().JinkX.Configs[CONFIG_KEY_CHEST]
						if not saved then return currentList end
						local seen = {}
						for _, v in ipairs(currentList) do seen[v] = true end
						for _, name in ipairs(saved) do
							if not seen[name] then
								currentList[#currentList + 1] = name
							end
						end
						return currentList
					end

					local weaponList = mergeSavedChestsIntoList(chestOptions)

					local defaultValue = nil
					if #weaponList > 0 then
						defaultValue = {1}
					end

					local MAX_MULTI = 999

					local function selectionIndices(value)
						if type(value) == "number" then
							return { value }
						end
						if type(value) == "table" then
							return value
						end
						return {}
					end

					local initialIndices = savedChestNamesToIndices(weaponList) or defaultValue

					local multi = row:Right():PopUpButton({
						Options = weaponList,
						Maximum = MAX_MULTI,
						Value = initialIndices,
						ValueChanged = function(self, value)
							local names = {}
							for _, idx in ipairs(selectionIndices(value)) do
								local n = self.Options[idx]
								if n then
									table.insert(names, n)
								end
							end
							getgenv().JinkX.Configs[CONFIG_KEY_CHEST] = names
							SaveConfig()
						end,
					})
				end

				do
					local row = titledRow(
						inventoryForm,
						"Auto Open Chest",
						"Automatically open selected chest types."
					)

					row:Right():Toggle({
						Value = getgenv().JinkX.Configs.AutoOpenChest,
						ValueChanged = function(self, value: boolean)
							getgenv().JinkX.Configs.AutoOpenChest = value
							SaveConfig()
						end,
					})
				end

				local UseItemRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem")
				local RequestInventory = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestInventory")
				local UpdateInventory = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateInventory")

				local chestInventoryCache = {}
				local lastInventoryRequest = 0
				local INVENTORY_REQUEST_COOLDOWN = 2

				UpdateInventory.OnClientEvent:Connect(function(category, data)
					if category == "Items" and type(data) == "table" then
						chestInventoryCache = {}
						for _, item in pairs(data) do
							if type(item) == "table" and item.name then
								chestInventoryCache[item.name] = item.quantity or 0
							end
						end
					end
				end)

				local function ensureInventoryData()
					local now = tick()
					if next(chestInventoryCache) == nil or (now - lastInventoryRequest) > INVENTORY_REQUEST_COOLDOWN then
						lastInventoryRequest = now
						RequestInventory:FireServer()
						task.wait(0.5)
					end
				end

				spawn(function()
					while true do
						task.wait(0.1)
						if getgenv().JinkX.Configs.AutoOpenChest then
							ensureInventoryData()

							local selectedChests = getgenv().JinkX.Configs.SelectedChestNames or {}

							for _, chestName in ipairs(selectedChests) do
								if chestName then
									local amount = chestInventoryCache[chestName] or 0
									if amount > 0 then
										local args = {
											[1] = "Use",
											[2] = chestName,
											[3] = 1,
											[4] = false
										}
										UseItemRemote:FireServer(unpack(args))
										task.wait(0.3)
									end
								end
							end
						end
					end
				end)

				task.spawn(function()
					local maxAttempts = 50
					for _ = 1, maxAttempts do
						task.wait()
						local questMap = GameData.GetQuestMap()
						if questMap and next(questMap) ~= nil then
							local mobOptions = {}
							for npcType in pairs(questMap) do
								table.insert(mobOptions, npcType)
							end
							table.sort(mobOptions)
							if #mobOptions >= 1 then
								local target = getgenv().JinkX.Configs.SelectedMobTarget
								local newIdx = 1
								for j, v in ipairs(mobOptions) do
									if v == target then
										newIdx = j
										break
									end
								end
								for _, opt in ipairs(mobOptions) do
									popBtn:Option(opt)
								end
								popBtn.Value = newIdx
								break
							end
						end
					end
				end)
		do
					local CONFIG_KEY = 'SelectWeapon_Multi'
					local Players = game:GetService("Players")

					local function getRawWeaponConfig()
						local raw = getgenv().JinkX.Configs[CONFIG_KEY]
						if not raw then return nil end
						if type(raw) == "string" then
							local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
							if ok and type(decoded) == "table" then return decoded end
							return nil
						end
						if type(raw) == "table" then return raw end
						return nil
					end

					local function savedNamesToIndices(weaponList)
						local raw = getRawWeaponConfig()
						if not raw or #raw == 0 then return nil end
						local indices = {}
						local allNumbers = true
						for _, v in ipairs(raw) do
							if type(v) ~= "number" then
								allNumbers = false
								break
							end
						end
						if allNumbers then
							for _, idx in ipairs(raw) do
								if type(idx) == "number" and weaponList[idx] then
									table.insert(indices, idx)
								end
							end
						else
							for _, name in ipairs(raw) do
								if type(name) == "string" then
									for i, w in ipairs(weaponList) do
										if w == name then
											table.insert(indices, i)
											break
										end
									end
								end
							end
						end
						return #indices > 0 and indices or nil
					end

					local function getWeaponsFromCharacter()
						local weapons = {}
						local player = Players.LocalPlayer
						local character = player and player.Character
						local backpack = player and player.Backpack

						if backpack then
							for _, item in ipairs(backpack:GetChildren()) do
								if item:IsA("Tool") then
									table.insert(weapons, item.Name)
								end
							end
						end

						if character then
							for _, item in ipairs(character:GetChildren()) do
								if item:IsA("Tool") then
									table.insert(weapons, item.Name)
								end
							end
						end

						local seen = {}
						local unique = {}
						for _, name in ipairs(weapons) do
							if not seen[name] then
								seen[name] = true
								table.insert(unique, name)
							end
						end
						table.sort(unique)
						return unique
					end

					local function mergeSavedNamesIntoWeaponList(baseList)
						local merged = {}
						local seen = {}
						for _, name in ipairs(baseList) do
							if not seen[name] then
								seen[name] = true
								table.insert(merged, name)
							end
						end
						local raw = getRawWeaponConfig()
						if raw and type(raw) == "table" then
							for _, v in ipairs(raw) do
								if type(v) == "string" and not seen[v] then
									seen[v] = true
									table.insert(merged, v)
								end
							end
						end
						table.sort(merged)
						return merged
					end

					local row = titledRow(
						form,
						"Select Weapon [Multiple]",
						"Displays a menu of non-mutually exclusive options."
					)

					local weaponList = mergeSavedNamesIntoWeaponList(getWeaponsFromCharacter())

					local defaultValue = nil
					if #weaponList > 0 then
						defaultValue = {1}
					end

					local MAX_MULTI = 999

					local function selectionIndices(value)
						if type(value) == "number" then
							return { value }
						end
						if type(value) == "table" then
							return value
						end
						return {}
					end

					local initialIndices = savedNamesToIndices(weaponList) or defaultValue

					local multi = row:Right():PopUpButton({
						Options = weaponList,
						Maximum = MAX_MULTI,
						Value = initialIndices,
						ValueChanged = function(self, value)
							local names = {}
							for _, idx in ipairs(selectionIndices(value)) do
								local n = self.Options[idx]
								if n then
									table.insert(names, n)
								end
							end
							getgenv().JinkX.Configs[CONFIG_KEY] = names
							SaveConfig()
						end,
					})

					task.defer(function()
						local wl = mergeSavedNamesIntoWeaponList(getWeaponsFromCharacter())
						pcall(function()
							multi.Options = wl
						end)
						local v = savedNamesToIndices(wl) or (#wl > 0 and {1} or nil)
						if v then
							multi.Value = v
						end
					end)

					local rowRefresh = titledRow(
						form,
						"Refresh weapons",
						"Reload tools from Backpack and Character."
					)
					rowRefresh:Right():Button({
						Label = "Refresh Weapon",
						State = "Secondary",
						Pushed = function()
							local newList = mergeSavedNamesIntoWeaponList(getWeaponsFromCharacter())
							local setOk = pcall(function()
								multi.Options = newList
							end)
							if not setOk then
								local opts = multi.Options
								local n = type(opts) == "table" and #opts or 0
								for i = n, 1, -1 do
									multi:Remove(i)
								end
								for _ = 1, 64 do
									opts = multi.Options
									if type(opts) ~= "table" or #opts < 1 then
										break
									end
									multi:Remove(1)
								end
								for _, name in ipairs(newList) do
									multi:Option(name)
								end
							end
							local nextVal = savedNamesToIndices(newList)
							if not nextVal and #newList > 0 then
								nextVal = {1}
							end
							multi.Value = nextVal
						end,
					})
				end

				do
					getgenv().JinkX.Configs.AutoSkill_Wpn_Z = getgenv().JinkX.Configs.AutoSkill_Wpn_Z or false
					getgenv().JinkX.Configs.AutoSkill_Wpn_X = getgenv().JinkX.Configs.AutoSkill_Wpn_X or false
					getgenv().JinkX.Configs.AutoSkill_Wpn_C = getgenv().JinkX.Configs.AutoSkill_Wpn_C or false
					getgenv().JinkX.Configs.AutoSkill_Wpn_V = getgenv().JinkX.Configs.AutoSkill_Wpn_V or false
					getgenv().JinkX.Configs.AutoSkill_Wpn_F = getgenv().JinkX.Configs.AutoSkill_Wpn_F or false
					getgenv().JinkX.Configs.AutoSkill_Fruit_Z = getgenv().JinkX.Configs.AutoSkill_Fruit_Z or false
					getgenv().JinkX.Configs.AutoSkill_Fruit_X = getgenv().JinkX.Configs.AutoSkill_Fruit_X or false
					getgenv().JinkX.Configs.AutoSkill_Fruit_C = getgenv().JinkX.Configs.AutoSkill_Fruit_C or false
					getgenv().JinkX.Configs.AutoSkill_Fruit_V = getgenv().JinkX.Configs.AutoSkill_Fruit_V or false

					local autoSkillForm = tab:PageSection({ Title = "Auto Skill" }):Form()

					local wpnRow = titledRow(autoSkillForm, "Weapon Skill", "Auto-cast weapon abilities by key.")
					local wpnKeys = { "Z", "X", "C", "V", "F" }
					local wpnToggles = {}
					for _, key in ipairs(wpnKeys) do
						local cfgKey = "AutoSkill_Wpn_" .. key
						local toggle = wpnRow:Right():Toggle({
							Value = getgenv().JinkX.Configs[cfgKey],
							ValueChanged = function(self, value: boolean)
								getgenv().JinkX.Configs[cfgKey] = value
								SaveConfig()
							end,
						})
						local lbl = wpnRow:Right():Label()
						lbl.Text = key
						wpnToggles[key] = toggle
					end

					local fruitRow = titledRow(autoSkillForm, "Fruit Ability", "Auto-cast fruit abilities by key.")
					local fruitKeys = { "Z", "X", "C", "V" }
					for _, key in ipairs(fruitKeys) do
						local cfgKey = "AutoSkill_Fruit_" .. key
						local toggle = fruitRow:Right():Toggle({
							Value = getgenv().JinkX.Configs[cfgKey],
							ValueChanged = function(self, value: boolean)
								getgenv().JinkX.Configs[cfgKey] = value
								SaveConfig()
							end,
						})
						local lbl = fruitRow:Right():Label()
						lbl.Text = key
					end
				end

			end
		end

		do
			local tab = section:Tab({
				Title = "Window",
				Icon = cascade.Symbols.sidebarLeft,
			})

			do
				local form = tab:PageSection({ Title = "Appearance" }):Form()

				do
					local row = titledRow(
						form,
						"Dark mode",
						"An application appearance setting that uses a dark color palette to provide a comfortable viewing experience tailored for low-light environments."
					)

					row:Right():Toggle({
						Value = app.Theme._id == "Dark",
						ValueChanged = function(self, value: boolean)
							app.Theme = value and cascade.Themes.Dark or cascade.Themes.Light
						end,
					})
				end

				do
					local row = titledRow(
						form,
						"Application accent",
						"An application appearance setting that allows you to change the overall accent of the application."
					)

					local flattenedAccents = {}
					for accent, _ in pairs(cascade.Accents) do
						table.insert(flattenedAccents, accent)
					end

					row:Right():PopUpButton({
						Value = table.find(flattenedAccents, (app.Accent and app.Accent._id) or "Blue"),
						Options = flattenedAccents,
						ValueChanged = function(self, value: number)
							app.Accent = cascade.Accents[self.Options[value]]
						end,
					})
				end
			end

			do
				local form = tab:PageSection({ Title = "Input" }):Form()

				do
					local row = titledRow(form, "Minimize shortcut")

					row:Right():KeybindField({
						Value = minimizeKeybind,
						ValueChanged = function(self, value: Enum.KeyCode)
							minimizeKeybind = value
						end,
					})
				end

				do
					local row = titledRow(
						form,
						"Searchable",
						"Allows users to search for content in a page with a search-field in the titlebar."
					)

					row:Right():Toggle({
						Value = window.Searching,
						ValueChanged = function(self, value: boolean)
							window.Searching = value
						end,
					})
				end

				do
					local row =
						titledRow(form, "Draggable", "Allows users to move the window with a mouse or touch device.")

					row:Right():Toggle({
						Value = window.Draggable,
						ValueChanged = function(self, value: boolean)
							window.Draggable = value
						end,
					})
				end

				do
					local row =
						titledRow(form, "Resizable", "Allows users to resize the window with a mouse or touch device.")

					row:Right():Toggle({
						Value = window.Resizable,
						ValueChanged = function(self, value: boolean)
							window.Resizable = value
						end,
					})
				end
			end

			do
				local form = tab:PageSection({
					Title = "Effects",
					Subtitle = "These effects may be resource intensive across different systems.",
				}):Form()

				do
					local row = titledRow(form, "Dropshadow", "Enables a dropshadow effect on the window.")

					row:Right():Toggle({
						Value = window.Dropshadow,
						ValueChanged = function(self, value: boolean)
							window.Dropshadow = value
						end,
					})
				end

				do
					local row = titledRow(
						form,
						"Background blur",
						"Enables a UI background blur effect on the window. This can be detectable in some games."
					)

					row:Right():Toggle({
						Value = false,
						ValueChanged = function(self, value: boolean)
							window.UIBlur = value
						end,
					})
				end
			end
		end
	end

	do
		local section = window:Section({ Title = "Navigation", Disclosure = false })
		local tab = section:Tab({
			Title = "Routing",
			Icon = cascade.Symbols.switch2,
			Selected = false,
		})

		local homePage = app:Page()
		local settingsPage = app:Page()

		do
			local form = homePage:Form()
			titledRow(form, "Home", "This is the main view."):Right():Button({
				Label = "Go to Settings",
				Pushed = function()
					tab:Navigate(settingsPage)
				end,
			})
		end

		do
			local form = settingsPage:Form()
			titledRow(form, "Settings", "This is a sub-page."):Right():Button({
				Label = "Back to Home",
				State = "Secondary",
				Pushed = function()
					tab:Navigate(homePage)
				end,
			})
		end

		tab:Navigate(homePage)
	end

	do
		local section = window:Section()

		section
			:Tab({ Icon = cascade.Symbols.squareStack3dUp })
			:Tab({ Icon = cascade.Symbols.squareStack3dUp })
			:Tab({ Icon = cascade.Symbols.squareStack3dUp })
			:Tab({ Icon = cascade.Symbols.squareStack3dUp })

		section:Tab({ Icon = cascade.Symbols.squareStack3dUp })
	end
end

			task.spawn(function()
				local TweenService = game:GetService("TweenService")
				local RunService = game:GetService("RunService")
				local Players = game:GetService("Players")
				local LocalPlayer = Players.LocalPlayer

				local CombatRemote = nil
				local AbilityRemote = nil
				local RemoteEvents = nil
				local AcceptQuestRemote = nil
				local CompleteQuestRemote = nil

				local function InitRemotes()
					if CombatRemote then return true end
					pcall(function()
						CombatRemote = ReplicatedStorage
							:WaitForChild("CombatSystem", 5)
							:WaitForChild("Remotes", 5)
							:WaitForChild("RequestHit", 5)
					end)
					pcall(function()
						AbilityRemote = ReplicatedStorage
							:WaitForChild("AbilitySystem", 5)
							:WaitForChild("Remotes", 5)
							:WaitForChild("RequestAbility", 5)
					end)
					pcall(function()
						RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 5)
						if RemoteEvents then
							AcceptQuestRemote = RemoteEvents:WaitForChild("AcceptQuest", 5)
							CompleteQuestRemote = RemoteEvents:WaitForChild("CompleteQuest", 5)
						end
					end)
					local ok = CombatRemote ~= nil and RemoteEvents ~= nil
					if ok then
						print("[AutoHaki] Remotes initialized")
					end
					return ok
				end

				local cachedFolderToPortal = nil
				local cachedZoneToPortal = nil
				local cachedZoneToIsland = nil

				local function GetFolderToPortalMap()
					if cachedFolderToPortal then return cachedFolderToPortal end
					cachedFolderToPortal = {}
					pcall(function()
						local pc = require(ReplicatedStorage:WaitForChild("PortalConfig", 5))
						if pc and pc.Portals then
							for portalName, pd in pairs(pc.Portals) do
								if pd.IslandFolder then
									cachedFolderToPortal[pd.IslandFolder] = portalName
								end
							end
						end
					end)
					return cachedFolderToPortal
				end

				local function GetZoneToPortalMap()
					if cachedZoneToPortal then return cachedZoneToPortal end
					cachedZoneToPortal = {}
					local folderMap = GetFolderToPortalMap()
					for folderName, portalName in pairs(folderMap) do
						cachedZoneToPortal[folderName] = portalName
						local spaced = folderName:gsub("(%u)", " %1"):gsub("^ ", "")
						cachedZoneToPortal[spaced] = portalName
					end
					return cachedZoneToPortal
				end

				local function GetStarterIslandData()
					if cachedZoneToIsland then return cachedZoneToIsland end
					pcall(function()
						local tc = require(ReplicatedStorage:WaitForChild("TravelConfig", 5))
						if tc and tc.Zones and tc.Zones.StarterIsland then
							cachedZoneToIsland = tc.Zones.StarterIsland
						end
					end)
					return cachedZoneToIsland
				end

				local lastPortalTpTime = 0
				local PORTAL_COOLDOWN = 1.2

				local function TeleportToStarterIsland()
					local now = tick()
					if now - lastPortalTpTime < PORTAL_COOLDOWN then return false end
					lastPortalTpTime = now

					local zoneToPortal = GetZoneToPortalMap()
					local portalName = zoneToPortal["StarterIsland"] or zoneToPortal["Starter"] or "Starter"

					local ok = pcall(function()
						local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
						local tpPortal = remotes:WaitForChild("TeleportToPortal", 5)
						if tpPortal then
							tpPortal:FireServer(portalName)
						end
					end)
					if ok then
						print("[AutoHaki] TeleportToPortal ->", portalName)
					end
					return ok
				end

				local function HasChar()
					local char = LocalPlayer.Character
					if not char then return false end
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if not hrp then return false end
					local hum = char:FindFirstChildOfClass("Humanoid")
					if not hum or hum.Health <= 0 then return false end
					return true, char, hrp
				end

				local function IsHakiUnlocked()
					local data = LocalPlayer:FindFirstChild("Data")
					if not data then return false end
					local attr = data:FindFirstChild("HakiUnlocked")
					if attr then return attr.Value == true end
					return false
				end

local function EquipCombat()
	local char = LocalPlayer.Character
	local backpack = LocalPlayer.Backpack
	if not char or not backpack then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local tool = char:FindFirstChild("Combat") or backpack:FindFirstChild("Combat")
	if tool then pcall(function() hum:EquipTool(tool) end) end
end

function ForceEquipCombat()
	local char = LocalPlayer.Character
	local backpack = LocalPlayer.Backpack

	local currentTool = nil
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then
				currentTool = item.Name
				break
			end
		end
		if currentTool == "Combat" then return end
	end

	local tool = nil
	if char then tool = char:FindFirstChild("Combat") end
	if not tool and backpack then tool = backpack:FindFirstChild("Combat") end

	if tool then
		pcall(function()
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum:EquipTool(tool) end
		end)
	else
		pcall(function()
			local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
			local equipRemote = remotes:WaitForChild("EquipWeapon", 5)
			if equipRemote then
				if currentTool and currentTool ~= "" then
					equipRemote:FireServer("Unequip", currentTool)
					task.wait(0.05)
				end
				equipRemote:FireServer("Equip", "Combat")
			end
		end)
	end
end

				local function ReadHakiQuestUI()
					local pGui = LocalPlayer:FindFirstChild("PlayerGui")
					if not pGui then return nil, 0, 0 end

					local qUI = pGui:FindFirstChild("QuestUI")
					if not qUI then return nil, 0, 0 end

					local qFrame = qUI:FindFirstChild("Quest")
					if not qFrame or not qFrame.Visible then return nil, 0, 0 end

					local holder = qFrame:FindFirstChild("Quest") or qFrame:FindFirstChild("Holder")
					if not holder then return nil, 0, 0 end
					holder = holder:FindFirstChild("Holder") or holder

					local content = holder:FindFirstChild("Content")
					if not content then return nil, 0, 0 end

					local questInfo = content:FindFirstChild("QuestInfo")
					if not questInfo then return nil, 0, 0 end

					local titleText = ""
					local titleObj = questInfo:FindFirstChild("QuestTitle")
					if titleObj then
						if titleObj:IsA("TextLabel") then
							titleText = titleObj.Text
						else
							local label = titleObj:FindFirstChild("QuestTitle")
							titleText = label and label.Text or ""
						end
					end

					local reqText = questInfo:FindFirstChild("QuestRequirement")
					local current, required = 0, 0
					if reqText and reqText:IsA("TextLabel") then
						local c, r = reqText.Text:match("(%d+)/(%d+)")
						if c and r then
							current, required = tonumber(c) or 0, tonumber(r) or 0
						end
					end

					return titleText, current, required
				end

				local function AcceptHakiQuest()
					if not AcceptQuestRemote then
						InitRemotes()
						if not AcceptQuestRemote then return false end
					end
					pcall(function()
						AcceptQuestRemote:FireServer("HakiQuestNPC")
					end)
					return true
				end

				local function CompleteHakiQuest()
					if not CompleteQuestRemote then
						InitRemotes()
						if not CompleteQuestRemote then return end
					end
					pcall(function()
						CompleteQuestRemote:FireServer("HakiQuestNPC")
					end)
				end

				local function CollectAliveThievesInRadius(playerPos, maxDist)
					local thieves = {}
					local npcs = workspace:FindFirstChild("NPCs")
					if not npcs then return thieves end

					local function scan(folder)
						for _, child in pairs(folder:GetChildren()) do
							if child:IsA("Folder") then
								scan(child)
							elseif child:IsA("Model") then
								local name = child.Name
								local isThief = type(name) == "string" and name:find("Thief", 1, true) == 1
								if isThief then
									local hum = child:FindFirstChildOfClass("Humanoid")
									if hum and hum.Health > 0 then
										local hrp = child:FindFirstChild("HumanoidRootPart")
										local pos = hrp and hrp.Position
										if not pos then
											local ok, p = pcall(function() return child:GetPivot() end)
											if ok and p then pos = p.Position end
										end
										if pos then
											local dist = (pos - playerPos).Magnitude
											if dist <= maxDist then
												table.insert(thieves, { mob = child, pos = pos, dist = dist })
											end
										end
									end
								end
							end
						end
					end

					scan(npcs)
					table.sort(thieves, function(a, b) return a.dist < b.dist end)
					return thieves
				end

				local TELEPORT_THRESHOLD = 600

				local function EnsureNearStarterIsland(hrpRef)
					local ok, _, hrp = HasChar()
					local hrpUse = hrpRef or hrp
					if not hrpUse then return end

					local islandData = GetStarterIslandData()
					if not islandData or not islandData.Center then
						local now = tick()
						if now - lastPortalTpTime > 3 then
							TeleportToStarterIsland()
							task.wait(1.2)
						end
						return
					end

					local distToIsland = (hrpUse.Position - islandData.Center).Magnitude
					if distToIsland > TELEPORT_THRESHOLD then
						print("[AutoHaki] Far from StarterIsland (" .. math.floor(distToIsland) .. " studs), teleporting...")
						TeleportToStarterIsland()
						task.wait(1.2)
					end
				end

				local function FireAttack(pos)
					if not CombatRemote then return end
					pcall(function() CombatRemote:FireServer(pos) end)
				end

				local lastZCastTime = 0
				local Z_COOLDOWN = 7.5

				local function TriggerGroundSmash()
					if not AbilityRemote then return false end
					local now = tick()
					if (now - lastZCastTime) >= Z_COOLDOWN then
						pcall(function() AbilityRemote:FireServer(1) end)
						lastZCastTime = now
						return true
					end
					return false
				end

				local HakiStages = {
					STAGE_KILL = 1,
					STAGE_ABILITY = 2,
				}

				local currentTween = nil

				local function CancelCurrentTween()
					if currentTween then
						currentTween:Cancel()
						currentTween = nil
					end
				end

				local function FarmThiefLoop(targetStageTitle)
					local SCAN_RADIUS = 2000
					local lastRescanTime = 0
					local RESCAN_INTERVAL = 0.5
					local lastKillCount = 0
					local lastTpTime = 0
					local loopCount = 0

					local _, baseCurrent, baseRequired = ReadHakiQuestUI()
					lastKillCount = baseCurrent

					while true do
						task.wait()

						if not getgenv().JinkX.Configs.AutoHakiQuest then
							break
						end

						local ok, char, hrp = HasChar()
						if not ok then
							task.wait(1)
							break
						end

						local titleCheck, currentCheck, requiredCheck = ReadHakiQuestUI()
						if not titleCheck or titleCheck == "" then
							task.wait(1)
							break
						end
						if string.find(titleCheck, "Haki") == nil then
							break
						end
						if not string.find(titleCheck, targetStageTitle) then
							break
						end
						if requiredCheck > 0 and currentCheck >= requiredCheck then
							break
						end

						if currentCheck > lastKillCount then
							print("[AutoHaki] Kill detected:", currentCheck, "/", requiredCheck)
							lastKillCount = currentCheck
							break
						end

						local now = tick()
						if now - lastRescanTime >= RESCAN_INTERVAL then
							EnsureNearStarterIsland(hrp)
							lastRescanTime = now
						end

						if now - lastTpTime > 4 then
							local thieves = CollectAliveThievesInRadius(hrp.Position, SCAN_RADIUS)
							if #thieves == 0 then
								print("[AutoHaki] No Thief mobs found, teleporting to StarterIsland...")
								TeleportToStarterIsland()
								task.wait(1.2)
								lastTpTime = now
							end
						end

						local thieves = CollectAliveThievesInRadius(hrp.Position, SCAN_RADIUS)
						if #thieves == 0 then
							task.wait(0.5)
						end

						EquipCombat()
						local closest = thieves[1]
						if closest and closest.pos then
							hrp.CFrame = CFrame.new(closest.pos)
								* CFrame.Angles(math.rad(-90), 0, 0)
								+ Vector3.new(0, 15, 0)
							FireAttack(closest.pos)
						end

						loopCount = loopCount + 1
					end
				end

				local lastStageTitle = nil

				while true do
					task.wait(0.5)

					if not getgenv().JinkX.Configs.AutoHakiQuest then
						task.wait(1)
						continue
					end

					InitRemotes()

					if IsHakiUnlocked() then
						print("[AutoHaki] Haki unlocked! Disabling AutoHakiQuest.")
						getgenv().JinkX.Configs.AutoHakiQuest = false
						task.wait(10)
						continue
					end

					local okChar, _, hrp = HasChar()
					if not okChar then
						task.wait(1)
						continue
					end

					local titleText, current, required = ReadHakiQuestUI()

					if not titleText or titleText == "" or string.find(titleText, "Haki") == nil then
						print("[AutoHaki] No Haki quest, accepting...")
						AcceptHakiQuest()
						task.wait(2)
						titleText, current, required = ReadHakiQuestUI()
					end

					if not titleText or titleText == "" then
						task.wait(2)
						continue
					end

					local done = required > 0 and current >= required
					if done then
						print("[AutoHaki] Quest complete:", titleText, "-", current, "/", required)
						CompleteHakiQuest()
						task.wait(1.5)
						lastStageTitle = nil
						continue
					end

					if string.find(titleText, "Path to Haki 1") then
						EnsureNearStarterIsland(hrp)
						FarmThiefLoop("Path to Haki 1")

					elseif string.find(titleText, "Path to Haki 2") then
						EquipCombat()
						task.wait(0.3)

						if required > 0 and current < required then
							local fired = TriggerGroundSmash()
							if fired then
								print("[AutoHaki] Fired GroundSmash (Z ability)")
							end
						end
						task.wait(1)

					elseif string.find(titleText, "Path to Haki Final") then
						EnsureNearStarterIsland(hrp)
						FarmThiefLoop("Path to Haki Final")

					else
						print("[AutoHaki] Unknown quest:", titleText)
						task.wait(2)
					end

					task.wait(0.05)
				end
			end)

local AutoFarm = {}

AutoFarm.State = {
    NONE = "NONE",
    FARMING_BOSS = "FARMING_BOSS",
    FARMING_PREVIOUS = "FARMING_PREVIOUS",
    WAITING_BOSS = "WAITING_BOSS",
}

AutoFarm.CurrentState = AutoFarm.State.NONE
AutoFarm.BossQuestName = nil
AutoFarm.PreviousQuestName = nil
AutoFarm.PreviousQuestType = nil
AutoFarm.WaitingForBossRespawn = false
AutoFarm.LastQuestAcceptTime = 0

local noclipConnection
local cachedCharParts

local function UpdateNoclipParts()
    local char = Character.Get()
    if char then
        cachedCharParts = {}
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("BasePart") then
                table.insert(cachedCharParts, child)
            end
        end
    end
end

noclipConnection = RunService.Stepped:Connect(function()
    pcall(function()
        local cfg = getgenv().JinkX.Configs
        if cfg.AutoFarm_Level or cfg.AutofarmSelectedMob or cfg.AutoHakiQuest then
            local char = Character.Get()
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    if humanoid.Sit then
                        humanoid:ChangeState(3)
                    else
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            if not hrp:FindFirstChild("Noclip") then
                                local bv = Instance.new("BodyVelocity")
                                bv.Name = "Noclip"
                                bv.Parent = hrp
                                bv.MaxForce = Vector3.new(10000, 10000, 10000)
                                bv.Velocity = Vector3.zero
                            end
                            if not hrp:FindFirstChild("NoclipAngular") then
                                local bav = Instance.new("BodyAngularVelocity")
                                bav.Name = "NoclipAngular"
                                bav.Parent = hrp
                                bav.MaxTorque = Vector3.new(4000, 4000, 4000)
                                bav.AngularVelocity = Vector3.zero
                            end

                            UpdateNoclipParts()
                            if cachedCharParts then
                                for _, v in ipairs(cachedCharParts) do
                                    v.CanCollide = false
                                end
                            end
                        end
                    end
                end
            end
        else
            local char = Character.Get()
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local noclip = hrp:FindFirstChild("Noclip")
                    if noclip then noclip:Destroy() end
                    local noclipAngular = hrp:FindFirstChild("NoclipAngular")
                    if noclipAngular then noclipAngular:Destroy() end
                end
            end
            cachedCharParts = nil
        end
    end)
end)

function AutoFarm.SetStateBoss(bossName, prevName, prevType)
    AutoFarm.CurrentState = AutoFarm.State.FARMING_BOSS
    AutoFarm.BossQuestName = bossName
    AutoFarm.PreviousQuestName = prevName
    AutoFarm.PreviousQuestType = prevType
    AutoFarm.WaitingForBossRespawn = false
    print("[STATE] -> FARMING_BOSS:", bossName)
end

function AutoFarm.SetStatePrevious()
    AutoFarm.CurrentState = AutoFarm.State.FARMING_PREVIOUS
    AutoFarm.WaitingForBossRespawn = false
    print("[STATE] -> FARMING_PREVIOUS:", AutoFarm.PreviousQuestName)
end

function AutoFarm.SetStateWaitingBoss()
    AutoFarm.CurrentState = AutoFarm.State.WAITING_BOSS
    AutoFarm.WaitingForBossRespawn = true
    print("[STATE] -> WAITING_BOSS")
end

function AutoFarm.SetStateNone()
    AutoFarm.CurrentState = AutoFarm.State.NONE
    AutoFarm.BossQuestName = nil
    AutoFarm.PreviousQuestName = nil
    AutoFarm.PreviousQuestType = nil
    AutoFarm.WaitingForBossRespawn = false
    print("[STATE] -> NONE")
end

task.spawn(function()
    local BOSS_RESPAWN_CHECK = 3
    local lastBossCheck = 0

    while true do
        task.wait(0.01)
        local cfg = getgenv().JinkX.Configs

        if not (cfg.AutoFarm_Level or cfg.AutofarmSelectedMob) then
            if AutoFarm.CurrentState ~= AutoFarm.State.NONE then
                AutoFarm.SetStateNone()
            end
            task.wait(0.1)
        else
            if not Character.IsAlive() then
                task.wait(1)
            else
                local playerLevel = Utils.GetPlayerLevel()
                local currentQuest = Quest.GetCurrent()

                if cfg.AutofarmSelectedMob and cfg.SelectedMobTarget then
                    local nearby = MobSystem.GetNearby({ npcType = cfg.SelectedMobTarget })

                    if #nearby > 0 then
                        Combat.SmartEquipWeapons()
                        Combat.AutoUseSkills()

                        local target = nearby[1]
                        if target and target.pos then
                            local attackHeight = Utils.GetAttackHeight()
                            local pHrp = Character.GetHRP()
                            if pHrp then
                                pHrp.CFrame = CFrame.new(target.pos) * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, attackHeight, 0)
                            end
                            Combat.Attack(target.pos)
                        end
                    else
                        Teleport.ToNpc(cfg.SelectedMobTarget)
                    end
                elseif cfg.AutoFarm_Level then
                    if Quest.IsComplete(currentQuest) then
                        local nextQuest, _ = Quest.FindNext(playerLevel)

                        if nextQuest then
                            Quest.Accept(nextQuest.npcName)
                            task.wait(2)
                        end
                    end

                    if not currentQuest or not Quest.HasActive() then
                        local bestQuest, _ = Quest.FindBest(playerLevel)

                        if bestQuest then
                            if bestQuest.isBoss and cfg.BossFallbackEnabled then
                                local prevQuest, _ = Quest.FindPreviousNonBoss(playerLevel)
                                local bossAlive = MobSystem.IsQuestBossAlive(bestQuest.npcName)

                                if bossAlive then
                                    Quest.Accept(bestQuest.npcName)
                                    AutoFarm.SetStateBoss(bestQuest.npcName, prevQuest and prevQuest.npcName or nil, prevQuest and prevQuest.npcType or nil)
                                elseif prevQuest then
                                    Quest.Accept(prevQuest.npcName)
                                    AutoFarm.SetStateBoss(bestQuest.npcName, prevQuest.npcName, prevQuest.npcType)
                                else
                                    Quest.Accept(bestQuest.npcName)
                                end
                            else
                                Quest.Accept(bestQuest.npcName)
                                AutoFarm.SetStateNone()
                            end
                        end
                    else
                        if cfg.BossFallbackEnabled and currentQuest.npcType then
                            if AutoFarm.CurrentState == AutoFarm.State.FARMING_BOSS then
                                local now = tick()
                                if now - lastBossCheck >= BOSS_RESPAWN_CHECK then
                                    lastBossCheck = now

                                    if not MobSystem.IsQuestBossAlive(AutoFarm.BossQuestName) then
                                        local qNow = Quest.GetCurrent()
                                        local onPrevQuest = qNow and not Utils.IsBossType(qNow.npcType)

                                        if onPrevQuest then
                                            AutoFarm.SetStatePrevious()
                                        else
                                            Quest.Abandon()
                                            task.wait(0.3)
                                            if AutoFarm.PreviousQuestName then
                                                Quest.Accept(AutoFarm.PreviousQuestName)
                                            end
                                            AutoFarm.SetStatePrevious()
                                        end
                                    end
                                end
                            elseif AutoFarm.CurrentState == AutoFarm.State.FARMING_PREVIOUS then
                                local qNow = Quest.GetCurrent()
                                if Quest.IsComplete(qNow) or not qNow then
                                    if MobSystem.IsQuestBossAlive(AutoFarm.BossQuestName) then
                                        Quest.Abandon()
                                        task.wait(0.3)
                                        Quest.Accept(AutoFarm.BossQuestName)
                                        AutoFarm.SetStateBoss(AutoFarm.BossQuestName, AutoFarm.PreviousQuestName, AutoFarm.PreviousQuestType)
                                    else
                                        AutoFarm.SetStateWaitingBoss()
                                    end
                                end
                            elseif AutoFarm.CurrentState == AutoFarm.State.WAITING_BOSS then
                                local now = tick()
                                if now - lastBossCheck >= BOSS_RESPAWN_CHECK then
                                    lastBossCheck = now

                                    if MobSystem.IsQuestBossAlive(AutoFarm.BossQuestName) then
                                        Quest.Abandon()
                                        task.wait(0.3)
                                        Quest.Accept(AutoFarm.BossQuestName)
                                        AutoFarm.SetStateBoss(AutoFarm.BossQuestName, AutoFarm.PreviousQuestName, AutoFarm.PreviousQuestType)
                                    end
                                end
                            end
                        end

                        local questData, _ = GameData.GetQuestMap()
                        local activeQuestData = questData and questData[currentQuest.npcType]

                        if activeQuestData then
                            local nearby = MobSystem.GetNearby(activeQuestData)
                            local aliveMobs = {}
                            for _, entry in ipairs(nearby) do
                                local mH = entry.mob:FindFirstChildOfClass("Humanoid")
                                if mH and mH.Health > 0 then
                                    table.insert(aliveMobs, entry.mob)
                                end
                            end

                            if #aliveMobs > 0 then
                                local targetIndex = 1
                                local lastSwitchTime = os.clock()
                                local lastRescanTime = os.clock()
                                local RESCAN_INTERVAL = 0.5
                                local SWITCH_INTERVAL = 1
                                local lastAliveScanTime = 0
                                local ALIVE_SCAN_INTERVAL = 0.2

                                repeat
                                    local now = os.clock()

                                    if not cfg.AutoFarm_Level then break end

                                    local pChar = Character.Get()
                                    local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
                                    if not pChar or not pHrp then break end

                                    local pHum = pChar:FindFirstChildOfClass("Humanoid")
                                    if not pHum or pHum.Health <= 0 then break end

                                    local qNow = Quest.GetCurrent()
                                    if not qNow or qNow.npcType ~= currentQuest.npcType then break end

                                    if Quest.IsComplete(qNow) then
                                        print("[QUEST] Quest complete, claiming reward")
                                        Quest.Complete()
                                        task.wait(0.3)
                                        break
                                    end

                                    if now - lastAliveScanTime >= ALIVE_SCAN_INTERVAL then
                                        nearby = MobSystem.GetNearby(activeQuestData)
                                        aliveMobs = {}
                                        for _, entry in ipairs(nearby) do
                                            local mH = entry.mob:FindFirstChildOfClass("Humanoid")
                                            if mH and mH.Health > 0 then
                                                table.insert(aliveMobs, entry.mob)
                                            end
                                        end
                                        lastAliveScanTime = now
                                        if #aliveMobs == 0 then break end
                                    end

                                    if targetIndex > #aliveMobs then targetIndex = 1 end
                                    local target = aliveMobs[targetIndex]
                                    if not target then break end

                                    local tHum = target:FindFirstChildOfClass("Humanoid")
                                    if not tHum or tHum.Health <= 0 then
                                        targetIndex = (targetIndex % math.max(1, #aliveMobs)) + 1
                                        target = aliveMobs[targetIndex]
                                        if not target then break end
                                    end

                                    if #aliveMobs > 1 and (now - lastSwitchTime) >= SWITCH_INTERVAL then
                                        targetIndex = (targetIndex % #aliveMobs) + 1
                                        lastSwitchTime = now
                                    end

                                    local targetHrp = target:FindFirstChild("HumanoidRootPart")
                                    local targetPos
                                    if targetHrp then
                                        targetPos = targetHrp.Position
                                    else
                                        local ok, pivot = pcall(function() return target:GetPivot() end)
                                        targetPos = (ok and pivot) and pivot.Position or target.Position
                                    end
                                    if not targetPos then break end

                                    local distToMob = (targetPos - pHrp.Position).Magnitude
                                    if distToMob > 50 then
                                        Teleport.SmartTween(targetPos, nil, currentQuest.npcType)
                                    else
                                        Teleport.CancelCurrentTween()
                                        local tHumFresh = target:FindFirstChildOfClass("Humanoid")
                                        if pHum.Health > 0 and tHumFresh and tHumFresh.Health > 0 then
                                            local attackHeight = Utils.GetAttackHeight()
                                            pHrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, attackHeight, 0)
                                            Combat.SmartEquipWeapons()
                                            Combat.AutoUseSkills()
                                            Combat.FireNormalAttack(targetPos)
                                        end
                                    end

                                    task.wait()
                                until not cfg.AutoFarm_Level
                                    or not target or not target:FindFirstChild("HumanoidRootPart")
                                    or not target:FindFirstChildOfClass("Humanoid")
                                    or target:FindFirstChildOfClass("Humanoid").Health <= 0
                            else
                                local playerChar = Character.Get()
                                local playerHrp = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
                                local playerPos = playerHrp and playerHrp.Position or Vector3.zero
                                local currentIsland = GameData.GetCurrentIslandFromPosition(playerPos)
                                local targetIsland = GameData.GetIslandForNpcType(currentQuest.npcType)
                                local islandName = targetIsland
                                local islandData = nil
                                if islandName then
                                    local zones = Teleport.GetIslandZones()
                                    islandData = zones and zones[islandName]
                                end
                                if not islandName or not islandData or not islandData.Center then
                                    local fallbackName, fallbackData = Teleport.GetClosestIsland(playerPos)
                                    if fallbackName then
                                        islandName = fallbackName
                                        islandData = fallbackData
                                    end
                                end
                                if islandName and islandData and islandData.Center and playerHrp then
                                    local onCorrectIsland = (currentIsland == islandName)
                                    if not onCorrectIsland then
                                        local dist = (playerHrp.Position - islandData.Center).Magnitude
                                        if dist > 780 then
                                            Teleport.ToIsland(islandName)
                                            task.wait(0.8)
                                        end
                                    else
                                        print("[AutoFarm] Already on island:", currentIsland, "- waiting for mob respawn")
                                        task.wait(1)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)

        local cfg = getgenv().JinkX.Configs
        if cfg.AutofarmSelectedMob and cfg.SelectedMobTarget then
            if not Character.IsAlive() then
                task.wait(1)
            else
                local hasQuest = Quest.HasActive()
                local quest = Quest.GetCurrent()
                local now = tick()

                if not hasQuest then
                    if now - (AutoFarm.LastQuestAcceptTime or 0) > 0.5 then
                        local questMap = GameData.GetQuestMap()
                        if questMap and next(questMap) then
                            local targetQuest = questMap[cfg.SelectedMobTarget]
                            if targetQuest then
                                Quest.Accept(targetQuest.npcName)
                                AutoFarm.LastQuestAcceptTime = now
                            end
                        end
                    end
                else
                    local currentCheck = Quest.GetCurrent()
                    if currentCheck and currentCheck.npcType ~= cfg.SelectedMobTarget then
                        Quest.Abandon()
                        task.wait(0.3)
                        local questMap = GameData.GetQuestMap()
                        if questMap and questMap[cfg.SelectedMobTarget] then
                            Quest.Accept(questMap[cfg.SelectedMobTarget].npcName)
                        end
                        AutoFarm.LastQuestAcceptTime = 0
                    else

                        local SWITCH_INTERVAL = 1
                        local ALIVE_SCAN_INTERVAL = 0.2
                        local lastAliveScanTime = 0
                        local lastSwitchTime = os.clock()
                        local targetIndex = 1

                        local function GetAliveMobs()
                            local nearby = MobSystem.GetNearby({ npcType = cfg.SelectedMobTarget })
                            local alive = {}
                            for _, entry in ipairs(nearby) do
                                local mH = entry.mob:FindFirstChildOfClass("Humanoid")
                                if mH and mH.Health > 0 then
                                    table.insert(alive, entry.mob)
                                end
                            end
                            return alive
                        end

                        local aliveMobs = GetAliveMobs()

                        if #aliveMobs == 0 then
                            local playerChar = Character.Get()
                            local playerHrp = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
                            local playerPos = playerHrp and playerHrp.Position or Vector3.zero
                            local currentIsland = GameData.GetCurrentIslandFromPosition(playerPos)
                            local targetIsland = GameData.GetIslandForNpcType(cfg.SelectedMobTarget)
                            local islandName = targetIsland
                            local islandData = nil
                            if islandName then
                                local zones = Teleport.GetIslandZones()
                                islandData = zones and zones[islandName]
                            end
                            if not islandData or not islandData.Center then
                                local portals = Teleport.GetAvailablePortals()
                                if portals then
                                    for _, portal in ipairs(portals) do
                                        if portal.island and portal.island == cfg.SelectedMobTarget then
                                            islandName = portal.island
                                            islandData = { Center = portal.pos, Size = 100 }
                                            break
                                        end
                                    end
                                end
                            end
                            if not islandData or not islandData.Center then
                                local fallbackName = Teleport.GetClosestIsland(playerPos)
                                if fallbackName then
                                    islandName = fallbackName
                                    local zones = Teleport.GetIslandZones()
                                    islandData = zones and zones[islandName]
                                end
                            end
                            if islandName and islandData and islandData.Center and playerHrp then
                                local onCorrectIsland = (currentIsland == islandName)
                                if not onCorrectIsland then
                                    local dist = (playerHrp.Position - islandData.Center).Magnitude
                                    if dist > 780 then
                                        Teleport.ToIsland(islandName)
                                        task.wait(0.8)
                                    end
                                else
                                    print("[AutoFarm] Already on", islandName, "- waiting for", cfg.SelectedMobTarget, "respawn")
                                    task.wait(2)
                                end
                            end
                        else
                            repeat
                                local nowLoop = os.clock()

                                if not cfg.AutofarmSelectedMob or not cfg.SelectedMobTarget then break end

                                local pChar = Character.Get()
                                local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
                                if not pChar or not pHrp then break end

                                local pHum = pChar:FindFirstChildOfClass("Humanoid")
                                if not pHum or pHum.Health <= 0 then break end

                                local currentCheck2 = Quest.GetCurrent()
                                if not currentCheck2 or currentCheck2.npcType ~= cfg.SelectedMobTarget then break end

                                if nowLoop - lastAliveScanTime >= ALIVE_SCAN_INTERVAL then
                                    aliveMobs = GetAliveMobs()
                                    lastAliveScanTime = nowLoop
                                    if #aliveMobs == 0 then break end
                                end

                                if targetIndex > #aliveMobs then targetIndex = 1 end
                                local target = aliveMobs[targetIndex]
                                if not target then break end

                                local tHum = target:FindFirstChildOfClass("Humanoid")
                                if not tHum or tHum.Health <= 0 then
                                    targetIndex = (targetIndex % math.max(1, #aliveMobs)) + 1
                                    target = aliveMobs[targetIndex]
                                    if not target then break end
                                end

                                if #aliveMobs > 1 and (nowLoop - lastSwitchTime) >= SWITCH_INTERVAL then
                                    targetIndex = (targetIndex % #aliveMobs) + 1
                                    lastSwitchTime = nowLoop
                                end

                                local targetHrp = target:FindFirstChild("HumanoidRootPart")
                                local targetPos
                                if targetHrp then
                                    targetPos = targetHrp.Position
                                else
                                    local ok, pivot = pcall(function() return target:GetPivot() end)
                                    targetPos = (ok and pivot) and pivot.Position or target.Position
                                end
                                if not targetPos then break end

                                local distToMob = (targetPos - pHrp.Position).Magnitude
                                if distToMob > 50 then
                                    Teleport.SmartTween(targetPos, nil, cfg.SelectedMobTarget)
                                else
                                    Teleport.CancelCurrentTween()
                                    local tHumFresh = target:FindFirstChildOfClass("Humanoid")
                                    if pHum.Health > 0 and tHumFresh and tHumFresh.Health > 0 then
                                        local attackHeight = Utils.GetAttackHeight()
                                        pHrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, attackHeight, 0)
                                        Combat.SmartEquipWeapons()
                                        Combat.AutoUseSkills()
                                        Combat.FireNormalAttack(targetPos)
                                    end
                                end

                                task.wait()
                                until not cfg.AutofarmSelectedMob or not cfg.SelectedMobTarget
                                    or not target or not target:FindFirstChild("HumanoidRootPart")
                                    or not target:FindFirstChildOfClass("Humanoid")
                                    or target:FindFirstChildOfClass("Humanoid").Health <= 0
                        end
                    end
                end
            end
        else
            task.wait(0.1)
        end
    end
end)

-- ============================================
-- AUTO HAKI QUEST MODULE
-- ============================================
-- Stage 1: Kill 150 NPCs using Combat (CombatNPCKills)
-- Stage 2: Use Z ability 65 times (GroundSmashUses)
-- Stage 3: Punch 750 times (CombatPunches)

function AcceptHakiQuest()
    pcall(function()
        local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
        local questAccept = remotes:WaitForChild("QuestAccept", 5)
        if questAccept then
            questAccept:FireServer("HakiQuestNPC")
        end
    end)
end

function GetHakiQuestInfo()
    if not questState.hasQuestline or not questState.questlineData then
        return nil
    end
    if questState.questlineData.questlineId ~= "Haki" then
        return nil
    end
    return questState.questlineData
end

function GetHakiStageConfig(stageNum)
    local QuestConfig = GameData.GetQuestConfig()
    if QuestConfig and QuestConfig.Questlines and QuestConfig.Questlines.Haki then
        local stages = QuestConfig.Questlines.Haki.stages
        if stages and stages[stageNum] then
            return stages[stageNum]
        end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.01)
        local cfg = getgenv().JinkX.Configs

        if not cfg.AutoHakiQuest then
            task.wait(0.1)
        else
            if not Character.IsAlive() then
                task.wait(1)
            else
                local questInfo = GetHakiQuestInfo()

                if not questInfo then
                    if not Quest.HasActive() then
                        AcceptHakiQuest()
                    end
                    task.wait(1)
                else
                    local currentStage = questInfo.currentStage or 1
                    local progress = questInfo.progress or 0
                    local stageConfig = GetHakiStageConfig(currentStage)
                    local goal = stageConfig and stageConfig.goal or 0
                    local title = stageConfig and stageConfig.title or "Unknown"

                    print("[HakiQuest] Stage", currentStage, ":", title, "-", progress, "/", goal)

                    if progress >= goal then
                        print("[HakiQuest] Stage", currentStage, "complete!")
                        AcceptHakiQuest()
                        task.wait(2)
                    else
                        if currentStage == 1 then
                            local npcType = "Thief"
                            local questData = { npcType = npcType }
                            local nearby = MobSystem.GetNearby(questData)
                            local aliveMobs = {}

                            for _, entry in ipairs(nearby) do
                                local mH = entry.mob:FindFirstChildOfClass("Humanoid")
                                if mH and mH.Health > 0 then
                                    table.insert(aliveMobs, entry.mob)
                                end
                            end

                            if #aliveMobs > 0 then
                                local targetIndex = 1
                                local lastSwitchTime = os.clock()
                                local lastAliveScanTime = 0
                                local SWITCH_INTERVAL = 1
                                local ALIVE_SCAN_INTERVAL = 0.2

                                repeat
                                    if not cfg.AutoHakiQuest then break end

                                    local pChar = Character.Get()
                                    local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
                                    if not pChar or not pHrp then break end

                                    local pHum = pChar:FindFirstChildOfClass("Humanoid")
                                    if not pHum or pHum.Health <= 0 then break end

                                    if os.clock() - lastAliveScanTime >= ALIVE_SCAN_INTERVAL then
                                        nearby = MobSystem.GetNearby(questData)
                                        aliveMobs = {}
                                        for _, entry in ipairs(nearby) do
                                            local mH = entry.mob:FindFirstChildOfClass("Humanoid")
                                            if mH and mH.Health > 0 then
                                                table.insert(aliveMobs, entry.mob)
                                            end
                                        end
                                        lastAliveScanTime = os.clock()
                                        if #aliveMobs == 0 then break end
                                    end

                                    if targetIndex > #aliveMobs then targetIndex = 1 end
                                    local target = aliveMobs[targetIndex]
                                    if not target then break end

                                    local tHum = target:FindFirstChildOfClass("Humanoid")
                                    if not tHum or tHum.Health <= 0 then
                                        targetIndex = (targetIndex % math.max(1, #aliveMobs)) + 1
                                        target = aliveMobs[targetIndex]
                                        if not target then break end
                                    end

                                    if #aliveMobs > 1 and (os.clock() - lastSwitchTime) >= SWITCH_INTERVAL then
                                        targetIndex = (targetIndex % #aliveMobs) + 1
                                        lastSwitchTime = os.clock()
                                    end

                                    local targetHrp = target:FindFirstChild("HumanoidRootPart")
                                    local targetPos
                                    if targetHrp then
                                        targetPos = targetHrp.Position
                                    else
                                        local ok, pivot = pcall(function() return target:GetPivot() end)
                                        targetPos = (ok and pivot) and pivot.Position or target.Position
                                    end
                                    if not targetPos then break end

                                    local distToMob = (targetPos - pHrp.Position).Magnitude
                                    if distToMob > 50 then
                                        Teleport.SmartTween(targetPos, nil, npcType)
                                    else
                                        Teleport.CancelCurrentTween()
                                        local tHumFresh = target:FindFirstChildOfClass("Humanoid")
                                        if pHum.Health > 0 and tHumFresh and tHumFresh.Health > 0 then
                                            local attackHeight = Utils.GetAttackHeight()
                                            pHrp.CFrame = CFrame.new(targetPos) * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, attackHeight, 0)
                                            ForceEquipCombat()
                                            Combat.AutoUseSkills()
                                            Combat.FireNormalAttack(targetPos)
                                        end
                                    end

                                    task.wait()
                                until not cfg.AutoHakiQuest
                                    or not target or not target:FindFirstChild("HumanoidRootPart")
                                    or not target:FindFirstChildOfClass("Humanoid")
                                    or target:FindFirstChildOfClass("Humanoid").Health <= 0
                            else
                                local playerChar = Character.Get()
                                local playerHrp = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
                                local playerPos = playerHrp and playerHrp.Position or Vector3.zero
                                local currentIsland = GameData.GetCurrentIslandFromPosition(playerPos)
                                local targetIsland = GameData.GetIslandForNpcType(npcType)
                                local islandName = targetIsland
                                local islandData = nil

                                if islandName then
                                    local zones = Teleport.GetIslandZones()
                                    islandData = zones and zones[islandName]
                                end

                                if not islandName or not islandData or not islandData.Center then
                                    local fallbackName, fallbackData = Teleport.GetClosestIsland(playerPos)
                                    if fallbackName then
                                        islandName = fallbackName
                                        islandData = fallbackData
                                    end
                                end

                                if islandName and islandData and islandData.Center and playerHrp then
                                    local dist = (playerHrp.Position - islandData.Center).Magnitude
                                    if dist > 780 then
                                        print("[HakiQuest] Warping to", islandName, "(dist:", math.floor(dist), ")")
                                        Teleport.ToIsland(islandName)
                                        task.wait(2.5)
                                    end
                                end
                            end

                        elseif currentStage == 2 then
                            ForceEquipCombat()
                            keypress(0x5A)
                            task.wait(0.1)
                            keyrelease(0x5A)
                            task.wait(0.5)

                        elseif currentStage == 3 then
                            local pChar = Character.Get()
                            local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")

                            if pHrp then
                                ForceEquipCombat()
                                local targetPos = pHrp.Position + pHrp.CFrame.LookVector * 10
                                Combat.Attack(targetPos)
                            end
                            task.wait(0.1)
                        end
                    end
                end
            end
        end
    end
end)

print("[JinkX] Sailor Piece - Refactored Version Loaded!")
local antiafk = getconnections or get_signal_cons
if antiafk then
	for _, Connection in next, antiafk(game:GetService("ScriptContext").Error) do
		Connection:Disable()
	end
	for i, v in pairs(antiafk(game.Players.LocalPlayer.Idled)) do
		if v.Disable then
			v:Disable()
		elseif v.Disconnect then
			v:Disconnect()
		end
	end
	for i, v in next, antiafk(game.Players.LocalPlayer.Idled) do
		v:Disable()
	end
	print("JinkX Loaded!")
else
	game.Players.LocalPlayer:Kick("Missing getconnections() - executor not supported")
end