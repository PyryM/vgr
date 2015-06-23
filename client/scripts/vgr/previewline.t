-- previewline.t
--
-- draws a preview line for orbits

local class = truss_import("core/30log.lua")
local matrixlib = truss_import("math/matrix.t")
local quatlib = truss_import("math/quat.t")
local Matrix4 = matrixlib.Matrix4
local Quaternion = quatlib.Quaternion
local OrbitCam = truss_import("gui/orbitcam.t")
local Line = truss_import("mesh/line.t")
local integrator = truss_import("vgr/integrator.t")

local PreviewLine = class("PreviewLine")

local function calcOrbitVel(gm0, rad)
	local ret = math.sqrt(gm0 / rad) / rad
	trss.trss_log(0, "Moonvel: " .. ret)
	return ret
end

function PreviewLine:init(renderer)
	self.linepoints = {}
	self.nlinepoints = 6000
	self.theline = nil
	self.scale = 0.01
	self.dt = 10.0 / 60.0

	local sunpos = {x = 0, y = 0, z = 0}
	local mooncenter = {x = 0, y = 0, z = 0}
	self.masses = {{gmass = 10.0, posfunc = integrator.makeStaticPosFunc(sunpos)},
		 		   {gmass = 2.0, posfunc = integrator.makeOrbitPosFunc(mooncenter, 100.0, calcOrbitVel(10,100.0), 0.0)},
		 		   {gmass = 2.0, posfunc = integrator.makeOrbitPosFunc(mooncenter, 200.0, calcOrbitVel(10,200.0), 0.0)}}

	self:createLine(renderer)
end

function PreviewLine:createLine(renderer)
	for i = 1,self.nlinepoints do
		table.insert(self.linepoints, {0,i*0.1,0})
	end
	self.theline = Line(#self.linepoints, true)
	self.theline:setPoints({self.linepoints})
	self.theline:createDefaultMaterial({1,0,0,1}, 0.01)
	renderer:add(self.theline)

	self.orbitdata = integrator.allocateData(self.masses, self.nlinepoints)
end

function PreviewLine:updateLine(t, p0raw, v0raw)
	local p0 = {x = p0raw[1], y = p0raw[2], z = p0raw[3]}
	local v0 = {x = v0raw[1], y = v0raw[2], z = v0raw[3]}
	integrator.integrate(self.orbitdata, self.masses, self.dt, t, p0, v0)
	local pts = integrator.dataToList(self.orbitdata, self.linepoints, self.scale)
	--local pts = integrator.massPositionsToList(self.orbitdata.masses[1], self.linepoints, self.scale)
	--trss.trss_log(0, "Pts0: " .. pts[1][1])
	self.theline:setPoints({pts})
end

return PreviewLine
