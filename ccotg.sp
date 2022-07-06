#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf_econ_data>
#include <morecolors>

#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#define REQUIRE_EXTENSIONS

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION		"0.1"

enum
{
	LoadoutSlot_Primary = 0,
	LoadoutSlot_Secondary,
	LoadoutSlot_Melee,
	LoadoutSlot_Utility,
	LoadoutSlot_Building,
	LoadoutSlot_PDA,
	LoadoutSlot_PDA2,
	LoadoutSlot_Head,
	LoadoutSlot_Misc,
	LoadoutSlot_Action,
	LoadoutSlot_Misc2
};

bool g_bArenaMode;
bool g_bTF2Items;

Handle g_hAnnouncementTimer;
Handle g_hBufferTimer[MAXPLAYERS + 1];

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
ConVar g_cvAnnouncementTimer;
ConVar g_cvCooldown;
ConVar g_cvDisableCosmetics;
ConVar g_cvOnlyAllowTeam;
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
	description = "local demoknight holds m2 and can not be stopped",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/mmmwo/"
}

public void OnPluginStart()
{
	g_bTF2Items = LibraryExists("TF2Items");
	
	Console_Init();
	ConVar_Init();
	Event_Init();
	SDKCall_Init();
	
	Enable();
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
		
	if (g_cvAnnouncementTimer.FloatValue > 0.0)
	{
		CreateTimer(0.0, Timer_MainAnnouncement); // In case the plugin was loaded mid-game, display a message immediately
		g_hAnnouncementTimer = CreateTimer(g_cvAnnouncementTimer.FloatValue, Timer_MainAnnouncement, _, TIMER_REPEAT);
	}
	
	// More stuff for late loads
	bool bLate = false;
	
	// Treat in-game clients as if they're joining (resets them)
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			OnClientPutInServer(iClient);
			bLate = true;
		}
	}
	
	if (!bLate)
		return;
	
	// Check if it's arena
	if (FindEntityByClassname(-1, "tf_logic_arena") > MaxClients)
	{
		g_bArenaMode = true;
	}
	else
	{
		g_bArenaMode = false;
	}
	
	int iEntity = MaxClients + 1;
	
	// Hook spawn rooms
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) > MaxClients)
	{
		SDKHook(iEntity, SDKHook_StartTouch, SDKHook_FuncRespawnRoom_StartTouch);
		SDKHook(iEntity, SDKHook_EndTouch, SDKHook_FuncRespawnRoom_EndTouch);
	}	
}

public void Disable()
{
	// Ideally we'd want to remove gunslinger viewmodels from snipers, but that still risks crashing the server (and client) if done mid-game lol!
	// ...so that won't be done. They'll be stuck with it until they rejoin or the map changes
	
	int iEntity = MaxClients + 1;
	
	// Unhook spawn rooms
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) > MaxClients)
	{
		SDKUnhook(iEntity, SDKHook_StartTouch, SDKHook_FuncRespawnRoom_StartTouch);
		SDKUnhook(iEntity, SDKHook_EndTouch, SDKHook_FuncRespawnRoom_EndTouch);
	}
	
	delete g_hAnnouncementTimer;
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (!g_cvEnabled.BoolValue)
		return;
	
	if (strcmp(sClassname, "tf_logic_arena") == 0)
	{
		g_bArenaMode = true;
	}
	else if (strcmp(sClassname, "func_respawnroom") == 0)
	{
		SDKHook(iEntity, SDKHook_StartTouch, SDKHook_FuncRespawnRoom_StartTouch);
		SDKHook(iEntity, SDKHook_EndTouch, SDKHook_FuncRespawnRoom_EndTouch);
	}
}
	
public Action TF2Items_OnGiveNamedItem(int iClient, char[] sClassname, int iIndex, Handle &hItem)
{
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
		
	if (!g_cvDisableCosmetics.BoolValue)
		return Plugin_Continue;
	
	// This is only used to block cosmetics, so we don't really care about class-specific slots
	int iSlot = TF2Econ_GetItemDefaultLoadoutSlot(iIndex);
	
	// I'm pretty sure only LoadoutSlot_Misc is used for cosmetics, but just in case
	if (iSlot == LoadoutSlot_Misc ||
		iSlot == LoadoutSlot_Misc2 ||
		iSlot == LoadoutSlot_Head)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Timer_MainAnnouncement(Handle hTimer)
{
	CPrintToChatAll("{olive}Change Class on the Go is active! You are free to change classes without respawning wherever you want.");
	
	return Plugin_Continue;
}

public Action Timer_DealWithBuffer(Handle hTimer, int iClient)
{
	if (hTimer != g_hBufferTimer[iClient] || !g_cvEnabled.BoolValue)
		return Plugin_Continue;
	
	if (!IsValidClient(iClient))
		return Plugin_Continue;
		
	TFClassType nClass = Player(iClient).nBufferedClass;
	
	// If the player has selected the class they already are, reset their buffer
	if (nClass == TF2_GetPlayerClass(iClient))
	{
		CPrintToChat(iClient, "{green}You will no longer switch classes.");
		
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
	}
	// If not, they should be clear to change classes
	else
	{
		Player(iClient).SetClass(nClass);
		
		// ...and reset their stuff
		Player(iClient).nBufferedClass = TFClass_Unknown;
	}
	
	return Plugin_Continue;
}
	