#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Diam0ndzx" //With Help from Extacy
#define PLUGIN_VERSION "1.0"
#define MAX_BUTTONS 25

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#pragma newdecls required

EngineVersion g_Game;

ConVar enabled;
ConVar damageRespawns;

bool isInRedie[MAXPLAYERS + 1];
bool canRedie[MAXPLAYERS + 1];

int lastButton[MAXPLAYERS + 1];

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
	
	enabled = CreateConVar("sm_enableredie", "1", "Sets whether redie is enabled or not");
	damageRespawns = CreateConVar("sm_rediedamagerespawns", "0", "Set if getting damages in redie respawns you or not");
	
	RegConsoleCmd("sm_redie", Command_Redie, "Become a ghost");
	RegConsoleCmd("sm_unredie", Command_Unredie, "Get out of becoming a ghost");
	
	HookEvent("player_death", Event_PrePlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start", Event_PreRoundStart, EventHookMode_Pre);
	//HookEvent("round_end", Event_PostRoundEnd, EventHookMode_Post);
	
	AddNormalSoundHook(OnNormalSoundPlayed);
	
	HookEntityOutput("func_door", "OnBlockedOpening", EntityOutput_DoorBlocked);
	HookEntityOutput("func_door", "OnBlockedClosing", EntityOutput_DoorBlocked);
	//HookEntityOutput("func_button", "OnPressed", EntityOutPut_ButtonPressed);
	
	AutoExecConfig(true, "redie");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse);
}

public void OnClientPostAdminCheck(int client)
{
	isInRedie[client] = false; //You can't be in redie the moment you join
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
	ent = MaxClients + 1;
	while((ent = FindEntityByClassname(ent, "func_rotating")) != -1)
	{
		SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
	}
	ent = MaxClients + 1;
	while((ent = FindEntityByClassname(ent, "func_breakable")) != -1)
	{
		SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
	}
	ent = MaxClients + 1; //ent is already defined, so we are changing/updating it
	while((ent = FindEntityByClassname(ent, "func_button")) != -1)
	{
		SDKHookEx(ent, SDKHook_EndTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_StartTouch, CollisionCheck);
		SDKHookEx(ent, SDKHook_Touch, CollisionCheck);
	}
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
	ent = MaxClients + 1;
	while((ent = FindEntityByClassname(ent, "trigger_hurt")) != -1)
	{
		if(GetConVarBool(damageRespawns))
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
	if(isInRedie[client])
	{
		isInRedie[client] = false;
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

public Action Command_Redie(int client, int args)
{
	if(!GetConVarBool(enabled))
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Redie is currently disabled!");
		return Plugin_Handled;
	}
	
	if(IsValidClient(client))
	{
		if(canRedie[client])
		{
			Redie(client, false);
			return Plugin_Handled;
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
	if(!fromDamage)
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04You are now a ghost!");
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Hold your \x0Freload \x04key(Default: 'r') to gain \x0Fnoclip \x04temporarily!");
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Type '!unredie' to stop being a ghost.");
	}
}

public Action Command_Unredie(int client, int args)
{
	if(!GetConVarBool(enabled))
	{
		PrintToChat(client, " \x01[\x03Redie\x01] \x04Redie is currently disabled!");
		return Plugin_Handled;
	}else
		{
		if(IsValidClient(client))
		{
			if(isInRedie[client])
			{
				Unredie(client);
				return Plugin_Handled;
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
	PrintToChat(client, " \x01[\x03Redie\x01] \x04You are no longer a ghost!");
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
			if(buttons & IN_USE)
			{
				if(!(lastButton[client] & IN_USE))
				{
					//SetEntityMoveType(client, MOVETYPE_NOCLIP);
					return Plugin_Handled;
				}
			}else if(lastButton[client] & IN_USE)
			{
				//SetEntityMoveType(client, MOVETYPE_WALK);
				return Plugin_Continue;
			}
			else if(buttons & IN_RELOAD)
			{
				if(!(lastButton[client] & IN_RELOAD))
				{
					SetEntityMoveType(client, MOVETYPE_NOCLIP);
				}
			}else if(lastButton[client] & IN_RELOAD)
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
			}
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

public Action OnNormalSoundPlayed(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if(entity && entity <= MaxClients && isInRedie[entity])
	{
		return Plugin_Handled;
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

/*public Action EntityOutPut_ButtonPressed(const char[] output, int caller, int activator, float delay)
{
	if(IsValidClient(activator))
	{
		if(isInRedie[activator])
		{
			return Plugin_Handled;
		}else
		{
			return Plugin_Continue;
		}
	}else
	{
		return Plugin_Handled;
	}
}*/

stock bool IsValidClient(int client) //Checks for making sure we are a valid client
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}