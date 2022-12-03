#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <jailbreak>

#define JUMP_BOOST 280.0

#define EF_BONEMERGE (1 << 0)
#define EF_NOSHADOW (1 << 4)
#define EF_NORECEIVESHADOW (1 << 6)

new const String:g_Tag[] = " \x04[Jailbreak]\x01"

new m_hOwnerEntity

new	g_Jumps[MAXPLAYERS + 1]
new	g_LastFlags[MAXPLAYERS + 1]
new g_MaxReJumps[MAXPLAYERS + 1]
new	g_LastButtons[MAXPLAYERS + 1]
new g_PlayerModels[MAXPLAYERS + 1]

new bool:g_Box
new bool:g_NoBlock
new bool:g_TerminateRound

new bool:g_LongJump[MAXPLAYERS + 1]
new bool:g_MultiJump[MAXPLAYERS + 1]
new bool:g_Regeneration[MAXPLAYERS + 1]
new bool:g_BFProtection[MAXPLAYERS + 1]

new Handle:lg_cooldown[MAXPLAYERS + 1] = {INVALID_HANDLE, ...}
new Handle:hr_cooldown[MAXPLAYERS + 1] = {INVALID_HANDLE, ...}
new Handle:re_cooldown[MAXPLAYERS + 1] = {INVALID_HANDLE, ...}

public Plugin:myinfo = 
{
	name = "Jailbreak Extra",
	author = "Vag",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/profiles/76561198855107628"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_box", CmdBox)
	RegConsoleCmd("sm_noblock", CmdNoBlock)
	
	RegAdminCmd("sm_setcolor", CmdSetColor, ADMFLAG_ROOT, "sm_setcolor <player> <red> <green> <blue> <alpha>")
	RegAdminCmd("sm_setglow", CmdSetGlow, ADMFLAG_ROOT, "sm_setglow <player> <red> <green> <blue> <alpha> <style>")
	RegAdminCmd("sm_removeglow", CmdRemoveGlow, ADMFLAG_ROOT, "sm_removeglow <player>")
	
	HookEvent("round_start", Event_RoundStart)
	HookEvent("player_hurt", Event_PlayerHurt)
	HookEvent("player_jump", Event_PlayerJump)
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("player_death", Event_PlayerDeath)
	
	m_hOwnerEntity = FindSendPropInfo("CBaseCombatWeapon", "m_hOwnerEntity")
	
	LoadTranslations("common.phrases")
}

public Action:OnPlayerRunCmd(client)
{
	if(g_MultiJump[client])
	{
		if(g_MaxReJumps[client] > 0)
		{
			MultiJump(client)
		}
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("JB_SetGlow", Native_SetGlow)
	CreateNative("JB_SetLongJump", Native_SetLongJump)
	CreateNative("JB_SetMultiJump", Native_SetMultiJump)
	CreateNative("JB_SetRegeneration", Native_SetRegeneration)
	CreateNative("JB_SetBFProtection", Native_SetBFProtection)

	RegPluginLibrary("jailbreak")
	
	return APLRes_Success
}

public Native_SetGlow(Handle:plugin, numParams)
{
	new client = GetNativeCell(1)
	new r = GetNativeCell(2)
	new g = GetNativeCell(3)
	new b = GetNativeCell(4)
	new a = GetNativeCell(5)
	new style = GetNativeCell(6)
	
	SetGlow(client, r, g, b, a, style)
}

public Native_SetLongJump(Handle:plugin, numParams)
{
	new client = GetNativeCell(1)
	
	g_LongJump[client] = true
}

public Native_SetMultiJump(Handle:plugin, numParams)
{
	new client = GetNativeCell(1)
	new jumps = GetNativeCell(2)
	
	g_MultiJump[client] = true
	g_MaxReJumps[client] = jumps
}

public Native_SetRegeneration(Handle:plugin, numParams)
{
	new client = GetNativeCell(1)
	
	g_Regeneration[client] = true
}

public Native_SetBFProtection(Handle:plugin, numParams)
{
	new client = GetNativeCell(1)
	
	g_BFProtection[client] = true
	
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamageBF)
}

public OnClientPutInServer(client)
{
	g_PlayerModels[client] = INVALID_ENT_REFERENCE
	
	if(g_Box)
	{
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamageBox)
	}
}

public Action:Hook_OnTakeDamageBox(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(attacker > 0 && IsClientInGame(attacker) && victim > 0 && IsClientInGame(victim))
	{
		if(GetClientTeam(attacker) == CS_TEAM_CT && GetClientTeam(victim) == CS_TEAM_CT && attacker != victim)
		{
			damage = 0.0
			
			return Plugin_Changed
		}
	}
	
	return Plugin_Continue
}

public Action:Hook_OnTakeDamageBF(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(victim > 0 && IsClientInGame(victim))
	{
		if(damagetype & DMG_BLAST || damagetype & DMG_BURN)
		{
			damage = 0.0
			
			return Plugin_Changed
		}
	}
	
	return Plugin_Continue
}

public Action:CmdBox(client, args)
{
	if(client != JB_GetSimon())
	{
		PrintToChat(client, "%s You don't have access to use this command", g_Tag)
		return Plugin_Handled
	}
	
	if(JB_IsFreeday() || JB_IsSpecialDay() || JB_IsLastRequest())
	{
		PrintToChat(client, "%s You can't use this command now", g_Tag)
		return Plugin_Handled
	}
	
	if(!g_Box)
	{
		g_Box = true
		
		PrintToChatAll("%s \x0E%N\x01 started Box", g_Tag, client)
		SetConVarInt(FindConVar("mp_teammates_are_enemies"), 1)
	}
	else
	{
		g_Box = false
		
		PrintToChatAll("%s \x0E%N\x01 stopped Box", g_Tag, client)
		SetConVarInt(FindConVar("mp_teammates_are_enemies"), 0)
	}
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(g_Box)
			{
				SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamageBox)
			}
			else
			{
				SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamageBox)
			}
			
			if(GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
			{
				SetEntityHealth(i, 100)
			}
		}
	}
	
	return Plugin_Handled
}

public Action:CmdNoBlock(client, args)
{
	if(!HasSimonAccess(client))
	{
		PrintToChat(client, "%s You don't have access to use this command", g_Tag)
		return Plugin_Handled
	}
	
	if(!g_NoBlock)
	{
		g_NoBlock = true
		
		SetConVarInt(FindConVar("mp_solid_teammates"), 0)
		PrintToChatAll("%s \x0E%N\x01 opened No Block", g_Tag, client)
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				SetEntProp(i, Prop_Data, "m_CollisionGroup", 2)
			}
		}
	}
	else
	{
		g_NoBlock = false
		
		SetConVarInt(FindConVar("mp_solid_teammates"), 1)
		PrintToChatAll("%s \x0E%N\x01 closed No Block", g_Tag, client)
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				SetEntProp(i, Prop_Data, "m_CollisionGroup", 5)
			}
		}
	}
	
	return Plugin_Handled
}

public Action:CmdSetColor(client, args)
{
	if(args < 5)
	{
		ReplyToCommand(client, "Usage: sm_setcolor <player> <red> <green> <blue> <alpha>")
		return Plugin_Handled
	}
	
	new String:szTarget[MAX_NAME_LENGTH]
	GetCmdArg(1, szTarget, sizeof(szTarget))
	
	new target = FindTarget(client, szTarget)
	
	if(target > 0 && IsClientInGame(target) && IsPlayerAlive(client))
	{
		new String:szRed[32]
		GetCmdArg(2, szRed, sizeof(szRed))
		
		new String:szGreen[32]
		GetCmdArg(3, szGreen, sizeof(szGreen))
		
		new String:szBlue[32]
		GetCmdArg(4, szBlue, sizeof(szBlue))
		
		new String:szAlpha[32]
		GetCmdArg(5, szAlpha, sizeof(szAlpha))
		
		new red = StringToInt(szRed)
		new green = StringToInt(szGreen)
		new blue = StringToInt(szBlue)
		new alpha = StringToInt(szAlpha)
		
		SetEntityRenderMode(target, RENDER_TRANSCOLOR)
		SetEntityRenderColor(target, red, green, blue, alpha)
	}
	
	return Plugin_Handled
}

public Action:CmdSetGlow(client, args)
{
	if(args < 6)
	{
		ReplyToCommand(client, "Usage: sm_setglow <player> <red> <green> <blue> <alpha> <style>")
		return Plugin_Handled
	}
	
	new String:szTarget[MAX_NAME_LENGTH]
	GetCmdArg(1, szTarget, sizeof(szTarget))
	
	new target = FindTarget(client, szTarget)
	
	if(target > 0 && IsClientInGame(target) && IsPlayerAlive(client))
	{
		new String:szRed[32]
		GetCmdArg(2, szRed, sizeof(szRed))
		
		new String:szGreen[32]
		GetCmdArg(3, szGreen, sizeof(szGreen))
		
		new String:szBlue[32]
		GetCmdArg(4, szBlue, sizeof(szBlue))
		
		new String:szAlpha[32]
		GetCmdArg(5, szAlpha, sizeof(szAlpha))
		
		new String:szStyle[32]
		GetCmdArg(6, szStyle, sizeof(szStyle))
		
		new red = StringToInt(szRed)
		new green = StringToInt(szGreen)
		new blue = StringToInt(szBlue)
		new alpha = StringToInt(szAlpha)
		new style = StringToInt(szStyle)
		
		SetGlow(target, red, green, blue, alpha, style)
	}
	
	return Plugin_Handled
}

public Action:CmdRemoveGlow(client, args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_removeglow <player>")
		return Plugin_Handled
	}
	
	new String:szTarget[MAX_NAME_LENGTH]
	GetCmdArg(1, szTarget, sizeof(szTarget))
	
	new target = FindTarget(client, szTarget)
	
	if(target > 0 && IsClientInGame(target))
	{
		RemoveGlow(target)
	}
	
	return Plugin_Handled
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	DisableHeal(false)
	
	g_TerminateRound = false
	
	if(g_Box)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamageBox)
			}
		}
		
		g_Box = false
		
		SetConVarInt(FindConVar("mp_teammates_are_enemies"), 0)
	}
	
	if(g_NoBlock)
	{
		g_NoBlock = false
		
		SetConVarInt(FindConVar("mp_solid_teammates"), 1)
	}
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"))
	
	if(g_Regeneration[victim])
	{
		if(IsPlayerAlive(victim))
		{
			ClearTimer(re_cooldown[victim])
			ClearTimer(hr_cooldown[victim])
			
			hr_cooldown[victim] = CreateTimer(5.0, RegenerateHealth, victim)
		}
	}
}

public Action:RegenerateHealth(Handle:timer, any:client)
{
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		SetGlow(client, 0, 255, 0, 255, 1)
		PrintToChat(client, "%s \x04Healing...", g_Tag)
		re_cooldown[client] = CreateTimer(1.0, RegenerateHP, client, TIMER_REPEAT)
		ClearTimer(hr_cooldown[client])
	}
	else
	{
		ClearTimer(hr_cooldown[client])
	}
}

public Action:RegenerateHP(Handle:timer, any:client)
{
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		new health = GetClientHealth(client)
		
		if((health + 5) < 150)
		{
			SetEntityHealth(client, health + 5)
		}
		else
		{
			RemoveGlow(client)
			SetEntityHealth(client, 150)
			ClearTimer(re_cooldown[client])
		}
	}
	else
	{
		ClearTimer(re_cooldown[client])
	}
}

public Event_PlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	
	if(g_LongJump[client]) 
	{
		if(lg_cooldown[client] == INVALID_HANDLE)
		{
			LongJump(client)
			
			lg_cooldown[client] = CreateTimer(2.0, LongJumpTimer, client)
		}
	}
}

public Action:LongJumpTimer(Handle:timer, any:client)
{
	if(client > 0 && IsClientInGame(client))
	{
		ClearTimer(lg_cooldown[client])
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	
	g_LongJump[client] = false
	g_MultiJump[client] = false
	g_Regeneration[client] = false
	
	if(g_BFProtection[client])
	{
		g_BFProtection[client] = false
		SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamageBF)
	}
	
	RemoveGlow(client)
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"))
	
	g_LongJump[victim] = false
	g_MultiJump[victim] = false
	g_Regeneration[victim] = false
	
	if(g_BFProtection[victim])
	{
		g_BFProtection[victim] = false
		SDKUnhook(victim, SDKHook_OnTakeDamage, Hook_OnTakeDamageBF)
	}
	
	RemoveGlow(victim)
	
	if(g_Box && !g_TerminateRound)
	{
		new guards
		new prisoners
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(GetClientTeam(i) == CS_TEAM_T)
				{
					prisoners++
				}
				else if(GetClientTeam(i) == CS_TEAM_CT)
				{
					guards++
				}
			}
		}
		
		if(prisoners == 0)
		{
			g_TerminateRound = true
			CS_TerminateRound(10.0, CSRoundEnd_CTWin)
		}
		else if(guards == 0)
		{
			g_TerminateRound = true
			CS_TerminateRound(10.0, CSRoundEnd_TerroristWin)
		}
	}
}

public JB_OnSpecialDay()
{
	g_Box = false
	g_NoBlock = true
	
	DisableHeal()
	RemoveDroppedGuns()
	SetConVarInt(FindConVar("mp_solid_teammates"), 0)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			RemoveGlow(i)
			CancelClientMenu(i, true)
			SetEntProp(i, Prop_Data, "m_CollisionGroup", 2)
			SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamageBox)
			
			g_LongJump[i] = false
			g_MultiJump[i] = false
			g_Regeneration[i] = false
			
			if(g_BFProtection[i])
			{
				g_BFProtection[i] = false
				SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamageBF)
			}
		}
	}
	
	if(JB_GetDayType() == 2 && JB_GetSpecialDay() == 4)
	{
		g_NoBlock = false
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SetEntProp(i, Prop_Data, "m_CollisionGroup", 5)
			}
		}
	}
}

public JB_OnLastRequest()
{
	g_Box = false
	g_NoBlock = false
	
	DisableHeal()
	RemoveDroppedGuns()
	SetConVarInt(FindConVar("mp_solid_teammates"), 1)
	SetConVarInt(FindConVar("mp_teammates_are_enemies"), 0)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			RemoveGlow(i)
			CancelClientMenu(i, true)
			SetEntProp(i, Prop_Data, "m_CollisionGroup", 5)
			SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamageBox)
			
			g_LongJump[i] = false
			g_MultiJump[i] = false
			g_Regeneration[i] = false
			
			if(g_BFProtection[i])
			{
				g_BFProtection[i] = false
				SDKUnhook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamageBF)
			}
		}
	}
}

LongJump(client)
{
	new Float:velocity[3]
	new Float:velocity0
	new Float:velocity1
	
	velocity0 = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]")
	velocity1 = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]")
	
	velocity[0] = (7.0 * velocity0) * (1.0 / 4.1)
	velocity[1] = (7.0 * velocity1) * (1.0 / 4.1)
	velocity[2] = 0.0
	
	SetEntPropVector(client, Prop_Send, "m_vecBaseVelocity", velocity)
}

MultiJump(client)
{
	new fCurFlags = GetEntityFlags(client), fCurButtons = GetClientButtons(client)
	
	if(g_LastFlags[client] & FL_ONGROUND)
	{
		if(!(fCurFlags & FL_ONGROUND) && !(g_LastButtons[client] & IN_JUMP) && fCurButtons & IN_JUMP)
		{
			OriginalJump(client)
		}
	}
	else if (fCurFlags & FL_ONGROUND)
	{
		Landed(client)
	}
	else if(!(g_LastButtons[client] & IN_JUMP) && fCurButtons & IN_JUMP)
	{
		ReJump(client)
	}
	
	g_LastFlags[client] = fCurFlags
	g_LastButtons[client] = fCurButtons
}

OriginalJump(client)
{
	g_Jumps[client]++
}

Landed(client)
{
	g_Jumps[client] = 0
}

ReJump(client)
{
	if(0 < g_Jumps[client] <= g_MaxReJumps[client])
	{
		g_Jumps[client]++
		new Float:vel[3]
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel)
		vel[2] = JUMP_BOOST
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel)
	}
}

SetGlow(client, red, green, blue, alpha, style)
{
	new String:szModel[PLATFORM_MAX_PATH]
	GetClientModel(client, szModel, sizeof(szModel))
	
	new skin = CreatePlayerModelProp(client, szModel)
	new offset = GetEntSendPropOffs(skin, "m_clrGlow")
	
	SetEntProp(skin, Prop_Send, "m_bShouldGlow", true, true)
	SetEntProp(skin, Prop_Send, "m_nGlowStyle", style)
	SetEntPropFloat(skin, Prop_Send, "m_flGlowMaxDist", 10000.0)
	
	SetEntData(skin, offset, red, _, true)
	SetEntData(skin, offset + 1, green, _, true)
	SetEntData(skin, offset + 2, blue, _, true)
	SetEntData(skin, offset + 3, alpha, _, true)
}

CreatePlayerModelProp(client, String:szModel[])
{
	RemoveGlow(client)
	
	new skin = CreateEntityByName("prop_dynamic_override")
	
	DispatchKeyValue(skin, "model", szModel)
	DispatchKeyValue(skin, "disablereceiveshadows", "1")
	DispatchKeyValue(skin, "disableshadows", "1")
	DispatchKeyValue(skin, "solid", "0")
	DispatchKeyValue(skin, "spawnflags", "256")
	SetEntProp(skin, Prop_Send, "m_CollisionGroup", 0)
	DispatchSpawn(skin)
	SetEntityRenderMode(skin, RENDER_TRANSALPHA)
	SetEntityRenderColor(skin, 0, 0, 0, 0)
	SetEntProp(skin, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW)
	SetVariantString("!activator")
	AcceptEntityInput(skin, "SetParent", client, skin)
	SetVariantString("primary")
	AcceptEntityInput(skin, "SetParentAttachment", skin, skin, 0)
	
	g_PlayerModels[client] = EntIndexToEntRef(skin)
	
	return skin
}

RemoveGlow(client)
{
	if(IsValidEntity(g_PlayerModels[client]))
	{
		AcceptEntityInput(g_PlayerModels[client], "Kill")
	}
	
	g_PlayerModels[client] = INVALID_ENT_REFERENCE
}

DisableHeal(bool:toggle = true)
{
	new ent
	
	while((ent = FindEntityByClassname(ent, "trigger_hurt")) != -1)
	{
		if(GetEntPropFloat(ent, Prop_Data, "m_flDamage") < 0)
		{
			if(toggle)
			{
				AcceptEntityInput(ent, "Disable")
			}
			else
			{
				AcceptEntityInput(ent, "Enable")
			}
		}
	}
}

RemoveDroppedGuns()
{
	new String:szWeapon[64]
	new max_ents = GetMaxEntities()
	
	for(new i = GetMaxClients(); i < max_ents; i++)
	{
		if(IsValidEdict(i) && IsValidEntity(i))
		{
			GetEdictClassname(i, szWeapon, sizeof(szWeapon))
			
			if((StrContains(szWeapon, "weapon_") != -1 || StrContains(szWeapon, "item_") != -1) && GetEntDataEnt2(i, m_hOwnerEntity) == -1)
			{
				RemoveEdict(i)
			}
		}
	}
}

bool:HasSimonAccess(client)
{
	if(client == JB_GetSimon() || GetUserAdmin(client) != INVALID_ADMIN_ID)
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