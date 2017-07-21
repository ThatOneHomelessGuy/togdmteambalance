#pragma semicolon 1
#define PLUGIN_VERSION "2.0"
#include <sourcemod>
#include <autoexecconfig>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

//cvars and their integers
ConVar g_hEnabled;
ConVar g_hImmuneFlag;
char g_sImmuneFlag[30];
ConVar g_hCheckTime;
ConVar g_hBalanceDifference;
ConVar g_hCooldownPlayerCount;
ConVar g_hCooldownTime;

bool g_bUnbalanced = false;
bool ga_bMovable[MAXPLAYERS + 1] = {false, ...};
bool ga_bInCooldown[MAXPLAYERS + 1] = {false, ...};

int g_iNumT = 0;
int g_iNumCT = 0;
int g_iTeamWithMore;

public Plugin myinfo =
{
	name = "TOGs Deathmatch Team Balancer",
	author = "That One Guy",
	description = "Balances Teams for Death Match Servers",
	version = PLUGIN_VERSION,
	url = "http://www.togcoding.com"
}

public void OnPluginStart()
{
	AutoExecConfig_SetFile("togdmteambalance");
	AutoExecConfig_CreateConVar("tdmtb_version", PLUGIN_VERSION, "TOGs Deathmatch Team Balancer Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hEnabled = AutoExecConfig_CreateConVar("tdmtb_enable", "1", "Enable plugin (0 = Disabled, 1 = Enabled).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCheckTime = AutoExecConfig_CreateConVar("tdmtb_checktime", "20", "Repeating time interval to check for unbalanced teams.", FCVAR_NONE, true, 0.0);
	g_hBalanceDifference = AutoExecConfig_CreateConVar("tdmtb_difference", "2", "How many more players a team must have to be considered unbalanced.", FCVAR_NONE, true, 2.0);
	g_hCooldownPlayerCount = AutoExecConfig_CreateConVar("tdmtb_cooldown_playercount", "8", "How many players must be playing (on a team) before players cannot be moved until after a cooldown time.", FCVAR_NONE, true, 1.0, true, 64.0);
	g_hCooldownTime = AutoExecConfig_CreateConVar("tdmtb_cooldown_time", "60", "Time after a player is moved during which they cannot be moved again (set to 0 to disable cooldown).", FCVAR_NONE, true, 0.0);
	
	g_hImmuneFlag = AutoExecConfig_CreateConVar("tdmtb_immuneflag", "a", "Flag to check for when balancing. Players with this flag will not be moved.");
	g_hImmuneFlag.GetString(g_sImmuneFlag, sizeof(g_sImmuneFlag));
	g_hImmuneFlag.AddChangeHook(OnCVarChange);
	
	RegAdminCmd("sm_chkbal", Command_ChkBal, ADMFLAG_BAN, "Checks Team Balance.");
	RegAdminCmd("sm_chkimm", Command_ChkImm, ADMFLAG_BAN, "Checks who has immunity to Team Balance.");
	
	HookEvent("player_death", EventPlayerDeath, EventHookMode_Post);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
}

public void OnCVarChange(ConVar hCVar, const char[] sOldValue, const char[] sNewValue)
{
	if(hCVar == g_hImmuneFlag)
	{
		g_hImmuneFlag.GetString(g_sImmuneFlag, sizeof(g_sImmuneFlag));
	}
}

public Action Command_ChkImm(int client, int iArgs)
{
	int iImmuneFound = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		ga_bMovable[i] = false;
		
		if(IsValidClient(i))
		{
			if(HasFlags(i, g_sImmuneFlag))
			{
				ga_bMovable[i] = true;
				if(!IsValidClient(client))
				{
					PrintToServer("Player \"%N\" is immune to Team Balance.", i);
				}
				else
				{
					PrintToConsole(client, "Player \"%N\" is immune to Team Balance.", i);
				}
				iImmuneFound = 1;
			}
		}
	}
	
	if(!iImmuneFound)
	{
		ReplyToCommand(client, "Did not find any players with immunity to Team Balance.");
		return Plugin_Handled;
	}
	
	if(IsValidClient(client))
	{
		PrintToChat(client, "Check console for players with immunity!");
	}
	return Plugin_Handled;
}

public Action Command_ChkBal(int client, int iArgs)
{
	ReplyToCommand(client, "Team Balances are being checked!");
	CheckTeams();
	ReplyToCommand(client, "Number of Ts: %i, Number of CTs: %i", g_iNumT, g_iNumCT);
	return Plugin_Handled;
}

void CheckTeams()		//count players and check for unbalance
{
	//reset counts
	g_iNumT = 0;
	g_iNumCT = 0;
	g_iTeamWithMore = 0;
	
	//count players on each team
	for(int i = 1; i <= MaxClients; i++)
	{	
		if(IsValidClient(i))
		{
			if(GetClientTeam(i) == 2)
			{
				g_iNumT++;
			}
			else if(GetClientTeam(i) == 3)
			{
				g_iNumCT++;
			}
		}
	}
	
	//check if unbalanced
	float fDifference = view_as<float>(g_iNumCT - g_iNumT);		//need to use float for abs value
	fDifference = FloatAbs(fDifference);
	if((fDifference + 1) > g_hBalanceDifference.IntValue)
	{
		g_bUnbalanced = true;
		
		if(g_iNumCT > g_iNumT)
		{
			g_iTeamWithMore = 3;
		}
		else
		{
			g_iTeamWithMore = 2;
		}
	}
	else
	{
		g_bUnbalanced = false;
	}
}

public void OnMapStart()
{
	if(g_hEnabled.IntValue)
	{
		CreateTimer(g_hCheckTime.FloatValue, TimerCB_CheckBalance, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

		for(int i = 1; i <= MaxClients; i++)	//check each player for if they are movable
		{
			ga_bMovable[i] = false;
			
			if(IsValidClient(i))
			{
				if(!HasFlags(i, g_sImmuneFlag))
				{
					ga_bMovable[i] = true;
				}
			}
		}
	}
}

bool HasFlags(int client, char[] sFlags)
{
	if(StrEqual(sFlags, "public", false) || StrEqual(sFlags, "", false))
	{
		return true;
	}
	else if(StrEqual(sFlags, "none", false))	//useful for some plugins
	{
		return false;
	}
	else if(!client)	//if rcon
	{
		return true;
	}
	else if(CheckCommandAccess(client, "sm_not_a_command", ADMFLAG_ROOT, true))
	{
		return true;
	}
	
	AdminId id = GetUserAdmin(client);
	if(id == INVALID_ADMIN_ID)
	{
		return false;
	}
	int flags, clientflags;
	clientflags = GetUserFlagBits(client);
	
	if(StrContains(sFlags, ";", false) != -1) //check if multiple strings
	{
		int i = 0, iStrCount = 0;
		while(sFlags[i] != '\0')
		{
			if(sFlags[i++] == ';')
			{
				iStrCount++;
			}
		}
		iStrCount++; //add one more for stuff after last comma
		
		char[][] a_sTempArray = new char[iStrCount][30];
		ExplodeString(sFlags, ";", a_sTempArray, iStrCount, 30);
		bool bMatching = true;
		
		for(i = 0; i < iStrCount; i++)
		{
			bMatching = true;
			flags = ReadFlagString(a_sTempArray[i]);
			for(int j = 0; j <= 20; j++)
			{
				if(bMatching)	//if still matching, continue loop
				{
					if(flags & (1<<j))
					{
						if(!(clientflags & (1<<j)))
						{
							bMatching = false;
						}
					}
				}
			}
			if(bMatching)
			{
				return true;
			}
		}
		return false;
	}
	else
	{
		flags = ReadFlagString(sFlags);
		for(int i = 0; i <= 20; i++)
		{
			if(flags & (1<<i))
			{
				if(!(clientflags & (1<<i)))
				{
					return false;
				}
			}
		}
		return true;
	}
}

public void OnClientPostAdminCheck(int client)		//check players for if they are movable
{
	ga_bMovable[client] = false;
	
	if(IsValidClient(client))
	{
		if(!HasFlags(client, g_sImmuneFlag))
		{
			ga_bMovable[client] = true;
		}
	}
}

public void OnClientPutInServer(int client)
{
	ga_bMovable[client] = false;
	ga_bInCooldown[client] = false;
}

public Action TimerCB_CheckBalance(Handle hTimer)
{
	CheckTeams();
	return Plugin_Continue;
}

public Action Timer_Cooldown(Handle hTimer, any iUserID)
{
	int client = GetClientOfUserId(iUserID);
	
	if(IsValidClient(client))
	{
		ga_bInCooldown[client] = false;
	}
	return Plugin_Continue;
}

public void EventPlayerDeath(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if(g_hEnabled.IntValue)
	{
		if(g_bUnbalanced)	//if teams are unbalanced
		{
			int iUserID = GetEventInt(hEvent, "userid");
			int client = GetClientOfUserId(iUserID);
			
			if(IsValidClient(client))
			{
				if(ga_bMovable[client])
				{
					if(GetClientTeam(client) == g_iTeamWithMore)
					{
						if(((g_iNumCT + g_iNumT) >= g_hCooldownPlayerCount.IntValue) && (g_hCooldownTime.FloatValue > 0.0))			//if player count is above or equal to set cooldown player count, and cooldown isnt set to disabled
						{
							if(!ga_bInCooldown[client])	//check if player is in cooldown
							{
								ChangeTeam(client);
								g_bUnbalanced = false;	//assume teams are balanced until checked again
								ga_bInCooldown[client] = true;
								CreateTimer(g_hCooldownTime.FloatValue, Timer_Cooldown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
							}
						}
						else	//no cooldown check
						{
							ChangeTeam(client);
							g_bUnbalanced = false;	//assume teams are balanced until checked again
							if(g_hCooldownTime.FloatValue > 0.0)	//if cooldowns are set to disabled, then dont bother with timer.
							{
								ga_bInCooldown[client] = true;
								CreateTimer(g_hCooldownTime.FloatValue, Timer_Cooldown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);		//still create the timer in case player count reaches g_hCooldownPlayerCount.IntValue
							}
						}
					}
				}
				else
				{
					PrintToChat(client, "\x04[TOG TB] You have been skipped for team balance due to immunity!");
				}
			}
		}
	}
}

void ChangeTeam(int client)
{
	PrintToChat(client, "\x03You are being switched to balance teams!!!");
	PrintCenterText(client, "You are being switched to balance teams!!!");
	PrintHintText(client, "You are being switched to balance teams!!!");
	PrintToChatAll("\x03Player %N is being switched to balance teams!", client);
	PrintToServer("Player %N is being switched to balance teams!", client);
	if(GetClientTeam(client) == 2)
	{
		ChangeToTeam(client, 3, 0.0, IsPlayerAlive(client));
	}
	else if(GetClientTeam(client) == 3)
	{
		ChangeToTeam(client, 2, 0.0, IsPlayerAlive(client));
	}
}

void ChangeToTeam(int client, int iTeam, float fDelay = 0.0, bool bRespawn = false)
{
	if(IsValidClient(client))
	{
		CreateTimer(fDelay, Timer_ChangeTeamSpec, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		if(iTeam == 2)
		{
			CreateTimer(fDelay + 1.0, Timer_ChangeTeamToT, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			CreateTimer(fDelay + 1.0, Timer_ChangeTeamToCT, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		
		if(bRespawn)
		{
			CreateTimer(fDelay + 1.5, TimerCB_RespawnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_ChangeTeamSpec(Handle hTimer, any iUserID)
{
	int client = GetClientOfUserId(iUserID);
	if(IsValidClient(client))
	{
		ChangeClientTeam(client, 1);
	}
}

public Action Timer_ChangeTeamToCT(Handle hTimer, any iUserID)
{
	int client = GetClientOfUserId(iUserID);
	if(IsValidClient(client))
	{
		ChangeClientTeam(client, 3);
	}
	
	CreateTimer(8.0, Timer_RecheckTeams, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ChangeTeamToT(Handle hTimer, any iUserID)
{
	int client = GetClientOfUserId(iUserID);
	if(IsValidClient(client))
	{
		ChangeClientTeam(client, 2);
	}
	
	CreateTimer(8.0, Timer_RecheckTeams, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerCB_RespawnPlayer(Handle hTimer, any iUserID)
{
	int client = GetClientOfUserId(iUserID);
	if(!IsValidClient(client))
	{
		if(!IsPlayerAlive(client))
		{
			CS_RespawnPlayer(client);
		}
	}
}

public Action Timer_RecheckTeams(Handle hTimer)
{
	CheckTeams();
}

bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!IsPlayerAlive(client) && !bAllowDead))
	{
		return false;
	}
	return true;
}

/*
Changelog:
	03/25/14 v1.0:
		* Initial release.
	03/25/14 v1.1:
		Fixed Immunity System.
		Added admin command to check which players in the server are immune.
	05/30/14 v1.2:
		Fixed problem i noticed in the code that the check immunity function could take off a players immunity.
		Fixed error that could have occured if check immunity or check balance functions were called via rcon (print to chat would cause an error, since client isnt in game).
		Added check to see if plugin is enabled before checks on player death.
		Added cooldown time (configurable via cvar) for players who are switched, as well as a minimum number of players (configurable via cvar) needed for the cooldowns to activate (and ability to disable cooldown time all together).
	5/19/15 v1.3:
		* Removed OnPluginEnd (it was pointless). No need to close handles to the timer in OnPluginEnd, since they are released when the plugin is unloaded anyways.
		* Added a few more notifications to the player being moved.
	11/11/16 v2.0:
		* Changed to new syntax and updated code for entire plugin. Changes untested.
*/