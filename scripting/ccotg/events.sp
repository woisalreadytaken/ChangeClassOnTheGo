#pragma semicolon 1
#pragma newdecls required

void Event_Init()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("teamplay_round_start", Event_RoundStart);
}

void Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return;
		
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidClient(iClient) || TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	// Reset the player's buffered class
	Player(iClient).nBufferedClass = TFClass_Unknown;
	
	// Reset the player's class data
	Player(iClient).ResetClassData(false);
	
	// If the player hasn't switched classes yet, nag them on each spawn until they do
	if (!Player(iClient).bHasChangedClass && Player(iClient).CanTeamChangeClass())
		PrintCenterText(iClient, "%t", "ChangeClass_Main_Hint");
	
	// Make sure to add any stray buildings back to the engineer on respawn, so he can't build multiple
	if (TF2_GetPlayerClass(iClient) == TFClass_Engineer && g_cvKeepBuildings.BoolValue)
	{
		int iBuilding = MaxClients + 1;
		while ((iBuilding = FindEntityByClassname(iBuilding, "obj_*")) > MaxClients)
		{
			if (GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder") == iClient)
				SDKCall_AddObject(iClient, iBuilding);
		}
	}
}

void Event_PostInventoryApplication(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return;
		
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidClient(iClient) || TF2_GetClientTeam(iClient) <= TFTeam_Spectator)
		return;
	
	if (Player(iClient).bIsChangingClass)
		return;
	
	Player(iClient).ResetClassData(true);
}

void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return;
	
	if (!g_bArenaMode)
		return;
		
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			// If it's arena mode, let players know they can open the class select menu with a different key
			if (!Player(iClient).bHasChangedClass && Player(iClient).CanTeamChangeClass())
			{
				CPrintToChat(iClient, "%t", "ChangeClass_Arena_Hint");
				PrintKeyHintText(iClient, "%t", "ChangeClass_Arena_Controls");
			}
		}
	}
}