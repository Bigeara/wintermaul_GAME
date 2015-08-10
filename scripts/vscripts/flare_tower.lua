require('buildinghelper')

BUILD_TIME=1.0

function printTable( kv )
	if kv ~= nil and type( kv ) == "table" then
		for k,v in pairs( kv ) do
			print("key: ", k, " Value: ", v)
		end
	elseif kv ~= nil then
		print("Value: ", kv)
	else
		print("Value was nil")
	end
end


function getBuildingPoint(keys)
	local point = BuildingHelper:AddBuildingToGrid(keys.target_points[1], 2, keys.caster)
	print("Caster: ",keys.caster:GetOwner())
	printTable(keys.caster:GetOwner())
	print("Caster PLayer OwnerID: ",keys.caster:GetPlayerOwnerID())
	printTable(keys.caster:GetPlayerOwnerID())
	print("Caster PLayer Owner: ",keys.caster:GetPlayerOwner())
	printTable(keys.caster:GetPlayerOwner())
	local hOwner = keys.caster:GetPlayerOwner()
	if point ~= -1 then
		local tower = CreateUnitByName("flare_tower", point, false, hOwner, hOwner, DOTA_TEAM_GOODGUYS)
		print("")
		print("Tower: ", tower)
		printTable(tower)
		print("Tower Owner: ", tower:GetOwner())
		printTable(tower:GetOwner())
		print("Tower Origin: ", tower:GetAbsOrigin())
		print("Tower PlayerOwner: ",tower:GetPlayerOwnerID())
		printTable(tower:GetPlayerOwnerID())
		BuildingHelper:AddBuilding(tower)
		tower:SetOwner(keys.caster:GetOwner())
		tower:UpdateHealth(BUILD_TIME,true,.85)
		tower:SetHullRadius(64)
		tower:SetControllableByPlayer( keys.caster:GetPlayerID(), true )
		print("Tower Owner (after set): ", tower:GetOwner())
		printTable(tower:GetOwner())
		print("Tower PlayerOwner (after set): ",tower:GetPlayerOwnerID())
		printTable(tower:GetPlayerOwnerID())
	else
		--Fire a game event here and use Actionscript to let the player know he can't place a building at this spot.
	end
end

function getHardtowerPoint(keys)
	local caster = keys.caster
	local point = BuildingHelper:AddBuildingToGrid(keys.target_points[1], 4, caster)
	if point == -1 then
		-- Refund the cost.
		caster:SetGold(caster:GetGold()+HARD_tower_COST, false)
		--Fire a game event here and use Actionscript to let the player know he can't place a building at this spot.
		return
	else
		caster:SetGold(caster:GetGold()-5, false)
		local tower = CreateUnitByName("npc_hard_tower", point, false, nil, nil, caster:GetTeam())
		BuildingHelper:AddBuilding(tower)
		tower:UpdateHealth(BUILD_TIME,true,.8)
		tower:SetHullRadius(128)
		tower:SetControllableByPlayer( caster:GetPlayerID(), true )
	end
end
