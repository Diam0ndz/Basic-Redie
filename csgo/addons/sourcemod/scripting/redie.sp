#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Diam0ndzx" //With Help from Extacy
#define PLUGIN_VERSION "1.2"
#define MAX_BUTTONS 25

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <autoexecconfig>

#pragma newdecls required

EngineVersion g_Game;

ConVar enabled;
ConVar isAutohopServer;
ConVar autoHop;
ConVar damageRespawns;
ConVar teleportsEnabled;
ConVar triggersEnabled;
ConVar rotationsEnabled;
ConVar trainsEnabled;

bool isInRedie[MAXPLAYERS + 1];
bool canRedie[MAXPLAYERS + 1];

bool isInNoclip[MAXPLAYERS + 1];
bool isBhop[MAXPLAYERS + 1];

int lastButton[MAXPLAYERS + 1];

int lastUsedCommand[MAXPLAYERS + 1];
int cooldownTimer = 5;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
   CreateNative("Redie_IsInRedie", Native_IsInRedie);
   return APLRes_Success;
}

public int Native_IsInRedie(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	return isInRedie[client];
}

public Plugin myinfo = 
{
	name = "Basic Redie",
	author = PLUGIN_AUTHOR,
	description = "Just another ol' redie plugin",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/Diam0ndz/"
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
    
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("redie");
	enabled = CreateConVar("sm_enableredie", "1", "Sets whether redie is enabled or not", _, true, 0.0, true, 1.0);
	isAutohopServer = CreateConVar("sm_redieautohopserver", "0", "Set if the server has autohop enabled by default", FCVAR_HIDDEN, true, 0.0, true, 1.0);
	autoHop = FindConVar("sv_autobunnyhopping");
	damageRespawns = CreateConVar("sm_rediedamagerespawns", "0", "Set if getting damages in redie respawns you or not", _, true, 0.0, true, 1.0);
	teleportsEnabled = CreateConVar("sm_redieteleports", "0", "Set if teleports are enabled while in redie", _, true, 0.0, true, 1.0);
	triggersEnabled = CreateConVar("sm_redietriggers", "0", "Set if triggers are enabled while in redie", _, true, 0.0, true, 1.0);
	trainsEnabled = CreateConVar("sm_redietrains", "0", "Set if trains(tanktrains) are enabled while in redie", _, true, 0.0, true, 1.0);
	rotationsEnabled = CreateConVar("sm_redierotations", "0", "Set if func_rotatings are enabled while in redie", _, true, 0.0, true, 1.0);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	RegConsoleCmd("sm_redie", Command_Redie, "Become a ghost");
	RegConsoleCmd("sm_unredie", Command_Unredie, "Get out of becoming a ghost");
	RegConsoleCmd("sm_die", Command_Unredie, "Alias for sm_unredie");
	RegConsoleCmd("sm_isredie", Command_IsRedie, "Lists players in redie", ADMFLAG_BAN);
	RegConsoleCmd("sm_rmenu", Menu_RedieMenu, "If you are in redie, it opens the redie menu");
	
	
	HookEvent("player_death", Event_PrePlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start", Event_PreRoundStart, EventHookMode_Pre);
	//HookEvent("round_end", Event_PostRoundEnd, EventHookMode_Post);
	
	autoHop.AddChangeHook(Hook_AutoHop);
	
	AddNormalSoundHook(OnNormalSoundPlayed);
	
	AddCommandListener(Command_JoinTeam, "jointeam");
	AddCommandListener(Command_OnSay, "say");
	AddCommandListener(Command_OnSay, "say_team");
	
	HookEntityOutput("func_door", "OnBlockedOpening", EntityOutput_DoorBlocked);
	HookEntityOutput("func_door", "OnBlockedClosing", EntityOutput_DoorBlocked);
	HookEntityOutput("func_door_rotating", "OnBlockedOpening", EntityOutput_DoorBlocked);
	HookEntityOutput("func_door_rotating", "OnBlockedClosing", EntityOutput_DoorBlocked);
	//HookEntityOutput("func_button", "OnPressed", EntityOutPut_ButtonPressed);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse);
}

public void OnClientPostAdminCheck(int client)
{
	isInRedie[client] = false; //You can't be in redie the moment you join
	lastUsedCommand[client] = 0; 
}

public void OnClientDisconnect_Pos(int client)
{
	lastButton[client] = 0;
}

public Action Event_PrePlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(isInRedie[client])
	{
		isInRedie[client] = false;
		if(!isAutohopServer.BoolValue)
		{
			SendConVarValue(client, autoHop, "0");
		}
		return Plugin_Handled; //Prevent things that would happen after normal players would die. 
	}else
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Type '!redie' to become a ghost!");
		return Plugin_Continue;
	}
}

public Action Event_PreRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int ent = MaxClients + 1;
	while((ent = FindEntityByClassname(ent, "func_door")) != -1)
	{
		SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
	}
	if(!rotationsEnabled.BoolValue)
	{
		ent = MaxClients + 1;
		while((ent = FindEntityByClassname(ent, "func_rotating")) != -1)
		{
			SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
		}
	}
	ent = MaxClients + 1;
	while((ent = FindEntityByClassname(ent, "func_breakable")) != -1)
	{
		SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
	}
	if(!trainsEnabled.BoolValue)
	{
		ent = MaxClients + 1;
		while((ent = FindEntityByClassname(ent, "func_tanktrain")) != -1)
		{
			SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
		}
		ent = MaxClients + 1;
		while((ent = FindEntityByClassname(ent, "func_tracktrain")) != -1)
		{
			SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
		}
	}
	ent = MaxClients + 1; //ent is already defined, so we are changing/updating it
	while((ent = FindEntityByClassname(ent, "func_button")) != -1)
	{
		SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
	}
	if(!triggersEnabled.BoolValue)
	{
		ent = MaxClients + 1; //ent is already defined, so we are changing/updating it
		while((ent = FindEntityByClassname(ent, "trigger_once")) != -1)
		{
			SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
		}
		ent = MaxClients + 1; //ent is already defined, so we are changing/updating it
		while((ent = FindEntityByClassname(ent, "trigger_multiple")) != -1)
		{
			SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
		}
	}
	if(!teleportsEnabled.BoolValue)
	{
		ent = MaxClients + 1; //ent is already defined, so we are changing/updating it
		while((ent = FindEntityByClassname(ent, "trigger_teleport")) != -1)
		{
			SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
			SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
		}
	}
	ent = MaxClients + 1;
	while((ent = FindEntityByClassname(ent, "trigger_hurt")) != -1)
	{
		if(damageRespawns.BoolValue)
		{
			if(GetEntPropFloat(ent, Prop_Data, "m_flDamage") > 0)
			{
				//SDKHookEx(ent, SDKHook_EndTouch, HurtCollisionCheck);
				//SDKHookEx(ent, SDKHook_StartTouch, HurtCollisionCheck);
				SDKHookEx(ent, SDKHook_Touch, HurtCollisionCheck);
			}
		}
	}
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			SDKHook(i, SDKHook_TraceAttack, TraceAttack);
		}
	}
	for(int i = 1; i < MaxClients; i++)
	{
		//Unredie(i); //Make sure all players are not in redie for round start
		//CS_RespawnPlayer(i);
		canRedie[i] = true;
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	SDKHook(client, SDKHook_SetTransmit, SetTransmit);
	if(IsValidClient(client))
	{
		if(isInRedie[client])
		{
			isInRedie[client] = false;
			if(!isAutohopServer.BoolValue)
			{
				SendConVarValue(client, autoHop, "0");
			}
		}
		if(isAutohopServer.BoolValue)
		{
			SendConVarValue(client, autoHop, "1");
		}
		else
		{
			SendConVarValue(client, autoHop, "0");
		}
	}
}

public Action Event_PostRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i < MaxClients; i++)
	{
		canRedie[i] = false;
		Unredie(i); //Make sure all players are not in redie for round end
	}
}

public Action TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if(IsValidEntity(victim))
	{
		if(isInRedie[victim])
		{
			return Plugin_Handled; //Prevent players on redie from taking damage
		}
	}
	return Plugin_Continue;
}

public Action Command_JoinTeam(int client, const char[] command, int argc)
{
	if(!IsValidClient(client)) return Plugin_Stop;
	
	if(isInRedie[client])
	{
		Unredie(client);
		PrintToChat(client, " \x01[\x03Redie\x01] \x04You were taken out of redie because you tried to switch teams.");
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Command_OnSay(int client, const char[] command, int args)
{
	char message[200];
	GetCmdArgString(message, sizeof(message));
	
	if(
		(strcmp(message, "\"!redie\"", false) == 0) ||
		(strcmp(message, "\"!unredie\"", false) == 0) ||
		(strcmp(message, "\"!isredie\"", false) == 0) ||
		(strcmp(message, "\"!rmenu\"", false) == 0)
		)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Command_Redie(int client, int args)
{
	if(!enabled.BoolValue)
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Redie is currently disabled!");
		return Plugin_Handled;
	}
	if(IsValidClient(client))
	{
		if(canRedie[client])
		{
			if(!IsPlayerAlive(client))
			{
				int time = GetTime();
				if(time - lastUsedCommand[client] < cooldownTimer)
				{
					PrintToChat(client, " \x01[\x03Redie\x01] \x04You are using commands too fast! Please wait before using the command again.");
					return Plugin_Handled;
				}else
				{
					lastUsedCommand[client] = time;
					Redie(client, false);
					return Plugin_Handled;
				}
			}else
			{
				PrintToChat(client, " \x01[\x03Redie\x01] \x04You must be dead in order to become a ghost!");
				return Plugin_Handled;
			}
		}else
		{
			PrintToChat(client, " \x01[\x03Redie\x01] \x04Wait for a new round to start!");
			return Plugin_Handled;
		}
	}else
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04You must be a valid client to use this command!");
		return Plugin_Handled;
	}
}

public void Redie(int client, bool fromDamage)
{
	isInRedie[client] = false; 
	CS_RespawnPlayer(client);
	isInRedie[client] = true; 
	int weaponIndex;
	for (int i = 0; i <= 3; i++)
	{
		if ((weaponIndex = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, weaponIndex);
			RemoveEdict(weaponIndex); //Remove any weapons the player could have had (Shouldn't happen because you must be dead to use the command!)
		}
	}
	SetEntProp(client, Prop_Send, "m_lifeState", 1); //Make the server think we are dead
	SetEntData(client, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), 2, 4, true); //No collisions with other players
	SetEntProp(client, Prop_Data, "m_ArmorValue", 0); //Make sure we dont have armor
	SetEntProp(client, Prop_Send, "m_bHasDefuser", 0); //Make sure we dont have a kit
	isBhop[client] = true;
	isInNoclip[client] = false;
	SendConVarValue(client, autoHop, "1");
	if(!fromDamage)
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04You are now a ghost!");
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Hold your \x0Freload \x04key(Default: 'r') to gain \x0Fnoclip \x04temporarily!");
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Type '!unredie' to stop being a ghost.");
	}
	Menu_RedieMenu(client, 1);
}

public void Hook_AutoHop(ConVar convar, char[] oldVal, char[] newVal)
{
	if(StringToInt(newVal) > 0)
	{
		SetConVarBool(isAutohopServer, true);
	} else
	{
		SetConVarBool(isAutohopServer, false);
	}
}

public Action Command_Unredie(int client, int args)
{
	if(!enabled.BoolValue)
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Redie is currently disabled!");
		return Plugin_Handled;
	}else
		{
		if(IsValidClient(client))
		{
			if(isInRedie[client])
			{
				int time = GetTime();
				if(time - lastUsedCommand[client] < cooldownTimer)
				{
					PrintToChat(client, " \x01[\x03Redie\x01] \x04You are using commands too fast! Please wait before using the command again.");
					return Plugin_Handled;
				}else
				{
					lastUsedCommand[client] = time;
					Unredie(client);
					return Plugin_Handled;
				}
			}else
			{
				PrintToChat(client, " \x01[\x03Redie\x01] \x04You must already be a ghost to get out of it!");
				return Plugin_Handled;
			}
		}else
		{
			PrintToChat(client, " \x01[\x03Redie\x01] \x04You must be a valid client to use this command!");
			return Plugin_Handled;
		}
	}
}

public void Unredie(int client)
{
	SetEntProp(client, Prop_Send, "m_lifeState", 0); 
	ForcePlayerSuicide(client); 
	isInRedie[client] = false; 
	isBhop[client] = false;
	if(!isAutohopServer.BoolValue)
	{
		SendConVarValue(client, autoHop, "0");
	}
	PrintToChat(client, " \x01[\x03Redie\x01] \x04You are no longer a ghost!");
}

public Action Command_IsRedie(int client, int args)
{
	if(!enabled.BoolValue)
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Redie is currently disabled!");
		return Plugin_Handled;
	}
	PrintToChat(client, " \x01[\x03Redie\x01] \x04List of players in redie:");
	for (int i = 0; i <= MAXPLAYERS + 1; i++)
	{
		if(IsValidClient(i))
		{
			if (isInRedie[i])
			{
				char clientName[64] = "";
				GetClientName(i, clientName, sizeof(clientName));
				PrintToChat(client, " \x03 %s", clientName);
			}
		}
	}
	return Plugin_Handled;
}

public Action CollisionCheck(int entity, int other)
{
	if
	(
		(0 < other && other <= MaxClients) &&
		(isInRedie[other]) &&
		(IsClientInGame(other))
	)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action HurtCollisionCheck(int entity, int other)
{
	if((0 < other && other <= MaxClients) && (isInRedie[other]) && (IsClientInGame(other)))
	{
		Redie(other, true);
		PrintToChat(other, " \x01[\x03Redie\x01] \x04You have been respawned due to taking damage");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(IsValidClient(client))
	{
		if(isInRedie[client])
		{
			if(isBhop[client])
			{
				if(buttons & IN_JUMP)
				{
					if(GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1 && !(GetEntityMoveType(client) & MOVETYPE_LADDER) && !(GetEntityFlags(client) & FL_ONGROUND))
					{
						SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
						buttons &= ~IN_JUMP;
					}
				}
				SendConVarValue(client, autoHop, "1");
			}
			if(buttons & IN_USE)
			{
				if(!(lastButton[client] & IN_USE))
				{
					return Plugin_Handled;
				}
			}else if(lastButton[client] & IN_USE)
			{
				return Plugin_Continue;
			}
			else if(buttons & IN_RELOAD)
			{
				if(!(lastButton[client] & IN_RELOAD))
				{
					SetEntityMoveType(client, MOVETYPE_NOCLIP);
					isInNoclip[client] = true;
				}
			}else if(lastButton[client] & IN_RELOAD)
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
				isInNoclip[client] = false;
			}
		}else if(autoHop.BoolValue)
		{
			//SendConVarValue(client, FindConVar("sv_autobunnyhopping"), "1");
		}else
		{
			//SendConVarValue(client, FindConVar("sv_autobunnyhopping"), "0");
		}
		lastButton[client] = buttons;
		return Plugin_Continue;
	}else
	{
		return Plugin_Handled;
	}
}

public Action WeaponCanUse(int client, int weapon)
{
	if(isInRedie[client])
	{
		return Plugin_Handled; //If a player in redie used a weapon, null it.
	}else
	{
		return Plugin_Continue;
	}
}

public Action SetTransmit(int entity, int client)
{
	if(IsValidClient(entity))
	{
		if(isInRedie[entity] && entity != client)
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action OnNormalSoundPlayed(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if(IsValidClient(entity))
	{
		if(entity && entity <= MaxClients && isInRedie[entity])
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public void EntityOutput_DoorBlocked(const char[] output, int caller, int activator, float delay)
{
	if(activator > 0 && activator < MAXPLAYERS)
	{
		if(isInRedie[activator])
		{
			PrintToChat(activator, "\x01[\x03Redie\x01] \x04You were respawned because you were blocking a door!");
			Redie(activator, true);
		}
	}
}

stock bool IsValidClient(int client) //Checks for making sure we are a valid client
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	if (IsFakeClient(client)) return false;
	if (IsClientSourceTV(client))return false;
	return IsClientInGame(client);
}

public int RedieMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(isInRedie[param1])
			{
				char info[32];
				menu.GetItem(param2, info, sizeof(info));
				if(StrEqual(info, "Noclip"))
				{
					PrintToChat(param1, " \x01[\x03Redie\x01] \x04Noclip toggled.");
					if(isInNoclip[param1])
					{
						SetEntityMoveType(param1, MOVETYPE_WALK);
						isInNoclip[param1] = false;
					}
					else if(!isInNoclip[param1])
					{
						SetEntityMoveType(param1, MOVETYPE_NOCLIP);
						isInNoclip[param1] = true;
					}
					Menu_RedieMenu(param1, 1);
				}
				else if(StrEqual(info, "Bhop"))
				{
					PrintToChat(param1, " \x01[\x03Redie\x01] \x04Bhop toggled.");
					if(isBhop[param1])
					{
						isBhop[param1] = false;
						SendConVarValue(param1, autoHop, "0");
					}
					else if(!isBhop[param1])
					{
						isBhop[param1] = true;
						SendConVarValue(param1, autoHop, "1");
					}
					Menu_RedieMenu(param1, 1);
				}
				else if(StrEqual(info, "Teleport"))
				{
					if(isInRedie[param1])
					{
						Menu_RedieTeleport(param1, 1);
					}
				}
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action Menu_RedieMenu(int client, int args)
{
	if(isInRedie[client])
	{
		Menu redieMenu = new Menu(RedieMenuHandler, MenuAction_Select);
		redieMenu.SetTitle("Redie Menu");
		redieMenu.AddItem("blank", "Type !rmenu to get this", ITEMDRAW_DISABLED);
		redieMenu.AddItem("blank", "menu back at any time", ITEMDRAW_DISABLED);
		redieMenu.AddItem("Teleport", "Teleport");
		if(!isInNoclip[client])
		{
			redieMenu.AddItem("Noclip", "Noclip[X]");
		}else
		{
			redieMenu.AddItem("Noclip", "Noclip[✓]");
		}
		
		/*if(!autoHop.BoolValue)
		{
			if(!isBhop[client])
			{
				redieMenu.AddItem("Bhop", "Bhop[X]");
			} else
			{
				redieMenu.AddItem("Bhop", "Bhop[✓]");
			}
		}*/
		redieMenu.Display(client, MENU_TIME_FOREVER);
		
		return Plugin_Handled;
	}else
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04You must be in redie to access the redie menu.");
		return Plugin_Handled;
	}
}

public int TeleportMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(isInRedie[param1])
			{
				char clientid2[64];
				menu.GetItem(param2, clientid2, sizeof(clientid2));
				int clientid3 = StringToInt(clientid2, 10);
				
				float destination[3];
				GetClientAbsOrigin(clientid3, destination);
				destination[2] += 10;
				TeleportEntity(param1, destination, NULL_VECTOR, NULL_VECTOR);
				
				Menu_RedieTeleport(param1, 1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_RedieMenu(param1, 1);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action Menu_RedieTeleport(int client, int args)
{
	if (isInRedie[client])
	{
		Menu teleportMenu = new Menu(TeleportMenuHandler, MenuAction_Select|MenuAction_End);
		for (int i = 0; i < MaxClients; i++)
		{
			if(IsValidClient(i) && IsPlayerAlive(i))
			{
				char name[64];
				GetClientName(i, name, sizeof(name));
				
				char clientid[64];
				IntToString(i, clientid, sizeof(clientid));
				teleportMenu.AddItem(clientid, name);
			}
		}
		teleportMenu.ExitBackButton = true;
		teleportMenu.Display(client, MENU_TIME_FOREVER);
		return Plugin_Handled;
	}else
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04You must be in redie to access this menu.");
		return Plugin_Handled;
	}
}