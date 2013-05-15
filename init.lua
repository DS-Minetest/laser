local max_lenght = 50
local laser_groups = {igniter=2, hot=3, not_in_creative_inventory=1}
local laser_damage = 8*2
local colours = {"red", "orange", "yellow", "green", "blue", "indigo", "violet", "white"}


local function get_direction(name, pos)
	if minetest.env:get_node({x=pos.x-1, y=pos.y, z=pos.z}).name == name then return 1 end
	if minetest.env:get_node({x=pos.x, y=pos.y, z=pos.z-1}).name == name then return 2 end
	if minetest.env:get_node({x=pos.x+1, y=pos.y, z=pos.z}).name == name then return 3 end
	if minetest.env:get_node({x=pos.x, y=pos.y, z=pos.z+1}).name == name then return 4 end
	if minetest.env:get_node({x=pos.x, y=pos.y-1, z=pos.z}).name == name then return 5 end
	if minetest.env:get_node({x=pos.x, y=pos.y+1, z=pos.z}).name == name then return 6 end
	return 7
end


local function get_direction_pos(direction, i, pos)
	if direction == 1 then return {x=pos.x+i, y=pos.y, z=pos.z} end
	if direction == 2 then return {x=pos.x, y=pos.y, z=pos.z+i} end
	if direction == 3 then return {x=pos.x-i, y=pos.y, z=pos.z} end
	if direction == 4 then return {x=pos.x, y=pos.y, z=pos.z-i} end
	if direction == 5 then return {x=pos.x, y=pos.y+i, z=pos.z} end
	if direction == 6 then return {x=pos.x, y=pos.y-i, z=pos.z} end
end


local function get_direction_par(direction, name, name_v)
	if direction == 1 or direction == 3 then return {name=name, param2 = 0} end
	if direction == 2 or direction == 4 then return {name=name, param2 = 1} end
	return {name=name_v}
end


local function laserstrahl(pos, name, name_v, direction, rnode, rnode2)
	block = get_direction_par(direction, name, name_v)
	for i = 1, max_lenght, 1 do
		p = get_direction_pos(direction, i, pos)
		if minetest.env:get_node(p).name == rnode
		or minetest.env:get_node(p).name == rnode2 then
			minetest.env:add_node(p, block)
		else
			break
		end
	end
end

local function lasernode(name, desc, texture, nodebox, selbox)
minetest.register_node(name, {
	description = desc,
	tile_images = {texture},
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
	selection_box = selbox,
	sounds =  default.node_sound_leaves_defaults(),
})
end

for _, colour in ipairs(colours) do
lasernode("laser:"..colour, colour.." laser", "laser_"..colour..".png^[transformR90",
	{
	type = "fixed",
	fixed = {
		{-0.5, -0.5, 0, 0.5, 0.5, 0},
		{-0.5, 0, -0.5, 0.5, 0, 0.5},
	},},
	{
	type = "fixed",
	fixed = {
		{-0.5, -0.1, -0.1, 0.5, 0.1, 0.1},
	},}
)

lasernode("laser:"..colour.."_v", "vertical "..colour.." laser", "laser_"..colour..".png",
	{
	type = "fixed",
	fixed = {
		{-0.5, -0.5, 0, 0.5, 0.5, 0},
		{0, -0.5, -0.5, 0, 0.5, 0.5},
	},},
	{
	type = "fixed",
	fixed = {
		{-0.1, -0.5, -0.1, 0.1, 0.5, 0.1},
	},}
)

minetest.register_on_punchnode(function(pos, node, puncher)
	if puncher:get_wielded_item():get_name() == "default:stick"
	and (node.name == 'bobblocks:'..colour..'block'
	or node.name == 'bobblocks:'..colour..'block_off') then
		local direction = get_direction('default:mese', pos)
		if direction == 7 then
			return
		end
		local p = get_direction_pos(direction, 1, pos)
		if minetest.env:get_node(p).name == "laser:"..colour
		or minetest.env:get_node(p).name == "laser:"..colour.."_v" then
			laserstrahl(pos, "air", "air", direction, "laser:"..colour, "laser:"..colour.."_v")
		else
			laserstrahl(pos, "laser:"..colour, "laser:"..colour.."_v", direction, 'air', 'air')
		end
	end
end)
end
