local max_lenght = 50
local laser_groups = {igniter=2, hot=3, not_in_creative_inventory=1}
local laser_damage = 8*2
local colours = {"red", "yellow"}


local function get_direction(name, pos)
	if minetest.env:get_node({x=pos.x-1, y=pos.y, z=pos.z}).name == name then return 1 end
	if minetest.env:get_node({x=pos.x, y=pos.y, z=pos.z-1}).name == name then return 2 end
	if minetest.env:get_node({x=pos.x+1, y=pos.y, z=pos.z}).name == name then return 3 end
	if minetest.env:get_node({x=pos.x, y=pos.y, z=pos.z+1}).name == name then return 4 end
	return 5
end


local function get_direction_pos(direction, i, pos)
	if direction == 1 then return {x=pos.x+i, y=pos.y, z=pos.z} end
	if direction == 2 then return {x=pos.x, y=pos.y, z=pos.z+i} end
	if direction == 3 then return {x=pos.x-i, y=pos.y, z=pos.z} end
	if direction == 4 then return {x=pos.x, y=pos.y, z=pos.z-i} end
end


local function get_direction_par(direction)
	if direction == 1 or direction == 3 then return 0 end
	if direction == 2 or direction == 4 then return 1 end
end


local function laserstrahl(pos, name, direction, rnode)
		par = get_direction_par(direction)
	for i = 1, max_lenght, 1 do
		p = get_direction_pos(direction, i, pos)
		if minetest.env:get_node(p).name == rnode then
			minetest.env:add_node(p, {name=name, param2 = par})
		else
			break
		end
	end
end


for _, colour in ipairs(colours) do
minetest.register_node("laser:"..colour, {
	description = colour.." laser",
	tile_images = {"laser_"..colour..".png"},
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
	node_box = {
	type = "fixed",
	fixed = {
		{-0.5, -0.5, 0, 0.5, 0.5, 0},
		{-0.5, 0, -0.5, 0.5, 0, 0.5},
	},},
	selection_box = {
	type = "fixed",
	fixed = {
		{-0.5, -0.1, -0.1, 0.5, 0.1, 0.1},
	},},
	sounds =  default.node_sound_leaves_defaults(),
})

minetest.register_on_punchnode(function(pos, node, puncher)
	if puncher:get_wielded_item():get_name() == "default:stick"
	and (node.name == 'bobblocks:'..colour..'block'
	or node.name == 'bobblocks:'..colour..'block_off') then
		local direction = get_direction('default:mese', pos)
		if direction == 5 then
			return
		end
		local p = get_direction_pos(direction, 1, pos)
		if minetest.env:get_node(p).name == "laser:"..colour then
			laserstrahl(pos, "air", direction, "laser:"..colour)
		else
			laserstrahl(pos, "laser:"..colour, direction, 'air')
		end
	end
end)
end
