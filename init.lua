local load_time_start = os.clock()
local max_lenght = 200
local laser_groups = {hot=3, not_in_creative_inventory=1}--igniter=2, 
local laser_damage = 8*2
local colours = {"red", "orange", "yellow", "green", "blue", "indigo", "violet", "white"}

local c_air = minetest.get_content_id("air")

local function r_area(manip, p1, p2)
	local emerged_pos1, emerged_pos2 = manip:read_from_map(p1, p2)
	return VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
end

local function set_vm_data(manip, nodes, pos, t1, name)
	manip:set_data(nodes)
	manip:write_to_map()
	print(string.format("[laser] "..name.." at ("..pos.x.."|"..pos.y.."|"..pos.z..") after ca. %.2fs", os.clock() - t1))
	local t1 = os.clock()
	manip:update_map()
	print(string.format("[laser] map updated after ca. %.2fs", os.clock() - t1))
end

local function invert_direction(dir)
	for _,i in ipairs({{1, 3}, {2, 4}, {5, 6}}) do
		if dir == i[1] then
			return i[2]
		end
		if dir == i[2] then
			return i[1]
		end
	end
end

local dirpos_list = {
	{x= 1, y= 0, z= 0},
	{x= 0, y= 0, z= 1},
	{x=-1, y= 0, z= 0},
	{x= 0, y= 0, z=-1},
	{x= 0, y= 1, z= 0},
	{x= 0, y=-1, z= 0}
}

local function get_direction(name, pos)
	for n,i in ipairs(dirpos_list) do
		local p = vector.add(pos, vector.multiply(i, -1))
		if minetest.get_node(p).name == name then
			return n
		end
	end
end

local function get_directions_laser(name, namev, pos)
	local tab, num = {}, 1
	local dir = get_direction(name, pos)
	for n,i in ipairs({
		{{x=pos.x-1, z=pos.z}, 0},
		{{x=pos.x, z=pos.z-1}, 1},
		{{x=pos.x+1, z=pos.z}, 0},
		{{x=pos.x, z=pos.z+1}, 1}
	}) do
		local pos = {x=i[1].x, y=pos.y, z=i[1].z}
		if dir == n
		and minetest.get_node(pos).param2 == i[2] then
			tab[num] = invert_direction(n)
			num = num+1
		end
	end
	if minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name == namev then
		tab[num] = 6
		num = num+1
	end
	if minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name == namev then
		tab[num] = 5
		num = num+1
	end
	return tab
end

local function get_direction_par(direction, name, name_v)
	if direction == 1
	or direction == 3 then
		return {name=name, param2 = 0}
	end
	if direction == 2
	or direction == 4 then
		return {name=name, param2 = 1}
	end
	return {name=name_v}
end

local function luftstrahl(pos, dir, colour)
	local t1 = os.clock()
	local addp = dirpos_list[dir]
	local p = pos
	local l = 0
	for i = 1, max_lenght do
		p = vector.add(p, addp)
		local nodename = minetest.get_node(p).name

		local laserfcts = minetest.registered_nodes[nodename].laser
		local func
		if laserfcts then
			func = laserfcts.disable
		end
		if func then
			if not func(p, dir, colour) then
				break
			end
		end
		if nodename == "laser:"..colour
		or nodename == "laser:"..colour.."_v" then
			l = l+1
		else
			break
		end
	end
	minetest.after(0, function(param)
		local t1, l, addp, pos, p = unpack(param)
		if l == 0 then
			return
		end
		if l == 1 then
			minetest.remove_node(vector.add(pos, addp))
			return
		end
		local p1 = vector.add(pos, addp)
		local p2 = vector.add(pos, vector.multiply(addp, l))
		if addp.x + addp.y + addp.z < 0 then
			p1,p2 = p2,p1
		end
		local manip = minetest.get_voxel_manip()
		local area = r_area(manip, p1, p2)
		local nodes = manip:get_data()
		for i in area:iterp(p1, p2) do
			nodes[i] = c_air
		end
		set_vm_data(manip, nodes, pos, t1, "removed")
	end, {t1, l, addp, pos, p})
end

local function laserstrahl(pos, name, name_v, dir)
	local t1 = os.clock()
	local addp = dirpos_list[dir]
	local p = pos
	local l = 0
	local block = get_direction_par(dir, name, name_v)
	for i = 1, max_lenght, 1 do
		p = vector.add(p, addp)
		local nodename = minetest.get_node(p).name

		local laserfcts = minetest.registered_nodes[nodename].laser
		local func
		if laserfcts then
			func = laserfcts.enable
		end
		if func then
			if not func(p, dir, {name, name_v}) then
				break
			end
		end
		if nodename == 'air' then
			l = l+1
		else
			break
		end
	end
	minetest.after(0, function(param)
		local t1, l, addp, pos, p = unpack(param)
		if l == 0 then
			return
		end
		if l == 1 then
			minetest.add_node(vector.add(pos, addp), block)
			return
		end
		local p1 = vector.add(pos, addp)
		local p2 = vector.add(pos, vector.multiply(addp, l))
		if addp.x + addp.y + addp.z < 0 then
			p1,p2 = p2,p1
		end
		local c_cur = minetest.get_content_id(block.name)
		local par2 = block.param2 or 0
		local manip = minetest.get_voxel_manip()
		local area = r_area(manip, p1, p2)
		local nodes = manip:get_data()
		local param2s = manip:get_param2_data()
		for i in area:iterp(p1, p2) do
			nodes[i] = c_cur	--I need an explanation: sometimes the needed param2 is
			param2s[i] = par2	--fetched automatically but only in the current chunk
		end
		manip:set_param2_data(param2s)
		set_vm_data(manip, nodes, pos, t1, "laser set")
	end, {t1, l, addp, pos, p})
end

local function laserabm(pos, colour)
	local dir = get_direction('default:mese', pos)
	if dir then
		luftstrahl(pos, dir, colour)
	else
		local dir = get_direction("mesecons_extrawires:mese_powered", pos)
		if dir then
			laserstrahl(pos, "laser:"..colour, "laser:"..colour.."_v", dir)
			--minetest.sound_play("laser", {pos = pos,  gain = 1})
		end
	end
end

function laser_continue_laser(pos) --untested
	for _,colour in ipairs(colours) do
		local name = "laser:"..colour
		local dir = get_direction(name, pos)
		if not dir then
			name = "laser:"..colour.."_v"
			dir = get_direction(name, pos)
		end
		if dir then
			local p2
			for _,i in ipairs(dirpos_list) do
				local p = vector.add(pos, i)
				local nodename = minetest.get_node(p).name
				if nodename == name then
					break
				end
			end
			laserstrahl(p, "laser:"..colour, "laser:"..colour.."_v", dir)
			return
		end
	end
end

local function lasernode(name, desc, texture, nodebox)
minetest.register_node(name, {
	description = desc,
	tiles = {texture},
	light_source = 15,
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	use_texture_alpha = true,
	damage_per_second = laser_damage,
	groups = laser_groups,
	drop = "",
	node_box = nodebox,
	sounds =  default.node_sound_leaves_defaults(),
	-- {-0.5, -0.1, -0.1, 0.5, 0.1, 0.1}, {-0.1, -0.5, -0.1, 0.1, 0.5, 0.1},
})
end

local LASERBOX = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 0, 0.5, 0.5, 0},
			{-0.5, 0, -0.5, 0.5, 0, 0.5},
		}
	}

local LASERBOXV = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, 0, 0.5, 0.5, 0},
			{0, -0.5, -0.5, 0, 0.5, 0.5},
		}
	}

local function after_dig_bob(pos, colour)
	local dirs = get_directions_laser("laser:"..colour, "laser:"..colour.."_v", pos)
	for _,dir in ipairs(dirs) do
		luftstrahl(pos, dir, colour)
	end
end

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

for _, colour in ipairs(colours) do
	lasernode("laser:"..colour, colour.." laser", "laser_"..colour..".png^[transformR90", LASERBOX)
	lasernode("laser:"..colour.."_v", "vertical "..colour.." laser", "laser_"..colour..".png", LASERBOXV)


	--Bob Blocks (redefinitions)

	local tmp = deepcopy(minetest.registered_nodes["bobblocks:"..colour.."block"])
	local block_table = {
		description = tmp.description,
		drawtype = tmp.drawtype,
		tile_images = tmp.tile_images,
		inventory_image = tmp.inventory_image,
		paramtype = tmp.paramtype,
		sunlight_propagates = tmp.sunlight_propagates,
		sounds = tmp.sounds,
		light_source = tmp.light_source,
		groups = tmp.groups,
		on_punch = tmp.on_punch,
		mesecons = {conductor = {
				state = mesecon.state.on,
				offstate = "bobblocks:"..colour.."block_off"
			},
			effector = {
				action_on = function(pos)
					laserabm(pos, colour)
				end,
				action_off = function(pos)
					laserabm(pos, colour)
				end,
			}
		},
		after_dig_node = function(pos)
			after_dig_bob(pos, colour)
		end
	}
	minetest.register_node(":bobblocks:"..colour.."block", block_table)

	local tmp = deepcopy(minetest.registered_nodes["bobblocks:"..colour.."block_off"])
	local block_table = {
		description = tmp.description,
		tile_images = tmp.tile_images,
		alpha = tmp.alpha,
		groups = tmp.groups,
		drop = tmp.drop,
		on_punch = tmp.on_punch,
		after_dig_node = function(pos)
			after_dig_bob(pos, colour)
		end,
		mesecons = {conductor = {
				state = mesecon.state.off,
				onstate = "bobblocks:"..colour.."block"
			},
			effector = {
				action_on = function(pos)
					laserabm(pos, colour)
				end,
				action_off = function(pos)
					laserabm(pos, colour)
				end,
			}
		}
	}
	minetest.register_node(":bobblocks:"..colour.."block_off", block_table)
end

local function is_touched_by_laser(pos)
	--function here
end

minetest.register_node("laser:detector", {
	description = "Laser Detector",
	tiles = {"laserdetector.png"},
	mesecons = {receptor ={state = mesecon.state.off}},
	groups = {cracky=1,level=2},
	sounds = default.node_sound_stone_defaults(),
	paramtype2 = "facedir",
	laser = {
		enable = function(pos)
			mesecon:receptor_on(pos) --seems to work in this order
			minetest.add_node(pos, {name="laser:detector_powered"})
		end
	}
})

minetest.register_node("laser:detector_powered", {
	tiles = {"laserdetector.png^[brighten"},
	mesecons = {receptor ={state = mesecon.state.on}},
	drop = "laser:detector",
	groups = {cracky=1,level=2},
	sounds = default.node_sound_stone_defaults(),
	paramtype2 = "facedir",
	laser = {
		disable = function(pos) --maybe disabling works slower
			minetest.add_node(pos, {name="laser:detector"})
			mesecon:receptor_off(pos)
		end
	}
})

print(string.format("[laser] loaded after ca. %.2fs", os.clock() - load_time_start))
