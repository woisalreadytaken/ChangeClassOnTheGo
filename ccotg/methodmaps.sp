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
	
		// i fucking hate the sniper :DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
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
		
		// Get the player's current health now so it can be set properly after changing class
		int iOldHealth = GetEntProp(this.iClient, Prop_Send, "m_iHealth");
		
		// Change classes!
		TF2_SetPlayerClass(this.iClient, nClass, false, true);
		TF2_RegeneratePlayer(this.iClient);
		
		// have i told you how much i fucking hate this class?
		if (nClass == TFClass_Sniper)
		{
			// Hide all non-passive weapons (after changing classes), because the engi's hand is ugly to look at
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
		
		int iNewHealth = GetEntProp(this.iClient, Prop_Send, "m_iHealth");
		int iMaxHealth = SDKCall_GetMaxHealth(this.iClient);
		
		if (iOldHealth < iNewHealth) // Don't let players heal off switching classes
		{
			SetEntProp(this.iClient, Prop_Send, "m_iHealth", iOldHealth);
		}
		else if (iOldHealth > iMaxHealth) // Don't let players be overhealed by the previous class' higher health
		{
			SetEntProp(this.iClient, Prop_Send, "m_iHealth", iMaxHealth);
		}
		
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
				CPrintToChat(this.iClient, "{red}You will switch classes in approximately {unique}%.2fs{red}.", (flCooldown - flTimeSinceLastChange));
			
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
				CPrintToChat(this.iClient, "{red}You will switch classes when you are done {unique}jetpacking{red}.");
			
			bResult = true;
		}
		// Hauling a building makes other classes A-pose and not be able to place the hauled building until you switch back to Engie (or hold the Sapper as Spy, or respawn)
		else if (GetEntProp(this.iClient, Prop_Send, "m_bCarryingObject"))
		{
			if (bDisplayText)
				CPrintToChat(this.iClient, "{red}You will switch classes when you are done {unique}hauling a building{red}.");
			
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