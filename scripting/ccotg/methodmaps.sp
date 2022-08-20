static float g_flLastClassChange[MAXPLAYERS + 1];
static bool g_bHasChangedClass[MAXPLAYERS + 1];
static bool g_bIsInRespawnRoom[MAXPLAYERS + 1];
static TFClassType g_nBufferedClass[MAXPLAYERS + 1];
static ArrayList g_aClassData[MAXPLAYERS + 1];

enum struct ClassData
{
	TFClassType nClass;
	
	int iClip[3];
	int iAmmo[TF_AMMO_COUNT];
	float flWeaponChargeMeter[3];
	float flWeaponChargeTime[3];
	
	int iMetal;
	int iHeads;
	int iRevengeCrits;
	float flChargeMeter;
	float flRage;
	float flHype;
	float flCloak;
	
	bool bRageDraining;
	bool bUbercharging;
	
	int iSpell;
	float flLastSwitch;
}

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
		this.bIsInRespawnRoom = false;
		this.nBufferedClass = TFClass_Unknown;
		
		this.ResetAllClassData();
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
		
		// Get the player's health now so it can be set properly after changing class
		int iOldHealth = GetEntProp(this.iClient, Prop_Send, "m_iHealth");
		int iOldMaxHealth = SDKCall_GetMaxHealth(this.iClient);
		
		// Store ammo, charge meters and the like
		this.StoreClassData(nCurrentClass);
		
		// Change classes!
		TF2_SetPlayerClass(this.iClient, nClass, false, true);
		TF2_RegeneratePlayer(this.iClient);
		
		// Retrieve ammo, charge meters and the like if we've already played the class we're switching to before
		this.ApplyClassData(nClass);
		
		// If switching back to engineer, check if there are any owned-but-not-really buildings and attach them back to the player
		if (nClass == TFClass_Engineer && g_cvKeepBuildings.BoolValue)
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
	
	public void StoreClassData(TFClassType nClass)
	{
		if (!g_cvAmmoManagement.BoolValue)
			return;
		
		ClassData data;
		data.nClass = nClass;
		
		// Get client ent props
		
		// Class-specific
		switch(nClass)
		{
			case TFClass_Scout: data.flHype = GetEntPropFloat(this.iClient, Prop_Send, "m_flHypeMeter");
			case TFClass_DemoMan: data.flChargeMeter = GetEntPropFloat(this.iClient, Prop_Send, "m_flChargeMeter");
			case TFClass_Engineer: data.iMetal = GetEntProp(this.iClient, Prop_Send, "m_iAmmo", _, TF_AMMO_METAL);
			case TFClass_Spy: data.flCloak = GetEntPropFloat(this.iClient, Prop_Send, "m_flCloakMeter");
		}
		
		// Multiple classes use these
		data.iHeads = GetEntProp(this.iClient, Prop_Send, "m_iDecapitations");
		data.iRevengeCrits = GetEntProp(this.iClient, Prop_Send, "m_iRevengeCrits");
		data.flRage = GetEntPropFloat(this.iClient, Prop_Send, "m_flRageMeter");
		data.bRageDraining = view_as<bool>(GetEntProp(this.iClient, Prop_Send, "m_bRageDraining"));
		
		data.flLastSwitch = GetGameTime();
		
		// Deal with weapons
		for (int i = TFWeaponSlot_Primary; i <= TFWeaponSlot_Melee; i++)
		{
			int iWeapon = TF2_GetItemInSlot(this.iClient, i);
			
			if (iWeapon <= MaxClients)
				continue;
			
			// Store weapon clip and ammo
			if (HasEntProp(iWeapon, Prop_Send, "m_iClip1"))
				data.iClip[i] = GetEntProp(iWeapon, Prop_Send, "m_iClip1");
			
			if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
			{
				int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
				if (iAmmoType > -1)
					data.iAmmo[iAmmoType] = GetEntProp(this.iClient, Prop_Send, "m_iAmmo", _, iAmmoType);
			}
			
			char sClassname[32];
			GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
			
			// Store weapon-specific charge meters
			switch(i)
			{
				case TFWeaponSlot_Primary:
				{
					if (StrEqual(sClassname, "tf_weapon_particle_cannon") || StrEqual(sClassname, "tf_weapon_drg_pomson"))
					{
						data.flWeaponChargeMeter[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy");
					}
					else
					{
						data.flWeaponChargeMeter[i] = GetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", i);
					}
				}
				
				case TFWeaponSlot_Secondary:
				{
					if (StrEqual(sClassname, "tf_weapon_medigun"))
					{
						data.flWeaponChargeMeter[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargeLevel");
						data.bUbercharging = view_as<bool>(GetEntProp(iWeapon, Prop_Send, "m_bChargeRelease"));
					}
					else if (StrEqual(sClassname, "tf_weapon_raygun"))
					{
						data.flWeaponChargeMeter[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy");
					}
					else if (StrEqual(sClassname, "tf_weapon_charged_smg"))
					{
						data.flWeaponChargeMeter[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flMinicritCharge");
					}
					else if (StrEqual(sClassname, "tf_weapon_rocketpack") || StrEqual(sClassname, "tf_weapon_jar_gas") || StrEqual(sClassname, "tf_weapon_lunchbox") || StrEqual(sClassname, "tf_wearable_razorback"))
					{
						data.flWeaponChargeMeter[i] = GetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", i);
					}
					else if (HasEntProp(iWeapon, Prop_Send, "m_flEffectBarRegenTime"))
					{
						data.flWeaponChargeTime[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime");
					}
				}
				
				case TFWeaponSlot_Melee:
				{
					if (StrEqual(sClassname, "tf_weapon_knife"))
					{
						data.flWeaponChargeTime[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flKnifeMeltTimestamp");
					}
					else if (HasEntProp(iWeapon, Prop_Send, "m_flEffectBarRegenTime"))
					{
						data.flWeaponChargeTime[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime");
					}
					else
					{
						data.flWeaponChargeMeter[i] = GetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", i);
					}
				}
			}
		}
		
		// If we haven't already played this class, add data for it, and if we have, replace
		int iValue = g_aClassData[this.iClient].FindValue(nClass, ClassData::nClass);
		if (iValue == -1)
		{
			g_aClassData[this.iClient].PushArray(data);
		}
		else
		{
			g_aClassData[this.iClient].SetArray(iValue, data);
		}
	}
	
	public void ApplyClassData(TFClassType nClass)
	{
		if (!g_cvAmmoManagement.BoolValue)
			return;
		
		int iValue = g_aClassData[this.iClient].FindValue(nClass, ClassData::nClass);
		
		// Haven't played this class yet, set things that would normally transfer over to 0
		if (iValue == -1)
		{
			SetEntProp(this.iClient, Prop_Send, "m_iDecapitations", 0);
			SetEntProp(this.iClient, Prop_Send, "m_iRevengeCrits", 0);
			SetEntPropFloat(this.iClient, Prop_Send, "m_flRageMeter", 0.0);
			SetEntProp(this.iClient, Prop_Send, "m_bRageDraining", false);
			
			return;
		}
		
		ClassData data;
		g_aClassData[this.iClient].GetArray(iValue, data);
		
		// Set client ent props
		SetEntProp(this.iClient, Prop_Send, "m_iAmmo", data.iMetal, _, TF_AMMO_METAL);
		SetEntProp(this.iClient, Prop_Send, "m_iDecapitations", data.iHeads);
		SetEntProp(this.iClient, Prop_Send, "m_iRevengeCrits", data.iRevengeCrits);
		SetEntPropFloat(this.iClient, Prop_Send, "m_flChargeMeter", data.flChargeMeter);
		SetEntPropFloat(this.iClient, Prop_Send, "m_flRageMeter", data.flRage);
		SetEntPropFloat(this.iClient, Prop_Send, "m_flHypeMeter", data.flHype);
		SetEntPropFloat(this.iClient, Prop_Send, "m_flCloakMeter", data.flCloak);
		SetEntProp(this.iClient, Prop_Send, "m_bRageDraining", data.bRageDraining);
		
		// Deal with weapons
		for (int i = TFWeaponSlot_Primary; i <= TFWeaponSlot_Melee; i++)
		{
			int iWeapon = TF2_GetItemInSlot(this.iClient, i);
			
			if (iWeapon <= MaxClients)
				continue;
			
			// Set clip size and ammo
			if (HasEntProp(iWeapon, Prop_Send, "m_iClip1"))
			{
				int iExpectedClip = Min(data.iClip[i], SDKCall_GetMaxClip(iWeapon));
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", iExpectedClip);
			}
			
			if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
			{
				int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
				if (iAmmoType > -1)
				{
					int iExpectedAmmo = Min(data.iAmmo[iAmmoType], SDKCall_GetMaxAmmo(this.iClient, iAmmoType));
					SetEntProp(this.iClient, Prop_Send, "m_iAmmo", iExpectedAmmo, _, iAmmoType);
				}
			}
			
			char sClassname[32];
			GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
			
			// Apply weapon-specific charge meters
			switch(i)
			{
				case TFWeaponSlot_Primary:
				{
					if (StrEqual(sClassname, "tf_weapon_particle_cannon") || StrEqual(sClassname, "tf_weapon_drg_pomson"))
					{
						SetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy", data.flWeaponChargeMeter[i]);
					}
					else
					{
						if (data.flWeaponChargeMeter[i] > 0.0)
							SetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", data.flWeaponChargeMeter[i], i);
					}
				}
				
				case TFWeaponSlot_Secondary:
				{
					if (StrEqual(sClassname, "tf_weapon_medigun"))
					{
						SetEntPropFloat(iWeapon, Prop_Send, "m_flChargeLevel", data.flWeaponChargeMeter[i]);
						SetEntProp(iWeapon, Prop_Send, "m_bChargeRelease", data.bUbercharging);
					}
					else if (StrEqual(sClassname, "tf_weapon_raygun"))
					{
						SetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy", data.flWeaponChargeMeter[i]);
					}
					else if (StrEqual(sClassname, "tf_weapon_charged_smg"))
					{
						SetEntPropFloat(iWeapon, Prop_Send, "m_flMinicritCharge", data.flWeaponChargeMeter[i]);
					}
					else if (StrEqual(sClassname, "tf_weapon_lunchbox_drink") || StrEqual(sClassname, "tf_weapon_jar") || StrEqual(sClassname, "tf_weapon_jar_milk") || StrEqual(sClassname, "tf_weapon_cleaver"))
					{
						// This apparently refreshes ammo on some weapons that don't use it (which is why the classnames are all hardcoded). cute
						SetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime", (data.flWeaponChargeTime[i] + GetGameTime()) - data.flLastSwitch);
					}
					else
					{
						SetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", data.flWeaponChargeMeter[i], i);
					}
				}
				
				case TFWeaponSlot_Melee:
				{
					if (StrEqual(sClassname, "tf_weapon_knife"))
					{
						// ??????? i don't fuckin know lol
						if ((data.flLastSwitch - data.flWeaponChargeTime[i]) < 15.0)
						{
							SetEntPropFloat(iWeapon, Prop_Send, "m_flKnifeMeltTimestamp", GetGameTime());
							SetEntPropFloat(iWeapon, Prop_Send, "m_flKnifeRegenerateDuration", 15.0 - (data.flLastSwitch - data.flWeaponChargeTime[i]));
							
							data.flWeaponChargeTime[i] = GetGameTime();
						}
						else
						{
							data.flWeaponChargeTime[i] = GetGameTime() - 15.0;
						}
					}
					else if (HasEntProp(iWeapon, Prop_Send, "m_flEffectBarRegenTime"))
					{
						SetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime", (data.flWeaponChargeTime[i] + GetGameTime()) - data.flLastSwitch);
					}
					else
					{
						if (data.flWeaponChargeMeter[i] > 0.0)
							SetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", data.flWeaponChargeMeter[i], i);
					}
				}
			}
		}
	}
	
	public void ResetAllClassData()
	{
		if (!g_aClassData[this.iClient])
		{
			g_aClassData[this.iClient] = new ArrayList(sizeof(ClassData));
		}
		else
		{
			g_aClassData[this.iClient].Clear();
		}
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
	
	public void Destroy()
	{
		// Free up memory space
		delete g_aClassData[this.iClient];
		
		// Destroy all buildings
		int iBuilding = MaxClients + 1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		{
			if (IsValidEntity(iBuilding) && GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == this.iClient)
			{
				SetVariantInt(999999);
				AcceptEntityInput(iBuilding, "RemoveHealth");
			}
		}
	}
}