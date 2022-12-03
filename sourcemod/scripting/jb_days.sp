#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <jailbreak>

#define MAX_DM_DAYS 7
#define MAX_TEAM_DAYS 6
#define MAX_SP_DAYS 2

#define TEAM_DAY 1
#define DM_DAY 2
#define SP_DAY 3

#define ZEUS_DAY 0
#define FIRE_DAY 1
#define DEATHMATCH 2
#define NO_SCOPE_DAY 3
#define SNOWBALL_DAY 4
#define SCOUTSMAN_DAY 5
#define BOX_DAY 6

#define AWP_DAY 0
#define RIOT_DAY 1
#define SPACE_DAY 2
#define ZOMBIE_DAY 3
#define HNS_DAY 4
#define VIP_DAY 5

#define ALIEN_DAY 0
#define ZOMBIE_SP_DAY 1

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new String:g_DMDays[MAX_DM_DAYS][] = 
{
	"Zeus Day",
	"Fire Day",
	"Deathmatch",
	"No-Scope Day",
	"Snowball Day",
	"Flying Scoutsman",
	"Box Day"
}

new String:g_TeamDays[MAX_TEAM_DAYS][] = 
{
	"AWP Day",
	"Riot Day",
	"Space Day",
	"Zombie Day",
	"Hide & Seek",
	"Protect the VIP"
}

new String:g_SPDays[MAX_SP_DAYS][] = 
{
	"Alien Day",
	"Zombie Day"
}

new const String:g_Primary[][] = 
{
	"weapon_awp",
	"weapon_m4a1",
	"weapon_m4a1_silencer",
	"weapon_ak47",
	"weapon_nova",
	"weapon_mp5sd"
}

new const String:g_Secondary[][] = 
{
	"weapon_fiveseven",
	"weapon_p250",
	"weapon_usp_silencer",
	"weapon_glock",
	"weapon_deagle",
	"weapon_elite"
}

new g_SP
new g_VIP
new g_GameType
new g_GameMode
new g_Countdown

new bool:g_SpecialDay

new String:g_ZMDayModel[128]
new String:g_VIPDayModel[128]

new Handle:g_cDMMoney
new Handle:g_cDMDayTime
new Handle:g_cSPDayTime
new Handle:g_cMinPlayers
new Handle:g_cMaxDollars
new Handle:g_cTeamDayTime
new Handle:g_cGuardTeamMoney
new Handle:g_cPrisonerTeamMoney
new Handle:g_cPrisonerSPMoney
new Handle:g_cSPMoney
new Handle:g_cVIPDayModel
new Handle:g_cZMDayModel

new Handle:cd_timer = INVALID_HANDLE
new Handle:game_timer = INVALID_HANDLE

new Handle:g_OnSpecialDay = INVALID_HANDLE

native SJD_OpenDoors()

native bool:IsClientVIP(client)

public Plugin:myinfo = 
{
	name = "Jailbreak Days",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_days", CmdDays)
	
	g_cDMDayTime = CreateConVar("jb_dm_day_time", "180", "Round time in seconds for DM Day", _, true, 60.0)
	g_cSPDayTime = CreateConVar("jb_sp_day_time", "210", "Round time in seconds for SP Day", _, true, 60.0)
	g_cTeamDayTime = CreateConVar("jb_team_day_time", "300", "Round time in seconds for Team Day", _, true, 60.0)
	g_cDMMoney = CreateConVar("jb_dm_winner_money", "150", "DM Winner Money", _, true, 10.0)
	g_cGuardTeamMoney = CreateConVar("jb_team_guards_win_money", "200", "Team Day Guards win money", _, true, 10.0)
	g_cPrisonerTeamMoney = CreateConVar("jb_team_prisoners_win_money", "100", "Team Day Prisoners win money", _, true, 10.0)
	g_cPrisonerSPMoney = CreateConVar("jb_sp_prisoners_win_money", "100", "SP Day Prisoners win money", _, true, 10.0)
	g_cSPMoney = CreateConVar("jb_sp_win_money", "150", "SP win money", _, true, 10.0)
	g_cMinPlayers = CreateConVar("jb_day_dollars_min_players", "6", "Minimum Players to get rewards", _, true, 0.0)
	g_cMaxDollars = CreateConVar("jb_day_max_dollars", "20000", "Maximum dollars a Player can get", _, true, 0.0, true, 20000.0)
	g_cVIPDayModel = CreateConVar("jb_day_vip_model", "models/player/custom_player/kuristaja/agent_smith/smith.mdl", "VIP model")
	g_cZMDayModel = CreateConVar("jb_day_zm_model", "models/player/custom_player/kuristaja/skeleton/skeleton.mdl", "Zombie model")
	
	g_OnSpecialDay = CreateGlobalForward("JB_OnSpecialDay", ET_Ignore, Param_Cell)
}

public OnMapStart()
{
	GetConVarString(g_cVIPDayModel, g_VIPDayModel, sizeof(g_VIPDayModel))
	PrecacheModel(g_VIPDayModel)
	
	GetConVarString(g_cZMDayModel, g_ZMDayModel, sizeof(g_ZMDayModel))
	PrecacheModel(g_ZMDayModel)
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("JB_GetDayType", Native_GetDayType)
	CreateNative("JB_IsSpecialDay", Native_IsSpecialDay)
	CreateNative("JB_GetSpecialDay", Native_GetSpecialDay)

	RegPluginLibrary("jailbreak")
	
	return APLRes_Success
}

public Native_GetDayType(Handle:plugin, numParams)
{
	return g_GameType
}

public Native_IsSpecialDay(Handle:plugin, numParams)
{
	return g_SpecialDay
}

public Native_GetSpecialDay(Handle:plugin, numParams)
{
	return g_GameMode
}

public OnClientPutInServer(client)
{
	if(g_SpecialDay)
	{
		if(g_GameType == TEAM_DAY)
		{
			SDKHook(client, SDKHook_WeaponSwitch, Hook_WSTeamDay)
		}
		else if(g_GameType == DM_DAY)
		{
			SDKHook(client, SDKHook_WeaponSwitch, Hook_WSDMDay)
			
			if(g_GameMode == NO_SCOPE_DAY)
			{
				SDKHook(client, SDKHook_PreThink, Hook_PreThink)
			}
		}
		else
		{
			SDKHook(client, SDKHook_WeaponSwitch, Hook_WSSPDay)
			SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage)
		}
	}
}

public Action:Hook_PreThink(client)
{
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")
	
	if(IsValidEdict(weapon))
	{
		new String:szWeapon[32]
		GetEdictClassname(weapon, szWeapon, sizeof(szWeapon))
		
		if(StrEqual(szWeapon, "weapon_awp"))
		{
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 2.0)
		}
	}
}

public Action:Hook_WSTeamDay(client, weapon)
{
	new String:szWeapon[64]
	GetEdictClassname(weapon, szWeapon, sizeof(szWeapon))
	
	switch(g_GameMode)
	{
		case AWP_DAY:
		{
			if(!StrEqual(szWeapon, "weapon_awp") && !StrEqual(szWeapon, "weapon_knife"))
			{
				return Plugin_Stop
			}
		}
		case SPACE_DAY:
		{
			if(GetClientTeam(client) == CS_TEAM_T)
			{
				if(!StrEqual(szWeapon, "weapon_ssg08") && !StrEqual(szWeapon, "weapon_knife"))
				{
					return Plugin_Stop
				}
			}
			else if(GetClientTeam(client) == CS_TEAM_CT)
			{
				if(!StrEqual(szWeapon, "weapon_g3sg1") && !StrEqual(szWeapon, "weapon_knife"))
				{
					return Plugin_Stop
				}
			}
		}
		case ZOMBIE_DAY:
		{
			if(GetClientTeam(client) == CS_TEAM_T)
			{
				if(!StrEqual(szWeapon, "weapon_knife"))
				{
					return Plugin_Stop
				}
			}
			else if(GetClientTeam(client) == CS_TEAM_CT)
			{
				if(!StrEqual(szWeapon, "weapon_xm1014") && !StrEqual(szWeapon, "weapon_knife"))
				{
					return Plugin_Stop
				}
			}
		}
		case HNS_DAY:
		{
			if(GetClientTeam(client) == CS_TEAM_T)
			{
				if(!StrEqual(szWeapon, "weapon_knife"))
				{
					return Plugin_Stop
				}
			}
		}
		case VIP_DAY:
		{
			if(GetClientTeam(client) == CS_TEAM_CT)
			{
				new weaponindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex")
	
				switch(weaponindex)
				{
					case 60: strcopy(szWeapon, sizeof(szWeapon), "weapon_m4a1_silencer")
					case 61: strcopy(szWeapon, sizeof(szWeapon), "weapon_usp_silencer")
				}
				
				if(!StrEqual(szWeapon, "weapon_m4a1_silencer") && !StrEqual(szWeapon, "weapon_usp_silencer") && !StrEqual(szWeapon, "weapon_knife"))
				{
					return Plugin_Stop
				}
			}
		}
	}
	
	return Plugin_Continue
}

public Action:Hook_WSDMDay(client, weapon)
{
	new String:szWeapon[64]
	GetEdictClassname(weapon, szWeapon, sizeof(szWeapon))
	
	switch(g_GameMode)
	{
		case ZEUS_DAY:
		{
			if(!StrEqual(szWeapon, "weapon_taser") && !StrEqual(szWeapon, "weapon_knife"))
			{
				return Plugin_Stop
			}
		}
		case FIRE_DAY:
		{
			if(!StrEqual(szWeapon, "weapon_molotov") && !StrEqual(szWeapon, "weapon_knife"))
			{
				return Plugin_Stop
			}
		}
		case NO_SCOPE_DAY:
		{
			if(!StrEqual(szWeapon, "weapon_awp") && !StrEqual(szWeapon, "weapon_knife"))
			{
				return Plugin_Stop
			}
		}
		case SNOWBALL_DAY:
		{
			if(!StrEqual(szWeapon, "weapon_snowball") && !StrEqual(szWeapon, "weapon_knife"))
			{
				return Plugin_Stop
			}
		}
		case SCOUTSMAN_DAY:
		{
			if(!StrEqual(szWeapon, "weapon_ssg08") && !StrEqual(szWeapon, "weapon_knife"))
			{
				return Plugin_Stop
			}
		}
		case BOX_DAY:
		{
			if(!StrEqual(szWeapon, "weapon_fists"))
			{
				return Plugin_Stop
			}
		}
	}
	
	return Plugin_Continue
}

public Action:Hook_WSSPDay(client, weapon)
{
	if(client == g_SP)
	{
		new String:szWeapon[64]
		GetEdictClassname(weapon, szWeapon, sizeof(szWeapon))
		
		if(!StrEqual(szWeapon, "weapon_knife"))
		{
			return Plugin_Stop
		}
	}
	
	return Plugin_Continue
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(attacker != g_SP && victim != g_SP)
	{
		damage = 0.0
		
		return Plugin_Changed
	}
	
	if(attacker == g_SP)
	{
		damage *= 100
		
		return Plugin_Changed
	}
	
	return Plugin_Continue
}

public Action:CmdDays(client, args)
{
	if(client != JB_GetSimon())
	{
		PrintToChat(client, "%s You don't have access to use this command", g_Tag)
		return Plugin_Handled
	}
	
	if(g_SpecialDay || JB_IsLastRequest() || JB_IsFreeday())
	{
		PrintToChat(client, "%s You can't use this command now", g_Tag)
		return Plugin_Handled
	}
	
	new Handle:menu = CreateMenu(menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Days Menu:")
	
	AddMenuItem(menu, "1", "Team Days")
	AddMenuItem(menu, "2", "Deathmatch Days")
	
	if(HasVIPAccess(client))
	{
		AddMenuItem(menu, "3", "Special Days")
	}
	else
	{
		AddMenuItem(menu, "3", "Special Days", ITEMDRAW_DISABLED)
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
	
	return Plugin_Handled
}

public menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			g_GameType = StringToInt(item)
			
			DaysMenu(client)
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetConVarInt(FindConVar("mp_death_drop_gun"), 1)
	
	if(CountConnectedPlayers() >= GetConVarInt(g_cMinPlayers))
	{
		new max_dollars = GetConVarInt(g_cMaxDollars)
		
		if(g_GameType == TEAM_DAY)
		{
			new money
			
			new winner = GetEventInt(event, "winner")
			
			if(winner == CS_TEAM_T)
			{
				money = GetConVarInt(g_cPrisonerTeamMoney)
			}
			else if(winner == CS_TEAM_CT)
			{
				money = GetConVarInt(g_cGuardTeamMoney)
			}
			
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && GetClientTeam(i) == winner && IsPlayerAlive(i))
				{
					if(max_dollars > JB_GetClientDollars(i) + money)
					{
						PrintToChat(i, "%s You got \x04%d%\x01 for winning \x07%s", g_Tag, money, g_TeamDays[g_GameMode])
						JB_SetClientDollars(i, JB_GetClientDollars(i) + money)
					}
				}
			}
		}
		else if(g_GameType == DM_DAY)
		{
			new winner = GetWinner()
			
			if(winner != -1)
			{
				new money = GetConVarInt(g_cDMMoney)
				
				if(max_dollars > JB_GetClientDollars(winner) + money)
				{
					PrintHintTextToAll("%N won the game", winner)
					PrintToChatAll("%s \x0E%N\x01 got \x04%d$\x01 for winning \x07%s", g_Tag, winner, money, g_DMDays[g_GameMode])
					JB_SetClientDollars(winner, JB_GetClientDollars(winner) + money)
				}
			}
		}
		else
		{
			new money
			
			new winner = GetEventInt(event, "winner")
			
			if(winner == CS_TEAM_T)
			{
				money = GetConVarInt(g_cPrisonerSPMoney)
				
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
					{
						if(max_dollars > JB_GetClientDollars(i) + money)
						{
							PrintToChat(i, "%s You got \x04%d%\x01 for winning \x07%s", g_Tag, money, g_SPDays[g_GameMode])
							JB_SetClientDollars(i, JB_GetClientDollars(i) + money)
						}
					}
				}
			}
			else if(winner == CS_TEAM_CT)
			{
				money = GetConVarInt(g_cSPMoney)
				
				if(max_dollars > JB_GetClientDollars(g_SP) + money)
				{
					PrintHintTextToAll("%N won the game", g_SP)
					PrintToChatAll("%s \x0E%N\x01 got \x04%d$\x01 for winning \x07%s", g_Tag, g_SP, money, g_SPDays[g_GameMode])
					JB_SetClientDollars(g_SP, JB_GetClientDollars(g_SP) + money)
				}
			}
		}
	}
	
	UnhookEvent("round_end", Event_RoundEnd)
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_GameType == TEAM_DAY)
	{
		if(g_GameMode == VIP_DAY)
		{
			UnhookEvent("player_death", Event_PlayerDeath)
		}
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKUnhook(i, SDKHook_WeaponSwitch, Hook_WSTeamDay)
			}
		}
	}
	else if(g_GameType == DM_DAY)
	{
		UnhookEvent("player_death", Event_PlayerDeath)
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKUnhook(i, SDKHook_PreThink, Hook_PreThink)
				SDKUnhook(i, SDKHook_WeaponSwitch, Hook_WSDMDay)
			}
		}
	}
	else
	{
		UnhookEvent("player_death", Event_PlayerDeath)
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKUnhook(i, SDKHook_WeaponSwitch, Hook_WSSPDay)
				SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage)
			}
		}
	}
	
	g_SP = 0
	g_VIP = 0
	g_GameType = 0
	g_GameMode = 0

	g_SpecialDay = false

	ClearTimer(cd_timer)
	ClearTimer(game_timer)
	
	SetConVarInt(FindConVar("sv_gravity"), 800)
	SetConVarInt(FindConVar("sv_infinite_ammo"), 0)
	SetConVarInt(FindConVar("mp_death_drop_gun"), 1)
	SetConVarInt(FindConVar("mp_taser_recharge_time"), -1)
	SetConVarInt(FindConVar("mp_teammates_are_enemies"), 0)
	SetConVarInt(FindConVar("weapon_accuracy_nospread"), 0)
	
	UnhookEvent("round_start", Event_RoundStart)
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"))
	
	if(g_GameType == TEAM_DAY)
	{
		if(victim == g_VIP)
		{
			PrintHintTextToAll("The VIP has died")
			CS_TerminateRound(10.0, CSRoundEnd_TerroristWin)
		}
	}
	else
	{
		if(victim == g_SP)
		{
			CS_TerminateRound(10.0, CSRoundEnd_TerroristWin)
		}
	}
}

public DaysMenu(client)
{
	new Handle:menu = CreateMenu(d_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Select Day:")
	
	new String:szItem[32]
	
	if(g_GameType == TEAM_DAY)
	{
		for(new i = 0; i < MAX_TEAM_DAYS; i++)
		{
			IntToString(i, szItem, sizeof(szItem))
			AddMenuItem(menu, szItem, g_TeamDays[i])
		}
	}
	else if(g_GameType == DM_DAY)
	{
		for(new i = 0; i < MAX_DM_DAYS; i++)
		{
			IntToString(i, szItem, sizeof(szItem))
			AddMenuItem(menu, szItem, g_DMDays[i])
		}
	}
	else
	{
		for(new i = 0; i < MAX_SP_DAYS; i++)
		{
			IntToString(i, szItem, sizeof(szItem))
			AddMenuItem(menu, szItem, g_SPDays[i])
		}
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public d_menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			new i = StringToInt(item)
			
			g_GameMode = i
			
			if(g_GameType == TEAM_DAY)
			{
				PrepareTeamDay()
			}
			else if(g_GameType == DM_DAY)
			{
				PrepareDMDay()
			}
			else
			{
				g_SP = client
				PrepareSPDay()
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

PrepareTeamDay()
{
	g_SpecialDay = true
	
	PlayDing()
	JB_RemoveSimon()
	Forward_OnSpecialDay()
	HookEvent("round_end", Event_RoundEnd)
	HookEvent("round_start", Event_RoundStart)
	SetConVarInt(FindConVar("sv_infinite_ammo"), 2)
	SetConVarInt(FindConVar("mp_death_drop_gun"), 0)
	SetConVarInt(FindConVar("mp_teammates_are_enemies"), 0)
	SetHudTextParams(-1.0, 0.55, 4.0, 0, 255, 0, 255)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ShowHudText(i, 1, g_TeamDays[g_GameMode])
			
			if(IsPlayerAlive(i))
			{
				StripPlayer(i)
				SetGodMode(i)
			}
		}
	}
	
	HookWeaponSwitch(TEAM_DAY)
	
	switch(g_GameMode)
	{
		case AWP_DAY:
		{
			FreezePlayers(CS_TEAM_T)
			SetConVarInt(FindConVar("sv_gravity"), 200)
		}
		case RIOT_DAY:
		{
			FreezePlayers(CS_TEAM_T)
		}
		case SPACE_DAY:
		{
			FreezePlayers(CS_TEAM_T)
			SetConVarInt(FindConVar("sv_gravity"), 200)
		}
		case ZOMBIE_DAY:
		{
			FreezePlayers(CS_TEAM_T)
		}
		case HNS_DAY:
		{
			SJD_OpenDoors()
			FreezePlayers(CS_TEAM_CT)
		}
		case VIP_DAY:
		{
			FreezePlayers(CS_TEAM_T)
			HookEvent("player_death", Event_PlayerDeath)
		}
	}
	
	CreateCountdown(30)
	game_timer = CreateTimer(30.0, StartTeamDay)
}

public Action:StartTeamDay(Handle:timer)
{
	PlayDing()
	SJD_OpenDoors()
	SetRoundTime(GetConVarInt(g_cTeamDayTime))
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			StripPlayer(i)
		}
	}
	
	CreateTimer(0.3, StartTeamDayTimer)
	ClearTimer(game_timer)
}

public Action:StartTeamDayTimer(Handle:timer)
{
	switch(g_GameMode)
	{
		case AWP_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					GivePlayerItem(i, "weapon_awp")
					GivePlayerItem(i, "weapon_knife")
					GivePlayerItem(i, "item_assaultsuit")
					
					if(GetClientTeam(i) == CS_TEAM_CT)
					{
						SetEntityHealth(i, 350)
					}
				}
			}
		}
		case RIOT_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					WeaponsMenu(i)
					GivePlayerItem(i, "weapon_knife")
				}
			}
		}
		case SPACE_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					if(GetClientTeam(i) == CS_TEAM_T)
					{
						GivePlayerItem(i, "weapon_ssg08")
					}
					else if(GetClientTeam(i) == CS_TEAM_CT)
					{
						GivePlayerItem(i, "weapon_g3sg1")
						GivePlayerItem(i, "item_assaultsuit")
					}
					
					GivePlayerItem(i, "weapon_knife")
				}
			}
		}
		case ZOMBIE_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					if(GetClientTeam(i) == CS_TEAM_T)
					{
						SetEntityGravity(i, 0.5)
						SetEntityHealth(i, 1500)
						SetEntityModel(i, g_ZMDayModel)
						SetEntityRenderColor(i, 255, 0, 0, 255)
						SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 0.9)
					}
					else if(GetClientTeam(i) == CS_TEAM_CT)
					{
						SetEntityHealth(i, 255)
						GivePlayerItem(i, "weapon_xm1014")
						GivePlayerItem(i, "item_assaultsuit")
					}
					
					GivePlayerItem(i, "weapon_knife")
				}
			}
		}
		case HNS_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					if(GetClientTeam(i) == CS_TEAM_T)
					{
						SetEntityRenderMode(i, RENDER_TRANSCOLOR)
						SetEntityRenderColor(i, 0, 0, 0, 50)
						GivePlayerItem(i, "weapon_flashbang")
					}
					else if(GetClientTeam(i) == CS_TEAM_CT)
					{
						WeaponsMenu(i)
					}
					
					GivePlayerItem(i, "weapon_knife")
				}
			}
		}
		case VIP_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					if(GetClientTeam(i) == CS_TEAM_T)
					{
						WeaponsMenu(i)
					}
					else if(GetClientTeam(i) == CS_TEAM_CT)
					{
						GivePlayerItem(i, "weapon_m4a1_silencer")
						GivePlayerItem(i, "weapon_usp_silencer")
						GivePlayerItem(i, "item_assaultsuit")
						SetEntityHealth(i, 255)
					}
					
					GivePlayerItem(i, "weapon_knife")
				}
			}
			
			g_VIP = GetRandomGuard()
			SetEntityHealth(g_VIP, 500)
			SetEntityModel(g_VIP, g_VIPDayModel)
			JB_SetGlow(g_VIP, 0, 0, 255, 255, 1)
			PrintHintTextToAll("%N is the VIP", g_VIP)
			PrintToChatAll("%s \x0E%N\x01 is the \x07VIP", g_Tag, g_VIP)
		}
	}
}

PrepareDMDay()
{
	g_SpecialDay = true
	
	PlayDing()
	SJD_OpenDoors()
	JB_RemoveSimon()
	Forward_OnSpecialDay()
	HookEvent("round_end", Event_RoundEnd)
	HookEvent("round_start", Event_RoundStart)
	SetConVarInt(FindConVar("mp_death_drop_gun"), 0)
	SetConVarInt(FindConVar("mp_teammates_are_enemies"), 1)
	SetHudTextParams(-1.0, 0.55, 4.0, 0, 255, 0, 255)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ShowHudText(i, 1, g_DMDays[g_GameMode])
			
			if(IsPlayerAlive(i))
			{
				StripPlayer(i)
				SetGodMode(i)
			}
		}
	}
	
	HookWeaponSwitch(DM_DAY)
	
	switch(g_GameMode)
	{
		case ZEUS_DAY:
		{
			SetConVarInt(FindConVar("mp_taser_recharge_time"), 1)
		}
		case FIRE_DAY:
		{
			SetConVarInt(FindConVar("sv_infinite_ammo"), 2)
		}
		case DEATHMATCH:
		{
			SetConVarInt(FindConVar("sv_infinite_ammo"), 2)
		}
		case NO_SCOPE_DAY:
		{
			HookPreThink()
			SetConVarInt(FindConVar("sv_infinite_ammo"), 2)
		}
		case SNOWBALL_DAY:
		{
			SetConVarInt(FindConVar("sv_infinite_ammo"), 2)
		}
		case SCOUTSMAN_DAY:
		{
			SetConVarInt(FindConVar("sv_infinite_ammo"), 2)
			SetConVarInt(FindConVar("weapon_accuracy_nospread"), 1)
		}
	}
	
	CreateCountdown(30)
	game_timer = CreateTimer(30.0, StartDMDay)
}

public Action:StartDMDay(Handle:timer)
{
	PlayDing()
	SJD_OpenDoors()
	SetRoundTime(GetConVarInt(g_cDMDayTime))
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			StripPlayer(i)
		}
	}
	
	CreateTimer(0.3, StartDMDayTimer)
	ClearTimer(game_timer)
}

public Action:StartDMDayTimer(Handle:timer)
{
	switch(g_GameMode)
	{
		case ZEUS_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					GivePlayerItem(i, "weapon_taser")
					GivePlayerItem(i, "weapon_knife")
					GivePlayerItem(i, "item_assaultsuit")
				}
			}
		}
		case FIRE_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					SetEntityHealth(i, 1)
					GivePlayerItem(i, "weapon_molotov")
					GivePlayerItem(i, "weapon_knife")
				}
			}
		}
		case DEATHMATCH:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					WeaponsMenu(i)
					GivePlayerItem(i, "weapon_knife")
				}
			}
		}
		case NO_SCOPE_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					GivePlayerItem(i, "weapon_awp")
					GivePlayerItem(i, "weapon_knife")
					GivePlayerItem(i, "item_assaultsuit")
				}
			}
		}
		case SNOWBALL_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					SetEntityHealth(i, 1)
					GivePlayerItem(i, "weapon_snowball")
					GivePlayerItem(i, "weapon_knife")
				}
			}
		}
		case SCOUTSMAN_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					GivePlayerItem(i, "weapon_ssg08")
					GivePlayerItem(i, "weapon_knife")
					GivePlayerItem(i, "item_assaultsuit")
				}
			}
		}
		case BOX_DAY:
		{
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					new fists = GivePlayerItem(i, "weapon_fists")
					EquipPlayerWeapon(i, fists)
				}
			}
		}
	}
}

PrepareSPDay()
{
	g_SpecialDay = true
	
	PlayDing()
	SJD_OpenDoors()
	JB_RemoveSimon()
	Forward_OnSpecialDay()
	HookEvent("round_end", Event_RoundEnd)
	HookEvent("round_start", Event_RoundStart)
	HookEvent("player_death", Event_PlayerDeath)
	SetConVarInt(FindConVar("mp_death_drop_gun"), 0)
	SetConVarInt(FindConVar("mp_teammates_are_enemies"), 1)
	SetHudTextParams(-1.0, 0.55, 4.0, 0, 255, 0, 255)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ShowHudText(i, 1, g_SPDays[g_GameMode])
			SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage)
			
			if(IsPlayerAlive(i))
			{
				StripPlayer(i)
				SetGodMode(i)
			}
		}
	}
	
	HookWeaponSwitch(SP_DAY)
	SetEntPropFloat(g_SP, Prop_Send, "m_flLaggedMovementValue", 0.0)
	SetEntityRenderMode(g_SP, RENDER_TRANSCOLOR)
	SetEntityRenderColor(g_SP, 0, 0, 0, 0)
	
	switch(g_GameMode)
	{
		case ALIEN_DAY:
		{
			SetConVarInt(FindConVar("sv_infinite_ammo"), 2)
		}
		case ZOMBIE_SP_DAY:
		{
			SetConVarInt(FindConVar("sv_infinite_ammo"), 2)
		}
	}
	
	CreateCountdown(30)
	game_timer = CreateTimer(30.0, StartSPDay)
}

public Action:StartSPDay(Handle:timer)
{
	PlayDing()
	SJD_OpenDoors()
	SetRoundTime(GetConVarInt(g_cSPDayTime))
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			StripPlayer(i)
		}
	}
	
	CreateTimer(0.3, StartSPDayTimer)
	ClearTimer(game_timer)
}

public Action:StartSPDayTimer(Handle:timer)
{
	switch(g_GameMode)
	{
		case ALIEN_DAY:
		{
			new count
			
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					if(i != g_SP)
					{
						count++
						WeaponsMenu(i)
						GivePlayerItem(i, "weapon_knife")
					}
				}
			}
			
			SetEntityGravity(g_SP, 0.5)
			SetEntityHealth(g_SP, 250*count)
			SetEntPropFloat(g_SP, Prop_Send, "m_flLaggedMovementValue", 1.3)
			SetEntityRenderMode(g_SP, RENDER_TRANSCOLOR)
			SetEntityRenderColor(g_SP, 0, 0, 0, 0)
			new ent = GivePlayerItem(g_SP, "weapon_knife")
			SetEntProp(GetEntPropEnt(ent, Prop_Send, "m_hWeaponWorldModel"), Prop_Send, "m_nModelIndex", -1)
		}
		case ZOMBIE_SP_DAY:
		{
			new count
			
			for(new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					if(i != g_SP)
					{
						count++
						WeaponsMenu(i)
						GivePlayerItem(i, "weapon_knife")
					}
				}
			}
			
			JB_SetLongJump(g_SP)
			JB_SetMultiJump(g_SP, 9)
			SetEntityHealth(g_SP, 250*count)
			GivePlayerItem(g_SP, "weapon_knife")
			SetEntityModel(g_SP, g_ZMDayModel)
			SetEntityRenderMode(g_SP, RENDER_TRANSCOLOR)
			SetEntityRenderColor(g_SP, 0, 0, 0, 255)
			JB_SetGlow(g_SP, 255, 0, 0, 0, 1)
		}
	}
}

WeaponsMenu(client)
{
	new Handle:menu = CreateMenu(w_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Weapons Menu:")
	
	AddMenuItem(menu, "0", "AWP + FiveN")
	AddMenuItem(menu, "1", "M4A1 + P250")
	AddMenuItem(menu, "2", "M4A4 + USP-S")
	AddMenuItem(menu, "3", "AK47 + Glock")
	AddMenuItem(menu, "4", "Nova + Deagle")
	AddMenuItem(menu, "5", "MP5-SD + Dualies")
	
	DisplayMenu(menu, client, 20)
}

public w_menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			new i = StringToInt(item)
			
			StripWeapons(client)
			GivePlayerItem(client, "weapon_knife")
			GivePlayerItem(client, g_Primary[i])
			GivePlayerItem(client, g_Secondary[i])
			GivePlayerItem(client, "item_assaultsuit")
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

StripPlayer(client)
{
	StripWeapons(client)
	SetEntityGravity(client, 1.0)
	SetEntProp(client, Prop_Send, "m_bHasHelmet", 0)
	SetEntProp(client, Prop_Data, "m_ArmorValue", 0, 1)
	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1)
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0)
}

StripWeapons(client)
{
	for(new i = 0; i < 6; i++)
	{
		new ent
		
		while((ent = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, ent)
			AcceptEntityInput(ent, "Kill")
		}
	}
}

FreezePlayers(team)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == team && IsPlayerAlive(i))
		{
			SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 0.0)
		}
	}
}

HookWeaponSwitch(day)
{
	if(day == TEAM_DAY)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKHook(i, SDKHook_WeaponSwitch, Hook_WSTeamDay)
			}
		}
	}
	else if(day == DM_DAY)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKHook(i, SDKHook_WeaponSwitch, Hook_WSDMDay)
			}
		}
	}
	else
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKHook(i, SDKHook_WeaponSwitch, Hook_WSSPDay)
			}
		}
	}
}

HookPreThink()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		{
			if(IsClientInGame(i))
			{
				SDKHook(i, SDKHook_PreThink, Hook_PreThink)
			}
		}
	}
}

SetGodMode(client)
{
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1)
}

Forward_OnSpecialDay()
{
	Call_StartForward(g_OnSpecialDay)
	Call_Finish()
}

CreateCountdown(cd_time)
{
	g_Countdown = (cd_time - 1)
	cd_timer = CreateTimer(1.0, CountdownTimer, _, TIMER_REPEAT)
}

public Action:CountdownTimer(Handle:timer)
{
	if(g_Countdown > 0)
	{
		PrintHintTextToAll("The game will start in: %d", g_Countdown)
	}
	else
	{
		PrintHintTextToAll("Play")
		ClearTimer(cd_timer)
	}
	
	g_Countdown--
}

GetRandomGuard()
{
	new count
	new clients[MaxClients + 1]
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i))
		{
			count++
			clients[count] = i
		}
	}
	
	return clients[GetRandomInt(1, count)]
}

GetWinner()
{
	new count
	new winner
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			count++
			winner = i
		}
	}
	
	if(count == 1)
	{
		return winner
	}
	else
	{
		return -1
	}
}

PlayDing()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ClientCommand(i, "playgamesound ambient/misc/brass_bell_c.wav")
		}
	}
}

SetRoundTime(seconds)
{
	GameRules_SetProp("m_iRoundTime", seconds, 4, 0, true)
}

CountConnectedPlayers()
{
	new count
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			count++
		}
	}
	
	return count
}

bool:HasVIPAccess(client)
{
	if(IsClientVIP(client))
	{
		return true
	}
	else
	{
		return false
	}
}

ClearTimer(&Handle:timer)
{
	if(timer != INVALID_HANDLE)
	{
		KillTimer(timer)
	}
	
	timer = INVALID_HANDLE
}