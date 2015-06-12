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

BasicThrustCommand.prototype.nextImpulse = function(p, v, a, t, dt) {
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

BasicThrustCommand.prototype.clone = function() {
	var ret = new BasicThrustCommand({direction: this.direction,
									  intensity: this.intensity,
									  duration: this.duration});
	ret.timeleft = this.timeleft;
	return ret;
};

function WaitCommand(args) {
	this.waittime = args.time;
	this.reset();
	console.log("Created wait command!");
}

WaitCommand.prototype.reset = function() {
	// Nothing to do
};

WaitCommand.prototype.nextImpulse = function(p, v, a, t, dt) {
	if(t >= this.waittime) {
		return null;
	} else {
		return new THREE.Vector3(0,0,0);
	}
};

WaitCommand.prototype.clone = function() {
	var ret = new WaitCommand({time: this.waittime});
	return ret;
};

function parseCommandArgs(gps) {
	var ret;
	var temparr = [];
	var argname = "ARG0";
	var fval;
	for(var i = 0; i < gps.length; ++i) {
		fval = parseFloat(gps[i]);
		if(isNaN(fval)) { // text
			if(temparr.length == 1) {
				ret[argname] = temparr[0];
			} else if(temparr.length > 1) {
				ret[argname] = temparr;
			}
			argname = gps[i];
			temparr = [];
		} else { // numeric value
			temparr.push(fval);
		}
	}
	return ret;
}

function applyAliases(gps, aliases) {
	var ret = gps;
	for(var i = 0; i < ret.length; ++i) {
		if(ret[i] in aliases) {
			ret[i] = aliases[ret[i]];
		}
	}
	return ret;
}

function parseCommand(gps) {
	var constructors = {"THRUST": BasicThrustCommand,
				   "WAIT": WaitCommand};

	var aliases = {"DUR": "duration",
				   "INT": "intensity",
				   "DIR": "direction",
				   "TIM": "time"};

	var cmdtype = gps[0];
	var arggps = applyAliases(gps.slice(1), aliases);
	var args = parseCommandArgs(arggps);
	var ret = new constructors[cmdtype](args);
	return ret;
}

function NavComputer(outputcallback) {
	this._zero = new THREE.Vector3(0,0,0);
	this._commands = [];
	this._commandindex = 0;
	this._callback = outputcallback;
}

NavComputer.prototype.clone = function() {
	var ret = new NavComputer();
	ret._commandindex = this._commandindex;
	for(var i = 0; i < this._commands.length; ++i) {
		ret._commands.push(this._commands[i].clone());
	}
	return ret;
};

NavComputer.prototype.addCommand = function(command) {
	this._commands.push(command);
	this.refreshDisplay();
};

NavComputer.prototype.handleInput = function(inputstr) {
	var gps = inputstr.split(" ");
	var cmdgps;
	var cmd;
	var idx;
	var offsets = {"ADD": 1,
				   "REP": 2,
				   "INS": 2};

	var cmdname = gps[0];
	if(cmdname in offsets) {
		cmdgps = gps.slice(offsets[cmdname]);
		cmd = parseCommand(cmdgps);
		cmd.committed = false;
		cmd.displayString = " ".join(cmdgps);
	}

	if(gps[0] == "ADD") {
		this.addCommand(cmd);
	} else if(gps[0] == "REP") {
		idx = parseInt(gps[1]);
		if(idx < this._commands.length && !(this._commands[idx].committed)) {
			this._commands[idx] = cmd;
		}
		this.refreshDisplay();
	} else if(gps[0] == "INS") {
		// TODO
	} else if(gps[0] == "EXECUTE") {
		this.execute();
	} else if(gps[0] == "ABORT") {
		this.abort();
	} else if(gps[0] == "CANCEL") {
		this.cancel();
	}
};

NavComputer.prototype.refreshDisplay = function() {
	if(!this._callback) {
		return;
	}

	var data = [];
	var entry;
	for(var i = 0; i < this._commands.length; ++i) {
		entry = {str: this._commands[i].displayString, style: 0};
		if(this._commands[i].committed) {
			entry.style = 1;
		}
		data.push(entry);
	}
	this._callback(data);
};

NavComputer.prototype.execute = function() {
	for(var i = 0; i < this._commands.length; ++i) {
		this._commands[i].committed = true;
	}
	this.refreshDisplay();
};

NavComputer.prototype.abort = function() {
	this._commands = [];
	this._commandindex = 0;
	this.refreshDisplay();
};

NavComputer.prototype.cancel = function() {
	for(var i = 0; i < this._commands.length; ++i) {
		if(!(this._commands[i].committed)) {
			this._commands = this._commands.slice(0,i);
			break;
		}
	}
	this.refreshDisplay();
};

NavComputer.prototype.nextImpulse = function(p, v, a, t, dt) {
	if(this._commandindex < this._commands.length) {
		var cmdimpulse = this._commands[this._commandindex].nextImpulse(p, v, a, t, dt);
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

NavComputer.prototype.reset = function() {
	for(var i = 0; i < this._commands.length; ++i) {
		this._commands[i].reset();
	}
	this._commandindex = 0;
};
