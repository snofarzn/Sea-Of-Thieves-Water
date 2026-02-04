-- Gerstnder Wave (Sea Of Thieves Waves)
-- By Kaiji, Kyi, aethersword, c6Fontaine, farzn


export type WaveInfo = {
	Direction: Vector3,
	WaveLength: number,
	Steepness: number,
	Gravity: number,

	WaveNumber: number,
	WaveSpeed: number,
	WaveAmplitude: number,
}

local PI = math.pi

local XZ_AXIS = Vector3.new(1, 0, 1)
local X_AXIS = Vector3.xAxis
local Y_AXIS = Vector3.yAxis
local Z_AXIS = Vector3.zAxis

local TwoPi = 2 * math.pi
local TWO_OVER_PI = 2 / math.pi

local acos = math.acos
local abs = math.abs

local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2

local v3new = Vector3.new
local v2new = Vector2.new
local v3zero = Vector3.zero
local v2zero = Vector2.zero

local clamp = math.clamp
local sign = math.sign
local rad = math.rad
local min = math.min

local GRID_INFO = {
	Padding = 0,
	Width = 0,
	Length = 0,
	PaddingMultiplier = 1,
	UV_SCALE = 1
}

--[[
	Lerps a number "a" to "b", and alpha "t", with a cosine easing style.
]]
local function CosineLerp(a: number, b: number, t: number): number
	local cosineT = (1 - cos(t * PI)) / 2  -- Cosine easing
	return a + (b - a) * cosineT
end

--[[
	Fetches the UV coordinates of an (x, z) point. Used for whirlpools.
]]
local function GetUVCoordinates(Vx: number, Vz: number): Vector2
	local Padding: number = GRID_INFO.Padding
	local Width: number = GRID_INFO.Width
	local Length: number = GRID_INFO.Length

	local x = ((Vx + ((Padding * (Width - 1) / 2))) / Padding) + 1
	local y = ((Vz + ((Padding * (Length - 1) / 2))) / Padding) + 1

	return v2new(x, y)
end

--[[
	Rotates a UV around a pivot point, given as a Vector2. Used for whirlpools.
]]
local function RotateUV(UV: Vector2, Angle: number, Center: Vector2): Vector2
	local cosA = cos(Angle)
	local sinA = sin(Angle)

	local x = cosA * (UV.X - Center.X) - sinA * (UV.Y - Center.Y) + Center.X
	local y = sinA * (UV.X - Center.X) + cosA * (UV.Y - Center.Y) + Center.Y

	return v2new(x, y)
end

local Gerstner = {}
local PaddingMultiplier = GRID_INFO.PaddingMultiplier
local UV_SCALE = GRID_INFO.UV_SCALE

function Gerstner:SET_SETTINGS(Padding: number, Width: number, Length: number, PaddingMulti: number, SCALE: number)
	GRID_INFO.Padding = Padding
	GRID_INFO.Width = Width
	GRID_INFO.Length = Length
	GRID_INFO.PaddingMultiplier = PaddingMulti

	PaddingMultiplier = PaddingMulti
	UV_SCALE = SCALE
end

--[[
	Constructs and returns a <strong>WaveInfo</strong> object.
	<strong>Direction:</strong> The direction of the wave, as a Vector3.
	<strong>WaveLength:</strong> The wave length of the wave, as a number.
	<strong>Steepness:</strong> The steepness (height) of the wave, as a number.
	<strong>Gravity:</strong> The gravity of the wave, as a number. Defaults to 9.8
]]
function Gerstner.new(Direction: Vector3, WaveLength: number, Steepness: number, Gravity: number?): WaveInfo
	local g = Gravity or 9.8

	local WaveNumber = TwoPi / WaveLength
	local WaveSpeed = sqrt(g / WaveNumber)
	local waveAmplitude = Steepness / WaveNumber

	return {
		Direction = Direction,
		WaveLength = WaveLength,
		Steepness = Steepness,
		Gravity = g,

		WaveNumber = WaveNumber,
		WaveSpeed = WaveSpeed,
		WaveAmplitude = waveAmplitude,
	}
end

--[[
	Computes all active waves for a specific Vector3 point and returns the new point.
	<strong>Waves:</strong> All the active waves given as a table.
	<strong>Position:</strong> The position of the vertex, as a Vector3.
	<strong>t:</strong> Time variable.
	<strong>phaseMulti:</strong> The phase multiplier for the wave, used for zone / island parameters.
	<strong>speedMulti:</strong> The speed multiplier for the wave, used for zone / island parameters.
	<strong>amplitudeMulti:</strong> The amplitude multiplier for the wave, used for zone / island parameters.
	
]]
function Gerstner.ComputeTransform( Waves: { WaveInfo }, Position: Vector3, t: number, phaseMulti: number?, speedMulti: number?, amplitudeMulti: number? ): Vector3
	local Transform = v3zero
	local phaseMulti = phaseMulti:: number or 1
	local speedMulti = speedMulti:: number or 1
	local amplitudeMulti = amplitudeMulti:: number or 1

	for i, Wave: WaveInfo in Waves do
		local waveNumber, waveSpeed, waveAmplitude = Wave.WaveNumber * phaseMulti, Wave.WaveSpeed * speedMulti, Wave.WaveAmplitude * amplitudeMulti
		Transform += Gerstner.ComputeWave(Position, t, waveNumber, waveSpeed, waveAmplitude, Wave.Direction)
	end

	return Transform
end

function Gerstner.ComputeWave(Position: Vector3, t: number, WaveNumber: number, WaveSpeed: number, WaveAmplitude: number, WaveDirection: Vector3): Vector3
	local Phase = WaveNumber * (WaveDirection:Dot(Position) - WaveSpeed * t)

	local cosf = cos(Phase)
	local sinf = sin(Phase)
	local Acosf = (WaveAmplitude * cosf)
	local X, Y, Z = WaveDirection.X * Acosf, WaveAmplitude * sinf, WaveDirection.Z * Acosf

	return v3new(X, Y, Z)
end 

--[[
	The same as Gerstner.ComputeTransform, but includes calculating the wave normals as well.
	Use this if you want to have accurate lighting reflections on the ocean.
]]
function Gerstner.ComputeTransformAndNormal( Waves: { WaveInfo }, Position: Vector3, t: number, phaseMulti: number?, speedMulti: number?, amplitudeMulti: number? ): (Vector3, Vector3)
	local Transform = v3zero
	local Tangent = X_AXIS
	local Binormal = Z_AXIS

	local phaseMulti = phaseMulti:: number or 1
	local speedMulti = speedMulti:: number or 1
	local amplitudeMulti = amplitudeMulti:: number or 1

	for i, Wave: WaveInfo in Waves do
		local waveNumber, waveSpeed, waveAmplitude = Wave.WaveNumber * phaseMulti, Wave.WaveSpeed * speedMulti, Wave.WaveAmplitude * amplitudeMulti
		local _transform, _tangent, _binormal = Gerstner.ComputeWaveAndNormals(Position, t, waveNumber, waveSpeed, waveAmplitude, Wave.Direction, Wave.Steepness)
		Transform += _transform

		Tangent += _tangent
		Binormal += _binormal
	end

	local Normal = Binormal:Cross(Tangent).Unit

	return Transform, Normal
end

function Gerstner.ComputeWaveAndNormals(Position: Vector3, t: number, WaveNumber: number, WaveSpeed: number, WaveAmplitude: number, WaveDirection: Vector3, Steepness: number): (Vector3, Vector3, Vector3)
	local Phase = WaveNumber * (WaveDirection:Dot(Position) - WaveSpeed * t)

	local cosf = cos(Phase)
	local sinf = sin(Phase)
	local Acosf = (WaveAmplitude * cosf)
	local X, Y, Z = WaveDirection.X * Acosf, WaveAmplitude * sinf, WaveDirection.Z * Acosf


	local dX, dZ = WaveDirection.X, WaveDirection.Z
	local SteepnessSinF = (Steepness * sinf)
	local SteepnessCosF = (Steepness * cosf)

	local Tangent = v3new(
		-dX * dX * SteepnessSinF,
		dX * SteepnessCosF,
		-dX * dZ * SteepnessSinF
	)
	local Binormal = v3new(
		-dX * dZ * SteepnessSinF,
		dZ * SteepnessCosF,
		-dZ * dZ * SteepnessSinF
	)
	return v3new(X, Y, Z), Tangent, Binormal
end 

--[[
	Returns a transformation / offset position, as well as a UV offset for whirlpools / vortices.
]]
function Gerstner.GetVortexTransform(VortexParams: any, VertexPosition: Vector3, BaseUV: Vector2?, t: number, PlanePosition: Vector3?): (Vector3, Vector2)
	local WhirlpoolCenter: Vector3 = VortexParams.Origin * XZ_AXIS
	local Radius: number = VortexParams.Radius

	local Displacement = (VertexPosition * XZ_AXIS) - WhirlpoolCenter
	local Distance = Displacement.Magnitude

	if Distance > Radius then
		return v3zero, v2zero
	end
	local FormationTime: number = VortexParams.FormationTime
	local SpawnedAt: number = VortexParams.SpawnedAt

	local Decay = 1
	local Despawn: boolean? = VortexParams.Despawn
	local Delta: number? = nil

	if Despawn == true then
		local DissolveTime: number = VortexParams.DissolveTime
		local FullyDecayAt: number = VortexParams.FullDecayAt

		if t > FullyDecayAt then
			-- return v3zero, v2zero
		end

		Delta = clamp(1 - ((FullyDecayAt - t) / DissolveTime), 0, 1)
		Decay = CosineLerp(1, 0, Delta:: number)
	end


	local Elapsed = t - SpawnedAt
	local ElapsedClamped = Elapsed >= FormationTime and 1 or CosineLerp(0, 1, min(Elapsed / FormationTime, 1))

	local DownwardForce: number = VortexParams.DownwardForce
	local TangentSpeed: number = VortexParams.TangentSpeed
	local RotSpeed: number = VortexParams.RotSpeed
	local Scale: number = VortexParams.Scale

	local DistanceFactor = (Distance / Radius)
	local DividedDistance = Distance / Scale
	local VelocityDistance = DistanceFactor * DistanceFactor

	local Falloff = clamp(1 - DistanceFactor, 0, 1)
	local FalloffSmooth = Falloff * Falloff * (3 - 2 * Falloff)

	-- // Calculate our main forces

	local DownwardForce = v3new(0, -DownwardForce / (DividedDistance + 1), 0) * FalloffSmooth * ElapsedClamped * Decay
	local TangentVelocity = Displacement:Cross(Y_AXIS).Unit * (TangentSpeed * VelocityDistance) * FalloffSmooth * ElapsedClamped * Decay

	-- // UV rotation: To simulate a spinning effect, the UV is rotated if we're in the whirlpool radius
	-- // This does create an issue where the UVs at the borders are distorted
	-- // 	Normally we'd avoid this by not rotating the actual UV at all, and instead having an 'overlay' texture 
	-- // 	and rotate that texture. However, ROBLOX doesn't have a stacking ability with PBR texture as far as I'm aware
	-- // 	and you'd need to use an EditableImage as well (assuming you want it to be directly layered over the ocean)

	local OffsetUV = v2zero
	if BaseUV ~= nil then
		local PlanePosition = PlanePosition:: Vector3
		local AngularSpeed = -sign(TangentSpeed) * RotSpeed 

		local VortexUV: Vector2 = VortexParams.UVCenter or GetUVCoordinates(WhirlpoolCenter.X - PlanePosition.X, WhirlpoolCenter.Z - PlanePosition.Z)
		VortexParams.UVCenter = VortexUV

		local angle = (rad(AngularSpeed * ElapsedClamped) * Elapsed) % TwoPi

		if Despawn == true then
			angle = CosineLerp(angle, TwoPi, Delta:: number)
		end
		local PM = 1 / UV_SCALE
		OffsetUV = (RotateUV(BaseUV * PM, angle, VortexUV) / PM) - BaseUV
	end

	return DownwardForce + TangentVelocity, OffsetUV
end

--[[
	Performs an approximation of the ocean height at a Vector3 position, at the cost of accuracy for speed.
]]
function Gerstner:GetApproximateHeight(Waves: { WaveInfo }, Position: Vector3, t: number, phaseMulti: number?, speedMulti: number?, amplitudeMulti: number?)
	local TransformY = 0
	local phaseMulti = phaseMulti:: number or 1
	local speedMulti = speedMulti:: number or 1
	local amplitudeMulti = amplitudeMulti:: number or 1

	for _, Wave: WaveInfo in Waves do
		local waveNumber, waveSpeed, waveAmplitude = Wave.WaveNumber * phaseMulti, Wave.WaveSpeed * speedMulti, Wave.WaveAmplitude * amplitudeMulti
		local wavePhase = waveNumber * (Wave.Direction:Dot(Position) - waveSpeed * t)
		local sin = sin(wavePhase)

		local Approximate = (1 - abs(TWO_OVER_PI * acos(sin)))

		TransformY += waveAmplitude * Approximate
	end

	return TransformY
end

return Gerstner


Setting Module
local GerstnerWave = require(script.Parent)


local Seed = script.Seed.Value
if Seed == 0 then
	Seed = math.random(-100000, 100000)
	print(`SEED: {Seed}`)
	script.Seed.Value = Seed
end
local R = Random.new(Seed)

-- // This is basically a function to generate random waves
local WLMultiplier, AmplitudeMultiplier = 1.14, 0.86
local function BrownianMotionWaves(Amount: number): { GerstnerWave.WaveInfo }
	local Results = {}
	local WaveLength, Amplitude = 40, 0.3

	local PrimaryDirectionUnit = workspace.GlobalWind.Unit

	for i = 1, Amount do
		if Amplitude <= 0.05 then
			warn('Stopped at ' .. i .. ' as amplitude reached threshold (0.025)')
			break
		end
		local RandomDirectionUnit = R:NextUnitVector()
		local Direction = i == 1 
			and PrimaryDirectionUnit 
			or (RandomDirectionUnit + PrimaryDirectionUnit).Unit

		local WaveInfo = GerstnerWave.new(Direction, WaveLength, Amplitude)
		table.insert(Results, WaveInfo)

		WaveLength *= WLMultiplier
		Amplitude *= AmplitudeMultiplier
	end
	print('Successfully generated '.. #Results .. ' waves!')
	return Results
end

return {
	DEBUG = true,
	GRID_SETTINGS = {
		CHUNK_SIZE = 100, 
		Padding = 48,
		PLANE_OFFSET = Vector3.new(0, 25, 0),
		Width = 40,
		Length = 40,

		PaddingMultiplier = 1,
		UV_SCALE = 2;
	},

	WORKER_COUNT = 6,
	FrustumRenderDistance = 900,
	LowRenderDistance = 200,
	MaxChunkRenderDistance = 800,

	Subdivisions = {
		[1] = 400,
		[2] = 200,
	},

	--Waves = BrownianMotionWaves(6);
	Waves = {
		-- // Start with base amplitude and wavelength, each wave iteration increases wavelength and decreases amplitude
		GerstnerWave.new(Vector3.new(0.6, 0, 0.05), 24, 0.6),
		GerstnerWave.new(Vector3.new(0.2, 0, 0.4), 28, 0.4),
		GerstnerWave.new(Vector3.new(0.15, 0, 0.1), 35, 0.35),
	},

	ISLAND_SPEED_MULTIPLIER = 1.1,
	ISLAND_PHASE_MULTIPLIER = 1,

	WAVE_COLORS = {
		CREST = Color3.fromRGB(77, 166, 156);
		TROUGH = Color3.fromRGB(46, 89, 118);
		VORTEX = Color3.fromRGB(18, 28, 33);
		SHORE = Color3.fromRGB(60, 186, 171)
	},
	UV_SCROLL_SPEED = 1/12,
	UV_SCROLL_DIRECTION = Vector2.new(1, 1),

	DEPTH_ENABLED = true, -- // Note: Check known issues #4 in thread linked below
	DEPTH_RAY_LENGTH = Vector3.new(0, -15, 0),
	DEPTH_RAY_OFFSET = Vector3.new(0, 5, 0),

	WHITECAP_HEIGHT = 6,
	SHORE_TRANSPARENCY = 0.2,

	-- // DEBUG
	-- // Known issues thread: https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293
	FRUSTUM_CULLING_FIX = true; -- // See known issues #7

}

setup module
--!strict
--[[
	@FlameEmber06
	Setup helper module in order to define the plane mesh, as well as subdivide and stitch vertices.
]]

local AssetService = game:GetService('AssetService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Types = require(script.Parent.Parent.Types)
local _settings = require(script.Parent.Parent.Settings)

local _QUADS: { [Vector3]: {} }? = {}
local _TRIANGLES: { [Vector3]: {} }? = {}
local VertexInfo: { Types.VertexKey } = {}


local Setup = {
	CurrentSubdivisions = 0,
	SETTINGS = {
		Padding = 0,
		Width = 0,
		Length = 0,
		UV_SCALE = 0,
		PLANE_OFFSET = Vector3.zero,
	},
	VertexInfo = VertexInfo,
	VertexPositionToId = {},

	_QUADS = _QUADS,
	_TRIANGLES = _TRIANGLES
}

local function GetMidpoint(a: Vector3, b: Vector3): Vector3
	return (a + b) / 2
end

local function MergeBorderVertex(EditableMesh: EditableMesh, VertexId: number, VertexPosition: Vector3, QuadCenter: Vector3, Subdivisions: number)
	local Displacement = (QuadCenter - VertexPosition)
	local Divisor = math.pow(2, Subdivisions)

	local VertexInfo = Setup.VertexInfo
	local GRID_SETTINGS = Setup.SETTINGS
	local VertexPositionToId = Setup.VertexPositionToId

	local _QUADS, _TRIANGLES = Setup._QUADS, Setup._TRIANGLES
	if _QUADS == nil or _TRIANGLES == nil then
		return
	end

	local Matched = false
	if Displacement.X < 0 then -- // left side (right side if inverted)
		Matched = true
		local TriangleCenter = VertexPosition + -Displacement
		local AdjacentMerge = VertexPosition + Vector3.new(0, 0, -GRID_SETTINGS.Padding / Divisor)
		local AdjacentMerge2 = VertexPosition + Vector3.new(0, 0, GRID_SETTINGS.Padding / Divisor)

		local CornerMerge = TriangleCenter + -Displacement + Vector3.new(0, 0, -GRID_SETTINGS.Padding / Divisor)
		local TriangleData = _TRIANGLES[TriangleCenter]

		local Index = (Setup.CurrentSubdivisions % 3) == 0 and 2 or 1
		EditableMesh:RemoveFace(TriangleData[Index])
		TriangleData[Index] = nil

		local Triangle1 = EditableMesh:AddTriangle(VertexPositionToId[CornerMerge], VertexPositionToId[AdjacentMerge], VertexId)
		local Triangle2 = EditableMesh:AddTriangle(VertexId, VertexPositionToId[AdjacentMerge2], VertexPositionToId[CornerMerge])
		table.insert(TriangleData, Triangle1)
		table.insert(TriangleData, Triangle2)

	elseif Displacement.X > 0 then -- // right side (left side if inverted)
		Matched = true
		local TriangleCenter = VertexPosition + -Displacement
		local AdjacentMerge = VertexPosition + Vector3.new(0, 0, GRID_SETTINGS.Padding / Divisor)
		local AdjacentMerge2 = VertexPosition + Vector3.new(0, 0, -GRID_SETTINGS.Padding / Divisor)

		local CornerMerge = TriangleCenter + -Displacement + Vector3.new(0, 0, GRID_SETTINGS.Padding / Divisor)
		local TriangleData = _TRIANGLES[TriangleCenter]

		local Index = (Setup.CurrentSubdivisions % 3) == 0 and 1 or 2
		EditableMesh:RemoveFace(TriangleData[Index])
		TriangleData[Index] = nil

		local Triangle1 = EditableMesh:AddTriangle(VertexPositionToId[CornerMerge], VertexPositionToId[AdjacentMerge], VertexId)
		local Triangle2 = EditableMesh:AddTriangle(VertexId, VertexPositionToId[AdjacentMerge2], VertexPositionToId[CornerMerge])
		table.insert(TriangleData, Triangle1)
		table.insert(TriangleData, Triangle2)
	end
	if Matched == false then
		if Displacement.Z > 0 then -- // bottom side (top side if inverted)
			local TriangleCenter = VertexPosition + -Displacement
			local AdjacentMerge = VertexPosition + Vector3.new(GRID_SETTINGS.Padding / Divisor, 0, 0)
			local AdjacentMerge2 = VertexPosition + Vector3.new(-GRID_SETTINGS.Padding / Divisor, 0, 0)

			local CornerMerge = TriangleCenter + -Displacement + Vector3.new(GRID_SETTINGS.Padding / Divisor, 0, 0)
			local TriangleData = _TRIANGLES[TriangleCenter]

			local Index = (Setup.CurrentSubdivisions % 3) == 0 and 1 or 2
			EditableMesh:RemoveFace(TriangleData[Index])
			TriangleData[Index] = nil

			local Triangle1 = EditableMesh:AddTriangle(VertexPositionToId[CornerMerge], VertexId, VertexPositionToId[AdjacentMerge])
			local Triangle2 = EditableMesh:AddTriangle(VertexPositionToId[CornerMerge], VertexPositionToId[AdjacentMerge2], VertexId)
			table.insert(TriangleData, Triangle1)
			table.insert(TriangleData, Triangle2)

		elseif Displacement.Z < 0 then -- // bottom side (top side if inverted)
			local TriangleCenter = VertexPosition + -Displacement
			local AdjacentMerge = VertexPosition + Vector3.new(-GRID_SETTINGS.Padding / Divisor, 0, 0)
			local AdjacentMerge2 = VertexPosition + Vector3.new(GRID_SETTINGS.Padding / Divisor, 0, 0)

			local CornerMerge = TriangleCenter + -Displacement + Vector3.new(-GRID_SETTINGS.Padding / Divisor, 0, 0)
			local TriangleData = _TRIANGLES[TriangleCenter]

			local Index = (Setup.CurrentSubdivisions % 3) == 0 and 2 or 1
			EditableMesh:RemoveFace(TriangleData[Index])
			TriangleData[Index] = nil

			local Triangle1 = EditableMesh:AddTriangle(VertexPositionToId[CornerMerge], VertexId, VertexPositionToId[AdjacentMerge])
			local Triangle2 = EditableMesh:AddTriangle(VertexPositionToId[CornerMerge], VertexPositionToId[AdjacentMerge2], VertexId)
			table.insert(TriangleData, Triangle1)
			table.insert(TriangleData, Triangle2)
		end
	end
end

local function GetUVCoordinates(Vx: number, Vz: number): Vector2

	local GRID_SETTINGS = Setup.SETTINGS
	local UVPadding = GRID_SETTINGS.UV_SCALE

	local Padding: number = GRID_SETTINGS.Padding
	local Width: number = GRID_SETTINGS.Width
	local Length: number = GRID_SETTINGS.Length

	local x = ((Vx + ((Padding * (Width - 1) / 2))) / Padding) + 1
	local y = ((Vz + ((Padding * (Length - 1) / 2))) / Padding) + 1

	return Vector2.new(x, y)
end

local function InsertToVertexInfo(EM: EditableMesh, Id: number)
	local VertexInfo = Setup.VertexInfo
	local GRID_SETTINGS = Setup.SETTINGS
	local VertexPositionToId = Setup.VertexPositionToId

	if VertexInfo[Id] ~= nil then
		return
	end

	local Position = EM:GetPosition(Id)
	local UV = GetUVCoordinates(Position.X, Position.Z)

	local QUALITY_LEVEL = 1
	local Distance = (Position - EM:GetCenter()).Magnitude
	if Distance > _settings.LowRenderDistance then
		QUALITY_LEVEL = 2
	end

	VertexInfo[Id] = {
		VertexId = Id,
		ColorId = 0,
		UVId = 0,
		NormalId = 0,

		UV = UV * GRID_SETTINGS.UV_SCALE,
		Position = Position,
		Lerping = false,
		CurrentFrame = 0,

		GoalPosition = Vector3.zero,
		LastPosition = Vector3.zero,

		CurrentColor = Color3.new(0, 0, 0),
		AlphaTransparency = 1,
		QUALITY_LEVEL = QUALITY_LEVEL,
	}
	VertexPositionToId[Position] = Id
end

function Setup.GetBlankVertexKey(Id: number, x: number, z: number): Types.VertexKey
	local GRID_SETTINGS = Setup.SETTINGS
	local UV = GetUVCoordinates(x, z)
	return {
		VertexId = Id,
		ColorId = 0,
		UVId = 0,
		NormalId = 0,
		UV = UV * GRID_SETTINGS.UV_SCALE,

		Position = Vector3.new(x, 0, z),

		Lerping = false,

		CurrentFrame = 0,
		GoalPosition = Vector3.zero,
		LastPosition = Vector3.zero,

		CurrentColor = Color3.new(0, 0, 0),
		AlphaTransparency = 1,
		QUALITY_LEVEL = 1,
	}
end

function Setup.SetupEditableMesh(): EditableMesh
	local Vertices: { { number } } = {}
	local EditableMesh = AssetService:CreateEditableMesh({ FixedSize = true; })

	local VertexInfo = Setup.VertexInfo
	local GRID_SETTINGS = Setup.SETTINGS
	local VertexPositionToId = Setup.VertexPositionToId

	local _QUADS, _TRIANGLES = Setup._QUADS, Setup._TRIANGLES
	if _QUADS == nil or _TRIANGLES == nil then
		warn('[Setup]: _QUADS or _TRIANGLES were not set.')
		return EditableMesh
	end

	-- // We begin to set up our vertices for the EditableMesh
	-- // Note: This segment is thanks to https://devforum.roblox.com/t/gerstner-wave-module/3011006

	for y = 1, GRID_SETTINGS.Length do
		local raw = {}
		for x = 1, GRID_SETTINGS.Width do
			local padding = GRID_SETTINGS.Padding

			local vertexX = (padding * (x - 1)) - (padding * (GRID_SETTINGS.Width - 1)) / 2
			local vertexZ = (padding * (y - 1)) - (padding * (GRID_SETTINGS.Length - 1)) / 2
			local VertexPosition = Vector3.new(vertexX, 0, vertexZ)
			local VertexId = EditableMesh:AddVertex(VertexPosition)

			VertexInfo[VertexId] = Setup.GetBlankVertexKey(VertexId, vertexX, vertexZ)
			local Distance = (VertexPosition - Vector3.zero).Magnitude
			if Distance > _settings.LowRenderDistance then
				VertexInfo[VertexId].QUALITY_LEVEL = 2
			end


			VertexPositionToId[VertexPosition] = VertexId
			raw[x] = VertexId
		end
		Vertices[y] = raw
	end

	for y = 1, GRID_SETTINGS.Length - 1 do
		for x = 1, GRID_SETTINGS.Width - 1 do
			local vertex1Front = Vertices[y][x]
			local vertex2Front = Vertices[y + 1][x]
			local vertex3Front = Vertices[y][x + 1]
			local vertex4Front = Vertices[y + 1][x + 1]

			local Center = 
				(EditableMesh:GetPosition(vertex1Front) + EditableMesh:GetPosition(vertex2Front) + EditableMesh:GetPosition(vertex3Front) + EditableMesh:GetPosition(vertex4Front)) / 4

			local triangle1 = EditableMesh:AddTriangle(vertex1Front, vertex2Front, vertex3Front)
			local triangle2 = EditableMesh:AddTriangle(vertex2Front, vertex4Front, vertex3Front)
			_QUADS[Center] = {
				vertex1Front,
				vertex2Front,
				vertex3Front,
				vertex4Front
			}

			_TRIANGLES[Center] = {
				triangle1,
				triangle2
			}
		end
	end

	table.clear(Vertices)
	EditableMesh:RemoveUnused()

	return EditableMesh
end

function Setup.GetPlaneFromEditableMesh(EM: EditableMesh, Name: string?): MeshPart
	-- // Create the plane mesh through the EditableMesh API.
	-- // We also set up all the properties for it, as well as
	-- // applying a SurfaceAppearance
	local Size = EM:GetSize()

	local Plane = AssetService:CreateMeshPartAsync(Content.fromObject(EM))
	local Existing = script.ExistingMesh

	Existing:ApplyMesh(Plane)
	Existing.Size = Plane.Size

	Plane:Destroy()
	Plane = Existing

	Plane.Name = Name or 'OceanPlane'
	Plane.Anchored = true
	Plane.CanCollide, Plane.CastShadow = false, false
	Plane.Material = Enum.Material.Granite

	local Appearance = ReplicatedStorage.Gerstner.Appearance:Clone()
	Appearance.Parent = Plane

	Plane.Color = Color3.fromRGB(255, 255, 255)
	Plane.Size = Vector3.new(Size.X, 0.001, Size.Z)
	Plane.Position = Setup.SETTINGS.PLANE_OFFSET
	Plane.Transparency = 0	

	Plane.Parent = workspace.Ocean

	return Plane
end

function Setup.SubdividePlane(MinimumDistance: number, Debug: boolean, EditableMesh: EditableMesh)
	local AddedQuads = {}
	local SubdividedQuadkeys = {}

	local VertexInfo = Setup.VertexInfo
	local GRID_SETTINGS = Setup.SETTINGS
	local VertexPositionToId = Setup.VertexPositionToId

	local _QUADS, _TRIANGLES = Setup._QUADS:: { [Vector3]: {} }, Setup._TRIANGLES

	Setup.CurrentSubdivisions += 1
	if _QUADS == nil or _TRIANGLES == nil then
		return
	end

	for QuadPosition, Vertices in _QUADS do
		local v1, v2, v3, v4 = Vertices[1], Vertices[2], Vertices[3], Vertices[4]
		local p1, p2, p3, p4 = VertexInfo[v1].Position, VertexInfo[v2].Position, VertexInfo[v3].Position, VertexInfo[v4].Position

		local CenterPosition = (p1 + p2 + p3 + p4) / 4
		if math.abs(CenterPosition.X) > MinimumDistance or math.abs(CenterPosition.Z) > MinimumDistance then
			continue
		end

		local OriginalFaces = _TRIANGLES[CenterPosition]

		for i, TriangleId in OriginalFaces do
			EditableMesh:RemoveFace(TriangleId:: number)
		end
		_TRIANGLES[CenterPosition] = nil

		local midpointAB = GetMidpoint(p1, p2)
		local midpointBD = GetMidpoint(p2, p4)
		local midpointCD = GetMidpoint(p3, p4)
		local midpointAC = GetMidpoint(p1, p3)

		local CenterVertex = EditableMesh:AddVertex(CenterPosition)
		local ABVertex = VertexPositionToId[midpointAB] or EditableMesh:AddVertex(midpointAB)
		local ACVertex = VertexPositionToId[midpointAC] or EditableMesh:AddVertex(midpointAC)
		local BDVertex = VertexPositionToId[midpointBD] or EditableMesh:AddVertex(midpointBD)
		local CDVertex = VertexPositionToId[midpointCD] or EditableMesh:AddVertex(midpointCD)


		InsertToVertexInfo(EditableMesh, CenterVertex)
		InsertToVertexInfo(EditableMesh, ABVertex)
		InsertToVertexInfo(EditableMesh, ACVertex)
		InsertToVertexInfo(EditableMesh, BDVertex)
		InsertToVertexInfo(EditableMesh, CDVertex)

		-- // top left
		local Triangle1 = EditableMesh:AddTriangle(v4, CDVertex, BDVertex)
		local Triangle2 = EditableMesh:AddTriangle(CDVertex, CenterVertex, BDVertex)
		table.insert(AddedQuads, {
			v4,
			CDVertex,
			BDVertex,
			CenterVertex,
			Triangles = {
				Triangle2,
				Triangle1
			}
		})

		-- // bottom left
		local Triangle1 = EditableMesh:AddTriangle(CDVertex, v3, CenterVertex)
		local Triangle2 = EditableMesh:AddTriangle(v3, ACVertex, CenterVertex)
		table.insert(AddedQuads, {
			CDVertex,
			v3,
			CenterVertex,
			ACVertex,
			Triangles = {
				Triangle2,
				Triangle1
			}
		})

		-- // top right
		local Triangle1 = EditableMesh:AddTriangle(BDVertex, CenterVertex, v2)
		local Triangle2 = EditableMesh:AddTriangle(CenterVertex, ABVertex, v2)
		table.insert(AddedQuads, {
			BDVertex,
			CenterVertex,
			v2,
			ABVertex,
			Triangles = {
				Triangle2,
				Triangle1
			}
		})

		-- // bottom right
		local Triangle1 = EditableMesh:AddTriangle(CenterVertex, ACVertex, ABVertex)
		local Triangle2 = EditableMesh:AddTriangle(ACVertex, v1, ABVertex)
		table.insert(AddedQuads, {
			CenterVertex,
			ACVertex,
			ABVertex,
			v1,
			Triangles = {
				Triangle2,
				Triangle1
			}
		})

		_QUADS[QuadPosition] = nil
		for i, Vertex in {ABVertex, ACVertex, BDVertex, CDVertex} do
			local FaceCount = #EditableMesh:GetFacesWithAttribute(Vertex)
			local Position = EditableMesh:GetPosition(Vertex)

			local Displacement = CenterPosition - Position
			local Neighbor = CenterPosition + (-Displacement * 2)
			local Valid = math.abs(Neighbor.X) > MinimumDistance or math.abs(Neighbor.Z) > MinimumDistance

			if FaceCount == 3 and Valid == true and Debug == true then
				MergeBorderVertex(EditableMesh, Vertex, Position, CenterPosition, Setup.CurrentSubdivisions)
			end
		end
	end
	EditableMesh:Triangulate()

	for i, Info in AddedQuads do
		local UpdatedTriangles = table.clone(Info.Triangles)
		Info.Triangles = nil:: any

		local Center = Vector3.zero
		for i, Vertex in Info do
			Center += EditableMesh:GetPosition(Vertex)
		end
		Center /= 4

		_QUADS[Center] = Info
		_TRIANGLES[Center] = UpdatedTriangles
	end

	return AddedQuads
end

function Setup.SetupSecondaryPlanes(EM: EditableMesh): { { MeshPart | Vector3 } }
	local AssetService = game:GetService('AssetService')
	local Size = EM:GetSize()

	local EditableMesh = AssetService:CreateEditableMesh({ FixedSize = true; })

	local v1 = EditableMesh:AddVertex(Vector3.new(-Size.X / 2, 0, -Size.Z / 2))
	local v2 = EditableMesh:AddVertex(Vector3.new(Size.X / 2, 0, -Size.Z / 2))
	local v3 = EditableMesh:AddVertex(Vector3.new(-Size.X / 2, 0, Size.Z / 2))
	local v4 = EditableMesh:AddVertex(Vector3.new(Size.X / 2, 0, Size.Z / 2))

	local triangle1 = EditableMesh:AddTriangle(v1, v3, v4)
	local triangle2 = EditableMesh:AddTriangle(v4, v2, v1)

	for i, UVId in EditableMesh:GetUVs() do
		local VertexId = EditableMesh:GetVerticesWithAttribute(UVId)[1]
		if VertexId then
			local POS = EditableMesh:GetPosition(VertexId)
			local Vx, Vz = POS.X, POS.Z

			local Padding = _settings.GRID_SETTINGS.Padding
			local x = ((Vx / Padding)) + 1
			local y = ((Vz / Padding)) + 1

			EditableMesh:SetUV(UVId, Vector2.new(x, y) * _settings.GRID_SETTINGS.PaddingMultiplier)
		end
	end
	for i, ColorId in EditableMesh:GetColors() do
		local VertexId = EditableMesh:GetVerticesWithAttribute(ColorId)[1]
		if VertexId then
			EditableMesh:SetColor(ColorId, _settings.WAVE_COLORS.TROUGH)
		end
	end

	local SecondaryPlaneInfo = {}
	for i = 1, 8 do
		local NewSize = EditableMesh:GetSize()

		local Plane = AssetService:CreateMeshPartAsync(Content.fromObject(EditableMesh))
		Plane.Name = 'SecondaryPlane'
		Plane.Anchored = true
		Plane.CanCollide, Plane.CastShadow = false, false
		Plane.Material = Enum.Material.Granite

		local Appearance = ReplicatedStorage.Gerstner.Appearance:Clone()
		Appearance.Parent = Plane

		Plane.Color = Color3.fromRGB(255, 255, 255)
		Plane.Size = Vector3.new(NewSize.X, 0.001, NewSize.Z)
		Plane.Position = Setup.SETTINGS.PLANE_OFFSET
		Plane.Transparency = 0
		Plane.Parent = workspace.Ocean

		local Offset = Vector3.zero
		if i == 1 then
			Offset = Vector3.new(-Plane.Size.X, 0, 0)
		elseif i == 2 then
			Offset = Vector3.new(Plane.Size.X, 0, 0)
		elseif i == 3 then
			Offset = Vector3.new(0, 0, -Plane.Size.Z)
		elseif i == 4 then
			Offset = Vector3.new(0, 0, Plane.Size.Z)
		elseif i == 5 then
			Offset = Vector3.new(Plane.Size.X, 0, Plane.Size.Z)
		elseif i == 6 then
			Offset = Vector3.new(-Plane.Size.X, 0, Plane.Size.Z)
		elseif i == 7 then
			Offset = Vector3.new(-Plane.Size.X, 0, -Plane.Size.Z)
		elseif i == 8 then
			Offset = Vector3.new(Plane.Size.X, 0, -Plane.Size.Z)
		end
		local Info = {
			Plane,
			Offset
		}
		table.insert(SecondaryPlaneInfo, Info)
	end
	return SecondaryPlaneInfo
end

return Setup



heightlookup module
--!native
--!optimize 2
--!strict

--[[
	@FlameEmber06
	Performant and accurate height lookup module for the ocean.
]]

local QuadInfo = {}
local IS_SERVER = game:GetService('RunService'):IsServer()

-- // These are our triangle maps based off our ADJACENT_OFFSETS.
-- // Should be unedited, unless the order of values in ADJACENT_OFFSETS are swapped.
local TRIANGLE_MAP_1 : { number? } = {nil, nil, nil, nil, nil, nil, 1, 5}
local TRIANGLE_MAP_2 : { number  } = {1, 2, 1, 4, 3, 5, 			2, 6}
local TRIANGLE_MAP_3 : { number  } = {2, 3, 4, 5, 6, 6, 			8, 7}

local _settings = require(script.Parent.Settings)
local Subdivisions = #_settings.Subdivisions
local Padding = _settings.GRID_SETTINGS.Padding / math.pow(2, Subdivisions)

local PLANE_OFFSET_Y = _settings.GRID_SETTINGS.PLANE_OFFSET.Y
local RAY_DISTANCE = _settings.GRID_SETTINGS.PLANE_OFFSET.Y + 5

local ADJACENT_OFFSETS = {
	Vector3.new(Padding, 0, 0),
	Vector3.new(0, 0, Padding),

	Vector3.new(-Padding, 0, Padding),
	Vector3.new(Padding, 0, -Padding),

	Vector3.new(0, 0, -Padding),
	Vector3.new(-Padding, 0, 0),

	Vector3.new(-Padding, 0, -Padding),
	Vector3.new(Padding, 0, Padding),
}

local SEARCH_OFFSETS = {
	Vector3.new(Padding, 0, 0),
	Vector3.new(0, 0, Padding),

	Vector3.new(-Padding, 0, Padding),
	Vector3.new(Padding, 0, -Padding),

	Vector3.new(0, 0, -Padding),
	Vector3.new(-Padding, 0, 0),

	Vector3.new(-Padding, 0, -Padding),
	Vector3.new(Padding, 0, Padding), 

	Vector3.new(Padding * 2, 0, Padding),
	Vector3.new(Padding * 2, 0, Padding * 2),
	Vector3.new(Padding * 2, 0, 0),
	Vector3.new(Padding * 2, 0, -Padding),
	Vector3.new(Padding * 2, 0, -Padding * 2),

	Vector3.new(-Padding * 2, 0, Padding),
	Vector3.new(-Padding * 2, 0, Padding * 2),
	Vector3.new(-Padding * 2, 0, 0),
	Vector3.new(-Padding * 2, 0, -Padding),
	Vector3.new(-Padding * 2, 0, -Padding * 2),


	Vector3.new(Padding, 0, Padding * 2),
	Vector3.new(0, 0, Padding * 2),
	Vector3.new(-Padding, 0, Padding * 2),

	Vector3.new(-Padding, 0, -Padding * 2),
	Vector3.new(0, 0, -Padding * 2),
	Vector3.new(Padding, 0, -Padding * 2),
}

local LOOKUP_METHODS = {
	PRECISE = "PRECISE",
	PRECISE_RAY = "RAY",

	FAST = "FAST",
}

local GerstnerModule = require(script.Parent)

local _PLANE : MeshPart? = nil
local EditableMesh: EditableMesh? = nil

local abs = math.abs
local v3new = Vector3.new
local round = math.round
local XZ_INCLUDE = Vector3.new(1, 0, 1)

--[[
	Returns the area of a triangle, given 3 vertices.
]]
local function GetTriangleArea(v1: Vector3, v2: Vector3, v3: Vector3): number
	-- // (1/2) [x1 (z2 - z3) + x2 (z3 - z1) + x3 (z1 - z2)]
	return 0.5 * abs(
		v1.X * (v2.Z - v3.Z) + 
			v2.X * (v3.Z - v1.Z) + 
			v3.X * (v1.Z - v2.Z)
	)
end

--[[
	Fetches the height of a point on a triangle, given 3 vertices and the point's position.
	Returns <code>nil</code> if the point is not on the plane of the triangle.
]]
local function GetHeight(point: Vector3, v1: Vector3, v2: Vector3, v3: Vector3): number?
	local A = GetTriangleArea(v1, v2, v3)
	local A1 = GetTriangleArea(point, v2, v3)
	local A2 = GetTriangleArea(v1, point, v3)
	local A3 = GetTriangleArea(v1, v2, point)

	-- // We use 1e-10 as a 'buffer' zone
	if abs(A - (A1 + A2 + A3)) < 1e-10 then
		-- // Barycentric coordinate math
		local h1, h2, h3 = v1.Y, v2.Y, v3.Y

		local weight1 = A1 / A
		local weight2 = A2 / A
		local weight3 = A3 / A

		return weight1 * h1 + weight2 * h2 + weight3 * h3
	end
	return nil
end


local HeightLookup = {}
local VertexPositionToId: { [Vector3]: number } = {}

HeightLookup.LOOKUP_METHODS = LOOKUP_METHODS
--[[
	Performs a height lookup at an XZ point. Offers lookup methods "PRECISE", "RAY" and "FAST"
	
	<strong>PRECISE:</strong> Performs an accurate height lookup off adjacent triangles.
	<strong>RAY:</strong> Performs an accurate height lookup using <code>EditableMesh.RaycastLocal</code>
	<strong>FAST:</strong> Performs an approximate height lookup through a modified formula. Prioritizes speed over accuracy.
	
	<code>UseNearbyVertices:</code> Determines whether the height lookup should use nearby mesh vertices to get the height instead of performing a Gerstner offset call for each vertex.
	Will have no effect if the server does a lookup with this set to <code>true</code>.
	
	Optional multipliers can be given, which are used for zone / island regions.
]]
function HeightLookup.Lookup(Point: Vector3, LOOKUP_METHOD: string, UseNearbyVertices: boolean, SpeedMultiplier: number?, PhaseMultiplier: number?, AmplitudeMultiplier: number?, ZONE: any?): number
	if _PLANE == nil and IS_SERVER == false then
		warn('[HeightLookup] Please set the _PLANE value of the module before calling \'Lookup\'.')
		return -1
	end
	local Plane, EM = nil, nil
	if IS_SERVER == false then 
		Plane = _PLANE:: MeshPart
		EM = EditableMesh:: EditableMesh
	end
	-- // Average performances were from testing the function on one point every heartbeat step.

	if LOOKUP_METHOD == LOOKUP_METHODS.PRECISE then -- // Average performance: ~0.01ms
		-- // 1. Get the nearest 'corner' point of a grid square relative to the point
		local Clamped = v3new(round(Point.X / Padding) * Padding, PLANE_OFFSET_Y, round(Point.Z / Padding) * Padding)
		if Subdivisions == 0 then
			Clamped += Vector3.new(Padding / 2, 0, Padding / 2)
		end

		-- // We define multiple 'region offset points' around our actual closest vertex. We do this due to limitation 1,
		-- // so that we still get a valid height even if the XZ positions of a vertex are very deformed / offset.
		-- // An example of this occurring would be being near or inside a whirlpool.
		-- // Doesn't seem to have a noticeable performance impact, with relatively low ms (~0.03ms) per frame.

		for SearchRegion = 0, 24 do
			-- // This is our corner point (which is a vertex)

			local CornerPosition = v3new(Clamped.X, 0, Clamped.Z)

			if SearchRegion ~= 0 then
				CornerPosition += (SEARCH_OFFSETS[SearchRegion] * 2)
			end

			local PlanePositionXZ = Vector3.zero
			if IS_SERVER == false then
				-- // We need to subtract the plane position as an offset to it so we can get it in local space for the client
				-- // We'll add this back later
				PlanePositionXZ = Plane.Position * XZ_INCLUDE
				CornerPosition -= PlanePositionXZ
			end


			-- // Because the adjacent table gives us our offsets in a specific order, we can easily 
			-- // create the 6 triangles using by mapping an iterator [i] from a loop to the indices
			-- // The index map would look like this:
			-- // {1, 2, 1, 4, 3, 5}
			-- // {2, 3, 4, 5, 6, 6}
			-- // Where triangle1 is points { Corner, Adj[1], Adj[2] }, triangle2 is { Corner, Adj[2], Adj[3] }, etc...

			-- // 2. Iterate through all the triangles in order to see which triangle we're on

			for i = 1, 8 do
				-- // Instead of having an array of adjacent corners, we can directly get the correct
				-- // adjacent grid corner that will form a triangle thanks to our triangle map array (memory safe)
				-- // Worst case: We loop through all 8 triangles in order to find the height
				-- // Best case: We get the height from 1 triangle (the first triangle we check)

				local CurrentAdjacent1 = CornerPosition
				local CurrentAdjacent2 = CornerPosition + ADJACENT_OFFSETS[TRIANGLE_MAP_2[i]]
				local CurrentAdjacent3 = CornerPosition + ADJACENT_OFFSETS[TRIANGLE_MAP_3[i]]
				if i == 7 or i == 8 then
					CurrentAdjacent1 = CornerPosition + ADJACENT_OFFSETS[TRIANGLE_MAP_1[i]:: number]
				end

				local v1, v2, v3 = Vector3.zero, Vector3.zero, Vector3.zero
				if UseNearbyVertices == true and IS_SERVER == false then
					local Vertex1Id = VertexPositionToId[CurrentAdjacent1]
					local Vertex2Id = VertexPositionToId[CurrentAdjacent2]
					local Vertex3Id = VertexPositionToId[CurrentAdjacent3]

					v1 = EM:GetPosition(Vertex1Id) + PlanePositionXZ
					v2 = EM:GetPosition(Vertex2Id) + PlanePositionXZ
					v3 = EM:GetPosition(Vertex3Id) + PlanePositionXZ
				else
					local t = workspace:GetServerTimeNow()
					-- // We apply our gerstner offsets to the triangle vertices, then check if we get a resulting height

					if IS_SERVER == false then
						CurrentAdjacent1 += PlanePositionXZ
						CurrentAdjacent2 += PlanePositionXZ
						CurrentAdjacent3 += PlanePositionXZ
					end

					v1 = CurrentAdjacent1 + GerstnerModule.ComputeTransform(_settings.Waves, CurrentAdjacent1, t, PhaseMultiplier, SpeedMultiplier, AmplitudeMultiplier)
					v2 = CurrentAdjacent2 + GerstnerModule.ComputeTransform(_settings.Waves, CurrentAdjacent2, t, PhaseMultiplier, SpeedMultiplier, AmplitudeMultiplier)
					v3 = CurrentAdjacent3 + GerstnerModule.ComputeTransform(_settings.Waves, CurrentAdjacent3, t, PhaseMultiplier, SpeedMultiplier, AmplitudeMultiplier)

					if ZONE ~= nil and ZONE.Type == 'Whirlpool' then
						v1 += GerstnerModule.GetVortexTransform(ZONE, CurrentAdjacent1, nil, t, nil)
						v2 += GerstnerModule.GetVortexTransform(ZONE, CurrentAdjacent2, nil, t, nil)
						v3 += GerstnerModule.GetVortexTransform(ZONE, CurrentAdjacent3, nil, t, nil)
					end
				end

				local Height = GetHeight(Point, v1, v2, v3)
				if Height ~= nil then
					-- // Once we've found a valid height, we don't need to iterate through any more triangles, so we immediately return
					return Height + PLANE_OFFSET_Y
				end
			end
		end
	elseif LOOKUP_METHOD == LOOKUP_METHODS.PRECISE_RAY then -- // Average performance: ~0.7ms
		-- // Performance is much slower compared to the default method as ROBLOX constructs a 
		-- // new KD tree everytime :RaycastLocal() is called (~0.57ms)

		-- // PRECISE_RAY can only be called from the client, as we need the mesh data to perform a local raycast.
		if IS_SERVER == true then
			warn('[HeightLookup] Attemped to call Lookup with PRECISE_RAY method on the server. Did you mean to call \'PRECISE\'?')
			return -1
		end
		local EM = EditableMesh:: EditableMesh

		-- // We'll cast a ray downards from the point, and check if we get any results
		local TriangleId, Height = EM:RaycastLocal(Point + Vector3.yAxis, -Vector3.yAxis * RAY_DISTANCE)
		if TriangleId ~= nil then
			-- // If we get a valid hit, we return the height
			return Height.Y + PLANE_OFFSET_Y
		end
		-- // In the case that we weren't able to, we return -1. This can occur if RAY_DISTANCE isn't large enough.
		-- // It's best to keep the distance short as longer raycasts can be more expensive.
		return -1
	elseif LOOKUP_METHOD == LOOKUP_METHODS.FAST then
		local t = workspace:GetServerTimeNow()
		return GerstnerModule:GetApproximateHeight(_settings.Waves, Point, t, PhaseMultiplier, SpeedMultiplier, AmplitudeMultiplier) + PLANE_OFFSET_Y
	end
	if _settings.DEBUG == true then
		warn('HEIGHT FAILED')
	end
	-- // In the case that we were not able to find a height for a given reason, we just return -1
	return -1
end

--[[
	Initializes the HeightLookup module for the client.
]]
function HeightLookup.ClientInit(Dictionary: { [Vector3]: number }, Mesh: EditableMesh, Plane: MeshPart)
	VertexPositionToId = Dictionary
	EditableMesh = Mesh
	_PLANE = Plane
end

return HeightLookup

Zone manager module
--!strict

local RS = game:GetService('ReplicatedStorage')
local CS = game:GetService('CollectionService')
local RunService = game:GetService('RunService')

local IS_SERVER = RunService:IsServer()
local OctreeModule = require(RS:WaitForChild('Octree'))
local _settings = require(RS.Gerstner.Settings)
local Helper = require(RS.Gerstner.Helper)

local ISLAND_TREE = OctreeModule.new()
local ZONE_TREE = OctreeModule.new()

local clamp = math.clamp
local REFRESH_RATE = 3

local ZONES = {}

local function IslandAdded(Island: Model)
	Island = Island:: Model	

	if Island:WaitForChild('Center', 1) == nil then
		return
	end
	local Center: BasePart = Island:WaitForChild('Center'):: BasePart

	local Radius = 0
	local RadiusInstance: IntValue? = Island:FindFirstChild('Radius'):: IntValue?
	if RadiusInstance then
		Radius = RadiusInstance.Value
	else
		Radius = (Island:GetExtentsSize() * Vector3.new(1, 0, 1)).Magnitude / 2
	end
	ISLAND_TREE:CreateNode(Center.Position, {
		Island = Island,
		Radius = Radius,
	})
end

local ZoneManager = {}
export type ZoneParameters = Helper.ZoneParameters
ZoneManager.ISLAND_TREE = ISLAND_TREE
ZoneManager.ZONE_TREE = ZONE_TREE

function ZoneManager:InsertZone(Position: Vector3, ZoneInfo: Helper.ZoneParameters): OctreeModule.Node<Helper.ZoneParameters>?
	local ExistingZone = ZONE_TREE:GetNearest(Position, ZoneInfo.Radius * 2, 1)
	if ExistingZone[1] ~= nil then
		return nil
	end

	local NODE = ZONE_TREE:CreateNode(Position, ZoneInfo)
	if ZoneInfo.Link then
		ZoneInfo.Link.Destroying:Once(function()
			ZONE_TREE:RemoveNode(NODE)
		end)
	end

	if IS_SERVER == true then
		script.EditZone:FireAllClients('Insert', Position, ZoneInfo)
	elseif ZoneInfo.Link then
		local Link = ZoneInfo.Link
		Link.AttributeChanged:Connect(function(Attribute: string)
			if Attribute == 'DestroyNode' then
				ZONE_TREE:RemoveNode(NODE)
				script.ZoneUpdated:Fire()
			elseif Attribute == 'Despawn' then
				NODE.Object.FullDecayAt = workspace:GetServerTimeNow() + ZoneInfo.DissolveTime
				NODE.Object.Despawn = true

				script.ZoneUpdated:Fire()
			end
		end)
	end

	return NODE
end

function ZoneManager:RemoveZone(Node: OctreeModule.Node<Helper.ZoneParameters>)
	Node.Object.Link:SetAttribute('DestroyNode', true)
	ZONE_TREE:RemoveNode(Node)
end

--[[
	Returns the parameters of the zone or island that overlaps the position, prioritizing custom zones over islands
	Should be called sparingly, as every node in the 2 octrees will be iterated over
]]
function ZoneManager:GetZoneParameters(Position: Vector3): Helper.ZoneParameters?

	local ZoneNodes = ZONE_TREE:GetAllNodes()
	for i, Node in ZoneNodes do
		local Data = Node.Object
		local NodePosition = Data.Link.Position
		if (NodePosition - Position).Magnitude < Data.Radius then
			return Data
		end
	end

	local IslandNodes = ISLAND_TREE:GetAllNodes()
	for i, Node in IslandNodes do
		local Data = Node.Object
		local NodePosition = Node.Position

		if (NodePosition - Position).Magnitude < Data.Radius then
			return Data:: any
		end		
	end
	return nil
end

--[[
	Fetches the wave parameter multipliers for a specified zone.
]]
function ZoneManager:GetZoneMultipliers(Point: Vector3, ZonePosition: Vector3, ZoneParameters: Helper.ZoneParameters): (number, number, number, boolean)
	return Helper.GetZoneMultipliers(Point, ZonePosition, ZoneParameters)
end

--[[
	Fetches the wave parameter multipliers for a specified island zone.
]]
function ZoneManager:GetIslandMultipliers(Point: Vector3, Island: any, Radius: number): (number, number, number, boolean, number)
	return Helper.GetIslandMultipliers(Point, Island, Radius)
end

--[[
	Updates all nodes in the 'ZONE' tree.
]]
function ZoneManager.UpdateAllNodes()
	local Nodes = ZONE_TREE:GetAllNodes()
	for i, Node in Nodes do
		local Data = Node.Object
		ZONE_TREE:ChangeNodePosition(Node, Data.Link.Position)
	end
end

-- // Main
local Accumulated = 0
RunService.PostSimulation:Connect(function(dt)
	Accumulated += dt
	if Accumulated >= REFRESH_RATE then
		Accumulated = 0
		ZoneManager.UpdateAllNodes()
	end
end)

CS:GetInstanceAddedSignal('Island'):Connect(function(Island)
	IslandAdded(Island)
end)
for i, Island in CS:GetTagged('Island') do
	if not Island:IsA('Model') then
		continue
	end
	IslandAdded(Island)
end

for i, Island in workspace.Map:GetChildren() do
	if not Island:IsA('Model') then
		continue
	end
	IslandAdded(Island)
end

if IS_SERVER == false then
	script.EditZone.OnClientEvent:Connect(function(Type, ...)
		if Type == 'Insert' then
			ZoneManager:InsertZone(...)
		end
		script.ZoneUpdated:Fire()
	end)
end

ZoneManager.ZoneUpdated = script.ZoneUpdated.Event

return ZoneManager



Zone manager have a remote event and a bindableevent

Boat manager module
--!strict
--!optimize 2

local RS = game:GetService('ReplicatedStorage')
local CS = game:GetService('CollectionService')
local RunService = game:GetService('RunService')

local IS_CLIENT = RunService:IsClient()
local HeightLookup = require(RS.Gerstner.HeightLookup)
local OctreeModule = require(RS:WaitForChild('Octree'))

local BOAT_TREE = nil
local DRAG_COEFFICIENT = 0.075

type ZONE_INFO = {
	SpeedMultiplier: number,
	AmplitudeMultiplier: number,
	PhaseMultiplier: number,
	CURRENT_ZONE: {}?,
}

local BoatManager = {}

function BoatManager.CalculateBuoyancy(CenterOfMass: Vector3, Bottom: Vector3, Points: { Attachment }, Length: number, Width: number, Height: number, ZoneInfo: ZONE_INFO): (Vector3, CFrame, number)
	local TopLeftHeight = HeightLookup.Lookup(Points[1].WorldPosition, "PRECISE", false, ZoneInfo.SpeedMultiplier, ZoneInfo.PhaseMultiplier, ZoneInfo.AmplitudeMultiplier, ZoneInfo.CURRENT_ZONE)
	local TopRightHeight = HeightLookup.Lookup(Points[2].WorldPosition, "PRECISE", false, ZoneInfo.SpeedMultiplier, ZoneInfo.PhaseMultiplier, ZoneInfo.AmplitudeMultiplier, ZoneInfo.CURRENT_ZONE)
	local BottomLeftHeight = HeightLookup.Lookup(Points[3].WorldPosition, "PRECISE", false, ZoneInfo.SpeedMultiplier, ZoneInfo.PhaseMultiplier, ZoneInfo.AmplitudeMultiplier, ZoneInfo.CURRENT_ZONE)
	local BottomRightHeight = HeightLookup.Lookup(Points[4].WorldPosition, "PRECISE", false, ZoneInfo.SpeedMultiplier, ZoneInfo.PhaseMultiplier, ZoneInfo.AmplitudeMultiplier, ZoneInfo.CURRENT_ZONE)

	local TotalHeight = (TopLeftHeight + TopRightHeight + BottomLeftHeight + BottomRightHeight)

	-- // Orientation
	local Front = (TopLeftHeight + TopRightHeight) / 2
	local Back = (BottomLeftHeight + BottomRightHeight) / 2
	local Left = (TopLeftHeight + BottomLeftHeight) / 2
	local Right = (TopRightHeight + BottomRightHeight) / 2

	local pitch = math.atan2(Front - Back, Length)
	local roll = math.atan2(Right - Left, Width)

	local Orientation = CFrame.fromEulerAnglesXYZ(pitch, 0, roll)


	local WaveHeightCenter = (TotalHeight / 4)
	local Depth = WaveHeightCenter - Bottom.Y
	if Depth > -0.5 then
		local ClampedDepth = math.min(Depth, 0)
		local TargetHeight = (WaveHeightCenter + ClampedDepth)
		local RelativeSpeed = (CenterOfMass.Y - TargetHeight)
		local DRAG = RelativeSpeed * DRAG_COEFFICIENT

		local TargetY = (WaveHeightCenter + Height) - DRAG
		return Vector3.new(0, TargetY, 0), Orientation, ClampedDepth

	elseif Depth < -0.25 then
		return Vector3.zero, Orientation, 0
	end
	return Vector3.zero, Orientation, 0
end

return BoatManager


Helper Module

--!native
--!optimize 2
--!strict

local Camera = workspace.Camera

local FOV = math.tan(math.rad(Camera.FieldOfView) / 2)
local ViewportRatio = (Camera.ViewportSize.X / Camera.ViewportSize.Y)
Camera:GetPropertyChangedSignal('DiagonalFieldOfView'):Connect(function()
	FOV = math.tan(math.rad(Camera.FieldOfView) / 2)
end)

Camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
	ViewportRatio = (Camera.ViewportSize.X / Camera.ViewportSize.Y)
end)

local Helper = {}
local _settings = require(script.Parent.Settings)

local v3 = Vector3.new
local v2 = Vector2.new
local acos = math.acos
local max = math.max
local min = math.min
local fmod = math.fmod
local clamp = math.clamp

local sqrt = math.sqrt
local pow = math.pow

local BAND = bit32.band

local COLOR_LOW, COLOR_HIGH =_settings.WAVE_COLORS.TROUGH, _settings.WAVE_COLORS.CREST
local SHORE_COLOR = _settings.WAVE_COLORS.SHORE
local VORTEX_LOW = _settings.WAVE_COLORS.VORTEX
local WHITECAP = Color3.new(1, 1, 1)

local SCROLL_DIRECTION_X, SCROLL_DIRECTION_Y = _settings.UV_SCROLL_DIRECTION.X, _settings.UV_SCROLL_DIRECTION.Y
local DEPTH_RAY = _settings.DEPTH_RAY_LENGTH
local DEPTH_RAY_OFFSET = _settings.DEPTH_RAY_OFFSET
local UV_SCROLL_SPEED = _settings.UV_SCROLL_SPEED
local SHORE_TRANSPARENCY = _settings.SHORE_TRANSPARENCY

local CHUNK_SIZE = _settings.GRID_SETTINGS.CHUNK_SIZE
local CHUNK_OFFSETS = {
	Vector3.new(CHUNK_SIZE, 0, CHUNK_SIZE),
	Vector3.new(-CHUNK_SIZE, 0, -CHUNK_SIZE),
	Vector3.new(CHUNK_SIZE, 0, -CHUNK_SIZE),
	Vector3.new(-CHUNK_SIZE, 0, CHUNK_SIZE),

	Vector3.new(0, -CHUNK_SIZE, 0) -- // An addition point placed at the bottom so that the camera being underwater won't bug out the frustum checks
}

local GOLDEN_RATIO = 1.618

local IslandParameters = RaycastParams.new()
IslandParameters.FilterDescendantsInstances = { workspace.Map }
IslandParameters.FilterType = Enum.RaycastFilterType.Include

export type ZoneParameters = {
	Type: string,
	Link: BasePart,
	Radius: number,

	PhaseMultiplier: number,
	SpeedMultiplier: number,
	AmplitudeMultiplier: number,

	Island: any?,
	Despawn: boolean?,

	FullDecayAt: number?,
	DissolveTime: number?,
}

function Helper.GetTableLength(Table: {[any]: any}): number
	local n = 0
	for i, v in Table do
		n += 1
	end
	return n
end

function Helper.GetFrustumPlanes(Distance: number, CamCF: CFrame): (number, number, number, Vector3, Vector3, Vector3, Vector3, CFrame)
	local cameraCFrame = CamCF
	local cameraPos = cameraCFrame.Position
	local rightVec, upVec = cameraCFrame.RightVector, cameraCFrame.UpVector

	local farPlaneCFrame = cameraCFrame * CFrame.new(0, 0, -Distance)

	local distance2 = Distance / 2
	local farPlaneHeight2 = FOV * Distance
	local farPlaneWidth2 = farPlaneHeight2 * ViewportRatio
	local farPlaneTopRight = farPlaneCFrame * Vector3.new(farPlaneWidth2, farPlaneHeight2, 0)
	local farPlaneBottomLeft = farPlaneCFrame * Vector3.new(-farPlaneWidth2, -farPlaneHeight2, 0)
	local farPlaneBottomRight = farPlaneCFrame * Vector3.new(farPlaneWidth2, -farPlaneHeight2, 0)

	local frustumCFrameInverse = (cameraCFrame * CFrame.new(0, 0, -distance2)):Inverse()

	local rightNormal = upVec:Cross(farPlaneBottomRight - cameraPos).Unit
	local leftNormal = (farPlaneBottomLeft - cameraPos):Cross(upVec).Unit
	local topNormal = (farPlaneTopRight - cameraPos):Cross(rightVec).Unit
	local bottomNormal = rightVec:Cross(farPlaneBottomRight - cameraPos).Unit

	-- // distance2, farPlaneHeight2, farPlaneWidth2,    rightNormal, leftNormal, topNormal, bottomNormal, frustumCFrameInverse
	return distance2, farPlaneHeight2, farPlaneWidth2,    rightNormal, leftNormal, topNormal, bottomNormal, frustumCFrameInverse

end

function Helper.IsInView(Point: Vector3, CameraCF: CFrame, distance2: number, farPlaneHeight2: number, farPlaneWidth2: number, rightNormal: Vector3, leftNormal: Vector3, topNormal: Vector3, bottomNormal: Vector3, frustumCFrameInverse: CFrame): boolean	
	local relativeToOBB = frustumCFrameInverse * Point
	if
		relativeToOBB.X > farPlaneWidth2
		or relativeToOBB.X < -farPlaneWidth2
		or relativeToOBB.Y > farPlaneHeight2
		or relativeToOBB.Y < -farPlaneHeight2
		or relativeToOBB.Z > distance2
		or relativeToOBB.Z < -distance2
	then
		return false
	end

	local lookToPoint = Point - CameraCF.Position
	if
		rightNormal:Dot(lookToPoint) < 0
		or leftNormal:Dot(lookToPoint) < 0
		or topNormal:Dot(lookToPoint) < 0
		or bottomNormal:Dot(lookToPoint) < 0
	then
		return false
	end
	return true
end

function Helper.IsChunkInView(Point: Vector3, CameraCF: CFrame, distance2: number, farPlaneHeight2: number, farPlaneWidth2: number, rightNormal: Vector3, leftNormal: Vector3, topNormal: Vector3, bottomNormal: Vector3, frustumCFrameInverse: CFrame): boolean	
	local Original = Point
	for i = 1, 6 do
		if i ~= 1 then
			Point = Original + CHUNK_OFFSETS[i - 1]
		end
		local relativeToOBB = frustumCFrameInverse * Point
		if
			relativeToOBB.X > farPlaneWidth2
			or relativeToOBB.X < -farPlaneWidth2
			or relativeToOBB.Y > farPlaneHeight2
			or relativeToOBB.Y < -farPlaneHeight2
			or relativeToOBB.Z > distance2
			or relativeToOBB.Z < -distance2
		then
			continue
		end

		local lookToPoint = Point - CameraCF.Position
		if
			rightNormal:Dot(lookToPoint) < 0
			or leftNormal:Dot(lookToPoint) < 0
			or topNormal:Dot(lookToPoint) < 0
			or bottomNormal:Dot(lookToPoint) < 0
		then
			continue
		end
		return true
	end
	return false
end

function Helper.GetVertexColor(TransformY: number, VortexY: number, AlphaTransparency: number): Color3
	if TransformY < -1 then
		TransformY = -1
	end

	local VertexColor = COLOR_LOW:Lerp(COLOR_HIGH, min(((TransformY + -1) * 4)  / 30, 1))
	if AlphaTransparency < 1 then
		return VertexColor:Lerp(SHORE_COLOR, 1 - (AlphaTransparency / GOLDEN_RATIO))
	end

	if TransformY > _settings.WHITECAP_HEIGHT then
		-- // We'll do a mini-version of 'whitecaps' / 'foam' by changing the color to be white if the wave is steeper than usual
		VertexColor = VertexColor:Lerp(WHITECAP, (TransformY - _settings.WHITECAP_HEIGHT) / 10)
	end

	if VortexY < 0 then
		return VertexColor:Lerp(VORTEX_LOW, min(-VortexY / 60, 1))
	end
	return VertexColor
end

function Helper.GetVertexTransparency(VertexPosition: Vector3, Array: SharedTable, NormalizedDistanceToIsland: number): number
	if _settings.DEPTH_ENABLED == false then
		return 1
	end
	-- // alpha 1 = no transparency, alpha 0 = transparent
	-- // I would also like to note SharedTable's being way less performant than regular tables, which is very sad

	if NormalizedDistanceToIsland > 0.6 then
		return 1
	end

	local X, Z = VertexPosition.X, VertexPosition.Z
	local Hashed = Helper.HashVector(X, Z)

	if Array[Hashed] ~= nil then
		return Array[Hashed]
	end

	local Result = workspace:Raycast(VertexPosition + DEPTH_RAY_OFFSET, DEPTH_RAY, IslandParameters)
	if Result == nil then
		Array[Hashed] = 1
		return 1
	end

	local Depth = Result.Distance
	local Alpha = 1
	if Depth < 5 then
		Alpha = SHORE_TRANSPARENCY
	else
		Alpha = 0.2 + (Depth / 15)
	end
	Array[Hashed] = Alpha
	return Alpha
end

function Helper.IsVertexNearShore(VertexTransparency: number): boolean
	if VertexTransparency < 0.85 then
		return true
	end
	return false
end

function Helper.GetUV(UV: Vector2, t: number): Vector2
	local Scroll = -fmod(t * UV_SCROLL_SPEED, 1) -- TODO: Could probably optimize(?) by using something else in place of modulo
	local AdjustedUV = UV + v2(Scroll * SCROLL_DIRECTION_X, Scroll * SCROLL_DIRECTION_Y)
	return AdjustedUV
end


function Helper.Lerp(a: Vector3, b: Vector3, Alpha: number): Vector3
	return v3(
		a.X + (b.X - a.X) * Alpha,
		a.Y + (b.Y - a.Y) * Alpha,
		a.Z + (b.Z - a.Z) * Alpha
	)
end

function Helper.PointInEllipse(Point: Vector3, Center: Vector3, Size: Vector3): boolean
	local a = Size.X / 2
	local b = Size.Z / 2
	local deltaX = (Point.X - Center.X) / a
	local deltaZ = (Point.Z - Center.Z) / b
	local distanceSquared = (deltaX*deltaX) + (deltaZ*deltaZ)

	return distanceSquared <= 1
end

function Helper.ScaledDistance(Point: Vector3, Center: Vector3, Size: Vector3, Exponent: number): (number, number)
	local a = Size.X / 2
	local b = Size.Z / 2
	local deltaX = (Point.X - Center.X) / a
	local deltaZ = (Point.Z - Center.Z) / b

	local radialDistance = sqrt((deltaX*deltaX) + (deltaZ*deltaZ))
	local adjustedDistance = pow(radialDistance, Exponent)

	return max(0, 1 - adjustedDistance), max(0, 1 - radialDistance)
end

function Helper.GetIslandMultipliers(Point: Vector3, IslandPosition: Vector3, Radius: number): (number, number, number, boolean, number)
	local IslandPosition: Vector3 = IslandPosition
	local Distance = (Point - IslandPosition).Magnitude
	local SpeedMultiplier, PhaseMultiplier, AmplitudeMultiplier = 1, 1, 1
	local InRadius = Distance < Radius
	local NormalizedDistance = 1

	if InRadius then
		local Factor = Distance / Radius
		NormalizedDistance = Factor

		SpeedMultiplier = _settings.ISLAND_SPEED_MULTIPLIER
		PhaseMultiplier = _settings.ISLAND_PHASE_MULTIPLIER
		AmplitudeMultiplier = Factor
	end
	return SpeedMultiplier, PhaseMultiplier, AmplitudeMultiplier, InRadius, NormalizedDistance
end

function Helper.GetZoneMultipliers(Point: Vector3, ZonePosition: Vector3, ZoneParameters: ZoneParameters): (number, number, number, boolean)
	local Radius = ZoneParameters.Radius
	local Distance = (Point - ZonePosition).Magnitude

	local SpeedMultiplier, PhaseMultiplier, AmplitudeMultiplier = 1, 1, 1
	local InRadius = Distance < Radius
	if InRadius then
		local InverseRatio = 1 - (Distance / Radius)
		local Scaled = 1 + (ZoneParameters.AmplitudeMultiplier - 1) * InverseRatio

		SpeedMultiplier = ZoneParameters.SpeedMultiplier
		PhaseMultiplier = ZoneParameters.PhaseMultiplier
		AmplitudeMultiplier = Scaled
	end
	return SpeedMultiplier, PhaseMultiplier, AmplitudeMultiplier, InRadius
end

function Helper.HashVector(X: number, Z: number): number
	-- https://www.beosil.com/download/CollisionDetectionHashing_VMV03.pdf

	-- // Luau numbers are a double-precision (64-bit) floating-point number
	-- // However, the SharedTable limit is a nonnegative integer that can only go up to 2^32,
	-- //	So we'll bitwise AND it to 0xFFFFFFFF to ensure it's positive + stays within the 2^32 range
	-- //	Overall, we should be able to safely hash vectors in a large range, which is more than enough for our case

	return BAND((X * 73856093) + (Z * 83492791), 0xFFFFFFFF)
end

return Helper

Type module
export type VertexKey = {
	VertexId: number,
	ColorId: number,
	UVId: number,

	UV: Vector2,
	Position: Vector3,

	Lerping: boolean,
	CurrentFrame: number,

	GoalPosition: Vector3,
	LastPosition: Vector3,

	AlphaTransparency: number,
	CurrentColor: Color3,
	QUALITY_LEVEL: number,
}
export type ChunkKey = {
	Rendering: boolean,
	ISLAND: {number | any} | nil,
	ZONE: {number | any} | nil,
}

export type Computations = { {Vector3 | Color3 | number | Vector2 | nil} }

return {}



Octree module
--!strict
--!native
--!optimize 2

export type Octree<T> = {
	ClearAllNodes: (self: Octree<T>) -> (),
	GetAllNodes: (self: Octree<T>) -> { Node<T> },
	ForEachNode: (self: Octree<T>) -> () -> Node<T>?,
	FindFirstNode: (self: Octree<T>, object: T) -> Node<T>?,
	CountNodes: (self: Octree<T>) -> number,
	CreateNode: (self: Octree<T>, position: Vector3, object: T) -> Node<T>,
	RemoveNode: (self: Octree<T>, node: Node<T>) -> (),
	ChangeNodePosition: (self: Octree<T>, node: Node<T>, position: Vector3) -> (),
	SearchRadius: (self: Octree<T>, position: Vector3, radius: number) -> { Node<T> },
	ForEachInRadius: (self: Octree<T>, position: Vector3, radius: number) -> () -> Node<T>?,
	GetNearest: (self: Octree<T>, position: Vector3, radius: number, maxNodes: number?) -> { Node<T> },
}

type OctreeInternal<T> = Octree<T> & {
	Size: number,
	Regions: { Region<T> },
	_getRegion: (self: OctreeInternal<T>, maxLevel: number, position: Vector3) -> Region<T>,
}

type Region<T> = {
	Center: Vector3,
	Size: number,
	Radius: number,
	Regions: { Region<T> },
	Parent: Region<T>?,
	Level: number,
	Nodes: { Node<T> }?,
}

export type Node<T> = {
	Position: Vector3,
	Object: T,
}

type NodeInternal<T> = Node<T> & {
	Region: Region<T>?,
}

local MAX_SUB_REGIONS = 4
local DEFAULT_TOP_REGION_SIZE = 512

local function IsPointInBox(point: Vector3, boxCenter: Vector3, boxSize: number)
	local half = boxSize / 2
	return point.X >= boxCenter.X - half
		and point.X <= boxCenter.X + half
		and point.Y >= boxCenter.Y - half
		and point.Y <= boxCenter.Y + half
		and point.Z >= boxCenter.Z - half
		and point.Z <= boxCenter.Z + half
end

local function RoundTo(x: number, mult: number): number
	return math.round(x / mult) * mult
end

local function SwapRemove(tbl, index)
	local n = #tbl
	tbl[index] = tbl[n]
	tbl[n] = nil
end

local function CountNodesInRegion<T>(region: Region<T>)
	local n = 0
	if region.Nodes then
		return #region.Nodes
	else
		for _, subRegion in ipairs(region.Regions) do
			n += CountNodesInRegion(subRegion)
		end
	end
	return n
end

local function GetTopRegion<T>(octree, position: Vector3, create: boolean): Region<T>
	local size = octree.Size
	local origin = Vector3.new(RoundTo(position.X, size), RoundTo(position.Y, size), RoundTo(position.Z, size))
	local region = octree.Regions[origin]
	if not region and create then
		region = {
			Regions = {},
			Level = 1,
			Size = size,
			Radius = math.sqrt(size * size + size * size + size * size),
			Center = origin,
		}
		table.freeze(region)
		octree.Regions[origin] = region
	end
	return region
end

local function GetRegionsInRadius<T>(octree, position: Vector3, radius: number): { Region<T> }
	local regionsFound = {}
	local function ScanRegions(regions: { Region<T> })
		-- Find regions that have overlapping radius values
		for _, region in ipairs(regions) do
			local distance = (position - region.Center).Magnitude
			if distance < (radius + region.Radius) then
				if region.Nodes then
					table.insert(regionsFound, region)
				else
					ScanRegions(region.Regions)
				end
			end
		end
	end
	local startRegions = {}
	local size = octree.Size
	local maxOffset = math.ceil(radius / size)
	if radius < octree.Size then
		-- Find all surrounding regions in a 3x3 cube:
		for i = 0, 26 do
			-- Get surrounding regions:
			local x = i % 3 - 1
			local y = math.floor(i / 9) - 1
			local z = math.floor(i / 3) % 3 - 1
			local offset = Vector3.new(x * radius, y * radius, z * radius)
			local startRegion = GetTopRegion(octree, position + offset, false)
			if startRegion and not startRegions[startRegion] then
				startRegions[startRegion] = true
				ScanRegions(startRegion.Regions)
			end
		end
	elseif maxOffset <= 3 then
		-- Find all surrounding regions:
		for x = -maxOffset, maxOffset do
			for y = -maxOffset, maxOffset do
				for z = -maxOffset, maxOffset do
					local offset = Vector3.new(x * size, y * size, z * size)
					local startRegion = GetTopRegion(octree, position + offset, false)
					if startRegion and not startRegions[startRegion] then
						startRegions[startRegion] = true
						ScanRegions(startRegion.Regions)
					end
				end
			end
		end
	else
		-- If radius is larger than the surrounding regions will detect, then
		-- we need to use a different algorithm to pickup the regions. Ideally,
		-- we won't be querying with huge radius values, but this is here in
		-- cases where that happens. Just scan all top-level regions and check
		-- the distance.
		for _, region in octree.Regions do
			local distance = (position - region.Center).Magnitude
			if distance < (radius + region.Radius) then
				ScanRegions(region.Regions)
			end
		end
	end
	return regionsFound
end

local Octree = {}
Octree.__index = Octree

local function CreateOctree<T>(topRegionSize: number?): Octree<T>
	local self = (setmetatable({}, Octree) :: unknown) :: OctreeInternal<T>
	self.Size = if topRegionSize then topRegionSize else DEFAULT_TOP_REGION_SIZE
	self.Regions = {} :: { Region<T> }
	return self
end

local function GetNodes(regions, all)
	for _, region in regions do
		local nodes = region.Nodes
		if nodes then
			table.move(nodes, 1, #nodes, #all + 1, all)
		else
			GetNodes(region.Regions, all)
		end
	end
end

function Octree:ClearAllNodes()
	table.clear(self.Regions)
end

function Octree:GetAllNodes<T>(): { Node<T> }
	local all = {}
	GetNodes(self.Regions, all)
	return all
end

function Octree:ForEachNode<T>(regions): () -> Node<T>?
	local function GetNodes()
		for _, region in regions or self.Regions do
			local nodes = region.Nodes
			if nodes then
				for _, node in nodes do
					coroutine.yield(node)
				end
			else
				GetNodes()
			end
		end
	end
	return coroutine.wrap(GetNodes)
end

function Octree:FindFirstNode<T>(object: T): Node<T>?
	for node: Node<T> in self:ForEachNode() do
		if node.Object == object then
			return node
		end
	end
	return nil
end

function Octree:CountNodes(): number
	return #self:GetAllNodes()
end

function Octree:CreateNode<T>(position: Vector3, object: T): Node<T>
	local region = (self :: OctreeInternal<T>):_getRegion(MAX_SUB_REGIONS, position)
	local node: Node<T> = {
		Region = region,
		Position = position,
		Object = object,
	}
	if region.Nodes then
		table.insert(region.Nodes, node)
	else
		error("region does not contain nodes array")
	end
	return node
end

function Octree:RemoveNode<T>(node: NodeInternal<T>)
	if not node.Region then
		return
	end
	local nodes = (node.Region :: Region<T>).Nodes :: { Node<T> }
	local index = table.find(nodes, node)
	if index then
		SwapRemove(nodes, index)
	end
	if #nodes == 0 then
		-- Remove regions without any nodes:
		local region = node.Region
		while region do
			local parent = region.Parent:: Region<T>
			if parent then
				local numNodes = CountNodesInRegion(region)
				if numNodes == 0 then
					local regionIndex = table.find(parent.Regions, region)
					if regionIndex then
						SwapRemove(parent.Regions, regionIndex)
					end
				end
			end
			region = parent
		end
	end
	node.Region = nil
end

function Octree:ChangeNodePosition<T>(node: NodeInternal<T>, position: Vector3)
	node.Position = position
	local newRegion = self:_getRegion(MAX_SUB_REGIONS, position)
	if newRegion == node.Region then
		return
	end
	table.insert(newRegion.Nodes, node)
	self:RemoveNode(node)
	node.Region = newRegion
end

function Octree:SearchRadius<T>(position: Vector3, radius: number): { Node<T> }
	local nodes = {}
	local regions = GetRegionsInRadius(self, position, radius)
	for _, region in ipairs(regions) do
		if region.Nodes ~= nil then
			for _, node: Node<T> in ipairs(region.Nodes) do
				if (node.Position - position).Magnitude < radius then
					table.insert(nodes, node)
				end
			end
		end
	end
	return nodes
end

function Octree:ForEachInRadius<T>(position: Vector3, radius: number): () -> Node<T>?
	local regions = GetRegionsInRadius(self, position, radius)
	return coroutine.wrap(function()
		for _, region: Region<T> in ipairs(regions) do
			if region.Nodes ~= nil then
				for _, node: Node<T> in ipairs(region.Nodes) do
					if (node.Position - position).Magnitude < radius then
						coroutine.yield(node)
					end
				end
			end
		end
	end)
end

function Octree:GetNearest<T>(position: Vector3, radius: number, maxNodes: number?): { Node<T> }
	local nodes = self:SearchRadius(position, radius)
	table.sort(nodes, function(n0: Node<T>, n1: Node<T>)
		local d0 = (n0.Position - position).Magnitude
		local d1 = (n1.Position - position).Magnitude
		return d0 < d1
	end)
	if maxNodes ~= nil and #nodes > maxNodes then
		return table.move(nodes, 1, maxNodes, 1, table.create(maxNodes))
	end
	return nodes
end

function Octree:_getRegion<T>(maxLevel: number, position: Vector3): Region<T>
	local function GetRegion(regionParent: Region<T>?, regions: { Region<T> }, level: number): Region<T>
		local region: Region<T>? = nil
		-- Find region that contains the position:
		for _, r in regions do
			if IsPointInBox(position, r.Center, r.Size) then
				region = r
				break
			end
		end
		if not region then
			-- Create new region:
			local size = (self :: OctreeInternal<T>).Size / (2 ^ (level - 1))
			local origin = if regionParent
				then regionParent.Center
				else Vector3.new(RoundTo(position.X, size), RoundTo(position.Y, size), RoundTo(position.Z, size))
			local center = origin
			if regionParent then
				-- Offset position to fit the subregion within the parent region:
				center += Vector3.new(
					if position.X > origin.X then size / 2 else -size / 2,
					if position.Y > origin.Y then size / 2 else -size / 2,
					if position.Z > origin.Z then size / 2 else -size / 2
				)
			end
			local newRegion: Region<T> = {
				Regions = {},
				Level = level,
				Size = size,
				-- Radius represents the spherical radius that contains the entirety of the cube region
				Radius = math.sqrt(size * size + size * size + size * size),
				Center = center,
				Parent = regionParent,
				Nodes = if level == MAX_SUB_REGIONS then {} else nil,
			}
			table.freeze(newRegion)
			table.insert(regions, newRegion)
			region = newRegion
		end
		if level == maxLevel then
			-- We've made it to the bottom-tier region
			return region :: Region<T>
		else
			-- Find the sub-region:
			return GetRegion(region :: Region<T>, (region :: Region<T>).Regions, level + 1)
		end
	end
	local startRegion = GetTopRegion(self, position, true)
	return GetRegion(startRegion, startRegion.Regions, 2)
end

Octree.__iter = Octree.ForEachNode

return {
	new = CreateOctree,
}



Genstner module have Heightlookup
Helper settings type module
Octree and gerstner exist together under replicated storage
Gerstner have a folder named serial contain boatmanager and setup and zone manager module


Client script that use the module
--!strict
--!native
--!optimize 2

--[[
	Gerstner Wave System
	@FlameEmber06
	
	Special thanks to @N0tKep, @SkySickz, @NewPuncher and @excuseslewis
	
	Simulates an ocean system on a mesh plane, with Gerstner waves.
	Uses Luau's parallel framework to run the ocean on multiple threads.
	
	Features:
		- Multithreading (Parallel Lua)
		- Frustum culling
		- Vertex lerping / LOD for vertices far from the camera
		- Customizable settings for the ocean
		- Infinite (ocean plane repositions to follow the camera)
		- Vertex coloring / Depth coloring
		- UV texture scrolling
		- Accurate & performant height lookups
			- Buoyancy / BoatManager module for boats
		- ZoneManager system, allowing for custom ocean zones with different parameters
		- Whirlpools
		- Subdivided mesh which acts as a grid
		- Shorelines (vertices are slightly transparent and colored differently near shallow water)
		
	Future Improvements:
		- Bulk updates for :SetPosition() [ROBLOX has no API for this yet]
		- Ocean tides
		
		- Plane instancing: Have multiple planes around you in a grid, all linked to the same EditableMesh.
			Note: You'd have to disable Frustum Culling for this to work properly, or have a second "low-res" EditableMesh 
			that has all its vertices also updated and instance that one around the 'main' ocean plane. Would allow you to stretch the
			ocean much further than you currently can with this system.
		
		- Calculate normals: Normals aren't calculated for the ocean, although this is relatively easy to do, 
			and I've implemented the functions for doing so in the Gerstner module already.
		
		- Better Subsurface Scattering: Instead of simply coloring waves on height, can also have the color depend on the angle of
			the camera towards the ocean plane, as well as the sun's direction to be more realistic.
			For those interested in approaching this, I'd recommend looking into the Fresnel effect.
		
		- Better Zone Handling: Instead of zones just being simple multipliers on the wave parameters, it'd be better to assign them
			their own wave parameters and smoothly interpolate between a set of wave parameters to the other 
			depending on distance.
	
	Limitations:
		Height Lookup: This relies on computing triangles based on a flat grid, but if vertices are very deformed on the XZ axis, there's a 
			good chance that the height lookup will fail due to the function scanning the wrong triangles. I've added a workaround to this,
			but there can still be incorrect heights given if the vertices are extremely deformed.
		   
		Whirlpool UV rotation: Due to the UV's of the ocean itself being rotated near whirlpools, there is UV distortion around
			the borders of the whirlpool.
			
		Vertex Popping: Due to the way LOD is handled, vertices can occasionally 'pop' when the ocean plane readjusts itself to follow
			the camera, depending on your wave parameters. This is specifically due to the LOD having no smooth transition 
			between different levels. If anyone wants to improve upon the system, I recommend looking into Continuous LOD systems (CLOD)
		
]]

local AssetService = game:GetService('AssetService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local SharedTableRegistry = game:GetService('SharedTableRegistry')

local GerstnerWave = require(ReplicatedStorage.Gerstner)
local Helper = require(ReplicatedStorage.Gerstner.Helper)
local HeightLookup = require(ReplicatedStorage.Gerstner.HeightLookup)
local _settings = require(ReplicatedStorage.Gerstner.Settings)
local Types = require(ReplicatedStorage.Gerstner.Types)

local clamp = math.clamp
local XZ_INCLUDE = Vector3.new(1, 0, 1)
local Y_AXIS = Vector3.yAxis
local v3new = Vector3.new
local v3zero = Vector3.zero
local v3one = Vector3.one

local LERP_MAX_FRAMES = 30 -- // How many frames a vertex will 'lerp' for
local WORKER_COUNT = _settings.WORKER_COUNT

local GRID_SETTINGS = _settings.GRID_SETTINGS
local Camera = workspace.Camera

local Actor: Actor? = script:GetActor()
local LastPlanePosition = Vector3.zero
GerstnerWave:SET_SETTINGS(GRID_SETTINGS.Padding, GRID_SETTINGS.Width, GRID_SETTINGS.Length, GRID_SETTINGS.PaddingMultiplier, GRID_SETTINGS.UV_SCALE)

do
	-- // This is the "main" thread that will set up all the workers
	-- // as well as the EditableMesh (Plane)

	local ChunkCount = 0

	local BoatManager = require(ReplicatedStorage.Gerstner.Serial.BoatManager)
	local ZoneManager = require(ReplicatedStorage.Gerstner.Serial.ZoneManager)
	local Setup = require(ReplicatedStorage.Gerstner.Serial.Setup)


	local VertexPositionToId: { [Vector3]: number } = {}
	local VertexInfo: { [number]: Types.VertexKey } = {}
	local CI = {}
	local ChunkInfo: { [Vector3]: Types.ChunkKey } = {}

	local _CHUNKS = {}
	local _QUADS: any = {}
	local _TRIANGLES: any = {}

	Setup._QUADS = _QUADS
	Setup._TRIANGLES = _TRIANGLES
	Setup.VertexPositionToId = VertexPositionToId
	Setup.VertexInfo = VertexInfo
	Setup.SETTINGS = table.clone(GRID_SETTINGS)

	local function SetupSecondaryIds(EditableMesh: EditableMesh, Info: { Types.VertexKey })
		-- // We grab the colors and UVs of the EditableMesh, each linked to a certain vertex
		-- // so that we can apply them to the specific vertex later on

		for i, ColorId in EditableMesh:GetColors() do
			local VertexId = EditableMesh:GetVerticesWithAttribute(ColorId)[1]
			if Info[VertexId] then
				Info[VertexId].ColorId = ColorId
				EditableMesh:SetColor(ColorId, Helper.GetVertexColor(0, 0, 1))
			end
		end
		for i, UVId in EditableMesh:GetUVs() do
			local VertexId = EditableMesh:GetVerticesWithAttribute(UVId)[1]
			if Info[VertexId] then
				Info[VertexId].UVId = UVId
				EditableMesh:SetUV(UVId, Info[VertexId].UV)
			end
		end
	end

	-- // Create a bunch of worker threads and place them under the main thread
	local workers = {}
	for i = 1, _settings.WORKER_COUNT do
		local actor = Instance.new('Actor')
		local ParallelWorker = script.ParallelWorker:Clone()
		ParallelWorker.Enabled = true
		ParallelWorker.Parent = actor
		table.insert(workers, actor)
	end
	for _, actor in workers do
		actor.Parent = script
	end

	local EditableMesh = Setup.SetupEditableMesh() 
	for i, SubdivisionRadius in _settings.Subdivisions do
		Setup.SubdividePlane(SubdivisionRadius:: number, true, EditableMesh)
	end

	local Plane = Setup.GetPlaneFromEditableMesh(EditableMesh, nil)
	if _settings.DEPTH_ENABLED == true then
		-- // TODO: Remove this if statement when ROBLOX fixes mesh transparency bug
		Plane.Transparency = 0.015
		warn('WARNING: "DEPTH_ENABLED" setting is set to true, which may lead to some render issues.\nSee known issues section in: https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293')
	end

	if _settings.FRUSTUM_CULLING_FIX == true then
		-- // Because of a bounding box issue with ROBLOX's frustum culling, we'll insert a highlight into the ocean plane so that it is rendered
		-- // at all times. ROBLOX has plans to fix this, but until then, we need to insert a highlight to force rendering.
		Instance.new('Highlight', Plane).Enabled = false
	end

	do
		-- // Begin creating chunks based off the vertices of the mesh
		-- // We'll be using these chunks in order to update the vertices in an optimized manner

		local CHUNK_SIZE = GRID_SETTINGS.CHUNK_SIZE
		for _, VertexId in EditableMesh:GetVertices() do
			if VertexInfo[VertexId] == nil then
				continue
			end
			local Position = Plane.CFrame * EditableMesh:GetPosition(VertexId)
			Position = v3new(math.round(Position.X / CHUNK_SIZE) * CHUNK_SIZE, 0, math.round(Position.Z / CHUNK_SIZE) * CHUNK_SIZE)
			local Distance = (Position - Plane.Position).Magnitude

			if Distance > _settings.MaxChunkRenderDistance then
				continue
			end

			if _CHUNKS[Position] == nil then
				ChunkCount += 1
				_CHUNKS[Position] = {VertexId}

				local Info: Types.ChunkKey = {
					Rendering = false,
					ISLAND = nil,
				}
				ChunkInfo[Position] = Info
			else
				table.insert(_CHUNKS[Position], VertexId)
			end
		end

		SetupSecondaryIds(EditableMesh, VertexInfo)
	end

	-- // Here, we go over all of the chunks we have and assign them to a worker.
	-- // It is done this way so that each worker has an equal amount of chunks to iterate through
	-- // so the load is balanced across all the workers

	local WorkerAssignments = {}
	local ChunkToWorker = {}
	local i = 0
	for ChunkPosition, Vertices in _CHUNKS do
		i += 1
		local worker_index = (i - 1) % WORKER_COUNT + 1
		table.insert(CI, ChunkPosition)

		if not WorkerAssignments[worker_index] then
			WorkerAssignments[worker_index] = {
				AssignedChunks = {},
				VertexInfo = {},
				ChunkInfo = {},
			}
		end
		for n, VertexId in Vertices do
			WorkerAssignments[worker_index].VertexInfo[VertexId] = VertexInfo[VertexId]
		end
		WorkerAssignments[worker_index].ChunkInfo[ChunkPosition] = ChunkInfo[ChunkPosition]

		table.insert(WorkerAssignments[worker_index].AssignedChunks, ChunkPosition)
		ChunkToWorker[ChunkPosition] = workers[worker_index]
	end

	if _settings.DEBUG == true then
		local TRI_COUNT = Helper.GetTableLength(_TRIANGLES)
		warn(`TOTAL CHUNKS: {ChunkCount}`)
		warn(`WORKER COUNT: {WORKER_COUNT}`)
		warn(`TOTAL TRIANGLES: {TRI_COUNT} ({Helper.GetTableLength(VertexInfo)} VERTICES)`)
	end

	do
		-- // We don't need these tables anymore, so clear them from memory
		Setup._QUADS = nil
		Setup._TRIANGLES = nil
		table.clear(_TRIANGLES)
		table.clear(_QUADS)
		_TRIANGLES = nil
		_QUADS = nil
	end

	local SecondaryPlanes = Setup.SetupSecondaryPlanes(EditableMesh)

	task.defer(function()
		-- // Once our worker table is ready, we loop through it and send a message to
		-- // the worker in order to begin the simulation
		local VertexTransparencyArray = SharedTable.new()
		SharedTableRegistry:SetSharedTable('VertexTransparency', VertexTransparencyArray)

		for worker_index, _DATA in WorkerAssignments do
			local AssignedChunks = _DATA.AssignedChunks
			local AssociatedVertexInfo = _DATA.VertexInfo
			local AssociatedChunkInfo = _DATA.ChunkInfo

			local worker = workers[worker_index]
			if _settings.DEBUG == true then
				warn('Sending compute message to worker ' .. tostring(worker_index) .. ' for chunks ', AssignedChunks)
			end
			worker:SendMessage('Compute', _settings.Waves, Plane, EditableMesh, AssignedChunks, AssociatedVertexInfo, AssociatedChunkInfo, _CHUNKS)
		end

	end)
	HeightLookup.ClientInit(VertexPositionToId, EditableMesh, Plane)

	-- // For the main thread itself, we have our own loop that moves the plane mesh with us
	-- // This allows us to have an 'infinite' effect on the ocean

	local function UpdateIslands()
		local GRID_AREA = GRID_SETTINGS.Width * GRID_SETTINGS.Padding + (GRID_SETTINGS.Width - 1) * GRID_SETTINGS.Padding
		local CameraPosition = Camera.CFrame.Position * XZ_INCLUDE
		local NearbyIslands = ZoneManager.ISLAND_TREE:GetNearest(CameraPosition, GRID_AREA)
		local FilledChunks = {}

		for i, Node in NearbyIslands do
			-- // There are island(s) near the camera, and thus, they are also in our grid			
			local Island, Radius = Node.Object.Island, Node.Object.Radius
			local IslandCenter = Node.Position
			for ChunkOffset, Vertices in _CHUNKS do
				local ChunkPosition = Plane.Position + ChunkOffset
				local Distance = (ChunkPosition - IslandCenter).Magnitude
				if FilledChunks[ChunkOffset] then
					if Distance > FilledChunks[ChunkOffset] then
						continue
					end
				end
				if math.floor(Distance) < Radius then
					local Info: {number | any} = {
						[1] = Island.Center.Position,
						[2] = Radius / 2,
					}
					FilledChunks[ChunkOffset] = Distance
					ChunkInfo[ChunkOffset].ISLAND = Info
					ChunkToWorker[ChunkOffset]:SendMessage('UpdateChunk', ChunkOffset, ChunkInfo[ChunkOffset])
				end
			end
		end
		for ChunkOffset, Vertices in _CHUNKS do
			if FilledChunks[ChunkOffset] == nil then
				local Info = ChunkInfo[ChunkOffset]
				if Info.ISLAND ~= nil then
					Info.ISLAND = nil
					ChunkToWorker[ChunkOffset]:SendMessage('UpdateChunk', ChunkOffset, ChunkInfo[ChunkOffset])
				end
			end
		end
		table.clear(FilledChunks)
	end
	local function UpdateZones()
		local GRID_AREA = GRID_SETTINGS.Width * GRID_SETTINGS.Padding + (GRID_SETTINGS.Width - 1) * GRID_SETTINGS.Padding
		local CameraPosition = Camera.CFrame.Position * XZ_INCLUDE
		local NearbyZones = ZoneManager.ZONE_TREE:GetNearest(CameraPosition, GRID_AREA)

		local FilledChunks = {}

		for i, Node in NearbyZones do
			local ZoneParameters, Radius = Node.Object, Node.Object.Radius

			for ChunkOffset, Vertices in _CHUNKS do
				local ChunkPosition = (Plane.Position + ChunkOffset) * XZ_INCLUDE
				local ZoneCenter = ZoneParameters.Link.Position * XZ_INCLUDE
				local Distance = (ChunkPosition - ZoneCenter).Magnitude

				if math.floor(Distance) < Radius * 2 then
					local Info: {number | any} = {
						[1] = ZoneParameters.Link,
						[2] = ZoneParameters,
					}
					FilledChunks[ChunkOffset] = true
					ChunkInfo[ChunkOffset].ZONE = Info
					ChunkToWorker[ChunkOffset]:SendMessage('UpdateChunk', ChunkOffset, ChunkInfo[ChunkOffset])
				end
			end
		end
		for ChunkOffset, Vertices in _CHUNKS do
			if FilledChunks[ChunkOffset] ~= true then
				local Info = ChunkInfo[ChunkOffset]
				if Info.ZONE ~= nil then
					Info.ZONE = nil
					ChunkToWorker[ChunkOffset]:SendMessage('UpdateChunk', ChunkOffset, ChunkInfo[ChunkOffset])
				end
			end
		end
		table.clear(FilledChunks)
	end

	ZoneManager.ZoneUpdated:Connect(function()
		UpdateZones()
	end)

	while true do
		local dt = task.wait(0.25)
		local distance2, farPlaneHeight2, farPlaneWidth2, rightNormal, leftNormal, topNormal, bottomNormal, frustumCFrameInverse = Helper.GetFrustumPlanes(_settings.FrustumRenderDistance, Camera.CFrame)

		local Padding = GRID_SETTINGS.Padding
		local Multiplier = GRID_SETTINGS.PaddingMultiplier

		local CameraPosition = Camera.CFrame.Position * XZ_INCLUDE
		local modPosition = v3new(CameraPosition.X % (Padding * Multiplier), 0, CameraPosition.Z % (Padding * Multiplier))

		local PlanePosition = Plane.Position
		local ObjectPosition = PlanePosition * Vector3.yAxis + (CameraPosition - modPosition)

		if LastPlanePosition ~= ObjectPosition then
			UpdateIslands()
			UpdateZones()
			Plane.Position = ObjectPosition

			for i, SecondaryPlane in SecondaryPlanes do
				local SP = SecondaryPlane[1]:: MeshPart
				local Offset = SecondaryPlane[2]:: Vector3

				SP.Position = ObjectPosition + Offset
			end
		end

		LastPlanePosition = ObjectPosition
	end
end


And another one a childern under the local client script

--!strict
--!native
--!optimize 2

-- // This is the parallel worker template.
-- // Depending on what WORKER_COUNT is configured to, there will be multiple instances of this script running.
-- // Each thread handles multiple ocean chunks, the total being divided equally between all workers to balance the load.

local AssetService = game:GetService('AssetService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local SharedTableRegistry = game:GetService('SharedTableRegistry')

local GerstnerWave = require(ReplicatedStorage.Gerstner)
local Helper = require(ReplicatedStorage.Gerstner.Helper)
local HeightLookup = require(ReplicatedStorage.Gerstner.HeightLookup)
local _settings = require(ReplicatedStorage.Gerstner.Settings)
local Types = require(ReplicatedStorage.Gerstner.Types)

local clamp = math.clamp
local XZ_INCLUDE = Vector3.new(1, 0, 1)
local Y_AXIS = Vector3.yAxis
local v3new = Vector3.new
local v3zero = Vector3.zero
local v3one = Vector3.one

local LERP_MAX_FRAMES = 30 -- // How many frames a vertex will 'lerp' for
local WORKER_COUNT = _settings.WORKER_COUNT

local GRID_SETTINGS = _settings.GRID_SETTINGS
local Camera = workspace.Camera


local Actor: Actor = script:GetActor()
local LastPlanePosition = Vector3.zero
GerstnerWave:SET_SETTINGS(GRID_SETTINGS.Padding, GRID_SETTINGS.Width, GRID_SETTINGS.Length, GRID_SETTINGS.PaddingMultiplier, GRID_SETTINGS.UV_SCALE)

local RS = game:GetService('RunService')
local ChunkInfo: { [Vector3]: Types.ChunkKey } = {}

Actor:BindToMessage('UpdateChunk', function(Position, Data)
	-- // "Position" should be in local space (Offset)
	ChunkInfo[Position] = Data
end)

local VertexTransparencyArray = SharedTableRegistry:GetSharedTable('VertexTransparency')

Actor:BindToMessage('Compute', function(waves, Plane: MeshPart, EditableMesh: EditableMesh, AssignedChunks: {Vector3}, VI, CI, SerializedChunks) 

	-- // The worker thread has received a message from the main thread to begin simulating the assigned chunks.
	-- // It also sends over the "VertexInfo" table, the "ChunkInfo" table, and the "_CHUNKS" table.
	-- // However, due to these tables being passed over VMs, they are serialized
	-- // So we need to (annoyingly) deserialize them

	local VertexCount = 0
	local VertexInfo: { Types.VertexKey } = {}
	for Key, Info in VI do
		Key = tonumber(Key)
		VertexInfo[Key:: number] = Info
		VertexCount += 1
	end

	for i, Position in CI do
		local v3 = tostring(i)

		local sX, sY, sZ = v3:match("(%-?%d+), (%-?%d+), (%-?%d+)")
		local X, Y, Z = tonumber(sX), tonumber(sY), tonumber(sZ)
		local vec = v3new(X, Y, Z)

		local Info: Types.ChunkKey = {
			Rendering = false,
			ISLAND = nil
		}
		ChunkInfo[vec] = Info
	end

	local _CHUNKS: { [Vector3]: { number } } = {}
	for i,v in SerializedChunks do
		local v3 = tostring(i)

		local sX, sY, sZ = v3:match("(%-?%d+), (%-?%d+), (%-?%d+)")
		local X, Y, Z = tonumber(sX), tonumber(sY), tonumber(sZ)
		local vec = v3new(X, Y, Z)

		_CHUNKS[vec] = v
	end

	-- // Connect to RunService.Heartbeat in parallel.
	-- // We'll begin simulating the assigned chunks we were given
	-- // in this event

	local FOV = Camera.FieldOfView
	Camera:GetPropertyChangedSignal('FieldOfView'):Connect(function()
		FOV = Camera.FieldOfView
	end)
	print('VERTEX COUNT: ', VertexCount)
	local Computations: Types.Computations = table.create(VertexCount + 1):: Types.Computations

	local PlaneSize = Plane.Size
	RS.Heartbeat:ConnectParallel(function(dt: number)
		-- // We store a bunch of variables early on that we'll be repetitively using below,
		-- // this is due to a micro-optimization with __index calls 
		-- // saving slight-moderate performance (depends on the case).
		local CameraCF = Camera.CFrame
		local distance2, farPlaneHeight2, farPlaneWidth2, rightNormal, leftNormal, topNormal, bottomNormal, frustumCFrameInverse = Helper.GetFrustumPlanes(_settings.FrustumRenderDistance, CameraCF)

		local objectCFrame = Plane.CFrame
		local ObjectPosition = Plane.Position
		local CameraPosition = CameraCF.Position
		local CameraXZ = CameraPosition * XZ_INCLUDE
		local VertexCount, VertexCount2 = 0, 0
		local t = workspace:GetServerTimeNow()

		-- // Create an array that will store the results of our parallel calculations
		-- // Since we can't edit the vertices in parallel, we use this table to edit all the vertices at once
		-- // Once we switch back to serial (task.synchronize)

		local Active = false -- // This variable is for determining whether any of the assigned chunks are "active" (rendering)

		debug.profilebegin('Ocean update')

		for i, ChunkOffset in AssignedChunks do
			local ChunkPosition = ObjectPosition + ChunkOffset

			local ChunkData = ChunkInfo[ChunkOffset]
			local DistanceToChunk = (ChunkPosition - CameraXZ).Magnitude
			local LOWER_QUALITY = DistanceToChunk > _settings.LowRenderDistance * 2

			-- // Use frustum culling in order to
			-- // not render any chunks that aren't on the screen
			-- // leading to some moderate performance gains

			if DistanceToChunk > _settings.MaxChunkRenderDistance or Helper.IsChunkInView(ChunkPosition, CameraCF, distance2, farPlaneHeight2, farPlaneWidth2, rightNormal, leftNormal, topNormal, bottomNormal, frustumCFrameInverse) == false then
				ChunkData.Rendering = false
				continue
			end

			Active = true
			local ChunkIsland = ChunkData.ISLAND
			local IslandPosition, IslandRadius = Vector3.zero, 0

			local ChunkZone = ChunkData.ZONE
			local ZonePosition = Vector3.zero
			local ZoneParameters: Helper.ZoneParameters? = nil
			local WhirlpoolParams: Helper.ZoneParameters? = nil

			if ChunkIsland then
				IslandPosition = ChunkIsland[1]:: Vector3
				IslandRadius = ChunkIsland[2]:: number
			end
			if ChunkZone then
				ZonePosition = ChunkZone[1].Position:: Vector3
				ZoneParameters = ChunkZone[2]:: Helper.ZoneParameters
				if ZoneParameters ~= nil and ZoneParameters.Type == 'Whirlpool' then
					WhirlpoolParams = ZoneParameters
				end
			end
			-- // Once the chunk has been validated to be inside the field of view,
			-- // we loop through all of its vertices so we can calculate the next position of it

			local Vertices = _CHUNKS[ChunkOffset]
			for i, VertexId in Vertices do
				local Info = VertexInfo[VertexId]
				local Displacement, Dampening = v3zero, v3one

				local PhaseMultiplier, SpeedMultiplier, AmplitudeMultiplier = 1, 1, 1
				local VertexInIslandRange = false
				local NormalizedDistanceToIsland = 1

				if ChunkIsland then
					debug.profilebegin('Island check')
					local Vertex = Info.Position
					local SeaPosition = Vertex + ObjectPosition
					SpeedMultiplier, PhaseMultiplier, AmplitudeMultiplier, VertexInIslandRange, NormalizedDistanceToIsland = Helper.GetIslandMultipliers(SeaPosition, IslandPosition, IslandRadius)

					debug.profileend()
				end
				if ChunkZone and VertexInIslandRange == false and ZoneParameters ~= nil and ZoneParameters.Type ~= 'Whirlpool' then
					debug.profilebegin('Zone check')
					local Vertex = Info.Position
					local SeaPosition = Vertex + ObjectPosition
					local VertexInRange = false

					SpeedMultiplier, PhaseMultiplier, AmplitudeMultiplier, VertexInRange = Helper.GetZoneMultipliers(SeaPosition, ZonePosition, ZoneParameters:: Helper.ZoneParameters)
					debug.profileend()
				end

				-- // If the distance to the chunk is some considerable away from the camera,
				-- // we don't prioritize rendering on this chunk and instead render it 'slowly',
				-- // using Vector3.Lerp to smoothly transition the vertex from one position to the other
				-- // this allows us to call the Gerstner computation less, at the cost of some smoothness / detail
				-- // however it is unnoticeable due to the distance.
				-- // Has moderate performance gains
				if Info.QUALITY_LEVEL == 2 and ZoneParameters == nil then
					debug.profilebegin('LOW-Chunk')

					local vertex = Info.Position
					VertexCount2 += 1

					local SeaPosition = ObjectPosition + Info.Position
					if ChunkData.Rendering == false or Info.CurrentFrame >= LERP_MAX_FRAMES or Info.Lerping == false or LastPlanePosition ~= ObjectPosition then
						local PreviousGoal = Info.GoalPosition

						-- // If the plane's position changed relative to where we last tracked it,
						-- // we have to forcefully update the vertex, as well as
						-- // the "goal position" of the lerp, otherwise it will look very desynced

						if LastPlanePosition ~= ObjectPosition or Info.Lerping == false or ChunkData.Rendering == false then
							local Transform = GerstnerWave.ComputeTransform(waves, SeaPosition, t, PhaseMultiplier, SpeedMultiplier, AmplitudeMultiplier)
							local Position = vertex + (Transform)

							PreviousGoal = Position
						end

						local Transform = 
							GerstnerWave.ComputeTransform(waves, SeaPosition, t + (dt * LERP_MAX_FRAMES), PhaseMultiplier, SpeedMultiplier, AmplitudeMultiplier)

						Info.GoalPosition = vertex + Transform
						Info.LastPosition = PreviousGoal or EditableMesh:GetPosition(VertexId)

						Info.CurrentFrame = (dt * LERP_MAX_FRAMES)

						Info.Lerping = true
					end

					if Info.Lerping == true then

						-- // We proceed with normal lerping behavior

						local CurrentFrame = Info.CurrentFrame
						local LastPosition = Info.LastPosition
						local GoalPosition = Info.GoalPosition

						local UVId = Info.UVId
						local ColorId = Info.ColorId

						local CurrentLerpPosition = Helper.Lerp(LastPosition, GoalPosition, CurrentFrame / LERP_MAX_FRAMES)

						CurrentFrame += 1
						Info.CurrentFrame = CurrentFrame

						local Transform = CurrentLerpPosition - vertex

						local ShoreTransparency = Helper.GetVertexTransparency(SeaPosition, VertexTransparencyArray, NormalizedDistanceToIsland)
						if Helper.IsVertexNearShore(ShoreTransparency) then
							Dampening += v3new(0, -0.85, 0)
						end

						local UpdateSecondary = true
						if LOWER_QUALITY == true and VertexInIslandRange == false then
							if Info.AlphaTransparency == 1 and Info.CurrentColor == _settings.WAVE_COLORS.TROUGH then
								UpdateSecondary = false
							end
						end

						local VertexColor = LOWER_QUALITY == true and _settings.WAVE_COLORS.TROUGH or Helper.GetVertexColor(Transform.Y, 0, ShoreTransparency)
						Computations[VertexId] = {
							CurrentLerpPosition * Dampening,

							UpdateSecondary == true and ColorId or nil,
							UpdateSecondary == true and VertexColor or nil,

							UVId,
							Helper.GetUV(Info.UV, t),

							UpdateSecondary == true and ShoreTransparency or nil,
						}
						Info.AlphaTransparency = ShoreTransparency
						Info.CurrentColor = VertexColor
					end

					debug.profileend()
					continue
				end

				-- // This section is for high-detail vertices, 
				-- // where we update their position directly according to the Gerstner formula
				-- // each frame, making the waves near the camera look much smoother 

				debug.profilebegin('HIGH-Chunk')
				local vertex = Info.Position
				local ColorId = Info.ColorId
				local UVId = Info.UVId
				local VortexOffsetY = 0

				local SeaPosition = ObjectPosition + vertex
				local ShoreTransparency = Helper.GetVertexTransparency(SeaPosition, VertexTransparencyArray, NormalizedDistanceToIsland)

				local Transform = GerstnerWave.ComputeTransform(waves, SeaPosition, t, PhaseMultiplier, SpeedMultiplier, AmplitudeMultiplier)
				local UpdatedUV = Helper.GetUV(Info.UV, t)
				local FinalPosition = vertex + Transform

				if WhirlpoolParams ~= nil then
					local VortexOffset, UVOffset = GerstnerWave.GetVortexTransform(WhirlpoolParams, SeaPosition, Info.UV, t, ObjectPosition)
					FinalPosition += VortexOffset
					UpdatedUV += UVOffset
					VortexOffsetY = VortexOffset.Y
				end

				-- // We'll further reduce the amplitude if the vertex is near the shore
				if Helper.IsVertexNearShore(ShoreTransparency) then
					Dampening += v3new(0, -0.85, 0)
				end

				Info.Lerping = false
				VertexCount += 1

				local UpdateSecondary = true
				if ShoreTransparency == Info.AlphaTransparency then
					UpdateSecondary = false
				end
				Computations[VertexId] = {
					(FinalPosition * Dampening) + Displacement,

					ColorId,
					Helper.GetVertexColor(Transform.Y, VortexOffsetY, ShoreTransparency),

					UVId,
					UpdatedUV,

					UpdateSecondary == true and ShoreTransparency or nil,
				}
				Info.AlphaTransparency = ShoreTransparency
				debug.profileend()
			end

			ChunkData.Rendering = true
		end

		debug.profileend()

		-- // If we're rendering any chunks, we'll need to update their positions
		-- // to do this, we need to switch back to the serial state (task.synchronize)
		-- // then manually update each vertex and color data

		-- // TODO: Switch to bulk :SetPosition() updates once ROBLOX releases it
		if Active == true then
			task.synchronize()
			debug.profilebegin('Serial Update')

			-- // We have to be sparse with what we update here, as updating too many things at once can lead to very high ms
			-- // ROBLOX batch update function plz

			for VertexId, Result in Computations do
				local ColorId = Result[2]:: number?
				local UVId = Result[4]:: number

				if ColorId ~= nil then
					local Alpha = Result[6]:: number?
					EditableMesh:SetColor(ColorId, Result[3]:: Color3)

					if Alpha ~= nil then
						EditableMesh:SetColorAlpha(ColorId, Alpha)
					end
				end
				EditableMesh:SetPosition(VertexId, Result[1]:: Vector3)
				EditableMesh:SetUV(UVId, Result[5]:: Vector2)
			end

			table.clear(Computations)
			debug.profileend()
		end

		LastPlanePosition = ObjectPosition
	end)

end)



