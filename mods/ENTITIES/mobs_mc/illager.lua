-- Common definitions for illagers
-- Copyright (C) 2025 blu.256

mobs_mc.illager = {}

local villager_nodes = {
	"group:pane",
	"group:bed",
	"mcl_composters:composter",
	"mcl_barrels:barrel_closed",
	"mcl_fletching_table:fletching_table",
	"mcl_loom:loom",
	"mcl_lectern:lectern",
	"mcl_cartography_table:cartography_table",
	"mcl_blast_furnace:blast_furnace",
	"group:cauldron",
	"mcl_smoker:smoker",
	"mcl_grindstone:grindstone",
	"mcl_smithing_table:table",
	"mcl_brewing:stand_000",
	"mcl_stonecutter:stonecutter"
}

function mobs_mc.illager:summon_help()
	local basepos = self.object:get_pos()
	local spawnpos = vector.add(basepos, minetest.yaw_to_dir(pr:next(0,360)))
	local choice = math.random(10)
	local mob = ""
	if choice == 1 then
		mob = "mobs_mc:evoker"
	elseif choice == 2 then
		mob = "mobs_mc:pillager"
	elseif choice == 3 then
		mob = "mobs_mc:illusioner"
	elseif choice == 4 then
		mob = "mobs_mc:vindicator"
	else
		mob = self.object:get_luaentity().name
	end
	minetest.add_entity(spawnpos, mob)
end

function mobs_mc.illager:find_closest_air_block(pos)
	local air = minetest.find_node_near(pos, 2, "air", true)
	if air then return air else return pos end
end

function mobs_mc.illager:find_closest_mob(radius, ent)
	local pos = self.object:get_pos()
	if type(ent) ~= "table" then ent = {ent} end

	for o in minetest.objects_inside_radius(pos, radius) do
		local l = o:get_luaentity()
		if l and o ~= self.object and l.is_mob
			and table.indexof(ent, l.name) ~= -1
		then return l end
	end
	return nil
end

function mobs_mc.illager:find_closest_loot(radius, loot)
	local pos = self.object:get_pos()
	if type(loot) ~= "table" then loot = {loot} end

	for o in minetest.objects_inside_radius(pos, radius) do
		local l = o:get_luaentity()
		if l and l.name == "__builtin:item" then
			local stack = ItemStack(l.itemstring)
			if table.indexof(loot, stack:get_name()) ~= -1
			then return l end
		end
	end
	return nil
end

function mobs_mc.illager:share_gunpowder(other, amount)
	self.order = "stand"
	other.order = "stand"
	self:set_state("stand")
	other:set_state("stand")

	self:look_at(other.object:get_pos())
	other:look_at(self.object:get_pos())

	local dropped_item = ItemStack("mcl_mobitems:gunpowder")
	dropped_item:set_count(amount)

	local dropped_meta = dropped_item:get_meta()
	dropped_meta:set_string("dropper", self._id)

	self._gunpowder:set_count(self._gunpowder:get_count() - amount)
	minetest.add_item(other.object:get_pos(), dropped_item)

	self.order = nil
	other.order = nil
	self:set_state("walk")
	other:set_state("walk")
end

function mobs_mc.illager:place_explosives(self)
	if not self.place_tnt or self._gunpowder:get_count() < 5 then return end

	local pos = self.object:get_pos()
	local yaw = self.object:get_yaw()
	local place_pos = vector.add(
		pos,
		minetest.facedir_to_dir(minetest.dir_to_facedir(minetest.yaw_to_dir(yaw)))
	)

	self.order = "stand"
	self:set_state("stand")

	if minetest.get_node(place_pos).name == "air"
		and not minetest.is_protected(place_pos, "")
	then
		local success = minetest.place_node(place_pos, {name = "mcl_tnt:tnt"})
		if success then
			self._gunpowder:set_count(self._gunpowder:get_count() - 5)

			local def = minetest.registered_nodes["mcl_tnt:tnt"]
			minetest.sound_play(def.sounds.place, {pos = place_pos, max_head_distance = 16}, true)

			tnt.ignite(place_pos)

			-- Run away
			self.order = nil
			self.runaway_timer = 0
			self:set_yaw(minetest.dir_to_yaw(vector.direction(place_pos, self.object:get_pos())))
			self:set_state("runaway")
			return
		end

		self.order = nil
		self:set_state("walk")
	end
end

table.update(mobs_mc.illager, {
	type = "monster",
	spawn_class = "hostile",
	can_despawn = false,
	pathfinding = 1,
	place_tnt = false,
	passive = false,
	retaliates = true,
	runaway = false,
	attack_npcs = true,
	physical = true,
	specific_attack = {
		"mobs_mc:villager",
		"mobs_mc:cat",
		"mobs_mc:witch",
		"mobs_mc:wandering_trader"
	},
	group_attack = {
		"mobs_mc:pillager",
		"mobs_mc:vindicator",
		"mobs_mc:vex",
		"mobs_mc:evoker",
		"mobs_mc:illusioner"
	},
	runaway_from = {
		"mobs_mc:iron_golem"
	},
	can_open_doors = true,
	pick_up = {
		"mcl_core:emerald"
	},

	on_spawn = function(self)
		self._id = minetest.sha1(minetest.get_gametime()
			..minetest.pos_to_string(self.object:get_pos())
			..tostring(math.random()))

		self._emeralds = ItemStack("mcl_core:emerald 0")
		if self.place_tnt then
			if table.indexof(self.pick_up, "mcl_mobitems:gunpowder") == nil then
				table.insert(self.pick_up, "mcl_mobitems:gunpowder")
			end
			if table.indexof(self.pick_up, "mcl_tnt:tnt") == nil then
				table.insert(self.pick_up, "mcl_tnt:tnt")
			end
			self._gunpowder = ItemStack("mcl_mobitems:gunpowder 0")
		end

		if self.on_illager_spawn then
			self.on_illager_spawn(self)
		end
	end,

	on_die = function(self)
		local pos = self.object:get_pos()
		minetest.add_item(pos, self._emeralds)
		if self.place_tnt and self._gunpowder then
			minetest.add_item(pos, self._gunpowder)
		end

		if self.on_illager_die then
			self.on_illager_die(self)
		end
	end,

	on_pick_up = function(self, e)
		if (self.place_tnt and not self._gunpowder)
			or not self._emeralds or not self._id
		then
			self:on_spawn(self)
		end

		local stack = ItemStack(e.itemstring)
		local item = stack:get_name()

		-- Pick up emeralds. Used as currency for summoning help
		if item == "mcl_core:emerald" then
			local count = stack:get_count()
			stack:take_item(count)
			self._emeralds:set_count(self._emeralds:get_count() + count)
			return stack

		-- Pick up gunpowder, used for making explosives
		elseif self.place_tnt and
			(item == "mcl_mobitems:gunpowder" or item == "mcl_tnt:tnt")
		then
			local meta = stack:get_meta()
			if self._id and meta:get_string("dropper") == self._id then
				return stack
			end

			local count = stack:get_count()
			stack:take_item(count)
			if item == "mcl_tnt:tnt" then
				count = count * 5
			end
			self._gunpowder:set_count(self._gunpowder:get_count() + count)
			return stack

		-- Custom pick up implementation
		elseif self.on_illager_pick_up then
			return self.on_illager_pick_up(self, e)
		else
			return stack
		end
	end,

	do_custom = function(self)
		if (self.place_tnt and not self._gunpowder)
			or not self._emeralds or not self._id
		then
			self:on_spawn(self)
		end

		if self.on_illager_custom then
			if self.on_illager_custom(self) then return true end
		end

		if self.state == "gowp" then return true end

		-- Summon help
		if math.random(5000) == 1 and self._emeralds:get_count() > 1 then
			self._emeralds:set_count(self._emeralds:get_count() - 1)
			self:summon_help()
		end

		-- Attack nearby enemies
		self:attack_specific()
		if self.state == "attack" or self.state == "runaway" then return true end

		self.order = nil

		-- Find nearby loot or enemies to attack
		local enemy = self:find_closest_mob(self.view_range, self.specific_attack)
		if enemy then
			if self:gopath(enemy.object:get_pos(), function(self)
				if self then self:attack_specific() end
			end, true)
			then return true end
		end

		local loot = self:find_closest_loot(math.floor(self.view_range * .75), self.pick_up)
		if loot then
			local loot_pos = loot.object:get_pos()
			local dist = vector.distance(self.object:get_pos(), loot_pos)
			if self:gopath(loot.object:get_pos(), function(self)
				if self then
					self.on_pick_up(self, loot)
					loot.object:remove()
				end
			end, true)
			then return true end
		end

		-- Look for villager structures and try to enter or bomb them
		if math.random(500) == 1 then
			local pos = self.object:get_pos()

			-- Prioritise everything except doors
			local npos = minetest.find_node_near(pos, self.view_range, villager_nodes, true)
			if not npos then
				npos = minetest.find_node_near(pos, self.view_range, {"group:door"}, true)
			end

			if npos then
				self:set_yaw(minetest.dir_to_yaw(vector.direction(npos, pos)))

				local node = minetest.get_node(npos)
				local dist = vector.distance(pos, npos)
				if dist > 5 then
					-- Find closest air block
					local tpos = minetest.find_node_near(npos, 2, "air", true)
					if tpos then
						local gp = self:gopath(tpos, function(self)
							if self then
								if math.random(100) == 1 and self.place_tnt then
									self:place_explosives()
								else
									self:attack_specific()
								end
							end
						end)
					end
				else
					if math.random(100) == 1 and self.place_tnt then
						self:place_explosives()
					else
						self:attack_specific()
					end
				end
			end
		end

		if not self.place_tnt then return true end

		-- Share explosives
		local other = self:find_closest_mob(3, self.object:get_luaentity().name)
		if math.random(20) == 1 and other then
			if not self._gunpowder or not self._id then self:on_spawn(self) end
			if not other._gunpowder or not other._id then other:on_spawn(self) end

			local diff = self._gunpowder:get_count() - other._gunpowder:get_count()
			if diff > 1 then
				local share = math.floor(diff / 2)
				self:share_gunpowder(other, share)
			end
		end
	end
})