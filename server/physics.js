var CANNON = require('cannon');

var world = null;
var playerShips = {};
var gravitors = [];
var gravitees = [];

var fixedTimeStep = 1.0 / 60.0; // seconds 
var maxSubSteps = 3;

var shipMass = 100.0;
var shipRad = 1.0;
var shipShape = new CANNON.Sphere(shipRad);

function updateEntities() {
    // gravity pass
    var curentity;
    var curgrav;
    for (var i = gravitees.length - 1; i >= 0; i--) {
        curentity = gravitees[i].physbody;
        curgrav = getGravity(curentity.position, curentity.mass);
        curentity.applyForce(curgrav, curentity.position);
    };

    // thruster pass
    for (var shipname in playerShips) {
        curentity = playerShips[shipname];
        applyThrusts(curentity);
    };

    world.step(fixedTimeStep, fixedTimeStep, maxSubSteps);
}

function createWorld() {
    // todo
}

function getStateString() {
    // todo
}

function setRandomInitialConditions(body) {

}

function createPlayerShip(shipname, options) {
    if(shipname in playerShips) {
        return playerShips[shipname];
    }

    var body = new CANNON.Body({ mass: shipMass });
    body.addShape(shipShape);
    
    var newship = {
        physbody: body
    };

    setRandomInitialConditions(body);
    world.add(body);
    playerShips[shipname] = newship;
    return newship;
}

function playerApplyControls(shipname, options) {

}

module.exports = {
    "createWorld": createWorld,
    "getStateString": getStateString,
    "createPlayerShip": createPlayerShip,
    "playerApplyControls": playerApplyControls
};