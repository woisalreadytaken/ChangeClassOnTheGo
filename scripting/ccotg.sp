#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>
#include <sendproxy>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION		"0.2"

bool g_bArenaMode;

Handle g_hBufferTimer[MAXPLAYERS + 1];
Handle g_hArenaCountdownTimer;

TFTeam g_nTeamThatIsAllowedToChangeClass;

char g_sClassNames[view_as<int>(TFClass_Engineer) + 1][] = {
	"random",
	"scout",
	"sniper",
	"soldier",
	"demoman",
	"medic",
	"heavyweapons",
	"pyro",
	"spy",
	"engineer"
};

ConVar g_cvEnabled;
ConVar g_cvCooldown;
ConVar g_cvOnlyAllowTeam;
ConVar g_cvKeepBuildings;
ConVar g_cvHealthMode;
ConVar g_cvHealthMaxOverheal;
ConVar g_cvPreventSwitchingDuringBadStates;
ConVar g_cvMessWithArenaRoundStates;

#include "ccotg/console.sp"
#include "ccotg/convars.sp"
#include "ccotg/events.sp"
#include "ccotg/methodmaps.sp"
#include "ccotg/sdkcalls.sp"
#include "ccotg/sdkhooks.sp"
#include "ccotg/stocks.sp"

public Plugin myinfo =
{
	name = "Change Class on the Go",
	author = "wo",
	description = "local demoknight holds m2 and can not be stopped",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/mmmwo/"
}

public void OnPluginStart()
{
	LoadTranslations("ccotg.phrases");
	
	Console_Init();
	ConVar_Init();
	Event_Init();
	SDKCall_Init();
	
	Enable();
}

public void OnMapStart()
{
	Map_Enable();
}

public void OnClientPutInServer(int iClient)
{
	Player(iClient).Reset();
}

public void OnPluginEnd()
{
	Disable();
}

public void Enable()
{
	if (!g_cvEnabled.BoolValue)
		return;
	
	// Treat in-game clients as if they're joining (resets them)
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
			OnClientPutInServer(iClient);
	}
	
	// Check if the convar for only allowing one team to switch is modified
	char sTeam[8];
	g_cvOnlyAllowTeam.GetString(sTeam, sizeof(sTeam));
	
	if (StrContains(sTeam, "red", false) != -1)
	{
		g_nTeamThatIsAllowedToChangeClass = TFTeam_Red;
	}
	else if (StrContains(sTeam, "blu", false) != -1)
	{
		g_nTeamThatIsAllowedToChangeClass = TFTeam_Blue;
	}
	else
	{
		g_nTeamThatIsAllowedToChangeClass = TFTeam_Unassigned;
	}
}

public void Map_Enable()
{
	// Check if it's arena
	if (FindEntityByClassname(-1, "tf_logic_arena") > MaxClients)
	{
		g_bArenaMode = true;
		
		// Hook arena-related stuff
		SendProxy_HookGameRules("m_iRoundState", Prop_Int, SendProxy_ArenaRoundState);
		HookEntityOutput("tf_logic_arena", "OnCapEnabled", EntityOutput_OnArenaCapEnabled);
		
		// We don't care about spawn rooms if it's arena so we stop here
		return;
	}
	else
	{
		g_bArenaMode = false;
	}
	
	// Hook spawn rooms. We don't care about them if it's arena mode
	int iEntity = MaxClients + 1;
	
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) > MaxClients)
	{
		SDKHook(iEntity, SDKHook_StartTouch, SDKHook_FuncRespawnRoom_StartTouch);
		SDKHook(iEntity, SDKHook_EndTouch, SDKHook_FuncRespawnRoom_EndTouch);
	}
}

public void Disable()
{
	// Unhook arena-related stuff
	SendProxy_UnhookGameRules("m_iRoundState", SendProxy_ArenaRoundState);
	UnhookEntityOutput("tf_logic_arena", "OnCapEnabled", EntityOutput_OnArenaCapEnabled);
	
	int iEntity = MaxClients + 1;
	
	// Unhook spawn rooms
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) > MaxClients)
	{
		SDKUnhook(iEntity, SDKHook_StartTouch, SDKHook_FuncRespawnRoom_StartTouch);
		SDKUnhook(iEntity, SDKHook_EndTouch, SDKHook_FuncRespawnRoom_EndTouch);
	}
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (!g_cvEnabled.BoolValue)
		return;
	
	if (strcmp(sClassname, "func_respawnroom") == 0)
	{
		SDKHook(iEntity, SDKHook_StartTouch, SDKHook_FuncRespawnRoom_StartTouch);
		SDKHook(iEntity, SDKHook_EndTouch, SDKHook_FuncRespawnRoom_EndTouch);
	}
}

public Action Timer_DealWithBuffer(Handle hTimer, int iClient)
{
	if (hTimer != g_hBufferTimer[iClient] || !g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!IsValidClient(iClient))
		return Plugin_Continue;
		
	TFClassType nClass = Player(iClient).nBufferedClass;
	
	// If the player has selected the class they already are, or their buffered class has already been reset, abort
	if (nClass == TF2_GetPlayerClass(iClient) || nClass <= TFClass_Unknown)
	{
		CPrintToChat(iClient, "%t", "ChangeClass_Wait_Cancelled");
		Player(iClient).nBufferedClass = TFClass_Unknown;
		
		return Plugin_Continue;
	}
	
	// If the player is no longer alive, give them whatever they had chosen as their desired class and reset their buffer
	if (!IsPlayerAlive(iClient))
	{
		SetEntProp(iClient, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(nClass));
		Player(iClient).nBufferedClass = TFClass_Unknown;
		
		return Plugin_Continue;
	}
	
	// If the player is still on cooldown, keep doing this
	if (Player(iClient).IsInCooldown(false))
	{
		g_hBufferTimer[iClient] = CreateTimer(0.1, Timer_DealWithBuffer, iClient);
		return Plugin_Continue;
	}
	
	// If the player is still in a bad state, keep doing this
	if (Player(iClient).IsInBadState(false))
	{
		g_hBufferTimer[iClient] = CreateTimer(0.1, Timer_DealWithBuffer, iClient);
		return Plugin_Continue;
	}
	
	// If we're through, they should be clear to change classes
	Player(iClient).SetClass(nClass);
	Player(iClient).nBufferedClass = TFClass_Unknown;
	
	return Plugin_Continue;
}

public Action EntityOutput_OnArenaCapEnabled(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!g_bArenaMode || !g_cvMessWithArenaRoundStates.BoolValue)
		return Plugin_Continue;
	
	// If players think they're not in the 'main' arena round state, a couple of issues happen with the control point 
	// We mitigate them here!
	
	// Unlock the control point(s?) by ourselves, so the players get the memo (if your map or gamemode is weird then I am so so sorry)
	// nvm can't find anything that works so far lol, it still works it just looks fucked up
	/*
	int iEntity = FindEntityByClassname(-1, "tf_logic_arena");
	if (iEntity > MaxClients)
	{
		GameRules_SetPropFloat("m_flCapturePointEnableTime", 0.0);
		//PrintToChatAll("%d", DispatchKeyValueFloat(iEntity, "CapEnableDelay", 0.0));
	}
	*/
	
	// Play a 'control point enabled' administrator voiceline
	EmitGameSoundToAll("Announcer.AM_CapEnabledRandom");
	
	return Plugin_Continue;
}

public Action SendProxy_ArenaRoundState(const char[] sPropName, int &iValue, int iElement, int iClient)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!g_bArenaMode || !g_cvMessWithArenaRoundStates.BoolValue)
		return Plugin_Continue;
	
	// Fool people into thinking the round is in an unused state so they can press comma to switch classes in arena
	if (iValue == view_as<int>(RoundState_Stalemate))
	{
		iValue = view_as<int>(RoundState_RoundRunning);
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
	