void Event_Init()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
		
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidClient(iClient) || TF2_GetClientTeam(iClient) <= TFTeam_Spectator || TF2_GetPlayerClass(iClient) == TFClass_Sniper || !Player(iClient).bHasRobotArm)
		return Plugin_Continue;
	
	// Remove gunslinger viewmodels given by the plugin if they spawn with it... and are not a Sniper
	// Doing it this way fucks up animations for other classes if they die as sniper then switch while dead, but that's the only way I could find so far that doesn't have a server-crashing side effect
	TF2Attrib_RemoveByName(iClient, "mod wrench builds minisentry");
	Player(iClient).bHasRobotArm = false;
	
	for (int i = TFWeaponSlot_Primary; i <= TFWeaponSlot_Melee; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, i);
		if (iWeapon > MaxClients)
		{
			SetEntityRenderMode(iWeapon, RENDER_TRANSCOLOR);
			SetEntityRenderColor(iWeapon, _, _, _, 255);
		}
	}
	
	return Plugin_Continue;
}