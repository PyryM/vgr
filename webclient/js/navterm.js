function NavTerm(nrows) {
	this.nrows = 40;
	this.term = null;
	this.datadest = null;

	this._commands = [];
}

NavTerm.prototype.attachToTerm = function(term) {
	this.term = term;
	this.term.cursorSet(this.nrows-1, 0);
	this.refreshDisplay();
};

NavTerm.prototype.detachFromTerm = function() {
	if(this.term) {
		this.term.clear();
		this.term = null;
	}
};

// new Terminal(
// 		{
// 			rows: this.nrows,
// 			greeting: '%+r +++ NAVIGATION CONSOLE +++%-r%n',
// 			termDiv: targetdiv,
// 			crsrBlinkMode: true,
// 			handler: this.makeHandler(),
// 			exitHandler: this.makeExitHandler(),
// 			closeOnESC: false
// 		}
// 	);

function twoDigitNum(v) {
	if(v < 10) {
		return "0" + v;
	} else {
		return "" + v;
	}
}

NavTerm.prototype.refreshDisplay = function() {
	if(!this.term) {
		return;
	}

	var rstr;
	var rstyle;
	for(var i = 0; i < this.nrows - 3; ++i) {
		rstr = twoDigitNum(i) + "} ";
		rstyle = 0;
		if(i < this._commands.length){
			rstr += this._commands[i].str;
			rstyle = this._commands[i].style;
		}
		//this.term.cursorSet(i, 0);
		//this.term.write(rstr);
		this.term.printRowFromString(i, rstr, rstyle);
	}
};


NavTerm.prototype.setCommands = function(commands) {
	this._commands = commands;
	this.refreshDisplay();
};

NavTerm.prototype.handleInput = function(cmd) {
	var term = this.term;
	if (cmd != '' && this.datadest != null) {
		this.datadest(cmd);
	}
	term.printRowFromString(this.nrows-1,"");
	term.cursorSet(this.nrows-1,0);
	term.prompt();
};