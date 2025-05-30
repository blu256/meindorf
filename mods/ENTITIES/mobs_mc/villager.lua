-- Villager code originally by maikerumine for mobs_mc
-- massively improved by cora, ancientmarinerdev and codiac

-- TODO: Particles
-- TODO: 4s Regeneration I after trade unlock
-- TODO: Internal inventory, trade with other villagers

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

local S = minetest.get_translator(modname)

local DEFAULT_WALK_CHANCE = 33 -- chance to walk in percent, if no player nearby
local PLAYER_SCAN_INTERVAL = 5 -- every X seconds, villager looks for players nearby
local PLAYER_SCAN_RADIUS = 4 -- scan radius for looking for nearby players

mobs_mc.jobsites = {}
mobs_mc.professions = {}
mobs_mc.villager = {}
mobs_mc.villager_mob = {}

local villager_sword_entity = {
	initial_properties = {
		visual = "wielditem",
		visual_size = { x = 0.3 / 5, y = 0.3 / 5, },
		physical = false,
		pointable = false,
		wield_item = "mcl_tools:sword_iron",
	},
	on_step = function(self)
		local parent = self.object:get_attach()
		if not parent then
			self.object:remove()
			return
		end
	end,
}
minetest.register_entity ("mobs_mc:villager_sword", villager_sword_entity)

function mobs_mc.register_villager_profession(title, record)

	-- TODO should we allow overriding jobs?
	-- If so what needs to be considered?
	if mobs_mc.professions[title] then
		minetest.log("warning", "[mobs_mc] Trying to register villager job "..title.." which already exists. Skipping.")
		return
	end

	mobs_mc.professions[title] = record

	if record.jobsite then
		table.insert(mobs_mc.jobsites, record.jobsite)
	end
end

for title, record in pairs(dofile(modpath.."/villagers/trades.lua")) do
	mobs_mc.register_villager_profession(title, record)
end


dofile(modpath.."/villagers/activities.lua")
dofile(modpath.."/villagers/trading.lua")
dofile(modpath.."/villagers/names.lua")

function mobs_mc.villager_mob:set_textures()
	local badge_textures = self:get_badge_textures()
	self.base_texture = badge_textures
	self.object:set_properties({textures=badge_textures})
end

--[------[ MOB REGISTRATION AND SPAWNING ]-------]

function mobs_mc.villager_mob:on_pick_up(itementity)
	local it = ItemStack(itementity.itemstring)
-- 	local inv = core.get_inventory({type="detached", name="mobs_mc:inv_villager_"..self._id})
-- 	if not inv then
-- 		inv = core.create_detached_inventory(self._inv_id, inv_callbacks)
-- 		inv:set_size("main", 20)
-- 	end

	if it.name == "mcl_farming:bread" or it.name == "mcl_farming:carrot_item"
	or it.name == "mcl_farming:beetroot_item" or it.name == "mcl_farming:potato_item"
	then
		local clicker
		for p in mcl_util.connected_players(self.object:get_pos(), 9) do
			clicker = p
		end
		if clicker and not self.horny then
			self:feed_tame(clicker, 4, true, false, true)
			it:take_item(1)
-- 		else
-- 			it = inv:add_item("main", it)
		end
-- 	else
-- 		it = inv:add_item("main", it)
	end
	return it
end

function mobs_mc.villager_mob:on_rightclick(clicker)
	if self._profession == "unemployed" or self._profession == "nitwit" or
	self.child then
		self.order = nil
		return
	end

	self:init_trader_vars()
	local name = clicker:get_player_name()
	self._trading_players[name] = true

	-- Make sure old villagers have minimal XP for current level
	-- Probably should be somewhere else ...
	if self._trade_xp == nil then
		if self._max_trade_tier and self._max_trade_tier > 1 then
			self._trade_xp = mobs_mc.villager_mob.tier_xp[self._max_trade_tier - 1]
		else
			self._trade_xp = 0
		end
	end

	self:init_trades()

	self:update_max_tradenum()
	if self._trades == false then
		return
	end

	local inv = minetest.get_inventory({type="detached", name="mobs_mc:trade_"..name})
	if not inv then
		return
	end

	self:show_trade_formspec(name)

	local selfpos = self.object:get_pos()
	local clickerpos = clicker:get_pos()
	local dir = vector.direction(selfpos, clickerpos)
	self.object:set_yaw(minetest.dir_to_yaw(dir))
	self:stand_still()
end

function mobs_mc.villager_mob:stand_near_players()
	-- Check infrequently to keep CPU load low
	if self.order ~= "sleep" and self:check_timer("player_scan", PLAYER_SCAN_INTERVAL) then
		if table.count(minetest.get_objects_inside_radius(self.object:get_pos(), PLAYER_SCAN_RADIUS), function(_, pl) return pl:is_player() end) > 0 then
			self:stand_still()
		else
			self:stop_standing_still()
		end
	end
end

function mobs_mc.villager_mob:equip_sword()
	if self._held_sword_object then return end
	local object = minetest.add_entity(self.object:get_pos(), "mobs_mc:villager_sword")
	if object then
		object:set_attach(self.object, "body", vector.new(0,1.8,2), vector.new(0,270,0))
		self._held_sword_object = object
	end
end

function mobs_mc.villager_mob:unequip_sword()
	if self._held_sword_object then self._held_sword_object:remove() end
end

function mobs_mc.villager_mob:do_custom(dtime)
	self:check_summon()
	self:get_a_name()
	self:attack_monsters()
	if (self.state == "attack") then
		self:equip_sword()
	else
		self:unequip_sword()
	end
	self:stand_near_players()
	self:do_activity(dtime)
end

function mobs_mc.villager_mob:on_spawn()
	if self.state == "attack" then
		-- in case a bug in mcl_mobs makes them set this state
		self.state = "stand"
		self.attack = nil
	end

	self._profession = "unemployed"

	-- TODO: make these probabilities configurable via settings menu
	local choice = math.random(2)
	if choice == 1 then
		self._gender = "female"
	else
		self._gender = "male"
	end

	choice = math.random(5)
	if choice == 1 then
		self._attraction = "all"
	elseif choice == 2 then
		self._attraction = "same"
	else
		self._attraction = "different"
	end

	self:get_a_name()
	core.log("action", S("@1 is a @2, attraction = @3", self.nametag, self._gender, self._attraction))

	self:get_a_job()
	self:set_textures()
	self._id=minetest.sha1(minetest.get_gametime()..minetest.pos_to_string(self.object:get_pos())..tostring(math.random()))
	self:set_textures()
end

function mobs_mc.villager_mob:on_die(_, cmi_cause)
	-- Close open trade formspecs and give input back to players
	local trading_players = self._trading_players
	if trading_players then
		for name, _ in pairs(trading_players) do
			minetest.close_formspec(name, "mobs_mc:trade_"..name)
			local player = minetest.get_player_by_name(name)
			if player then
				mobs_mc.villager.return_fields(player)
			end
		end
	end

	local bed = self._bed
	if bed then
		local bed_meta = minetest.get_meta(bed)
		bed_meta:set_string("villager", "")
		bed_meta:set_string("infotext", "")
	end
	local jobsite = self._jobsite
	if jobsite then
		local jobsite_meta = minetest.get_meta(jobsite)
		jobsite_meta:set_string("villager", "")
		jobsite_meta:set_string("infotext", "")
	end

	if cmi_cause and cmi_cause.puncher then
		local l = cmi_cause.puncher:get_luaentity()
		if l and math.random(2) == 1 and( l.name == "mobs_mc:zombie" or l.name == "mobs_mc:baby_zombie" or l.name == "mobs_mc:villager_zombie" or l.name == "mobs_mc:husk") then
			mcl_util.replace_mob(self.object,"mobs_mc:villager_zombie")
			if self.nametag then
				core.chat_send_all(S("@1 turned into a zombie!", self.nametag))
			end
			return true
		end
	end

	if self.nametag then
		core.chat_send_all(S("@1 died!", self.nametag))
	end
end

function mobs_mc.villager_mob:_on_lightning_strike()
	 mcl_util.replace_mob(self.object, "mobs_mc:witch")
	 return true
end

function mobs_mc.villager_mob:on_mob_replace(new_ent)
	new_ent._profession = self._profession
	new_ent._gender = self._gender
	new_ent._attraction = self._attraction
	new_ent._id = self._id
	new_ent._jobsite = self._jobsite
	new_ent._bed = self._bed
	new_ent._name = self.nametag
end

table.update(mobs_mc.villager_mob, {
	description = S("Villager"),
	spawn_class = "passive",
	type = "npc",
	passive = true,
	retaliates = true,
	attacks_monsters = true,
	runaway = false,
	hp_min = 50,
	hp_max = 50,
 	pathfinding = 2,
	head_swivel = "head.control",
	bone_eye_height = 6.3,
	head_eye_height = 2.2,
	curiosity = 20,
	collisionbox = {-0.25, -0.01, -0.25, 0.25, 1.94, 0.25},
	visual = "mesh",
	mesh = "mobs_mc_villager.b3d",
	textures = {
		"mobs_mc_villager.png",
		"mobs_mc_villager.png", --hat
	},
	makes_footstep_sound = true,
	walk_velocity = 1,
	run_velocity = 1.5,
	drops = {},
	can_despawn = false,
	-- TODO: sounds
	sounds = {
		random = "mobs_mc_villager",
		damage = "mobs_mc_villager_hurt",
		distance = 10,
	},
	animation = {
		stand_start = 0, stand_end = 0,
		walk_start = 0, walk_end = 40, walk_speed = 35,
		run_start = 0, run_end = 40, run_speed = 25,
		head_shake_start = 60, head_shake_end = 70, head_shake_loop = false,
		head_nod_start = 50, head_nod_end = 60, head_nod_loop = false,
	},
	_child_animations = {
		stand_start = 71, stand_end = 71,
		walk_start = 71, walk_end = 111, walk_speed = 60,
		run_start = 71, run_end = 111, run_speed = 50,
		punch_start = 90, punch_end = 110, punch_speed = 25,
		head_shake_start = 131, head_shake_end = 141, head_shake_loop = false,
		head_nod_start = 121, head_nod_end = 131, head_nod_loop = false,
	},
	view_range = 32,
	fear_height = 2,
	jump = true,
	walk_chance = DEFAULT_WALK_CHANCE,
	_bed = nil,
	_id = nil,
	_profession = nil,
	_gender = nil,
	_attraction = nil,
	_partner = nil,
	_relationship = 0,
	_rejected_partners = {},
	_max_trade_tier = 1,
	_trade_xp = 0,
	look_at_player = true,
	can_open_doors = true,
	_player_scan_timer = 0,
	_bed_search_interval = 10,
	_sleep_over_interval = 10,
	_trading_players = {},
	damage = 3,
	knock_back = true,
	reach = 2,
	group_attack = { "mobs_mc:iron_golem", "mobs_mc:villager" },
	attack_type = "dogfight",
	after_activate = mobs_mc.villager_mob.set_textures,
	mob_pushable = false,
	follow = {"mcl_core:emerald"},
	pick_up = {
		"mcl_core:emerald",
		"mcl_farming:bread",
		"mcl_farming:carrot_item",
		"mcl_farming:beetroot_item",
		"mcl_farming:potato_item"
	}
})

mcl_mobs.register_mob("mobs_mc:villager", mobs_mc.villager_mob)

-- spawn eggs
mcl_mobs.register_egg("mobs_mc:villager", S("Villager"), "#563d33", "#bc8b72", 0)

dofile(modpath.."/villagers/wandering_trader.lua")
