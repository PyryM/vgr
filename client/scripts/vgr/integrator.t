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
	var a: vec3 = {0.0, 0.0, 0.0}
	integrator.vsub(p0, p1, a)
	var d: float = integrator.vlength(a)

	-- dest += a * gm0 / (d^3)
	-- divide by d^3 rather than d^2 because a is non-normalized and
	-- so contains an extra factor of d that needs to be cancelled
	var ga: float = gm0 / (d*d*d)
	integrator.vaddscaled(dest, a, ga, dest)
end

struct integrator.gravinfo {
	gmass: float,
	positions: &vec3,
	npositions: uint32
}

terra integrator.integrate(p0: &vec3, v0: &vec3, 
	                       masses: &integrator.gravinfo,
	                       nmasses: uint32,
	                       timestep: float,
	                       nsteps: uint32,
	                       dest: &vec3)
	var p_t: vec3
	var v_t: vec3
	var a_t: vec3
	integrator.vcopy(p0, p_t)
	integrator.vcopy(v0, v_t)

	-- note that terra loops are C-style and only go up to end-1
	for	step = 0,nsteps do
		integrator.vcopy(p_t, dest[step])
		a_t = {0.0, 0.0, 0.0}
		for massidx = 0,nmasses do
			var curmass: &(masses[massidx])
			integrator.addGAccelVec(curmass.positions[step],
									p_t, curmass.gmass, a_t)
		end
		-- v_t += (a_t * timestep)
		integrator.vaddscaled(v_t, a_t, timestep, v_t)
		-- p_t += (v_t * timestep)
		integrator.vaddscaled(p_t, v_t, timestep, p_t)
	end
end




return integrator