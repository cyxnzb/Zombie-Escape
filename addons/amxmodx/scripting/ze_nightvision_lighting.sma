#include <zombie_escape>

// Constants.
const TASK_ID = 100

// Variables
new g_iZombieNVisionDensity,
	g_iZombieNVisionColors[3],
	bool:g_bNightVision,
	bool:g_bAutoNightVision,
	bool:g_bNvgOn[MAX_PLAYERS+1],
	Float:g_flLastNvgToggle[MAX_PLAYERS+1],
	g_szCurLightStyle[2] 

// Cvars
new g_pCvarZombieNVission, 
	g_pCvarZombieAutoNVision, 
	g_pCvarNVisionDensity,
	g_pCvarZombieNVisionColors[3],
	g_pCvarLightingStyle
	
// Colors
enum
{
	Red = 0,
	Green,
	Blue
}

public plugin_init()
{
	register_plugin("[ZE] Nightvision/Lighting", ZE_VERSION, AUTHORS)
	
	// Hook Chains
	RegisterHookChain(RG_CBasePlayer_Killed, "Fw_PlayerKilled_Post", 1)
	
	// Commands
	register_clcmd("nightvision", "Cmd_NvgToggle")
	
	// Cvars
	g_pCvarZombieNVission 				= register_cvar("ze_zombie_nightvision", "1")
	g_pCvarZombieAutoNVision 			= register_cvar("ze_zombie_auto_nightvision", "1")
	g_pCvarNVisionDensity 				= register_cvar("ze_zombie_nightvision_density", "70")
	g_pCvarZombieNVisionColors[Red] 	= register_cvar("ze_zombie_nvision_red", "253")
	g_pCvarZombieNVisionColors[Green] 	= register_cvar("ze_zombie_nvision_green", "110")
	g_pCvarZombieNVisionColors[Blue] 	= register_cvar("ze_zombie_nvision_blue", "110")
	g_pCvarLightingStyle 				= register_cvar("ze_lighting_style", "d")

	bind_pcvar_num(g_pCvarZombieNVission, g_bNightVision)
	bind_pcvar_num(g_pCvarZombieAutoNVision, g_bAutoNightVision)
	bind_pcvar_num(g_pCvarNVisionDensity, g_iZombieNVisionDensity)
	bind_pcvar_num(g_pCvarZombieNVisionColors[Red], g_iZombieNVisionColors[Red])
	bind_pcvar_num(g_pCvarZombieNVisionColors[Green], g_iZombieNVisionColors[Green])
	bind_pcvar_num(g_pCvarZombieNVisionColors[Blue], g_iZombieNVisionColors[Blue])
	bind_pcvar_string(g_pCvarLightingStyle, g_szCurLightStyle, charsmax(g_szCurLightStyle))

	hook_cvar_change(g_pCvarZombieNVission, "fw_CvarChange_Post")
	hook_cvar_change(g_pCvarZombieAutoNVision, "fw_CvarChange_Post")
	hook_cvar_change(g_pCvarNVisionDensity, "fw_CvarChange_Post")
	hook_cvar_change(g_pCvarZombieNVisionColors[Red], "fw_CvarChange_Post")
	hook_cvar_change(g_pCvarZombieNVisionColors[Green], "fw_CvarChange_Post")
	hook_cvar_change(g_pCvarZombieNVisionColors[Blue], "fw_CvarChange_Post")
	hook_cvar_change(g_pCvarLightingStyle, "fw_CvarChange_Post")
}

// Hook called when change value in NightVision cvars.
public fw_CvarChange_Post(pCvar, const szOld_Value[], const szNew_Value[])
{
	// ze_zombie_nightvision
	if (pCvar == g_pCvarZombieNVission)
	{
		// Nightvision has Enabled?
		g_bNightVision = (str_to_num(szNew_Value) != 0) ? true : false
		return // Prevent execute rest of code.
	}

	// ze_zombie_auto_nightvision
	if (pCvar == g_pCvarZombieAutoNVision)
	{
		// Auto nightivision is Enabled?
		g_bAutoNightVision = (str_to_num(szNew_Value) != 0) ? true : false
		return // Prevent execute rest of code.
	}

	// ze_lighting_style
	if (pCvar == g_pCvarLightingStyle)
	{
		// Set all players new map light style.
		setMapLightStyle(szNew_Value)
		copy(g_szCurLightStyle, charsmax(g_szCurLightStyle), szNew_Value)
		return // Prevent execute rest of code.
	}

	// ze_zombie_nvision_colors and density.
	if (pCvar == g_pCvarZombieNVisionColors[Red])
		g_iZombieNVisionColors[Red] = str_to_num(szNew_Value)
	else if (pCvar == g_pCvarZombieNVisionColors[Green])
		g_iZombieNVisionColors[Green] = str_to_num(szNew_Value)
	else if (pCvar == g_pCvarZombieNVisionColors[Blue])
		g_iZombieNVisionColors[Blue] = str_to_num(szNew_Value)
	else if (pCvar == g_pCvarNVisionDensity)
		g_iZombieNVisionDensity = str_to_num(szNew_Value)
}

// Forward called when player join the server.
public client_putinserver(id)
{
	set_task(0.1, "delaySet", id)
}

// Forward called after player disconnected from server.
public client_disconnected(id)
{
	// Reset Variables.
	g_bNvgOn[id] = false
	g_flLastNvgToggle[id] = 0.0
}

public delaySet(id)
{
	// Set map light stlye.
	Set_MapLightStyle(id, g_szCurLightStyle)
}

// Forward called when player become Human.
public ze_user_humanized(id)
{
	// Unset player NVision.
	g_bNvgOn[id] = false
	Set_NightVision(id)
	Set_MapLightStyle(id, g_szCurLightStyle)
}

// Forward called after player infected
public ze_user_infected(iVictim, iInfector)
{
	if (g_bAutoNightVision)
	{
		// Set player Nightvision 
		Set_MapLightStyle(iVictim, "z")
		Set_NightVision(iVictim, 0, 0, 0x0004, g_iZombieNVisionColors[Red], g_iZombieNVisionColors[Green], g_iZombieNVisionColors[Blue], g_iZombieNVisionDensity)
		g_bNvgOn[iVictim] = true
		
		// Play sound Nightvision ON for player.
		PlaySound(iVictim, "items/nvg_on.wav")
	}
}

// Forward called after player spawn.
public ze_player_spawn_post(id)
{
	// Remove task.
	remove_task(id+TASK_ID)
}

// Hook called when player killed.
public Fw_PlayerKilled_Post(id)
{
	if (g_bNvgOn[id])
	{
		// Unset player NightVision.
		g_bNvgOn[id] = false
		Set_NightVision(id)
		Set_MapLightStyle(id, g_szCurLightStyle)
	}

	set_task(1.0, "set_Specs_NVision", id+TASK_ID, "", 0, "b")
}

public set_Specs_NVision(id)
{
	// Get player id.
	id -= TASK_ID

	// Static
	static iSpecId

	// Free Look?
	if ((get_entvar(id, var_iuser1) == OBS_ROAMING) && g_bNvgOn[id])
	{
		g_bNvgOn[id] = false
		set_Zombie_NVision(id, false)
		return // Prevent execute rest of codes.
	}

	// Get player ID the spectator is watching?
	iSpecId = get_entvar(id, var_iuser2)

	// Player has watching by spectator is not an alive?
	if (!is_user_alive(iSpecId))
		return
	
	// Player has watching by spectator is a Zombie?
	if (ze_is_user_zombie(iSpecId))
	{
		if (g_bNvgOn[iSpecId])
		{
			if (!g_bNvgOn[id])
			{
				g_bNvgOn[id] = true
				set_Zombie_NVision(id)
			}
		}
		else
		{
			if (g_bNvgOn[id])
			{
				g_bNvgOn[id] = false
				set_Zombie_NVision(id, false)
			}
		}
	}
	else
	{
		if (g_bNvgOn[id])
		{
			g_bNvgOn[id] = false
			set_Zombie_NVision(id, false)
		}
	}
}

public Cmd_NvgToggle(id)
{
	// Nighitvision of Zombies is disabled?
	if (!g_bNightVision)
		return PLUGIN_HANDLED

	if (is_user_alive(id))
	{
		if(ze_is_user_zombie(id))
		{
			new Float:fReffrenceTime = get_gametime()
			
			if(g_flLastNvgToggle[id] > fReffrenceTime)
				return PLUGIN_HANDLED
			
			// Just Add Delay like in default one in CS and to allow sound complete
			g_flLastNvgToggle[id] = fReffrenceTime + 1.5
			
			if(!g_bNvgOn[id])
			{
				g_bNvgOn[id] = true
				Set_MapLightStyle(id, "z")
				Set_NightVision(id, 0, 0, 0x0004, get_pcvar_num(g_pCvarZombieNVisionColors[Red]), get_pcvar_num(g_pCvarZombieNVisionColors[Green]), get_pcvar_num(g_pCvarZombieNVisionColors[Blue]), get_pcvar_num(g_pCvarNVisionDensity))
				PlaySound(id, "items/nvg_on.wav")
			}
			else
			{
				g_bNvgOn[id] = false
				Set_NightVision(id)
				Set_MapLightStyle(id, g_szCurLightStyle)
				PlaySound(id, "items/nvg_off.wav")
			}
		}
	}

	return PLUGIN_HANDLED
}

setMapLightStyle(const szLightStyle[] = "", id = 0)
{
	if (id == 0)
	{
		for (id = 1; id <= MaxClients; id++)
		{
			// Player not found?
			if (!is_user_alive(id))
				continue
		
			// Player is a Zombie?
			if (ze_is_user_zombie(id))
				continue
				
			// Unset player NightVision and set player map light style
			Set_NightVision(id)
			Set_MapLightStyle(id, szLightStyle)
		}
	}
	else
	{
		// Unset player NightVision and set player map light style
		Set_NightVision(id)
		Set_MapLightStyle(id, szLightStyle)		
	}
}

set_Zombie_NVision(id, bool:bSet = true)
{
	if (bSet)
	{
		// Set player Nightvision 
		Set_MapLightStyle(id, "z")
		Set_NightVision(id, 0, 0, 0x0004, g_iZombieNVisionColors[Red], g_iZombieNVisionColors[Green], g_iZombieNVisionColors[Blue], g_iZombieNVisionDensity)	
	}
	else
	{
		// Unset player Nightvision 
		Set_MapLightStyle(id, g_szCurLightStyle)
		Set_NightVision(id)	
	}
}