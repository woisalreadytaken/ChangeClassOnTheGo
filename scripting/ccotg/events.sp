#pragma semicolon 1
#pragma newdecls required

void Event_Init()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("arena_round_start", Event_ArenaRoundStart);
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
	
	if (!g_bArenaMode || g_cvMessWithArenaRoundStates.BoolValue)
		return;
		
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			// If it's arena mode and we're not messing with round states, let players know they can open the class select menu... with a different key...
			if (!Player(iClient).bHasChangedClass && Player(iClient).CanTeamChangeClass())
			{
				CPrintToChat(iClient, "%t", "ChangeClass_Arena_Hint");
				PrintKeyHintText(iClient, "%t", "ChangeClass_Arena_Controls");
			}
		}
	}
}

void Event_ArenaRoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return;
	
	if (!g_bArenaMode || !g_cvMessWithArenaRoundStates.BoolValue)
		return;
	
	// If round states are being messed with, there'll be no 'cap enabled' countdown, so we have to handle it by ourselves
	int iEntity = FindEntityByClassname(-1, "tf_logic_arena");
	if (iEntity > MaxClients)
	{
		float flTime = GameRules_GetPropFloat("m_flCapturePointEnableTime") - GetGameTime();
		
		if (flTime > 5.0)
			g_hArenaCountdownTimer = CreateTimer(flTime - 5.0, Timer_CapEnabledCountdown, 5);
	}
}

void Event_RoundEnd(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return;
	
	if (!g_bArenaMode || !g_cvMessWithArenaRoundStates.BoolValue)
		return;
		
	// Cancel the countdown once the round ends, if it's still active
	delete g_hArenaCountdownTimer;
}

void Timer_CapEnabledCountdown(Handle hTimer, int iValue)
{
	if (!g_cvEnabled.BoolValue)
		return;
	
	if (!g_bArenaMode || !g_cvMessWithArenaRoundStates.BoolValue)
		return;
	
	char sSound[64];
	Format(sSound, sizeof(sSound), "Announcer.RoundBegins%dSeconds", iValue);
	EmitGameSoundToAll(sSound);
	iValue--;
	
	// Keep counting down every second
	if (iValue > 0)
	{
		g_hArenaCountdownTimer = CreateTimer(1.0, Timer_CapEnabledCountdown, iValue);
	}
	else
	{
		g_hArenaCountdownTimer = null;
	}
}