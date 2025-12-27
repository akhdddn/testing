-- ========= CAMERA (FIX: allow player control + stop forward/back bounce) =========
-- Strategy:
-- - Keep camera Custom (player can rotate/zoom normally)
-- - Use Humanoid.CameraOffset for shoulder/height ONLY (X,Y). Z is handled as fixed zoom distance.
-- - Lock zoom distance while mining to prevent camera in/out.
-- - Set occlusion to Invisicam to avoid camera collision pushing in/out.

local prevCamType = nil
local prevHumCamOffset = nil
local prevMinZoom, prevMaxZoom = nil, nil
local prevOcclusionMode = nil
local cameraApplied = false

local function StopCameraStabilize()
	-- In case older code bound RenderStep
	pcall(function()
		RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
	end)

	local cam = Workspace.CurrentCamera
	if cam and prevCamType then
		cam.CameraType = prevCamType
	end
	prevCamType = nil

	local hum = GetHumanoid()
	if hum and prevHumCamOffset then
		hum.CameraOffset = prevHumCamOffset
	end
	prevHumCamOffset = nil

	-- restore zoom distances
	if prevMinZoom ~= nil then
		pcall(function() Player.CameraMinZoomDistance = prevMinZoom end)
	end
	if prevMaxZoom ~= nil then
		pcall(function() Player.CameraMaxZoomDistance = prevMaxZoom end)
	end
	prevMinZoom, prevMaxZoom = nil, nil

	-- restore occlusion mode
	if prevOcclusionMode ~= nil then
		pcall(function() Player.DevCameraOcclusionMode = prevOcclusionMode end)
	end
	prevOcclusionMode = nil

	cameraApplied = false
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

		pcall(function()
			prevMinZoom = Player.CameraMinZoomDistance
			prevMaxZoom = Player.CameraMaxZoomDistance
		end)

		pcall(function()
			prevOcclusionMode = Player.DevCameraOcclusionMode
		end)

		cameraApplied = true
	end

	-- keep player control
	cam.CameraType = Enum.CameraType.Custom

	-- Interpret Settings.CameraOffset:
	-- X,Y => Humanoid.CameraOffset
	-- Z   => fixed zoom distance while mining
	local off = Settings.CameraOffset or Vector3.new(0, 10, 18)

	-- Apply only XY to CameraOffset (prevents weird depth bounce)
	hum.CameraOffset = Vector3.new(off.X, off.Y, 0)

	-- Lock zoom distance using abs(Z)
	local zoom = math.max(2, math.abs(off.Z))
	pcall(function()
		Player.CameraMinZoomDistance = zoom
		Player.CameraMaxZoomDistance = zoom
	end)

	-- Prevent camera collision from pushing in/out
	pcall(function()
		Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
	end)
end
