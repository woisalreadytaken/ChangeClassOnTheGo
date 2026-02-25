#pragma semicolon 1
#pragma newdecls required

static float g_flLastClassChange[MAXPLAYERS + 1];
static float g_flLastReset[MAXPLAYERS + 1];
static bool g_bIsChangingClass[MAXPLAYERS + 1];
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
	float flWeaponCooldown[3];
	float flWeaponChargeTime[3];
	float flWeaponEnergy[3];
	
	int iMetal;
	int iHeads;
	int iRevengeCrits;
	float flChargeMeter;
	float flRage;
	float flHype;
	float flCloak;
	
	bool bRageDraining;
	bool bUbercharging;
	
	float flLastSwitch;
}

enum struct ConditionData
{
	TFCond nCond;
	
	int iInflictor;
	float flDuration;
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
	
	property float flLastReset
	{
		public get()
		{
			return g_flLastReset[this.iClient];
		}
		public set(float flTime)
		{
			g_flLastReset[this.iClient] = flTime;
		}
	}
	
	property bool bIsChangingClass
	{
		public get()
		{
			return g_bIsChangingClass[this.iClient];
		}
		public set(bool bIsChangingClass)
		{
			g_bIsChangingClass[this.iClient] = bIsChangingClass;
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
	
	property ArrayList aClassData
	{
		public get()
		{
			return g_aClassData[this.iClient];
		}
		public set(ArrayList aClassData)
		{
			g_aClassData[this.iClient] = aClassData;
		}
	}
	
	public void Reset()
	{
		this.flLastClassChange = GetGameTime();
		this.flLastReset = 0.0;
		this.bHasChangedClass = false;
		this.bIsInRespawnRoom = false;
		this.nBufferedClass = TFClass_Unknown;
		g_hBufferTimer[this.iClient] = null; // bleh, need to change this sometime
		
		this.ResetClassData();
	}
	
	public void SetClass(TFClassType nClass)
	{
		this.bIsChangingClass = true;
		
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
		
		// Regenerate through VScript because that allows us not to refill health/ammo
		SetVariantString("self.Regenerate(false)");
		AcceptEntityInput(this.iClient, "RunScriptCode");
		
		// Fix hitboxes
		SetVariantString("");
		AcceptEntityInput(this.iClient, "SetCustomModel");
		
		// Retrieve ammo, charge meters and the like if we've already played the class we're switching to before
		this.ApplyClassData(nClass);
		
		if (TF2_IsPlayerInCondition(this.iClient, TFCond_MeleeOnly) || TF2_IsPlayerInCondition(this.iClient, TFCond_RestrictToMelee))
		{
			int iMelee = GetPlayerWeaponSlot(this.iClient, TFWeaponSlot_Melee);
			if (iMelee > MaxClients)
			{
				char sClassname[64];
				GetEntityClassname(iMelee, sClassname, sizeof(sClassname));
				FakeClientCommand(this.iClient, "use %s", sClassname);
			}
		}
		
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
		
		switch (g_cvHealthMode.IntValue)
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
		
		// Set final health
		SetEntProp(this.iClient, Prop_Send, "m_iHealth", Min(iFinalHealth, iMaxAllowedHealth));
		
		// Remove momentum, if the convar is disabled
		if (!g_cvKeepMomentum.BoolValue)
			TeleportEntity(this.iClient, NULL_VECTOR, NULL_VECTOR, {0.0, 0.0, 0.0});
		
		// Add a little effect, if set
		if (g_cvParticle.BoolValue)
		{
			float vecPos[3];
			GetClientAbsOrigin(this.iClient, vecPos);
			ShowParticle(TF2_GetClientTeam(this.iClient) == TFTeam_Blue ? "teleportedin_blue" : "teleportedin_red", 0.1, vecPos);
		}
		
		// Update properties
		this.flLastClassChange = GetGameTime();
		this.bHasChangedClass = true;
		this.bIsChangingClass = false;
	}
	
	public void StoreClassData(TFClassType nClass)
	{
		ClassData data;
		data.nClass = nClass;
		
		// Get client ent props
		
		// Class-specific
		switch (nClass)
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
		data.bRageDraining = GetEntProp(this.iClient, Prop_Send, "m_bRageDraining") != 0;
		
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
						data.flWeaponEnergy[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy");
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
						data.bUbercharging = !!GetEntProp(iWeapon, Prop_Send, "m_bChargeRelease");
					}
					else if (StrEqual(sClassname, "tf_weapon_raygun"))
					{
						data.flWeaponEnergy[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy");
					}
					else if (StrEqual(sClassname, "tf_weapon_charged_smg"))
					{
						data.flWeaponChargeMeter[i] = GetEntPropFloat(iWeapon, Prop_Send, "m_flMinicritCharge");
					}
					else if (StrEqual(sClassname, "tf_weapon_rocketpack") || StrEqual(sClassname, "tf_weapon_lunchbox") || StrEqual(sClassname, "tf_wearable_razorback"))
					{
						data.flWeaponCooldown[i] = GetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", i);
					}
					else if (StrEqual(sClassname, "tf_weapon_jar_gas"))
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
			this.aClassData.PushArray(data);
		}
		else
		{
			this.aClassData.SetArray(iValue, data);
		}
	}
	
	public void ApplyClassData(TFClassType nClass)
	{
		int iValue = this.aClassData.FindValue(nClass, ClassData::nClass);
		
		// Haven't played this class yet, set things that would normally transfer over to 0
		if (iValue == -1)
		{
			this.GiveDefaultAmmoForClass(nClass);
			return;
		}
		
		ClassData data;
		this.aClassData.GetArray(iValue, data);
		
		// Set client ent props
		SetEntProp(this.iClient, Prop_Send, "m_iDecapitations", data.iHeads);
		SetEntProp(this.iClient, Prop_Send, "m_iRevengeCrits", data.iRevengeCrits);
		
		SetEntPropFloat(this.iClient, Prop_Send, "m_flRageMeter", data.flRage);
		SetEntPropFloat(this.iClient, Prop_Send, "m_flHypeMeter", data.flHype);
		
		SetEntProp(this.iClient, Prop_Send, "m_bRageDraining", data.bRageDraining);
		
		if (data.iMetal >= 0)
			SetEntProp(this.iClient, Prop_Send, "m_iAmmo", data.iMetal, _, TF_AMMO_METAL);
		
		if (data.flChargeMeter >= 0.0)
			SetEntPropFloat(this.iClient, Prop_Send, "m_flChargeMeter", data.flChargeMeter);
		
		if (data.flCloak >= 0.0)
			SetEntPropFloat(this.iClient, Prop_Send, "m_flCloakMeter", data.flCloak);
		
		
		// Deal with weapons
		for (int i = TFWeaponSlot_Primary; i <= TFWeaponSlot_Melee; i++)
		{
			int iWeapon = TF2_GetItemInSlot(this.iClient, i);
			
			if (iWeapon <= MaxClients)
				continue;
			
			// Set clip size and ammo
			if (data.iClip[i] >= 0 && HasEntProp(iWeapon, Prop_Send, "m_iClip1"))
			{
				int iExpectedClip = Min(data.iClip[i], SDKCall_GetMaxClip(iWeapon));
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", iExpectedClip);
			}
			
			if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
			{
				int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
				if (iAmmoType > -1 && data.iAmmo[iAmmoType] >= 0)
				{
					int iExpectedAmmo = Min(data.iAmmo[iAmmoType], SDKCall_GetMaxAmmo(this.iClient, iAmmoType));
					SetEntProp(this.iClient, Prop_Send, "m_iAmmo", iExpectedAmmo, _, iAmmoType);
				}
			}
			
			char sClassname[32];
			GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
			
			// Apply weapon-specific charge meters
			switch (i)
			{
				case TFWeaponSlot_Primary:
				{
					if (StrEqual(sClassname, "tf_weapon_particle_cannon") || StrEqual(sClassname, "tf_weapon_drg_pomson"))
					{
						if (data.flWeaponEnergy[i] >= 0.0)
							SetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy", data.flWeaponEnergy[i]);
					}
					else
					{
						if (data.flWeaponChargeMeter[i] >= 0.0)
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
						if (data.flWeaponEnergy[i] >= 0.0)
							SetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy", data.flWeaponEnergy[i]);
					}

					else if (StrEqual(sClassname, "tf_weapon_charged_smg"))
					{
						SetEntPropFloat(iWeapon, Prop_Send, "m_flMinicritCharge", data.flWeaponChargeMeter[i]);
					}
					else if (StrEqual(sClassname, "tf_weapon_lunchbox_drink") || StrEqual(sClassname, "tf_weapon_jar") || StrEqual(sClassname, "tf_weapon_jar_milk") || StrEqual(sClassname, "tf_weapon_cleaver"))
					{
						// This apparently refreshes ammo on some weapons that don't use it (which is why the classnames are all hardcoded). cute
						if (data.flWeaponChargeTime[i] >= 0.0)
							SetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime", (data.flWeaponChargeTime[i] + GetGameTime()) - data.flLastSwitch);
					}
					else if (StrEqual(sClassname, "tf_weapon_rocketpack") || StrEqual(sClassname, "tf_weapon_lunchbox") || StrEqual(sClassname, "tf_wearable_razorback"))
					{
						if (data.flWeaponCooldown[i] >= 0.0)
							SetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", data.flWeaponCooldown[i], i);
					}
					else if (StrEqual(sClassname, "tf_weapon_jar_gas"))
					{
						if (data.flWeaponChargeMeter[i] >= 0.0)
							SetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", data.flWeaponChargeMeter[i], i);
					}
				}
				
				case TFWeaponSlot_Melee:
				{
					if (StrEqual(sClassname, "tf_weapon_knife"))
					{
						if (data.flWeaponChargeTime[i] >= 0.0)
						{
							const float flDefaultSpycicleRechargeTime = 15.0;
							
							// ??????? i don't fuckin know lol
							if ((data.flLastSwitch - data.flWeaponChargeTime[i]) < flDefaultSpycicleRechargeTime)
							{
								SetEntPropFloat(iWeapon, Prop_Send, "m_flKnifeMeltTimestamp", GetGameTime());
								SetEntPropFloat(iWeapon, Prop_Send, "m_flKnifeRegenerateDuration", flDefaultSpycicleRechargeTime - (data.flLastSwitch - data.flWeaponChargeTime[i]));
								
								data.flWeaponChargeTime[i] = GetGameTime();
							}
							else
							{
								data.flWeaponChargeTime[i] = GetGameTime() - flDefaultSpycicleRechargeTime;
							}
						}
					}
					else if (HasEntProp(iWeapon, Prop_Send, "m_flEffectBarRegenTime"))
					{
						if (data.flWeaponChargeTime[i] >= 0.0)
							SetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime", (data.flWeaponChargeTime[i] + GetGameTime()) - data.flLastSwitch);
					}
					else
					{
						if (data.flWeaponChargeMeter[i] >= 0.0)
							SetEntPropFloat(this.iClient, Prop_Send, "m_flItemChargeMeter", data.flWeaponChargeMeter[i], i);
					}
				}
			}
		}
	}
	
	public void ResetClassData(bool bOnlyNegative = false)
	{
		if (!this.aClassData)
		{
			this.aClassData = new ArrayList(sizeof(ClassData));
		}
		else
		{
			if (!bOnlyNegative)
			{
				this.aClassData.Clear();
			}
			else
			{
				float flTime = GetGameTime();
				if (this.flLastReset == flTime)
					return;
				
				this.flLastReset = flTime;
				
				ClassData data;
				int iLength = this.aClassData.Length;
				
				for (int i = 0; i < iLength; i++)
				{
					this.aClassData.GetArray(i, data);
					
					for (int iSlot = TFWeaponSlot_Primary; iSlot <= TFWeaponSlot_Melee; iSlot++)
					{
						data.iClip[iSlot] = -1;
						data.flWeaponCooldown[iSlot] = -1.0;
						data.flWeaponChargeTime[iSlot] = -1.0;
						data.flWeaponEnergy[iSlot] = -1.0;
					}
					
					for (int iSlot = TF_AMMO_DUMMY; iSlot < TF_AMMO_COUNT; iSlot++)
						data.iAmmo[iSlot] = -1;
					
					data.iMetal = -1;
					data.flCloak = -1.0;
					data.flChargeMeter = -1.0;
					
					this.aClassData.SetArray(i, data);
				}
			}
		}
	}
	
	public void GiveDefaultAmmoForClass(TFClassType nClass)
	{
		SetEntProp(this.iClient, Prop_Send, "m_iDecapitations", 0);
		SetEntProp(this.iClient, Prop_Send, "m_iRevengeCrits", 0);
		SetEntPropFloat(this.iClient, Prop_Send, "m_flRageMeter", 0.0);
		SetEntProp(this.iClient, Prop_Send, "m_bRageDraining", false);
		
		// Class-specific
		switch (nClass)
		{
			case TFClass_Scout: SetEntPropFloat(this.iClient, Prop_Send, "m_flHypeMeter", 0.0);
			case TFClass_DemoMan: SetEntPropFloat(this.iClient, Prop_Send, "m_flChargeMeter", 100.0);
			case TFClass_Engineer: SetEntProp(this.iClient, Prop_Send, "m_iAmmo", 200, _, TF_AMMO_METAL);
			case TFClass_Spy: SetEntPropFloat(this.iClient, Prop_Send, "m_flCloakMeter", 100.0);
		}
		
		for (int i = TF_AMMO_DUMMY; i < TF_AMMO_COUNT; i++)
			SetEntProp(this.iClient, Prop_Send, "m_iAmmo", SDKCall_GetMaxAmmo(this.iClient, i), _, i);
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
		if (TF2_IsPlayerInCondition(this.iClient, TFCond_RocketPack) && TF2_GetPlayerClass(this.iClient) == TFClass_Pyro)
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
		return (g_nTeamThatIsAllowedToChangeClass <= TFTeam_Spectator || g_nTeamThatIsAllowedToChangeClass == TF2_GetClientTeam(this.iClient));
	}
	
	public void Destroy()
	{
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