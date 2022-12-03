#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <jailbreak>

#define LR_DUEL 1
#define LR_S4S 2
#define LR_BOX 3
#define LR_NO_SCOPE 4
#define LR_GUN_TOSS 5

#define MAX_S4S_WEAPONS 10
#define MAX_DUEL_WEAPONS 12

#define MAX_HEALTH_CHOICES 5
#define MAX_BULLET_CHOICES 5

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new const String:g_WeaponNames[][] = 
{
	"SSG",
	"AWP",
	"USP-S",
	"MAG-7",
	"Deagle",
	"Revolver",
	"AK47",
	"M4A1-S",
	"MP5-SD",
	"XM1014",
	"Taser",
	"Snowball"
}

new const String:g_Weapons[][] = 
{
	"weapon_ssg08",
	"weapon_awp",
	"weapon_usp_silencer",
	"weapon_mag7",
	"weapon_deagle",
	"weapon_revolver",
	"weapon_ak47",
	"weapon_m4a1_silencer",
	"weapon_mp5sd",
	"weapon_xm1014",
	"weapon_taser",
	"weapon_snowball",
}

new g_Guard
new g_Prisoner

new g_GuardShots
new g_PrisonerShots

new g_LRType
new g_Selection
new g_Countdown

new g_HealthChoice
new g_BulletsChoice

new const g_Health[MAX_HEALTH_CHOICES] = {100, 125, 150, 200, 255}
new const g_Bullets[MAX_BULLET_CHOICES] = {1, 2, 3, 4, 5}

new bool:g_LastRequest

new Handle:lr_start = INVALID_HANDLE
new Handle:cd_timer = INVALID_HANDLE

new Handle:g_OnLastRequest = INVALID_HANDLE

native bool:IsClientVIP(client)

public Plugin:myinfo = 
{
	name = "Jailbreak Last Request",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_lr", CmdLastRequest)
	RegConsoleCmd("sm_lastrequest", CmdLastRequest)
	
	g_OnLastRequest = CreateGlobalForward("JB_OnLastRequest", ET_Ignore, Param_Cell)
}

public OnClientDisconnect(client)
{
	if(g_LastRequest)
	{
		if(client == g_Guard || client == g_Prisoner)
		{
			ClearLastRequest()
		}
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("JB_IsLastRequest", Native_IsLastRequest)

	RegPluginLibrary("jailbreak")
	
	return APLRes_Success
}

public Native_IsLastRequest(Handle:plugin, numParams)
{
	return g_LastRequest
}

public Action:CmdLastRequest(client, args)
{
	if(GetClientTeam(client) != CS_TEAM_T)
	{
		PrintToChat(client, "%s You are not a \x07Prisoner", g_Tag)
		return Plugin_Handled
	}
	
	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "%s You are not alive", g_Tag)
		return Plugin_Handled
	}
	
	if(!OnePrisonerAlive())
	{
		PrintToChat(client, "%s You are not the last alive \x07Prisoner", g_Tag)
		return Plugin_Handled
	}
	
	if(g_LastRequest || JB_IsSpecialDay())
	{
		PrintToChat(client, "%s You can't use this command now", g_Tag)
		return Plugin_Handled
	}
	
	LastRequestMenu(client)
	SetClientListeningFlags(client, VOICE_NORMAL)
	
	return Plugin_Handled
}

LastRequestMenu(client)
{
	new Handle:menu = CreateMenu(menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Last Request Menu:")
	
	AddMenuItem(menu, "1", "Classic Duel")
	AddMenuItem(menu, "2", "Shot4Shot")
	AddMenuItem(menu, "3", "Box Fight")
	AddMenuItem(menu, "4", "No-Scope")
	AddMenuItem(menu, "5", "Gun Toss")
	AddMenuItem(menu, "6", "Free 150$")
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			g_LRType = StringToInt(item)
			
			switch(StringToInt(item))
			{
				case 1:
				{
					WeaponsMenu(client)
				}
				case 2:
				{
					WeaponsMenu(client)
				}
				case 3:
				{
					SelectGuard(client)
				}
				case 4:
				{
					NoScope(client)
				}
				case 5:
				{
					SelectGuard(client)
				}
				case 6:
				{
					FreeMoney(client)
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

WeaponsMenu(client)
{
	new String:szItem[32]
	
	new Handle:menu = CreateMenu(w_menu_h, MenuAction_Select | MenuAction_End)
	
	if(g_LRType == LR_DUEL)
	{
		SetMenuTitle(menu, "Duel Menu:")
		
		for(new i = 0; i < MAX_DUEL_WEAPONS; i++)
		{
			IntToString(i, szItem, sizeof(szItem))
			AddMenuItem(menu, szItem, g_WeaponNames[i])
		}
	}
	else
	{
		SetMenuTitle(menu, "Shot4Shot Menu:")
		
		for(new i = 0; i < MAX_S4S_WEAPONS; i++)
		{
			IntToString(i, szItem, sizeof(szItem))
			AddMenuItem(menu, szItem, g_WeaponNames[i])
		}
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public w_menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			g_Selection = StringToInt(item)
			
			if(g_LRType == LR_DUEL)
			{
				if(g_Selection < MAX_S4S_WEAPONS)
				{
					DuelSettings(client)
				}
				else
				{
					SelectGuard(client)
				}
			}
			else
			{
				SelectGuard(client)
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

NoScope(client)
{
	new Handle:menu = CreateMenu(ns_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "No-Scope Menu:")
	
	AddMenuItem(menu, "1", "SSG")
	AddMenuItem(menu, "2", "AWP")
	AddMenuItem(menu, "3", "G3SG1")
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public ns_menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			g_Selection = StringToInt(item)
			
			SelectGuard(client)
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

DuelSettings(client)
{
	new Handle:menu = CreateMenu(ds_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Duel Settings:")
	
	if(HasVIPAccess(client))
	{
		new String:szFormat[32]
		FormatEx(szFormat, sizeof(szFormat), "Health: %d", g_Health[g_HealthChoice])
		AddMenuItem(menu, "1", szFormat)
		
		FormatEx(szFormat, sizeof(szFormat), "Bullets: %d", g_Bullets[g_BulletsChoice])
		AddMenuItem(menu, "2", szFormat)
	}
	else
	{
		new String:szFormat[32]
		FormatEx(szFormat, sizeof(szFormat), "Health: %d", g_Health[g_HealthChoice])
		AddMenuItem(menu, "1", szFormat, ITEMDRAW_DISABLED)
		
		FormatEx(szFormat, sizeof(szFormat), "Bullets: %d", g_Bullets[g_BulletsChoice])
		AddMenuItem(menu, "2", szFormat, ITEMDRAW_DISABLED)
	}
	
	AddMenuItem(menu, "3", "Continue")
	
	SetMenuExitButton(menu, false)
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public ds_menu_h(Handle:menu, MenuAction:action, client, param2)
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
					g_HealthChoice++
					
					if(g_HealthChoice == MAX_HEALTH_CHOICES)
					{
						g_HealthChoice = 0
					}
					
					DuelSettings(client)
				}
				case 2:
				{
					g_BulletsChoice++
					
					if(g_BulletsChoice == MAX_BULLET_CHOICES)
					{
						g_BulletsChoice = 0
					}
					
					DuelSettings(client)
				}
				case 3:
				{
					SelectGuard(client)
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

SelectGuard(client)
{
	new String:szUserID[32]
	new String:szName[MAX_NAME_LENGTH]
	
	new Handle:menu = CreateMenu(guard_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "Select Player:")
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i))
		{
			GetClientName(i, szName, sizeof(szName))
			IntToString(GetClientUserId(i), szUserID, sizeof(szUserID))
			AddMenuItem(menu, szUserID, szName)
		}
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public guard_menu_h(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			new String:item[64]
			GetMenuItem(menu, param2, item, sizeof(item))
			
			new target = GetClientOfUserId(StringToInt(item))
			
			if(target > 0 && IsClientInGame(target))
			{
				g_Guard = target
				g_Prisoner = client
				
				ProceedLastRequest()
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

ProceedLastRequest()
{
	if(IsPlayerAlive(g_Guard) && IsPlayerAlive(g_Prisoner))
	{
		g_LastRequest = true
		
		StripPlayer(g_Guard)
		StripPlayer(g_Prisoner)
		
		SetEntityRenderColor(g_Guard, 0, 0, 255, 255)
		SetEntityRenderColor(g_Prisoner, 255, 0, 0, 255)
		
		HookTakeDamage()
		JB_RemoveSimon()
		Forward_OnLastRequest()
		HookEvent("round_start", Event_RoundStart)
		HookEvent("weapon_fire", Event_WeaponFire)
		HookEvent("player_death", Event_PlayerDeath)
		
		new String:szMessage[64]
		
		switch(g_LRType)
		{
			case LR_DUEL:
			{
				if(g_Selection < MAX_S4S_WEAPONS)
				{
					FormatEx(szMessage, sizeof(szMessage), "%s Duel\nBullets: %d\nHealth: %d", g_WeaponNames[g_Selection], g_Bullets[g_BulletsChoice], g_Health[g_HealthChoice])
				}
				else
				{
					FormatEx(szMessage, sizeof(szMessage), "%s Duel", g_WeaponNames[g_Selection])
				}
			}
			case LR_S4S:
			{
				FormatEx(szMessage, sizeof(szMessage), "%s Shot4Shot", g_WeaponNames[g_Selection])
			}
			case LR_BOX:
			{
				FormatEx(szMessage, sizeof(szMessage), "Box")
			}
			case LR_NO_SCOPE:
			{
				switch(g_Selection)
				{
					case 1:
					{
						FormatEx(szMessage, sizeof(szMessage), "SSG No-Scope")
					}
					case 2:
					{
						FormatEx(szMessage, sizeof(szMessage), "AWP No-Scope")
					}
					case 3:
					{
						FormatEx(szMessage, sizeof(szMessage), "G3SG1 No-Scope")
					}
				}
			}
			case LR_GUN_TOSS:
			{
				FormatEx(szMessage, sizeof(szMessage), "Gun Toss")
			}
		}
		
		CreateCountdown(4)
		ShowHudTextToAll(szMessage)
		
		lr_start = CreateTimer(4.0, StartLastRequest)
	}
}

ShowHudTextToAll(const String:message[])
{
	SetHudTextParams(-1.0, 0.55, 4.0, 0, 255, 0, 255)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ShowHudText(i, 1, message)
		}
	}
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	ClearLastRequest()
}

public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	
	switch(g_LRType)
	{
		case LR_DUEL:
		{
			if(client == g_Guard)
			{
				g_GuardShots++
				
				if(g_GuardShots == g_Bullets[g_BulletsChoice])
				{
					g_GuardShots = 0
					
					new weapon = GetEntPropEnt(g_Guard, Prop_Send, "m_hActiveWeapon")
					SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", g_Bullets[g_BulletsChoice])
				}
			}
			else if(client == g_Prisoner)
			{
				g_PrisonerShots++
				
				if(g_PrisonerShots == g_Bullets[g_BulletsChoice])
				{
					g_PrisonerShots = 0
					
					new weapon = GetEntPropEnt(g_Prisoner, Prop_Send, "m_hActiveWeapon")
					SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", g_Bullets[g_BulletsChoice])
				}
			}
		}
		case LR_S4S:
		{
			if(client == g_Guard)
			{
				new weapon = GetEntPropEnt(g_Prisoner, Prop_Send, "m_hActiveWeapon")
				SetEntProp(weapon, Prop_Send, "m_iClip1", 1)
			}
			else if(client == g_Prisoner)
			{
				new weapon = GetEntPropEnt(g_Guard, Prop_Send, "m_hActiveWeapon")
				SetEntProp(weapon, Prop_Send, "m_iClip1", 1)
			}
		}
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"))
	
	if(victim == g_Guard || victim == g_Prisoner)
	{
		ClearLastRequest()
	}
}

public Action:StartLastRequest(Handle:timer)
{
	PlayDing()
	StripWeapons(g_Guard)
	StripWeapons(g_Prisoner)
	
	SDKHook(g_Guard, SDKHook_WeaponSwitch, Hook_WeaponSwitch)
	SDKHook(g_Prisoner, SDKHook_WeaponSwitch, Hook_WeaponSwitch)
	
	switch(g_LRType)
	{
		case LR_DUEL:
		{
			g_GuardShots = 0
			g_PrisonerShots = 0
			
			PrepareDuel(g_Guard, g_Health[g_HealthChoice], g_Bullets[g_BulletsChoice], g_Weapons[g_Selection])
			PrepareDuel(g_Prisoner, g_Health[g_HealthChoice], g_Bullets[g_BulletsChoice], g_Weapons[g_Selection])
			
			if(g_Selection >= MAX_S4S_WEAPONS)
			{
				UnhookEvent("weapon_fire", Event_WeaponFire)
				SetConVarInt(FindConVar("sv_infinite_ammo"), 2)
				SetConVarInt(FindConVar("mp_taser_recharge_time"), 2)
				
				if(g_Selection == MAX_DUEL_WEAPONS - 1)
				{
					SetEntityHealth(g_Guard, 1)
					SetEntityHealth(g_Prisoner, 1)
					
					GivePlayerItem(g_Guard, "weapon_knife")
					GivePlayerItem(g_Prisoner, "weapon_knife")
				}
			}
			
			SetConVarInt(FindConVar("mp_death_drop_gun"), 0)
		}
		case LR_S4S:
		{
			new num = GetRandomInt(0, 1)
			
			switch(num)
			{
				case 0:
				{
					PrepareS4S(g_Guard, g_Weapons[g_Selection], false)
					PrepareS4S(g_Prisoner, g_Weapons[g_Selection], true)
				}
				case 1:
				{
					PrepareS4S(g_Guard, g_Weapons[g_Selection], true)
					PrepareS4S(g_Prisoner, g_Weapons[g_Selection], false)
				}
			}
			
			SetConVarInt(FindConVar("mp_death_drop_gun"), 0)
		}
		case LR_BOX:
		{
			new f1 = GivePlayerItem(g_Guard, "weapon_fists")
			EquipPlayerWeapon(g_Guard, f1)
			
			new f2 = GivePlayerItem(g_Prisoner, "weapon_fists")
			EquipPlayerWeapon(g_Prisoner, f2)
		}
		case LR_NO_SCOPE:
		{
			switch(g_Selection)
			{
				case 1:
				{
					GivePlayerItem(g_Guard, "weapon_ssg08")
					GivePlayerItem(g_Prisoner, "weapon_ssg08")
				}
				case 2:
				{
					GivePlayerItem(g_Guard, "weapon_awp")
					GivePlayerItem(g_Prisoner, "weapon_awp")
				}
				case 3:
				{
					GivePlayerItem(g_Guard, "weapon_g3sg1")
					GivePlayerItem(g_Prisoner, "weapon_g3sg1")
				}
			}
			
			SDKHook(g_Guard, SDKHook_PreThink, Hook_PreThink)
			SDKHook(g_Prisoner, SDKHook_PreThink, Hook_PreThink)
			
			GivePlayerItem(g_Guard, "item_kevlar")
			GivePlayerItem(g_Prisoner, "item_kevlar")
			
			GivePlayerItem(g_Guard, "weapon_knife")
			GivePlayerItem(g_Prisoner, "weapon_knife")
			
			SetConVarInt(FindConVar("sv_infinite_ammo"), 1)
			SetConVarInt(FindConVar("mp_death_drop_gun"), 0)
		}
		case LR_GUN_TOSS:
		{
			PrepareGunToss(g_Guard, 0, 255)
			PrepareGunToss(g_Prisoner, 255, 0)
		}
	}
	
	ClearTimer(lr_start)
}

public Action:Hook_PreThink(client)
{
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")
	
	if(IsValidEdict(weapon))
	{
		new String:szWeapon[32]
		GetEdictClassname(weapon, szWeapon, sizeof(szWeapon))
		
		if(StrEqual(szWeapon, "weapon_awp") || StrEqual(szWeapon, "weapon_ssg08") || StrEqual(szWeapon, "weapon_g3sg1"))
		{
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 2.0)
		}
	}
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if((attacker == g_Guard && victim == g_Prisoner) || (attacker == g_Prisoner && victim == g_Guard))
	{
		return Plugin_Continue
	}
	else
	{
		damage = 0.0
		
		return Plugin_Changed
	}
}

public Action:Hook_WeaponSwitch(client, weapon)
{
	new String:szWeapon[32]
	GetEdictClassname(weapon, szWeapon, sizeof(szWeapon))
	
	new weaponindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex")
	
	switch(weaponindex)
	{
		case 23: strcopy(szWeapon, sizeof(szWeapon), "weapon_mp5sd")
		case 60: strcopy(szWeapon, sizeof(szWeapon), "weapon_m4a1_silencer")
		case 61: strcopy(szWeapon, sizeof(szWeapon), "weapon_usp_silencer")
		case 64: strcopy(szWeapon, sizeof(szWeapon), "weapon_revolver")
	}
	
	switch(g_LRType)
	{
		case LR_DUEL:
		{
			if(g_Selection <= MAX_S4S_WEAPONS)
			{
				if(!StrEqual(szWeapon, g_Weapons[g_Selection]))
				{
					return Plugin_Stop
				}
			}
			else if(g_Selection == MAX_DUEL_WEAPONS - 1)
			{
				if(!StrEqual(szWeapon, g_Weapons[g_Selection]) && !StrEqual(szWeapon, "weapon_knife"))
				{
					return Plugin_Stop
				}
			}
		}
		case LR_S4S:
		{
			if(!StrEqual(szWeapon, g_Weapons[g_Selection]))
			{
				return Plugin_Stop
			}
		}
		case LR_BOX:
		{
			if(!StrEqual(szWeapon, "weapon_fists"))
			{
				return Plugin_Stop
			}
		}
		case LR_NO_SCOPE:
		{
			switch(g_Selection)
			{
				case 1:
				{
					if(!StrEqual(szWeapon, "weapon_ssg08") && !StrEqual(szWeapon, "weapon_knife"))
					{
						return Plugin_Stop
					}
				}
				case 2:
				{
					if(!StrEqual(szWeapon, "weapon_awp") && !StrEqual(szWeapon, "weapon_knife"))
					{
						return Plugin_Stop
					}
				}
				case 3:
				{
					if(!StrEqual(szWeapon, "weapon_g3sg1") && !StrEqual(szWeapon, "weapon_knife"))
					{
						return Plugin_Stop
					}
				}
			}
		}
	}
	
	return Plugin_Continue
}

PrepareDuel(client, health, bullets, const String:szWeapon[])
{
	SetEntityHealth(client, health)
	GivePlayerItem(client, "item_kevlar")
	
	new weapon = GivePlayerItem(client, szWeapon)
	
	if(g_Selection < MAX_S4S_WEAPONS)
	{
		SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"))
		SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0)
		SetEntProp(weapon, Prop_Send, "m_iClip1", bullets)
	}
}

PrepareS4S(client, const String:szWeapon[], bool:first)
{
	GivePlayerItem(client, "item_kevlar")
	
	new weapon = GivePlayerItem(client, szWeapon)
	
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"))
	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0)
	
	if(first)
	{
		SetEntProp(weapon, Prop_Send, "m_iClip1", 1)
		PrintToChatAll("%s \x0E%N\x07 will fire the first bullet", g_Tag, client)
	}
	else
	{
		SetEntProp(weapon, Prop_Send, "m_iClip1", 0)
	}
}

PrepareGunToss(client, red, blue)
{
	new weapon = GivePlayerItem(client, "weapon_deagle")
	
	SetEntityHealth(client, 100)
	GivePlayerItem(client, "weapon_knife")
	
	SetEntityRenderColor(weapon, red, 0, blue, 255)
	SetEntityRenderColor(weapon, red, 0, blue, 255)
	
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"))
	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0)
	SetEntProp(weapon, Prop_Send, "m_iClip1", 0)
}

FreeMoney(client)
{
	ForcePlayerSuicide(client)
	PrintToChatAll("%s \x0E%N\x01 chose the easy money", g_Tag, client)
	JB_SetClientDollars(client, JB_GetClientDollars(client) + 150)
}

Forward_OnLastRequest()
{
	Call_StartForward(g_OnLastRequest)
	Call_Finish()
}

ClearLastRequest()
{
	g_LastRequest = false
	
	HookTakeDamage(false)
	
	SDKUnhook(g_Guard, SDKHook_PreThink, Hook_PreThink)
	SDKUnhook(g_Prisoner, SDKHook_PreThink, Hook_PreThink)
	
	SDKUnhook(g_Guard, SDKHook_WeaponSwitch, Hook_WeaponSwitch)
	SDKUnhook(g_Prisoner, SDKHook_WeaponSwitch, Hook_WeaponSwitch)
	
	SDKUnhook(g_Guard, SDKHook_OnTakeDamage, Hook_OnTakeDamage)
	SDKUnhook(g_Prisoner, SDKHook_OnTakeDamage, Hook_OnTakeDamage)
	
	SetConVarInt(FindConVar("sv_infinite_ammo"), 0)
	SetConVarInt(FindConVar("mp_death_drop_gun"), 1)
	SetConVarInt(FindConVar("mp_taser_recharge_time"), -1)
	
	UnhookEvent("round_start", Event_RoundStart)
	UnhookEvent("player_death", Event_PlayerDeath)
	
	if(g_Selection < MAX_S4S_WEAPONS)
	{
		UnhookEvent("weapon_fire", Event_WeaponFire)
	}
	
	g_Guard = 0
	g_Prisoner = 0
	g_LRType = 0
	
	g_Selection = 0
	g_Countdown = 0
	
	g_HealthChoice = 0
	g_BulletsChoice = 0
	
	ClearTimer(lr_start)
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
		PrintHintTextToAll("Last Request starts in: %d", g_Countdown)
	}
	else
	{
		PrintHintTextToAll("Fight")
		ClearTimer(cd_timer)
	}
	
	g_Countdown--
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

ClearTimer(&Handle:timer)
{
	if(timer != INVALID_HANDLE)
	{
		KillTimer(timer)
	}
	
	timer = INVALID_HANDLE
}

HookTakeDamage(bool:state = true)
{
	if(state)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage)
			}
		}
	}
	else
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage)
			}
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

bool:OnePrisonerAlive()
{
	new count
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
		{
			count++
		}
	}
	
	if(count == 1)
	{
		return true
	}
	else
	{
		return false
	}
}