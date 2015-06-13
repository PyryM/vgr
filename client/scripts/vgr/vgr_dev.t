-- dart_simple_renderer.t
--
-- example of using renderers/simple_renderer.t
-- to render a dart json scenegraph

bgfx = libs.bgfx
bgfx_const = libs.bgfx_const
terralib = libs.terralib
trss = libs.trss
sdl = libs.sdl
sdlPointer = libs.sdlPointer
TRSS_ID = libs.TRSS_ID
nanovg = libs.nanovg

function init()
	trss.trss_log(TRSS_ID, "vgr_dev.t init")
	sdl.trss_sdl_create_window(sdlPointer, width, height, 'Very Good: Risky')
	initBGFX()
	initNVG()
	local rendererType = bgfx.bgfx_get_renderer_type()
	local rendererName = ffi.string(bgfx.bgfx_get_renderer_name(rendererType))
	trss.trss_log(TRSS_ID, "Renderer type: " .. rendererName)
end

width = 1280
height = 720
frame = 0
time = 0.0
mousex, mousey = 0, 0

frametime = 0.0

objectmanager = truss_import("vgr/objectmanager.t")
simple_renderer = truss_import("renderers/simple_renderer.t")
matrixlib = truss_import("math/matrix.t")
quatlib = truss_import("math/quat.t")
local Matrix4 = matrixlib.Matrix4
local Quaternion = quatlib.Quaternion
local OrbitCam = truss_import("gui/orbitcam.t")
grid = truss_import("geometry/grid.t")
json = truss_import("lib/json.lua")

guiSrc = "gui/console.t"
gui = truss_import(guiSrc)

function onTextInput(tstr)
	log("Text input: " .. tstr)
	if gui ~= nil and gui.onTextInput ~= nil then
		gui.onTextInput(tstr)
	end
end

function onKeyDown(keyname, modifiers)
	log("Keydown: " .. keyname)
	if keyname == "F10" then
		takeScreenshot()
	end
	if gui ~= nil and gui.onKeyDown ~= nil then
		gui.onKeyDown(keyname, modifiers)
	end
end

function onKeyUp(keyname)
	-- nothing to do
end

downkeys = {}

function cprint(str)
	if gui then gui.printStraightText_(tostring(str)) end
end

function cerr(str)
	if gui then gui.printColored(tostring(str), {255,0,0}) end
end

websocket = truss_import("io/websocket.t")

function connect(url, callback)
	cprint("Connecting to [" .. url .. "]")
	if theSocket == nil then
		theSocket = websocket.WebSocketConnection()
	end
	theSocket:onMessage(callback)
	theSocket:connect(url)
	return theSocket
end

curthrusts = {yaw= 0, pitch= 0, roll= 0, thrust= 0}

-- hack to have some kind of controls
function getKeyboardThrusts()
	local ret = curthrusts
	if downkeys["W"] then
		ret.pitch = 1.0
	elseif downkeys["S"] then
		ret.pitch = -1.0
	else
		ret.pitch = 0.0
	end

	if downkeys["A"] then
		ret.yaw = 1.0
	elseif downkeys["D"] then
		ret.yaw = -1.0
	else 
		ret.yaw = 0.0
	end

	if downkeys["Q"] then
		ret.roll = 1.0
	elseif downkeys["E"] then
		ret.roll = -1.0
	else
		ret.roll = 0.0
	end

	if downkeys["Y"] then
		ret.thrust = 1.0
	elseif downkeys["H"] then
		ret.thrust = 0.5
	elseif downkeys["N"] then
		ret.thrust = 0.25
	else
		ret.thrust = 0.0
	end

	curthrusts = ret
	return ret
end

sframe = 0
decimate = 2
function requestData()
	sframe = sframe + 1 
	if theSocket and theSocket:isOpen() and sframe % decimate == 0 then
		local thrusts = getKeyboardThrusts()
		thrusts.username = username
		theSocket:send(json:encode(thrusts))
	end
end

function updateMeshesFromJSONString(str)
	manager:update(str)
end

function set_update_decimation(v)
	if v > 0 then
		decimate = v
	else
		cerr("Cannot set decimate to <= 0!")
	end
end

username = "BLARGH"
function connect_vgr(url, sname)
	cprint("Connecting to [" .. url .. "]")
	if sname == nil then
		username = "USER" .. math.floor(math.random() * 1000.0)
	else
		username = sname
	end
	cprint("Connecting as [" .. username .. "]")
	if theSocket == nil then
		theSocket = websocket.WebSocketConnection()
	end
	theSocket:onMessage(updateMeshesFromJSONString)
	theSocket:connect(url)
	return theSocket
end

function load_json_scene(filename)
	cprint("Loading local json serialization file [" .. filename .. "]")
	local jsonstring = loadStringFromFile(filename)
	manager:update(jsonstring)
end

function conlocal()
	connect_vgr("ws://localhost:9090", "testo")
end

function info(v)
	local vt = type(v)
	if vt == "number" or vt == "string" or vt == "boolean" or vt == "nil" then
		cprint(tostring(v))
	elseif vt == "table" then
		local curstr = ""
		for fieldname, field in pairs(v) do
			curstr = curstr .. "[" .. fieldname .. "]: "
			curstr = curstr .. tostring(field) .. ","
			if #curstr > 60 then
				cprint(curstr)
				curstr = ""
			end
		end
		if #curstr > 0 then cprint(curstr) end
	else
		cprint("type <" .. vt .. ">: " .. tostring(v))
	end
end

function filter(t, p)
	local ret = {}
	for i,v in ipairs(t) do
		if v:find(p) then
			table.insert(ret, v)
		end
	end
	return ret
end

function setcamtarget(tgt)
	camTarget = tgt
	debugCam = false
end

function setcamdebug(newmode)
	debugCam = newmode
end

function getanyobject(idx)
	local id = idx or 1
	local objs = manager:getObjectList()
	return manager.objects[objs[id]]
end

function watchID(id)
	setcamtarget(getanyobject(id))
end

function watchSelf()
	setcamtarget(manager:getPlayer(username))
end

consoleenv = {print = cprint, 
			  err = cerr,
			  pairs = pairs,
			  ipairs = ipairs,
			  math = math,
			  string = string,
			  table = table,
			  connect = connect,
			  connect_vgr = connect_vgr,
			  set_update_decimation = set_update_decimation,
			  truss_import = truss_import,
			  load_json_scene = load_json_scene,
			  info = info,
			  filter = filter,
			  conlocal = conlocal,
			  setcamtarget = setcamtarget,
			  setcamdebug = setcamdebug,
			  getanyobject = getanyobject,
			  watchID = watchID,
			  play = watchSelf}

function consoleExecute(str)
	local lchunk, err = loadstring(str)
	if err then
		cerr(err)
		return
	end
	setfenv(lchunk, consoleenv)
	local succeeded, retval = pcall(lchunk)
	if succeeded then
		if retval then
			cprint(retval)
		end
	else
		cerr(retval)
	end
end

screenshotid = 0
screenshotpath = ""

function takeScreenshot()
	local fn = screenshotpath .. "img_" .. screenshotid .. ".png"
	bgfx.bgfx_save_screen_shot(fn)
	screenshotid = screenshotid + 1
end

function updateEvents()
	local nevents = sdl.trss_sdl_num_events(sdlPointer)
	for i = 1,nevents do
		local evt = sdl.trss_sdl_get_event(sdlPointer, i-1)
		if evt.event_type == sdl.TRSS_SDL_EVENT_KEYDOWN or evt.event_type == sdl.TRSS_SDL_EVENT_KEYUP then
			local keyname = ffi.string(evt.keycode)
			if evt.event_type == sdl.TRSS_SDL_EVENT_KEYDOWN then
				if not downkeys[keyname] then
					downkeys[keyname] = true
					onKeyDown(keyname, evt.flags)
				end
			else -- keyup
				downkeys[keyname] = false
				onKeyUp(keyname)
			end
		elseif evt.event_type == sdl.TRSS_SDL_EVENT_TEXTINPUT then
			onTextInput(ffi.string(evt.keycode))
		elseif evt.event_type == sdl.TRSS_SDL_EVENT_WINDOW and evt.flags == 14 then
			trss.trss_log(0, "Received window close, stopping interpreter...")
			trss.trss_stop_interpreter(TRSS_ID)
		end
		orbitcam:updateFromSDL(evt)
	end
end

function log(msg)
	trss.trss_log(0, msg)
end

debugCam = true
camTarget = nil

tempMat = Matrix4()

function updateCamera()
	if camTarget and not debugCam then
		-- compose like this to avoid having a scale in the camera matrix
		-- (scaling will mess with the z-buffer limits)
		tempMat:compose(camTarget.quaternion, {x=1,y=1,z=1}, camTarget.position)
		renderer:setCameraTransform(tempMat)
	else
		orbitcam:update(1.0 / 60.0)
		renderer:setCameraTransform(orbitcam.mat)
	end
end

function initNVG()
	-- create context, indicate to bgfx that drawcalls to view
	-- 0 should happen in the order that they were submitted
	nvg = nanovg.nvgCreate(1, 1) -- make sure to have antialiasing on
	bgfx.bgfx_set_view_seq(1, true)

	-- load font
	--nvgfont = nanovg.nvgCreateFont(nvg, "sans", "font/roboto-regular.ttf")
	nvgfont = nanovg.nvgCreateFont(nvg, "sans", "font/VeraMono.ttf")

	if gui and gui.init then
		gui.init(width, height, nvg)
		gui.execCallback = consoleExecute
	end
end

function initBGFX()
	-- Basic init

	local debug = bgfx_const.BGFX_DEBUG_TEXT
	local reset = bgfx_const.BGFX_RESET_VSYNC + bgfx_const.BGFX_RESET_MSAA_X8
	--local reset = bgfx_const.BGFX_RESET_MSAA_X8

	bgfx.bgfx_init(bgfx.BGFX_RENDERER_TYPE_COUNT, 0, 0, nil, nil)
	bgfx.bgfx_reset(width, height, reset)

	-- Enable debug text.
	bgfx.bgfx_set_debug(debug)

	bgfx.bgfx_set_view_clear(0, 
	0x0001 + 0x0002, -- clear color + clear depth
	0x000000ff,
	1.0,
	0)

	trss.trss_log(0, "Initted bgfx I hope?")

	-- Init renderer
	renderer = simple_renderer.SimpleRenderer(width, height)
	renderer.autoUpdateMatrices = false
	-- set default lights
	renderer:setLightDirections({
			{ 1.0,  0.0,  0.0},
			{-1.0,  0.0,  0.0},
			{ 0.0, -1.0,  1.0},
			{ 0.0, -1.0, -1.0}})

	local off = {0.0, 0.0, 0.0}
	renderer:setLightColors({
			{0.4, 0.35, 0.3},
			{0.005, 0.005, 0.01},
			off,
			off})

	-- init object manager
	manager = objectmanager.ObjectManager(renderer)
	consoleenv.objects = manager

	-- create a line grid
	thegrid = grid.createLineGrid()
	renderer:add(thegrid)
	consoleenv.grid = thegrid

	-- camera
	cammat = Matrix4():identity()
	camquat = Quaternion():identity()
	campos = {x = 0, y = 0, z = 0}
	orbitcam = OrbitCam()

end

function drawNVG()
	nanovg.nvgBeginFrame(nvg, width, height, 1.0)
	if gui then
		gui.draw(nvg, width, height)
	end
	nanovg.nvgEndFrame(nvg)
end

frametime = 0.0
scripttime = 0.0

function update()
	frame = frame + 1
	time = time + 1.0 / 60.0

	local startTime = tic()

	-- Deal with input and io events
	updateEvents()
	if theSocket then
		requestData() 
		theSocket:update() 
	end

	-- Set view 0,1 default viewport.
	bgfx.bgfx_set_view_rect(0, 0, 0, width, height)
	bgfx.bgfx_set_view_rect(1, 0, 0, width, height)

	-- This dummy draw call is here to make sure that view 0 is cleared
	-- if no other draw calls are submitted to view 0.
	bgfx.bgfx_submit(0, 0)

	-- Use debug font to print information about this example.
	bgfx.bgfx_dbg_text_clear(0, false)

	bgfx.bgfx_dbg_text_printf(0, 1, 0x4f, "vgr_dev.t")
	bgfx.bgfx_dbg_text_printf(0, 2, 0x6f, "total: " .. frametime*1000.0 .. " ms, script: " .. scripttime*1000.0 .. " ms")

	updateCamera()
	renderer:render()
	drawNVG()

	scripttime = toc(startTime)

	-- Advance to next frame. Rendering thread will be kicked to
	-- process submitted rendering primitives.
	bgfx.bgfx_frame()

	frametime = toc(startTime)
end