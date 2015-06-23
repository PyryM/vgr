-- integrator.t
--
-- does basic euler integration for previewing orbits

local integrator = {}

struct integrator.vec3 {
	x: float;
	y: float;
	z: float;
}

local vec3 = integrator.vec3

local CMath = terralib.includec("math.h")

-- dest = a - b
terra integrator.vsub(a: &vec3, 
					  b: &vec3, 
					  dest: &vec3)
	dest.x = a.x - b.x
	dest.y = a.y - b.y
	dest.z = a.z - b.z
end

-- dest = a + b
terra integrator.vadd(a: &vec3, 
					  b: &vec3, 
					  dest: &vec3)
	dest.x = a.x + b.x
	dest.y = a.y + b.y
	dest.z = a.z + b.z
end

-- dest = s*a
terra integrator.vscale(a: &vec3, 
					    s: float, 
					    dest: &vec3)
	dest.x = a.x * s
	dest.y = a.y * s
	dest.z = a.z * s
end

-- dest = a + s*b
terra integrator.vaddscaled(a: &vec3,
	  						b: &vec3,
	  						s: float,
	  						dest: &vec3)
	dest.x = a.x + s*b.x
	dest.y = a.y + s*b.y
	dest.z = a.z + s*b.z
end

-- return dot(a,b)
terra integrator.vdot(a: &vec3,
					  b: &vec3)
	return a.x*b.x + a.y*b.y + a.z*b.z
end

terra integrator.vcopy(src: &vec3, dest: &vec3)
	dest.x = src.x
	dest.y = src.y
	dest.z = src.z
end

function integrator.vcopyarr(srcarr, dest)
	dest.x = srcarr[1]
	dest.y = srcarr[2]
	dest.z = srcarr[3]
end

function integrator.vcopytable(srctab, dest)
	dest.x = srctab.x
	dest.y = srctab.y
	dest.z = srctab.z
end

-- return ||a||
terra integrator.vlength(a: &vec3)
	var s = integrator.vdot(a,a)
	return CMath.sqrt(s)
end

-- calculate acceleration on body at p1 from a mass
-- at p0 with G*m0 gm0, and add this acceleration
-- into dest
terra integrator.addGAccelVec(p0: &vec3,
					     	  p1: &vec3,
							  gm0: float,
							  dest: &vec3)
	var a: vec3
	a.x = 0.0
	a.y = 0.0
	a.z = 0.0
	integrator.vsub(p0, p1, &a)
	var d: float = integrator.vlength(&a)

	-- dest += a * gm0 / (d^3)
	-- divide by d^3 rather than d^2 because a is non-normalized and
	-- so contains an extra factor of d that needs to be cancelled
	var ga: float = gm0 / (d*d*d)
	integrator.vaddscaled(dest, &a, ga, dest)
end

struct integrator.gravinfo {
	gmass: float,
	positions: &vec3,
	npositions: uint32
}

terra integrator.step_(p0: &vec3, v0: &vec3, 
	                       masses: &integrator.gravinfo,
	                       nmasses: uint32,
	                       timestep: float,
	                       stepidx: uint32)
	var a_t: vec3
	a_t.x = 0.0
	a_t.y = 0.0
	a_t.z = 0.0
	for massidx = 0,nmasses do
		var curmass: &integrator.gravinfo = &(masses[massidx])
		integrator.addGAccelVec(&curmass.positions[stepidx],
								p0, curmass.gmass, &a_t)
	end
	-- v0 += (a_t * timestep)
	integrator.vaddscaled(v0, &a_t, timestep, v0)
	-- p0 += (v0 * timestep)
	integrator.vaddscaled(p0, v0, timestep, p0)
end

terra integrator.integrate_(p0: &vec3, v0: &vec3, 
	                       masses: &integrator.gravinfo,
	                       nmasses: uint32,
	                       timestep: float,
	                       nsteps: uint32,
	                       dest: &vec3)
	var p_t: vec3
	var v_t: vec3
	var a_t: vec3
	integrator.vcopy(p0, &p_t)
	integrator.vcopy(v0, &v_t)

	-- note that terra loops are C-style and only go up to end-1
	for	step = 0,nsteps do
		integrator.vcopy(&p_t, &dest[step])
		a_t.x = 0.0
		a_t.y = 0.0
		a_t.z = 0.0
		for massidx = 0,nmasses do
			var curmass: &integrator.gravinfo = &(masses[massidx])
			integrator.addGAccelVec(&curmass.positions[step],
									&p_t, curmass.gmass, &a_t)
		end
		-- v_t += (a_t * timestep)
		integrator.vaddscaled(&v_t, &a_t, timestep, &v_t)
		-- p_t += (v_t * timestep)
		integrator.vaddscaled(&p_t, &v_t, timestep, &p_t)
	end
end

function integrator.integrate(data, masses, timestep, timeoffset, p0, v0)
	integrator.vcopytable(p0, data.p0)
	integrator.vcopytable(v0, data.v0)
	integrator.setPositions(data, masses, timestep, timeoffset)
	integrator.integrate_(data.p0, data.v0,
						 data.masses, data.nmasses,
						 timestep, data.nsteps,
						 data.positions)
	integrator.vcopytable(p0, data.p1)
	integrator.vcopytable(v0, data.v1)
	integrator.step_(data.p1, data.v1,
						 data.masses, data.nmasses,
						 timestep, 0)
	return data.p1, data.v1
end

function integrator.dataToList(data, dest, scale)
	local ret = dest or {}
	local p = data.positions
	local s = scale or 1.0
	for i = 1,data.nsteps do
		local cp = p[i-1]
		ret[i] = ret[i] or {0,0,0}
		ret[i][1] = cp.x * s
		ret[i][2] = cp.y * s
		ret[i][3] = cp.z * s
		--trss.trss_log(0, "i: " .. i .. ", " .. cp.x .. ", " .. cp.y .. ", " .. cp.z)
	end
	return ret
end

function integrator.massPositionsToList(massinfo, dest, scale)
	local ret = dest or {}
	local p = massinfo.positions
	local s = scale or 1.0
	for i = 1,massinfo.npositions do
		local cp = p[i-1]
		ret[i] = ret[i] or {0,0,0}
		ret[i][1] = cp.x * s
		ret[i][2] = cp.y * s
		ret[i][3] = cp.z * s
		--trss.trss_log(0, "i: " .. i .. ", " .. cp.x .. ", " .. cp.y .. ", " .. cp.z)
	end
	return ret
end

function integrator.allocateData(srcmasses, nsteps)
	local ret = {}

	local nmasses = #srcmasses
	local masses = terralib.new(integrator.gravinfo[nmasses])

	-- need to save the mass positions in lua or else terra will try to 
	-- garbage collect them
	ret.masspositions = {}
	print(tostring(masses))
	for i = 1,nmasses do
		masses[i-1].gmass = srcmasses[i].gmass or 1.0
		masses[i-1].npositions = nsteps
		local newpos = terralib.new(vec3[nsteps])
		masses[i-1].positions = newpos
		table.insert(ret.masspositions, newpos)
		print(tostring(masses[i-1]))
		print(tostring(masses[i-1].positions))
	end
	ret.masses = masses
	ret.nmasses = nmasses
	ret.positions = terralib.new(vec3[nsteps])
	ret.nsteps = nsteps

	ret.p0 = terralib.new(vec3)
	ret.v0 = terralib.new(vec3)
	ret.p1 = terralib.new(vec3)
	ret.v1 = terralib.new(vec3)

	return ret
end

function integrator.makeStaticPosFunc(pos)
	local p = pos
	local ret = function(t, dest)
		dest.x = p.x
		dest.y = p.y
		dest.z = p.z
	end
	return ret
end

function integrator.makeOrbitPosFunc(pCenter, rad, vtheta, theta0)
	local pc = pCenter
	local v = vtheta
	local offset = theta0
	local r = rad
	local ret = function(t, dest)
		dest.x = pc.x + rad * math.cos(-vtheta*t + theta0)
		dest.y = pc.y
		dest.z = pc.z + rad * math.sin(-vtheta*t + theta0)
	end
	return ret
end

function integrator.setPositions(data, srcmasses, timestep, timeoffset)
	local nmasses = #srcmasses
	local nsteps = data.nsteps
	for i = 1,nmasses do
		local dest = data.masses[i-1].positions
		--print(dest)
		data.masses[i-1].gmass = srcmasses[i].gmass
		local posfunc = srcmasses[i].posfunc
		for tidx = 0,nsteps-1 do
			local t = tidx * timestep + timeoffset
			--print(dest[tidx])
			posfunc(t, dest[tidx])
			--dest[tidx].x = 0
			--dest[tidx].y = 0
			--dest[tidx].z = 0
		end
	end
end


return integrator