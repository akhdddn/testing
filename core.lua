-- ReplicatedStorage/ForgeCore (ModuleScript)
-- FULL: TweenSpeed = studs/sec (always tween when moving) + MULTI-ORE FIX
-- + CAMERA FIX: player can still rotate/zoom camera while mining (uses Humanoid.CameraOffset, NOT Scriptable cam)
-- + PATCH (Solusi 2): CameraOffset di-lerp per frame untuk mengurangi kamera maju-mundur
--
-- Notes:
-- - CameraStabilize now means "apply CameraOffset while mining/locked" (camera remains Custom).
-- - CameraOffsetMode is not used anymore (kept for compatibility with settings; ignored).
-- - If your offset feels inverted, change CameraOffset Z to negative in ForgeSettings (e.g. Vector3.new(0,10,-18)).

local M = {}

function M.Start(Settings, DATA)
	-- ========= SERVICES =========
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Player = Players.LocalPlayer
	local CAMERA_BIND_NAME = "Forge_CameraFollow_Optim" -- kept for compatibility

	-- ========= DEBUG =========
	_G.ForgeDebug = (_G.ForgeDebug ~= nil) and _G.ForgeDebug or false
	local function D(tag, msg, extra)
		if not _G.ForgeDebug then return end
		local pfx = ("[ForgeDBG:%s] "):format(tag)
		if extra ~= nil then
			warn(pfx .. msg .. " | " .. tostring(extra))
		else
			warn(pfx .. msg)
		end
	end

	local function boolCount(map)
		if type(map) ~= "table" then
			return false, 0
		end
		local any, count = false, 0
		for _, v in pairs(map) do
			if v == true then
				any = true
				count += 1
			end
		end
		return any, count
	end

	-- ========= ANTI DOUBLE LOAD =========
	if _G.__ForgeCoreLoaded_OPT then
		warn("[!] Forge Core OPT already loaded.")
		return
	end
	_G.__ForgeCoreLoaded_OPT = true

	-- ========= CHARACTER UTILS =========
	local function GetChar()
		local c = Player.Character
		if not c or not c.Parent then return nil end
		return c
	end

	local function GetHumanoid()
		local c = GetChar()
		if not c then return nil end
		return c:FindFirstChildOfClass("Humanoid")
	end

	local function GetCharAndRoot()
		local c = GetChar()
		if not c then return nil, nil end
		local r = c:FindFirstChild("HumanoidRootPart")
		return c, r
	end

	-- ========= NOCLIP =========
	local noclipConn, descConn
	local partsSet = {}
	local originalCollide = {}

	local function cacheCharacterParts(c)
		table.clear(partsSet)
		table.clear(originalCollide)
		if not c then return end
		for _, inst in ipairs(c:GetDescendants()) do
			if inst:IsA("BasePart") then
				partsSet[inst] = true
				originalCollide[inst] = inst.CanCollide
			end
		end
	end

	local function enableNoclip()
		if noclipConn then return end

		local c = Player.Character
		cacheCharacterParts(c)

		if descConn then descConn:Disconnect() end
		if c then
			descConn = c.DescendantAdded:Connect(function(inst)
				if inst:IsA("BasePart") then
					partsSet[inst] = true
					if originalCollide[inst] == nil then
						originalCollide[inst] = inst.CanCollide
					end
					inst.CanCollide = false
				end
			end)
		end

		local stepSignal = RunService.PreSimulation or RunService.Stepped
		noclipConn = stepSignal:Connect(function()
			for part in pairs(partsSet) do
				if part and part.Parent then
					part.CanCollide = false
				else
					partsSet[part] = nil
					originalCollide[part] = nil
				end
			end
		end)
	end

	local function disableNoclip()
		if noclipConn then noclipConn:Disconnect() end
		if descConn then descConn:Disconnect() end
		noclipConn, descConn = nil, nil

		for part, old in pairs(originalCollide) do
			if part and part.Parent then
				part.CanCollide = old
			end
		end
		table.clear(partsSet)
		table.clear(originalCollide)
	end

	Player.CharacterAdded:Connect(function(c)
		task.wait(0.25)
		disableNoclip()
		cacheCharacterParts(c)
	end)

	-- ========= CAMERA (FIX: allow player control) =========
	-- Instead of Scriptable camera + forcing CFrame each frame (which locks mouse look),
	-- we apply Humanoid.CameraOffset while mining/locked, keeping CameraType.Custom.
	-- PATCH (Solusi 2): CameraOffset di-lerp per frame (RenderStep) supaya tidak memicu kamera maju-mundur.
	local prevCamType = nil
	local prevHumCamOffset = nil
	local cameraApplied = false
	local cameraRestoring = false
	local camOffsetGoal = nil

	local function bindCameraOffsetLerp()
		-- Pastikan tidak double-bind
		pcall(function()
			RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
		end)

		RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
			local hum = GetHumanoid()
			if not hum then
				-- Character/humanoid hilang, cleanup supaya tidak nyangkut
				pcall(function()
					RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
				end)
				camOffsetGoal = nil
				cameraApplied = false
				cameraRestoring = false
				prevHumCamOffset = nil
				prevCamType = nil
				return
			end

			if not camOffsetGoal then return end

			local alpha = Settings.CameraOffsetLerpAlpha
			if type(alpha) ~= "number" then alpha = 0.15 end
			alpha = math.clamp(alpha, 0, 1)

			hum.CameraOffset = hum.CameraOffset:Lerp(camOffsetGoal, alpha)

			-- Jika sedang restore: ketika sudah dekat goal, snap + unbind
			if cameraRestoring then
				local diff = (hum.CameraOffset - camOffsetGoal).Magnitude
				local eps = Settings.CameraOffsetRestoreEps
				if type(eps) ~= "number" then eps = 0.05 end

				if diff <= eps then
					hum.CameraOffset = camOffsetGoal
					pcall(function()
						RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
					end)

					camOffsetGoal = nil
					cameraRestoring = false
					cameraApplied = false
					prevHumCamOffset = nil
					prevCamType = nil
				end
			end
		end)
	end

	local function StopCameraStabilize()
		-- Jika tidak pernah apply, cukup unbind (jaga-jaga kompatibilitas)
		if not cameraApplied then
			pcall(function()
				RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
			end)
			camOffsetGoal = nil
			cameraRestoring = false
			return
		end

		-- Restore CameraType langsung
		local cam = Workspace.CurrentCamera
		if cam and prevCamType then
			cam.CameraType = prevCamType
		end

		-- Restore offset secara halus menuju offset sebelumnya
		camOffsetGoal = prevHumCamOffset or Vector3.zero
		cameraRestoring = true
		bindCameraOffsetLerp()
	end

	local function StartCameraStabilize()
		if not Settings.CameraStabilize then
			StopCameraStabilize()
			return
		end

		local cam = Workspace.CurrentCamera
		local hum = GetHumanoid()
		if not (cam and hum) then return end

		if not cameraApplied then
			prevCamType = cam.CameraType
			prevHumCamOffset = hum.CameraOffset
			cameraApplied = true
		end

		cameraRestoring = false
		cam.CameraType = Enum.CameraType.Custom

		-- Goal offset while mining/locked (dikejar dengan lerp)
		camOffsetGoal = Settings.CameraOffset or Vector3.new(0, 10, 18)
		bindCameraOffsetLerp()
	end

	-- ========= TOOL REMOTE =========
	local toolActivatedRF = nil
	local lastHit = 0

	local function ResolveToolActivated()
		if toolActivatedRF and toolActivatedRF.Parent then return toolActivatedRF end
		local ok, res = pcall(function()
			return ReplicatedStorage:WaitForChild("Shared", 5)
				:WaitForChild("Packages", 5)
				:WaitForChild("Knit", 5)
				:WaitForChild("Services", 5)
				:WaitForChild("ToolService", 5)
				:WaitForChild("RF", 5)
				:WaitForChild("ToolActivated", 5)
		end)
		if ok and res then
			toolActivatedRF = res
			D("REMOTE", "ToolActivated resolved")
		end
		return toolActivatedRF
	end

	local function HitPickaxe()
		local interval = tonumber(Settings.HitInterval) or 0.12
		local now = os.clock()
		if (now - lastHit) < interval then return end
		lastHit = now

		local rf = ResolveToolActivated()
		if not rf then return end
		pcall(function()
			rf:InvokeServer("Pickaxe")
		end)
	end

	-- ========= ROCK INDEX =========
	local RockIndex = { entries = {}, byModel = {} }

	local function IsRockModel(m)
		if not m or not m:IsA("Model") then return false end
		local hp = m:GetAttribute("Health")
		local mhp = m:GetAttribute("MaxHealth")
		return (hp ~= nil) and (mhp ~= nil)
	end

	local function PickTargetPartFromRockModel(m)
		if not m or not m.Parent then return nil end
		if m.PrimaryPart then return m.PrimaryPart end
		local hit = m:FindFirstChild("Hitbox", true)
		if hit and hit:IsA("BasePart") then return hit end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				return d
			end
		end
		return nil
	end

	local function GetHealthPct(rockModel)
		local hp = rockModel:GetAttribute("Health")
		local maxHP = rockModel:GetAttribute("MaxHealth") or 100
		local curHP = hp or maxHP
		return (maxHP > 0) and ((curHP / maxHP) * 100) or 100
	end

	-- ========= LAST HIT OWNERSHIP =========
	local function GetLastHitOwner(model)
		local v = model:GetAttribute("LastHitPlayer")
		if v == nil then v = model:GetAttribute("LastHitUserId") end
		if v == nil then v = model:GetAttribute("LastHitBy") end
		if v == nil then v = model:GetAttribute("LastHitByUserId") end
		if v == nil then v = model:GetAttribute("LastHitter") end
		if v == nil then v = model:GetAttribute("OwnerUserId") end
		if v == nil then v = model:GetAttribute("Owner") end
		return v
	end

	local function IsOwnerMe(owner)
		if owner == nil then return false end
		if typeof(owner) == "Instance" and owner:IsA("Player") then
			return owner == Player
		end
		if type(owner) == "number" then
			return owner == Player.UserId
		end
		if type(owner) == "string" then
			local n = tonumber(owner)
			if n then return n == Player.UserId end
			local s = owner:lower()
			if Player.Name and s == Player.Name:lower() then return true end
			if Player.DisplayName and s == Player.DisplayName:lower() then return true end
		end
		return false
	end

	local function RockIsAllowed(model)
		if not Settings.RespectLastHitPlayer then
			return true
		end
		local owner = GetLastHitOwner(model)
		if owner == nil then return true end
		if type(owner) == "number" and owner == 0 then return true end
		if type(owner) == "string" and owner == "" then return true end
		if IsOwnerMe(owner) then return true end
		return false
	end

	-- ========= MULTI-ORE READER =========
	-- Returns array list: {"Iron","Crimsonite",...} (may be empty)
	local function GetOreTypes(rockModel)
		local set = {}

		for _, inst in ipairs(rockModel:GetDescendants()) do
			if inst.Name == "Ore" then
				if inst:IsA("StringValue") then
					local v = inst.Value
					if type(v) == "string" and v ~= "" then
						set[v] = true
					end
				elseif inst:IsA("Model") or inst:IsA("Folder") then
					local v = inst:GetAttribute("Ore")
					if type(v) == "string" and v ~= "" then
						set[v] = true
					end
				end
			end
		end

		local a = rockModel:GetAttribute("Ore")
		if type(a) == "string" and a ~= "" then
			set[a] = true
		end

		local list = {}
		for name in pairs(set) do
			table.insert(list, name)
		end
		table.sort(list)
		return list
	end

	local function AnyOreSelected()
		return select(1, boolCount(Settings.Ores))
	end

	local function RockMatchesOreSelection(rockModel, oreTypes)
		local anySelected = AnyOreSelected()

		if (not anySelected) and (Settings.AllowAllOresIfNoneSelected == true) then
			return true
		end

		if anySelected and (not Settings.RequireOreMatchWhenSelected) then
			return true
		end

		if not anySelected then
			return Settings.AllowAllOresIfNoneSelected == true
		end

		if type(oreTypes) ~= "table" or #oreTypes == 0 then
			if Settings.AllowUnknownOreAboveReveal then
				local pct = GetHealthPct(rockModel)
				local thr = tonumber(Settings.OreRevealThreshold) or 50
				return pct > thr
			end
			return false
		end

		for _, oreName in ipairs(oreTypes) do
			if Settings.Ores[oreName] == true then
				return true
			end
		end

		return false
	end

	local function IsRockAliveEnough(model)
		local hp = model:GetAttribute("Health")
		if hp == nil then return true end
		return hp > 0
	end

	-- Watchers to keep oreTypes cache updated
	local function disconnectOreConns(entry)
		if entry._oreConns then
			for _, c in ipairs(entry._oreConns) do
				if c and c.Connected then c:Disconnect() end
			end
		end
		entry._oreConns = {}
	end

	local function bindOreWatchers(rockModel, entry)
		disconnectOreConns(entry)

		-- fallback attribute on rockModel
		table.insert(entry._oreConns, rockModel:GetAttributeChangedSignal("Ore"):Connect(function()
			entry.oreTypes = GetOreTypes(rockModel)
		end))

		-- bind all current ore nodes
		for _, inst in ipairs(rockModel:GetDescendants()) do
			if inst.Name == "Ore" then
				if inst:IsA("Model") or inst:IsA("Folder") then
					table.insert(entry._oreConns, inst:GetAttributeChangedSignal("Ore"):Connect(function()
						entry.oreTypes = GetOreTypes(rockModel)
					end))
				elseif inst:IsA("StringValue") then
					table.insert(entry._oreConns, inst.Changed:Connect(function()
						entry.oreTypes = GetOreTypes(rockModel)
					end))
				end
			end
		end
	end

	local function UpsertRock(model, zoneName)
		if RockIndex.byModel[model] then
			local e = RockIndex.byModel[model]
			e.zoneName = zoneName or e.zoneName
			e.part = e.part and e.part.Parent and e.part or PickTargetPartFromRockModel(model)
			e.oreTypes = GetOreTypes(model)
			bindOreWatchers(model, e)
			return
		end

		local entry = {
			model = model,
			zoneName = zoneName or "UnknownZone",
			part = PickTargetPartFromRockModel(model),
			oreTypes = GetOreTypes(model),
			_oreConns = {},
		}

		RockIndex.byModel[model] = entry
		table.insert(RockIndex.entries, entry)

		-- children changes can add/remove ore nodes -> refresh & rebind
		model.ChildAdded:Connect(function()
			entry.oreTypes = GetOreTypes(model)
			bindOreWatchers(model, entry)
		end)
		model.ChildRemoved:Connect(function()
			entry.oreTypes = GetOreTypes(model)
			bindOreWatchers(model, entry)
		end)

		bindOreWatchers(model, entry)
	end

	local function RemoveRock(model)
		local e = RockIndex.byModel[model]
		if not e then return end
		disconnectOreConns(e)
		RockIndex.byModel[model] = nil
		for i = #RockIndex.entries, 1, -1 do
			if RockIndex.entries[i].model == model then
				table.remove(RockIndex.entries, i)
			end
		end
	end

	local function InitRockIndex()
		local rocksFolder = Workspace:FindFirstChild("Rocks")
		if not rocksFolder then
			D("INDEX", "Workspace.Rocks not found (will retry later)")
			return nil
		end

		for _, zone in ipairs(rocksFolder:GetChildren()) do
			if zone:IsA("Folder") or zone:IsA("Model") then
				for _, desc in ipairs(zone:GetDescendants()) do
					if IsRockModel(desc) then
						UpsertRock(desc, zone.Name)
					end
				end
			end
		end

		rocksFolder.ChildAdded:Connect(function(child)
			task.wait(0.1)
			if not child then return end
			if child:IsA("Folder") or child:IsA("Model") then
				for _, desc in ipairs(child:GetDescendants()) do
					if IsRockModel(desc) then
						UpsertRock(desc, child.Name)
					end
				end
			end
		end)

		rocksFolder.DescendantAdded:Connect(function(inst)
			if IsRockModel(inst) then
				local zone = inst:FindFirstAncestorWhichIsA("Folder") or inst:FindFirstAncestorWhichIsA("Model")
				local zn = zone and zone.Name or "UnknownZone"
				UpsertRock(inst, zn)
			end
		end)

		rocksFolder.DescendantRemoving:Connect(function(inst)
			if IsRockModel(inst) then
				RemoveRock(inst)
			end
		end)

		D("INDEX", "Rock index initialized", #RockIndex.entries)
		return rocksFolder
	end

	local rocksFolder = InitRockIndex()
	if not rocksFolder then
		task.spawn(function()
			while not rocksFolder do
				task.wait(1)
				rocksFolder = InitRockIndex()
			end
		end)
	end

	-- ========= LOCK (HARD / CONSTRAINT) =========
	local lockConn = nil
	local lockRoot = nil
	local lockHum = nil
	local lockCFrame = nil
	local currentLockMode = nil

	local prevPlatformStand, prevAutoRotate, prevAnchored
	local prevWalkSpeed, prevJumpPower

	local lockTargetPart = nil
	local rootAtt, targetAtt
	local alignPos, alignOri

	local function CleanupConstraintStuff()
		if alignPos then alignPos:Destroy() end
		if alignOri then alignOri:Destroy() end
		if rootAtt then rootAtt:Destroy() end
		if targetAtt then targetAtt:Destroy() end
		if lockTargetPart then lockTargetPart:Destroy() end
		alignPos, alignOri, rootAtt, targetAtt, lockTargetPart = nil, nil, nil, nil, nil
	end

	local function StopLock()
		if lockConn then lockConn:Disconnect() end
		lockConn = nil

		CleanupConstraintStuff()

		if lockRoot and lockRoot.Parent and prevAnchored ~= nil then
			lockRoot.Anchored = prevAnchored
		end

		if lockHum and lockHum.Parent then
			if prevPlatformStand ~= nil then lockHum.PlatformStand = prevPlatformStand end
			if prevAutoRotate ~= nil then lockHum.AutoRotate = prevAutoRotate end
			if prevWalkSpeed ~= nil then lockHum.WalkSpeed = prevWalkSpeed end
			if prevJumpPower ~= nil then lockHum.JumpPower = prevJumpPower end
		end

		lockRoot, lockHum = nil, nil
		prevPlatformStand, prevAutoRotate, prevAnchored = nil, nil, nil
		prevWalkSpeed, prevJumpPower = nil, nil
		currentLockMode = nil
	end

	local function StartConstraintLock(rootPart, cf)
		lockRoot = rootPart
		lockCFrame = cf
		lockHum = GetHumanoid()

		if lockHum then
			prevAutoRotate = lockHum.AutoRotate
			prevWalkSpeed = lockHum.WalkSpeed
			prevJumpPower = lockHum.JumpPower
			prevPlatformStand = lockHum.PlatformStand

			lockHum.PlatformStand = false
			lockHum.AutoRotate = false
			lockHum.WalkSpeed = 0
			lockHum.JumpPower = 0
		end

		if lockRoot then
			prevAnchored = lockRoot.Anchored
			lockRoot.Anchored = false
			lockRoot.AssemblyLinearVelocity = Vector3.zero
			lockRoot.AssemblyAngularVelocity = Vector3.zero
		end

		lockTargetPart = Instance.new("Part")
		lockTargetPart.Name = "Forge_LockTarget"
		lockTargetPart.Size = Vector3.new(0.2, 0.2, 0.2)
		lockTargetPart.Anchored = true
		lockTargetPart.CanCollide = false
		lockTargetPart.CanQuery = false
		lockTargetPart.CanTouch = false
		lockTargetPart.Transparency = 1
		lockTargetPart.CFrame = cf
		lockTargetPart.Parent = Workspace

		rootAtt = Instance.new("Attachment")
		rootAtt.Name = "Forge_RootAtt"
		rootAtt.Parent = lockRoot

		targetAtt = Instance.new("Attachment")
		targetAtt.Name = "Forge_TargetAtt"
		targetAtt.Parent = lockTargetPart

		alignPos = Instance.new("AlignPosition")
		alignPos.Name = "Forge_AlignPos"
		alignPos.Attachment0 = rootAtt
		alignPos.Attachment1 = targetAtt
		alignPos.RigidityEnabled = true
		alignPos.Responsiveness = tonumber(Settings.ConstraintResponsiveness) or 200
		alignPos.MaxForce = tonumber(Settings.ConstraintMaxForce) or 1e9
		alignPos.Parent = lockRoot

		alignOri = Instance.new("AlignOrientation")
		alignOri.Name = "Forge_AlignOri"
		alignOri.Attachment0 = rootAtt
		alignOri.Attachment1 = targetAtt
		alignOri.RigidityEnabled = true
		alignOri.Responsiveness = tonumber(Settings.ConstraintResponsiveness) or 200
		alignOri.MaxTorque = tonumber(Settings.ConstraintMaxForce) or 1e9
		alignOri.Parent = lockRoot

		if lockConn then lockConn:Disconnect() end
		if Settings.LockVelocityZero then
			local stepSignal = RunService.PreSimulation or RunService.Stepped
			lockConn = stepSignal:Connect(function()
				if lockRoot and lockRoot.Parent then
					lockRoot.AssemblyLinearVelocity = Vector3.zero
					lockRoot.AssemblyAngularVelocity = Vector3.zero
				end
			end)
		end
	end

	local function StartHardLock(rootPart, cf)
		lockRoot = rootPart
		lockCFrame = cf
		lockHum = GetHumanoid()

		if lockHum then
			prevPlatformStand = lockHum.PlatformStand
			prevAutoRotate = lockHum.AutoRotate
			lockHum.PlatformStand = true
			lockHum.AutoRotate = false
		end

		if lockRoot then
			prevAnchored = lockRoot.Anchored
			if Settings.AnchorDuringLock then
				lockRoot.Anchored = true
			end
		end

		if lockConn then lockConn:Disconnect() end
		local stepSignal = RunService.PreSimulation or RunService.Stepped
		lockConn = stepSignal:Connect(function()
			if not (lockRoot and lockRoot.Parent and lockCFrame) then return end
			lockRoot.CFrame = lockCFrame
			if Settings.LockVelocityZero then
				lockRoot.AssemblyLinearVelocity = Vector3.zero
				lockRoot.AssemblyAngularVelocity = Vector3.zero
			end
		end)
	end

	local function UpdateConstraintTarget(cf)
		if not (lockTargetPart and lockTargetPart.Parent) then return end
		local alpha = tonumber(Settings.LockSmoothAlpha) or 0.35
		if alpha >= 1 then
			lockTargetPart.CFrame = cf
		else
			lockTargetPart.CFrame = lockTargetPart.CFrame:Lerp(cf, math.clamp(alpha, 0, 1))
		end
	end

	local function StartLock(rootPart, cf)
		if not Settings.LockToTarget then
			StopLock()
			return
		end

		local desiredMode = (Settings.LockMode == "Hard") and "Hard" or "Constraint"

		if lockRoot == rootPart and lockRoot and lockRoot.Parent and currentLockMode == desiredMode then
			lockCFrame = cf
			if desiredMode == "Constraint" then
				UpdateConstraintTarget(cf)
			end
			return
		end

		StopLock()
		currentLockMode = desiredMode

		if desiredMode == "Hard" then
			StartHardLock(rootPart, cf)
		else
			StartConstraintLock(rootPart, cf)
		end
	end

	-- ========= TARGET SELECTION =========
	local function GetBestTargetPart()
		if not Settings.AutoFarm then return nil end
		local _, r = GetCharAndRoot()
		if not r then return nil end

		local zonesAny = select(1, boolCount(Settings.Zones))
		local rocksAny = select(1, boolCount(Settings.Rocks))

		local allowAllZones = (Settings.AllowAllZonesIfNoneSelected == true) and (not zonesAny)
		local allowAllRocks = (Settings.AllowAllRocksIfNoneSelected == true) and (not rocksAny)

		local myPos = r.Position
		local closestPart, minDist = nil, math.huge

		for _, e in ipairs(RockIndex.entries) do
			local model = e.model
			if model and model.Parent then
				if allowAllZones or Settings.Zones[e.zoneName] == true then
					if allowAllRocks or Settings.Rocks[model.Name] == true then
						if RockIsAllowed(model) then
							if RockMatchesOreSelection(model, e.oreTypes) then
								if IsRockAliveEnough(model) then
									local part = e.part
									if not (part and part.Parent) then
										part = PickTargetPartFromRockModel(model)
										e.part = part
									end
									if part and part.Parent then
										local d = (myPos - part.Position).Magnitude
										if d < minDist then
											minDist = d
											closestPart = part
										end
									end
								end
							end
						end
					end
				end
			end
		end

		return closestPart
	end

	-- ========= MOVE (TweenSpeed = studs/sec) =========
	local activeTween = nil
	local currentTargetPart = nil
	local lastTweenSpeedUsed = nil
	local lastGoalPos = nil

	local function CancelTween()
		if activeTween then
			pcall(function() activeTween:Cancel() end)
		end
		activeTween = nil
	end

	local function MakeMiningLockCF(targetPart)
		local rockPos = targetPart.Position
		local yOff = tonumber(Settings.YOffset) or 0
		local targetPos = rockPos + Vector3.new(0, yOff, 0)

		local lockCF = CFrame.new(targetPos)
		if Settings.FaceTargetWhileMining then
			local lookPos = Vector3.new(rockPos.X, targetPos.Y, rockPos.Z)
			if (lookPos - targetPos).Magnitude > 0.05 then
				lockCF = CFrame.lookAt(targetPos, lookPos)
			end
		end

		return targetPos, lockCF
	end

	local function EnsureAtPart(targetPart)
		if not (targetPart and targetPart.Parent) then
			CancelTween()
			currentTargetPart = nil
			lastTweenSpeedUsed = nil
			lastGoalPos = nil
			return false
		end

		local _, r = GetCharAndRoot()
		if not (r and r.Parent) then
			CancelTween()
			currentTargetPart = nil
			lastTweenSpeedUsed = nil
			lastGoalPos = nil
			return false
		end

		local targetPos, lockCF = MakeMiningLockCF(targetPart)

		local dist = (r.Position - targetPos).Magnitude
		local arriveDist = tonumber(Settings.ArriveDistance) or 2.25

		if dist <= arriveDist then
			CancelTween()
			currentTargetPart = targetPart
			lastGoalPos = targetPos
			lastTweenSpeedUsed = tonumber(Settings.TweenSpeed) or lastTweenSpeedUsed

			StartLock(r, lockCF)
			StartCameraStabilize()
			if Settings.KeepNoclipWhileLocked then enableNoclip() else disableNoclip() end
			return true
		end

		local speed = math.max(1, tonumber(Settings.TweenSpeed) or 55)
		local duration = math.max(0.06, dist / speed)

		local sameTarget = (currentTargetPart == targetPart)
		local sameSpeed = (lastTweenSpeedUsed == speed)
		local sameGoal = (lastGoalPos ~= nil) and ((lastGoalPos - targetPos).Magnitude < 0.05)

		if activeTween and sameTarget and sameSpeed and sameGoal then
			enableNoclip()
			return false
		end

		currentTargetPart = targetPart
		lastTweenSpeedUsed = speed
		lastGoalPos = targetPos

		enableNoclip()
		StopCameraStabilize()
		StopLock()
		CancelTween()

		activeTween = TweenService:Create(
			r,
			TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(targetPos) }
		)
		activeTween:Play()

		pcall(function() activeTween.Completed:Wait() end)
		activeTween = nil

		if not (targetPart and targetPart.Parent) then return false end
		local _, rr = GetCharAndRoot()
		if not (rr and rr.Parent) then return false end

		StartLock(rr, lockCF)
		StartCameraStabilize()
		if Settings.KeepNoclipWhileLocked then enableNoclip() else disableNoclip() end
		return true
	end

	-- ========= MAIN LOOP =========
	local lastScan = 0
	local lockedTarget = nil
	local lockedUntil = 0

	task.spawn(function()
		D("LOOP", "Main loop started (OPT)")

		while _G.FarmLoop ~= false do
			task.wait(0.03)

			if not Settings.AutoFarm then
				currentTargetPart = nil
				lockedTarget = nil
				CancelTween()
				StopCameraStabilize()
				StopLock()
				disableNoclip()
				lastTweenSpeedUsed = nil
				lastGoalPos = nil
				task.wait(0.15)
				continue
			end

			local _, r = GetCharAndRoot()
			if not r then
				currentTargetPart = nil
				lockedTarget = nil
				CancelTween()
				StopCameraStabilize()
				StopLock()
				disableNoclip()
				lastTweenSpeedUsed = nil
				lastGoalPos = nil
				task.wait(0.25)
				continue
			end

			local now = os.clock()

			local targetInvalid = (not lockedTarget) or (not lockedTarget.Parent)
			if not targetInvalid then
				local rockModel = lockedTarget:FindFirstAncestorOfClass("Model")
				if not rockModel or not rockModel.Parent then
					targetInvalid = true
				else
					local hp = rockModel:GetAttribute("Health")
					if hp and hp <= 0 then
						targetInvalid = true
					end
					if (not targetInvalid) and (not RockIsAllowed(rockModel)) then
						targetInvalid = true
					end
					if (not targetInvalid) and Settings.RequireOreMatchWhenSelected and AnyOreSelected() then
						if not RockMatchesOreSelection(rockModel, GetOreTypes(rockModel)) then
							targetInvalid = true
						end
					end
				end
			end

			if targetInvalid then
				lockedTarget = nil
				currentTargetPart = nil
				CancelTween()
				lastTweenSpeedUsed = nil
				lastGoalPos = nil
			end

			if lockedTarget and now < lockedUntil then
				-- stick
			else
				if (now - lastScan) >= (Settings.ScanInterval or 0.12) then
					lastScan = now
					lockedTarget = GetBestTargetPart()
					lockedUntil = now + (Settings.TargetStickTime or 0.25)
					currentTargetPart = lockedTarget
				end
			end

			if lockedTarget and lockedTarget.Parent then
				EnsureAtPart(lockedTarget)

				local rockModel = lockedTarget:FindFirstAncestorOfClass("Model")
				if rockModel then
					local hp = rockModel:GetAttribute("Health")
					if (not hp) or hp > 0 then
						HitPickaxe()
					end
				end
			else
				CancelTween()
				StopCameraStabilize()
				StopLock()
				disableNoclip()
				task.wait(0.08)
			end
		end

		CancelTween()
		StopCameraStabilize()
		StopLock()
		disableNoclip()
	end)

	print("[✓] Forge Core OPT Loaded! (TweenSpeed=studs/sec + Multi-Ore + Camera control fix)")
end

return M
