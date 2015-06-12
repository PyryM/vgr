function integrateTrajectory(p0, v0, tf, dt, forces, impulseSchedule) {
	var p_hist = [];
	var v_hist = [];
	var a_hist = [];

	var p, v, a;
	var sv;
	p = new THREE.Vector3();
	p.copy(p0);
	v = new THREE.Vector3();
	v.copy(v0);
	sv = new THREE.Vector3();

	var idx = 0;
	var impulse;

	for(var t = 0; t < tf; t += dt) {
		a = forces.computeAt(p, v, t);

		a_hist.push([a.x, a.y, a.z]);
		v_hist.push([v.x, v.y, v.z]);
		p_hist.push([p.x, p.y, p.z]);

		a.multiplyScalar(dt);
		v.add(a);
		impulse = impulseSchedule.nextImpulse(p, v, a, dt);
		v.add(impulse);

		sv.copy(v);
		sv.multiplyScalar(dt);
		p.add(sv);

		++idx;
	}

	return [p_hist, v_hist, a_hist];
}

function BasicThrustCommand(args) {
	this.direction = new THREE.Vector3();
	this.direction.fromArray(args.direction)
	this.direction.normalize();

	this.intensity = args.intensity;
	this.duration = args.duration;

	this.reset();
	console.log("Created thrust command!");
}

BasicThrustCommand.prototype.reset = function() {
	this.timeleft = this.duration;
};

BasicThrustCommand.prototype.nextImpulse = function(p, v, a, dt) {
	if(this.timeleft <= 0) {
		return null;
	} else {
		var tdt;
		if(this.timeleft < dt) {
			tdt = this.timeleft;
		} else {
			tdt = dt;
		}
		this.timeleft -= dt;
		var ret = new THREE.Vector3();
		ret.copy(this.direction);
		ret.multiplyScalar(this.intensity * tdt);
		return ret;
	}
};

function WaitCommand(args) {
	this.waittime = args.time;
	this.reset();
	console.log("Created wait command!");
}

WaitCommand.prototype.reset = function() {
	this.timeleft = this.waittime;
};

WaitCommand.prototype.nextImpulse = function(p, v, a, dt) {
	if(this.timeleft <= 0) {
		return null;
	} else {
		this.timeleft -= dt;
		return new THREE.Vector3(0,0,0);
	}
};

function parseThrustCommands(commands, sched) {
	var aliases = {"thrust": BasicThrustCommand,
				   "wait": WaitCommand};
	var curcmd;
	var cmdobj;
	for(var i = 0; i < commands.length; ++i) {
		curcmd = commands[i];
		cmdobj = new aliases[curcmd.cmd](curcmd);
		sched.addCommand(cmdobj);
	}
}

function ImpulseSchedule() {
	this._zero = new THREE.Vector3(0,0,0);
	this._commands = [];
	this._commandindex = 0;
}

ImpulseSchedule.prototype.addCommand = function(command) {
	this._commands.push(command);
};

ImpulseSchedule.prototype.nextImpulse = function(p, v, a, dt) {
	if(this._commandindex < this._commands.length) {
		var cmdimpulse = this._commands[this._commandindex].nextImpulse(p, v, a, dt);
		if(cmdimpulse) {
			return cmdimpulse;
		} else {
			this._commandindex += 1;
			return this._zero;
		}
	} else {
		return this._zero;
	}
};

ImpulseSchedule.prototype.reset = function() {
	for(var i = 0; i < this._commands.length; ++i) {
		this._commands[i].reset();
	}
	this._commandindex = 0;
};


function StaticBody(position, acceleration) {
	this._pos = position;
	this.accel = acceleration;
}

StaticBody.prototype.position = function(t) {
	return this._pos;
};

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
		pb.copy(this._bodies[i].position(t));
		pb.sub(p);
		d2 = pb.lengthSq();
		pb.normalize();
		pb.multiplyScalar(this._bodies[i].accel / d2);
		ret.add(pb);
	}
	return ret;
};

function testIntegration(commands) {
	var gf = new GravityField();
	gf.addBody(new StaticBody(new THREE.Vector3(0,0,0), 125.0 ));
	//gf.addBody(new StaticBody(new THREE.Vector3(0,10,0), 125.0));
	var isched = new ImpulseSchedule();
	if(commands) {
		parseThrustCommands(commands, isched);
	}
	var p0 = new THREE.Vector3(30.0, 0.0, 0.0);
	var v0 = new THREE.Vector3(0.0, 1.0, 0.0);
	var tf = 3.0 * 12;
	var dt = 0.01;
	var ret = integrateTrajectory(p0, v0, tf, dt, gf, isched);
	console.log(ret);
	return ret[0];	
}