static float g_flLastClassChange[MAXPLAYERS + 1];
static bool g_bHasChangedClass[MAXPLAYERS + 1];
static bool g_bHasRobotArm[MAXPLAYERS + 1];
static bool g_bIsInRespawnRoom[MAXPLAYERS + 1];
static TFClassType g_nBufferedClass[MAXPLAYERS + 1];

methodmap Player
{
	public Player(int iClient)
	{
		return view_as<Player>(iClient);
	}
	
	property int iClient
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property float flLastClassChange
	{
		public get()
		{
			return g_flLastClassChange[this.iClient];
		}
		public set(float flTime)
		{
			g_flLastClassChange[this.iClient] = flTime;
		}
	}
	
	property bool bHasChangedClass
	{
		public get()
		{
			return g_bHasChangedClass[this.iClient];
		}
		public set(bool bHasChangedClass)
		{
			g_bHasChangedClass[this.iClient] = bHasChangedClass;
		}
	}
	
	property bool bHasRobotArm
	{
		public get()
		{
			return g_bHasRobotArm[this.iClient];
		}
		public set(bool bHasRobotArm)
		{
			g_bHasRobotArm[this.iClient] = bHasRobotArm;
		}
	}
	
	property bool bIsInRespawnRoom
	{
		public get()
		{
			return g_bIsInRespawnRoom[this.iClient];
		}
		public set(bool bIsInRespawnRoom)
		{
			g_bIsInRespawnRoom[this.iClient] = bIsInRespawnRoom;
		}
	}
	
	property TFClassType nBufferedClass
	{
		public get()
		{
			return g_nBufferedClass[this.iClient];
		}
		public set(TFClassType nBufferedClass)
		{
			g_nBufferedClass[this.iClient] = nBufferedClass;
		}
	}
	
	public void Reset()
	{
		this.flLastClassChange = GetGameTime();
		this.bHasChangedClass = false;
		this.bHasRobotArm = false;
		this.bIsInRespawnRoom = false;
		this.nBufferedClass = TFClass_Unknown;
	}
	
	public void SetClass(TFClassType nClass)
	{
		// Switching classes while taunting makes players have no active weapon, so stop them
		TF2_RemoveCondition(this.iClient, TFCond_Taunting);
		
		// Check if the player is switching FROM engineer to handle building ownership
		TFClassType nCurrentClass = TF2_GetPlayerClass(this.iClient);
		
		if (nCurrentClass == TFClass_Engineer)
		{
			int iBuilding = MaxClients + 1;
			while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
			{
				if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == this.iClient)
				{
					if (g_cvKeepBuildings.BoolValue)
					{
						// Detach buildings from engineers before switching class if the convar to keep is on
						SDKCall_RemoveObject(this.iClient, iBuilding);
					}
					else
					{
						// If it is not on, murder them. kill them. dispose of their mechanical bodies.
						SetVariantInt(999999);
						AcceptEntityInput(iBuilding, "RemoveHealth");
					}
				}
			}
		}
		
		// If switching to sniper, handle the gunslinger viewmodel before actually switching classes
		if (nClass == TFClass_Sniper)
		{
			// Give him the the "mod wrench builds minisentry" attribute (before changing classes) to prevent a server crash related to specifically the Sniper's viewmodel
			TF2Attrib_SetByName(this.iClient, "mod wrench builds minisentry", 1.0);
			this.bHasRobotArm = true;
		}
		else
		{
			// (doing this doesn't have any effect on weapons with this attribute)
			TF2Attrib_RemoveByName(this.iClient, "mod wrench builds minisentry");
			this.bHasRobotArm = false;
		}
		
		// Get the player's health now so it can be set properly after changing class
		int iOldHealth = GetEntProp(this.iClient, Prop_Send, "m_iHealth");
		int iOldMaxHealth = SDKCall_GetMaxHealth(this.iClient);
		
		// Change classes!
		TF2_SetPlayerClass(this.iClient, nClass, false, true);
		TF2_RegeneratePlayer(this.iClient);
		
		// If the player switched to sniper, now make their non-passive weapons hidden, because the engi's hand is ugly to look at
		if (nClass == TFClass_Sniper)
		{
			for (int i = TFWeaponSlot_Primary; i <= TFWeaponSlot_Melee; i++)
			{
				int iWeapon = GetPlayerWeaponSlot(this.iClient, i);
				if (iWeapon > MaxClients)
				{
					SetEntityRenderMode(iWeapon, RENDER_TRANSCOLOR);
					SetEntityRenderColor(iWeapon, _, _, _, 0);
				}
			}
			
			CPrintToChat(this.iClient, "{red}Your Sniper weapons were made invisible to prevent server crashes. Apologies for the inconvenience.");
		}
		// If switching back to engineer, check if there are any owned-but-not-really buildings and attach them back to the player
		else if (nClass == TFClass_Engineer && g_cvKeepBuildings.BoolValue)
		{
			int iBuilding = MaxClients + 1;
			while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
			{
				if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == this.iClient)
					SDKCall_AddObject(this.iClient, iBuilding);
			}
		}
		
		// Handle health
		int iNewMaxHealth = SDKCall_GetMaxHealth(this.iClient);
		int iFinalHealth;
		
		switch(g_cvHealthMode.IntValue)
		{
			// Keep the same health
			case 1: iFinalHealth = iOldHealth;
			
			// Change health to have the same health:max health ratio between classes
			case 2: iFinalHealth = RoundToCeil(iNewMaxHealth * (float(iOldHealth) / float(iOldMaxHealth)));
			
			// Just full heal
			default: iFinalHealth = iNewMaxHealth;
		}
		
		// Handle overheal
		int iMaxAllowedHealth = RoundToCeil(iNewMaxHealth * g_cvHealthMaxOverheal.FloatValue);
		
		if (iFinalHealth > iMaxAllowedHealth)
			iFinalHealth = iMaxAllowedHealth;
		
		// Set final health
		SetEntProp(this.iClient, Prop_Send, "m_iHealth", iFinalHealth);
		
		// Add a little effect
		float vecPos[3];
		GetClientAbsOrigin(this.iClient, vecPos);
		ShowParticle(TF2_GetClientTeam(this.iClient) == TFTeam_Blue ? "teleportedin_blue" : "teleportedin_red", 0.1, vecPos);
		
		// Update properties
		this.flLastClassChange = GetGameTime();
		this.bHasChangedClass = true;
	}
	
	public bool IsInCooldown(bool bDisplayText = false)
	{
		bool bResult = false;
		
		// If the convar is not set, well, ignore this
		if (g_cvCooldown.FloatValue <= 0.0)
			return bResult;
		
		float flTime = GetGameTime();
		float flTimeSinceLastChange = flTime - this.flLastClassChange;
		float flCooldown = g_cvCooldown.FloatValue;
	
		if (flTimeSinceLastChange < flCooldown)
		{
			if (bDisplayText)
				CPrintToChat(this.iClient, "%t", "ChangeClass_Wait_Cooldown", (flCooldown - flTimeSinceLastChange));
			
			bResult = true;
		}
		
		return bResult;
	}
	
	public bool IsInBadState(bool bDisplayText = false)
	{
		bool bResult = false;
		
		// If the convar is not set, well, ignore this
		if (!g_cvPreventSwitchingDuringBadStates.BoolValue)
			return bResult;
		
		// TFCond_RocketPack makes the looping woosh sound persist until you switch back to Pyro (or die)
		if (TF2_IsPlayerInCondition(this.iClient, TFCond_RocketPack))
		{
			if (bDisplayText)
				CPrintToChat(this.iClient, "%t", "ChangeClass_Wait_BadState_Jetpacking");
			
			bResult = true;
		}
		// Hauling a building makes other classes A-pose and not be able to place the hauled building until you switch back to Engie (or hold the Sapper as Spy, or respawn)
		else if (GetEntProp(this.iClient, Prop_Send, "m_bCarryingObject") && g_cvKeepBuildings.BoolValue)
		{
			if (bDisplayText)
				CPrintToChat(this.iClient, "%t", "ChangeClass_Wait_BadState_Hauling");
			
			bResult = true;
		}
		
		return bResult;
	}
	
	public bool CanTeamChangeClass()
	{
		// Checking for the only-allow-team convar
		TFTeam nTeam = TF2_GetClientTeam(this.iClient);
		
		if (g_nTeamThatIsAllowedToChangeClass <= TFTeam_Spectator || g_nTeamThatIsAllowedToChangeClass == nTeam)
			return true;
		
		return false;
	}
}