--[[
	Try to run GC if we cross a certain threshold of created
	SDL/sdlext objects, in an attempt to clean them up.
--]]
local gccounter = 0
local function checkGC()
	gccounter = gccounter + 1
	if gccounter > 10000 then
		gccounter = 0
		collectgarbage("collect")
		LOG("sdlext triggered GC")
	end
end

local oldsdltext = sdl.text
function sdl.text(font, textset, text)
	checkGC()

	return oldsdltext(font, textset, text)
end

local resourceDat = sdl.resourceDat("resources/resource.dat")
local resourceDatMtime = os.mtime("resources/resource.dat")
local function checkResource()
	local mtime = os.mtime("resources/resource.dat")
	if resourceDatMtime ~= mtime then
		resourceDatMtime = mtime
		resourceDat:reload()
	end
end

sdlext = {}

function sdlext.font(path,size)
	checkResource()
	checkGC()
	
	local blob = sdl.blobFromResourceDat(resourceDat,path)
	if blob.length==0 then
		return sdl.filefont(path, size)
	end

	return sdl.filefontFromBlob(blob,size)
end

function sdlext.surface(path)
	checkResource()
	checkGC()
	
	local blob = sdl.blobFromResourceDat(resourceDat,path)
	if blob.length==0 then
		return sdl.surface(path)
	end
	
	return sdl.surfaceFromBlob(blob)
end

function sdlext.squadPalettes()
	local GetColorMapOld = GetColorMap
	local GL_ColorOld = GL_Color
	function GL_Color(r,g,b,a)
		if a == nil then
			return sdl.rgb(r,g,b)
		else
			return sdl.rgba(r,g,b,a)
		end
	end
	
	require("scripts/color_map")
	local res = {}
	
	for i=1,GetColorCount() do
		res[i]=GetColorMap(i)
	end
	
	GetColorMap = GetColorMapOld
	GL_Color = GL_ColorOld

	return res
end

function sdlext.config(filename, func)
	local path = GetSavedataLocation()
	os.mkdir(path)

	local obj = persistence.load(path..filename)
	obj = obj or {}
	
	func(obj)
	
	persistence.store(path..filename, obj)
end

function drawborder(screen, color, rect, borderwidth, temprect)
	if not temprect then temprect = sdl.rect(0,0,0,0) end

	-- left side
	temprect.x = rect.x
	temprect.y = rect.y
	temprect.w = borderwidth
	temprect.h = rect.h
	screen:drawrect(color, temprect)

	-- right side
	temprect.x = rect.x + rect.w - borderwidth
	screen:drawrect(color, temprect)

	-- top side
	temprect.x = rect.x
	temprect.y = rect.y
	temprect.w = rect.w
	temprect.h = borderwidth
	screen:drawrect(color, temprect)

	-- bottom side
	temprect.y = rect.y + rect.h - borderwidth
	screen:drawrect(color, temprect)
end

function drawtri_tl(screen, color, rect, temprect)
	if not temprect then temprect = sdl.rect(0,0,0,0) end

	for y = 0, rect.h do
		temprect.x = rect.x
		temprect.y = rect.y + y
		temprect.w = rect.w * (1 - y / rect.h)
		temprect.h = 1

		screen:drawrect(color, temprect)
	end
end

function drawtri_tr(screen, color, rect, temprect)
	if not temprect then temprect = sdl.rect(0,0,0,0) end

	for y = 0, rect.h do
		temprect.w = rect.w * (1 - y / rect.h)
		temprect.x = rect.x + rect.w - temprect.w
		temprect.y = rect.y + y
		temprect.h = 1

		screen:drawrect(color, temprect)
	end
end

function drawtri_bl(screen, color, rect, temprect)
	if not temprect then temprect = sdl.rect(0,0,0,0) end

	for y = 0, rect.h do
		temprect.x = rect.x
		temprect.y = rect.y + y
		temprect.w = rect.w * (y / rect.h)
		temprect.h = 1

		screen:drawrect(color, temprect)
	end
end

function drawtri_br(screen, color, rect, temprect)
	if not temprect then temprect = sdl.rect(0,0,0,0) end

	for y = 0, rect.h do
		temprect.w = rect.w * (y / rect.h)
		temprect.x = rect.x + rect.w - temprect.w
		temprect.y = rect.y + y
		temprect.h = 1

		screen:drawrect(color, temprect)
	end
end

local function rect_contains0(x, y, w, h, px, py)
	return px > x     and
	       px < x + w and
	       py > y     and
	       py < y + h
end

--[[
	rect_contains(rect, px, py)
	OR
	rect_contains(x, y, w, h, px, py)
--]]
function rect_contains(...)
	local a = {...}
	assert(#a == 3 or #a == 6, "Invalid arguments")

	if #a == 3 then
		return rect_contains0(
			a[1].x, a[1].y,
			a[1].w, a[1].h,
			a[2],   a[3]
		)
	else
		return rect_contains0(...)
	end
end

function rect_intersects(r1, r2)
	return not (r2.x > r1.x + r1.w or
	            r2.x + r2.w < r1.x or
	            r2.y > r1.y + r1.h or
	            r2.y + r2.h < r1.y)
end

--[[
	rect_equals(rect1, rect2)
	OR
	rect_equals(rect, x, y, w, h)
		x, y, w, and h arguments can be nil, defaulting to 0
--]]
function rect_equals(...)
	local a = {...}
	assert(#a <= 5, "Invalid arguments")

	if #a == 2 then
		return a[1].x == a[2].x and
		       a[1].y == a[2].y and
		       a[1].w == a[2].w and
		       a[1].h == a[2].h
	else
		a[2] = a[2] or 0
		a[3] = a[3] or 0
		a[4] = a[4] or 0
		a[5] = a[5] or 0

		return a[1].x == a[2] and
		       a[1].y == a[3] and
		       a[1].w == a[4] and
		       a[1].h == a[5]
	end
end

--[[
	rect_set(rect1, rect2)
	OR
	rect_set(rect, x, y, w, h)
		x, y, w, and h arguments can be nil, defaulting to 0
--]]
function rect_set(...)
	local a = {...}
	assert(#a <= 5, "Invalid arguments")

	if #a == 2 then
		a[1].x = a[2].x
		a[1].y = a[2].y
		a[1].w = a[2].w
		a[1].h = a[2].h
	else
		a[1].x = a[2] or 0
		a[1].y = a[3] or 0
		a[1].w = a[4] or 0
		a[1].h = a[5] or 0
	end
end
