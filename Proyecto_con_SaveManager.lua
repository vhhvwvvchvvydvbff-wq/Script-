local httpService = game:GetService("HttpService")

local SaveManager = {} do
	SaveManager.Folder = "FluentSettings"
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = "Toggle", idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = "Slider", idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = "Dropdown", idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Colorpicker = {
			Save = function(idx, object)
				return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		Keybind = {
			Save = function(idx, object)
				return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.key, data.mode)
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = "Input", idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] and type(data.text) == "string" then
					SaveManager.Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, "no config file is selected"
		end

		local fullPath = self.Folder .. "/settings/" .. name .. ".json"

		local data = {
			objects = {}
		}

		for idx, option in next, SaveManager.Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, "failed to encode data"
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, "no config file is selected"
		end
		
		local file = self.Folder .. "/settings/" .. name .. ".json"
		if not isfile(file) then return false, "invalid file" end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, "decode error" end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end) -- task.spawn() so the config loading wont get stuck.
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind"
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. "/settings"
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. "/settings")

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == ".json" then
				local pos = file:find(".json", 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= "/" and char ~= "\\" and char ~= "" do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == "/" or char == "\\" then
					local name = file:sub(pos + 1, start - 1)
					if name ~= "options" then
						table.insert(out, name)
					end
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
        self.Options = library.Options
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. "/settings/autoload.txt") then
			local name = readfile(self.Folder .. "/settings/autoload.txt")

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to load autoload config: " .. err,
					Duration = 7
				})
			end

			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Auto loaded config %q", name),
				Duration = 7
			})
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Must set SaveManager.Library")

		local section = tab:AddSection("Configuration")

		section:AddInput("SaveManager_ConfigName",    { Title = "Config name" })
		section:AddDropdown("SaveManager_ConfigList", { Title = "Config list", Values = self:RefreshConfigList(), AllowNull = true })

		section:AddButton({
            Title = "Create config",
            Callback = function()
                local name = SaveManager.Options.SaveManager_ConfigName.Value

                if name:gsub(" ", "") == "" then 
                    return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Invalid config name (empty)",
						Duration = 7
					})
                end

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to save config: " .. err,
						Duration = 7
					})
                end

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Created config %q", name),
					Duration = 7
				})

                SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
            end
        })

        section:AddButton({Title = "Load config", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to load config: " .. err,
					Duration = 7
				})
			end

			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Loaded config %q", name),
				Duration = 7
			})
		end})

		section:AddButton({Title = "Overwrite config", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to overwrite config: " .. err,
					Duration = 7
				})
			end

			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Overwrote config %q", name),
				Duration = 7
			})
		end})

		section:AddButton({Title = "Refresh list", Callback = function()
			SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
		end})

		local AutoloadButton
		AutoloadButton = section:AddButton({Title = "Set as autoload", Description = "Current autoload config: none", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. "/settings/autoload.txt", name)
			AutoloadButton:SetDesc("Current autoload config: " .. name)
			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Set %q to auto load", name),
				Duration = 7
			})
		end})

		if isfile(self.Folder .. "/settings/autoload.txt") then
			local name = readfile(self.Folder .. "/settings/autoload.txt")
			AutoloadButton:SetDesc("Current autoload config: " .. name)
		end

		SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
-- =============================================
-- PROYECTO MAIN
-- =============================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local Rep0 oklicatedStorage = game:GetService("ReplicatedStorage")
local muscleEvent = player:WaitForChild("muscleEvent")
local leaderstats = player:WaitForChild("leaderstats")
local rebirthsStat = leaderstats:WaitForChild("Rebirths")

local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end


local title = (" op script | ZIX HUB")


local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/f58075956-gif/Sxo/refs/heads/main/Proyecto%20gui", true))()
local window = library:AddWindow(title, {
    main_color = Color3.fromRGB(0, 0, 0),
    min_size = Vector2.new(760, 760),
    can_resize = true,
})
local function Crearpets()
local pets = window:AddTab("pets")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Foldersexo = pets:AddFolder("crystals")
-- Crystal data structure with exact names from your original code
local crystalData = {
    ["Blue Crystal"] = {
        {name = "Blue Birdie", rarity = "Basic"},
        {name = "Orange Hedgehog", rarity = "Basic"},
        {name = "Blue Aura", rarity = "Basic"},
        {name = "Red Kitty", rarity = "Basic"},
        {name = "Dark Vampy", rarity = "Advanced"},
        {name = "Blue Bunny", rarity = "Basic"},
        {name = "Red Aura", rarity = "Basic"},
        {name = "Blue Aura", rarity = "Basic"},
        {name = "Green Aura", rarity = "Basic"},
        {name = "Purple Aura", rarity = "Basic"},
        {name = "Red Aura", rarity = "Basic"},
        {name = "Yellow Aura", rarity = "Basic"}
    },
    ["Green Crystal"] = {
        {name = "Silver Dog", rarity = "Basic"},
        {name = "Green Aura", rarity = "Advanced"},
        {name = "Dark Golem", rarity = "Advanced"},
        {name = "Green Butterfly", rarity = "Advanced"},
        {name = "Crimson Falcon", rarity = "Rare"},
        {name = "Red Aura", rarity = "Basic"},
        {name = "Blue Aura", rarity = "Basic"},
        {name = "Green Aura", rarity = "Basic"},
        {name = "Purple Aura", rarity = "Basic"},
        {name = "Red Aura", rarity = "Basic"},
        {name = "Yellow Aura", rarity = "Basic"}
    },
    ["Frost Crystal"] = {
        {name = "Yellow Butterfly", rarity = "Advanced"},
        {name = "Purple Dragon", rarity = "Rare"},
        {name = "Blue Pheonix", rarity = "Epic"},
        {name = "Orange Pegasus", rarity = "Rare"},
        {name = "Lightning", rarity = "Rare"},
        {name = "Electro", rarity = "Advanced"}
    },
    ["Mythical Crystal"] = {
        {name = "Purple Falcon", rarity = "Rare"},
        {name = "Red Dragon", rarity = "Rare"},
        {name = "Blue Firecaster", rarity = "Epic"},
        {name = "Golden Pheonix", rarity = "Epic"},
        {name = "Power Lightning", rarity = "Rare"},
        {name = "Dark Lightning", rarity = "Epic"}
    },
    ["Inferno Crystal"] = {
        {name = "Red Firecaster", rarity = "Epic"},
        {name = "Infernal Dragon", rarity = "Unique"},
        {name = "White Pegasus", rarity = "Rare"},
        {name = "Golden Pheonix", rarity = "Epic"},
        {name = "Inferno", rarity = "Epic"},
        {name = "Dark Storm", rarity = "Unique"}
    },
    ["Legends Crystal"] = {
        {name = "Ultra Birdie", rarity = "Unique"},
        {name = "Magic Butterfly", rarity = "Unique"},
        {name = "Green Firecaster", rarity = "Epic"},
        {name = "White Pheonix", rarity = "Epic"},
        {name = "Supernova", rarity = "Epic"},
        {name = "Purple Nova", rarity = "Unique"}
    },
    ["Muscle Elite Crystal"] = {
        {name = "Frostwave Legends Penguin", rarity = "Rare"},
        {name = "Phantom Genesis Dragon", rarity = "Rare"},
        {name = "Dark Legends Manticore", rarity = "Epic"},
        {name = "Ultimate Supernova Pegasus", rarity = "Epic"},
        {name = "Aether Spirit Bunny", rarity = "Unique"},
        {name = "Cybernetic Showdown Dragon", rarity = "Unique"}
    },
    ["Galaxy Oracle Crystal"] = {
        {name = "Eternal Strike Leviathan", rarity = "Rare"},
        {name = "Lightning Strike Phantom", rarity = "Epic"},
        {name = "Darkstar Hunter", rarity = "Unique"},
        {name = "Muscle King", rarity = "Unique"},
        {name = "Azure Tundra", rarity = "Epic"},
        {name = "Ultra Inferno", rarity = "Rare"}
    },
    ["Jungle Crystal"] = {
        {name = "Entropic Blast", rarity = "Unique"},
        {name = "Muscle Sensei", rarity = "Unique"},
        {name = "Grand Supernova", rarity = "Epic"},
        {name = "Neon Guardian", rarity = "Unique"},
        {name = "Eternal Megastrike", rarity = "Unique"},
        {name = "Golden Viking", rarity = "Epic"},
        {name = "Astral Electro", rarity = "Epic"},
        {name = "Dark Electro", rarity = "Epic"},
        {name = "Enchanted Mirage", rarity = "Epic"},
        {name = "Ultra Mirage", rarity = "Unique"},
        {name = "Unstable Mirage", rarity = "Unique"}
    }
}

-- Function to collect all unique pets and auras
local function getAllPetsAndAuras()
    local allPets = {}
    local allAuras = {}
    
    for crystalName, pets in pairs(crystalData) do
        for _, pet in ipairs(pets) do
            if string.find(pet.name, "Aura") then
                if not allAuras[pet.name] then
                    allAuras[pet.name] = {name = pet.name, rarity = pet.rarity, crystal = crystalName}
                end
            else
                if not allPets[pet.name] then
                    allPets[pet.name] = {name = pet.name, rarity = pet.rarity, crystal = crystalName}
                end
            end
        end
    end
    
    return allPets, allAuras
end

-- Function to find which crystal contains a specific pet/aura
local function findCrystalForItem(itemName)
    for crystalName, pets in pairs(crystalData) do
        for _, pet in ipairs(pets) do
            if pet.name == itemName then
                return crystalName
            end
        end
    end
    return nil
end

-- Variables to track current selections
local selectedPet = ""
local selectedAura = ""

-- Get all pets and auras
local allPets, allAuras = getAllPetsAndAuras()

Foldersexo:AddButton("--- Buy pets and auras ---", function() end)

-- Pet dropdown
local petDropdown = Foldersexo:AddDropdown("Select pet", function(text)
    selectedPet = text
    local crystal = findCrystalForItem(text)
    print("Pet selected: " .. text .. " (Found in: " .. (crystal or "Unknown") .. ")")
end)

-- Add all pets manually (sorted by rarity)
-- Basic Pets
petDropdown:Add("Blue Birdie (Basic)")
petDropdown:Add("Orange Hedgehog (Basic)")
petDropdown:Add("Red Kitty (Basic)")
petDropdown:Add("Blue Bunny (Basic)")
petDropdown:Add("Silver Dog (Basic)")

-- Advanced Pets
petDropdown:Add("Dark Vampy (Advanced)")
petDropdown:Add("Dark Golem (Advanced)")
petDropdown:Add("Green Butterfly (Advanced)")
petDropdown:Add("Yellow Butterfly (Advanced)")

-- Rare Pets
petDropdown:Add("Crimson Falcon (Rare)")
petDropdown:Add("Purple Dragon (Rare)")
petDropdown:Add("Orange Pegasus (Rare)")
petDropdown:Add("Purple Falcon (Rare)")
petDropdown:Add("Red Dragon (Rare)")
petDropdown:Add("White Pegasus (Rare)")
petDropdown:Add("Frostwave Legends Penguin (Rare)")
petDropdown:Add("Phantom Genesis Dragon (Rare)")
petDropdown:Add("Eternal Strike Leviathan (Rare)")

-- Epic Pets
petDropdown:Add("Blue Pheonix (Epic)")
petDropdown:Add("Blue Firecaster (Epic)")
petDropdown:Add("Golden Pheonix (Epic)")
petDropdown:Add("Red Firecaster (Epic)")
petDropdown:Add("Green Firecaster (Epic)")
petDropdown:Add("White Pheonix (Epic)")
petDropdown:Add("Dark Legends Manticore (Epic)")
petDropdown:Add("Ultimate Supernova Pegasus (Epic)")
petDropdown:Add("Lightning Strike Phantom (Epic)")
petDropdown:Add("Golden Viking (Epic)")

-- Unique Pets
petDropdown:Add("Infernal Dragon (Unique)")
petDropdown:Add("Ultra Birdie (Unique)")
petDropdown:Add("Magic Butterfly (Unique)")
petDropdown:Add("Aether Spirit Bunny (Unique)")
petDropdown:Add("Cybernetic Showdown Dragon (Unique)")
petDropdown:Add("Darkstar Hunter (Unique)")
petDropdown:Add("Muscle Sensei (Unique)")
petDropdown:Add("Neon Guardian (Unique)")

-- Aura dropdown
local auraDropdown = Foldersexo:AddDropdown("Select Aura", function(text)
    selectedAura = text
    local crystal = findCrystalForItem(text)
    print("Aura selected: " .. text .. " (Found in: " .. (crystal or "Unknown") .. ")")
end)

-- Add all auras manually (sorted by rarity)
-- Basic Auras
auraDropdown:Add("Blue Aura (Basic)")
auraDropdown:Add("Green Aura (Basic)")
auraDropdown:Add("Purple Aura (Basic)")
auraDropdown:Add("Red Aura (Basic)")
auraDropdown:Add("Yellow Aura (Basic)")
auraDropdown:Add("Ultra Inferno  (Rare)")
auraDropdown:Add("Azure Tundra (Epic)")
auraDropdown:Add("Grand Supernova (Epic)")
auraDropdown:Add("Muscle King (Unique)")
auraDropdown:Add("Entropic Blast (Unique)")
auraDropdown:Add("Eternal Megastrike (Unique)")

Foldersexo:AddButton("--- System to buys---", function() end)

-- Auto buy pet toggle
Foldersexo:AddSwitch("Auto Buy Pet", function(bool)
    _G.AutoBuyPet = bool
    
    if bool then
        if selectedPet == "" then
            print("Please select a pet first!")
            return
        end
        
        -- Extract pet name from dropdown selection (remove rarity part)
        local petName = selectedPet:match("^(.-)%s*%(")
        if not petName then
            petName = selectedPet
        end
        
        local crystal = findCrystalForItem(petName)
        if not crystal then
            print("Could not find crystal for pet: " .. petName)
            return
        end
        
        print("Auto buy pet started for: " .. petName .. " from " .. crystal)
        spawn(function()
            while _G.AutoBuyPet and selectedPet ~= "" do
                local petToBuy = ReplicatedStorage.cPetShopFolder:FindFirstChild(petName)
                if petToBuy then
                    ReplicatedStorage.cPetShopRemote:InvokeServer(petToBuy)
                    print("Bought pet: " .. petName)
                else
                    print("Pet not found: " .. petName)
                end
                task.wait(0.1)
            end
        end)
    else
        print("Auto buy pet stopped")
    end
end)

-- Auto buy aura toggle
Foldersexo:AddSwitch("Auto buy Aura", function(bool)
    _G.AutoBuyAura = bool
    
    if bool then
        if selectedAura == "" then
            print("Please select an aura first!")
            return
        end
        
        -- Extract aura name from dropdown selection (remove rarity part)
        local auraName = selectedAura:match("^(.-)%s*%(")
        if not auraName then
            auraName = selectedAura
        end
        
        local crystal = findCrystalForItem(auraName)
        if not crystal then
            print("Could not find crystal for aura: " .. auraName)
            return
        end
        
        print("Auto buy aura started for: " .. auraName .. " from " .. crystal)
        spawn(function()
            while _G.AutoBuyAura and selectedAura ~= "" do
                local auraToBuy = ReplicatedStorage.cPetShopFolder:FindFirstChild(auraName)
                if auraToBuy then
                    ReplicatedStorage.cPetShopRemote:InvokeServer(auraToBuy)
                    print("Bought aura: " .. auraName)
                else
                    print("Aura not found: " .. auraName)
                end
                task.wait(0.1)
            end
        end)
    else
        print("Auto buy aura stopped")
    end
end)

pets:Show()

Foldersexo:AddLabel("=== buy ultimates ===")

-- Ultimate options
local ultimateOptions = {
    "+1 Daily Spin",
    "+1 Pet Slot", 
	"+10 Item Capacity",
    "+5% Rep Speed",
    "Demon Damage",
    "Galaxy Gains",
    "Golden Rebirth",
    "Jungle Swift",
    "Muscle Mind",
    "x2 Chest Rewards",
    "x2 Quest Rewards"
}

-- Variable to track selected ultimate
local selectedUltimate = ""

-- Ultimate dropdown
local ultimateDropdown = Foldersexo:AddDropdown("Select ultimate", function(text)
    selectedUltimate = text
    print("Ultimate selected: " .. text)
end)

-- Add all ultimate options to dropdown
for _, ultimate in ipairs(ultimateOptions) do
    ultimateDropdown:Add(ultimate)
end

-- Auto upgrade ultimate toggle
Foldersexo:AddSwitch("Auto Buy Ultimates", function(bool)
    _G.AutoUpgradeUltimate = bool
    
    if bool then
        if selectedUltimate == "" then
            print("Please select an ultimate first!")
            return
        end
			print("Auto upgrade ultimate started for: " .. selectedUltimate)
        spawn(function()
            while _G.AutoUpgradeUltimate and selectedUltimate ~= "" do
                game:GetService("ReplicatedStorage").rEvents.ultimatesRemote:InvokeServer(
                    "upgradeUltimate",
                    selectedUltimate
                )
                print("Upgraded ultimate: " .. selectedUltimate)
                task.wait(1)
            end
        end)
    else
        print("Auto comprar ultimates")
    end
end)
local Pets = {
    "Blue Birdie",
    "Orange Hedgehog",
    "Red Kitty",
    "Blue Bunny",
    "Silver Dog",
    "Dark Vampy",
    "Dark Golem",
    "Green Butterfly",
    "Yellow Butterfly",
    "Crimson Falcon",
    "Purple Dragon",
    "Orange Pegasus",
    "Purple Falcon",
    "Red Dragon",
    "White Pegasus",
    "Frostwave Legends Penguin",
    "Phantom Genesis Dragon",
    "Eternal Strike Leviathan",
    "Blue Pheonix",
    "Blue Firecaster",
    "Golden Pheonix",
    "Red Firecaster",
    "Green Firecaster",
    "White Pheonix",
    "Dark Legends Manticore",
    "Ultimate Supernova Pegasus",
    "Lightning Strike Phantom",
    "Golden Viking",
    "Infernal Dragon",
    "Ultra Birdie",
    "Magic Butterfly",
    "Aether Spirit Bunny",
    "Cybernetic Showdown Dragon",
    "Darkstar Hunter",
    "Muscle Sensei",
    "Neon Guardian"
}

local evolveRemote = game:GetService("ReplicatedStorage"):WaitForChild("rEvents"):WaitForChild("petEvolveEvent")

local function evolvePets()
	for _, petName in ipairs(Pets) do
		local args = {"evolvePet", petName}
		evolveRemote:FireServer(unpack(args))
		warn("Intentando evolucionar:", petName)
	end
end

pets:AddSwitch("Auto Evolve Pets", function(state)
	_G.AutoEvolvePets = state
	if state then
		print("Auto evolve ON")
		task.spawn(function()
			while _G.AutoEvolvePets do
				evolvePets()
				task.wait(0.1)
			end
		end)
	else
		print("Auto evolve OFF")
	end
end)
local FolderTrade = pets:AddFolder("trade")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local petList = {
	["Blue Birdie"] = "Basic",
	["Orange Hedgehog"] = "Basic",
	["Red Kitty"] = "Basic",
	["Blue Bunny"] = "Basic",
	["Silver Dog"] = "Basic",
	["Dark Vampy"] = "Advanced",
	["Dark Golem"] = "Advanced",
	["Green Butterfly"] = "Advanced",
	["Yellow Butterfly"] = "Advanced",
	["Crimson Falcon"] = "Rare",
	["Purple Dragon"] = "Rare",
	["Orange Pegasus"] = "Rare",
	["Purple Falcon"] = "Rare",
	["Red Dragon"] = "Rare",
	["White Pegasus"] = "Rare",
	["Frostwave Legends Penguin"] = "Rare",
	["Phantom Genesis Dragon"] = "Rare",
	["Eternal Strike Leviathan"] = "Rare",
	["Blue Pheonix"] = "Epic",
	["Blue Firecaster"] = "Epic",
	["Golden Pheonix"] = "Epic",
	["Red Firecaster"] = "Epic",
	["Green Firecaster"] = "Epic",
	["White Pheonix"] = "Epic",
	["Dark Legends Manticore"] = "Epic",
	["Ultimate Supernova Pegasus"] = "Epic",
	["Lightning Strike Phantom"] = "Epic",
	["Golden Viking"] = "Epic",
	["Infernal Dragon"] = "Unique",
	["Ultra Birdie"] = "Unique",
	["Magic Butterfly"] = "Unique",
	["Aether Spirit Bunny"] = "Unique",
	["Cybernetic Showdown Dragon"] = "Unique",
	["Darkstar Hunter"] = "Unique",
	["Muscle Sensei"] = "Unique",
	["Neon Guardian"] = "Unique"
}

local selectedPlayer = nil
local selectedPet = nil
local selectedRarity = nil
local autoTrading = false
local tradeAll = false

local playerDropdown = FolderTrade:AddDropdown("Choose Player", function(value)
	selectedPlayer = value
end)

for _, plr in pairs(Players:GetPlayers()) do
	if plr ~= player then
		playerDropdown:Add(plr.Name)
	end
end

Players.PlayerAdded:Connect(function(plr)
	playerDropdown:Add(plr.Name)
end)
Players.PlayerRemoving:Connect(function(plr)
	playerDropdown:Remove(plr.Name)
end)

local petDropdown = FolderTrade:AddDropdown("Choose Pet", function(value)
	selectedPet = value
	selectedRarity = petList[value]
end)

for name, _ in pairs(petList) do
	petDropdown:Add(name)
end

local function getSixPets(petName, rarity)
	local folder = player:WaitForChild("petsFolder"):FindFirstChild(rarity)
	if not folder then return {} end
	local found = {}
	for _, pet in ipairs(folder:GetChildren()) do
		if pet.Name == petName then
			table.insert(found, pet)
			if #found >= 9 then break end
		end
	end
	return found
end

local function doTrade(target)
	if not target or not selectedPet or not selectedRarity then return end
	local args1 = {"sendTradeRequest", target}
	ReplicatedStorage.rEvents.tradingEvent:FireServer(unpack(args1))
	task.wait(1)
	local petsToOffer = getSixPets(selectedPet, selectedRarity)
	for _, pet in ipairs(petsToOffer) do
		local args2 = {"offerItem", pet}
		ReplicatedStorage.rEvents.tradingEvent:FireServer(unpack(args2))
		task.wait(0.1)
	end
	local args3 = {"acceptTrade"}
	ReplicatedStorage.rEvents.tradingEvent:FireServer(unpack(args3))
end

FolderTrade:AddSwitch("Start Auto Trade", function(state)
	autoTrading = state
	if state and selectedPlayer and selectedPet then
		task.spawn(function()
			doTrade(Players:FindFirstChild(selectedPlayer))
		end)
	end
end)

FolderTrade:AddSwitch("Trade All Players", function(state)
	tradeAll = state
	if state and selectedPet then
		task.spawn(function()
			while tradeAll do
				for _, plr in pairs(Players:GetPlayers()) do
					if plr ~= player then
						doTrade(plr)
						task.wait(0.1)
					end
				end
				task.wait(0.1)
			end
		end)
	end
end)

Players.PlayerAdded:Connect(function(plr)
	if tradeAll and selectedPet then
		task.wait(0.1)
		doTrade(plr)
	end
end)
end
local function CrearRock()
local farmTab = window:AddTab("Rock")
local Folderanal = farmTab:AddFolder("FARM-ROCK-V1")
Folderanal:AddLabel("Rock Farming")

getgenv().autoFarm = false

-- 🔥 TOOL + REMOTE MEJORADO
local function gettool()
    local LP = game.Players.LocalPlayer
    local char = LP.Character
    local bp = LP.Backpack

    local tool = char:FindFirstChildOfClass("Tool") or bp:FindFirstChildOfClass("Tool")

    if tool then
        tool.Parent = char

        local attackTime = tool:FindFirstChild("attackTime")
        if attackTime then
            attackTime.Value = 0
        end
    end

    local remote = LP:FindFirstChild("muscleEvent")
    if remote then
        remote:FireServer("punch", "rightHand")
        remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		remote:FireServer("punch", "rightHand")
		
	end
end

-- ⚡ FUNCIÓN BASE DE FARM (MEJORADA)
local function farmRock(targetDurability)
    spawn(function()
        while getgenv().autoFarm do
            local LP = game.Players.LocalPlayer
            local char = LP.Character

            if char and char:FindFirstChild("RightHand") and char:FindFirstChild("LeftHand") then
                local right = char.RightHand
                local left = char.LeftHand

                for _, v in pairs(workspace.machinesFolder:GetDescendants()) do
                    if v.Name == "neededDurability" and v.Value == targetDurability then
                        local rock = v.Parent:FindFirstChild("Rock")

                        if rock then
                            -- 💀 MULTI TOUCH (RANGE BOOST)
                            for i = 90000, 100000 do
								firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
										firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
										firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
								
								
								
                            end
                            -- 🔥 punch real
                            gettool()
                        end
                    end
                end
            end

           task.wait(0)  -- ⚡ velocidad óptima
        end
    end)
end

-- 🔘 SWITCHES (todos arreglados)
Folderanal:AddSwitch("Tiny Island Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(0) end
end)

Folderanal:AddSwitch("Starter Island Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(100) end
end)

Folderanal:AddSwitch("Legend Beach Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(5000) end
end)

Folderanal:AddSwitch("Frost Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(150000) end
end)

Folderanal:AddSwitch("Mythical Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(400000) end
end)

Folderanal:AddSwitch("Eternal Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(750000) end
end)

Folderanal:AddSwitch("Legend Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(1000000) end
end)

Folderanal:AddSwitch("Muscle King Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(5000000) end
end)

Folderanal:AddSwitch("Ancient Jungle Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(10000000) end
end) 
local urls = {
    "https://raw.githubusercontent.com/f58075956-gif/Antiafk/refs/heads/main/Anti%20afk.lua",
}

-- ⚡ Botón que ejecuta todos los scripts remotos
farmTab:AddButton("anti afk", function()
    for _, url in ipairs(urls) do
        spawn(function()
            local success, response = pcall(function()
                return game:HttpGet(url)
            end)
            if success and response then
                local loadSuccess, err = pcall(function()
                    loadstring(response)()
                end)
                if not loadSuccess then
                    warn("[Pegar Muerto] Error ejecutando raw:", url, err)
                end
            else
                warn("[Pegar Muerto] No se pudo cargar:", url)
            end
        end)
    end
end)
-- 📂 ROCK V2
local FolderROCK2 = farmTab:AddFolder("ROCK-V2")

getgenv().autoFarm = false
getgenv().autoPunch = false

-- 📍 TP A LA ROCA
local function tpToRock(rock)
    local LP = game.Players.LocalPlayer
    local char = LP.Character

    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = rock.CFrame + Vector3.new(0,3,0)
    end
end

-- 👊 AUTO PUNCH
spawn(function()
    while task.wait(0) do
        if getgenv().autoPunch then
            local remote = game.Players.LocalPlayer:FindFirstChild("muscleEvent")

            if remote then
                remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
					remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
            end
        end
    end
end)

-- ⚡ FARM ROCK
local function farmRock(targetDurability)
    spawn(function()

        -- 🔥 activa auto punch automáticamente
        getgenv().autoPunch = true

        while getgenv().autoFarm do
            local LP = game.Players.LocalPlayer
            local char = LP.Character

            if char and char:FindFirstChild("RightHand") and char:FindFirstChild("LeftHand") then
                local right = char.RightHand
                local left = char.LeftHand

                for _, v in pairs(workspace.machinesFolder:GetDescendants()) do
                    if v.Name == "neededDurability" and v.Value == targetDurability then
                        local rock = v.Parent:FindFirstChild("Rock")

                        if rock then
                            -- 📍 TP
                            tpToRock(rock)

                            -- 💥 TOUCH
                            for i = 1, 300 do
                                firetouchinterest(rock, right, 0)
                                firetouchinterest(rock, right, 1)

                                firetouchinterest(rock, left, 0)
                                firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
                                firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
                                firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
                                firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
                                firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
                                firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
                                firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
                                firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 0)
									firetouchinterest(rock, left, 1)
								firetouchinterest(rock, left, 1)
									firetouchinterest(rock, left, 0)
								firetouchinterest(rock, left, 1)
                            end
                        end
                    end
                end
            end

            task.wait(0)
        end

        -- ❌ desactiva auto punch al apagar
        getgenv().autoPunch = false
    end)
end

-- 🪨 ROCKS
FolderROCK2:AddSwitch("Tiny Island Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(0) end
end)

FolderROCK2:AddSwitch("Starter Island Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(100) end
end)

FolderROCK2:AddSwitch("Legend Beach Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(5000) end
end)

FolderROCK2:AddSwitch("Frost Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(150000) end
end)

FolderROCK2:AddSwitch("Mythical Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(400000) end
end)

FolderROCK2:AddSwitch("Eternal Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(750000) end
end)

FolderROCK2:AddSwitch("Legend Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(1000000) end
end)

FolderROCK2:AddSwitch("Muscle King Gym Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(5000000) end
end)

FolderROCK2:AddSwitch("Ancient Jungle Rock", function(bool)
    getgenv().autoFarm = bool
    if bool then farmRock(10000000) end
end)
local FolderROCK3 = farmTab:AddFolder("ROCK-V3")

getgenv().autoFarmV3 = false
getgenv().autoPunchV3 = false

-- 🪨 TRAER ROCA
local function bringRockV3(rock)
    local char = game.Players.LocalPlayer.Character

    if char and char:FindFirstChild("HumanoidRootPart") then
        rock.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0,0,-3)
    end
end

-- 👊 AUTO PUNCH
spawn(function()
    while task.wait(0) do
        if getgenv().autoPunchV3 then
            local remote = game.Players.LocalPlayer:FindFirstChild("muscleEvent")

            if remote then
                remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				remote:FireServer("punch","rightHand")
                remote:FireServer("punch","leftHand")
				
					
            end
        end
    end
end)

-- ⚡ FARM
local function farmRockV3(targetDurability)
    spawn(function()

        getgenv().autoPunchV3 = true

        while getgenv().autoFarmV3 do
            local LP = game.Players.LocalPlayer
            local char = LP.Character

            if char and char:FindFirstChild("RightHand") and char:FindFirstChild("LeftHand") then
                local right = char.RightHand
                local left = char.LeftHand

                for _,v in pairs(workspace.machinesFolder:GetDescendants()) do
                    if v.Name == "neededDurability" and v.Value == targetDurability then
                        local rock = v.Parent:FindFirstChild("Rock")

                        if rock then
                            -- 🪨 TRAER ROCA
                            bringRockV3(rock)

                            -- 💥 TOUCH SPAM
                            for i = 1,400 do
                                firetouchinterest(rock, right, 0)
                                firetouchinterest(rock, right, 1)
									firetouchinterest(rock, right, 0)
                                firetouchinterest(rock, right, 1)
									firetouchinterest(rock, right, 0)
                                firetouchinterest(rock, right, 1)
									firetouchinterest(rock, right, 0)
                                firetouchinterest(rock, right, 1)
									

                                
                            end
                        end
                    end
                end
            end

            task.wait(0)
        end

        getgenv().autoPunchV3 = false
    end)
end

-- 🪨 ROCKS
FolderROCK3:AddSwitch("Tiny Island Rock", function(bool)
    getgenv().autoFarmV3 = bool
    if bool then farmRockV3(0) end
end)

FolderROCK3:AddSwitch("Starter Island Rock", function(bool)
    getgenv().autoFarmV3 = bool
    if bool then farmRockV3(100) end
end)

FolderROCK3:AddSwitch("Legend Beach Rock", function(bool)
    getgenv().autoFarmV3 = bool
    if bool then farmRockV3(5000) end
end)

FolderROCK3:AddSwitch("Frost Gym Rock", function(bool)
    getgenv().autoFarmV3 = bool
    if bool then farmRockV3(150000) end
end)

FolderROCK3:AddSwitch("Mythical Gym Rock", function(bool)
    getgenv().autoFarmV3 = bool
    if bool then farmRockV3(400000) end
end)

FolderROCK3:AddSwitch("Eternal Gym Rock", function(bool)
    getgenv().autoFarmV3 = bool
    if bool then farmRockV3(750000) end
end)

FolderROCK3:AddSwitch("Legend Gym Rock", function(bool)
    getgenv().autoFarmV3 = bool
    if bool then farmRockV3(1000000) end
end)

FolderROCK3:AddSwitch("Muscle King Gym Rock", function(bool)
    getgenv().autoFarmV3 = bool
    if bool then farmRockV3(5000000) end
end)

FolderROCK3:AddSwitch("Ancient Jungle Rock", function(bool)
    getgenv().autoFarmV3 = bool
    if bool then farmRockV3(10000000) end
end)

local Calculadora = window:AddTab("calculator", Color3.fromRGB(200, 100, 100))

local baseStrength = 0
local resultadoLabelsDamage = {}

local FolderDamage = Calculadora:AddFolder("Pack Damage Calculator")

FolderDamage:AddTextBox("Base Strongth (ej: 1.27Qa, T, B)", function(text)
    local unidades = { ["T"] = 1e12, ["Q"] = 1e15, ["B"] = 1e9 }
    text = text:upper()
    for u, m in pairs(unidades) do
        if text:find(u) then
            local num = tonumber(text:match("(%d+%.?%d*)"))
            if num then
                baseStrength = num * m
                return
            end
        end
    end
    baseStrength = tonumber(text:match("(%d+%.?%d*)")) or 0
end)

local mensajeLabelDamage = FolderDamage:AddLabel("")

for i = 1, 8 do
    resultadoLabelsDamage[i] = FolderDamage:AddLabel(string.format("%d pack(s): -", i))
end

FolderDamage:AddButton("Calculate Damage", function()
    if baseStrength <= 0 then
        mensajeLabelDamage.Text = "Enter a valid value."
        for i = 1, 8 do
            resultadoLabelsDamage[i].Text = string.format("%d pack(s): -", i)
        end
        return
    end

    mensajeLabelDamage.Text = ""

    local danoAjustado = baseStrength * 0.10
    local incremento = 0.335

    for pack = 1, 8 do
        local mult = 1 + (pack * incremento)
        local valor = danoAjustado * mult

        local disp
        if valor >= 1e15 then
            disp = string.format("%.3f Qa", valor / 1e15)
        elseif valor >= 1e12 then
            disp = string.format("%.2f T", valor / 1e12)
        elseif valor >= 1e9 then
            disp = string.format("%.2f B", valor / 1e9)
        else
            disp = tostring(math.floor(valor))
        end

        resultadoLabelsDamage[pack].Text = string.format("%d pack(s): %s", pack, disp)
    end
end)

local baseDurabilidad = 0
local resultadoLabelsDurabilidad = {}

local FolderDurabilidad = Calculadora:AddFolder("Pack Durability Calculator")

FolderDurabilidad:AddTextBox("Base durability (ej: 1.27Qa, T, B)", function(text)
    local unidades = { ["T"] = 1e12, ["Q"] = 1e15, ["B"] = 1e9 }
    text = text:upper()
    for u, m in pairs(unidades) do
        if text:find(u) then
            local num = tonumber(text:match("(%d+%.?%d*)"))
            if num then
                baseDurabilidad = num * m
                return
            end
        end
    end
    baseDurabilidad = tonumber(text:match("(%d+%.?%d*)")) or 0
end)

local mensajeLabelDurabilidad = FolderDurabilidad:AddLabel("")

for i = 1, 8 do
    resultadoLabelsDurabilidad[i] = FolderDurabilidad:AddLabel(string.format("%d pack(s): -", i))
end

FolderDurabilidad:AddButton("Calculate Durability", function()
    if baseDurabilidad <= 0 then
        mensajeLabelDurabilidad.Text = "Enter a valid value."
        for i = 1, 8 do
            resultadoLabelsDurabilidad[i].Text = string.format("%d pack(s): -", i)
        end
        return
    end

    mensajeLabelDurabilidad.Text = ""

    local incremento = 0.335
    local adicional = 1.5

    for pack = 1, 8 do
        local mult = 1 + (pack * incremento)
        local valor = baseDurabilidad * mult * adicional

        local disp
        if valor >= 1e15 then
            disp = string.format("%.3f Qa", valor / 1e15)
        elseif valor >= 1e12 then
            disp = string.format("%.2f T", valor / 1e12)
        elseif valor >= 1e9 then
            disp = string.format("%.2f B", valor / 1e9)
        else
            disp = tostring(math.floor(valor))
        end

        resultadoLabelsDurabilidad[pack].Text = string.format("%d pack(s): %s", pack, disp)
    end
end)

local FarmingTab = window:AddTab("Fast Farm")

local Folderfarming = FarmingTab:AddFolder("farm")

local strengthStat = leaderstats:WaitForChild("Strength")
local durabilityStat = player:WaitForChild("Durability")

local function formatNumber(number)
    local isNegative = number < 0
    number = math.abs(number)
    if number >= 1e15 then
        return (isNegative and "-" or "") .. string.format("%.2fQa", number / 1e15)
    elseif number >= 1e12 then
        return (isNegative and "-" or "") .. string.format("%.2fT", number / 1e12)
    elseif number >= 1e9 then
        return (isNegative and "-" or "") .. string.format("%.2fB", number / 1e9)
    elseif number >= 1e6 then
        return (isNegative and "-" or "") .. string.format("%.2fM", number / 1e6)
    elseif number >= 1e3 then
        return (isNegative and "-" or "") .. string.format("%.2fK", number / 1e3)
    else
        return (isNegative and "-" or "") .. string.format("%.2f", number)
    end
end

Folderfarming:AddLabel("Time:").TextSize = 20
local stopwatchLabel = FarmingTab:AddLabel("0d 0h 0m 0s - Fast Rep Inactive")
stopwatchLabel.TextSize = 17
stopwatchLabel.TextColor3 = Color3.fromRGB(255, 50, 50)

local projectedStrengthLabel = Folderfarming:AddLabel("[Strength Pace: 0 /Hour | 0 /Day | 0 /Week]")
projectedStrengthLabel.TextSize = 17
local projectedDurabilityLabel = Folderfarming:AddLabel("[Durability Pace: 0 /Hour | 0 /Day | 0 /Week]")
projectedDurabilityLabel.TextSize = 17
local averageStrengthLabel = Folderfarming:AddLabel("[Average Strength Pace: 0 /Hour | 0 /Day | 0 /Week]")
averageStrengthLabel.TextSize = 17
local averageDurabilityLabel = Folderfarming:AddLabel("[Average Durability Pace: 0 /Hour | 0 /Day | 0 /Week]")
averageDurabilityLabel.TextSize = 17

Folderfarming:AddLabel("").TextSize = 10
local statsLabel = Folderfarming:AddLabel("Stats:")
statsLabel.TextSize = 20
local strengthLabel = Folderfarming:AddLabel("Strength: 0 | Gained: 0")
strengthLabel.TextSize = 17
local durabilityLabel = Folderfarming:AddLabel("Durability: 0 | Gained: 0")
durabilityLabel.TextSize = 17

local startTime = 0
local pausedElapsedTime = 0
local lastPauseTime = 0

local runFastRep = false
local trackingStarted = false

local strengthHistory = {}
local durabilityHistory = {}
local calculationInterval = 10

local initialStrength = strengthStat.Value
local initialDurability = durabilityStat.Value

task.spawn(function()
    local lastCalcTime = tick()
    while true do
        local currentTime = tick()
        local currentStrength = strengthStat.Value
        local currentDurability = durabilityStat.Value

        strengthLabel.Text = "Strength: " .. formatNumber(currentStrength) .. " | Gained: " .. formatNumber(currentStrength - initialStrength)
        durabilityLabel.Text = "Durability: " .. formatNumber(currentDurability) .. " | Gained: " .. formatNumber(currentDurability - initialDurability)

        if runFastRep then
            if not trackingStarted then
                trackingStarted = true
                startTime = currentTime
                strengthHistory = {}
                durabilityHistory = {}
            end
            local elapsedTime = pausedElapsedTime + (currentTime - startTime)
            local days = math.floor(elapsedTime / (24 * 3600))
            local hours = math.floor((elapsedTime % (24 * 3600)) / 3600)
            local minutes = math.floor((elapsedTime % 3600) / 60)
            local seconds = math.floor(elapsedTime % 60)
            stopwatchLabel.Text = string.format("%dd %dh %dm %ds - Fast Rep Running", days, hours, minutes, seconds)
            stopwatchLabel.TextColor3 = Color3.fromRGB(50, 255, 50)

            table.insert(strengthHistory, {time = currentTime, value = currentStrength})
            table.insert(durabilityHistory, {time = currentTime, value = currentDurability})

            while #strengthHistory > 0 and currentTime - strengthHistory[1].time > calculationInterval do
                table.remove(strengthHistory, 1)
            end
            while #durabilityHistory > 0 and currentTime - durabilityHistory[1].time > calculationInterval do
                table.remove(durabilityHistory, 1)
            end

            if currentTime - lastCalcTime >= calculationInterval then
                lastCalcTime = currentTime

                if #strengthHistory >= 2 then
                    local strengthDelta = strengthHistory[#strengthHistory].value - strengthHistory[1].value
                    local strengthPerSecond = strengthDelta / calculationInterval
                    local strengthPerHour = strengthPerSecond * 3600
                    local strengthPerDay = strengthPerSecond * 86400
                    local strengthPerWeek = strengthPerSecond * 604800
                    projectedStrengthLabel.Text = "Strength Pace: " .. formatNumber(strengthPerHour) .. "/Hour | " .. formatNumber(strengthPerDay) .. "/Day | " .. formatNumber(strengthPerWeek) .. "/Week"
                end

                if #durabilityHistory >= 2 then
                    local durabilityDelta = durabilityHistory[#durabilityHistory].value - durabilityHistory[1].value
                    local durabilityPerSecond = durabilityDelta / calculationInterval
                    local durabilityPerHour = durabilityPerSecond * 3600
                    local durabilityPerDay = durabilityPerSecond * 86400
                    local durabilityPerWeek = durabilityPerSecond * 604800
                    projectedDurabilityLabel.Text = "Durability Pace: " .. formatNumber(durabilityPerHour) .. "/Hour | " .. formatNumber(durabilityPerDay) .. "/Day | " .. formatNumber(durabilityPerWeek) .. "/Week"
                end

                local totalElapsed = pausedElapsedTime + (currentTime - startTime)
                if totalElapsed > 0 then
                    local avgStrengthPerSecond = (currentStrength - initialStrength) / totalElapsed
                    local avgStrengthPerHour = avgStrengthPerSecond * 3600
                    local avgStrengthPerDay = avgStrengthPerSecond * 86400
                    local avgStrengthPerWeek = avgStrengthPerSecond * 604800
                    averageStrengthLabel.Text = "Average Strength Pace: " .. formatNumber(avgStrengthPerHour) .. "/Hour | " .. formatNumber(avgStrengthPerDay) .. "/Day | " .. formatNumber(avgStrengthPerWeek) .. "/Week"

                    local avgDurabilityPerSecond = (currentDurability - initialDurability) / totalElapsed
                    local avgDurabilityPerHour = avgDurabilityPerSecond * 3600
                    local avgDurabilityPerDay = avgDurabilityPerSecond * 86400
                    local avgDurabilityPerWeek = avgDurabilityPerSecond * 604800
                    averageDurabilityLabel.Text = "Average Durability Pace: " .. formatNumber(avgDurabilityPerHour) .. "/Hour | " .. formatNumber(avgDurabilityPerDay) .. "/Day | " .. formatNumber(avgDurabilityPerWeek) .. "/Week"
                end
            end
        else
            if trackingStarted then
                trackingStarted = false
                pausedElapsedTime = pausedElapsedTime + (currentTime - startTime)
                stopwatchLabel.Text = string.format("%dd %dh %dm %ds - Fast Rep Stopped", math.floor(pausedElapsedTime / (24 * 3600)), math.floor((pausedElapsedTime % (24 * 3600)) / 3600), math.floor((pausedElapsedTime % 3600) / 60), math.floor(pausedElapsedTime % 60))
                stopwatchLabel.TextColor3 = Color3.fromRGB(255, 165, 0)

                projectedStrengthLabel.Text = "Strength Pace: 0 /Hour | 0 /Day | 0 /Week"
                projectedDurabilityLabel.Text = "Durability Pace: 0 /Hour | 0 /Day | 0 /Week"
                averageStrengthLabel.Text = "Average Strength Pace: 0 /Hour | 0 /Day | 0 /Week"
                averageDurabilityLabel.Text = "Average Durability Pace: 0 /Hour | 0 /Day | 0 /Week"

                strengthHistory = {}
                durabilityHistory = {}
            end
        end

        task.wait(0.05)
    end
end)

Folderfarming:AddLabel("")
Folderfarming:AddLabel("Fast Farm (Recommended Speed: 20)").TextSize = 20

local repsPerTick = 1

local function getPing()
    local stats = game:GetService("Stats")
    local pingStat = stats:FindFirstChild("PerformanceStats") and stats.PerformanceStats:FindFirstChild("Ping")
    return pingStat and pingStat:GetValue() or 0
end

Folderfarming:AddTextBox("Rep Speed", function(value)
    local num = tonumber(value)
    if num and num > 0 then
        repsPerTick = math.floor(num)
    end
end, {
    placeholder = "1",
})

local function fastRepLoop()
    while runFastRep do
        local startTick = tick()
        while tick() - startTick < 0.75 and runFastRep do
            for i = 1, repsPerTick do
                muscleEvent:FireServer("rep")
            end
            task.wait(0.02)
        end
        while runFastRep and getPing() >= 350 do
            task.wait(1)
        end
    end
end

Folderfarming:AddSwitch("Fast Rep", function(state)
    if state and not runFastRep then
        runFastRep = true
        task.spawn(fastRepLoop)
    elseif not state and runFastRep then
        runFastRep = false
    end
end)
local player = game.Players.LocalPlayer
local SelectedTool = nil
local AutoFarmActive = false
local selectedRock = nil
local player = game.Players.LocalPlayer

Folderfarming:AddSwitch("Fast Tools", function(state)
    _G.FastTools = state

    local toolSettings = {
        {"Punch",       "attackTime", state and 0 or 0.01},
        {"Ground Slam", "attackTime", state and 0 or 6},
        {"Stomp",       "attackTime", state and 0 or 7},
        {"Handstands",  "repTime",    state and 0 or 1},
        {"Pushups",     "repTime",    state and 0 or 1},
        {"Weight",      "repTime",    state and 0 or 1},
        {"Situps",      "repTime",    state and 0 or 1},
    }

    local function applyTool(tool)
        -- Backpack
        local backpackTool = player.Backpack:FindFirstChild(tool[1])
        if backpackTool and backpackTool:FindFirstChild(tool[2]) then
            backpackTool[tool[2]].Value = tool[3]
        end

        -- Character
        local character = player.Character
        if character then
            local equippedTool = character:FindFirstChild(tool[1])
            if equippedTool and equippedTool:FindFirstChild(tool[2]) then
                equippedTool[tool[2]].Value = tool[3]
            end
        end
    end

    for _, tool in ipairs(toolSettings) do
        applyTool(tool)
    end
end)
local FolderautoTools = FarmingTab:AddFolder("TOOLS X ROCK")
FolderautoTools:AddLabel("Select the tool you will use:").TextSize = 22

local toolDropdown = FolderautoTools:AddDropdown("Select Tool", function(selection)
    SelectedTool = selection
end)
toolDropdown:Add("Weight")
toolDropdown:Add("Pushups")
toolDropdown:Add("Situps")
toolDropdown:Add("Handstands")
toolDropdown:Add("Fast Punch")
toolDropdown:Add("Stomp")
toolDropdown:Add("Ground Slam")


local rockData = {
    ["Jungle Rock"] = 10000000
}

local rockDropdown = FolderautoTools:AddDropdown("Select Rock", function(selection)
    selectedRock = selection
end)
for rockName in pairs(rockData) do
    rockDropdown:Add(rockName)
end

local function punchTool()
    for _, v in pairs(player.Backpack:GetChildren()) do
        if v.Name == "Punch" and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid:EquipTool(v)
        end
    end
    player.muscleEvent:FireServer("punch", "leftHand")
    player.muscleEvent:FireServer("punch", "rightHand")
end

local function startFarming()
    task.spawn(function()
        while AutoFarmActive do
            local char = player.Character or player.CharacterAdded:Wait()
            local toolName = SelectedTool
            local durability = player.Durability and player.Durability.Value or 0

            if toolName == "Weight" or toolName == "Pushups" or toolName == "Situps" or toolName == "Handstands" then
                if not char:FindFirstChild(toolName) then
                    local tool = player.Backpack:FindFirstChild(toolName)
                    if tool then
                        pcall(function() char.Humanoid:EquipTool(tool) end)
                    end
                end
                pcall(function() player.muscleEvent:FireServer("rep") end)
            elseif toolName == "Fast Punch" then
                punchTool()
            elseif toolName == "Stomp" then
                local stomp = player.Backpack:FindFirstChild("Stomp")
                if stomp and not char:FindFirstChild("Stomp") then
                    pcall(function() stomp.Parent = char end)
                    if stomp:FindFirstChild("attackTime") then
                        pcall(function() stomp.attackTime.Value = 0 end)
                    end
                end
                pcall(function() player.muscleEvent:FireServer("stomp") end)
                if char:FindFirstChild("Stomp") then
                    pcall(function() char.Stomp:Activate() end)
                end
                if tick() % 6 < 0.1 then
                    local vu = game:GetService("VirtualUser")
                    pcall(function()
                        vu:CaptureController()
                        vu:ClickButton1(Vector2.new(500, 500))
                    end)
                end
            elseif toolName == "Ground Slam" then
                local gs = player.Backpack:FindFirstChild("Ground Slam")
                if gs and not char:FindFirstChild("Ground Slam") then
                    pcall(function() gs.Parent = char end)
                    if gs:FindFirstChild("attackTime") then
                        pcall(function() gs.attackTime.Value = 0 end)
                    end
                end
                pcall(function() player.muscleEvent:FireServer("slam") end)
                if char:FindFirstChild("Ground Slam") then
                    pcall(function() char["Ground Slam"]:Activate() end)
                end
                if tick() % 6 < 0.1 then
                    local vu = game:GetService("VirtualUser")
                    pcall(function()
                        vu:CaptureController()
                        vu:ClickButton1(Vector2.new(500, 500))
                    end)
                end
            end

            if selectedRock then
                local requiredDurability = rockData[selectedRock]
                if durability >= requiredDurability then
                    for _, v in pairs(workspace:GetDescendants()) do
                        if v.Name == "neededDurability" and v.Value == requiredDurability and
                           char:FindFirstChild("LeftHand") and char:FindFirstChild("RightHand") then
                            local rock = v.Parent:FindFirstChild("Rock")
                            if rock then
                                pcall(function()
                                    firetouchinterest(rock, char.RightHand, 0)
                                    firetouchinterest(rock, char.RightHand, 1)
                                    firetouchinterest(rock, char.LeftHand, 0)
                                    firetouchinterest(rock, char.LeftHand, 1)
                                end)
                                punchTool()
                            end
                        end
                    end
                end
            end
            task.wait()
        end
    end)
end

FolderautoTools:AddSwitch("Start", function(enabled)
    AutoFarmActive = enabled
    if enabled then
        startFarming()
    else
        if SelectedTool and player.Character and player.Character:FindFirstChild(SelectedTool) then
            pcall(function()
                player.Character:FindFirstChild(SelectedTool).Parent = player.Backpack
            end)
        end
    end
end)

local Folder_AutoGym = FarmingTab:AddFolder(' Auto Gym')

Folder_AutoGym:AddLabel('King Gym')
Folder_AutoGym:AddSwitch('Auto Muscle King Lift', function(p36)
    if p36 then
        _G.automlking = true

        while true do
            local v37 = {
                'useMachine',
                workspace.machinesFolder:FindFirstChild('Muscle King Lift').interactSeat,
            }

            game:GetService('ReplicatedStorage').rEvents.machineInteractRemote:InvokeServer(unpack(v37))

            local _Character = game.Players.LocalPlayer.Character
            local v39 = Vector3.new(-8773, 17, -5669)

            if _Character then
                _Character.HumanoidRootPart.CFrame = CFrame.new(v39)
            end

            wait()

            local v40 = {
                'rep',
                workspace.machinesFolder:FindFirstChild('Muscle King Lift').interactSeat,
            }

            game:GetService('Players').LocalPlayer.muscleEvent:FireServer(unpack(v40))
            game:GetService('RunService').RenderStepped:Wait()

            if not _G.automlking then
            end
        end
    else
        _G.automlking = false

        return
    end
end)
Folder_AutoGym:AddSwitch('Auto Muscle King Bench', function(p41)
    if p41 then
        _G.automlking = true

        while true do
            local v42 = {
                'useMachine',
                workspace.machinesFolder:FindFirstChild('Muscle King Bench').interactSeat,
            }

            game:GetService('ReplicatedStorage').rEvents.machineInteractRemote:InvokeServer(unpack(v42))

            local _Character2 = game.Players.LocalPlayer.Character
            local v44 = Vector3.new(-8593.6884765625, 22.231548309326172, -6061.2900390625)

            if _Character2 then
                _Character2.HumanoidRootPart.CFrame = CFrame.new(v44)
            end

            wait()

            local v45 = {
                'rep',
                workspace.machinesFolder:FindFirstChild('Muscle King Bench').interactSeat,
            }

            game:GetService('Players').LocalPlayer.muscleEvent:FireServer(unpack(v45))
            game:GetService('RunService').RenderStepped:Wait()

            if not _G.automlking then
            end
        end
    else
        _G.automlking = false

        return
    end
end)
Folder_AutoGym:AddSwitch('Auto Muscle King Squat', function(p46)
    if p46 then
        _G.automlking = true

        while true do
            local v47 = {
                'useMachine',
                workspace.machinesFolder:FindFirstChild('Muscle King Squat').interactSeat,
            }

            game:GetService('ReplicatedStorage').rEvents.machineInteractRemote:InvokeServer(unpack(v47))

            local _Character3 = game.Players.LocalPlayer.Character
            local v49 = Vector3.new(-8752, 24, -6051)

            if _Character3 then
                _Character3.HumanoidRootPart.CFrame = CFrame.new(v49)
            end

            wait()

            local v50 = {
                'rep',
                workspace.machinesFolder:FindFirstChild('Muscle King Squat').interactSeat,
            }

            game:GetService('Players').LocalPlayer.muscleEvent:FireServer(unpack(v50))
            game:GetService('RunService').RenderStepped:Wait()

            if not _G.automlking then
            end
        end
    else
        _G.automlking = false

        return
    end
end)
Folder_AutoGym:AddSwitch('Auto Muscle King Boulder', function(p51)
    if p51 then
        _G.automlking = true

        while true do
            local v52 = {
                'useMachine',
                workspace.machinesFolder:FindFirstChild('King Boulder').interactSeat,
            }

            game:GetService('ReplicatedStorage').rEvents.machineInteractRemote:InvokeServer(unpack(v52))

            local _Character4 = game.Players.LocalPlayer.Character
            local v54 = Vector3.new(-8944, 24, -5684)

            if _Character4 then
                _Character4.HumanoidRootPart.CFrame = CFrame.new(v54)
            end

            wait()

            local v55 = {
                'rep',
                workspace.machinesFolder:FindFirstChild('King Boulder').interactSeat,
            }

            game:GetService('Players').LocalPlayer.muscleEvent:FireServer(unpack(v55))
            game:GetService('RunService').RenderStepped:Wait()

            if not _G.automlking then
            end
        end
    else
        _G.automlking = false

        return
    end
end)
Folder_AutoGym:AddLabel('Legends Gym')
Folder_AutoGym:AddSwitch('Auto Legends Press', function(p56)
    if p56 then
        _G.autolegends = true

        while true do
            local v57 = {
                'useMachine',
                workspace.machinesFolder:FindFirstChild('Legends Press').interactSeat,
            }

            game:GetService('ReplicatedStorage').rEvents.machineInteractRemote:InvokeServer(unpack(v57))

            local _Character5 = game.Players.LocalPlayer.Character
            local v59 = Vector3.new(4097.8427734375, 996.5140380859375, -3787.60791015625)

            if _Character5 then
                _Character5.HumanoidRootPart.CFrame = CFrame.new(v59)
            end

            wait()

            local v60 = {
                'rep',
                workspace.machinesFolder:FindFirstChild('Legends Press').interactSeat,
            }

            game:GetService('Players').LocalPlayer.muscleEvent:FireServer(unpack(v60))
            game:GetService('RunService').RenderStepped:Wait()

            if not _G.autolegends then
            end
        end
    else
        _G.autolegends = false

        return
    end
end)
Folder_AutoGym:AddSwitch('Auto Legends Throw', function(p61)
    if p61 then
        _G.autolegends = true

        local v62 = {
            'useMachine',
            workspace.machinesFolder:FindFirstChild('Legends Throw').interactSeat,
        }

        game:GetService('ReplicatedStorage').rEvents.machineInteractRemote:InvokeServer(unpack(v62))

        local _Character6 = game.Players.LocalPlayer.Character
        local v64 = Vector3.new(4196.248046875, 991.5355224609375, -3905.087158203125)

        if _Character6 then
            _Character6.HumanoidRootPart.CFrame = CFrame.new(v64)
        end

        wait()

        local v65 = {
            'rep',
            workspace.machinesFolder:FindFirstChild('Legends Throw').interactSeat,
        }

        game:GetService('Players').LocalPlayer.muscleEvent:FireServer(unpack(v65))
        game:GetService('RunService').RenderStepped:Wait()

        if not _G.autolegends then
        end
    end

    _G.autolegends = false
end)
Folder_AutoGym:AddSwitch('Auto Legends Pullup', function(p66)
    if p66 then
        _G.autolegends = true

        while true do
            local v67 = {
                'useMachine',
                workspace.machinesFolder:FindFirstChild('Legends Pullup').interactSeat,
            }

            game:GetService('ReplicatedStorage').rEvents.machineInteractRemote:InvokeServer(unpack(v67))

            local _Character7 = game.Players.LocalPlayer.Character
            local v69 = Vector3.new(4308, 998, -4121)

            if _Character7 then
                _Character7.HumanoidRootPart.CFrame = CFrame.new(v69)
            end

            wait()

            local v70 = {
                'rep',
                workspace.machinesFolder:FindFirstChild('Legends Pullup').interactSeat,
            }

            game:GetService('Players').LocalPlayer.muscleEvent:FireServer(unpack(v70))
            game:GetService('RunService').RenderStepped:Wait()

            if not _G.autolegends then
            end
        end
    else
        _G.autolegends = false

        return
    end
end)
Folder_AutoGym:AddSwitch('Auto Legends Squat', function(p71)
    if p71 then
        _G.autolegends = true

        while true do
            local v72 = {
                'useMachine',
                workspace.machinesFolder:FindFirstChild('Legends Squat').interactSeat,
            }

            game:GetService('ReplicatedStorage').rEvents.machineInteractRemote:InvokeServer(unpack(v72))

            local _Character8 = game.Players.LocalPlayer.Character
            local v74 = Vector3.new(4446, 998, -4069)

            if _Character8 then
                _Character8.HumanoidRootPart.CFrame = CFrame.new(v74)
            end

            wait()

            local v75 = {
                'rep',
                workspace.machinesFolder:FindFirstChild('Legends Squat').interactSeat,
            }

            game:GetService('Players').LocalPlayer.muscleEvent:FireServer(unpack(v75))
            game:GetService('RunService').RenderStepped:Wait()

            if not _G.autolegends then
            end
        end
    else
        _G.autolegends = false

        return
    end
end)
Folder_AutoGym:AddSwitch('Auto Legends Lift', function(p76)
    if p76 then
        _G.autolegends = true

        while true do
            local v77 = {
                'useMachine',
                workspace.machinesFolder:FindFirstChild('Legends Lift').interactSeat,
            }

            game:GetService('ReplicatedStorage').rEvents.machineInteractRemote:InvokeServer(unpack(v77))

            local _Character9 = game.Players.LocalPlayer.Character
            local v79 = Vector3.new(4527.3583984375, 991.4735717773438, -4001.750732421875)

            if _Character9 then
                _Character9.HumanoidRootPart.CFrame = CFrame.new(v79)
            end

            wait()

            local v80 = {
                'rep',
                workspace.machinesFolder:FindFirstChild('Legends Lift').interactSeat,
            }

            game:GetService('Players').LocalPlayer.muscleEvent:FireServer(unpack(v80))
            game:GetService('RunService').RenderStepped:Wait()

            if not _G.autolegends then
            end
        end
    else
        _G.autolegends = false

        return
    end
end)

local Folder_rebirth = FarmingTab:AddFolder("sin packs")
Folder_rebirth:AddTextBox("Rebirth Target", function(text)
    local newValue = tonumber(text)
    if newValue and newValue > 0 then
        targetRebirthValue = newValue
        updateStats() -- Call the stats update function
        
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Objetivo Actualizado",
            Text = "Nuevo objetivo: " .. tostring(targetRebirthValue) .. " renacimientos",
            Duration = 0
        })
    else
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Size",
            Text = "Put a size larger than 0",
            Duration = 0
        })
    end
end)

local targetSwitch = Folder_rebirth:AddSwitch("Auto Rebirth Target", function(bool)
    _G.targetRebirthActive = bool
    
    if bool then
        if _G.infiniteRebirthActive and infiniteSwitch then
            infiniteSwitch:Set(false)
            _G.infiniteRebirthActive = false
        end
        
        spawn(function()
            while _G.targetRebirthActive and wait(0.1) do
                local currentRebirths = game.Players.LocalPlayer.leaderstats.Rebirths.Value
                
                if currentRebirths >= targetRebirthValue then
                    targetSwitch:Set(false)
                    _G.targetRebirthActive = false
                    
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "¡Objetivo Alcanzado!",
                        Text = "Has alcanzado " .. tostring(targetRebirthValue) .. " renacimientos",
                        Duration = 5
                    })
                    
                    break
                end
                
                game:GetService("ReplicatedStorage").rEvents.rebirthRemote:InvokeServer("rebirthRequest")
            end
        end)
    end
end, "automatic rebirth until reaching the goal")

infiniteSwitch = Folder_rebirth:AddSwitch("Auto Rebirth (Infinitely)", function(bool)
    _G.infiniteRebirthActive = bool
    
    if bool then
        if _G.targetRebirthActive and targetSwitch then
            targetSwitch:Set(false)
            _G.targetRebirthActive = false
        end
        
        spawn(function()
            while _G.infiniteRebirthActive and wait(0.1) do
                game:GetService("ReplicatedStorage").rEvents.rebirthRemote:InvokeServer("rebirthRequest")
            end
        end)
    end
end, "rebirth infinitely")

local sizeSwitch = Folder_rebirth:AddSwitch("Auto Size 2", function(bool)
    _G.autoSizeActive = bool
    
    if bool then
        spawn(function()
            while _G.autoSizeActive and wait() do
                game:GetService("ReplicatedStorage").rEvents.changeSpeedSizeRemote:InvokeServer("changeSize", 2)
            end
        end)
    end
end, "Size 2")

local teleportSwitch = Folder_rebirth:AddSwitch("Auto Teleport to Muscle King", function(bool)
    _G.teleportActive = bool
    
    if bool then
        spawn(function()
            while _G.teleportActive and wait() do
                if game.Players.LocalPlayer.Character then
                    game.Players.LocalPlayer.Character:MoveTo(Vector3.new(-8646, 17, -5738))
                end
            end
        end)
    end
end, "Tp to Mk")

local AutoEggEnabled = false

local function ConsumeProteinEgg()
    local player = game.Players.LocalPlayer

    player:WaitForChild("Backpack")

    local character = player.Character or player.CharacterAdded:Wait()

    local egg = player.Backpack:FindFirstChild("Protein Egg")

    if egg then
        egg.Parent = character

        pcall(function()
            egg:Activate()
        end)

        print("[AutoEgg] Protein Egg consumido.")
    else
        warn("[AutoEgg] No se encontró Protein Egg en el Backpack.")
    end
end

task.spawn(function()
    while true do
        if AutoEggEnabled then
            ConsumeProteinEgg()
            task.wait(1800) -- 30 minutos
        else
            task.wait(1)
        end
    end
end)

Folder_rebirth:AddSwitch("Eat Egg (30 Min)", function(state)
    AutoEggEnabled = state

    if state then
        print("[AutoEgg] Activado.")
    else
        print("[AutoEgg] Desactivado.")
    end
end)
end
local function Crearextra()
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local extraTab = window:AddTab("Extra")
local lockSwitch = extraTab:AddSwitch("Lock Position", function(Value)
    local player = game.Players.LocalPlayer

    if Value then
        lockRunning = true
        lockConnection = game:GetService("RunService").Heartbeat:Connect(function()
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChildOfClass("Humanoid") then return end

            local hrp = char.HumanoidRootPart
            local humanoid = char:FindFirstChildOfClass("Humanoid")

            if not humanoid or not hrp then return end

            if not humanoid:FindFirstChild("LockState") then
                humanoid.WalkSpeed = 0
                humanoid.JumpPower = 0
                humanoid.AutoRotate = false
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                local marker = Instance.new("BoolValue", humanoid)
                marker.Name = "LockState"
                marker.Value = true
                humanoid:SetAttribute("LockCFrame", hrp.CFrame)
            end

            local savedCFrame = humanoid:GetAttribute("LockCFrame")
            if savedCFrame then
                hrp.Velocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
                hrp.CFrame = savedCFrame
            end
        end)
    else
        lockRunning = false
        if lockConnection then
            lockConnection:Disconnect()
            lockConnection = nil
        end
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 250
                humanoid.JumpPower = 50
                humanoid.AutoRotate = true
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                if humanoid:FindFirstChild("LockState") then
                    humanoid.LockState:Destroy()
                end
                humanoid:SetAttribute("LockCFrame", nil)
            end
        end
    end
end)

lockSwitch:Set(false)
--------------------------------------------------
-- 🐾 SHOW / HIDE PETS
--------------------------------------------------
local function onShowPets(enabled)
    local v = LocalPlayer:FindFirstChild("hidePets")
    if v then
        v.Value = enabled
    end
end

extraTab:AddSwitch("Show Pets", onShowPets)

--------------------------------------------------
-- 🦘 INFINITE JUMP
--------------------------------------------------
local infJump = false

local function onInfiniteJump(state)
    infJump = state
end

UIS.JumpRequest:Connect(function()
    if infJump then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

extraTab:AddSwitch("Infinite Jump", onInfiniteJump)

--------------------------------------------------
-- 🌊 WALK ON WATER (OPTIMIZADO)
--------------------------------------------------
local waterPart = nil

local function onWalkOnWater(state)
    if state then
        if not waterPart then
            waterPart = Instance.new("Part")
            waterPart.Size = Vector3.new(5000, 1, 5000)
            waterPart.Anchored = true
            waterPart.Transparency = 1
            waterPart.Name = "WaterPlatform"
            waterPart.Parent = workspace
        end

        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                waterPart.Position = Vector3.new(hrp.Position.X, hrp.Position.Y - 5, hrp.Position.Z)
            end
        end

        RunService.Heartbeat:Connect(function()
            if waterPart then
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        waterPart.Position = Vector3.new(hrp.Position.X, hrp.Position.Y - 5, hrp.Position.Z)
                    end
                end
            end
        end)
    else
        if waterPart then
            waterPart:Destroy()
            waterPart = nil
        end
    end
end

local WalkWaterSwitch = extraTab:AddSwitch("Walk on Water", onWalkOnWater)
WalkWaterSwitch:Set(false)

--------------------------------------------------
-- 🌗 TIME CONTROL
--------------------------------------------------
local function onChangeTime(value)
    if value == "Night" then
        Lighting.ClockTime = 0
    elseif value == "Day" then
        Lighting.ClockTime = 12
    elseif value == "Midnight" then
        Lighting.ClockTime = 6
    end
end


local TimeDropdown = extraTab:AddDropdown("Change Time", onChangeTime)
TimeDropdown:Add("Night")
TimeDropdown:Add("Day")
TimeDropdown:Add("Midnight")


extraTab:AddButton("Equip Swift Samurai", function()
    print("Boton presionado: equipando 8 Swift Samurai")

    local LocalPlayer = game:GetService("Players").LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -- Primero desequipamos todo
    local petsFolder = LocalPlayer:FindFirstChild("petsFolder")
    if not petsFolder then return end

    for _, folder in pairs(petsFolder:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in pairs(folder:GetChildren()) do
                ReplicatedStorage.rEvents.equipPetEvent:FireServer("unequipPet", pet)
            end
        end
    end
    task.wait(0.1)

    -- Ahora equipamos mÃ¡ximo 8 "Swift Samurai"
    local equipped = 0
    local maxEquip = 8
    for _, folder in pairs(petsFolder:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in pairs(folder:GetChildren()) do
                if pet.Name == "Swift Samurai" then
                    ReplicatedStorage.rEvents.equipPetEvent:FireServer("equipPet", pet)
                    equipped += 1
                    print("Equipado Swift Samurai #" .. equipped)

                    if equipped >= maxEquip then
                        return -- salir cuando ya haya 8 equipados
                    end
                end
            end
        end
    end

    print("Se equiparon " .. equipped .. " Swift Samurai")
end)

extraTab:AddButton("Jungle lift", function()
    local player = game.Players.LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    -- Teletransportar al nuevo CFrame
    hrp.CFrame = CFrame.new(-8652.8672, 29.2667, 2089.2617)
    task.wait(0.2)

    local VirtualInputManager = game:GetService("VirtualInputManager")
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end)



local MP3_URL = ""
local Playlist = {}
local currentIndex = 0
local isPaused = false
local fileName = "GenesisPlaylist_"..player.Name..".txt"
local tempIndex = 0
local currentSound = nil

if isfile(fileName) then
	local data = readfile(fileName)
	for url in string.gmatch(data, "[^,]+") do
		table.insert(Playlist, url)
	end
else
	writefile(fileName, "")
end

local function savePlaylist()
	writefile(fileName, table.concat(Playlist, ","))
end

local function formatTime(sec)
	sec = math.floor(sec or 0)
	local m = math.floor(sec / 60)
	local s = sec % 60
	return string.format("%02d:%02d", m, s)
end

local TimeLabel = extraTab:AddLabel("00:00 / 00:00")

local function loadMP3(url)
	if url == "" then return end
	tempIndex = tempIndex + 1
	local tempFile = "GenesisMusic_"..tempIndex..".mp3"

	pcall(function()
		if isfile(tempFile) then delfile(tempFile) end
		writefile(tempFile, game:HttpGet(url))
	end)

	if currentSound then
		currentSound:Destroy()
	end

	currentSound = Instance.new("Sound")
	currentSound.Name = "papi karmaMP3Sound"
	currentSound.Parent = SoundService
	currentSound.SoundId = getcustomasset(tempFile)
	currentSound.Volume = 1
	currentSound.Looped = false
	currentSound:Play()
	isPaused = false

	-- Cuando termina la canciÃ³n, pasa a la siguiente
	currentSound.Ended:Connect(function()
		if not currentSound.Looped and not isPaused then
			currentIndex = currentIndex + 1
			if currentIndex > #Playlist then currentIndex = 1 end
			loadMP3(Playlist[currentIndex])
		end
	end)
end

-- Bucle de actualizaciÃ³n de tiempo
task.spawn(function()
	while task.wait(0.1) do
		if currentSound and currentSound:IsDescendantOf(SoundService) and currentSound.IsLoaded then
			TimeLabel.Text = "â±ï¸ " .. formatTime(currentSound.TimePosition) .. " / " .. formatTime(currentSound.TimeLength)

			-- Respaldo por si el evento Ended falla
			if not currentSound.IsPlaying and not isPaused and currentSound.TimePosition > 0 and currentSound.TimePosition >= currentSound.TimeLength - 0.2 then
				currentIndex = currentIndex + 1
				if currentIndex > #Playlist then currentIndex = 1 end
				loadMP3(Playlist[currentIndex])
			end
		end
	end
end)

-- Controles
extraTab:AddTextBox(" MP3 URL", function(val)
	MP3_URL = val
end, {["clear"] = false})

extraTab:AddButton("Play", function()
	if MP3_URL ~= "" then
		loadMP3(MP3_URL)
	end
end)

extraTab:AddButton("Continue", function()
	if currentSound then
		if isPaused then
			isPaused = false
			currentSound:Resume()
		else
			currentSound:Play()
		end
	end
end)

extraTab:AddButton("Pause", function()
	if currentSound and currentSound.IsPlaying then
		currentSound:Pause()
		isPaused = true
	end
end)

extraTab:AddButton("Stop", function()
	if currentSound then
		currentSound:Stop()
		isPaused = false
	end
end)

extraTab:AddTextBox("Volumen (0-5)", function(val)
	if currentSound then
		local num = tonumber(val)
		if num then
			currentSound.Volume = math.clamp(num, 0, 5)
		end
	end
end, {["clear"] = false})

extraTab:AddButton("Toggle Loop", function()
	if currentSound then
		currentSound.Looped = not currentSound.Looped
	end
end)

extraTab:AddButton("Add to Playlist", function()
	if MP3_URL ~= "" then
		tempIndex = tempIndex + 1
		local tempFile = "GenesisMusic_"..tempIndex..".mp3"
		pcall(function()
			if isfile(tempFile) then delfile(tempFile) end
			writefile(tempFile, game:HttpGet(MP3_URL))
		end)
		table.insert(Playlist, MP3_URL)
		savePlaylist()
	end
end)

extraTab:AddButton("Play Playlist", function()
	if #Playlist > 0 then
		currentIndex = 1
		loadMP3(Playlist[currentIndex])
	end
end)

extraTab:AddButton("Next", function()
	if #Playlist > 0 then
		currentIndex = currentIndex + 1
		if currentIndex > #Playlist then currentIndex = 1 end
		loadMP3(Playlist[currentIndex])
	end
end)

extraTab:AddButton("Previous", function()
	if #Playlist > 0 then
		currentIndex = currentIndex - 1
		if currentIndex < 1 then currentIndex = #Playlist end
		loadMP3(Playlist[currentIndex])
	end
end)

extraTab:AddButton("Clear Playlist", function()
	Playlist = {}
	savePlaylist()
	currentIndex = 0
end)
extraTab:AddTextBox("Speed", function(value)
    local selectedSpeed = value
 
    _G.AutoSpeed = true
 
    if _G.AutoSpeed then
        if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = tonumber(selectedSpeed)
        end
    end
end)
 extraTab:AddButton('Claim All Chest ', function()
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').mythicalChest.circleInner, 0)
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').mythicalChest.circleInner, 1)
    wait()
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').magmaChest.circleInner, 0)
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').magmaChest.circleInner, 1)
    wait()
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').groupRewardsCircle.circleInner, 0)
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').groupRewardsCircle.circleInner, 1)
    wait()
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').goldenChest.circleInner, 0)
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').goldenChest.circleInner, 1)
    wait()
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').enchantedChest.circleInner, 0)
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').enchantedChest.circleInner, 1)
    wait()
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').legendsChest.circleInner, 0)
    firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, game:GetService('Workspace').legendsChest.circleInner, 1)
end)
extraTab:AddTextBox("Size", function(value)
    local selectedSize = value
 
    _G.AutoSize = true
 
    if _G.AutoSize then
        game:GetService("ReplicatedStorage").rEvents.changeSpeedSizeRemote:InvokeServer("changeSize", tonumber(selectedSize))
    end
end)
    extraTab:AddSwitch("Spin Fortune Wheel", function(state)
    _G.AutoSpinWheel = state

    if state then
        spawn(function()
            while _G.AutoSpinWheel and task.wait(0.1) do
                game:GetService("ReplicatedStorage").rEvents.openFortuneWheelRemote:InvokeServer(
                    "openFortuneWheel",
                    game:GetService("ReplicatedStorage").fortuneWheelChances["Fortune Wheel"]
                )
            end
        end)
    end
end)
extraTab:AddSwitch("Hide All Frames", function(state)
    local rSto = game:GetService("ReplicatedStorage")

    for _, obj in pairs(rSto:GetDescendants()) do
        if obj:IsA("GuiObject") and obj.Name:match("Frames") then
            obj.Visible = not state
        end
    end

    if state then
        if _G.HideFramesConn then
            _G.HideFramesConn:Disconnect()
        end
        _G.HideFramesConn = rSto.DescendantAdded:Connect(function(obj)
            if obj:IsA("GuiObject") and obj.Name:match("Frames") then
                obj.Visible = false
            end
        end)
    else
        if _G.HideFramesConn then
            _G.HideFramesConn:Disconnect()
            _G.HideFramesConn = nil
        end
        for _, obj in pairs(rSto:GetDescendants()) do
            if obj:IsA("GuiObject") and obj.Name:match("Frames") then
                obj.Visible = true
            end
        end
    end
end)


extraTab:AddButton("Gamepass AutoLift", function()

    local gamepassIds = ReplicatedStorage:WaitForChild("gamepassIds")

    for _, gamepass in ipairs(gamepassIds:GetChildren()) do
        local owned = Instance.new("IntValue")
        owned.Name = gamepass.Name
        owned.Value = gamepass.Value
        owned.Parent = player:WaitForChild("ownedGamepasses")
    end

    print("[Gamepass AutoLift] Todos los gamepasses fueron agregados localmente.")

end)

extraTab:AddButton("Anti Lag", function()
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            v.Enabled = false
        end
    end
 
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = false
    lighting.FogEnd = 9e9
    lighting.Brightness = 0
 
    settings().Rendering.QualityLevel = 1
 
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("BasePart") and not v:IsA("MeshPart") then
            v.Material = Enum.Material.SmoothPlastic
            if v.Parent and (v.Parent:FindFirstChild("Humanoid") or v.Parent.Parent:FindFirstChild("Humanoid")) then
            else
                v.Reflectance = 0
            end
        end
    end
 
    for _, v in pairs(lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
            v.Enabled = false
        end
    end
 
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "anti lag activado",
        Text = "Full optimization applied!",
        Duration = 5
    })
end)
extraTab:AddButton("Remove Portals", function()
    for _, portal in pairs(game:GetDescendants()) do
        if portal.Name == "RobloxForwardPortals" then
            portal:Destroy()
        end
    end
    
    if _G.AdRemovalConnection then
        _G.AdRemovalConnection:Disconnect()
    end
    
    _G.AdRemovalConnection = game.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "RobloxForwardPortals" then
            descendant:Destroy()
        end
    end)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Anuncios Eliminados",
        Text = "Los anuncios de Roblox han sido eliminados",
        Duration = 0
    })
end)
extraTab:AddButton("Claim Codes", function()

    local Event = game:GetService("ReplicatedStorage").rEvents.codeRemote

    local codes = {
        "superpunch100",
        "supermuscle100",
        "speedy50",
        "spacegems50",
        "Skyagility50",
        "musclestorm50",
        "megalift50",
        "launch250",
        "galaxycrystal50",
        "frostgems10",
        "epicreward500",
        "MillionWarriors"
    }

    for _, code in ipairs(codes) do
        Event:InvokeServer(code)
        task.wait(0.5)
    end

    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Codes",
        Text = "Claim Done",
        Duration = 5
    })

end)
local Gift = window:AddTab("Auto Gift")
local RS = game:GetService("ReplicatedStorage")


-- Labels for item counts
Gift:AddLabel("Gifting Protein egg:").TextSize = 22
local proteinEggLabel = Gift:AddLabel("Protein Eggs: 0")
proteinEggLabel.TextSize = 20

Gift:AddLabel("Gifting Tropical Shakes:").TextSize = 22
local tropicalShakeLabel = Gift:AddLabel("Tropical Shakes: 0")
tropicalShakeLabel.TextSize = 18

-- Dropdown helper
local function createPlayerDropdown(title, callback)
	local drop = Gift:AddDropdown(title, callback)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then drop:Add(plr.DisplayName) end
	end
	Players.PlayerAdded:Connect(function(plr)
		if plr ~= LocalPlayer then drop:Add(plr.DisplayName) end
	end)
	return drop
end

-- Protein Egg gifting
local selectedEggPlayer = nil
local eggCount = 0

createPlayerDropdown("Player to Gift Eggs", function(display)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.DisplayName == display then
			selectedEggPlayer = plr
			break
		end
	end
end)

Gift:AddTextBox("Amount of Eggs", function(text)
	eggCount = tonumber(text) or 0
end)

Gift:AddButton("Gift Eggs", function()
	if not selectedEggPlayer or eggCount <= 0 then return end
	for _ = 1, eggCount do
		local egg = LocalPlayer.consumablesFolder:FindFirstChild("Protein Egg")
		if egg then
			RS.rEvents.giftRemote:InvokeServer("giftRequest", selectedEggPlayer, egg)
			task.wait(0.1)
		end
	end
end)

-- Tropical Shake gifting
local selectedShakePlayer = nil
local shakeCount = 0

createPlayerDropdown("Player to Gift Tropical Shakes", function(display)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.DisplayName == display then
			selectedShakePlayer = plr
			break
		end
	end
end)

Gift:AddTextBox("Tropical Shakes gift", function(text)
	shakeCount = tonumber(text) or 0
end)

Gift:AddButton("Gift Tropical Shakes", function()
	if not selectedShakePlayer or shakeCount <= 0 then return end
	for _ = 1, shakeCount do
		local shake = LocalPlayer.consumablesFolder:FindFirstChild("Tropical Shake")
		if shake then
			RS.rEvents.giftRemote:InvokeServer("giftRequest", selectedShakePlayer, shake)
			task.wait(0.1)
		end
	end
end)

-- Update item counts
local function updateItemCount()
	local eggs, shakes = 0, 0
	for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
		if item.Name == "Protein Egg" then
			eggs += 1
		elseif item.Name == "Tropical Shake" then
			shakes += 1
		end
	end
	proteinEggLabel.Text = "Protein Eggs: " .. eggs
	tropicalShakeLabel.Text = "Tropical Shakes: " .. shakes
end

task.spawn(function()
	while true do
		updateItemCount()
		task.wait(0.25)
	end
end)

-- Auto Eat System
local itemList = {
	"Tropical Shake", "Energy Shake", "Protein Bar",
	"TOUGH Bar", "Protein Shake", "ULTRA Shake", "Energy Bar"
}

local function formatEventName(name)
	local parts = {}
	for word in name:gmatch("%S+") do parts[#parts+1] = word:lower() end
	for i = 2, #parts do
		parts[i] = parts[i]:sub(1,1):upper() .. parts[i]:sub(2)
	end
	return table.concat(parts)
end

local function activateRandomItems(count)
	local items = {unpack(itemList)}
	for i = #items, 2, -1 do
		local j = math.random(i)
		items[i], items[j] = items[j], items[i]
	end
	for i = 1, math.min(count, #items) do
		local name = items[i]
		local tool = LocalPlayer.Character:FindFirstChild(name) or LocalPlayer.Backpack:FindFirstChild(name)
		if tool then
			LocalPlayer.muscleEvent:FireServer(formatEventName(name), tool)
		end
	end
end

local eatingRunning = false
task.spawn(function()
	while true do
		if eatingRunning then activateRandomItems(4) end
		task.wait(0.5)
	end
end)

Gift:AddButton("Eat Everything", function(state)
	eatingRunning = state
	if state then activateRandomItems(4) end
end)

-- Requiere que ya tengas creado el Tab (acÃ¡ lo llamo StatsTab) y las
-- variables player / leaderstats como en el resto de tus scripts.

local StatsTab = window:AddTab("Stats")

local targetName = ""
local playerDropdown = StatsTab:AddDropdown("Select Player", function(value)
	-- El dropdown muestra "DisplayName | Name", nos quedamos con el Name real
	targetName = value:match("| (.+)")
end)

for _, plr in pairs(Players:GetPlayers()) do
	playerDropdown:Add(plr.DisplayName .. " | " .. plr.Name)
end

Players.PlayerAdded:Connect(function(plr)
	playerDropdown:Add(plr.DisplayName .. " | " .. plr.Name)
end)

local function formatNumber(number)
	-- Igual que en tu farming_stats.lua: agrega separador de miles y
	-- sufijo (K/M/B/T/Qa/Qi)
	local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi"}
	local index = 1
	while number >= 1000 and index < #suffixes do
		number = number / 1000
		index = index + 1
	end
	return string.format("%.2f", number) .. suffixes[index]
end

-- CuÃ¡ntas mascotas de "petName" tiene equipadas el jugador dado
local function countEquippedPets(plr, petName)
	local equippedPets = plr:FindFirstChild("equippedPets")
	if not equippedPets then
		return 0
	end
	local count = 0
	for _, entry in pairs(equippedPets:GetChildren()) do
		local ref = entry:FindFirstChild("petReference")
		if ref and ref.Value and ref.Value.Name == petName then
			count += 1
		end
	end
	return count
end

local wildWizardLabel -- se asigna mÃ¡s abajo, junto con los demÃ¡s labels

-- Tu daÃ±o: 10% de tu Strength, + 33% de bonus por cada Wild Wizard equipado
local function calculateYourDamage()
	local strength = player:FindFirstChild("leaderstats")
		and player.leaderstats:FindFirstChild("Strength")
	if not strength then
		return 0
	end

	local base = strength.Value * 0.1
	local wildWizardCount = countEquippedPets(player, "Wild Wizard")
	local bonusMultiplier = wildWizardCount * 0.33

	if wildWizardLabel then
		wildWizardLabel.Text = "Wild Wizard equipped: " .. wildWizardCount
			.. " (" .. formatNumber(base * bonusMultiplier) .. " bonus)"
	end

	return base * (1 + bonusMultiplier)
end

-- Vida del objetivo: su Durability (con posible bonus de "Infernal Health",
-- ver nota abajo)
local function calculateEnemyLife(targetPlayer)
	if not targetPlayer then
		return 0
	end
	local durability = targetPlayer:FindFirstChild("Durability")
	return durability and durability.Value or 0
end

-- Golpes necesarios: vida / daÃ±o, redondeado hacia arriba; âˆž si da mÃ¡s de 50
local function calculateBlowsToKill(enemyLife, yourDamage)
	if yourDamage <= 0 then
		return "âˆž"
	end
	local blows = math.ceil(enemyLife / yourDamage)
	if blows > 50 then
		return "âˆž"
	end
	return tostring(math.max(blows, 1))
end

-- --- Labels ---

local enemyLifeLabel = StatsTab:AddLabel("Enemy life: N/A")
local yourDamageLabel = StatsTab:AddLabel("Your damage: N/A")
local blowsToKillLabel = StatsTab:AddLabel("Blows to kill him: N/A")
wildWizardLabel = StatsTab:AddLabel("Wild Wizard equipped: 0 (0 bonus)")

local goodKarmaLabel = StatsTab:AddLabel("Good Karma: N/A")
local evilKarmaLabel = StatsTab:AddLabel("Evil Karma: N/A")

local function updateStats(targetPlayer)
	if not targetPlayer then
		enemyLifeLabel.Text = "Enemy life: N/A"
		yourDamageLabel.Text = "Your damage: N/A"
		blowsToKillLabel.Text = "Blows to kill him: N/A"
		goodKarmaLabel.Text = "Good Karma: N/A"
		evilKarmaLabel.Text = "Evil Karma: N/A"
		return
	end

	local enemyLife = calculateEnemyLife(targetPlayer)
	local yourDamage = calculateYourDamage()

	enemyLifeLabel.Text = "Enemy life: " .. (enemyLife > 0 and formatNumber(enemyLife) or "N/A")
	yourDamageLabel.Text = "Your damage: " .. (yourDamage > 0 and formatNumber(yourDamage) or "N/A")
	blowsToKillLabel.Text = "Blows to kill him: " .. calculateBlowsToKill(enemyLife, yourDamage)

	local goodKarma = targetPlayer:FindFirstChild("goodKarma")
	local evilKarma = targetPlayer:FindFirstChild("evilKarma")
	goodKarmaLabel.Text = "Good Karma: " .. (goodKarma and formatNumber(goodKarma.Value) or "N/A")
	evilKarmaLabel.Text = "Evil Karma: " .. (evilKarma and formatNumber(evilKarma.Value) or "N/A")
end

task.spawn(function()
	while true do
		local targetPlayer = targetName ~= "" and Players:FindFirstChild(targetName)
		updateStats(targetPlayer)
		task.wait() -- se recalcula todos los frames, igual que el original
	end
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local teleport = window:AddTab("Tp")

teleport:AddButton("Spawn", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(2, 8, 115)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Spawn",
        Duration = 0
    })
end)

teleport:AddButton("Secret Area", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(1947, 2, 6191)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Secret Area",
        Duration = 0
    })
end)

teleport:AddButton("Tiny Island", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(-34, 7, 1903)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Tiny Island",
        Duration = 0
    })
end)

teleport:AddButton("Frozen Island", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(- 2600.00244, 3.67686558, - 403.884369, 0.0873617008, 1.0482899e-09, 0.99617666, 3.07204253e-08, 1, - 3.7464023e-09, - 0.99617666, 3.09302628e-08, 0.0873617008)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Frozen Island",
        Duration = 0
    })
end)

teleport:AddButton("Mythical Island", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(2255, 7, 1071)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Mythical Island",
        Duration = 0
    })
end)

teleport:AddButton("Hell Island", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(-6768, 7, -1287)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Hell Island",
        Duration = 0
    })
end)

teleport:AddButton("Legend Island", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(4604, 991, -3887)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Legend Island",
        Duration = 0
    })
end)

teleport:AddButton("Muscle King Island", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(-8646, 17, -5738)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Muscle King",
        Duration = 0
    })
end)

teleport:AddButton("Jungle Island", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(-8659, 6, 2384)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Jungle Island",
        Duration = 0
    })
end)

teleport:AddButton("Brawl Lava", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(4471, 119, -8836)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Brawl Lava",
        Duration = 0
    })
end)

teleport:AddButton("Brawl Desert", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(960, 17, -7398)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Brawl Desert",
        Duration = 0
    })
end)

teleport:AddButton("Brawl Regular", function()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoidRootPart.CFrame = CFrame.new(-1849, 20, -6335)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Teletransporte",
        Text = "Teleported to Brawl Regular",
        Duration = 0
    })
end)


local Killer = window:AddTab("Kills op")

local playerWhitelist = {}
local targetPlayerNames = {}
local autoGoodKarma = false
local autoBadKarma = false
local autoKill = false
local killTarget = false
local spying = false
local autoEquipPunch = false
local autoPunchNoAnim = false
local targetDropdownItems = {}
local availableTargets = {}

local titleLabel = Killer:AddLabel("Equipar pet de dura o daño")
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.Merriweather 
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

local dropdown = Killer:AddDropdown("Select Pet", function(text)
    local petsFolder = game.Players.LocalPlayer.petsFolder
    for _, folder in pairs(petsFolder:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in pairs(folder:GetChildren()) do
                game:GetService("ReplicatedStorage").rEvents.equipPetEvent:FireServer("unequipPet", pet)
            end
        end
    end
    task.wait(0.2)

    local petName = text
    local petsToEquip = {}

    for _, pet in pairs(game.Players.LocalPlayer.petsFolder.Unique:GetChildren()) do
        if pet.Name == petName then
            table.insert(petsToEquip, pet)
        end
    end

    local maxPets = 8
    local equippedCount = math.min(#petsToEquip, maxPets)

    for i = 1, equippedCount do
        game:GetService("ReplicatedStorage").rEvents.equipPetEvent:FireServer("equipPet", petsToEquip[i])
        task.wait(0.1)
    end
end)

local Wild_Wizard = dropdown:Add("Wild Wizard")
local Powerful_Monster = dropdown:Add("Mighty Monster")


Killer:AddSwitch("Auto Good Karma", function(bool)
    autoGoodKarma = bool
    task.spawn(function()
        while autoGoodKarma do
            local playerChar = LocalPlayer.Character
            local rightHand = playerChar and playerChar:FindFirstChild("RightHand")
            local leftHand = playerChar and playerChar:FindFirstChild("LeftHand")
            if playerChar and rightHand and leftHand then
                for _, target in ipairs(Players:GetPlayers()) do
                    if target ~= LocalPlayer then
                        local evilKarma = target:FindFirstChild("evilKarma")
                        local goodKarma = target:FindFirstChild("goodKarma")
                        if evilKarma and goodKarma and evilKarma:IsA("IntValue") and goodKarma:IsA("IntValue") and evilKarma.Value > goodKarma.Value then
                            local rootPart = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                            if rootPart then
                                firetouchinterest(rightHand, rootPart, 1)
                                firetouchinterest(leftHand, rootPart, 1)
                                firetouchinterest(rightHand, rootPart, 0)
                                firetouchinterest(leftHand, rootPart, 0)
                            end
                        end
                    end
                end
            end
            task.wait(0.01)
        end
    end)
end)

Killer:AddSwitch("Auto Bad Karma", function(bool)
    autoBadKarma = bool
    task.spawn(function()
        while autoBadKarma do
            local playerChar = LocalPlayer.Character
            local rightHand = playerChar and playerChar:FindFirstChild("RightHand")
            local leftHand = playerChar and playerChar:FindFirstChild("LeftHand")
            if playerChar and rightHand and leftHand then
                for _, target in ipairs(Players:GetPlayers()) do
                    if target ~= LocalPlayer then
                        local evilKarma = target:FindFirstChild("evilKarma")
                        local goodKarma = target:FindFirstChild("goodKarma")
                        if evilKarma and goodKarma and evilKarma:IsA("IntValue") and goodKarma:IsA("IntValue") and goodKarma.Value > evilKarma.Value then
                            local rootPart = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                            if rootPart then
                                firetouchinterest(rightHand, rootPart, 1)
                                firetouchinterest(leftHand, rootPart, 1)
                                firetouchinterest(rightHand, rootPart, 0)
                                firetouchinterest(leftHand, rootPart, 0)
                            end
                        end
                    end
                end
            end
            task.wait(0.01)
        end
    end)
end)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local friendWhitelistActive = false

Killer:AddSwitch("Auto Whitelist Friends", function(state)
    friendWhitelistActive = state

    if state then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and LocalPlayer:IsFriendsWith(player.UserId) then
                playerWhitelist[player.Name] = true
            end
        end

        Players.PlayerAdded:Connect(function(player)
            if friendWhitelistActive and player ~= LocalPlayer and LocalPlayer:IsFriendsWith(player.UserId) then
                playerWhitelist[player.Name] = true
            end
        end)
    else
        for name in pairs(playerWhitelist) do
            local friend = Players:FindFirstChild(name)
            if friend and LocalPlayer:IsFriendsWith(friend.UserId) then
                playerWhitelist[name] = nil
            end
        end
    end
end)

Killer:AddTextBox("Whitelist", function(text)
    local target = Players:FindFirstChild(text)
    if target then
        playerWhitelist[target.Name] = true
    end
end)

Killer:AddTextBox("UnWhitelist", function(text)
    local target = Players:FindFirstChild(text)
    if target then
        playerWhitelist[target.Name] = nil
    end
end)

Killer:AddSwitch("Auto Kill", function(bool)
    autoKill = bool

    task.spawn(function()
        while autoKill do
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local rightHand = character:FindFirstChild("RightHand")
            local leftHand = character:FindFirstChild("LeftHand")

            local punch = LocalPlayer.Backpack:FindFirstChild("Punch")
            if punch and not character:FindFirstChild("Punch") then
                punch.Parent = character
            end

            if rightHand and leftHand then
                for _, target in ipairs(Players:GetPlayers()) do
                    if target ~= LocalPlayer and not playerWhitelist[target.Name] then
                        local targetChar = target.Character
                        local rootPart = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            pcall(function()
                                firetouchinterest(rightHand, rootPart, 1)
                                firetouchinterest(leftHand, rootPart, 1)
                                firetouchinterest(rightHand, rootPart, 0)
                                firetouchinterest(leftHand, rootPart, 0)
                            end)
                        end
                    end
                end
            end

            task.wait(0.05)
        end
    end)
end)

local targetDropdown = Killer:AddDropdown("Select Target", function(name)
    if name and not table.find(targetPlayerNames, name) then
        table.insert(targetPlayerNames, name)
    end
end)

Killer:AddTextBox("Remove Target", function(name)
    for i, v in ipairs(targetPlayerNames) do
        if v == name then
            table.remove(targetPlayerNames, i)
            break
        end
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        targetDropdown:Add(player.Name)
        targetDropdownItems[player.Name] = true
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        targetDropdown:Add(player.Name)
        targetDropdownItems[player.Name] = true
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if targetDropdownItems[player.Name] then
        targetDropdownItems[player.Name] = nil
        targetDropdown:Clear()
        for name in pairs(targetDropdownItems) do
            targetDropdown:Add(name)
        end
    end

    for i = #targetPlayerNames, 1, -1 do
        if targetPlayerNames[i] == player.Name then
            table.remove(targetPlayerNames, i)
        end
    end
end)

Killer:AddSwitch("Start Kill Target", function(state)
    killTarget = state

    task.spawn(function()
        while killTarget do
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

            local punch = LocalPlayer.Backpack:FindFirstChild("Punch")
            if punch and not character:FindFirstChild("Punch") then
                punch.Parent = character
            end

            local rightHand = character:WaitForChild("RightHand", 5)
            local leftHand = character:WaitForChild("LeftHand", 5)

            if rightHand and leftHand then
                for _, name in ipairs(targetPlayerNames) do
                    local target = Players:FindFirstChild(name)
                    if target and target ~= LocalPlayer then
                        local rootPart = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            pcall(function()
                                firetouchinterest(rightHand, rootPart, 1)
                                firetouchinterest(leftHand, rootPart, 1)
                                firetouchinterest(rightHand, rootPart, 0)
                                firetouchinterest(leftHand, rootPart, 0)
                            end)
                        end
                    end
                end
            end

            task.wait(0.05)
        end
    end)
end)

local spyTargetDropdown = Killer:AddDropdown("Select View Target", function(name)
    targetPlayerName = name
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        spyTargetDropdown:Add(player.Name)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        spyTargetDropdown:Add(player.Name)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player ~= LocalPlayer then
        spyTargetDropdown:Clear()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                spyTargetDropdown:Add(plr.Name)
            end
        end
    end
end)

Killer:AddSwitch("View Player", function(bool)
    spying = bool
    if not spying then
        local cam = workspace.CurrentCamera
        cam.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") or LocalPlayer
        return
    end
    task.spawn(function()
        while spying do
            local target = Players:FindFirstChild(targetPlayerName)
            if target and target ~= LocalPlayer then
                local humanoid = target.Character and target.Character:FindFirstChild("Humanoid")
                if humanoid then
                    workspace.CurrentCamera.CameraSubject = humanoid
                end
            end
            task.wait(0.1)
        end
    end)
end)

local button = Killer:AddButton("Remove Punch Anim", function()
    local blockedAnimations = {
        ["rbxassetid://3638729053"] = true,
        ["rbxassetid://3638767427"] = true,
    }

    local function setupAnimationBlocking()
        local char = game.Players.LocalPlayer.Character
        if not char or not char:FindFirstChild("Humanoid") then return end

        local humanoid = char:FindFirstChild("Humanoid")

        for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
            if track.Animation then
                local animId = track.Animation.AnimationId
                local animName = track.Name:lower()

                if blockedAnimations[animId] or
                    animName:match("punch") or
                    animName:match("attack") or
                    animName:match("right") then
                    track:Stop()
                end
            end
        end

        if not _G.AnimBlockConnection then
            local connection = humanoid.AnimationPlayed:Connect(function(track)
                if track.Animation then
                    local animId = track.Animation.AnimationId
                    local animName = track.Name:lower()

                    if blockedAnimations[animId] or
                        animName:match("punch") or
                        animName:match("attack") or
                        animName:match("right") then
                        track:Stop()
                    end
                end
            end)

            _G.AnimBlockConnection = connection
        end
    end

    setupAnimationBlocking()

    local function overrideToolActivation()
        local function processTool(tool)
            if tool and (tool.Name == "Punch" or tool.Name:match("Attack") or tool.Name:match("Right")) then
                if not tool:GetAttribute("ActivatedOverride") then
                    tool:SetAttribute("ActivatedOverride", true)

                    local connection = tool.Activated:Connect(function()
                        task.wait(0.05)

                        local char = game.Players.LocalPlayer.Character
                        if char and char:FindFirstChild("Humanoid") then
                            for _, track in pairs(char.Humanoid:GetPlayingAnimationTracks()) do
                                if track.Animation then
                                    local animId = track.Animation.AnimationId
                                    local animName = track.Name:lower()

                                    if blockedAnimations[animId] or
                                        animName:match("punch") or
                                        animName:match("attack") or
                                        animName:match("right") then
                                        track:Stop()
                                    end
                                end
                            end
                        end
                    end)

                    if not _G.ToolConnections then
                        _G.ToolConnections = {}
                    end
                    _G.ToolConnections[tool] = connection
                end
            end
        end

        for _, tool in pairs(game.Players.LocalPlayer.Backpack:GetChildren()) do
            processTool(tool)
        end

        local char = game.Players.LocalPlayer.Character
        if char then
            for _, tool in pairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    processTool(tool)
                end
            end
        end

        if not _G.BackpackAddedConnection then
            _G.BackpackAddedConnection = game.Players.LocalPlayer.Backpack.ChildAdded:Connect(function(child)
                if child:IsA("Tool") then
                    task.wait(0.1)
                    processTool(child)
                end
            end)
        end

        if not _G.CharacterToolAddedConnection and char then
            _G.CharacterToolAddedConnection = char.ChildAdded:Connect(function(child)
                if child:IsA("Tool") then
                    task.wait(0.1)
                    processTool(child)
                end
            end)
        end
    end

    overrideToolActivation()

    if not _G.AnimMonitorConnection then
        _G.AnimMonitorConnection = game:GetService("RunService").Heartbeat:Connect(function()
            if tick() % 0.5 < 0.01 then
                local char = game.Players.LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") then
                    for _, track in pairs(char.Humanoid:GetPlayingAnimationTracks()) do
                        if track.Animation then
                            local animId = track.Animation.AnimationId
                            local animName = track.Name:lower()

                            if blockedAnimations[animId] or
                                animName:match("punch") or
                                animName:match("attack") or
                                animName:match("right") then
                                track:Stop()
                            end
                        end
                    end
                end
            end
        end)
    end

    if not _G.CharacterAddedConnection then
        _G.CharacterAddedConnection = game.Players.LocalPlayer.CharacterAdded:Connect(function(newChar)
            task.wait(1)
            setupAnimationBlocking()
            overrideToolActivation()

            if _G.CharacterToolAddedConnection then
                _G.CharacterToolAddedConnection:Disconnect()
            end

            _G.CharacterToolAddedConnection = newChar.ChildAdded:Connect(function(child)
                if child:IsA("Tool") then
                    task.wait(0.1)
                    processTool(child)
                end
            end)
        end)
    end
end)

function RecoveryPunch()
    if _G.AnimBlockConnection then
        _G.AnimBlockConnection:Disconnect()
        _G.AnimBlockConnection = nil
    end
    if _G.AnimMonitorConnection then
        _G.AnimMonitorConnection:Disconnect()
        _G.AnimMonitorConnection = nil
    end
    if _G.ToolConnections then
        for _, conn in pairs(_G.ToolConnections) do
            if conn then conn:Disconnect() end
        end
        _G.ToolConnections = nil
    end
    if _G.BackpackAddedConnection then
        _G.BackpackAddedConnection:Disconnect()
        _G.BackpackAddedConnection = nil
    end
    if _G.CharacterToolAddedConnection then
        _G.CharacterToolAddedConnection:Disconnect()
        _G.CharacterToolAddedConnection = nil
    end
    if _G.CharacterAddedConnection then
        _G.CharacterAddedConnection:Disconnect()
        _G.CharacterAddedConnection = nil
    end
end

Killer:AddButton("Recover Punch Anim", function()
    RecoveryPunch()
end)

Killer:AddSwitch("Auto Equip Punch", function(state)
	autoEquipPunch = state
	task.spawn(function()
		while autoEquipPunch do
			local punch = LocalPlayer.Backpack:FindFirstChild("Punch")
			if punch then
				punch.Parent = LocalPlayer.Character
			end
			task.wait(0.1)
		end
	end)
end)

Killer:AddSwitch("Auto golpear [sin animación]", function(state)
	autoPunchNoAnim = state
	task.spawn(function()
		while autoPunchNoAnim do
			local punch = LocalPlayer.Backpack:FindFirstChild("Punch") or LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch")
			if punch then
				if punch.Parent ~= LocalPlayer.Character then
					punch.Parent = LocalPlayer.Character
				end
				LocalPlayer.muscleEvent:FireServer("punch", "rightHand")
				LocalPlayer.muscleEvent:FireServer("punch", "leftHand")
			else
				autoPunchNoAnim = false
			end
			task.wait(0.01)
		end
	end)
end)

Killer:AddSwitch("Auto Punch", function(state)
	_G.fastHitActive = state
	if state then
		task.spawn(function()
			while _G.fastHitActive do
				local punch = LocalPlayer.Backpack:FindFirstChild("Punch")
				if punch then
					punch.Parent = LocalPlayer.Character
					if punch:FindFirstChild("attackTime") then
						punch.attackTime.Value = 0
					end
				end
				task.wait(0.1)
			end
		end)
		task.spawn(function()
			while _G.fastHitActive do
				local punch = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch")
				if punch then
					punch:Activate()
				end
				task.wait(0.1)
			end
		end)
	else
		local punch = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch")
		if punch then
			punch.Parent = LocalPlayer.Backpack
		end
	end
end)

Killer:AddSwitch("golpe rápido", function(state)
	_G.autoPunchActive = state
	if state then
		task.spawn(function()
			while _G.autoPunchActive do
				local punch = LocalPlayer.Backpack:FindFirstChild("Punch")
				if punch then
					punch.Parent = LocalPlayer.Character
					if punch:FindFirstChild("attackTime") then
						punch.attackTime.Value = 0
					end
				end
				task.wait()
			end
		end)
		task.spawn(function()
			while _G.autoPunchActive do
				local punch = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch")
				if punch then
					punch:Activate()
				end
				task.wait()
			end
		end)
	else
		local punch = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch")
		if punch then
			punch.Parent = LocalPlayer.Backpack
		end
	end
end)



local godModeToggle = false
Killer:AddSwitch("modo dios (esperar peleas)", function(State)
    godModeToggle = State
    if State then
        task.spawn(function()
            while godModeToggle do
                game:GetService("ReplicatedStorage").rEvents.brawlEvent:FireServer("joinBrawl")
                task.wait()
            end
        end)
    end
end)
-- 📌 Teleport / Follow System (versión auto-follow desde Dropdown)

-- 📌 Auto Follow (TP detrás del jugador en vez de caminar)
local following = false
local followTarget = nil

-- Función auxiliar: TP detrás del jugador
function followPlayer(targetPlayer)
    local myChar = LocalPlayer.Character
    local targetChar = targetPlayer.Character

    if not (myChar and targetChar) then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")

    if myHRP and targetHRP then
        -- 📌 Calcular posición detrás del jugador (3 studs atrás)
        local followPos = targetHRP.Position - (targetHRP.CFrame.LookVector * 3)
        -- 📌 Teletransportar siempre recto
        myHRP.CFrame = CFrame.new(followPos, targetHRP.Position)
    end
end

-- Dropdown dinámico de jugadores
local followDropdown = Killer:AddDropdown("Seguir Jugador (TP)", function(selected)
    if selected and selected ~= "" then
        local target = Players:FindFirstChild(selected)
        if target then
            followTarget = target.Name
            following = true
            print("Started following:", target.Name)

            -- TP inmediato al seleccionarlo
            followPlayer(target)
        end
    end
end)

-- Inicializar lista de jugadores
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        followDropdown:Add(player.Name)
    end
end

-- Mantener lista actualizada
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        followDropdown:Add(player.Name)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    followDropdown:Clear()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            followDropdown:Add(plr.Name)
        end
    end
    if followTarget == player.Name then
        followTarget = nil
        following = false
    end
end)

-- Botón para dejar de seguir
Killer:AddButton("Dejar de Seguir", function()
    following = false
    followTarget = nil
    print("Stopped following")
end)

-- Loop de seguimiento automático
task.spawn(function()
    while true do
        task.wait(0.2) -- cada 0.2s para actualizar TP
        if following and followTarget then
            local target = Players:FindFirstChild(followTarget)
            if target then
                followPlayer(target)
            else
                following = false
                followTarget = nil
            end
        end
    end
end)

local godDamageActive = false

Killer:AddSwitch("Daño con Godmode", function(state)
    godDamageActive = state
    if state then
        task.spawn(function()
            while godDamageActive do
                local player = game.Players.LocalPlayer
                local groundSlam = player.Backpack:FindFirstChild("Ground Slam") or (player.Character and player.Character:FindFirstChild("Ground Slam"))

                if groundSlam then
                    -- Equipar
                    if groundSlam.Parent == player.Backpack then
                        groundSlam.Parent = player.Character
                    end

                    -- Quitar delay
                    if groundSlam:FindFirstChild("attackTime") then
                        groundSlam.attackTime.Value = 0
                    end

                    -- Lanzar evento
                    player.muscleEvent:FireServer("slam")

                    -- Activar herramienta
                    groundSlam:Activate()
                end

                task.wait(0.1) -- delay pequeño
            end
        end)
    end
end)

Killer:AddButton("Tamaño NaN", function()
    local args = {"changeSize", 0/0}
    game:GetService("ReplicatedStorage"):WaitForChild("rEvents"):WaitForChild("changeSpeedSizeRemote"):InvokeServer(unpack(args))
end)
-- 📜 Lista de RAWs a ejecutar
local urls = {
    "https://raw.githubusercontent.com/SadOz8/Stuffs/refs/heads/main/Crack",
    "https://raw.githubusercontent.com/SadOz8/Stuffs/refs/heads/main/Crack2",
    "https://raw.githubusercontent.com/SadOz8/Stuffs/refs/heads/main/Crack3",
    "https://raw.githubusercontent.com/SadOz8/Stuffs/refs/heads/main/Crack4",
    "https://raw.githubusercontent.com/SadOz8/Stuffs/refs/heads/main/Crack5",
    "https://raw.githubusercontent.com/SadOz8/Stuffs/refs/heads/main/Crack6"
}

-- ⚡ Botón que ejecuta todos los scripts remotos
Killer:AddButton("Pegar Muerto", function()
    for _, url in ipairs(urls) do
        spawn(function()
            local success, response = pcall(function()
                return game:HttpGet(url)
            end)
            if success and response then
                local loadSuccess, err = pcall(function()
                    loadstring(response)()
                end)
                if not loadSuccess then
                    warn("[Pegar Muerto] Error ejecutando raw:", url, err)
                end
            else
                warn("[Pegar Muerto] No se pudo cargar:", url)
            end
        end)
    end
end)


-- Sistema de Auto Area Travel
local autoAreaTravelEnabled = false

Killer:AddSwitch("Auto GODMODE Join Tiny island", function(state)
    autoAreaTravelEnabled = state
    
    if state then
        warn("ðŸ”„ Auto Area Travel ATIVADO - Tentando viajar para Ã¡rea...")
        task.spawn(function()
            local success, result = pcall(function()
                local Event = game:GetService("ReplicatedStorage").rEvents.areaTravelRemote
                return Event:InvokeServer("travelToArea", workspace.areaCircles.areaCircle)
            end)
            
            if success then
                warn("âœ… Viagem de Ã¡rea executada com sucesso!")
                StarterGui:SetCore("SendNotification", {
                    Title = "Area Travel",
                    Text = "Viagem realizada com sucesso!",
                    Duration = 5
                })
            else
                warn("âŒ Erro ao viajar para Ã¡rea:", result)
                StarterGui:SetCore("SendNotification", {
                    Title = "Area Travel",
                    Text = "Erro: " .. tostring(result),
                    Duration = 5
                })
            end
        end)
    else
        warn("â›” Auto Area Travel DESATIVADO")
    end
end)

task.spawn(function()
    while true do
        if autoAreaTravelEnabled then
            task.wait(10)
            
            local success, result = pcall(function()
                local Event = game:GetService("ReplicatedStorage").rEvents.areaTravelRemote
                return Event:InvokeServer("travelToArea", workspace.areaCircles.areaCircle)
            end)
            
            if success then
                warn("ðŸ”„ Tentativa de viagem automÃ¡tica realizada")
            end
        else
            task.wait(1)
        end
    end
end)

Killer:AddButton("GODMODE Tiny island (Button)", function()
    local success, result = pcall(function()
        local Event = game:GetService("ReplicatedStorage").rEvents.areaTravelRemote
        return Event:InvokeServer("travelToArea", workspace.areaCircles.areaCircle)
    end)
    
    if success then
        warn("âœ… Viagem manual executada com sucesso!")
        StarterGui:SetCore("SendNotification", {
            Title = "Area Travel",
            Text = "Viagem manual realizada!",
            Duration = 5
        })
    else
        warn("âŒ Erro na viagem manual:", result)
    end
end)

-- God Mode
Killer:AddSwitch("GOD MODE Peleas", function(State)
    godModeToggle = State
    if State then
        task.spawn(function()
            while godModeToggle do
                ReplicatedStorage.rEvents.brawlEvent:FireServer("joinBrawl")
                task.wait()
            end
        end)
    end
end)


-- Auto Slam/Stomp
Killer:AddSwitch("Auto Slams", function(state)
    godDamageActive = state
    if state then
        task.spawn(function()
            while godDamageActive do
                local groundSlam = LocalPlayer.Backpack:FindFirstChild("Ground Slam") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Ground Slam"))

                if groundSlam then
                    if groundSlam.Parent == LocalPlayer.Backpack then
                        groundSlam.Parent = LocalPlayer.Character
                    end
                    if groundSlam:FindFirstChild("attackTime") then
                        groundSlam.attackTime.Value = 0
                    end
                    LocalPlayer.muscleEvent:FireServer("slam")
                    groundSlam:Activate()
                end

                task.wait(0.1)
            end
        end)
    end
end)


Killer:AddSwitch("Auto Stomp", function(state)
    godDamageActive = state
    if state then
        task.spawn(function()
            while godDamageActive do
                local stomp = LocalPlayer.Backpack:FindFirstChild("Stomp") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Stomp"))

                if stomp then
                    if stomp.Parent == LocalPlayer.Backpack then
                        stomp.Parent = LocalPlayer.Character
                    end
                    if stomp:FindFirstChild("attackTime") then
                        stomp.attackTime.Value = 0
                    end
                    LocalPlayer.muscleEvent:FireServer("slam")
                    stomp:Activate()
                end

                task.wait(0.1)
            end
        end)
    end
end)

local urls = {
    "https://raw.githubusercontent.com/xccxk/MAIN/refs/heads/main/1-2-3-ALL-STEPS"
}

-- ⚡ Botón que ejecuta todos los scripts remotos
Killer:AddSwitch("Pegar Muerto", function()
    for _, url in ipairs(urls) do
        spawn(function()
            local success, response = pcall(function()
                return game:HttpGet(url)
            end)
            if success and response then
                local loadSuccess, err = pcall(function()
                    loadstring(response)()
                end)
                if not loadSuccess then
                    warn("[Pegar Muerto] Error ejecutando raw:", url, err)
                end
            else
                warn("[Pegar Muerto] No se pudo cargar:", url)
            end
        end)
    end
end)
Killer:AddTextBox("Tamamaño de Aura", function(text)
    local value = tonumber(text)
    if value then
        currentRadius = math.clamp(value, 1, 150)
    end
end)

-- 2. Switch del Kill Aura
Killer:AddSwitch("Aura Kill (Combat)", function(state)
    getgenv().killNearby = state
    
    -- CreaciÃ³n del cÃ­rculo visual
    local radiusVisual = Instance.new("Part")
    radiusVisual.Anchored = true
    radiusVisual.CanCollide = false
    radiusVisual.Transparency = 0.5
    radiusVisual.Material = Enum.Material.ForceField
    radiusVisual.Color = Color3.fromRGB(255, 0, 0) -- Rojo
    radiusVisual.Shape = Enum.PartType.Cylinder
    radiusVisual.Rotation = Vector3.new(0, 0, 90) -- Acostado en el suelo
    
    task.spawn(function()
        while getgenv().killNearby do
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            
            if myRoot then
                -- Actualizar posiciÃ³n del cÃ­rculo visual
                radiusVisual.Parent = workspace
                radiusVisual.Size = Vector3.new(0.1, currentRadius * 2, currentRadius * 2)
                radiusVisual.CFrame = myRoot.CFrame * CFrame.new(0, -3, 0) * CFrame.Angles(0, 0, math.rad(90))
                
                -- Auto-Equipar Combat
                local tool = LocalPlayer.Backpack:FindFirstChild("Combat") or myChar:FindFirstChild("Combat")
                if tool and tool.Parent ~= myChar then
                    tool.Parent = myChar
                end

                -- Buscar vÃ­ctimas dentro del rango
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        local hum = char and char:FindFirstChild("Humanoid")
                        
                        if root and hum and hum.Health > 0 then
                            local distance = (root.Position - myRoot.Position).Magnitude
                            
                            if distance <= currentRadius then
                                pcall(function()
                                    -- Ejecutar el ataque
                                    if tool and tool.Parent == myChar then
                                        tool:Activate()
                                    end
                                    
                                    -- DaÃ±o fÃ­sico por contacto
                                    firetouchinterest(myRoot, root, 1)
                                    firetouchinterest(myRoot, root, 0)
                                    
                                    -- Disparar Remote detectado
                                    if globalTween then
                                        globalTween:FireServer("dmgLabel", root.CFrame, 50000)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
            task.wait(0.1) -- Velocidad de escaneo
        end
        radiusVisual:Destroy()
    end)
end)
Killer:AddLabel("PACK SPAM & PETS").TextSize = 30


local running = false

local function getRemote()
	local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
	if not rEvents then
		return
	end
	return rEvents:FindFirstChild("equipPetEvent")
end

local function unequipAll(remote, petsFolder)
	for _, folder in pairs(petsFolder:GetChildren()) do
		if folder:IsA("Folder") then
			for _, pet in pairs(folder:GetChildren()) do
				remote:FireServer("unequipPet", pet)
			end
		end
	end
end

local function getPets(folder, name)
	local t = {}
	for _, pet in pairs(folder:GetChildren()) do
		if pet.Name == name then
			table.insert(t, pet)
		end
	end
	return t
end

local function equipPet(petName, amount)
	local petsFolder = LocalPlayer:FindFirstChild("petsFolder")
	if not petsFolder then
		warn("petsFolder not found")
		return
	end

	local uniqueFolder = petsFolder:FindFirstChild("Unique")
	if not uniqueFolder then
		warn("Unique folder not found")
		return
	end

	local remote = getRemote()
	if not remote then
		warn("equipPetEvent not found")
		return
	end

	unequipAll(remote, petsFolder)
	task.wait(0.2)

	local petsToEquip = getPets(uniqueFolder, petName)

	for i = 1, math.min(amount, #petsToEquip) do
		remote:FireServer("equipPet", petsToEquip[i])
		task.wait(0.1)
	end
end

Killer:AddButton("Start Pack Spam", function()
	if running then
		return
	end
	running = true

	task.spawn(function()
		local petsFolder = LocalPlayer:FindFirstChild("petsFolder")
		if not petsFolder then
			warn("petsFolder not found")
			running = false
			return
		end

		local unique = petsFolder:FindFirstChild("Unique")
		if not unique then
			warn("Unique folder not found")
			running = false
			return
		end

		local remote = getRemote()
		if not remote then
			warn("equipPetEvent not found")
			running = false
			return
		end

		while running do
			-- ===== Mighty Monster =====
			unequipAll(remote, petsFolder)
			task.wait(0.1)

			local mighty = getPets(unique, "Mighty Monster")

			for i = 1, math.min(7, #mighty) do
				if not running then
					return
				end
				remote:FireServer("equipPet", mighty[i])
				task.wait(0.025)
			end

			task.wait(0.01)

			-- ===== Wild Wizard =====
			unequipAll(remote, petsFolder)
			task.wait(0.1)

			local wizard = getPets(unique, "Wild Wizard")

			-- Antes tenÃ­a math.min(0, #wizard), por eso nunca se equipaba
			-- ningÃºn Wild Wizard. Corregido a 8 (mismo tope que el resto).
			for i = 1, math.min(8, #wizard) do
				if not running then
					return
				end
				remote:FireServer("equipPet", wizard[i])
				task.wait(0.025)
			end

			task.wait(0.1)
		end
	end)
end)

Killer:AddButton("Stop Pack Spam", function()
	running = false
	print("[PackSpam]: Stopped")
end)

-- MAKE SURE Killer TAB EXISTS BEFORE THIS
if Killer then
	Killer:AddButton("Equip Wild Wizard", function()
		equipPet("Wild Wizard", 8)
	end)

	Killer:AddButton("Equip Mighty Monster", function()
		equipPet("Mighty Monster", 8)
	end)
else
	warn("Killer tab is nil")
end
local infoTab = window:AddTab("info")
infoTab:AddLabel("hecho por karma").TextSize = 20
infoTab:AddLabel("op script").TextSize = 20
infoTab:AddLabel("epic").TextSize = 20

infoTab:AddButton("Copy Invite", function()
    local link = "https://discord.gg/v5nw66wcEQ"

    if setclipboard then
        setclipboard(link)

        game.StarterGui:SetCore("SendNotification", {
            Title = "Link Copied!";
            Text = "You can continue to Discord now.";
            Duration = 3;
        })

    else
        game.StarterGui:SetCore("SendNotification", {
            Title = "Error!";
            Text = "Not Supported.";
            Duration = 3;
        })
    end
end)
end

Crearpets()
CrearRock()
Crearextra()
