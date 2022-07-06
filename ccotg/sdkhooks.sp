public Action SDKHook_FuncRespawnRoom_StartTouch(int iEntity, int iClient)
{
	if (g_bArenaMode)
		return Plugin_Continue;
	
	if (IsValidClient(iClient) && GetClientTeam(iClient) == GetEntProp(iEntity, Prop_Send, "m_iTeamNum"))
		Player(iClient).bIsInRespawnRoom = true;
	
	return Plugin_Continue;
}

public Action SDKHook_FuncRespawnRoom_EndTouch(int iEntity, int iClient)
{
	if (g_bArenaMode)
		return Plugin_Continue;
	
	if (IsValidClient(iClient) && GetClientTeam(iClient) == GetEntProp(iEntity, Prop_Send, "m_iTeamNum"))
		Player(iClient).bIsInRespawnRoom = false;
	
	return Plugin_Continue;
}