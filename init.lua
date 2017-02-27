local load_time_start = os.clock()
local laser_groups = {hot=3, not_in_creative_inventory=1}--igniter=2,
local laser_damage = 8*2
local texture_scale = 0.16
local colours = {
	red = "#ff0000",
	orange = "#ff6400",
	yellow = "#f5ff00",
	green = "#00ff00",
	blue = "#0005ff",
	indigo = "#ff00e8",
	violet = "#9900ff",
	white = true
}
local pcolours = {
	red = "1",
	orange = "2",
	yellow = "3",
	green = "4",
	blue = "5",
	indigo = "6",
	violet = "7",
	white = 0
}

local c_air = minetest.get_content_id"air"

local function r_area(manip, p1, p2)
	local emerged_pos1, emerged_pos2 = manip:read_from_map(p1, p2)
	return VoxelArea:new{MinEdge=emerged_pos1, MaxEdge=emerged_pos2}
end

local function log(text)
	minetest.log("info", "[laser] "..text)
end

local function set_vm_data(manip, nodes, pos, t1, name)
	manip:set_data(nodes)
	manip:write_to_map()
	log(string.format(name.." at ("..pos.x.."|"..pos.y.."|"..pos.z..") after ca. %.2fs", os.clock() - t1))
	local t1 = os.clock()
	manip:update_map()
	log(string.format("map updated after ca. %.2fs", os.clock() - t1))
end

local dir_tab = {3, 4, 1, 2, 6, 5}

local dirpos_list = {
	{x= 1, y= 0, z= 0},
	{x= 0, y= 0, z= 1},
	{x=-1, y= 0, z= 0},
	{x= 0, y= 0, z=-1},
	{x= 0, y= 1, z= 0},
	{x= 0, y=-1, z= 0}
}

--returns directions of name touching pos
local function get_direction(name, pos, use_tab)
	local tab, num
	if use_tab then
		tab, num = {}, 1
	end
	for n = 1,6 do
		local p = vector.add(pos, dirpos_list[dir_tab[n]])
		if minetest.get_node(p).name == name then
			if not use_tab then
				return n
			end
			tab[num] = n
			num = num+1
		end
	end
	if use_tab then
		return tab
	end
end

local function table_contains(t, v)
	for _,i in pairs(t) do
		if i == v then
			return true
		end
	end
	return false
end

--returns a table of some directions of lasers touching pos
local function get_directions_laser(name, pos, use_tab)
	local tab, num = {}, 1
	local dir = get_direction(name, pos, use_tab)
	for n,i in pairs{
		{{x=pos.x-1, y=pos.y, z=pos.z}, 0},
		{{x=pos.x, y=pos.y, z=pos.z-1}, 1},
		{{x=pos.x+1, y=pos.y, z=pos.z}, 0},
		{{x=pos.x, y=pos.y, z=pos.z+1}, 1},
		{{x=pos.x, y=pos.y-1, z=pos.z}, 5},
		{{x=pos.x, y=pos.y+1, z=pos.z}, 5},
	} do
		local pos = i[1]
		local dir_is_n
		if use_tab then
			dir_is_n = table_contains(dir, n)
		else
			dir_is_n = dir == n
		end
		if dir_is_n
		and minetest.get_node(pos).param2 == i[2] then
			tab[num] = dir_tab[n]
			num = num+1
		end
	end
	return tab
end

-- gets a node also in unloaded chunks
local function get_nodename(p, addp)
	local nodename = minetest.get_node(p).name
	if nodename ~= "ignore" then
		return nodename
	end
	-- load chunk
	minetest.get_voxel_manip():read_from_map(p, vector.add(p, vector.multiply(addp, 16)))
	nodename = minetest.get_node(p).name
	if nodename == "ignore" then
		-- not generated
		return
	end
	return nodename
end

-- returns step and count for iteration
local function iter_straight(area, addp)
	if addp.x ~= 0 then
		return 1
	end
	if addp.y ~= 0 then
		return area.ystride
	end
	if addp.z ~= 0 then
		return area.zstride
	end
end

-- removes a laser
local function luftstrahl_setzen(t1, l, addp, pos, p, name)
	if l == 0 then
		return
	end
	if l == 1 then
		pos = vector.add(pos, addp)
		if minetest.get_node(pos).name == name then
			minetest.remove_node(pos)
		end
		return
	end
	local p1 = vector.add(pos, addp)
	local p2 = vector.add(pos, vector.multiply(addp, l))
	if addp.x + addp.y + addp.z < 0 then
		p1,p2 = p2,p1
	end
	local laser_id = minetest.get_content_id(name)
	local manip = minetest.get_voxel_manip()
	local area = r_area(manip, p1, p2)
	local nodes = manip:get_data()

	local vi = area:indexp(p1)
	local stride = iter_straight(area, addp)
	for _ = 1,l do
		if nodes[vi] == laser_id then
			nodes[vi] = c_air
		end
		vi = vi + stride
	end
	set_vm_data(manip, nodes, pos, t1, "removed")
end

-- tests and then removes laser
local function luftstrahl(pos, dir, colour)
	local t1 = os.clock()
	local addp = dirpos_list[dir]
	local p = pos
	local l = 0
	local name = "laser:laser"

	-- gets the length of the laser beam
	while true do
		p = vector.add(p, addp)
		local nodename = get_nodename(p, addp)
		if not nodename then
			break
		end

		local laserfcts = minetest.registered_nodes[nodename].laser
		if laserfcts then
			local func = laserfcts.disable
			if func
			and not func(p, dir, colour) then
				break
			end
		end
		if nodename ~= name then
			break
		end
		l = l+1
	end

	-- removes it with vm
	minetest.delay_function(20, luftstrahl_setzen, t1, l, addp, pos, p, name)
end

--node information for the laser
local direction_params = {0,1,0,1,5,5}

-- creates a laser
local function laserstrahl_setzen(t1, l, addp, pos, dir, colour)
	if l == 0 then
		return
	end
	local par2 = direction_params[dir] + 32*pcolours[colour]
	if l == 1 then
		pos = vector.add(pos, addp)
		if minetest.get_node(pos).name == "air" then
			minetest.add_node(pos, {name="laser:laser", param2=par2})
		end
		return
	end
	local p1 = vector.add(pos, addp)
	local p2 = vector.add(pos, vector.multiply(addp, l))
	if addp.x + addp.y + addp.z < 0 then
		p1,p2 = p2,p1
	end
	local c_cur = minetest.get_content_id(name)
	local manip = minetest.get_voxel_manip()
	local area = r_area(manip, p1, p2)
	local nodes = manip:get_data()
	local param2s = manip:get_param2_data()

	local vi = area:indexp(p1)
	local stride = iter_straight(area, addp)
	for _ = 1,l do
		if nodes[vi] ~= c_air then
			break
		end
		nodes[vi] = c_cur	--I need an explanation: sometimes the needed param2 is
		param2s[vi] = par2	--fetched automatically but only in the current chunk
		vi = vi + stride
	end

	manip:set_param2_data(param2s)
	set_vm_data(manip, nodes, pos, t1, "laser set")
end

-- tests and then creates laser
local function laserstrahl(pos, colour, dir)
	local t1 = os.clock()
	local addp = dirpos_list[dir]
	local p = pos
	local l = 0
	while true do
		p = vector.add(p, addp)
		local nodename = get_nodename(p, addp)
		if not nodename then
			break
		end

		local laserfcts = minetest.registered_nodes[nodename].laser
		if laserfcts then
			local func = laserfcts.enable
			if func
			and not func(p, dir, colour) then
				break
			end
		end
		if nodename ~= "air" then
			break
		end
		l = l+1
	end
	minetest.delay_function(20, laserstrahl_setzen, t1, l, addp, pos, dir, colour)
end

--used to create/remove a laser
local function laserabm(pos, colour)
	local dir = get_direction("default:mese", pos)
	if dir then
		luftstrahl(pos, dir, colour)
	else
		local dir = get_direction("mesecons_extrawires:mese_powered", pos)
		if dir then
			laserstrahl(pos, colour, dir)
			--minetest.sound_play("laser", {pos = pos,  gain = 1})
		end
	end
end

--[[function laser_continue_laser(pos) --untested
	for colour in pairs(colours) do
		local name = "laser:"..colour
		local dir = get_direction(name, pos)
		if not dir then
			name = "laser:"..colour.."_v"
			dir = get_direction(name, pos)
		end
		if dir then
			local p2
			for _,i in pairs(dirpos_list) do
				local p = vector.add(pos, i)
				local nodename = minetest.get_node(p).name
				if nodename == name then
					break
				end
			end
			laserstrahl(p, "laser:"..colour, dir)
			return
		end
	end
end]]

local function after_destruct_bob(pos, colour)
	local name = minetest.get_node(pos).name
	if name == "bobblocks:"..colour.."block"
	or name == "bobblocks:"..colour.."block_off" then
		-- don't remove the laser if the bobblock became punched
		return
	end
	local dirs = get_directions_laser("laser:laser", pos)
	for _,dir in pairs(dirs) do
		luftstrahl(pos, dir, colour)
	end
end

local node_box = {
	type = "fixed",
	fixed = {
		{nil, -0.5, 0, nil, 0.5, 0},
		{nil, 0, -0.5, nil, 0, 0.5},
	}
}
local b = node_box.fixed
for i = 1, #b do
	local b = b[i]
	b[1] = -0.5 / texture_scale
	b[4] = 0.5 / texture_scale
end

--~ for colour,hx in pairs(colours) do


-- registers a laser node

-- [[
--~ local texture = "laser_white.png^[transformR90"
--~ if colour ~= "white" then
	--~ texture = texture.."^[colorize:"..hx..":alpha"
--~ end--]]

local name = "laser:laser"
minetest.register_node(name, {
	description = "laser",
	tiles = {"laser_white.png^[transformR90"},
	--tiles = {"laser_"..colour..".png^[transformR90"},
	light_source = 15,
	sunlight_propagates = true,
	walkable = false,
	--~ pointable = false,
	diggable = false,
	drop = "",
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "colorfacedir",
	palette = "laser_palette.png",
	use_texture_alpha = true,
	damage_per_second = laser_damage,
	groups = laser_groups,
	visual_scale = texture_scale,
	node_box = node_box,
	sounds =  default.node_sound_leaves_defaults(),
	-- {-0.5, -0.1, -0.1, 0.5, 0.1, 0.1}, {-0.1, -0.5, -0.1, 0.1, 0.5, 0.1},
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		minetest.set_node(pos, {name = "laser:laser", param2 = node.param2 + 1})
	end,
})

if mesecon.register_mvps_stopper then
	mesecon.register_mvps_stopper(name)
end

for colour,hx in pairs(colours) do

	--Bob Blocks (redefinitions)

	for _,name in pairs{"bobblocks:"..colour.."block", "bobblocks:"..colour.."block_off"} do
		local data = minetest.registered_nodes[name]

		local cons = data.mesecons or {}
		cons.effector = cons.effector or {}
		cons.effector.action_on = function(pos)
			laserabm(pos, colour)
		end
		cons.effector.action_off = function(pos)
			laserabm(pos, colour)
		end

		local af_dest = data.after_destruct
		if af_dest then
			local old_af_dest = af_dest
			function af_dest(pos,b)
				local res = old_af_dest(pos,b)
				after_destruct_bob(pos, colour)
				return res
			end
		else
			function af_dest(pos)
				after_destruct_bob(pos, colour)
			end
		end

		minetest.override_item(name, {
			mesecons = cons,
			after_destruct = af_dest,
			laser = {emitter = true}
		})
	end
end

--checks if a laser touches pos
local function is_touched_by_laser(pos, dir)
	dir = dir_tab[dir]
	for colour in pairs(colours) do
		local lasers = get_directions_laser("laser:laser", pos, true)
		if lasers[1] then
			for _,dir2 in pairs(lasers) do
				if dir ~= dir2 then
					return true
				end
			end
		end
	end
	return false
end

minetest.register_node("laser:detector", {
	description = "laser detector",
	tiles = {"laserdetector.png"},
	mesecons = {receptor ={state = mesecon.state.off}},
	groups = {cracky=1,level=2},
	sounds = default.node_sound_stone_defaults(),
	paramtype2 = "facedir",
	laser = {
		enable = function(pos)
			mesecon.receptor_on(pos) --seems to work in this order
			minetest.add_node(pos, {name="laser:detector_powered"})
		end
	}
})

minetest.register_node("laser:detector_powered", {
	tiles = {"laserdetector.png^[brighten"},
	mesecons = {receptor = {state = mesecon.state.on}},
	drop = "laser:detector",
	groups = {cracky=1,level=2},
	sounds = default.node_sound_stone_defaults(),
	paramtype2 = "facedir",
	laser = {
		disable = function(pos, dir) --maybe disabling works slower
			if is_touched_by_laser(pos, dir) then
				return
			end
			minetest.add_node(pos, {name="laser:detector"})
			mesecon.receptor_off(pos)
		end
	}
})

local mirror_data = {
	[0]={2,5}, {1,5}, {4,5}, {3,5},
	{4,5}, {1,2}, {4,6}, {3,2},
	{2,6}, {1,4}, {2,5}, {2,1},
	{2,1}, {3,5}, {3,2}, {3,6},
	{1,4}, {1,6}, {1,2}, {1,5},
	{2,6}, {3,6}, {4,6}, {1,6},
}
for par,dirs in pairs(mirror_data) do
	mirror_data[par] = {[dirs[1]] = dirs[2], [dir_tab[dirs[2]]] = dir_tab[dirs[1]]}
end

minetest.register_node("laser:mirror", {
	description = "mirror",
	tiles = {"default_steel_block.png"},
	groups = {cracky=1,level=2},
	sounds = default.node_sound_glass_defaults(),
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 0.4, 0.5, 0.5, 0.5},
			{-0.5, -0.5, -0.5, 0.5, -0.4, 0.5},
		}
	},
	paramtype = "light",
	paramtype2 = "facedir",
	laser = {
		emitter = true,
		enable = function(pos, dir, colour)
			local par2 = minetest.get_node(pos).param2
			local next_dir = mirror_data[par2][dir]
			if not next_dir then
				return
			end
			laserstrahl(pos, colour, next_dir)
		end,
		disable = function(pos, dir, colour)
			local par2 = minetest.get_node(pos).param2
			local next_dir = mirror_data[par2][dir]
			if not next_dir then
				return
			end
			luftstrahl(pos, next_dir, colour)
		end
	},
	on_place = minetest.rotate_node,
})


-- legacy

for colour in pairs(colours) do
	minetest.register_node("laser:"..colour.."_v", {groups={laser_oldv=1}})
end

minetest.register_abm({
	nodenames = {"group:laser_oldv"},
	interval = 1,
	chance = 1,
	action = function(pos, node)
		node.name = string.sub(node.name, 1, -3)
		node.param2 = 5
		minetest.set_node(pos, node)
		log("an old vertical laser node became changed at "..minetest.pos_to_string(pos))
	end
})


log(string.format("loaded after ca. %.2fs", os.clock() - load_time_start))
