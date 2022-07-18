#include <zombie_escape>

// Defines
#define TASK_SHOWHUD 100
#define ID_SHOWHUD (taskid-TASK_SHOWHUD)

// Constants Change X,Y If you need (HUD & DHud)
const Float:HUD_SPECT_X = 0.01
const Float:HUD_SPECT_Y = 0.130
const Float:HUD_STATS_X = -1.0
const Float:HUD_STATS_Y = 0.86

// Colors
enum
{
	Red = 0,
	Green,
	Blue
}

// Variables
new g_iMsgSync
new g_iRankMode
new g_iHudInfoMode
new g_iZombieInfoColors[3]
new g_iHumanInfoColors[3]
new g_iSpecInfoColors[3]
new bool:g_bHudInfoCommas

// Forward allows register new natives.
public plugin_natives()
{
	register_native("ze_show_user_hud_info", "native_show_user_hud_info", 1)
	register_native("ze_hide_user_hud_info", "native_hide_user_hud_info", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Hud Information", ZE_VERSION, AUTHORS)
		
	// CVars
	new pCvarHudInfoMode = create_cvar("ze_hud_info_mode", "1")
	
	bind_pcvar_num(pCvarHudInfoMode, g_iHudInfoMode)
	bind_pcvar_num(create_cvar("ze_hud_info_commas", "1"), g_bHudInfoCommas)
	bind_pcvar_num(create_cvar("ze_hud_info_zombie_red", "255"), g_iZombieInfoColors[Red])
	bind_pcvar_num(create_cvar("ze_hud_info_zombie_green", "20"), g_iZombieInfoColors[Green])
	bind_pcvar_num(create_cvar("ze_hud_info_zombie_blue", "20"), g_iZombieInfoColors[Blue])
	bind_pcvar_num(create_cvar("ze_hud_info_human_red", "20"), g_iHumanInfoColors[Red])
	bind_pcvar_num(create_cvar("ze_hud_info_human_green", "20"), g_iHumanInfoColors[Green])
	bind_pcvar_num(create_cvar("ze_hud_info_human_blue", "255"), g_iHumanInfoColors[Blue])
	bind_pcvar_num(create_cvar("ze_hud_info_spec_red", "100"), g_iSpecInfoColors[Red])
	bind_pcvar_num(create_cvar("ze_hud_info_spec_green", "100"), g_iSpecInfoColors[Green])
	bind_pcvar_num(create_cvar("ze_hud_info_spec_blue", "100"), g_iSpecInfoColors[Blue])
	bind_pcvar_num(get_cvar_pointer("ze_speed_rank_mode"), g_iRankMode)

	hook_cvar_change(pCvarHudInfoMode, "fw_CVar_HudInfoModeChanged")

	// Static Values.
	g_iMsgSync = CreateHudSyncObj()
}

// Hook called when change value in cvar "ze_hud_info_mode"
public fw_CVar_HudInfoModeChanged(pCvar)
{
	// Remove all tasks.
	if (!g_iHudInfoMode)
	{
		for (new id = 1; id <= MaxClients; id++)
			remove_task(id+TASK_SHOWHUD)		
	}
	else
	{
		for (new id = 1; id <= MaxClients; id++)
			if (!task_exists(id+TASK_SHOWHUD)) set_task(1.0, "ShowHUD", id+TASK_SHOWHUD, _, _, "b")
	}
}

// Forward called when player join the server.
public client_putinserver(id)
{
	// Player is bot or HLTV?
	if(is_user_bot(id) || is_user_hltv(id) || !g_iHudInfoMode)
		return

	set_task(1.0, "ShowHUD", id+TASK_SHOWHUD, _, _, "b")
}

// Forward called when player disconnected from the server.
public client_disconnected(id)
{
	// Remove task.
	remove_task(id+TASK_SHOWHUD)
}

public ShowHUD(taskid)
{
	// Static's.
	static szName[MAX_NAME_LENGTH], szHealth[15], iPlayer

	iPlayer = ID_SHOWHUD

	if (!is_user_alive(iPlayer))
	{
		iPlayer = get_entvar(iPlayer, var_iuser2)
		
		if (!is_user_alive(iPlayer))
			return
	}
	
	if(iPlayer != ID_SHOWHUD)
	{
		get_user_name(iPlayer, szName, charsmax(szName))

		switch (g_iHudInfoMode) 
		{
			case 1: // HUD
			{
				set_hudmessage(g_iSpecInfoColors[Red], g_iSpecInfoColors[Green], g_iSpecInfoColors[Blue], HUD_SPECT_X, HUD_SPECT_Y, 0, 1.2, 1.1, 0.5, 0.6, -1)
				
				if (g_bHudInfoCommas)
				{
					AddCommas(get_user_health(iPlayer), szHealth, charsmax(szHealth))
					
					if (ze_is_user_zombie(iPlayer))
					{
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "ZOMBIE_SPEC_COMMAS", szName, szHealth, ze_get_escape_coins(iPlayer))
					}
					else if ((iPlayer == ze_get_escape_leader_id()) && (0 < g_iRankMode <= 2))
					{
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "HUMAN_SPEC_COMMAS_LEADER", szName, szHealth, ze_get_escape_coins(iPlayer))
					}
					else
					{
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "HUMAN_SPEC_COMMAS", szName, szHealth, ze_get_escape_coins(iPlayer))
					}
				}
				else
				{
					if (ze_is_user_zombie(iPlayer))
					{
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "ZOMBIE_SPEC", szName, get_user_health(iPlayer), ze_get_escape_coins(iPlayer))
					}
					else if ((iPlayer == ze_get_escape_leader_id()) && (0 < g_iRankMode <= 2))
					{
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "HUMAN_SPEC_LEADER", szName, get_user_health(iPlayer), ze_get_escape_coins(iPlayer))
					}
					else
					{
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "HUMAN_SPEC", szName, get_user_health(iPlayer), ze_get_escape_coins(iPlayer))
					}
				}
			}
			case 2: // DHUD
			{
				set_dhudmessage(g_iSpecInfoColors[Red], g_iSpecInfoColors[Green], g_iSpecInfoColors[Blue], HUD_SPECT_X, HUD_SPECT_Y, 0, 1.2, 1.1, 0.5, 0.6)
				
				if (g_bHudInfoCommas)
				{
					AddCommas(get_user_health(iPlayer), szHealth, charsmax(szHealth))
					
					if (ze_is_user_zombie(iPlayer))
					{
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "ZOMBIE_SPEC_COMMAS", szName, szHealth, ze_get_escape_coins(iPlayer))
					}
					else if ((iPlayer == ze_get_escape_leader_id()) && (0 < g_iRankMode <= 2))
					{
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "HUMAN_SPEC_COMMAS_LEADER", szName, szHealth, ze_get_escape_coins(iPlayer))
					}
					else
					{
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "HUMAN_SPEC_COMMAS", szName, szHealth, ze_get_escape_coins(iPlayer))
					}
				}
				else
				{
					if (ze_is_user_zombie(iPlayer))
					{
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "ZOMBIE_SPEC", szName, get_user_health(iPlayer), ze_get_escape_coins(iPlayer))
					}
					else if ((iPlayer == ze_get_escape_leader_id()) && (0 < g_iRankMode <= 2))
					{
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "HUMAN_SPEC_LEADER", szName, get_user_health(iPlayer), ze_get_escape_coins(iPlayer))
					}
					else
					{
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "HUMAN_SPEC", szName, get_user_health(iPlayer), ze_get_escape_coins(iPlayer))
					}
				}
			}
		}
	}
	else if (ze_is_user_zombie(iPlayer))
	{
		switch (g_iHudInfoMode)
		{
			case 1: // HUD
			{
				set_hudmessage(g_iZombieInfoColors[Red], g_iZombieInfoColors[Green], g_iZombieInfoColors[Blue], HUD_STATS_X, HUD_STATS_Y, 0, 1.2, 1.1, 0.5, 0.6, -1)
				
				if (g_bHudInfoCommas)
				{
					AddCommas(get_user_health(ID_SHOWHUD), szHealth, charsmax(szHealth))

					ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "ZOMBIE_COMMAS", szHealth, ze_get_escape_coins(ID_SHOWHUD))
				}
				else
				{
					ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "ZOMBIE", get_user_health(ID_SHOWHUD), ze_get_escape_coins(ID_SHOWHUD))
				}
			}
			case 2: // DHUD
			{
				set_dhudmessage(g_iZombieInfoColors[Red], g_iZombieInfoColors[Green], g_iZombieInfoColors[Blue], HUD_STATS_X, HUD_STATS_Y, 0, 1.2, 1.1, 0.5, 0.6)
				
				if (g_bHudInfoCommas)
				{
					AddCommas(get_user_health(ID_SHOWHUD), szHealth, charsmax(szHealth))
					
					show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "ZOMBIE_COMMAS", szHealth, ze_get_escape_coins(ID_SHOWHUD))
				}
				else
				{
					show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "ZOMBIE", get_user_health(ID_SHOWHUD), ze_get_escape_coins(ID_SHOWHUD))	
				}
			}
		}
	}
	else
	{
		switch (g_iHudInfoMode)
		{
			case 1: // HUD
			{
				set_hudmessage(g_iHumanInfoColors[Red], g_iHumanInfoColors[Green], g_iHumanInfoColors[Blue], HUD_STATS_X, HUD_STATS_Y, 0, 1.2, 1.1, 0.5, 0.6, -1)
				
				if (g_bHudInfoCommas)
				{
					if ((ID_SHOWHUD == ze_get_escape_leader_id()) && (0 < g_iRankMode <= 2))
					{
						AddCommas(get_user_health(ID_SHOWHUD), szHealth, charsmax(szHealth))
					
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "HUMAN_LEADER_COMMAS", szHealth, ze_get_escape_coins(ID_SHOWHUD))
					}
					else
					{
						AddCommas(get_user_health(ID_SHOWHUD), szHealth, charsmax(szHealth))
					
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "HUMAN_COMMAS", szHealth, ze_get_escape_coins(ID_SHOWHUD))
					}					
				}
				else
				{
					if ((ID_SHOWHUD == ze_get_escape_leader_id()) && (0 < g_iRankMode <= 2))
					{
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "HUMAN_LEADER", get_user_health(ID_SHOWHUD), ze_get_escape_coins(ID_SHOWHUD))
					}
					else
					{
						ShowSyncHudMsg(ID_SHOWHUD, g_iMsgSync, "%L", LANG_PLAYER, "HUMAN", get_user_health(ID_SHOWHUD), ze_get_escape_coins(ID_SHOWHUD))
					}					
				}
			}
			case 2: // DHUD
			{
				set_dhudmessage(g_iHumanInfoColors[Red], g_iHumanInfoColors[Green], g_iHumanInfoColors[Blue], HUD_STATS_X, HUD_STATS_Y, 0, 1.2, 1.1, 0.5, 0.6)
				
				if (g_bHudInfoCommas)
				{
					if ((ID_SHOWHUD == ze_get_escape_leader_id()) && (0 < g_iRankMode <= 2))
					{
						AddCommas(get_user_health(ID_SHOWHUD), szHealth, charsmax(szHealth))
					
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "HUMAN_LEADER_COMMAS", szHealth, ze_get_escape_coins(ID_SHOWHUD))
					}
					else
					{
						AddCommas(get_user_health(ID_SHOWHUD), szHealth, charsmax(szHealth))
					
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "HUMAN_COMMAS", szHealth, ze_get_escape_coins(ID_SHOWHUD))
					}
				}
				else
				{
					if ((ID_SHOWHUD == ze_get_escape_leader_id()) && (0 < g_iRankMode <= 2))
					{
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "HUMAN_LEADER", get_user_health(ID_SHOWHUD), ze_get_escape_coins(ID_SHOWHUD))
					}
					else
					{
						show_dhudmessage(ID_SHOWHUD, "%L", LANG_PLAYER, "HUMAN", get_user_health(ID_SHOWHUD), ze_get_escape_coins(ID_SHOWHUD))
					}
				}
			}			
		}
	}
}

/**
 * Natives.
 */
public native_show_user_hud_info(id)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error in server console.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}

	if (!task_exists(id+TASK_SHOWHUD))
	{
		set_task(1.0, "ShowHUD", id+TASK_SHOWHUD, _, _, "b")
	}

	return true
}

public native_hide_user_hud_info(id)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error in server console.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}	

	// Stop appear HUDs.
	ClearSyncHud(id, g_iMsgSync)
	remove_task(id+TASK_SHOWHUD)
	return true
}