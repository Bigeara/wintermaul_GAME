--[[
	CWintermaulGameSpawner - A single unit spawner for Holdout.
]]
if CWintermaulGameSpawner == nil then
	CWintermaulGameSpawner = class({})
end


function CWintermaulGameSpawner:ReadConfiguration( name, kv, gameRound )
	self._gameRound = gameRound
	self._dependentSpawners = {}

	self._szChampionNPCClassName = kv.ChampionNPCName or ""
	self._szGroupWithUnit = kv.GroupWithUnit or ""
	self._szName = name
	self._szNPCClassName = kv.NPCName or ""
	self._szSpawnerName = kv.SpawnerName or ""
	self._szWaitForUnit = kv.WaitForUnit or ""
	self._szWaypointName = kv.Waypoint or ""
	self._waypointEntity = nil

	self._nChampionLevel = tonumber( kv.ChampionLevel or 1 )
	self._nChampionMax = tonumber( kv.ChampionMax or 1 )
	self._nCreatureLevel = tonumber( kv.CreatureLevel or 1 )
	self._nTotalUnitsToSpawn = tonumber( kv.TotalUnitsToSpawn or 0 )
	self._nUnitsPerSpawn = tonumber( kv.UnitsPerSpawn or 0 )
	self._nUnitsPerSpawn = tonumber( kv.UnitsPerSpawn or 1 )

	self._flChampionChance = tonumber( kv.ChampionChance or 0 )
	self._flInitialWait = tonumber( kv.WaitForTime or 0 )
	self._flSpawnInterval = tonumber( kv.SpawnInterval or 0 )

	self._bDontGiveGoal = ( tonumber( kv.DontGiveGoal or 0 ) ~= 0 )
	self._bDontOffsetSpawn = ( tonumber( kv.DontOffsetSpawn or 0 ) ~= 0 )

	if kv.PossibleSpawns ~= nil then
		self:_LoadPossibleSpawns( kv.PossibleSpawns )
	end
end

function CWintermaulGameSpawner:_LoadPossibleSpawns( kvSpawns )
	print("load possible spawns function")
	vPossibleSpawnsNames = {}
	self._vPossibleSpawns = {}
	if type( kvSpawns ) == "table" then
		print("its a table")
		local i
		while true do
			i = #vPossibleSpawnsNames + 1
			if kvSpawns[string.format(i)] == nil then
				print("element ", i, " was nil")
				break
			end
			table.insert(vPossibleSpawnsNames, kvSpawns[string.format(i)])
			print("key: ", i, " val: ", kvSpawns[string.format(i)])
		end
	else
		print("its not a table")
	end
	print("what the fuck are you fucking doing")
	for k,v in pairs( vPossibleSpawnsNames ) do
		print(self:_SearchSpawnTable(v))
		table.insert(self._vPossibleSpawns, self:_SearchSpawnTable(v))
		for kk,vv in pairs(self:_SearchSpawnTable(v)) do
			print("---- key: ", kk, " val: ", vv)
		end
		print("| key: ", k, " | val: ", v, " |")
	end
		for k,v in pairs( self._vPossibleSpawns ) do
		print("key: ", k, "val: ", v.szSpawnerName, v.szFirstWaypoint)
	end
end

function CWintermaulGameSpawner:_SearchSpawnTable( sSpawnName )
	local spawn
	for k,v in pairs(self._gameRound._gameMode._vSpawnsList) do
		if v.szSpawnerName == sSpawnName then
			spawn = v
		end
	end
	if spawn == nil then
		print("could not find ", sSpawnName)
	end
	return spawn
end

function CWintermaulGameSpawner:PostLoad( spawnerList )
	self._waitForUnit = spawnerList[ self._szWaitForUnit ]
	if self._szWaitForUnit ~= "" and not self._waitForUnit then
		print( "%s has a wait for unit %s that is missing from the round data.", self._szName, self._szWaitForUnit )
	elseif self._waitForUnit then
		table.insert( self._waitForUnit._dependentSpawners, self )
	end

	self._groupWithUnit = spawnerList[ self._szGroupWithUnit ]
	if self._szGroupWithUnit ~= "" and not self._groupWithUnit then
		print ("%s has a group with unit %s that is missing from the round data.", self._szName, self._szGroupWithUnit )
	elseif self._groupWithUnit then
		table.insert( self._groupWithUnit._dependentSpawners, self )
	end
end


function CWintermaulGameSpawner:Precache()
	PrecacheUnitByNameAsync( self._szNPCClassName, function( sg ) self._sg = sg end )
	if self._szChampionNPCClassName ~= "" then
		PrecacheUnitByNameAsync( self._szChampionNPCClassName, function( sg ) self._sgChampion = sg end )
	end
end


function CWintermaulGameSpawner:Begin()
	self._nUnitsSpawnedThisRound = 0
	self._nChampionsSpawnedThisRound = 0
	self._nUnitsCurrentlyAlive = 0

	self._vecSpawnLocation = nil
	if self._szSpawnerName ~= "" then
		print("Spawning started")
		local entSpawner = Entities:FindByName( nil, self._szSpawnerName )
		if not entSpawner then
			print( string.format( "Failed to find spawner named %s for %s\n", self._szSpawnerName, self._szName ) )
		end
		self._vecSpawnLocation = entSpawner:GetAbsOrigin()
	end
	self._entWaypoint = nil
	if self._szWaypointName ~= "" and not self._bDontGiveGoal then
		self._entWaypoint = Entities:FindByName( nil, self._szWaypointName )
		if not self._entWaypoint then
			print( string.format( "Failed to find waypoint named %s for %s", self._szWaypointName, self._szName ) )
		end
	end

	if self._waitForUnit ~= nil or self._groupWithUnit ~= nil then
		self._flNextSpawnTime = nil
	else
		self._flNextSpawnTime = GameRules:GetGameTime() + self._flInitialWait
	end
end


function CWintermaulGameSpawner:End()
	if self._sg ~= nil then
		UnloadSpawnGroupByHandle( self._sg )
		self._sg = nil
	end
	if self._sgChampion ~= nil then
		UnloadSpawnGroupByHandle( self._sgChampion )
		self._sgChampion = nil
	end
end


function CWintermaulGameSpawner:ParentSpawned( parentSpawner )
	if parentSpawner == self._groupWithUnit then
		-- Make sure we use the same spawn location as parentSpawner.
		self:_DoSpawn()
	elseif parentSpawner == self._waitForUnit then
		if parentSpawner:IsFinishedSpawning() and self._flNextSpawnTime == nil then
			self._flNextSpawnTime = parentSpawner._flNextSpawnTime + self._flInitialWait
		end
	end
end


function CWintermaulGameSpawner:Think()
	if not self._flNextSpawnTime then
		return
	end

	if GameRules:GetGameTime() >= self._flNextSpawnTime then
		self:_DoSpawn()
		for _,s in pairs( self._dependentSpawners ) do
			s:ParentSpawned( self )
		end

		if self:IsFinishedSpawning() then
			self._flNextSpawnTime = nil
		else
			self._flNextSpawnTime = self._flNextSpawnTime + self._flSpawnInterval
		end
	end
end


function CWintermaulGameSpawner:GetTotalUnitsToSpawn()
	return self._nTotalUnitsToSpawn
end


function CWintermaulGameSpawner:IsFinishedSpawning()
	return ( self._nTotalUnitsToSpawn <= self._nUnitsSpawnedThisRound ) or ( self._groupWithUnit ~= nil )
end


function CWintermaulGameSpawner:_GetSpawnLocation()
	if self._groupWithUnit then
		return self._groupWithUnit:_GetSpawnLocation()
	else
		return self._vecSpawnLocation
	end
end


function CWintermaulGameSpawner:_GetSpawnWaypoint()
	if self._groupWithUnit then
		return self._groupWithUnit:_GetSpawnWaypoint()
	else
		return self._entWaypoint
	end
end


function CWintermaulGameSpawner:_UpdateSpawn( index )
	self._vecSpawnLocation = Vector( 0, 0, 0 )
	self._entWaypoint = nil

	self:_GetSpawnerInfo(index)
end

function CWintermaulGameSpawner:_GetSpawnerInfo( index )
	local spawnInfo
	if self._vPossibleSpawns == nil then
		spawnInfo = self._gameRound._gameMode._vSpawnsList[ index ]
	else
		spawnInfo = self._vPossibleSpawns[ (index % (#self._vPossibleSpawns + 1)) ]
	end
	if spawnInfo == nil then
		print( string.format( "Failed to get random spawn info for spawner %s.", self._szName ) )
		return
	end

	local entSpawner = Entities:FindByName( nil, spawnInfo.szSpawnerName )
	if not entSpawner then
		print( string.format( "Failed to find spawner named %s for %s.", spawnInfo.szSpawnerName, self._szName ) )
		return
	end
	self._vecSpawnLocation = entSpawner:GetAbsOrigin()

	if not self._bDontGiveGoal then
		self._entWaypoint = Entities:FindByName( nil, spawnInfo.szFirstWaypoint )
		if not self._entWaypoint then
			print( string.format( "Failed to find a waypoint named %s for %s.", spawnInfo.szFirstWaypoint, self._szName ) )
			return
		end
	end
end


function CWintermaulGameSpawner:_DoSpawn()
	local nUnitsToSpawn = math.min( self._nUnitsPerSpawn, self._nTotalUnitsToSpawn - self._nUnitsSpawnedThisRound )

	if nUnitsToSpawn <= 0 then
		return
	elseif self._nUnitsSpawnedThisRound == 0 then
		print( string.format( "Started spawning %s at %.2f", self._szName, GameRules:GetGameTime() ) )
	end
	for i = 1, #self._gameRound._gameMode._vSpawnsList do
		if self._szSpawnerName == "" then
			self:_UpdateSpawn( i )
		end

		local vBaseSpawnLocation = self:_GetSpawnLocation()
		if not vBaseSpawnLocation then return end

		for iUnit = 1,nUnitsToSpawn do
			local bIsChampion = RollPercentage( self._flChampionChance )
			if self._nChampionsSpawnedThisRound >= self._nChampionMax then
				bIsChampion = false
			end

			local szNPCClassToSpawn = self._szNPCClassName
			if bIsChampion and self._szChampionNPCClassName ~= "" then
				szNPCClassToSpawn = self._szChampionNPCClassName
			end

			local vSpawnLocation = vBaseSpawnLocation
			if not self._bDontOffsetSpawn then
				vSpawnLocation = vSpawnLocation + RandomVector( RandomFloat( 0, 200 ) )
			end

			local entUnit = CreateUnitByName( szNPCClassToSpawn, vSpawnLocation, true, nil, nil, DOTA_TEAM_BADGUYS )
			if entUnit then
				if entUnit:IsCreature() then
					if bIsChampion then
						self._nChampionsSpawnedThisRound = self._nChampionsSpawnedThisRound + 1
						entUnit:CreatureLevelUp( ( self._nChampionLevel - 1 ) )
						entUnit:SetChampion( true )
						local nParticle = ParticleManager:CreateParticle( "heavens_halberd", PATTACH_ABSORIGIN_FOLLOW, entUnit )
						ParticleManager:ReleaseParticleIndex( nParticle )
						entUnit:SetModelScale( 1.1, 0 )
					else
						entUnit:CreatureLevelUp( self._nCreatureLevel - 1 )
					end
				end

				local entWp = self:_GetSpawnWaypoint()

				if entWp ~= nil then
					entUnit:SetInitialGoalEntity( entWp )
				end
				self._nUnitsSpawnedThisRound = self._nUnitsSpawnedThisRound + 1
				self._nUnitsCurrentlyAlive = self._nUnitsCurrentlyAlive + 1
				entUnit.Holdout_IsCore = true
				entUnit:SetDeathXP( self._gameRound:GetXPPerCoreUnit() )
			end
		end
	end
end


function CWintermaulGameSpawner:StatusReport()
	print( string.format( "** Spawner %s", self._szNPCClassName ) )
	print( string.format( "%d of %d spawned", self._nUnitsSpawnedThisRound, self._nTotalUnitsToSpawn ) )
end
