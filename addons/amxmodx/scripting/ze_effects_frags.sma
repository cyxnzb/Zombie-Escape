#include <zombie_escape>

// Global Variables
new g_iFragsInfection,
	g_iDeathInfection,
	g_iFragsEscapeSuccess,
	g_iDamage2Score,
	Float:g_flRequiredDamage,
	Float:g_flTotalDamage[MAX_PLAYERS+1]

// Hook Chains.
new HookChain:g_pTakeDamagePost

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Frags Awards/Death Effects", ZE_VERSION, AUTHORS, ZE_HOMEURL, "It's give infector's or humans an frags on scoreboard.")
	
	// Hook Chains.
	g_pTakeDamagePost = RegisterHookChain(RG_CBasePlayer_TakeDamage, "fw_TakeDamage_Post", 1)

	// CVars.
	new pCvar_iDamage2Score = register_cvar("ze_damage_to_frags", "0")

	// Create new CVars and Store automatically new value in Global Variables.
	bind_pcvar_num(register_cvar("ze_human_infected_frags", "1"), g_iFragsInfection)
	bind_pcvar_num(register_cvar("ze_infection_deaths", "1"), g_iDeathInfection)
	bind_pcvar_num(register_cvar("ze_escape_success_frags", "3"), g_iFragsEscapeSuccess)
	bind_pcvar_num(pCvar_iDamage2Score, g_iDamage2Score)
	bind_pcvar_float(register_cvar("ze_required_damage", "200"), g_flRequiredDamage)

	// Hook CVars.
	hook_cvar_change(pCvar_iDamage2Score, "fw_CvarDamageToScore_Post")

	// Delay before enable or disable TakeDamage hook.
	set_task(1.0, "delayEnableHook")
}

public delayEnableHook() {
	// Enable|Disable TakeDamage hook.
	if (g_iDamage2Score != 0)
		EnableHookChain(g_pTakeDamagePost) // Enable TakeDamage hook.
	else
		DisableHookChain(g_pTakeDamagePost) // Disable TakeDamage hook.	
}

// Hook called when changed value in CVar ze_damage_to_frags.
public fw_CvarDamageToScore_Post(pCvar, const szOldVal[], const szNewVal[])
{
	// Enable TakeDamage hook.
	if (strlen(szNewVal) != 0)
		EnableHookChain(g_pTakeDamagePost)
	else // Disable TakeDamage hook.
		DisableHookChain(g_pTakeDamagePost)
}

// Forward called after player infected.
public ze_user_infected(iVictim, iInfector)
{
	// Player infected by Server?
	if (iInfector == 0)
		return // Prevent give award for server.
	
	// Award Zombie Who infected, And Increase Deaths of the infected human
	UpdateFrags(iInfector, iVictim, g_iFragsInfection, g_iDeathInfection, 1)
}

// Hook called when player take damage.
public fw_TakeDamage_Post(iVictim, iInflector, iAttacker, Float:flDamage, iDamageType)
{
	// Invalid player?
	if (!is_user_connected(iVictim) || !is_user_connected(iAttacker))
		return
	
	// Attacker ins't Human or Victim isn't Zombie?
	if (!ze_is_user_zombie(iVictim) || ze_is_user_zombie_ex(iAttacker))
		return

	// +Damage.
	g_flTotalDamage[iAttacker] += flDamage

	// Player has reached required damage?
	if (g_flTotalDamage[iAttacker] >= g_flRequiredDamage)
	{
		// Reset Var.
		g_flTotalDamage[iAttacker] -= g_flRequiredDamage

		// Give player Frags.
		UpdateFrags(iAttacker, 0, g_iDamage2Score, 0, 1)
	}
}

// Forward called when round over.
public ze_roundend(WinTeam)
{
	// Humans are winners?
	if (WinTeam == ZE_TEAM_HUMAN)
	{
		// Get id of all players.
		new iPlayers[MAX_PLAYERS], iAliveCount
		get_players(iPlayers, iAliveCount, "a")

		for (new id = 0; id <= iAliveCount; id++)
		{
			// Player isn't Human?
			if (ze_is_user_zombie_ex(id))
				continue
			
			// +Frags for all Humans.
			UpdateFrags(id, 0, g_iFragsEscapeSuccess, 0, 1)
		}
	}
}