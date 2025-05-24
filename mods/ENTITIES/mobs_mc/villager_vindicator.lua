--MCmobs v0.4
--maikerumine
--made for MC like Survival game
--License for code WTFPL and otherwise stated in readmes

--###################
--################### VINDICATOR
--###################

local S = minetest.get_translator("mobs_mc")

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
dofile(modpath.."/illager.lua")

mobs_mc.vindicator_mob = table.merge(mobs_mc.illager, {
	description = S("Vindicator"),
	collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.94, 0.3},
	visual = "mesh",
	mesh = "mobs_mc_vindicator.b3d",
	head_swivel = "head.control",
	bone_eye_height = 2.2,
	head_eye_height = 2.2,
	curiosity = 20,
	textures = {
	{
			"mobs_mc_vindicator.png",
			"blank.png", --no hat
			"default_tool_steelaxe.png",
			-- TODO: Glow when attacking (mobs_mc_vindicator.png)
		},
	},
	visual_size = {x=2.75, y=2.75},
	makes_footstep_sound = true,
	damage = 6,
	reach = 2,
	walk_velocity = 1.2,
	run_velocity = 1.6,
	attack_type = "dogfight",
	drops = {
		{name = "mcl_core:emerald",
		chance = 1,
		min = 0,
		max = 1,
		looting = "common",},
		{name = "mcl_tools:axe_iron",
		chance = 100 / 8.5,
		min = 1,
		max = 1,
		looting = "rare",},
	},
	-- TODO: sounds
	animation = {
		stand_start = 40, stand_end = 59, stand_speed = 30,
		walk_start = 0, walk_end = 40, walk_speed = 50,
		punch_start = 90, punch_end = 110, punch_speed = 25,
		die_start = 170, die_end = 180, die_speed = 15, die_loop = false,
	},
	view_range = 16,
	fear_height = 4,
	place_tnt = true
})

table.insert(mobs_mc.vindicator_mob.specific_attack, "mobs_mc:creeper")

mcl_mobs.register_mob("mobs_mc:vindicator", mobs_mc.vindicator_mob)
mcl_mobs.register_egg("mobs_mc:vindicator", S("Vindicator"), "#959b9b", "#275e61", 0)
