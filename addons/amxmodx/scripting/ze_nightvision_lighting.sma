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
	
// Colors
enum
{
	Red = 0,
	Green,
	Blue
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Nightvision/Lighting", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Zombies Nightvision and Map lighting style changer")
	
	// Hook Chains.
	RegisterHookChain(RG_CBasePlayer_Killed, "Fw_PlayerKilled_Post", 1)
	
	// Client Commands.
	register_clcmd("nightvision", "Cmd_NvgToggle")

	// Cvars.
	new pCvarLightingStyle = register_cvar("ze_lighting_style", "d")

	// Bind CVars (Store automatically new values in CVars).
	bind_pcvar_num(register_cvar("ze_zombie_nightvision", "1"), g_bNightVision)
	bind_pcvar_num(register_cvar("ze_zombie_auto_nightvision", "1"), g_bAutoNightVision)
	bind_pcvar_num(register_cvar("ze_zombie_nightvision_density", "70"), g_iZombieNVisionDensity)
	bind_pcvar_num(register_cvar("ze_zombie_nvision_red", "253"), g_iZombieNVisionColors[Red])
	bind_pcvar_num(register_cvar("ze_zombie_nvision_green", "110"), g_iZombieNVisionColors[Green])
	bind_pcvar_num(register_cvar("ze_zombie_nvision_blue", "110"), g_iZombieNVisionColors[Blue])
	bind_pcvar_string(pCvarLightingStyle, g_szCurLightStyle, charsmax(g_szCurLightStyle))

	// Hook CVar (called when changed value in CVar ze_lighting_style)
	hook_cvar_change(pCvarLightingStyle, "fw_NewLightingStyle")
}

// Hook called when changed value in CVar "ze_lighting_style".
public fw_NewLightingStyle(pCvar, const szOld_Value[], const szNew_Value[])
{
	for (new id = 1; id <= MaxClients; id++)
	{
		// Player is Zombie?
		if (g_bNvgOn[id])
			set_lightstyle(id, "z")
		else
			set_lightstyle(id, g_szCurLightStyle)
	}
}

// Forward called when player join the server.
public client_putinserver(id)
{
	// Delay needed to set the new player map lighting style.
	set_task(0.1, "delaySet", id)
}

public delaySet(id)
{
	// Set player map lighting style.
	set_lightstyle(id, g_szCurLightStyle)
}

// Forward called after player disconnected from server.
public client_disconnected(id)
{
	// Reset Variables.
	g_bNvgOn[id] = false
	g_flLastNvgToggle[id] = 0.0
}

// Forward called when player become Human.
public ze_user_humanized(id)
{
	// Reset boolean.
	g_bNvgOn[id] = false

	// Remove player Nightvision
	set_zombie_nightvision(id, 0)
}

// Forward called after player infected.
public ze_user_infected(iVictim, iInfector)
{
	if (g_bAutoNightVision)
	{
		// Set player Nightvision.
		g_bNvgOn[iVictim] = true
		set_zombie_nightvision(iVictim, 1)
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
		set_zombie_nightvision(id, 0)
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
		set_zombie_nightvision(id, 0)
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
				set_zombie_nightvision(id, 0)
			}
		}
		else
		{
			if (g_bNvgOn[id])
			{
				g_bNvgOn[id] = false
				set_zombie_nightvision(id, 1)
			}
		}
	}
	else
	{
		if (g_bNvgOn[id])
		{
			g_bNvgOn[id] = false
			set_zombie_nightvision(id, 0)
		}
	}
}

// Hook called when player turn on/off nightvision.
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
				set_zombie_nightvision(id, 1)
				PlaySound(id, "items/nvg_on.wav")
			}
			else
			{
				g_bNvgOn[id] = false
				set_zombie_nightvision(id, 0)
				PlaySound(id, "items/nvg_off.wav")
			}
		}
	}

	return PLUGIN_HANDLED
}

/**
 * Private functions:
 */
set_zombie_nightvision(id, bSet = 1)
{
	if (bSet)
	{
		// Set player Nightvision 
		set_fadescreen(id, 0, 0, SF_FADE_ONLYONE, g_iZombieNVisionColors[Red], g_iZombieNVisionColors[Green], g_iZombieNVisionColors[Blue], g_iZombieNVisionDensity)	
		set_lightstyle(id, "z")
	}
	else
	{
		// Unset player Nightvision 
		set_fadescreen(id)	
		set_lightstyle(id, g_szCurLightStyle)
	}
}