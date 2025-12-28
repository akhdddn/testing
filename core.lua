-- ReplicatedStorage/ForgeCore (ModuleScript)
-- OPT+ : non-b... (original header preserved)

local M = {}

function M.Start(Settings, DATA)
	-- ============================
	-- Services
	-- ============================
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local LP = Players.LocalPlayer

	-- ============================
	-- Debug helper
	-- ============================
	local function D(tag, ...)
		if Settings and Settings.Debug then
			print(("[ForgeCore:%s]"):format(tag), ...)
		end
	end

	-- ============================
	-- Anti double load
	-- ============================
	if _G.__ForgeCoreLoaded_OPT then
		warn("[!] ForgeCore OPT+ already loaded, aborting duplicate load.")
		return
	end
	_G.__ForgeCoreLoaded_OPT = true

	-- ============================
	-- Character helpers
	-- ============================
	local function GetChar()
		local c = LP.Character
		if c and c.Parent then
			return c
		end
		return nil
	end

	local function GetHumanoid()
		local c = GetChar()
		if not c then return nil end
		local h = c:FindFirstChildOfClass("Humanoid")
		if h and h.Parent then
			return h
		end
		return nil
	end

	local function GetCharAndRoot()
		local c = GetChar()
		if not c then return nil, nil end
		local r = c:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") and r.Parent then
			return c, r
		end
		return c, nil
	end

	-- ============================
	-- Noclip system (cached)
	-- ============================
	local noclipOn = false
	local noclipConn = nil
	local charDescConn = nil

	local partsSet = {}
	local originalCollide = {}

	local function cacheCharacterParts(c)
		partsSet = {}
		originalCollide = {}
		if not c then return end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				partsSet[d] = true
				originalCollide[d] = d.CanCollide
			end
		end
	end

	local function enableNoclip()
		if noclipOn then return end
		noclipOn = true

		local c = GetChar()
		if c then
			cacheCharacterParts(c)
		end

		if charDescConn then charDescConn:Disconnect() end
		if c then
			charDescConn = c.DescendantAdded:Connect(function(inst)
				if inst:IsA("BasePart") then
					partsSet[inst] = true
					if originalCollide[inst] == nil then
						originalCollide[inst] = inst.CanCollide
					end
					inst.CanCollide = false
				end
			end)
		end

		if noclipConn then noclipConn:Disconnect() end

		-- Prefer PreSimulation for physics-safe collision overrides
		if RunService.PreSimulation then
			noclipConn = RunService.PreSimulation:Connect(function()
				if not noclipOn then return end
				for p in pairs(partsSet) do
					if p and p.Parent then
						p.CanCollide = false
					else
						partsSet[p] = nil
						originalCollide[p] = nil
					end
				end
			end)
		else
			noclipConn = RunService.Stepped:Connect(function()
				if not noclipOn then return end
				for p in pairs(partsSet) do
					if p and p.Parent then
						p.CanCollide = false
					else
						partsSet[p] = nil
						originalCollide[p] = nil
					end
				end
			end)
		end
	end

	local function disableNoclip()
		if not noclipOn then return end
		noclipOn = false
		if noclipConn then noclipConn:Disconnect() end
		noclipConn = nil
		if charDescConn then charDescConn:Disconnect() end
		charDescConn = nil

		for p in pairs(partsSet) do
			if p and p.Parent then
				local orig = originalCollide[p]
				if orig ~= nil then
					p.CanCollide = orig
				end
			end
		end
		partsSet = {}
		originalCollide = {}
	end

	LP.CharacterAdded:Connect(function(newChar)
		disableNoclip()
		task.wait(0.1)
		cacheCharacterParts(newChar)
	end)

	-- ============================
	-- Ultra-light camera stabilize (optional)
	-- ============================
	local camRunning = false
	local camOutCF = nil
	local CAMERA_BIND_NAME = "ForgeCamStabilize"

	local function smoothAlpha(dt, smoothTime)
		smoothTime = math.max(1e-4, smoothTime or 0.12)
		return 1 - math.exp(-dt / smoothTime)
	end

	local function StartCameraStabilize()
		if not Settings.CameraStabilize then
			return
		end
		if camRunning then return end
		camRunning = true

		local cam = Workspace.CurrentCamera
		if not cam then return end
		camOutCF = cam.CFrame

		RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
			if not camRunning then return end
			local c = Workspace.CurrentCamera
			if not c then return end

			local target = c.CFrame
			if not camOutCF then camOutCF = target end

			local snapDist = tonumber(Settings.CameraSnapDist) or 4.0
			if (camOutCF.Position - target.Position).Magnitude > snapDist then
				camOutCF = target
			else
				local a = smoothAlpha(dt, tonumber(Settings.CameraSmoothTime) or 0.12)
				camOutCF = camOutCF:Lerp(target, a)
			end

			c.CFrame = camOutCF
		end)
	end

	local function StopCameraStabilize()
		camRunning = false
		pcall(function()
			RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
		end)
		camOutCF = nil
	end

	-- ============================
	-- Body Aim (Pitch Up/Down) while mining (no yaw changes)
	-- ============================
	local aimConn = nil
	local aimChar = nil
	local aimNeck = nil
	local aimWaist = nil
	local aimNeckC0 = nil
	local aimWaistC0 = nil
	local aimPitch = 0

	local function FindMotor6DByName(char: Model, motorName: string)
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") and d.Name == motorName then
				return d
			end
		end
		return nil
	end

	local function ResetBodyAim()
		if aimNeck and aimNeck.Parent and aimNeckC0 then
			aimNeck.C0 = aimNeckC0
		end
		if aimWaist and aimWaist.Parent and aimWaistC0 then
			aimWaist.C0 = aimWaistC0
		end
		aimChar, aimNeck, aimWaist = nil, nil, nil
		aimNeckC0, aimWaistC0 = nil, nil
		aimPitch = 0
	end

	local function StopBodyAim()
		if aimConn then
			aimConn:Disconnect()
		end
		aimConn = nil
		ResetBodyAim()
	end

	local function ComputePitchToTarget(rootPart: BasePart, targetPos: Vector3)
		local dir = (targetPos - rootPart.Position)
		if dir.Magnitude < 1e-3 then
			return 0
		end
		local localDir = rootPart.CFrame:VectorToObjectSpace(dir.Unit)

		-- localDir.Z biasanya negatif jika target di depan root
		local forward = math.max(1e-3, -localDir.Z)
		local pitch = math.atan2(localDir.Y, forward)
		return pitch
	end

	local function StartBodyAim(getRootAndTargetFn)
		-- Default ON kecuali explicitly dimatikan
		if Settings.BodyAimWhileMining == false then
			return
		end

		StopBodyAim()

		aimConn = RunService.RenderStepped:Connect(function(dt)
			local char, root, targetPart = getRootAndTargetFn()
			if not (char and root and targetPart and targetPart.Parent) then
				return
			end

			-- (Re)bind motors jika character berubah
			if aimChar ~= char then
				ResetBodyAim()
				aimChar = char
				aimNeck = FindMotor6DByName(char, "Neck")
				aimWaist = FindMotor6DByName(char, "Waist")
				if aimNeck then aimNeckC0 = aimNeck.C0 end
				if aimWaist then aimWaistC0 = aimWaist.C0 end
			end

			local maxDeg = tonumber(Settings.BodyAimMaxPitchDeg) or 35
			local maxPitch = math.rad(maxDeg)
			local smoothTime = tonumber(Settings.BodyAimSmoothTime) or 0.08
			local alpha = 1 - math.exp(-dt / math.max(1e-4, smoothTime))

			local desired = ComputePitchToTarget(root, targetPart.Position)
			if desired > maxPitch then desired = maxPitch end
			if desired < -maxPitch then desired = -maxPitch end

			aimPitch = aimPitch + (desired - aimPitch) * alpha

			-- Apply pitch split: mostly neck, sedikit waist (lebih natural)
			if aimNeck and aimNeck.Parent and aimNeckC0 then
				aimNeck.C0 = aimNeckC0 * CFrame.Angles(aimPitch * 0.75, 0, 0)
			end
			if aimWaist and aimWaist.Parent and aimWaistC0 then
				aimWaist.C0 = aimWaistC0 * CFrame.Angles(aimPitch * 0.25, 0, 0)
			end
		end)
	end

	-- ============================
	-- Tool remote resolve + throttled hit
	-- ============================
	local toolRF = nil
	local lastResolve = 0
	local RESOLVE_COOLDOWN = 2.0

	local function ResolveToolActivated()
		if toolRF and toolRF.Parent then
			return toolRF
		end

		local now = os.clock()
		if (now - lastResolve) < RESOLVE_COOLDOWN then
			return nil
		end
		lastResolve = now

		local ok, rf = pcall(function()
			local shared = ReplicatedStorage:WaitForChild("Shared", 2)
			if not shared then return nil end
			local packages = shared:WaitForChild("Packages", 2)
			if not packages then return nil end
			local knit = packages:WaitForChild("Knit", 2)
			if not knit then return nil end
			local services = knit:WaitForChild("Services", 2)
			if not services then return nil end
			local toolService = services:WaitForChild("ToolService", 2)
			if not toolService then return nil end
			local rfFolder = toolService:WaitForChild("RF", 2)
			if not rfFolder then return nil end
			return rfFolder:WaitForChild("ToolActivated", 2)
		end)

		if ok and rf then
			toolRF = rf
			return toolRF
		end

		return nil
	end

	local lastHit = 0
	local function HitPickaxe()
		local now = os.clock()
		local interval = tonumber(Settings.HitInterval) or 0.12
		if (now - lastHit) < interval then
			return
		end
		lastHit = now

		local rf = ResolveToolActivated()
		if not rf then return end

		pcall(function()
			rf:InvokeServer("Pickaxe")
		end)
	end

	-- ============================
	-- Rock Index
	-- ============================
	local RockIndex = {
		entries = {},
		byModel = {},
	}

	local function IsRockModel(m)
		if not (m and m:IsA("Model")) then return false end
		local h = m:GetAttribute("Health")
		local mh = m:GetAttribute("MaxHealth")
		if type(h) == "number" and type(mh) == "number" then
			return true
		end
		return false
	end

	local function PickTargetPartFromRockModel(m)
		if not m then return nil end
		if m.PrimaryPart and m.PrimaryPart:IsA("BasePart") then
			return m.PrimaryPart
		end
		local hb = m:FindFirstChild("Hitbox")
		if hb and hb:IsA("BasePart") then
			return hb
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				return d
			end
		end
		return nil
	end

	local function GetOreTypes(m)
		local oreSet = {}
		if not m then return {} end

		local attrOre = m:GetAttribute("Ore")
		if type(attrOre) == "string" and attrOre ~= "" then
			oreSet[attrOre] = true
		end

		for _, d in ipairs(m:GetDescendants()) do
			if d.Name == "Ore" then
				if d:IsA("StringValue") then
					if d.Value and d.Value ~= "" then
						oreSet[d.Value] = true
					end
				else
					local a = d:GetAttribute("Ore")
					if type(a) == "string" and a ~= "" then
						oreSet[a] = true
					end
				end
			end
		end

		local list = {}
		for k in pairs(oreSet) do
			table.insert(list, k)
		end
		table.sort(list)
		return list
	end

	local function boolCount(tbl)
		if type(tbl) ~= "table" then return 0, false end
		local n = 0
		for _, v in pairs(tbl) do
			if v == true then n += 1 end
		end
		return n, n > 0
	end

	local function UpsertRockModel(zoneName, model)
		if RockIndex.byModel[model] then
			-- refresh cached pieces
			local e = RockIndex.byModel[model]
			e.part = PickTargetPartFromRockModel(model)
			return
		end

		local e = {
			zoneName = zoneName,
			model = model,
			part = PickTargetPartFromRockModel(model),
			oreTypes = {},
			oreRefreshScheduled = false,
			conns = {},
		}
		RockIndex.byModel[model] = e
		table.insert(RockIndex.entries, e)

		local function scheduleOreRefresh()
			if e.oreRefreshScheduled then return end
			e.oreRefreshScheduled = true
			task.delay(0.05, function()
				e.oreRefreshScheduled = false
				if e.model and e.model.Parent then
					e.oreTypes = GetOreTypes(e.model)
				end
			end)
		end

		table.insert(e.conns, model.AttributeChanged:Connect(function(attr)
			if attr == "Ore" then
				scheduleOreRefresh()
			end
		end))

		table.insert(e.conns, model.DescendantAdded:Connect(function(d)
			if d.Name == "Ore" then
				scheduleOreRefresh()
			end
		end))

		table.insert(e.conns, model.DescendantRemoving:Connect(function(d)
			if d.Name == "Ore" then
				scheduleOreRefresh()
			end
		end))

		table.insert(e.conns, model.ChildAdded:Connect(function(ch)
			if ch.Name == "Ore" then
				scheduleOreRefresh()
			end
		end))

		table.insert(e.conns, model.ChildRemoved:Connect(function(ch)
			if ch.Name == "Ore" then
				scheduleOreRefresh()
			end
		end))

		-- init
		e.oreTypes = GetOreTypes(model)
	end

	local function RemoveRockModel(model)
		local e = RockIndex.byModel[model]
		if not e then return end
		RockIndex.byModel[model] = nil

		for i = #RockIndex.entries, 1, -1 do
			if RockIndex.entries[i].model == model then
				table.remove(RockIndex.entries, i)
				break
			end
		end

		for _, c in ipairs(e.conns) do
			pcall(function() c:Disconnect() end)
		end
	end

	local function InitRockIndex()
		local rocksFolder = Workspace:FindFirstChild("Rocks")
		if not rocksFolder then
			return nil
		end

		for _, zone in ipairs(rocksFolder:GetChildren()) do
			if zone:IsA("Folder") or zone:IsA("Model") then
				for _, ch in ipairs(zone:GetChildren()) do
					if IsRockModel(ch) then
						UpsertRockModel(zone.Name, ch)
					end
				end
			end
		end

		rocksFolder.DescendantAdded:Connect(function(inst)
			if inst:IsA("Model") and IsRockModel(inst) then
				local zone = inst.Parent
				local zoneName = zone and zone.Name or "Unknown"
				UpsertRockModel(zoneName, inst)
			end
		end)

		rocksFolder.DescendantRemoving:Connect(function(inst)
			if inst:IsA("Model") then
				RemoveRockModel(inst)
			end
		end)

		rocksFolder.ChildAdded:Connect(function(zone)
			if zone:IsA("Folder") or zone:IsA("Model") then
				for _, ch in ipairs(zone:GetChildren()) do
					if IsRockModel(ch) then
						UpsertRockModel(zone.Name, ch)
					end
				end
			end
		end)

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
		StopBodyAim()

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

		lockRoot = nil
		lockHum = nil
		lockCFrame = nil
		currentLockMode = nil
		prevPlatformStand, prevAutoRotate, prevAnchored = nil, nil, nil
		prevWalkSpeed, prevJumpPower = nil, nil
	end

	local function UpdateConstraintTarget(cf)
		if lockTargetPart and lockTargetPart.Parent then
			local smoothAlphaVal = tonumber(Settings.LockSmoothAlpha) or 1.0
			if smoothAlphaVal >= 1 then
				lockTargetPart.CFrame = cf
			else
				lockTargetPart.CFrame = lockTargetPart.CFrame:Lerp(cf, smoothAlphaVal)
			end
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

		lockRoot = rootPart
		lockCFrame = cf
		currentLockMode = desiredMode

		local h = GetHumanoid()
		lockHum = h

		if lockHum and lockHum.Parent then
			prevPlatformStand = lockHum.PlatformStand
			prevAutoRotate = lockHum.AutoRotate
			prevWalkSpeed = lockHum.WalkSpeed
			prevJumpPower = lockHum.JumpPower
		end

		if lockRoot and lockRoot.Parent then
			prevAnchored = lockRoot.Anchored
		end

		if desiredMode == "Hard" then
			if lockHum and lockHum.Parent then
				lockHum.AutoRotate = false
				lockHum.PlatformStand = true
			end
			if Settings.AnchorDuringLock and lockRoot and lockRoot.Parent then
				lockRoot.Anchored = true
			end

			if lockConn then lockConn:Disconnect() end
			lockConn = RunService.PreSimulation:Connect(function()
				if not (lockRoot and lockRoot.Parent) then return end
				if not lockCFrame then return end
				lockRoot.CFrame = lockCFrame
				if Settings.ZeroVelocityWhileLocked then
					lockRoot.AssemblyLinearVelocity = Vector3.new()
					lockRoot.AssemblyAngularVelocity = Vector3.new()
				end
			end)

		else
			-- Constraint mode
			if lockHum and lockHum.Parent then
				lockHum.AutoRotate = false
				lockHum.WalkSpeed = 0
				lockHum.JumpPower = 0
				lockHum.PlatformStand = false
			end

			lockTargetPart = Instance.new("Part")
			lockTargetPart.Name = "Forge_LockTarget"
			lockTargetPart.Size = Vector3.new(0.25, 0.25, 0.25)
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
			alignPos.Responsiveness = tonumber(Settings.AlignResponsiveness) or 200
			alignPos.MaxForce = tonumber(Settings.AlignMaxForce) or 200000
			alignPos.Parent = lockRoot

			alignOri = Instance.new("AlignOrientation")
			alignOri.Name = "Forge_AlignOri"
			alignOri.Attachment0 = rootAtt
			alignOri.Attachment1 = targetAtt
			alignOri.RigidityEnabled = true
			alignOri.Responsiveness = tonumber(Settings.AlignResponsiveness) or 200
			alignOri.MaxTorque = tonumber(Settings.AlignMaxTorque) or 200000
			alignOri.Parent = lockRoot

			if lockConn then lockConn:Disconnect() end
			lockConn = RunService.PreSimulation:Connect(function()
				if not (lockRoot and lockRoot.Parent) then return end
				if not lockCFrame then return end
				UpdateConstraintTarget(lockCFrame)
				if Settings.ZeroVelocityWhileLocked then
					lockRoot.AssemblyLinearVelocity = Vector3.new()
					lockRoot.AssemblyAngularVelocity = Vector3.new()
				end
			end)
		end
	end

	-- ============================
	-- Ownership / ore filter
	-- ============================
	local function GetLastHitOwner(model)
		if not model then return nil end
		local a1 = model:GetAttribute("LastHitPlayer")
		if a1 ~= nil then return a1 end
		local a2 = model:GetAttribute("LastHitUserId")
		if a2 ~= nil then return a2 end
		local a3 = model:GetAttribute("Owner")
		if a3 ~= nil then return a3 end
		return nil
	end

	local function IsOwnerMe(owner)
		if owner == nil then return false end
		if typeof(owner) == "Instance" and owner:IsA("Player") then
			return owner == LP
		end
		if type(owner) == "number" then
			return owner == LP.UserId
		end
		if type(owner) == "string" then
			return owner == tostring(LP.UserId) or owner == LP.Name
		end
		return false
	end

	local function RockIsAllowed(model)
		if Settings.RespectLastHitPlayer == false then
			return true
		end
		local owner = GetLastHitOwner(model)
		if owner == nil or owner == 0 or owner == "" then
			return true
		end
		if IsOwnerMe(owner) then
			return true
		end
		return false
	end

	local function RockMatchesOreSelection(model, oreTypes)
		local anyOreSelected = select(2, boolCount(Settings.Ores))
		if not anyOreSelected then
			return Settings.AllowAllOresIfNoneSelected == true
		end
		if Settings.RequireOreMatchWhenSelected == false then
			return true
		end

		-- if unknown ores (empty) allow above reveal threshold
		if not oreTypes or #oreTypes == 0 then
			if Settings.AllowUnknownOreAboveReveal then
				local h = model:GetAttribute("Health")
				local mh = model:GetAttribute("MaxHealth")
				if type(h) == "number" and type(mh) == "number" and mh > 0 then
					local pct = h / mh
					local thr = tonumber(Settings.OreRevealThreshold) or 0.75
					return pct > thr
				end
			end
			return false
		end

		for _, ore in ipairs(oreTypes) do
			if Settings.Ores[ore] == true then
				return true
			end
		end
		return false
	end

	-- ============================
	-- Target selection
	-- ============================
	local function GetBestTargetPart()
		local c, r = GetCharAndRoot()
		if not (c and r) then return nil end

		local zonesCount, zonesAny = boolCount(Settings.Zones)
		local rocksCount, rocksAny = boolCount(Settings.Rocks)
		local anyOreSelected = select(1, boolCount(Settings.Ores))

		local allowAllZones = (Settings.AllowAllZonesIfNoneSelected == true) and (not zonesAny)
		local allowAllRocks = (Settings.AllowAllRocksIfNoneSelected == true) and (not rocksAny)

		local myPos = r.Position
		local closestPart, minDist2 = nil, math.huge

		for _, e in ipairs(RockIndex.entries) do
			local model = e.model
			if model and model.Parent then
				if allowAllZones or Settings.Zones[e.zoneName] == true then
					if allowAllRocks or Settings.Rocks[model.Name] == true then
						if RockIsAllowed(model) then
							if RockMatchesOreSelection(model, e.oreTypes) then
								local hp = model:GetAttribute("Health")
								if type(hp) == "number" and hp > 0 then
									local p = e.part
									if p and p.Parent then
										local d = (p.Position - myPos)
										local d2 = d:Dot(d)
										if d2 < minDist2 then
											minDist2 = d2
											closestPart = p
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

	-- ============================
	-- Movement (Tween->lockCF) + arrived gating
	-- ============================
	local lockedTarget = nil
	local currentTargetPart = nil

	local activeTween = nil
	local lastTweenSpeedUsed = nil
	local lastGoalPos = nil
	local tweenToken = 0
	local pendingLockCF = nil
	local pendingLockTargetPart = nil

	local function CancelTween()
		if activeTween then
			pcall(function() activeTween:Cancel() end)
		end
		activeTween = nil
		pendingLockCF = nil
		pendingLockTargetPart = nil
	end

	local function MakeMiningLockCF(targetPart)
		local rockPos = targetPart.Position
		local yOff = tonumber(Settings.YOffset) or 0
		local targetPos = rockPos + Vector3.new(0, yOff, 0)

		local lockCF = CFrame.new(targetPos)
		if Settings.FaceTargetWhileMining then
			-- yaw-only face (kept as original)
			local lookPos = Vector3.new(rockPos.X, targetPos.Y, rockPos.Z)
			if (lookPos - targetPos).Magnitude > 0.05 then
				lockCF = CFrame.lookAt(targetPos, lookPos)
			end
		end

		return targetPos, lockCF
	end

	local function ApplyLockedState(rootPart, lockCF, targetPart)
		StartLock(rootPart, lockCF)
		StartCameraStabilize()

		-- Body aim (pitch) ONLY while locked/mining
		StartBodyAim(function()
			local c, r = GetCharAndRoot()
			return c, r, targetPart
		end)

		if Settings.KeepNoclipWhileLocked then
			enableNoclip()
		else
			disableNoclip()
		end
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

		-- ARRIVED: lock + face target (via lockCF)
		if dist <= arriveDist then
			CancelTween()
			ApplyLockedState(r, lockCF, targetPart)
			return true
		end

		-- Moving: tween to lockCF (not position only)
		local speed = tonumber(Settings.MoveSpeed) or 80
		speed = math.max(1, speed)

		local sameGoal = (lastGoalPos ~= nil) and ((lastGoalPos - targetPos).Magnitude < 0.02)
		if activeTween and sameGoal and lastTweenSpeedUsed == speed and currentTargetPart == targetPart then
			return false
		end

		currentTargetPart = targetPart
		lastTweenSpeedUsed = speed
		lastGoalPos = targetPos

		-- stop lock/camera while moving
		StopCameraStabilize()
		StopLock()
		CancelTween()

		tweenToken += 1
		local myToken = tweenToken

		pendingLockCF = lockCF
		pendingLockTargetPart = targetPart

		enableNoclip()

		local duration = dist / speed
		activeTween = TweenService:Create(
			r,
			TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ CFrame = lockCF }
		)

		activeTween.Completed:Connect(function()
			if myToken ~= tweenToken then return end
			activeTween = nil

			local tp = pendingLockTargetPart
			local cf = pendingLockCF
			pendingLockTargetPart = nil
			pendingLockCF = nil

			if not (tp and tp.Parent) then return end
			local _, rr = GetCharAndRoot()
			if not (rr and rr.Parent and cf) then return end

			ApplyLockedState(rr, cf, tp)
		end)

		activeTween:Play()
		return false
	end

	-- ============================
	-- Cleanup
	-- ============================
	local function FullCleanup()
		currentTargetPart = nil
		lockedTarget = nil
		CancelTween()
		StopCameraStabilize()
		StopLock()
		disableNoclip()
		lastTweenSpeedUsed = nil
		lastGoalPos = nil
	end

	-- ============================
	-- Main loop
	-- ============================
	task.spawn(function()
		D("LOOP", "Main loop started (OPT+)")

		local lastScan = 0
		local wasActive = false
		local lockedUntil = 0

		while _G.FarmLoop ~= false do
			task.wait(0.03)

			if not Settings.AutoFarm then
				if wasActive then
					FullCleanup()
					wasActive = false
				end
				task.wait(0.15)
				continue
			end

			wasActive = true

			local c, r = GetCharAndRoot()
			if not (c and r) then
				FullCleanup()
				task.wait(0.25)
				continue
			end

			-- validate existing target
			if lockedTarget and lockedTarget.Parent then
				local model = lockedTarget:FindFirstAncestorOfClass("Model")
				if not (model and model.Parent and IsRockModel(model)) then
					lockedTarget = nil
				else
					local hp = model:GetAttribute("Health")
					if type(hp) ~= "number" or hp <= 0 then
						lockedTarget = nil
					else
						if not RockIsAllowed(model) then
							lockedTarget = nil
						else
							-- if strict ore match, re-check
							local e = RockIndex.byModel[model]
							if e and Settings.RequireOreMatchWhenSelected ~= false then
								if not RockMatchesOreSelection(model, e.oreTypes) then
									lockedTarget = nil
								end
							end
						end
					end
				end
			end

			-- scan for target
			local now = os.clock()
			local scanInterval = tonumber(Settings.ScanInterval) or 0.12
			local stickTime = tonumber(Settings.TargetStickTime) or 0.25

			local needScan = (now - lastScan) >= scanInterval and (not lockedTarget or now >= lockedUntil)
			if needScan then
				lastScan = now
				lockedTarget = GetBestTargetPart()
				lockedUntil = now + stickTime
			end

			if lockedTarget and lockedTarget.Parent then
				local arrived = EnsureAtPart(lockedTarget)
				if arrived then
					local model = lockedTarget:FindFirstAncestorOfClass("Model")
					if model and model.Parent then
						local hp = model:GetAttribute("Health")
						if type(hp) == "number" and hp > 0 then
							HitPickaxe()
						end
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

		FullCleanup()
	end)

	print("[✓] Forge Core OPT+ Loaded! (Tween->lockCF + HitOnlyWhenArrived + UltraLight Camera)")
end

return M
