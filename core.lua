-- ReplicatedStorage/ForgeCore (ModuleScript)
local M = {}

function M.Start(Settings, DATA)
	-- ========= SERVICES =========
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Player = Players.LocalPlayer
	local CAMERA_BIND_NAME = "Forge_CameraFollow_Optim"

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

	-- ========= CAMERA STABILIZER =========
	local camConn = nil
	local cam = Workspace.CurrentCamera
	local prevCamType = nil

	local function StopCameraStabilize()
		if camConn then camConn:Disconnect() end
		camConn = nil
		if cam and prevCamType then
			cam.CameraType = prevCamType
		end
		prevCamType = nil
	end

	local function StartCameraStabilize()
		if not Settings.CameraStabilize then
			StopCameraStabilize()
			return
		end
		if camConn then return end

		cam = Workspace.CurrentCamera
		if not cam then return end
		prevCamType = cam.CameraType
		cam.CameraType = Enum.CameraType.Scriptable

		local alpha = tonumber(Settings.CameraSmoothAlpha) or 1
		local offsetMode = Settings.CameraOffsetMode or "World"
		local offset = Settings.CameraOffset or Vector3.new(0, 10, 18)
		local lastCF = cam.CFrame

		camConn = RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
			local _, r = GetCharAndRoot()
			if not (r and r.Parent and cam) then return end

			local targetPos
			if offsetMode == "Relative" then
				targetPos = (r.CFrame * CFrame.new(offset)).Position
			else
				targetPos = r.Position + offset
			end

			local lookAt = r.Position
			local wanted = CFrame.lookAt(targetPos, lookAt)

			if alpha >= 1 then
				lastCF = wanted
			else
				lastCF = lastCF:Lerp(wanted, math.clamp(alpha, 0, 1))
			end
			cam.CFrame = lastCF
		end)
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

	-- ========= ROCK INDEX (CACHE + EVENTS) =========
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

	-- ========= LAST HIT PLAYER OWNERSHIP (SIMPLE CHECK) =========
	local function GetLastHitOwner(model)
		local v = model:GetAttribute("LastHitPlayer")
		if v == nil then v = model:GetAttribute("LastHitUserId") end
		if v == nil then v = model:GetAttribute("LastHitBy") end
		if v == nil then v = model:GetAttribute("LastHitter") end
		return v
	end

	local function RockIsUnowned(model)
		if Settings.RespectLastHitPlayer ~= true then
			return true
		end
		local owner = GetLastHitOwner(model)
		if owner == nil then return true end
		if owner == "" then return true end
		if owner == 0 then return true end
		return false
	end

	local function AnyOreSelected()
		return select(1, boolCount(Settings.Ores))
	end

	local function GetOreType(rockModel)
		for _, child in ipairs(rockModel:GetChildren()) do
			if child.Name == "Ore" then
				local oreType = child:GetAttribute("Ore")
				if oreType ~= nil then
					return oreType
				end
			end
		end
		return nil
	end

	local function RockMatchesOreSelection(rockModel, cachedOreType)
		local oresAny = AnyOreSelected()
		if (not oresAny) and (Settings.AllowAllOresIfNoneSelected == true) then
			return true
		end

		local oreType = cachedOreType
		if oreType == nil then oreType = GetOreType(rockModel) end

		if oreType == nil then
			if oresAny and Settings.AllowUnknownOreAboveReveal then
				local hpPct = GetHealthPct(rockModel)
				local thr = tonumber(Settings.OreRevealThreshold) or 50
				if hpPct ~= nil and hpPct > thr then
					return true
				end
			end
			return false
		end

		return Settings.Ores[oreType] == true
	end

	local function IsRockAliveEnough(rockModel)
		local hp = rockModel:GetAttribute("Health")
		if type(hp) == "number" then
			return hp > 0
		end
		return true
	end

	local function UpsertRock(rockModel, zoneName)
		if not rockModel then return end
		if RockIndex.byModel[rockModel] then
			local e = RockIndex.byModel[rockModel]
			e.zoneName = zoneName or e.zoneName
			return
		end

		local part = PickTargetPartFromRockModel(rockModel)
		local entry = {
			model = rockModel,
			zoneName = zoneName,
			part = part,
			oreType = GetOreType(rockModel),
		}
		table.insert(RockIndex.entries, entry)
		RockIndex.byModel[rockModel] = entry

		rockModel.ChildAdded:Connect(function(ch)
			if ch.Name == "Ore" then
				entry.oreType = GetOreType(rockModel)
			end
		end)
		rockModel.ChildRemoved:Connect(function(ch)
			if ch.Name == "Ore" then
				entry.oreType = GetOreType(rockModel)
			end
		end)
	end

	local function RemoveRock(rockModel)
		local entry = RockIndex.byModel[rockModel]
		if not entry then return end
		RockIndex.byModel[rockModel] = nil
		for i = #RockIndex.entries, 1, -1 do
			if RockIndex.entries[i].model == rockModel then
				table.remove(RockIndex.entries, i)
				break
			end
		end
	end

	local function InitRockIndex()
		local rocksFolder = Workspace:FindFirstChild("Rocks")
		if not rocksFolder then
			warn("[!] Workspace.Rocks not found.")
			return
		end

		local function scanZone(zoneFolder)
			for _, d in ipairs(zoneFolder:GetDescendants()) do
				if d:IsA("Model") and IsRockModel(d) then
					UpsertRock(d, zoneFolder.Name)
				end
			end
		end

		for _, zone in ipairs(rocksFolder:GetChildren()) do
			if zone:IsA("Folder") then
				scanZone(zone)
			end
		end

		rocksFolder.ChildAdded:Connect(function(ch)
			if ch:IsA("Folder") then
				scanZone(ch)
			end
		end)

		rocksFolder.DescendantAdded:Connect(function(inst)
			if inst:IsA("Model") and IsRockModel(inst) then
				local zoneFolder = inst:FindFirstAncestorOfClass("Folder")
				if zoneFolder and zoneFolder.Parent == rocksFolder then
					UpsertRock(inst, zoneFolder.Name)
				end
			end
		end)

		rocksFolder.DescendantRemoving:Connect(function(inst)
			if inst:IsA("Model") then
				RemoveRock(inst)
			end
		end)

		D("INDEX", "RockIndex initialized", #RockIndex.entries)
	end

	InitRockIndex()

	-- ========= LOCK SYSTEM (Hard/Constraint) =========
	local lockConn = nil
	local lockRoot = nil
	local lockCFrame = nil
	local lockHum = nil

	local prevPlatformStand = nil
	local prevAutoRotate = nil
	local prevAnchored = nil
	local prevWalkSpeed = nil
	local prevJumpPower = nil

	local lockTargetPart = nil
	local rootAtt = nil
	local targetAtt = nil
	local alignPos = nil
	local alignOri = nil

	local currentLockMode = nil

	local function DestroyConstraintLock()
		if alignPos then alignPos:Destroy() end
		if alignOri then alignOri:Destroy() end
		if rootAtt then rootAtt:Destroy() end
		if lockTargetPart then lockTargetPart:Destroy() end
		alignPos, alignOri, rootAtt, targetAtt, lockTargetPart = nil, nil, nil, nil, nil
	end

	local function StopLock()
		if lockConn then lockConn:Disconnect() end
		lockConn = nil
		lockCFrame = nil

		DestroyConstraintLock()

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
						if RockIsUnowned(model) then
							if RockMatchesOreSelection(model, e.oreType) then
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

	-- ========= MOVE =========
	local activeTween = nil
	local currentTargetPart = nil

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
		if not (targetPart and targetPart.Parent) then return false end
		local _, r = GetCharAndRoot()
		if not (r and r.Parent) then return false end

		local targetPos, lockCF = MakeMiningLockCF(targetPart)
		local desiredCF = CFrame.new(targetPos)

		local dist = (r.Position - targetPos).Magnitude
		local arriveDist = tonumber(Settings.ArriveDistance) or 2.25
		local retweenDist = tonumber(Settings.RetweenDistance) or 6

		if dist <= arriveDist then
			CancelTween()
			StartLock(r, lockCF)
			StartCameraStabilize()
			if Settings.KeepNoclipWhileLocked then enableNoclip() else disableNoclip() end
			return true
		end

		if dist < retweenDist and currentTargetPart == targetPart then
			StartLock(r, lockCF)
			StartCameraStabilize()
			if Settings.KeepNoclipWhileLocked then enableNoclip() end
			return true
		end

		enableNoclip()
		StopCameraStabilize()
		StopLock()
		CancelTween()

		local speed = math.max(1, tonumber(Settings.TweenSpeed) or 55)
		local duration = math.max(0.06, dist / speed)

		activeTween = TweenService:Create(
			r,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = desiredCF }
		)

		activeTween:Play()
		pcall(function() activeTween.Completed:Wait() end)
		activeTween = nil

		StartLock(r, lockCF)
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
				StopCameraStabilize()
				StopLock()
				disableNoclip()
				task.wait(0.15)
				continue
			end

			local _, r = GetCharAndRoot()
			if not r then
				currentTargetPart = nil
				lockedTarget = nil
				StopCameraStabilize()
				StopLock()
				disableNoclip()
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

					-- ownership re-check
					if (not targetInvalid) and (not RockIsUnowned(rockModel)) then
						targetInvalid = true
					end

					-- ore strict re-check (ore reveal aware)
					if (not targetInvalid) and Settings.RequireOreMatchWhenSelected and AnyOreSelected() then
						if not RockMatchesOreSelection(rockModel, GetOreType(rockModel)) then
							targetInvalid = true
						end
					end
				end
			end

			if targetInvalid then
				lockedTarget = nil
				currentTargetPart = nil
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

	print("[✓] Forge Core OPT Loaded! (split core/settings)")
end

return M
