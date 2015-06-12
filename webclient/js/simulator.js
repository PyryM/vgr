function integrateTrajectory(p0, v0, ts, tf, dt, forces, impulses) {
	var p_hist = [];
	// var v_hist = [];
	// var a_hist = [];

	var p, v, a;
	var sv;
	p = new THREE.Vector3();
	p.copy(p0);
	v = new THREE.Vector3();
	v.copy(v0);
	sv = new THREE.Vector3();

	var impulse;

	for(var t = ts; t < tf; t += dt) {
		a = forces.computeAt(p, v, t);

		// a_hist.push([a.x, a.y, a.z]);
		// v_hist.push([v.x, v.y, v.z]);
		p_hist.push([p.x, p.y, p.z]);

		a.multiplyScalar(dt);
		v.add(a);
		if(impulses) {
			impulse = impulses.nextImpulse(p, v, a, dt);
			v.add(impulse);
		}

		sv.copy(v);
		sv.multiplyScalar(dt);
		p.add(sv);
	}

	return p_hist;
}

function computePassiveTrajectory(body, forcegen, ts, tf, dt) {
	var p0 = body.position;
	var v0 = body.velocity;
	return integrateTrajectory(p0, v0, ts, tf, dt, forcegen, null);
}

function GravityField() {
	this._bodies = [];
}

GravityField.prototype.addBody = function(body) {
	this._bodies.push(body);
};

GravityField.prototype.computeAt = function(p, v, t) {
	var ret = new THREE.Vector3();
	var pb = new THREE.Vector3();
	var d2;
	for(var i = 0; i < this._bodies.length; ++i) {
		pb.copy(this._bodies[i].position_function(t));
		pb.sub(p);
		d2 = pb.lengthSq();
		pb.normalize();
		pb.multiplyScalar(this._bodies[i].accel / d2);
		ret.add(pb);
	}
	return ret;
};

function makeStaticPosFunc(pos) {
	var p = pos;
	var ret = function(t) {
		return p;
	}
	return ret;
}

function AnalyticBody(name, options) {
	this.name = name;
	this.accel = options.accel;
	if(options.position_function) {
		this.position_function = options.position_function;
	} else {
		this.position_function = makeStaticPosFunc(options.pos);
	}
}

AnalyticBody.prototype.predictPosition = function(t) {
	return this.position_function(t);
};

AnalyticBody.prototype.predictTrajectory = function(t0, tf, dt) {
	var ret = [];
	var curpos;
	for(var  t = t0; t < tf; t += dt) {
		curpos = new THREE.Vector3();
		curpos.copy(this.position_function(t));
		ret.push(curpos);
	}};
	return ret;
};

AnalyticBody.prototype.update = function(t0, dt) {
	// nothing to do
};

function DynamicBody(name, options) {
	this.name = name;
	this.pos = options.pos;
	this.vel = options.vel;
	this.driver = options.driver;
	this.sv = new THREE.Vector3();
}

DynamicBody.prototype.clone = function(name) {
	var p = new THREE.Vector3();
	var v = new THREE.Vector3();
	p.copy(this.pos);
	v.copy(this.vel);
	var dcopy = null;
	if(this.driver) {
		dcopy = this.driver.clone();
	}
	var ret = new DynamicBody(name, {pos: p, vel: v, driver: dcopy});
	ret.simulator = this.simulator;
	return ret;
};

DynamicBody.prototype.predictPosition = function(t0, tf) {
	var clone = this.clone("CLONE");
	var dt = 0.01;
	var t = t0;
	while(t < tf) {
		clone.update(t, dt);
		t += dt;
	}
	return clone.pos;
};

DynamicBody.prototype.predictTrajectory = function(t0, tf, dt) {
	var clone = this.clone("CLONE");
	var ret = [];
	var tpos;
	var t = t0;
	while(t < tf) {
		clone.update(t, dt);
		tpos = new THREE.Vector3();
		tpos.copy(clone.pos);
		ret.push(tpos);
		t += dt;
	}
	return ret;
};

DynamicBody.prototype.update = function(t0, dt) {
	var impulse;
	var a = this.simulator._gravfield.computeAt(this.pos, this.vel, t0);
	a.multiplyScalar(dt);
	this.vel.add(a);
	if(this.driver) {
		impulse = this.driver.nextImpulse(this.pos, this.vel, a, t0, dt);
		this.vel.add(impulse);
	}
	this.sv.copy(v);
	this.sv.multiplyScalar(dt);
	this.pos.add(sv);
};

function Simulator() {
	this._t = 0.0;
	this._gravfield = new GravityField();
	this._bodies = {};
}

Simulator.prototype.addBody = function(body) {
	this._bodies[body.name] = body;
	body.simulator = this;
	if(body.accel && body.accel > 0.0) {
		this._gravfield.addBody(body);
	}
};

Simulator.prototype.removeBody = function(body) {
	delete this._bodies[body.name];
	if(body.accel && body.accel > 0) {
		console.log("Warning! Can't delete gravitational bodies!");
	}
};

Simulator.prototype.predictBodyPosition = function(bodyname, t) {
	// body...
};

Simulator.prototype.predictBodyTrajectory = function(bodyname, tf, dt) {
	var body = this._bodies[bodyname];
	return body.predictTrajectory(this._t, tf, dt);
};

Simulator.prototype.update = function(dt) {
	var t0 = this._t;
	for(var bname in this._bodies) {
		this._bodies[bname].update(t0, dt);
	}
	this._t += dt;
};