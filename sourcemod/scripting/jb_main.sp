#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <jailbreak>

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new g_Simon
new g_Round
new g_Deputy

new Handle:g_cSimonModel
new Handle:g_cFreedayTimer

new String:g_SimonModel[128]

new bool:g_Freeday = false
new bool:g_PlayerFreeday[MAXPLAYERS + 1]

new Handle:g_OnFreeday = INVALID_HANDLE
new Handle:g_OnSimonRemove = INVALID_HANDLE

new Handle:fd_timer = INVALID_HANDLE
new Handle:pf_timer[MAXPLAYERS + 1] = {INVALID_HANDLE, ...}

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

public Plugin:myinfo = 
{
	name = "Jailbreak Main",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

native SJD_OpenDoors()

public OnPluginStart()
{
	RegConsoleCmd("sm_s", CmdSimon)
	RegConsoleCmd("sm_simon", CmdSimon)
	RegConsoleCmd("sm_deputy", CmdDeputy)
	RegConsoleCmd("sm_menu", CmdSimonMenu)
	RegConsoleCmd("sm_fd", CmdFreedayMenu)
	RegConsoleCmd("sm_freeday", CmdFreedayMenu)
	RegConsoleCmd("sm_open", CmdOpenCells)
	
	AddCommandListener(Hook_BuyAmmo, "buyammo2")
	
	RegAdminCmd("jb_setpv", CmdSetPV, ADMFLAG_ROOT, "jb_setpv <steamid> <key> <value>")
	RegAdminCmd("jb_getpv", CmdGetPV, ADMFLAG_ROOT, "jb_setpv <steamid> <key>")
	
	HookEvent("round_start", Event_RoundStart)
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("player_death", Event_PlayerDeath)
	
	g_cFreedayTimer = CreateConVar("jb_freeday_time", "120.0", "Freeday time", _, true, 0.0)
	g_cSimonModel = CreateConVar("jb_simon_model", "models/player/custom_player/kuristaja/agent_smith/smith.mdl", "Simon model")
	
	g_OnFreeday = CreateGlobalForward("JB_OnFreeday", ET_Ignore, Param_Cell)
	g_OnSimonRemove = CreateGlobalForward("JB_OnSimonRemove", ET_Ignore, Param_Cell)
	
	CreateTimer(1.0, HUD_Status, _, TIMER_REPEAT)
}

public OnMapStart()
{
	GetConVarString(g_cSimonModel, g_SimonModel, sizeof(g_SimonModel))
	PrecacheModel(g_SimonModel)
}

public OnClientDisconnect(client)
{
	if(client == g_Simon)
	{
		g_Simon = 0
		PrintToChatAll("%s The \x0ESimon\x01 has left the game, someone should replace him!", g_Tag)
	}
	
	if(client == g_Deputy)
	{
		g_Deputy = 0
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("JB_GetSimon", Native_GetSimon)
	CreateNative("JB_IsFreeday", Native_IsFreeday)
	CreateNative("JB_RemoveSimon", Native_RemoveSimon)

	RegPluginLibrary("jailbreak")
	
	return APLRes_Success
}

public Native_GetSimon(Handle:plugin, numParams)
{
	return g_Simon
}

public Native_IsFreeday(Handle:plugin, numParams)
{
	return g_Freeday
}

public Native_RemoveSimon(Handle:plugin, numParams)
{
	RemoveSimon()
}

public Action:CmdSimon(client, args)
{
	if(GetClientTeam(client) != CS_TEAM_CT)
	{
		PrintToChat(client, "%s You are not a \x0CGuard", g_Tag)
		return Plugin_Handled
	}
	
	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "%s You are not alive", g_Tag)
		return Plugin_Handled
	}
	
	if(g_Simon != 0)
	{
		PrintToChat(client, "%s There is already another \x0ESimon", g_Tag)
		return Plugin_Handled
	}
	
	if(g_Freeday || JB_IsSpecialDay() || JB_IsLastRequest())
	{
		PrintToChat(client, "%s You can't use this command now", g_Tag)
		return Plugin_Handled
	}
	
	g_Simon = client
	
	SetEntityModel(client, g_SimonModel)
	CS_SetClientClanTag(client, "[Simon]")
	PrintToChatAll("%s \x0E%N\x01 is the new \x0ESimon\x01, everyone should follow his orders!", g_Tag, client)
	
	return Plugin_Handled
}

public Action:CmdDeputy(client, args)
{
	if(GetClientTeam(client) != CS_TEAM_CT)
	{
		PrintToChat(client, "%s You are not a \x0CGuard", g_Tag)
		return Plugin_Handled
	}
	
	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "%s You are not alive", g_Tag)
		return Plugin_Handled
	}
	
	if(g_Simon == 0)
	{
		PrintToChat(client, "%s There is no \x0ESimon\x01 at the moment", g_Tag)
		return Plugin_Handled
	}
	
	if(g_Deputy != 0 || g_Deputy == g_Simon)
	{
		PrintToChat(client, "%s There is already another \x0EDeputy", g_Tag)
		return Plugin_Handled
	}
	
	if(g_Freeday || JB_IsSpecialDay() || JB_IsLastRequest())
	{
		PrintToChat(client, "%s You can't use this command now", g_Tag)
		return Plugin_Handled
	}
	
	g_Deputy = client
	
	return Plugin_Handled
}

public Action:CmdSimonMenu(client, args)
{
	if(client != g_Simon)
	{
		PrintToChat(client, "%s You don't have access to use this command", g_Tag)
		return Plugin_Handled
	}
	
	new Handle:menu = CreateMenu(menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Simon Menu:")
	
	AddMenuItem(menu, "1", "Open Cells")
	AddMenuItem(menu, "2", "Days Menu")
	AddMenuItem(menu, "3", "Freeday Menu")
	AddMenuItem(menu, "4", "Box")
	AddMenuItem(menu, "5", "No Block")
	AddMenuItem(menu, "6", "Voice Menu")
	
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
			
			switch(StringToInt(item))
			{
				case 1:
				{
					FakeClientCommand(client, "sm_open")
					FakeClientCommand(client, "sm_menu")
				}
				case 2:
				{
					FakeClientCommand(client, "sm_days")
				}
				case 3:
				{
					FakeClientCommand(client, "sm_freeday")
				}
				case 4:
				{
					FakeClientCommand(client, "sm_box")
					FakeClientCommand(client, "sm_menu")
				}
				case 5:
				{
					FakeClientCommand(client, "sm_noblock")
					FakeClientCommand(client, "sm_menu")
				}
				case 6:
				{
					FakeClientCommand(client, "sm_voice")
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

public Action:CmdFreedayMenu(client, args)
{
	if(!HasSimonAccess(client))
	{
		PrintToChat(client, "%s You don't have access to use this command", g_Tag)
		return Plugin_Handled
	}
	
	if(g_Freeday || JB_IsSpecialDay() || JB_IsLastRequest())
	{
		PrintToChat(client, "%s You can't use this command now", g_Tag)
		return Plugin_Handled
	}
	
	new Handle:menu = CreateMenu(fd_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Freeday Menu:")
	
	AddMenuItem(menu, "1", "Freeday For All")
	AddMenuItem(menu, "2", "Player Freeday")
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
	
	return Plugin_Handled
}

public fd_menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			switch(StringToInt(item))
			{
				case 1:
				{
					FreedayForAll()
					PrintToChatAll("%s \x0E%N\x01 started \x04Freeday For All", g_Tag, client)
				}
				case 2:
				{
					PlayerFreeday(client)
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

FreedayForAll()
{
	g_Freeday = true
	
	PlayDing()
	RemoveSimon()
	SJD_OpenDoors()
	Forward_OnFreeday()
	SetHudTextParams(-1.0, 0.55, 4.0, 0, 255, 0, 255)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ShowHudText(i, 1, "Freeday For All")
			
			if(GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
			{
				SetEntityRenderColor(i, 0, 255, 0, 255)
			}
		}
	}
	
	fd_timer = CreateTimer(GetConVarFloat(g_cFreedayTimer), FreedayForAllTimer)
}

public Action:FreedayForAllTimer(Handle:timer)
{
	g_Freeday = false
	
	PlayDing()
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
		{
			SetEntityRenderColor(i, 255, 255, 255, 255)
		}
	}
	
	PrintToChatAll("%s The \x04Freeday\x01 has ended", g_Tag)
	ClearTimer(fd_timer)
}

PlayerFreeday(client)
{
	new String:szUserID[12]
	new String:szName[MAX_NAME_LENGTH]
	
	new Handle:menu = CreateMenu(pfd_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Select Player:")
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
		{
			GetClientName(i, szName, sizeof(szName))
			IntToString(GetClientUserId(i), szUserID, sizeof(szUserID))
			
			if(!g_PlayerFreeday[i])
			{
				AddMenuItem(menu, szUserID, szName)
			}
			else
			{
				new String:szFormat[64]
				FormatEx(szFormat, sizeof(szFormat), "%s [Freeday]", szName)
				AddMenuItem(menu, szUserID, szFormat)
			}
		}
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public pfd_menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			new userid = StringToInt(item)
			new target = GetClientOfUserId(userid)
			
			if(target > 0 && IsClientInGame(target) && GetClientTeam(target) == CS_TEAM_T && IsPlayerAlive(target))
			{
				if(!g_PlayerFreeday[target])
				{
					g_PlayerFreeday[target] = true
					
					SetEntityRenderColor(target, 0, 255, 0, 255)
					PrintToChatAll("%s \x0E%N\x01 gave \x04Freeday\x01 to \x07%N", g_Tag, client, target)
					
					pf_timer[target] = CreateTimer(GetConVarFloat(g_cFreedayTimer), PlayerFreedayTimer, userid)
				}
				else
				{
					g_PlayerFreeday[target] = false
					
					SetEntityRenderColor(target, 255, 255, 255, 255)
					PrintToChatAll("%s \x0E%N\x01 ended the \x04Freeday\x01 of \x07%N", g_Tag, client, target)
					ClearTimer(pf_timer[target])
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

public Action:PlayerFreedayTimer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid)
	
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		g_PlayerFreeday[client] = false
		
		SetEntityRenderColor(client, 255, 255, 255, 255)
		PrintToChatAll("%s The \x04Freeday\x01 of \x07%N\x01 has ended", g_Tag, client)
	}
	
	ClearTimer(pf_timer[client])
}

public Action:CmdOpenCells(client, args)
{
	if(!HasSimonAccess(client))
	{
		PrintToChat(client, "%s You don't have access to use this command", g_Tag)
		return Plugin_Handled
	}
	
	SJD_OpenDoors()
	PrintToChatAll("%s \x0E%N\x01 opened the cells", g_Tag, client)
	
	return Plugin_Handled
}

public Action:Hook_BuyAmmo(client, const String:command[], args)
{
	FakeClientCommand(client, "sm_menu")
}

public Action:CmdSetPV(client, args)
{
	if(args < 3)
	{
		ReplyToCommand(client, "Usage: jb_setpv <steamid> <key> <value>")
		return Plugin_Handled
	}
	
	new String:szSteamID[32]
	GetCmdArg(1, szSteamID, sizeof(szSteamID))
	
	ReplaceString(szSteamID, sizeof(szSteamID), "STEAM_0", "STEAM_1")
	
	if(StrEqual(szSteamID, "STEAM_1") || !(StrContains(szSteamID, "STEAM_1") != -1))
	{
		ReplyToCommand(client, "This SteamID is not valid")
		return Plugin_Handled
	}
	
	new String:szPath[PLATFORM_MAX_PATH]
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
	
	if(FileExists(szPath))
	{
		new Handle:kv
		kv = CreateKeyValues("Data")
		
		FileToKeyValues(kv, szPath)
		
		new String:szKey[32]
		GetCmdArg(2, szKey, sizeof(szKey))
		
		new String:szValue[32]
		GetCmdArg(3, szValue, sizeof(szValue))
		
		new value = StringToInt(szValue)
		
		KvSetNum(kv, szKey, value)
		PrintToConsole(client, "%s new value is: %d for %s", szKey, value, szSteamID)
		
		KvRewind(kv)
		KeyValuesToFile(kv, szPath)
		
		CloseHandle(kv)
	}
	else
	{
		PrintToConsole(client, "%s not found", szSteamID)
	}
	
	return Plugin_Handled
}

public Action:CmdGetPV(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "Usage: jb_getpv <steamid> <key>")
		return Plugin_Handled
	}
	
	new String:szSteamID[32]
	GetCmdArg(1, szSteamID, sizeof(szSteamID))
	
	ReplaceString(szSteamID, sizeof(szSteamID), "STEAM_0", "STEAM_1")
	
	if(StrEqual(szSteamID, "STEAM_1") || !(StrContains(szSteamID, "STEAM_1") != -1))
	{
		ReplyToCommand(client, "This SteamID is not valid")
		return Plugin_Handled
	}
	
	new String:szPath[PLATFORM_MAX_PATH]
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/jailbreak/%s.txt", szSteamID)
	
	if(FileExists(szPath))
	{
		new Handle:kv
		kv = CreateKeyValues("Data")
		
		FileToKeyValues(kv, szPath)
		
		new String:szKey[32]
		GetCmdArg(2, szKey, sizeof(szKey))
		
		new value = KvGetNum(kv, szKey)
		
		PrintToConsole(client, "%s value is: %d for %s", szKey, value, szSteamID)
		
		CloseHandle(kv)
	}
	else
	{
		PrintToConsole(client, "%s not found", szSteamID)
	}
	
	return Plugin_Handled
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	RemoveSimon()
	
	g_Simon = -1
	g_Deputy = -1
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_Simon = -1
	g_Deputy = -1
	g_Freeday = false
	
	ClearTimer(fd_timer)
	
	if(GameRules_GetProp("m_bWarmupPeriod") != 1)
	{
		g_Round++
		
		CreateTimer(1.0, AllowSimon)
		
		if(g_Round == 1)
		{
			CreateTimer(1.0, FirstFreeday)
		}
	}
	else
	{
		g_Round = 0
	}
}

public Action:AllowSimon(Handle:timer)
{
	g_Simon = 0
	g_Deputy = 0
}

public Action:FirstFreeday(Handle:timer)
{
	FreedayForAll()
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	
	StripWeapons(client)
	GivePlayerItem(client, "weapon_knife")
	ClearTimer(pf_timer[client])
	
	g_PlayerFreeday[client] = false
	
	CreateTimer(0.1, PlayerSpawnTimer, GetClientUserId(client))
}

public Action:PlayerSpawnTimer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid)
	
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(GetClientTeam(client) == CS_TEAM_T)
		{
			CancelClientMenu(client, true)
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 0)
			SetEntProp(client, Prop_Data, "m_ArmorValue", 0, 1)
		}
		else if(GetClientTeam(client) == CS_TEAM_CT)
		{
			WeaponsMenu(client)
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 1)
			SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1)
		}
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"))
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"))
	
	CancelClientMenu(victim, true)
	ClearTimer(pf_timer[victim])
	
	g_PlayerFreeday[victim] = false
	
	if(!JB_IsSpecialDay() && !JB_IsLastRequest())
	{
		CheckLastRequest()
		
		if(GetClientTeam(victim) == CS_TEAM_CT)
		{
			if(GetClientTeam(attacker) == CS_TEAM_T)
			{
				SetEntityRenderColor(attacker, 255, 0, 0, 255)
				PrintToChatAll("%s \x07%N\x01 killed a \x0CGuard", g_Tag, attacker)
			}
			
			if(victim == g_Simon)
			{
				g_Simon = 0
				
				CS_SetClientClanTag(victim, "")
				PrintToChatAll("%s The \x0ESimon\x01 has died, someone should replace him!", g_Tag)
				
				if(g_Deputy > 0)
				{
					FakeClientCommand(g_Deputy, "sm_simon")
					g_Deputy = 0
				}
			}
			
			if(victim == g_Deputy)
			{
				g_Deputy = 0
			}
		}
	}
}

Forward_OnFreeday()
{
	Call_StartForward(g_OnFreeday)
	Call_Finish()
}

Forward_OnSimonRemove(client)
{
	Call_StartForward(g_OnSimonRemove)
	Call_PushCell(client)
	Call_Finish()
}

public Action:HUD_Status(Handle:timer)
{
	SetHudTextParams(0.0, 0.0, 1.0, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ShowHudText(i, 5, "Alive Prisoners: %d", CountAlivePrisoners())
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

RemoveSimon()
{
	if(g_Simon > 0)
	{
		CS_SetClientClanTag(g_Simon, "")
		Forward_OnSimonRemove(g_Simon)
		
		g_Simon = 0
	}
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

CheckLastRequest()
{
	new count
	new player
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
		{
			count++
			player = i
		}
	}
	
	if(count == 1)
	{
		FakeClientCommand(player, "sm_lastrequest")
	}
}

CountAlivePrisoners()
{
	new count
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
		{
			count++
		}
	}
	
	return count
}

bool:HasSimonAccess(client)
{
	if(client == g_Simon || GetUserAdmin(client) != INVALID_ADMIN_ID)
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