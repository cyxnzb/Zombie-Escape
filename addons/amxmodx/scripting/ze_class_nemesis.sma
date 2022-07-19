#include <zombie_escape>

// Natives.
native ze_set_user_model(id, const szModel[]);

// Constants.
const TASK_AURALIGHT = 1100

// Enums (Colors).
enum _:Colors
{
	Red = 0,
	Green,
	Blue
}

// Default nemesis model.
new const g_szNemesisModel[][] = { "ze_nemesis" }

// Default nemesis claws.
new const g_szNemesisClaws[][] = { "models/zombie_escape/v_knife_nemesis.mdl" }

// Global Variables.
new g_iNemesisHealth
new g_iNemesisBaseHealth
new g_iNemesisSpeed
new g_iNemesisGravity
new g_iNemesisAuraRaduis
new g_iNemesisNvgDensity
new g_iNemesisNvgColors[Colors]
new g_iNemesisGlowColors[Colors]
new g_iNemesisAuraColors[Colors]
new bool:g_bNemesisNvg
new bool:g_bNemesisGlow
new bool:g_bNemesisAura
new bool:g_bNemesisExplode
new bool:g_bNemesisOneHit
new bool:g_bNemesisFrost
new bool:g_bNemesisFire
new bool:g_bNemesisNvgAuto
new bool:g_bNemesisLeap
new bool:g_bIsNemesis[MAX_PLAYERS+1]
new Float:g_flNemesisMultiDamage
new Float:g_flNemesisKnockback
new Float:g_flNemesisLeapForce
new Float:g_flNemesisLeapHeight
new Float:g_flNemesisLeapCooldown

// Dynamic Array.
new Array:g_aNemesisModel
new Array:g_aNemesisKnife

// Forward allows register new natives.
public plugin_natives()
{
	// Create new natives.
	register_native("ze_is_user_nemesis", "native_is_user_nemesis", 1)
	register_native("ze_set_user_nemesis", "native_set_user_nemesis", 1)
	register_native("ze_remove_user_nemesis", "native_remove_user_nemesis", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Class: Nemesis", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Class nemesis (Tyran), Zombie with high skills")

	// Hook Chain.
	RegisterHookChain(RG_CBasePlayer_Killed, "fw_PlayerKilled_Pre", 0)

	// CVars (Create new CVars and store new value in Global Variable).
	bind_pcvar_num(create_cvar("ze_nemesis_health", "20000"), g_iNemesisHealth)
	bind_pcvar_num(create_cvar("ze_nemesis_basehealth", "0"), g_iNemesisBaseHealth)
	bind_pcvar_num(create_cvar("ze_nemesis_speed", "320"), g_iNemesisSpeed)
	bind_pcvar_num(create_cvar("ze_nemesis_gravity", "500"), g_iNemesisGravity)
	bind_pcvar_num(create_cvar("ze_nemesis_glow", "1"), g_bNemesisGlow)
	bind_pcvar_num(create_cvar("ze_nemesis_glow_red", "200"), g_iNemesisGlowColors[Red])
	bind_pcvar_num(create_cvar("ze_nemesis_glow_green", "0"), g_iNemesisGlowColors[Green])
	bind_pcvar_num(create_cvar("ze_nemesis_glow_blue", "0"), g_iNemesisGlowColors[Blue])
	bind_pcvar_num(create_cvar("ze_nemesis_aura", "0"), g_bNemesisAura)
	bind_pcvar_num(create_cvar("ze_nemesis_aura_red", "200"), g_iNemesisAuraColors[Red])
	bind_pcvar_num(create_cvar("ze_nemesis_aura_green", "0"), g_iNemesisAuraColors[Green])
	bind_pcvar_num(create_cvar("ze_nemesis_aura_blue", "0"), g_iNemesisAuraColors[Blue])
	bind_pcvar_num(create_cvar("ze_nemesis_aura_raduis", "64"), g_iNemesisAuraRaduis)
	bind_pcvar_num(create_cvar("ze_nemesis_frost", "1"), g_bNemesisFrost)
	bind_pcvar_num(create_cvar("ze_nemesis_fire", "1"), g_bNemesisFire)
	bind_pcvar_num(create_cvar("ze_nemesis_onehit", "0"), g_bNemesisOneHit)
	bind_pcvar_num(create_cvar("ze_nemesis_explode", "1"), g_bNemesisExplode)
	bind_pcvar_float(create_cvar("ze_nemesis_damage", "2.0"), g_flNemesisMultiDamage)
	bind_pcvar_float(create_cvar("ze_nemesis_knockback", "200"), g_flNemesisKnockback)

	bind_pcvar_num(create_cvar("ze_nemesis_leap", "1"), g_bNemesisLeap)
	bind_pcvar_float(create_cvar("ze_nemesis_leap_force", "500"), g_flNemesisLeapForce)
	bind_pcvar_float(create_cvar("ze_nemesis_leap_height", "300"), g_flNemesisLeapHeight)
	bind_pcvar_float(create_cvar("ze_nemesis_leap_cooldown", "5.0"), g_flNemesisLeapCooldown)

	new pCvarNemesisNvgColors[Colors]
	new pCvarNemesisNvg = create_cvar("ze_nemesis_nightvision", "1")
	new pCvarNemesisNvgAuto = create_cvar("ze_nemesis_nightvision_auto", "1")
	pCvarNemesisNvgColors[Red] = create_cvar("ze_nemesis_nightvision_red", "200")
	pCvarNemesisNvgColors[Green] = create_cvar("ze_nemesis_nightvision_green", "0")
	pCvarNemesisNvgColors[Blue] = create_cvar("ze_nemesis_nightvision_blue", "0")
	new pCvarNemesisNvgDensity = create_cvar("ze_nemesis_nightvision_density", "200")

	bind_pcvar_num(pCvarNemesisNvg, g_bNemesisNvg)
	bind_pcvar_num(pCvarNemesisNvgAuto, g_bNemesisNvgAuto)
	bind_pcvar_num(pCvarNemesisNvgColors[Red], g_iNemesisNvgColors[Red])
	bind_pcvar_num(pCvarNemesisNvgColors[Green], g_iNemesisNvgColors[Green])
	bind_pcvar_num(pCvarNemesisNvgColors[Blue], g_iNemesisNvgColors[Blue])
	bind_pcvar_num(pCvarNemesisNvgDensity, g_iNemesisNvgDensity)

	hook_cvar_change(pCvarNemesisNvg, "fw_CVar_NemesisNvgChanged")
	hook_cvar_change(pCvarNemesisNvgAuto, "fw_CVar_NemesisNvgChanged")
	hook_cvar_change(pCvarNemesisNvgColors[Red], "fw_CVar_NemesisNvgChanged")
	hook_cvar_change(pCvarNemesisNvgColors[Green], "fw_CVar_NemesisNvgChanged")
	hook_cvar_change(pCvarNemesisNvgColors[Blue], "fw_CVar_NemesisNvgChanged")
	hook_cvar_change(pCvarNemesisNvgDensity, "fw_CVar_NemesisNvgChanged")
}

// Hook called when change value in CVar of NightVision.
public fw_CVar_NemesisNvgChanged(pCvar)
{
	for (new id = 1; id <= MaxClients; id++)
	{
		// Player not alive or Is not nemesis?
		if (!is_user_alive(id) || !g_bIsNemesis[id])
			continue
		
		// Re-set player Night Vision.
		if (g_bNemesisNvg)
			ze_set_user_nvg(id, g_iNemesisNvgColors[Red], g_iNemesisNvgColors[Green], g_iNemesisNvgColors[Blue], g_iNemesisNvgDensity, ze_is_nvg_on(id))
		else
			ze_reset_user_nvg(id)
	}
}

// Forward allows precaching game files (called before init).
public plugin_precache()
{
	// Create new dynamic array in Memory.
	g_aNemesisModel = ArrayCreate(MAX_MODEL_LENGTH, 1)
	g_aNemesisKnife = ArrayCreate(MAX_MODEL_LENGTH, 1)

	// Load all Nemesis models from externel file.
	amx_load_setting_string_arr(ZE_SETTING_RESOURCES, "Player Models", "NEMESIS", g_aNemesisModel)
	amx_load_setting_string_arr(ZE_SETTING_RESOURCES, "Weapon Models", "V_KNIFE NEMESIS", g_aNemesisKnife)

	new iNum

	// No nemesis models un dynamic array?
	if (!ArraySize(g_aNemesisModel))
	{
		// Save default nemesis models in dynamic array.
		for (iNum = 0; iNum < sizeof g_szNemesisModel; iNum++)
			ArrayPushString(g_aNemesisModel, g_szNemesisModel[iNum])
		
		// Save default nemesis models in externel file.
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Player Models", "NEMESIS", g_aNemesisModel)
	}

	// No nemesis knife models in dynamic array?
	if (!ArraySize(g_aNemesisKnife))
	{
		// Save default nemesis knife models in dynamic array.
		for (iNum = 0; iNum < sizeof g_szNemesisClaws; iNum++)
			ArrayPushString(g_aNemesisKnife, g_szNemesisClaws[iNum])
		
		// Save default nemesis models in externel file.
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Weapon Models", "V_KNIFE NEMESIS", g_aNemesisKnife)			
	}

	// Local Variables.
	new szModel[MAX_MODEL_LENGTH], iArrSize

	// Get number of nemesis player models in dynamic array.
	iArrSize = ArraySize(g_aNemesisModel)

	// Precache Models.
	for (iNum = 0; iNum < iArrSize; iNum++)
	{
		// Get nemesis models from dynamic array.
		ArrayGetString(g_aNemesisModel, iNum, szModel, charsmax(szModel))

		// Add nemesis model name in path.
		format(szModel, charsmax(szModel), "models/player/%s/%s.mdl", szModel, szModel)

		// Precache Model (Store model in Memory).
		precache_model(szModel)
	}
	
	// Get number of nemesis knife models in dynamic array.
	iArrSize = ArraySize(g_aNemesisKnife)

	for (iNum = 0; iNum < iArrSize; iNum++)
	{
		// Get nemesis models from dynamic array.
		ArrayGetString(g_aNemesisKnife, iNum, szModel, charsmax(szModel))

		// Precache Model (Store model in Memory).
		precache_model(szModel)		
	}
}

// Forward called when player disconnected from server.
public client_disconnected(id)
{
	// Remove player Flag Nemesis.
	g_bIsNemesis[id] = false
}

// Forward called before FrostNade freeze player.
public ze_frost_pre(id)
{
	// Don't freeze Nemesis?
	if (g_bNemesisFrost && g_bIsNemesis[id])
		return ZE_STOP // Block freeze Nemesis.
	return ZE_CONTINUE
}

// Forward called before FrostNade burn player.
public ze_fire_pre(id)
{
	// Don't burn Nemesis?
	if (g_bNemesisFire && g_bIsNemesis[id])
		return ZE_STOP // Block burn Nemesis.
	return ZE_CONTINUE	
}

// Hook called when player killed.
public fw_PlayerKilled_Pre(iVictim, iAttacker, iShouldGibs)
{
	// CVar is disabled or player is not Nemesis?
	if (!g_bNemesisExplode || !g_bIsNemesis[iVictim])
		return

	// Unset player Nemesis.
	remove_User_Nemesis(iVictim)

	// Destroy player.
	SetHookChainArg(3, ATYPE_INTEGER, GIB_ALWAYS)
}

// Forward called after player become Human.
public ze_user_humanized(id)
{
	// Unset player Nemesis.
	remove_User_Nemesis(id)
}

// Forward called before infection event.
public ze_user_infected_pre(iVictim, iInfector, iDamage)
{
	// Infector is Server?
	if (!iInfector)
		return ZE_CONTINUE // Continue infection event.

	// Player is Nemesis?
	if (g_bIsNemesis[iInfector])
	{
		// Multiple damage?
		if (!g_bNemesisOneHit)
		{
			// Damage player.
			rg_multidmg_clear()
			rg_multidmg_add(iInfector, iVictim, float(iDamage)*g_flNemesisMultiDamage, DMG_GENERIC)
			rg_multidmg_apply(iInfector, iInfector)	
		}
		else
		{
			// Kill victim.
			ExecuteHam(Ham_Killed, iVictim, iInfector, GIB_ALWAYS)
		}

		return ZE_STOP // Block infection event.	
	}

	return ZE_CONTINUE // Continue infection event.
}

public set_User_Nemesis(id)
{
	// Player is not Zombie?
	if (!ze_is_user_zombie_ex(id))
		ze_set_user_zombie(id) // Set player Zombie.

	// Set player Nemesis flag.
	g_bIsNemesis[id] = true

	// Base health enabled?
	if (g_iNemesisBaseHealth > 0)
		set_entvar(id, var_health, float(g_iNemesisBaseHealth * ze_get_humans_number())) // Set player health (health * number of alive humans).
	else 
		set_entvar(id, var_health, float(g_iNemesisHealth)) // Set player health.

	// Custom Speed!
	if (g_iNemesisSpeed > 0)
		ze_set_zombie_speed(id, g_iNemesisSpeed) // Set player custom speed.

	// Custom gravity?
	if (g_iNemesisGravity > 0)
		ze_set_user_gravity(id, g_iNemesisGravity) // Set player custom gravity.
	
	// Colored glowshell enabled?
	if (g_bNemesisGlow)
		Set_Rendering(id, kRenderFxGlowShell, g_iNemesisGlowColors[Red], g_iNemesisGlowColors[Green], g_iNemesisGlowColors[Blue], kRenderNormal, 16) // Set player colored GlowShell

	// Colored aura enabled?
	if (g_bNemesisAura)	
		set_task(0.1, "auraLight", (id+TASK_AURALIGHT), "", 0, "b") // New task for display dynamic light.

	// Set nemesis custom Knockback.
	ze_set_user_knockback(id, g_flNemesisKnockback)

	// Local Variable.
	new szModel[MAX_MODEL_LENGTH]

	// Get random nemesis player model from dynamic array.
	ArrayGetString(g_aNemesisModel, random_num(0, ArraySize(g_aNemesisModel) - 1), szModel, charsmax(szModel))

	// Set player Nemesis Model.
	rg_set_user_model(id, szModel)

	// Get random nemesis knife model from dynamic array.
	ArrayGetString(g_aNemesisKnife, random_num(0, ArraySize(g_aNemesisKnife) - 1), szModel, charsmax(szModel))

	// Set player nemesis knife.
	ze_set_user_view_model(id, CSW_KNIFE, szModel)
	ze_set_user_weap_model(id, CSW_KNIFE, "")

	// Set player Night Vision.
	if (g_bNemesisNvg)
		ze_set_user_nvg(id, g_iNemesisNvgColors[Red], g_iNemesisNvgColors[Green], g_iNemesisNvgColors[Blue], g_iNemesisNvgDensity, g_bNemesisNvgAuto)

	// Set player Leap.
	if (g_bNemesisLeap)
		ze_set_user_leap(id, g_flNemesisLeapForce, g_flNemesisLeapHeight, g_flNemesisLeapCooldown)
	else
		ze_block_user_leap(id) // Don't set player Zombie leap.
}

public remove_User_Nemesis(id)
{
	// Remove player nemesis flag.
	g_bIsNemesis[id] = false
	
	// Reset player speed.
	ze_reset_zombie_speed(id)

	// Reset player gravity.
	ze_reset_user_gravity(id)

	// Remove rendering.
	Set_Rendering(id)

	// Stop Aura.
	remove_task(id+TASK_AURALIGHT)

	// Reset Zombie knockback.
	ze_reset_user_knockback(id)

	// Remove player Night Vision.
	ze_reset_user_nvg(id)

	// Remove player Leap.
	ze_remove_user_leap(id)

	// Unlock player Leap.
	ze_unblock_user_leap(id)
}

public auraLight(id)
{
	// Get player index.
	id -= TASK_AURALIGHT
	
	static iOrigin[3]

	// Get origin of player.
	get_user_origin(id, iOrigin, Origin_Client)

	// Colored dynamic light.
	message_begin(MSG_PVS, SVC_TEMPENTITY, iOrigin)
	write_byte(TE_DLIGHT) // TE id.
	write_coord(iOrigin[0]) // Position X.
	write_coord(iOrigin[1]) // Position Y.
	write_coord(iOrigin[2]) // Position Z.
	write_byte(g_iNemesisAuraRaduis) // Raduis.
	write_byte(g_iNemesisAuraColors[Red]) // Red color.
	write_byte(g_iNemesisAuraColors[Green]) // Green color.
	write_byte(g_iNemesisAuraColors[Blue]) // Blue color.
	write_byte(2) // Life time.
	write_byte(0) // Decay rate
	message_end()
}

/**
 * Function of natives:
 */
public bool:native_is_user_nemesis(id)
{
	// Player not found?
	if (!is_user_connected(id) || !ze_is_user_zombie_ex(id))
		return false
	
	// Return true or false.
	return g_bIsNemesis[id]
}

public native_set_user_nemesis(id)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console with details.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}

	// Set player Nemesis.
	set_User_Nemesis(id)
	return true
}

public native_remove_user_nemesis(id, bool:bZombie)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console with details.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}

	// Remove player Nemesis.
	remove_User_Nemesis(id)

	// Set player Zombie.
	if (bZombie)
		ze_set_user_zombie(id)
	return true	
}