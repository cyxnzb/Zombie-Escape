#include <zombie_escape>

// Constant.
const TASK_ID = 100

// Enums (Colors)
enum _:Colors
{
	Red = 0,
	Green,
	Blue
}

// Global Variables.
new g_iHumanNvgDensity
new g_iZombieNvgDensity
new g_iHumanNvgColors[Colors]
new g_iZombieNvgColors[Colors]
new g_iCustomNvgDensity[MAX_PLAYERS+1]
new g_iCustomNvgColors[MAX_PLAYERS+1][Colors]
new bool:g_bHumanNvg
new bool:g_bHumanNvgOnAuto
new bool:g_bZombieNvg
new bool:g_bZombieNvgOnAuto
new bool:g_bCustomNvg[MAX_PLAYERS+1]
new bool:g_bNvgEnabled[MAX_PLAYERS+1]
new bool:g_bCustomNvgAuto[MAX_PLAYERS+1]
new Float:g_flTurnOnDelay[MAX_PLAYERS+1]

// String's.
new g_szCurLighting[2]

// Forward allows reigtsering natives.
public plugin_natives()
{
	register_native("ze_is_nvg_on", "native_ze_is_nvg_on", 1)
	register_native("ze_set_user_nvg", "native_ze_set_user_nvg", 1)
	register_native("ze_reset_user_nvg", "native_ze_reset_user_nvg", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Nightvision & Lighting", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Custom Nightvision and Lighting style")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayer_Killed, "fw_PlayerKilled_Post", 1)

	// Cvars (Store automatically new value of CVar in Global Variables).
	bind_pcvar_num(create_cvar("ze_human_nightvision", "0"), g_bHumanNvg)
	bind_pcvar_num(create_cvar("ze_human_nightvision_auto", "0"), g_bHumanNvgOnAuto)
	bind_pcvar_num(create_cvar("ze_human_nightvision_red", "0"), g_iHumanNvgColors[Red])
	bind_pcvar_num(create_cvar("ze_human_nightvision_green", "100"), g_iHumanNvgColors[Green])
	bind_pcvar_num(create_cvar("ze_human_nightvision_blue", "200"), g_iHumanNvgColors[Blue])
	bind_pcvar_num(create_cvar("ze_human_nightvision_density", "70"), g_iHumanNvgDensity)

	bind_pcvar_num(create_cvar("ze_zombie_nightvision", "1"), g_bZombieNvg)
	bind_pcvar_num(create_cvar("ze_zombie_nightvision_auto", "1"), g_bZombieNvgOnAuto)
	bind_pcvar_num(create_cvar("ze_zombie_nightvision_red", "253"), g_iZombieNvgColors[Red])
	bind_pcvar_num(create_cvar("ze_zombie_nightvision_green", "110"), g_iZombieNvgColors[Green])
	bind_pcvar_num(create_cvar("ze_zombie_nightvision_blue", "110"), g_iZombieNvgColors[Blue])
	bind_pcvar_num(create_cvar("ze_zombie_nightvision_density", "70"), g_iZombieNvgDensity)

	new pCvarLightingStyle = create_cvar("ze_lighting_style", "n")
	bind_pcvar_string(pCvarLightingStyle, g_szCurLighting, charsmax(g_szCurLighting))
	hook_cvar_change(pCvarLightingStyle, "fw_CVar_LightingStyleChanged")

	// Clcmds.
	register_clcmd("nightvision", "clcmd_TurnNightvision")
}

// Hook called when change value in CVar "ze_lighting_style".
public fw_CVar_LightingStyleChanged(pCvar, const szNew_Value[], const szOld_Value[])
{
	set_task(0.1, "new_Lighting")
}

public new_Lighting()
{
	// Set all players new lighting style.
	for (new id = 1; id <= MaxClients; id++)
	{
		// Player not found or Player is use nvg?
		if (!is_user_connected(id) || g_bNvgEnabled[id])
			continue
		
		// Set player new lighting style.
		set_lightstyle(id, g_szCurLighting)
	}	
}

// Hook called when player turn on or off nightvision.
public clcmd_TurnNightvision(id)
{
	// Player not alive?
	if (!is_user_alive(id))
		return PLUGIN_HANDLED
	
	// Delay time has expired?
	if ((g_flTurnOnDelay[id] - get_gametime()) > 0.0)
		return PLUGIN_HANDLED

	// Delay before turn on or off again.
	g_flTurnOnDelay[id] = get_gametime() + 1.0

	// Custom nightvision?
	if (g_bCustomNvg[id])
	{
		// Nvg is off?
		if (!g_bNvgEnabled[id])
		{
			// Turn on nvg for player.
			g_bNvgEnabled[id] = true

			// Set player custom nightvision.
			set_nightvision(id, g_iCustomNvgColors[id][Red], g_iCustomNvgColors[id][Green], g_iCustomNvgColors[id][Blue], g_iCustomNvgDensity[id])			
	
			// Play sound.
			rg_send_audio(id, "items/nvg_on.wav", PITCH_NORM)	
		}
		else // Nvg is on
		{
			// Turn off nvg for player.
			g_bNvgEnabled[id] = false

			// Set player custom nightvision.
			unset_nightvision(id)

			// Play sound.
			rg_send_audio(id, "items/nvg_off.wav", PITCH_NORM)
		}
	}	
	else
	{
		// Player is Zombie?
		if (ze_is_user_zombie_ex(id))
		{
			// Zombie nightvision enabled?
			if (g_bZombieNvg)
			{
				// Nvg is off?
				if (!g_bNvgEnabled[id])
				{
					// Turn on nvg for player.
					g_bNvgEnabled[id] = true

					// Set player nightvision.
					set_nightvision(id, g_iZombieNvgColors[Red], g_iZombieNvgColors[Green], g_iZombieNvgColors[Blue], g_iZombieNvgDensity)
				
					// Play sound.
					rg_send_audio(id, "items/nvg_on.wav", PITCH_NORM)
				}
				else // Nvg is on
				{
					// Turn off nvg for player.
					g_bNvgEnabled[id] = false

					// Set player nightvision.
					unset_nightvision(id)
				
					// Play sound.
					rg_send_audio(id, "items/nvg_off.wav", PITCH_NORM)
				}				
			}
		}
		else // Human.
		{
			// Human nightvision enabled?
			if (g_bHumanNvg)
			{
				// Nvg is off?
				if (!g_bNvgEnabled[id])
				{
					// Turn on nvg for player.
					g_bNvgEnabled[id] = true

					// Set player nightvision.
					set_nightvision(id, g_iHumanNvgColors[Red], g_iHumanNvgColors[Green], g_iHumanNvgColors[Blue], g_iHumanNvgDensity)		
				
					// Play sound.
					rg_send_audio(id, "items/nvg_on.wav", PITCH_NORM)		
				}
				else
				{
					// Turn off nvg for player.
					g_bNvgEnabled[id] = false

					// Remove player nightvision.
					unset_nightvision(id)				
				
					// Play sound.
					rg_send_audio(id, "items/nvg_off.wav", PITCH_NORM)			
				}				
			}
		}		
	}

	return PLUGIN_HANDLED // Prevent execute property of command on game.
}

// Forward called when player disconnected from server.
public client_disconnected(id)
{
	// Reset Variables.
	g_bCustomNvg[id] = false
	g_bCustomNvgAuto[id] = false
	g_flTurnOnDelay[id] = 0.0
	g_iCustomNvgDensity[id] = 0
	g_iCustomNvgColors[id][Red] = 0
	g_iCustomNvgColors[id][Green] = 0
	g_iCustomNvgColors[id][Blue] = 0
}

// Forward called after player become Human.
public ze_user_humanized(id)
{
	// Custom nightvision?
	if (g_bCustomNvg[id])
	{
		// Turn on nvg automatically?
		if (g_bCustomNvgAuto[id])
		{
			// Turn on nvg.
			g_bNvgEnabled[id] = true

			// Set player nightvision.
			set_nightvision(id, g_iCustomNvgColors[id][Red], g_iCustomNvgColors[id][Green], g_iCustomNvgColors[id][Blue], g_iCustomNvgDensity[id])
		}
		else
		{
			// Remove player nightvision
			unset_nightvision(id)
		}

		return // Prevent execute rest of codes.
	}
	
	// Human nightvision enabled?
	if (g_bHumanNvg)
	{
		// Turn on nvg automatically?
		if (g_bHumanNvgOnAuto)
		{
			// Turn on nvg.
			g_bNvgEnabled[id] = true

			// Set player nightvision.
			set_nightvision(id, g_iHumanNvgColors[Red], g_iHumanNvgColors[Green], g_iHumanNvgColors[Blue], g_iHumanNvgDensity)
		}
		else
		{
			// Remove player nightvision
			unset_nightvision(id)
		}
	}
}

// Forward called after player infected.
public ze_user_infected(iVictim, iInfector)
{
	// Custom nightvision?
	if (g_bCustomNvg[iVictim])
	{
		// Turn on nvg automatically?
		if (g_bCustomNvgAuto[iVictim])
		{
			// Turn on nvg.
			g_bNvgEnabled[iVictim] = true

			// Set player nightvision.
			set_nightvision(iVictim, g_iCustomNvgColors[iVictim][Red], g_iCustomNvgColors[iVictim][Green], g_iCustomNvgColors[iVictim][Blue], g_iCustomNvgDensity[iVictim])
		}
		else
		{
			// Remove player nightvision
			unset_nightvision(iVictim)			
		}

		return // Prevent execute rest of codes.
	}

	// Human nightvision enabled?
	if (g_bZombieNvg)
	{
		// Turn on nvg automatically?
		if (g_bZombieNvgOnAuto)
		{
			// Turn on nvg.
			g_bNvgEnabled[iVictim] = true	

			// Set player nightvision.
			set_nightvision(iVictim, g_iZombieNvgColors[Red], g_iZombieNvgColors[Green], g_iZombieNvgColors[Blue], g_iZombieNvgDensity)
		}
		else
		{
			// Remove player nightvision
			unset_nightvision(iVictim)
		}
	}
}

// Hook called after player killed.
public fw_PlayerKilled_Post(iVictim, iAttacker, iShouldGibs)
{
	// Remove player nightvision.
	unset_nightvision(iVictim)

	// Show nightvision of others.
	set_task(1.0, "show_Specs_Nvg", iVictim+TASK_ID, _, _, "b")
}

public show_Specs_Nvg(id)
{
	// Nightvision disabled?
	if (!g_bHumanNvg && !g_bZombieNvg)
		return

	// Get player index.
	id -= TASK_ID

	// Free Look?
	if ((get_entvar(id, var_iuser1) == OBS_ROAMING) && g_bNvgEnabled[id])
	{
		// Turn on nvg.
		g_bNvgEnabled[id] = false
	
		// Remove player nightvision.
		unset_nightvision(id)

		// Prevent execute rest of codes.
		return
	}

	// Static's.
	static iSpec

	// Get a player who is watching a spectator?
	iSpec = get_entvar(id, var_iuser3)

	// Target is not a alive?
	if (!is_user_alive(iSpec))
		return
	
	// Nvg on?
	if (g_bNvgEnabled[iSpec])
	{
		// Custom nightvision?
		if (g_bCustomNvg[iSpec])
		{
			if (!g_bNvgEnabled[id])
			{
				// Turn on nvg for spectator.
				g_bNvgEnabled[id] = true

				// Set player custom nightvision.
				set_nightvision(id, g_iCustomNvgColors[iSpec][Red], g_iCustomNvgColors[iSpec][Green], g_iCustomNvgColors[iSpec][Blue], g_iCustomNvgDensity[iSpec])
			}

			return // Prevent execute rest of codes.
		}	
	
		// Player is Zombie?
		if (ze_is_user_zombie_ex(iSpec))
		{
			// Nvg when Spectator is off? 
			if (!g_bNvgEnabled[id])
			{
				// Turn on nvg for spectator.
				g_bNvgEnabled[id] = true

				// Set player nightvision.
				set_nightvision(id, g_iZombieNvgColors[Red], g_iZombieNvgColors[Green], g_iZombieNvgColors[Blue], g_iZombieNvgDensity)
			}
		}
		else // Human.
		{
			// Nvg when Spectator is off? 
			if (!g_bNvgEnabled[id])
			{
				// Turn on nvg for spectator.
				g_bNvgEnabled[id] = true

				// Set player nightvision.
				set_nightvision(id, g_iHumanNvgColors[Red], g_iHumanNvgColors[Green], g_iHumanNvgColors[Blue], g_iHumanNvgDensity)
			}
		}
	}
}

/**
 * Private function:
 */
set_nightvision(id, r, g, b, density)
{
	// Set player map light style (brightest)
	set_lightstyle(id, "z")

	// Set player colored fade screen.
	set_fadescreen(id, 0, 0, SF_FADE_ONLYONE, r, g, b, density)
}

unset_nightvision(id)
{
	// Set player colored fade screen.
	set_fadescreen(id, 0, 0, 0x0000, 0, 0, 0, 0)

	// Set player map light style (brightest)
	set_lightstyle(id, g_szCurLighting)
}

/**
 * Function of natives:
 */
public native_ze_set_user_nvg(id, iRed, iGreen, iBlue, iDensity, bool:bAuto)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console with details.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}

	// Set player nightvision.
	g_bCustomNvg[id] = true
	g_bCustomNvgAuto[id] = bAuto

	// Turn on nvg when player.
	if (bAuto) set_nightvision(id, iRed, iGreen, iBlue, iDensity) // Set player nvg.

	// Set player nightvision.	
	g_iCustomNvgDensity[id] = iDensity
	g_iCustomNvgColors[id][Red] = iRed
	g_iCustomNvgColors[id][Green] = iGreen
	g_iCustomNvgColors[id][Blue] = iBlue
	return true
}

public native_ze_reset_user_nvg(id)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console with details.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}

	// Unset player nightvision.
	g_bCustomNvg[id] = false
	g_bCustomNvgAuto[id] = false

	// Turn off nvg.
	unset_nightvision(id)
	
	// Reset Variables.
	g_iCustomNvgDensity[id] = 0
	g_iCustomNvgColors[id][Red] = 0
	g_iCustomNvgColors[id][Green] = 0
	g_iCustomNvgColors[id][Blue] = 0
	return true	
}

public native_ze_is_nvg_on(id)
{
	// Player not found?
	if (!is_user_connected(id))
		return false
	return g_bNvgEnabled[id]
}