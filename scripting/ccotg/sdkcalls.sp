#pragma semicolon 1
#pragma newdecls required

static Handle g_hSDKCallGetMaxHealth;
static Handle g_hSDKCallAddObject;
static Handle g_hSDKCallRemoveObject;
static Handle g_hSDKCallGetEquippedWearableForLoadoutSlot;
static Handle g_hSDKCallGetMaxClip;
static Handle g_hSDKCallGetMaxAmmo;

void SDKCall_Init()
{
	GameData hGameData = new GameData("sdkhooks.games");
	if (hGameData == null)
		SetFailState("Could not find sdkhooks.games gamedata!"); 

	// This call is used to retrieve a player's max health
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCallGetMaxHealth = EndPrepSDKCall();
	if (g_hSDKCallGetMaxHealth == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxHealth!");
	
	delete hGameData;
	
	hGameData = new GameData("ccotg");
	if (hGameData == null)
		SetFailState("Could not find ccotg gamedata!"); 
	
	// This call is used to give an owner to a building
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::AddObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallAddObject = EndPrepSDKCall();
	if (g_hSDKCallAddObject == null)
		LogMessage("Failed to create call: CTFPlayer::AddObject!");
	
	// This call is used to remove a building's owner
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::RemoveObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallRemoveObject = EndPrepSDKCall();
	if (g_hSDKCallRemoveObject == null)
		LogMessage("Failed to create call: CTFPlayer::RemoveObject!");
	
	// This call is used to correctly get wearables from a loadout slot
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallGetEquippedWearableForLoadoutSlot = EndPrepSDKCall();
	if (g_hSDKCallGetEquippedWearableForLoadoutSlot == null)
		LogMessage("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot");
	
	// This call is used to get the maximum clip 1 for a given weapon
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTFWeaponBase::GetMaxClip1");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCallGetMaxClip = EndPrepSDKCall();
	if (g_hSDKCallGetMaxClip == null)
		LogMessage("Failed to create call: CTFWeaponBase::GetMaxClip1!");
	
	// This call is used to get a weapon's max ammo
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCallGetMaxAmmo = EndPrepSDKCall();
	if (g_hSDKCallGetMaxAmmo == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo!");
	
	delete hGameData;
}

int SDKCall_GetMaxHealth(int iClient)
{
	if (g_hSDKCallGetMaxHealth != null)
		return SDKCall(g_hSDKCallGetMaxHealth, iClient);
	
	return 0;
}

void SDKCall_AddObject(int iClient, int iEntity)
{
	if (g_hSDKCallAddObject != null)
		SDKCall(g_hSDKCallAddObject, iClient, iEntity);
}

void SDKCall_RemoveObject(int iClient, int iEntity)
{
	if (g_hSDKCallRemoveObject != null)
		SDKCall(g_hSDKCallRemoveObject, iClient, iEntity);
}

int SDKCall_GetEquippedWearableForLoadoutSlot(int iClient, int iSlot)
{
	if (g_hSDKCallGetEquippedWearableForLoadoutSlot != null)
		return SDKCall(g_hSDKCallGetEquippedWearableForLoadoutSlot, iClient, iSlot);
	
	return -1;
}

int SDKCall_GetMaxClip(int iWeapon)
{
	if (g_hSDKCallGetMaxClip != null)
		return SDKCall(g_hSDKCallGetMaxClip, iWeapon);
	
	return -1;
}

int SDKCall_GetMaxAmmo(int iClient, int iSlot)
{
	if (g_hSDKCallGetMaxAmmo != null)
		return SDKCall(g_hSDKCallGetMaxAmmo, iClient, iSlot, -1);
	
	return -1;
}