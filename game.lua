-- title:  Ant racer
-- author: @zlatovlas
-- desc:   Infinite runner type game made for Slovak rally team red ants
-- script: lua
-- input:  gamepad
-- saveid: antracer1

--[[ SETTINGS ]]--
settings={
	bb=false, --show bounding box
	high_score=pmem(2),
	tutorial=true
}

if pmem(0) == 0 then
	settings.music = true
else
	settings.music = false
end

if pmem(1) == 0 then
	settings.sound = true
else
	settings.sound = false
end


--[[ CODE ]]--
function overlap(x_min1, x_max1, x_min2, x_max2)
	return x_max1 >= x_min2 and x_max2 >= x_min1
end

function scale(value, istart, istop, ostart, ostop)
	return ostart + (ostop - ostart) * ((value - istart) / (istop - istart));
end

function choose(t)
    local i = math.random(1, #t)
    return t[i]
end

function Positioner(total, initial)
	initial = initial or 1
	local pos = initial
	return {
		add = function()
			pos = pos + 1
		end,
		sub = function()
			pos = pos - 1
		end,
		pos = function()
			return ((pos - 1) % total) + 1
		end
	}
end

function Shaker(duration)
	local d = 2
	local t = 0
	local strategy = nil
	local function empty(dt) end
	local function shake(dt)
		t = t + dt
		if t >= duration then
			memset(0x3FF9, 0, 2)
			strategy = empty
		else
			poke(0x3FF9, math.random(-d, d))
			poke(0x3FF9 + 1, math.random(-d, d))
		end
	end

	strategy = shake
	if duration == nil then
		strategy = empty
	end

	return function(dt)
		strategy(dt)
	end
end

--[[ STAGE ]]--
Stage = {}
function Stage:new(o)
	o = o or {}
	setmetatable(o, {__index=self})
	return o
end

function Stage:init() end
function Stage:update(dt) end
function Stage:quit() end

function StageManager()

	local stages = {}
	local actual_stage = {
		instance=Stage:new() -- Phony stage
	}

	return {
		add = function(name, stage)
			stages[name] = {
				name=name,
				proto=stage,
				instance=nil
			}
		end,
		switch = function(name, keep_instance)
			keep_instance = keep_instance or false
			local new_stage = stages[name]

			if new_stage == nil then return end
			if actual_stage.name == name then return end

			actual_stage.instance:quit()
			if not keep_instance then actual_stage.instance = nil end

			if new_stage.instance == nil then
				new_stage.instance = new_stage.proto:new()
				new_stage.instance:init()
			end

			actual_stage = new_stage
		end,
		update = function(dt)
			actual_stage.instance:update(dt)
		end
	}
end

--[[ ENTITY ]]--
Entity={
	x=0,y=0,
	ox=0,oy=0,
	w=8,h=8,
	sprh=8, --used in sorting mechanism during draw
	alive=true,
	active=true,
	stage=nil
}

function Entity:new(o)
	o=o or {}
	return setmetatable(o, {__index=self})
end

function Entity:overlap(e)
	local e1_x=self.x+self.ox
	local e1_y=self.y+self.oy
	local e2_x=e.x+e.ox
	local e2_y=e.y+e.oy
	return overlap(e1_x,e1_x+self.w,e2_x,e2_x+e.w) and
		overlap(e1_y,e1_y+self.h,e2_y,e2_y+e.h)
end

function Entity:draw() end
function Entity:update(dt) end

--[[ DRINK ]]--
Drink=Entity:new{
	type="drink",
	pos=0,oy=4,h=4
}
function Drink:draw() spr(352,self.x,self.y,0) end
function Drink:update(dt)
	self.x=self.x-(self.stage.road_pos-self.pos)/1.5
	self.pos=self.stage.road_pos
end

--[[ FUEL ]]--
Fuel=Entity:new{
	type="fuel",
	pos=0,ox=4,oy=10,h=5
}
function Fuel:draw() spr(341,self.x,self.y,0,1,0,0,2,2) end
function Fuel:update(dt)
	self.x=self.x-(self.stage.road_pos-self.pos)/1.5
	self.pos=self.stage.road_pos
end

--[[ OIL ]]--
Oil=Entity:new{
	type="oil",
	pos=0
}
function Oil:draw() spr(354, self.x, self.y, 7) end
function Oil:update(dt)
	self.x = self.x - (self.stage.road_pos - self.pos)
	self.pos = self.stage.road_pos
end

--[[ FOREIGN CAR ]]--
Car=Entity:new{
	type="car",
	pos=0,
	ox=2,
	oy=12,
	w=28,
	h=12,
	sprh=24,
	spr=304
}
function Car:draw() spr(self.spr, self.x, self.y, 0, 1, 0, 0, 4, 3) end
function Car:update(dt)
	self.x = self.x - (self.stage.road_pos - self.pos) / 2
	self.pos = self.stage.road_pos
end

--[[ PLAYER ]]--
Player=Entity:new{
	type="player",
	ax=.0,
	ay=.0,
	vx=.0,
	vy=.0,
	fuel=20.0,
	offroad=false
}

function Player:draw()
	local index=256
	if self.y < 34 then
		index=260
	elseif self.y > 89 then
		index=264
	end
	spr(index,self.x,self.y,0,1,0,0,4,3)
end

function Player:update(dt)
	if self.stage.state=="enter" then
		self.x=self.x+0.02*dt
		if self.x>=16 then
			self.x=16
			self.stage.state="game"
		end
	elseif self.stage.state=="game" then
		local ay = 0.00012
		local vy = 0.06

		if btn(0) then
			self.ay = -ay
		elseif btn(1) then
			self.ay = ay
		else
			self.vy = self.vy -(self.vy * vy)
		end

		self.vx = self.vx + self.ax * dt
		self.vy = self.vy + self.ay * dt
		self.x  = self.x  + self.vx * dt
		self.y  = self.y  + self.vy * dt

		self.ay = .0

		if self.y < 32 then
			if not self.offroad then
				if settings.sound then sfx(7, 24, 30, 3) end
				self.offroad = true
			end
			self.y = 32
			self.vy = 0
		elseif self.y > 90 then
			if not self.offroad then
				if settings.sound then sfx(7, 24, 30, 3) end
				self.offroad = true
			end
			self.y = 90
			self.vy = 0
		else
			self.offroad = false
		end

		self.fuel = self.fuel - 0.01
		self.fuel = math.max(0, self.fuel)
		if self.fuel == 0 then
			music()
			if settings.sound then sfx(7, 12, 60, 3) end
			self.stage.fuel_blink = true
			self.stage.state = "game over"
			pmem(2, settings.high_score)
		end
	end
end

--[[ INTRO STAGE ]]--
Intro=Stage:new{
	t_blink=0,
	visible=true
}

function Intro:init()
	if settings.music then music(0) end
end

function Intro:update(dt)
	self:draw()

	if btnp(5) then
		sm.switch("menu")
	end

	self.t_blink=self.t_blink+dt
	if self.t_blink > 1000 then
		self.visible= not self.visible
		self.t_blink=0
	end
end

function Intro:draw()
	cls(0)
	if self.visible then
		print("Press x to continue", 64, 64)
	end
end

--[[ MENU STAGE]]--
Menu = Stage:new{
	p = nil
}

function Menu:init()
	if settings.music then music(1) end
	self.p = Positioner(2)
end

function Menu:update(dt)
	self:draw()

	if btnp(0) then
		if settings.sound then sfx(5, 24, -1, 3) end
		self.p.sub()
	elseif btnp(1) then
		if settings.sound then sfx(5, 24, -1, 3) end
		self.p.add()
	elseif btnp(4) or btnp(5) then
		if settings.sound then sfx(5, 36, -1, 3) end
		if self.p.pos()==1 then
			if settings.tutorial then
				sm.switch("tutorial")
			else
				sm.switch("game")
			end
		elseif self.p.pos()==2 then
			sm.switch("settings", true)
		end
	end
end

function Menu:draw()
	local y = 64
	cls(0)
	map(30,17,30,17,0,-24)
	print("Let's race", 90, y)
	print("Settings", 90, y + 8)
	spr(368, 80, (self.p.pos() - 1) * 8 + y - 2)
end

--[[ SETTINGS STAGE ]]--
Settings=Stage:new{
	p=nil
}

function Settings:init()
	self.p = Positioner(3)
end

function Settings:update(dt)
	self:draw()

	if btnp(0) then
		if settings.sound then sfx(5, 24, -1, 3) end
		self.p.sub()
	elseif btnp(1) then
		if settings.sound then sfx(5, 24, -1, 3) end
		self.p.add()
	elseif btnp(4) or btnp(5) then
		if settings.sound then sfx(5, 36, -1, 3) end
		if self.p.pos() == 1  then
			settings.music = not settings.music
			if settings.music then
				music(1)
				pmem(0, 0)
			else
				music()
				pmem(0, 1)
			end
		elseif self.p.pos() == 2 then
			settings.sound = not settings.sound
			if settings.sound then
				pmem(1, 0)
			else
				pmem(1, 1)
			end
		elseif self.p.pos() == 3 then
			sm.switch("menu")
		end
	end
end

function Settings:draw()
	local y = 64
	cls(0)
	map(30,17,30,17,0,-24)
	print("Music", 90, y)
	print(settings.music and "ON" or "OFF", 90 + 48, y)
	print("Sound", 90, y + 8)
	print(settings.sound and "ON" or "OFF", 90 + 48, y + 8)
	print("Back", 90, y + 16)
	spr(368, 80, (self.p.pos() - 1) * 8 + y - 2)
end

--[[ TUTORIAL STAGE ]]--
Tutorial=Stage:new{
	t_blink=0,
	visible=true,
	up_pressed=false,
	down_pressed=false
}

function Tutorial:update(dt)
	cls(0)

	spr(256, 0, 0, 0, 1, 0, 0, 4, 3)
	print("YOU ARE", 40, 8, 14)
	print("R. Pravda", 40, 16)

	spr(407, 0, 24, 0, 1, 0, 0, 4, 3)
	print("Bye in 1000 m", 40, 32, 14)
	print("L. Danda", 40, 40)

	spr(359, 0, 48, 0, 1, 0, 0, 4, 3)
	print("Bye in 2000 m", 40, 56, 14)
	print("T. Nekonecny", 40, 64)

	spr(311, 0, 72, 0, 1, 0, 0, 4, 3)
	print("Bye in 3000 m", 40, 80, 14)
	print("P. Vaglak", 40, 88)

	spr(341, 128, 7, 0, 1, 0, 0, 2, 2)
	print("Take this", 148, 8, 14)
	print("Fuel", 148, 16)

	spr(352, 132, 7 + 24)
	print("Life", 148, 32, 14)
	print("Energy drink", 148, 40)

	spr(354, 132, 56)
	print("Avoid this", 148, 56, 14)
	print("Oil", 148, 64)

	if self.visible then
		print("Press", 34, 120)
		if self.up_pressed then
			print("UP", 34 + 36, 120, 14)
		else
			print("up", 34 + 36, 120)
		end
		print("and", 34 + 54, 120)
		if self.down_pressed then
			print("DOWN", 34 + 78, 120, 14)
		else
			print("down", 34 + 78, 120)
		end
		print("to continue!", 34 + 105, 120)
	end

	self.t_blink=self.t_blink+dt
	if self.t_blink > 500 then
		self.visible= not self.visible
		self.t_blink=0
	end

	if btnp(0) then
		if not self.up_pressed then
			if settings.sound then sfx(8, 48, -1, 3) end
			self.up_pressed=true
		end
	end

	if btnp(1) then
		if not self.down_pressed then
			if settings.sound then sfx(8, 48, -1, 3) end
			self.down_pressed=true
		end
	end

	if self.up_pressed and self.down_pressed then
		settings.tutorial = false
		sm.switch("game")
	end
end


--[[ GAME STAGE ]]--
Game=Stage:new{
	entities=nil,
	distance=0,
	drinks=0,
	player=nil,
	road_vx=.15,
	road_pos=0,
	state="enter",
	last_obstacle=0,
	next_obstacle=240, -- in px
	last_fuel=1000,
	next_fuel=4500, -- in px
	fuel_blink=false,
	fuel_blink_t=0,
	fuel_orange=true,
    landa=false,
	konecny=false,
	gavlak=false,
	shaker=nil
}

function Game:init()
	if settings.music then music(3) end
	self.entities={}
	self.player=Player:new{
		x = -48,
		y = 64,
		ox= 2,
		oy= 12,
		w = 28,
		h = 12,
		sprh=24,
		stage=self
	}
	table.insert(self.entities,self.player)
	self.shaker = Shaker()
end

function Game:shake_it(duration)
	self.shaker = Shaker(duration)
end

function Game:update(dt)

	-- Draw
	cls(0)
	self:draw_road()
	self:draw_entities()
	self:draw_ui()
	self.shaker(dt)

	if self.state == "enter" then
		print("GET READY", 64, 73, 14, false, 2)
	elseif self.state == "game over" then
		print("GAME OVER", 64, 73, 14, false, 2)
	end

	-- Update
	self:update_road(dt)
	self:update_entities(dt)

	for i,e in pairs(self.entities) do
		if self.player:overlap(e) then
			if e.type=="drink" then
				if e.alive then
					if settings.sound then sfx(6, 36, -1, 3) end
					self.drinks = self.drinks + 1
				end
				e.alive=false
			end
			if e.type=="fuel" then
				if e.alive then
					if settings.sound then sfx(6, 24, -1, 3) end
					self.player.fuel = math.min(60,self.player.fuel + math.random(10, 15))
				end
				e.alive=false
			end
			if e.type=="car" then
				if self.drinks > 0 then
					if e.alive then
						self.drinks = self.drinks - 1
						if settings.sound then sfx(7, 12, 60, 3) end
						if e.name ~= nil then self:shake_it(800) end
					end
					e.alive = false
				else
					if self.state ~= "game over" then
						music()
						if settings.sound then sfx(7, 12, 60, 3) end
						pmem(2, settings.high_score)
					end
					self.state="game over"
				end
			end
			if e.type == "oil" then
				if e.active then
					local ay = {0.003, -0.003}
					if settings.sound then sfx(8, 48, -1, 3) end
					self.player.ay = ay[math.random(1,2)]
				end
				e.active = false
			end
		end
	end

	if self.fuel_blink then
		self.fuel_blink_t = self.fuel_blink_t + dt
		if self.fuel_blink_t > 300 then
			self.fuel_orange = not self.fuel_orange
			self.fuel_blink_t = 0
		end
	end

	if self.state == "game over" then
		if btnp(4) or btnp(5) then
			sm.switch("intro")
		end
	end
end

function Game:draw_road()
	local pos = math.floor(self.road_pos)
	local tmp = pos%480
	if tmp > 239 then
		map(30,0,30,17,-(tmp-240),0)
		map( 0,0,30,17,-(tmp-240-240),0)
	else
		map( 0,0,30,17,-tmp,0)
		map(30,0,30,17,-(tmp-240),0)
	end
end

function Game:update_road(dt)

	if self.state == "game" then
		self.road_vx=self.road_vx+0.000001*dt
	end

	if self.state ~= "game over" then
		self.road_pos=self.road_pos+self.road_vx*dt
	end

	if self.state == "game" then
		self.distance = 0.1406 * self.road_pos

		if self.distance > settings.high_score then
			settings.high_score = self.distance
		end

		if self.road_pos > self.last_obstacle then
			local p={42,64,86}
			local i=math.random(1,#p)

			if self.distance > 1000 and self.landa == false then
				table.insert(self.entities, Car:new{
					pos=self.road_pos,
					x=240,
					y=p[i] + math.random(1, 5) - 2,
					stage=self,
					spr=407,
					name="landa"
				})
				self.landa = true
			elseif self.distance > 2000 and self.konecny == false then
				table.insert(self.entities, Car:new{
					pos=self.road_pos,
					x=240,
					y=p[i] + math.random(1, 5) - 2,
					stage=self,
					spr=359,
					name="konecny"
				})
				self.konecny = true
			elseif self.distance > 3000 and self.gavlak == false then
				table.insert(self.entities, Car:new{
					pos=self.road_pos,
					x=240,
					y=p[i] + math.random(1, 5) - 2,
					stage=self,
					spr=311,
					name="gavlak"
				})
				self.gavlak = true
			else
				table.insert(self.entities, Car:new{
					pos=self.road_pos,
					x=240,
					y=p[i] + math.random(1, 5) - 2,
					stage=self,
                    spr=choose{315, 363, 411, 459}
				})
			end

			table.remove(p, i)
			i = math.random(1, #p)

			if self.road_pos > self.last_fuel then
				table.insert(self.entities, Fuel:new{
					pos=self.road_pos,
					x=240,
					y=p[i] + 8,
					stage=self
				})
				self.last_fuel = self.last_fuel + self.next_fuel
				table.remove(p, i)
				i = 1
			end

			local tmp=math.random(1,15)

			if tmp == 1 or tmp == 2 or tmp == 3 or tmp == 4 then
				table.insert(self.entities, Car:new{
					pos=self.road_pos,
					x=240 + math.random(10, 40),
					y=p[i] + math.random(1, 5) - 2,
					stage=self,
                    spr=choose{315, 363, 411, 459}
				})
			elseif tmp == 13 then
				table.insert(self.entities, Oil:new{
					pos=self.road_pos,
					x=240,
					y=math.random(50, 94),
					stage=self
				})
			elseif tmp == 14 then
				table.insert(self.entities, Drink:new{
					pos=self.road_pos,
					x=240,
					y=p[i] + 8,
					stage=self
				})
			end

			self.last_obstacle = self.road_pos + self.next_obstacle
		end

	end
end

function Game:draw_entities()
	table.sort(self.entities, function(e1,e2)
		return (e1.y+e1.sprh)<(e2.y+e2.sprh)
	end)
	for i=1,#self.entities do
		local e=self.entities[i]
		e:draw()
		if settings.bb then
			rectb(e.x+e.ox, e.y+e.oy, e.w, e.h, 0)
		end
	end
end

function Game:update_entities(dt)
	local entities_ = {}
	for i=1,#self.entities do
		local e = self.entities[i]
		e:update(dt)
		if e.alive and e.x > -64 then
			table.insert(entities_, e)
		end
	end
	self.entities = entities_
end

function Game:draw_ui()

	if self.fuel_orange then
		map(0, 17, 29, 4)
	else
		map(0, 21, 29, 4)
	end

	print("high", 8, 2, 3)
	print(string.format("%06.f m", settings.high_score), 8, 10, 9, true)
	print("actual", 8, 18, 3)
	print(string.format("%06.f m", self.distance), 8, 26, 9, true)

	for i=1,self.drinks do
		spr(352, 180 + (i - 1) * 8, 24, 0)
	end

	local tmpf = scale(self.player.fuel, 0, 60,
		math.pi + math.pi/4 + 0.4,
		math.pi - math.pi/4 - 0.4)
	local xf = math.cos(tmpf) * 12 + 159
	local yf = -math.sin(tmpf) * 12 + 16
	line(159, 16, xf, yf, 9)

	local speed = 3600 * self.road_vx * 0.1406
	print(string.format("%03.f", speed), 87, 18, 9, true)
	local tmps = scale(speed, 60, 140, math.pi-0.23, math.pi/2)
	local xs = math.cos(tmps) * 26 + 80 + 15
	local ys = -math.sin(tmps) * 26 + 31
	line(80 + 15, 31, xs, ys, 9)
end

--[[ TIC ]]--
sm = StageManager()
sm.add("intro", Intro)
sm.add("menu", Menu)
sm.add("settings", Settings)
sm.add("game", Game)
sm.add("tutorial", Tutorial)
sm.switch("intro")

last_t = time()
function TIC()
	local actual_t = time()
	local dt = actual_t - last_t

	--[[ PAUSE HACK ]]--
	if dt < 500 then
		sm.update(dt)
	end

	-- Save time
	last_t = actual_t
end

