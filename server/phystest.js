var physics = require("./physics")
var WebSocketServer = require('ws').Server
var wss = new WebSocketServer({ port: 9090 });

physics.createWorld();

wss.on('connection', function connection(ws) {
  ws.on('message', function incoming(message) {
    ws.send(physics.getStateString());
  });
});