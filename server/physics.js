var CANNON = require('cannon');

var world = null;
var playerShips = {};
var gravitors = [];
var gravitees = [];

var fixedTimeStep = 1.0 / 60.0; // seconds 
var maxSubSteps = 3;

var shipMass = 1.0;
var shipRad = 0.05;
var boxSize = new CANNON.Vec3(shipRad,shipRad,shipRad);
//var shipShape = new CANNON.Sphere(shipRad);
var shipShape = new CANNON.Box(boxSize);

var stateDirty = true;
var stateString = "{}";
var infoString = "{}";

var updateDelayMS = 1000.0 / 60.0;

var nextIdx = 0;

var G = 30.0; // could be anything!

function newID() {
    nextIdx += 1;
    return ""+nextIdx;
}

function createStaticGravitor(x, y, z, mass, rad) {
    var p = new CANNON.Vec3(x, y, z);

    var planetshape = new CANNON.Sphere(rad);
    var body = new CANNON.Body({ mass: 0 });
    body.position.set(x, y, z);
    body.addShape(planetshape);
    world.add(body);

    gravitors.push({idx: newID(), 
                    position: p, 
                    mass: mass, 
                    physbody: body, 
                    radius: rad});
}

function updateMoon(moon) {
    moon.t += fixedTimeStep;
    var theta = -moon.t * moon.vtheta;
    var x = moon.dist * Math.cos(theta);
    var y = 0.0;
    var z = moon.dist * Math.sin(theta);
    moon.position.set(x, y, z);
    moon.physbody.position.set(x, y, z);
    //console.log(theta);
}

function createMoonGravitor(dist, mass, rad) {
    var p = new CANNON.Vec3(x, y, z);
    var x = dist;
    var y = 0;
    var z = 0;

    var planetshape = new CANNON.Sphere(rad);
    var body = new CANNON.Body({ mass: 0 });
    body.position.set(x, y, z);
    body.addShape(planetshape);
    world.add(body);
    
    var curpos = new CANNON.Vec3(x, y, z);
    var velvec = calcOrbitalVelocityVec(curpos);
    var orbitvel = velvec.length();
    var vtheta = orbitvel / dist; 

    gravitors.push({idx: newID(),
                    position: p, 
                    mass: mass, 
                    physbody: body, 
                    radius: rad,
                    t: 0.0, vtheta: vtheta, 
                    update: updateMoon,
                    dist: dist});   
}

function gravityTo(p0, m0, p1, m1) {
    var dv = p1.vsub(p0); // copy
    var r2 = dv.lengthSquared();
    dv.normalize();
    var gval = -G * m0 * m1 / r2;
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
    // gravitors
    for(var i = 0; i < gravitors.length; ++i) {
        var curg = gravitors[i];
        if("update" in curg) {
            curg.update(curg);
        }
    }

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
    stateDirty = true;

    //console.log(getStateString());
}

function randRange(minval, maxval) {
  return Math.random() * (maxval - minval) + minval;
}

function createWorld() {
    world = new CANNON.World();
    world.gravity.set(0, 0, 0); // it is space
    createStaticGravitor(0, 0, 0, 10, 10); // blargh
    createMoonGravitor(100, 2, 3);

    for(var i = 0; i < 256; ++i) {
        createAsteroid();
    }

    updateCallback();
}

function updateCallback() {
    updateEntities();
    setTimeout(updateCallback, updateDelayMS);
}

function getGravitorPlain(gravitor) {
    return {
        position: gravitor.position.toArray(),
        mass: gravitor.mass,
        radius: gravitor.radius
    };
}

function getGraviteePlain(gravitee) {
    return [gravitee.physbody.position.toArray(),
            gravitee.physbody.velocity.toArray(),
            gravitee.physbody.quaternion.toArray(),
            gravitee.physbody.angularVelocity.toArray()];

}

function getStateString() {
    if(stateDirty) {
        var stateobj = {};
        stateobj.gravitors = {};
        var curobj;
        for(var i = 0; i < gravitors.length; ++i) {
            curobj = gravitors[i];
            stateobj.gravitors[curobj.idx] = getGravitorPlain(curobj);
        }
        stateobj.dynamics = {};
        for(var i = 0; i < gravitees.length; ++i) {
            curobj = gravitees[i];
            stateobj.dynamics[curobj.idx] = getGraviteePlain(curobj);
        }
        stateString = JSON.stringify(stateobj);
    }

    return stateString;
}

function calcOrbitalVelocityVec(pos) {
    var up = new CANNON.Vec3(0,1,0);
    var orbitdir = up.cross(pos);
    orbitdir.normalize();

    // f = m1 v^2/r
    // f = G m1 m2 / r^2
    // m1 v^2 = G m1 m2 / r
    // v = sqrt(G * m2 / r)
    var orbitvel = Math.sqrt(G * gravitors[0].mass / pos.length());
    console.log("Calculated orbvel: " + orbitvel);

    return orbitdir.scale(orbitvel);
}

function setRandomInitialConditions(body) {
    var minrad = 70.0;
    var maxrad = 80.0;
    // rejection sample eh
    var currad = -1.0;
    var curpos = new CANNON.Vec3();
    while(currad < minrad || currad > maxrad) {
        curpos.set(randRange(-maxrad,maxrad),
                    randRange(-maxrad*0.1,maxrad*0.1),
                    randRange(-maxrad,maxrad));
        currad = curpos.length();
    }
    body.position.copy(curpos);
    body.velocity.copy(calcOrbitalVelocityVec(curpos));
}

function createAsteroid(options) {
    var body = new CANNON.Body({ mass: shipMass, 
                                 linearDamping: 0.0,
                                 angularDamping: 0.1 });
    body.addShape(shipShape);
    
    var newship = {
        idx: newID(),
        physbody: body,
        radius: shipRad
    };

    setRandomInitialConditions(body);
    world.add(body);
    gravitees.push(newship);
    return newship;
}

function createPlayerShip(shipname, options) {
    if(shipname in playerShips) {
        return playerShips[shipname];
    }

    var body = new CANNON.Body({ mass: shipMass,
                                linearDamping: 0.0,
                                 angularDamping: 0.1 });
    body.addShape(shipShape);
    
    var newship = {
        idx: newID(),
        physbody: body,
        displayname: options.displayname || shipname,
        radius: shipRad
    };

    setRandomInitialConditions(body);
    world.add(body);
    playerShips[shipname] = newship;
    gravitees.push(newship);
    return newship;
}

function playerApplyControls(shipname, options) {
    // todo
}

module.exports = {
    "createWorld": createWorld,
    "getStateString": getStateString,
    "createPlayerShip": createPlayerShip,
    "playerApplyControls": playerApplyControls
};