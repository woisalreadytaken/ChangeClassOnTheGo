#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"0.5"

bool g_bArenaMode;
Handle g_hBufferTimer[MAXPLAYERS + 1];
TFTeam g_nTeamThatIsAllowedToChangeClass;

char g_sClassNames[][] = {
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

enum
{
	TF_AMMO_DUMMY = 0,
	TF_AMMO_PRIMARY,	//General primary weapon ammo
	TF_AMMO_SECONDARY,	//General secondary weapon ammo
	TF_AMMO_METAL,		//Engineer's metal
	TF_AMMO_GRENADES1,	//Weapon misc ammo 1
	TF_AMMO_GRENADES2,	//Weapon misc ammo 2
	TF_AMMO_GRENADES3,
	
	TF_AMMO_COUNT
}

ConVar g_cvEnabled;
ConVar g_cvCooldown;
ConVar g_cvParticle;
ConVar g_cvOnlyAllowTeam;
ConVar g_cvKeepBuildings;
ConVar g_cvKeepMomentum;
ConVar g_cvHealthMode;
ConVar g_cvHealthMaxOverheal;
ConVar g_cvPreventSwitchingDuringBadStates;

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
	description = "Allows players to change classes and not die out of spawn.",
	version = PLUGIN_VERSION,
	url = "https://github.com/woisalreadytaken/ChangeClassOnTheGo"
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

public void OnClientDisconnect(int iClient)
{
	Player(iClient).Destroy();
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
	if (FindEntityByClassname(-1, "tf_logic_arena") > MaxClients)
	{
		g_bArenaMode = true;
		
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
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
			OnClientDisconnect(iClient);
	}
	
	int iEntity = MaxClients + 1;
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

public Action Timer_DealWithBuffer(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!IsValidClient(iClient))
		return Plugin_Stop;
	
	if (hTimer != g_hBufferTimer[iClient] || !g_cvEnabled.BoolValue)
		return Plugin_Stop;
	
	TFClassType nClass = Player(iClient).nBufferedClass;
	
	// If the player has selected the class they already are, or their buffered class has already been reset, abort
	if (nClass == TF2_GetPlayerClass(iClient) || nClass <= TFClass_Unknown)
	{
		CPrintToChat(iClient, "%t", "ChangeClass_Wait_Cancelled");
		Player(iClient).nBufferedClass = TFClass_Unknown;
		
		return Plugin_Stop;
	}
	
	// If the player is no longer alive, give them whatever they had chosen as their desired class and reset their buffer
	if (!IsPlayerAlive(iClient))
	{
		SetEntProp(iClient, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(nClass));
		Player(iClient).nBufferedClass = TFClass_Unknown;
		
		return Plugin_Stop;
	}
	
	// If the player is still on cooldown, keep doing this
	if (Player(iClient).IsInCooldown(false))
		return Plugin_Continue;
	
	// If the player is still in a bad state, keep doing this
	if (Player(iClient).IsInBadState(false))
		return Plugin_Continue;
	
	// If we're through, they should be clear to change classes
	Player(iClient).SetClass(nClass);
	Player(iClient).nBufferedClass = TFClass_Unknown;
	
	return Plugin_Stop;
}