-- dart/meshmanager.t
--
-- loads+moves meshes around according to json

class = truss_import("core/30log.lua")
json = truss_import("lib/json.lua")
objloader = truss_import("loaders/objloader.t")
meshutils = truss_import("mesh/mesh.t")
stringutils = truss_import("utils/stringutils.t")
textureutils = truss_import("utils/textureutils.t")

local m = {}

local ObjectManager = class("ObjectManager")

function ObjectManager:init(renderer)
	self.renderer = renderer
	self.geos = {}

	self.objects = {}
	self.assRad = 2.0

	self.verbose = false
	self.scale = 0.01
end

function ObjectManager:getResourceInfo(objtype, objname)
	if objtype == "asteroid" then
		return {obj = "models/tetrahedron.obj", tex = "models/some_rock.jpg"}
	elseif objtype == "planet" then
		local modelname = "models/uvsphere_hi_alt.obj"
		local texname = "models/some_rock.jpg"
		if objname == "center" then
			--texname = "models/jupiter_hi.jpg"
			texname = "models/gray.png"
			modelname = "models/thecrystal.obj"
		else
			texname = "models/europa_hi.jpg"
		end
		return {obj = modelname, tex = texname}
	elseif objtype == "player" then
		return {obj = "models/cone_alt.obj", tex = "models/some_rock.jpg"}
	else
		return {obj = "models/ico.obj", tex = "models/some_rock.jpg"}
	end
end

function ObjectManager:getObjectList()
	local ret = {}
	for meshname, mesh in pairs(self.objects) do
		table.insert(ret, meshname)
	end
	return ret
end

function ObjectManager:getPlayer(pname)
	return self.objects["player:player." .. pname]
end

function ObjectManager:createMesh_(meshfilename, texfilename)
	local fullfilename = meshfilename
	trss.trss_log(0, "ObjectManager creating [" .. fullfilename .. "]")

	if self.geos[meshfilename] == nil then
		local modeldata = objloader.loadOBJ(fullfilename, false)
		local geo = meshutils.Geometry():fromData(self.renderer.vertexInfo, modeldata)
		self.geos[meshfilename] = geo
	end

	local tex = textureutils.loadTexture(texfilename)
	local mat = {texture = tex}
	local ret = meshutils.Mesh(self.geos[meshfilename], mat)
	ret.source_filename = meshfilename
	self.renderer:add(ret)

	return ret
end

function ObjectManager:getObject(objectname, objecttype)
	local fullname = objecttype .. ":" ..objectname
	if self.objects[fullname] == nil then
		local resData = self:getResourceInfo(objecttype, objectname)
		local newmesh = self:createMesh_(resData.obj, resData.tex)
		self.objects[fullname] = newmesh
	end
	return self.objects[fullname]
end

function ObjectManager:updateObject(obj, position, quat, rad)
	if quat then
		local mq = obj.quaternion
		mq.x, mq.y, mq.z, mq.w = quat[1], quat[2], quat[3], quat[4]
	end
	if position then
		local s = self.scale
		local mp = obj.position
		mp.x, mp.y, mp.z = position[1]*s, position[2]*s, position[3]*s
	end
	if rad then
		local ms = obj.scale
		local r = rad * self.scale
		ms.x, ms.y, ms.z = r,r,r
	end
	obj:updateMatrixWorld()
end

function ObjectManager:updateDynamics(dyns)
	for dname, dynobj in pairs(dyns) do
		local dtype = dynobj[5]
		local rad = self.assRad
		--if dtype then rad = 10.0 end

		local vobj = self:getObject(dname, dtype or "asteroid")
		local pos = dynobj[1]
		--trss.trss_log(0, "pos: " .. tostring(pos))
		-- local vel = dynobj[2] -- not used
		local quat = dynobj[3]
		--local angvel = dynobj[4] -- not used
		self:updateObject(vobj, pos, quat, rad)
		vobj.visible = true
	end
end

function ObjectManager:updateGravitors(gravs)
	for gname, gravitor in pairs(gravs) do
		local obj = self:getObject(gname, "planet")
		local pos = gravitor.position
		local quat = nil
		local rad = gravitor.radius
		self:updateObject(obj, pos, quat, rad)
		obj.visible = true
	end
end

function ObjectManager:update(rawstr)
	local jdata = json:decode(rawstr)

	-- hide everything first, the individual updates will then
	-- make the objects that still exist visible again
	for objname, obj in pairs(self.objects) do
		obj.visible = false
	end

	if jdata["dynamics"] then
		self:updateDynamics(jdata["dynamics"])
	end

	if jdata["gravitors"] then
		self:updateGravitors(jdata["gravitors"])
	else
		trss.trss_log(0, "No gravitors???")
	end
end

m.ObjectManager = ObjectManager
return m