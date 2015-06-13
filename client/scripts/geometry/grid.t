local grid = {}
local Line = truss_import("mesh/line.t")

function grid.addLineCircle(dest, rad)
	-- create a circle
	local circlepoints = {}
	local npts = 60
	local dtheta = math.pi * 2.0 / (npts - 1)
	for i = 1,npts do
		local x = rad * math.cos(i * dtheta)
		local z = rad * math.sin(i * dtheta)
		local y = 0.0
		circlepoints[i] = {x, y, z}
	end
	table.insert(dest, circlepoints)
	return npts
end

function grid.addSegmentedLine(dest, v0, v1, nsteps)
	local dx = (v1[1] - v0[1]) / (nsteps - 1)
	local dy = (v1[2] - v0[2]) / (nsteps - 1)
	local dz = (v1[3] - v0[3]) / (nsteps - 1)

	local curline = {}
	local x, y, z = v0[1], v0[2], v0[3]
	for i = 0,(nsteps-1) do
		table.insert(curline, {x, y, z})
		x, y, z = x + dx, y + dy, z + dz
	end
	table.insert(dest, curline)
	return #curline
end

function grid.createLineGrid()
	local x0 = -5
	local dx = 0.5
	local nx = 20
	local x1 = x0 + nx*dx
	local y0 = -5
	local dy = 0.5
	local ny = 20
	local y1 = y0 + ny*dy

	local lines = {}
	local npts = 0

	for ix = 0,nx do
		local x = x0 + ix*dx
		local v0 = {x, 0, y0}
		local v1 = {x, 0, y1}
		npts = npts + grid.addSegmentedLine(lines, v0, v1, 30)
		--table.insert(lines, {v0, v1})
		--npts = npts + 2
	end

	for iy = 0,ny do
		local y = y0 + iy*dy
		local v0 = {x0, 0, y}
		local v1 = {x1, 0, y}
		npts = npts + grid.addSegmentedLine(lines, v0, v1, 30)
		--table.insert(lines, {v0, v1})
		--npts = npts + 2
	end

	local r0 = 0.0
	local dr = 0.5
	local nr = 10
	for ir = 1,nr do
		npts = npts + grid.addLineCircle(lines, r0 + ir*dr)
	end

	local theline = Line(npts, false) -- static line
	theline:setPoints(lines)
	theline:createDefaultMaterial({0.7,0.7,0.7,1}, 0.005)

	return theline
end

return grid