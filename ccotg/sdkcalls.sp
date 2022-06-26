static Handle g_hSDKCallGetMaxHealth;

void SDKCall_Init()
{
	GameData hGameData = new GameData("sdkhooks.games");
	if (hGameData == null)
		SetFailState("Could not find sdkhooks.games gamedata!"); 

	// This function is used to retrieve a player's max health
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCallGetMaxHealth = EndPrepSDKCall();
	if (g_hSDKCallGetMaxHealth == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxHealth!");
	
	delete hGameData;
}

int SDKCall_GetMaxHealth(int iClient)
{
	if (g_hSDKCallGetMaxHealth != null)
		return SDKCall(g_hSDKCallGetMaxHealth, iClient);
	
	return 0;
}