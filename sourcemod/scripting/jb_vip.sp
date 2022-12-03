#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <jailbreak>

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new bool:g_UsedVIP[MAXPLAYERS + 1]

new Handle:g_cEnableVIP

native bool:IsClientVIP(client)

public Plugin:myinfo = 
{
	name = "Jailbreak VIP",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_vmenu", CmdVIPMenu)
	RegConsoleCmd("sm_vipmenu", CmdVIPMenu)
	
	HookEvent("round_start", Event_RoundStart)
	
	g_cEnableVIP = CreateConVar("jb_enable_vipmenu", "1", "Enable VIP menu? [1 = Yes | 0 = No]", _, true, 0.0, true, 1.0)
}

public OnClientPutInServer(client)
{
	g_UsedVIP[client] = false
}

public Action:CmdVIPMenu(client, args)
{
	if(!GetConVarBool(g_cEnableVIP))
	{
		PrintToChat(client, "%s \x10VIP\x01 menu is disabled", g_Tag)
		return Plugin_Handled
	}
	
	if(!HasVIPAccess(client))
	{
		PrintToChat(client, "%s Only \x10VIP\x01 players can use this command", g_Tag)
		return Plugin_Handled
	}
	
	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "%s You are not alive", g_Tag)
		return Plugin_Handled
	}
	
	if(g_UsedVIP[client])
	{
		PrintToChat(client, "%s You already used the \x10VIP\x01 menu this round", g_Tag)
		return Plugin_Handled
	}
	
	if(JB_IsSpecialDay() || JB_IsLastRequest())
	{
		PrintToChat(client, "%s You can't use this command now", g_Tag)
		return Plugin_Handled
	}
	
	switch(GetClientTeam(client))
	{
		case CS_TEAM_T:
		{
			PrisonerVIPMenu(client)
		}
		case CS_TEAM_CT:
		{
			GuardVIPMenu(client)
		}
	}
	
	return Plugin_Handled
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		g_UsedVIP[i] = false
	}
}

PrisonerVIPMenu(client)
{
	new Handle:menu = CreateMenu(p_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "VIP Menu:")
	
	AddMenuItem(menu, "1", "Multi-Jump")
	AddMenuItem(menu, "2", "More Speed")
	AddMenuItem(menu, "3", "150HP + Armor")
	AddMenuItem(menu, "4", "Invisibility [70%]")
	AddMenuItem(menu, "5", "Deagle [33% Win Rate]")
	AddMenuItem(menu, "6", "AWP [20% Win Rate]")
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public p_menu_h(Handle:menu, MenuAction:action, client, param2)
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
					g_UsedVIP[client] = true
					JB_SetMultiJump(client, 3)
				}
				case 2:
				{
					g_UsedVIP[client] = true
					SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.3)
				}
				case 3:
				{
					g_UsedVIP[client] = true
					SetEntityHealth(client, 150)
					GivePlayerItem(client, "item_kevlar")
					ClientCommand(client, "play items/smallmedkit1")
				}
				case 4:
				{
					g_UsedVIP[client] = true
					SetEntityRenderMode(client, RENDER_TRANSCOLOR)
					SetEntityRenderColor(client, 255, 255, 255, 50)
					ClientCommand(client, "play ui/achievement_earned")
				}
				case 5:
				{
					g_UsedVIP[client] = true
					new num = GetRandomInt(1, 4)
					PrintToChatAll("%s \x07%N\x01 may has a \x04Deagle", g_Tag, client)
					
					if(num == 1)
					{
						GiveWeapon(client, "weapon_deagle", 7, CS_SLOT_SECONDARY)
						PrintToChat(client, "%s \x04Congrats, you won!", g_Tag)
						ClientCommand(client, "playgamesound training/pointscored.wav")
					}
					else
					{
						PrintToChat(client, "%s \x07You risked, you lost", g_Tag)
						ClientCommand(client, "playgamesound training/puck_fail.wav")
					}
				}
				case 6:
				{
					g_UsedVIP[client] = true
					new num = GetRandomInt(1, 8)
					PrintToChatAll("%s \x07%N\x01 may has an \x04AWP", g_Tag, client)
					
					if(num == 1)
					{
						GiveWeapon(client, "weapon_awp", 5, CS_SLOT_PRIMARY)
						PrintToChat(client, "%s \x04Congrats, you won!", g_Tag)
						ClientCommand(client, "playgamesound training/pointscored.wav")
					}
					else
					{
						PrintToChat(client, "%s \x07You risked, you lost", g_Tag)
						ClientCommand(client, "playgamesound training/puck_fail.wav")
					}
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

GuardVIPMenu(client)
{
	new Handle:menu = CreateMenu(g_menu_h, MenuAction_Select | MenuAction_End)
	SetMenuTitle(menu, "VIP Menu:")
	
	AddMenuItem(menu, "1", "Longjump")
	AddMenuItem(menu, "2", "Multi-Jump")
	AddMenuItem(menu, "3", "More Speed")
	AddMenuItem(menu, "4", "200HP + Armor")
	AddMenuItem(menu, "5", "Invisibility [70%]")
	AddMenuItem(menu, "6", "G3SG1 with 230 Bullets")
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER)
}

public g_menu_h(Handle:menu, MenuAction:action, client, param2)
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
					g_UsedVIP[client] = true
					JB_SetLongJump(client)
				}
				case 2:
				{
					g_UsedVIP[client] = true
					JB_SetMultiJump(client, 3)
				}
				case 3:
				{
					g_UsedVIP[client] = true
					SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.3)
				}
				case 4:
				{
					g_UsedVIP[client] = true
					SetEntityHealth(client, 200)
					GivePlayerItem(client, "item_assaultsuit")
					ClientCommand(client, "play items/smallmedkit1")
				}
				case 5:
				{
					g_UsedVIP[client] = true
					SetEntityRenderMode(client, RENDER_TRANSCOLOR)
					SetEntityRenderColor(client, 255, 255, 255, 50)
					ClientCommand(client, "play ui/achievement_earned")
				}
				case 6:
				{
					g_UsedVIP[client] = true
					GiveWeapon(client, "weapon_g3sg1", 998, CS_SLOT_PRIMARY)
				}
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu)
		}
	}
}

GiveWeapon(client, const String:szWeapon[], bullets, slot)
{
	new ent
	
	if((ent = GetPlayerWeaponSlot(client, slot)) != -1)
	{
		RemovePlayerItem(client, ent)
		AcceptEntityInput(ent, "Kill")
	}
	
	new weapon = GivePlayerItem(client, szWeapon)
	
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"))
	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0)
	SetEntProp(weapon, Prop_Send, "m_iClip1", bullets)
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