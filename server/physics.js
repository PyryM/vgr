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

var G = 1.0; // could be anything!

function createStaticGravitor(x, y, z, mass, rad) {
    var p = new CANNON.Vec3(x, y, z);
    gravitors.push({position: p, mass: mass});

    var planetshape = new CANNON.Sphere(rad);
    var body = new CANNON.Body({ mass: 0 });
    body.position.set(x, y, z);
    body.addShape(planetshape);
    world.add(body);
}

function gravityTo(p_0, m_0, p_1, m_1) {
    var dv = p1.vsub(p0); // copy
    var r2 = dv.lengthSquared();
    dv.normalize();
    var gval = G * m_0 * m_1 / d2;
    return dv.scale(gval); // another copy :(
}

function getGravity(position, mass) {
    var totalForce = new CANNON.Vec3();
    var tempForce;
    for (var i = gravitors.length - 1; i >= 0; i--) {
        tempForce = gravityTo(gravitors[i].position, gravitors[i].mass,
                              position, mass);
        totalForce.vadd(tempForce, totalForce); // in place + into totalForce
    }
    return totalForce;
}

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

function randRange(minval, maxval) {
  return Math.random() * (maxval - minval) + minval;
}

function createWorld() {
    var world = new CANNON.World();
    world.gravity.set(0, 0, 0); // it is space
    createStaticGravitor(0, 0, 0, 1000); // blargh
}

function getStateString() {
    // todo
}

function calcOrbitalVelocityVec(pos) {
    var up = new CANNON.Vec3(0,1,0);
    var orbitdir = up.cross(pos);
    orbitdir.normalize();
    var orbitvel = 1.0;

    return orbitdir.scale(orbitvel);
}

function setRandomInitialConditions(body) {
    var minrad = 200.0;
    var maxrad = 10000.0;
    // rejection sample eh
    var currad = -1.0;
    var curpos = new CANNON.Vec3();
    while(currad < minrad || currad > maxrad) {
        curpos.set(randRange(-maxrad,maxrad),
                    randRange(-maxrad,maxrad),
                    randRange(-maxrad,maxrad));
        currad = curpos.length();
    }
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