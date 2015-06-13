var physics = require("./physics")
var WebSocketServer = require('ws').Server
var wss = new WebSocketServer({ port: 9090 });

physics.createWorld();

wss.on('connection', function connection(ws) {
  ws.on('message', function incoming(rawmessage) {
  	//console.log(message);
  	var message = JSON.parse(rawmessage);
  	if("username" in message) {
  		physics.playerApplyControls(message.username, message);
  	}
    ws.send(physics.getStateString());
  });
});