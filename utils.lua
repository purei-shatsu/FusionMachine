--[[
local oldRandomSeed = math.randomseed
local hasSeed
function math.randomseed(...)
	print('SEEDING')
	hasSeed = not hasSeed or error('seeding twice', 2)
	oldRandomSeed(...)
end
--]]

function table.count(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

function hexEncode(str)
	return str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end)
end

function hexDecode(str)
	return str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end)
end

function drawRectangle(r, g, b, a)
	love.graphics.superpush()
	love.graphics.superorigin()
	
	local sw, sh = love.graphics.getDimensions(true)
	love.graphics.setColor(r, g, b, a)
	love.graphics.rectangle('fill', 0, 0, sw, sh)
	
	love.graphics.superpop()
end

function math.round(x)
	if x>=0 then
		return math.floor(x+0.5) 
	else
		return math.ceil(x-0.5)
	end
end

function formatTime(t)
	if not t then
		return '---:--:--'
	end
	
	t = math.round(t*1000)/1000
	local ms = (t*1000)%1000
	local s = math.floor(t)%60
	local m = math.floor(t/60)
	if m>999 then
		--maximum time
		return '999:59:999'
	end
	return string.format('%003d:%02d:%003d', m, s, ms)
end

function findTableName(t)
	for n,p in pairs(_G) do
		if p==t then
			return n
		end
	end
	return nil
end

function math.interval(x, a, b)
	return math.min(math.max(x, a), b)
end

function byteToString(bytes)
	local str = ''
	for i=1,8 do
		str = str .. string.char(bytes[i])
	end
	return str
end

function stringToByte(str)
	return {str:byte(1,8)}
end

function readDouble(str)
	local bytes = stringToByte(str)
	local sign = 1
	local mantissa = bytes[2] % 2^4
	for i = 3, 8 do
		mantissa = mantissa * 256 + bytes[i]
	end
	if bytes[1] > 127 then sign = -1 end
	local exponent = (bytes[1] % 128) * 2^4 + math.floor(bytes[2] / 2^4)

	if exponent == 0 then
		return 0
	end
	mantissa = (math.ldexp(mantissa, -52) + 1) * sign
	return math.ldexp(mantissa, exponent - 1023)
end

function writeDouble(num)
	local bytes = {0,0,0,0, 0,0,0,0}
	if num==0 then
		return byteToString(bytes)
	end
	if num==-1/0 then
		bytes = {255,255,255,255, 255,255,255,255}
		return byteToString(bytes)
	end
	local anum = math.abs(num)

	local mantissa, exponent = math.frexp(anum)
	exponent = exponent - 1
	mantissa = mantissa * 2 - 1
	local sign = num ~= anum and 128 or 0
	exponent = exponent + 1023

	bytes[1] = sign + math.floor(exponent / 2^4)
	mantissa = mantissa * 2^4
	local currentmantissa = math.floor(mantissa)
	mantissa = mantissa - currentmantissa
	bytes[2] = (exponent % 2^4) * 2^4 + currentmantissa
	for i= 3, 8 do
		mantissa = mantissa * 2^8
		currentmantissa = math.floor(mantissa)
		mantissa = mantissa - currentmantissa
		bytes[i] = currentmantissa
	end
	return byteToString(bytes)
end

function requireFolder(path, skip)
	for line in love.filesystem.lines(path .. '/files.txt') do
		if line~=skip then --skip this file
			require(path .. '/' .. line)
		end
	end
end

function compileProject(files, dir)
	print('Start compiling...')
	dir = dir or ''
	for i,path in ipairs(scandir(dir, {format=true})) do
		--compile single files
		local point = path:find('%.')
		local fileFormat = point and path:sub(point, -1):lower() or ''
		if fileFormat=='.lua' then
			print('single', path)
			--load
			local chunk, err = love.filesystem.load(dir .. path)
			if err then
				error(err)
				return
			end
			
			--compile
			local cmp = string.dump(chunk)
			
			--save
			local newPath = dir .. (files[path:sub(1, -5):lower()] or path)
			success, message = love.filesystem.write('cmp/' .. newPath, cmp)
		end
		
		--compile folders
		if fileFormat=='' then
			if files[path:lower()] then
				print('folder', dir .. path)
				
				--create folder
				love.filesystem.createDirectory('cmp/' .. dir .. path)
				
				--prepare files
				local newFiles = {}
				for line in love.filesystem.lines(dir .. path .. '/files.txt') do
					print('sub', line)
					newFiles[#newFiles+1] = line
					newFiles[line:lower()] = line .. '.lua'
				end
				
				--copy files.txt
				love.filesystem.write('cmp/' .. dir .. path .. '/files.txt', love.filesystem.read(dir .. path .. '/files.txt'))
				
				--compile files
				compileProject(newFiles, dir .. path .. '/')
			end
		end
	end
	
	print('end')
end

local invertDir = {
	up = 'down',
	left = 'right',
	down = 'up',
	right = 'left',
}
function invertDirection(dir)
	return invertDir[dir]
end

local orientationDir = {
	up = 'vertical',
	left = 'horizontal',
	down = 'vertical',
	right = 'horizontal',
}
function getDirectionOrientation(dir)
	return orientationDir[dir]
end

local dtdConst = {
	right = {1, 0},
	up = {0, -1},
	left = {-1, 0},
	down = {0, 1},
}
function directionToDistance(dir)
	local r = dtdConst[dir]
	return r[1], r[2]
end

local dtaConst = {
	right = 0,
	up = -math.pi/2,
	left = math.pi,
	down = math.pi/2,
}
function directionToAngle(dir)
	return dtaConst[dir]
end

local atdConst = {
	'right',
	'down',
	'left',
	'up',
}
function angleToDirection(angle)
	return atdConst[math.round(angle/(math.pi/2))%4+1]
end

local dtiConst = {
	right = 0,
	up = 1,
	left = 2,
	down = 3,
}
function directionToID(dir)
	return dtiConst[dir]
end

local dfiConst = {
	[0] = 'right',
	[1] = 'up',
	[2] = 'left',
	[3] = 'down',
}
function directionFromID(id)
	return dfiConst[id]
end

function getDirection(dx, dy)
	if dx>0 then
		return 'right'
	end
	if dx<0 then
		return 'left'
	end
	if dy>0 then
		return 'down'
	end
	if dy<0 then
		return 'up'
	end
end

if love then
	local oldGetDimensions = love.graphics.getDimensions
	function love.graphics.getDimensions(dontCut)
		local w,h = oldGetDimensions()
		if dontCut then
			return w,h
		end
		local dx = 0
		local dy = 0
		if w/h<=16/9 then
			local oldH = h
			h = w*9/16
			dy = (oldH-h)/2
		else
			local oldW = w
			w = h*16/9
			dx = (oldW-w)/2
		end
		return w, h, dx, dy, 0.5+dx/w, 0.5+dy/h
	end
	
	function love.graphics.extraTranslate()
		local w, h, dx, dy = love.graphics.getDimensions()
		love.graphics.translate(dx, dy)
	end
	
	--[[
	function love.graphics.extraScissor()
		local w, h, dx, dy = love.graphics.getDimensions()
		love.graphics.setScissor(dx, dy, w, h)
	end
	--]]
	
	local super = {}
	function love.graphics.superpush()
		love.graphics.push()
		super.color = {love.graphics.getColor()}
		super.shader = love.graphics.getShader()
		--super.canvas = love.graphics.getCanvas()
	end
	
	function love.graphics.superorigin()
		love.graphics.origin()
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setShader()
	end
	
	function love.graphics.superpop()
		love.graphics.pop()
		love.graphics.setColor(super.color)
		love.graphics.setShader(super.shader)
		--love.graphics.setCanvas(super.canvas)
	end
	
	do
		local it = 10
		local alpha = 30
		
		function love.graphics.printfWithShadow(...)
			--save previous info
			local r,g,b,a = love.graphics.getColor()
			love.graphics.push()
			
			--shadow draw
			local tr = love.graphics.getFont():getHeight()*0.1
			local dr = tr/it
			for i=1,it do
				love.graphics.setColor(0, 0, 0, alpha*a/255)
				love.graphics.translate(dr, dr)
				love.graphics.printf(...)
			end
			
			--reload previous info
			love.graphics.pop()
			love.graphics.setColor(r, g, b, a)
			
			--normal draw
			love.graphics.printf(...)
		end
		
		function love.graphics.withShadow(draw, ...)
			local draw = love.graphics[draw]
			
			--save previous info
			local r,g,b,a = love.graphics.getColor()
			love.graphics.push()
			
			--shadow draw
			local tr = 0.05
			local dr = tr/it
			for i=1,it do
				love.graphics.setColor(0, 0, 0, alpha*a/255)
				love.graphics.translate(dr, dr)
				draw(...)
			end
			
			--reload previous info
			love.graphics.pop()
			love.graphics.setColor(r, g, b, a)
			
			--normal draw
			draw(...)
		end
		
		function love.graphics.drawWithShadow(...)
			love.graphics.withShadow('draw', ...)
		end
	end
	
	do
		local iterations = 5
		local blurShader = love.graphics.newShader('blurShader.glsl')
		local oldCanvas, blurCanvas, auxCanvas
		local oldW, oldH
		function startBlur()
			oldCanvas = love.graphics.getCanvas()
			
			local w, h
			if oldCanvas then
				w, h = oldCanvas:getDimensions(true)
			else
				w, h = love.graphics.getDimensions(true)
			end
			
			if oldW~=w or oldH~=h then
				oldW = w
				oldH = h
				blurCanvas = love.graphics.newCanvas(w, h)
				auxCanvas = love.graphics.newCanvas(w, h)
				blurShader:send('diff', {2/w, 2/h})
			end
			
			love.graphics.setCanvas(blurCanvas)
			love.graphics.clear()
		end
	
		function applyBlur(modifier)
			modifier = modifier or 1
			
			--save previous settings
			local oldShader = love.graphics.getShader()
			local r,g,b,a = love.graphics.getColor()
			love.graphics.push()
			
			--set new settings
			love.graphics.origin()
			love.graphics.setShader(blurShader)
			love.graphics.setColor(255, 255, 255, 255)
			
			--blur
			for i=1,iterations*modifier do
				love.graphics.setCanvas(auxCanvas)
				love.graphics.clear()
				love.graphics.draw(blurCanvas)
				blurCanvas, auxCanvas = auxCanvas, blurCanvas
			end
			
			--reset previous settings
			love.graphics.setColor(r, g, b, a)
			love.graphics.pop()
			love.graphics.setShader(oldShader)
		end
		
		function endBlur()
			--save state
			local oldShader = love.graphics.getShader()
			local r,g,b,a = love.graphics.getColor()
			love.graphics.push()
			
			--undo all transforms
			love.graphics.setShader()
			love.graphics.setColor(255, 255, 255, 255)
			love.graphics.origin()
			
			--draw on screen
			love.graphics.setCanvas(oldCanvas)
			love.graphics.draw(blurCanvas)
			
			--load state
			love.graphics.pop()
			love.graphics.setColor(r, g, b, a)
			love.graphics.setShader(oldShader)
		end
	end
	
	local textInput = ''
	function love.textinput(text)
		textInput = text
	end
	function love.getTextInput()
		return textInput
	end
	function love.clearTextInput()
		textInput = ''
	end
	
	local wheelX, wheelY = 0, 0
	function love.wheelmoved(x, y)
		wheelX = x
		wheelY = y
	end
	function love.getWheel()
		return wheelX, wheelY
	end
	
	love.keyboard.setKeyRepeat(true)
	local keyTable = {}
	function love.keypressed(key)
		keyTable[key] = true
	end
	function love.isKeyPressed(key)
		return keyTable[key]
	end
	
	function love.hasResized(oldW, oldH)
		local w,h = love.graphics.getDimensions()
		return w~=oldW or h~=oldH
	end
	
	function love.reset()
		wheelX = 0
		wheelY = 0
		textInput = ''
		keyTable = {}
		resized = false
	end
	
	function love.fileOpen(filename, mode)
		local file, err = love.filesystem.newFile(filename, mode or 'r')
		if not err then
			return file
		else
			return nil, err
		end
	end
	
	function love.fileWrite(file, data)
		return file:write(data)
	end
	
	function love.fileRead(file, ...)
		local r = {}
		for i,arg in ipairs{...} do
			if type(arg)=='number' then --bytes
				local d, a = file:read(arg)
				if a==0 then
					return
				end
				--[[if d=='\r' then
					d = file:read(1)
				end]]
				r[i] = d
				
				
			elseif arg=='*n' then
				--find first number
				repeat
					local d, a = file:read(1)
					if a==0 then
						return
					end
				until tonumber(d)
				file:seek(file:tell()-1)
				
				--read number
				local n = ''
				repeat
					local d = file:read(1)
					n = n .. d
				until tonumber(d)==nil and d~='.'
				file:seek(file:tell()-1)
				r[i] = tonumber(n:sub(1,-2))
				
			elseif arg=='*line' then
				--find \n
				local s = ''
				repeat
					local d = file:read(1)
					if d=='\r' then
						d = file:read(1)
					end
					s = s .. d
				until d=='\n'
				r[i] = s:sub(1,-2)
				
			else
				error('Unknown read string: ' .. arg, 2)
			end
		end
		return unpack(r)
	end
	
	function love.audio.newSound(path, volume, loop)
		local source = love.audio.newSource(path)
		source:setVolume(volume or 1)
		if loop then
			source:setLooping(true)
		end
		return source
	end

	function love.keyboard.isDown2(key)
		--use regular function if single value
		if type(key)~='table' then
			return love.keyboard.isDown(key)
		end
		
		--call recursively for each value
		for i,k in ipairs(key) do
			if love.keyboard.isDown2(k) then
				return true
			end
		end
		return false
	end
end

function wait(duration)
	coroutine.yield(function(dt)
		duration = duration - dt
		return duration<=0
	end)
end

function checkParameters(command, parameters, types)
	local t
	local i = 1
	while parameters[i] or types[i] do
		local p = parameters[i]
		t = types[i] or t --keep previous type if inexistent (used for ... parameters)
		local pt = class(p)
		if class(t)=='table' then
			local correct = false
			for j,tt in ipairs(t) do
				if pt==tt then
					correct = true
					break
				end
			end
			if not correct then
				local errorMsg = 'bad argument #' .. i .. " to '" .. command .. "' ("
				for j,tt in ipairs(t) do
					if j==#t then --last
						errorMsg = errorMsg .. tostring(tt)
					elseif j==#t-1 then --last but one
						errorMsg = errorMsg .. tostring(tt) .. ' or '
					else --other
						errorMsg = errorMsg .. tostring(tt) .. ', '
					end
				end
				errorMsg = errorMsg .. ' expected, got ' .. tostring(pt) .. ')'
				error(errorMsg, 3)
			end
		else
			if pt~=t then
				error('bad argument #' .. i .. " to '" .. command .. "' (" .. tostring(t) .. ' expected, got ' .. tostring(pt) .. ')', 3)
			end
		end
		i = i + 1
	end
end

if love then
	local globalBtnFlag = {}
	function love.mouse.btnpressed(btn, btnFlag)
		btnFlag = btnFlag or globalBtnFlag
		if love.mouse.isDown(btn) then
			if not btnFlag[btn] then
				btnFlag[btn] = true
				return true
			end
		else
			btnFlag[btn] = nil
		end
		return false
	end

	local globalKeyFlag = {}
	function love.keyboard.keypressed(key, keyFlag)
		if type(key)=='table' then
			local ret = false
			for i, k in ipairs(key) do
				ret = ret or love.keyboard.keypressed(k, keyFlag)
			end
			return ret
		end
		
		keyFlag = keyFlag or globalKeyFlag
		if love.keyboard.isDown(key) then
			if keyFlag[key] then
				keyFlag[key] = nil
				return true
			end
		else
			keyFlag[key] = true
		end
		return false
	end
end

function table.random(t)
	if #t==0 then
		return nil
	end
	local r = math.random(1, #t)
	return t[r]
end

function table.merge(t1, t2)
	for i,e in ipairs(t2) do
		t1[#t1+1] = e
	end
end

function table.shuffle(t)
	for i=1,#t do
		local j = math.random(i, #t)
		t[i],t[j] = t[j],t[i]
	end
end

function table.update(t, update, ...)
	for i,e in ipairs(t) do
		t[i] = update(e, ...)
	end
end

function table.select(t, better, ...)
	local best = nil
	for i,e in ipairs(t) do
		if best==nil or better(e, best, ...) then
			best = e
		end
	end
	return best
end

function table.filter(t, filter, ...)
	local t2 = {}
	for i,e in ipairs(t) do
		if filter(e, ...) then
			t2[#t2+1] = e
		end
	end
	return t2
end

function table.exists(t, condition, ...)
	for i,e in ipairs(t) do
		if condition(e, ...) then
			return true
		end
	end
	return false
end

function isClass(obj, cl)
	return class(obj)==cl
end

function class(object)
	local t = type(object) 
	if t~='table' then
		return t
	end
	
	local mt = getmetatable(object)
	return mt or t
end

function createClass(class, constructor, name)
	--object metatable
	class.__index = class
	class.new = function(self, ...)
		if self==class then
			--create new self
			self = {}
			setmetatable(self, class)
		end
		self = constructor(self, ...) or self
		return self
	end
	
	--class metatable
	setmetatable(class, {
		__tostring = name and function()
			return name
		end,
	})
	
	return class
end

function screenshot(path)
	if os.rename(path, path) then
		os.remove(path)
	end
	local name = 'temp.png'
	local screenshot = love.graphics.newScreenshot()
	screenshot:encode('png', name)
	--os.execute('convert "' .. love.filesystem.getAppdataDirectory() .. '/LOVE/' .. love.filesystem.getIdentity() .. '/' .. name .. '" "' .. path .. '"')
	os.rename(love.filesystem.getAppdataDirectory() .. '/LOVE/' .. love.filesystem.getIdentity() .. '/' .. name, path)
end

function string.readF(s, ...)
	local t = {...}
	local pattern = ''
	for i,p in ipairs(t) do
		pattern = pattern .. '(' .. p .. ') '
	end
	pattern = pattern:gsub(' $', '')
	local ret = {s:find(pattern)}
	table.remove(ret, 1)
	table.remove(ret, 1)
	return unpack(ret)
end

function os.copy(source, dest)
	local sf = io.open(source, 'rb')
	local df = io.open(dest, 'wb')
	df:write(sf:read('*a'))
	sf:close()
	df:close()
end

function tableInsertC(t, callback, elem)
	local a = 0
	local b = #t+1
	while b ~= a+1 do
		local m = math.floor((a+b)/2)
		if callback(elem, t[m]) then
			b = m
		else
			a = m
		end
	end
	table.insert(t, b, elem)
end

function tostring2(elem)
	if type(elem)=='string' then
		return "'" .. elem .. "'"
	else
		return tostring(elem)
	end
end

function printR(elem, hist, tabs)
	hist = hist or {}
	tabs = tabs or 0
	if type(elem)~='table' then
		print(tostring2(elem))
	else
		if not hist[elem] then
			hist[elem] = true
			print(tostring2(elem) .. ' {')
			tabs = tabs + 1
			for i,e in pairs(elem) do
				io.write(string.rep('\t', tabs) .. '[' .. tostring2(i) .. '] ')
				printR(e, hist, tabs)
			end
			tabs = tabs - 1
			print(string.rep('\t', tabs) .. '}')
		else
			print(tostring2(elem) .. ' {...}')
		end
	end
end

function printRToFile(file, elem, hist, tabs)
	hist = hist or {}
	tabs = tabs or 0
	if type(elem)~='table' then
		file:write(tostring2(elem) .. '\n')
	else
		if not hist[elem] then
			hist[elem] = true
			file:write(tostring2(elem) .. ' {\n')
			tabs = tabs + 1
			for i,e in pairs(elem) do
				file:write(string.rep('\t', tabs) .. '[' .. tostring2(i) .. '] ')
				printRToFile(file, e, hist, tabs)
			end
			tabs = tabs - 1
			file:write(string.rep('\t', tabs) .. '}\n')
		else
			file:write(tostring2(elem) .. ' {...}\n')
		end
	end
end

function copyR(t, hist)
	hist = hist or {}
	if type(t)~='table' then
		return t
	end
	if hist[t] then
		return hist[t]
	end
	local c = {}
	setmetatable(c, getmetatable(t))
	hist[t] = c
	for i,value in pairs(t) do
		c[i] = copyR(value, hist)
	end
	return c
end

function compareR(elem1, elem2, hist)
	hist = hist or {}
	if type(elem1)~=type(elem2) then
		return false
	end
	if type(elem1)~='table' then
		return elem1==elem2
	end
	hist[elem1] = hist[elem1] or {}
	if not hist[elem1][elem2] then
		hist[elem1][elem2] = true
		for i, e1 in pairs(elem1) do
			local e2 = elem2[i]
			if not compareR(e1, e2, hist) then
				return false
			end
		end
		for i, e2 in pairs(elem2) do
			local e1 = elem1[i]
			if not compareR(e1, e2, hist) then
				return false
			end
		end
	end
	return true
end

function makeBackup(t, hist)
	hist = hist or {}
	if type(t)~='table' then
		return t
	end
	if hist[t] then
		return hist[t]
	end
	local c = {
		address = t,
		data = {},
	}
	setmetatable(c.data, getmetatable(t))
	hist[t] = c
	for i,value in pairs(t) do
		c.data[i] = makeBackup(value, hist)
	end
	return c
end

function restoreBackup(t, hist)
	hist = hist or {}
	if type(t)~='table' then
		return t
	end
	if hist[t] then
		return hist[t]
	end
	local c = t.address
	hist[t] = c
	for i in pairs(c) do
		c[i] = nil
	end
	for i,value in pairs(t.data) do
		c[i] = restoreBackup(value, hist)
	end
	return c
end

function concatTable(t1, t2)
	local count = 0
	for i,v in ipairs(t2) do
		table.insert(t1, v)
		count = count + 1
	end
	return count
end

function concatSet(t1, t2)
	local count = 0
	for i,v in pairs(t2) do
		if not t1[i] then
			t1[i] = v
			count = count + 1
		end
	end
	return count
end

function isNan(n)
	return n~=n
end

function getNearest(self, target)
	local nearestTarget
	local nearestDist = math.huge
	for i,t in ipairs(target) do
		local dist = math.abs(t.x-self.x) + math.abs(t.y-self.y)
		if dist<nearestDist then
			nearestDist = dist
			nearestTarget = t
		end
	end
	return nearestTarget, nearestDist
end

function scandir(directory, arg)
	arg = arg or {}
	local i = 0
	local t = {}
	local tmp = io.popen('dir /B ' .. (arg.dirOnly and '/ad ' or '')  .. (arg.recursive and '/s ' or '')  .. '"' .. directory .. '"')
	for filename in tmp:lines() do
		if not arg.format then
			filename = filename:gsub('%..*', '')
		end
		i = i + 1
		t[i] = filename
	end
	tmp:close()
	return t
end

function random(...)
	local t = {...}
	return t[math.random(1, #t)]
end

function math.lerp(a, b, t)
	return a*(1-t) + b*t
end






































