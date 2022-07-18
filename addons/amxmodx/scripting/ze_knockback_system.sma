#include <zombie_escape>
#include <xs>

// Default Weapons power.
new Float:g_flWeaponPower[] = 
{
	-1.0,	// ---
	2.4,	// P228
	-1.0,	// ---
	6.5,	// Scout
	-1.0,	// ---
	8.0,	// Xm1014
	-1.0,	// ---
	2.3,	// Mac10
	5.0,	// Aug
	-1.0,	// ---
	2.4,	// Elite
	2.0,	// Five-SeveN
	2.4,	// Ump45
	5.3,	// SG550
	5.5,	// Galil
	5.5,	// Famas
	2.2,	// USP
	2.0,	// Glock18
	10.0,	// Awp
	2.5,	// Mp5 Navy
	5.2,	// M249
	8.0,	// M3
	5.0,	// M4A1
	2.4,	// Tmp
	6.5,	// G3SG1
	-1.0,	// ---
	5.3,	// Deagle
	5.0,	// SG552
	6.0,	// AK47
	-1.0,	// ---
	2.0		// P90	
}

// Global Variables.
new bool:g_bCalcDamage
new bool:g_bCalcPower
new bool:g_bEnableVerVelo
new bool:g_bCustomKnockback[MAX_PLAYERS+1]
new Float:g_flDucking
new Float:g_flZombieKnockback
new Float:g_flRequiredDistance
new Float:g_flKnockbackUsed[MAX_PLAYERS+1]

// Forward allows registering new natives.
public plugin_natives()
{
	// Create new natives.
	register_native("ze_get_user_knockback", "native_ze_get_user_knockback", 1)
	register_native("ze_get_user_knockback_f", "native_ze_get_user_knockback_f", 1)
	register_native("ze_set_user_knockback", "native_ze_set_user_knockback", 1)
	register_native("ze_reset_user_knockback", "native_ze_reset_user_knockback", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Knockback System", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Zombie knockback system")

	// Hook Chain.
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "fw_TraceAttack_Post", 1)

	// CVars.
	bind_pcvar_num(create_cvar("ze_knockback_damage", "1"), g_bCalcDamage)
	bind_pcvar_num(create_cvar("ze_knockback_power", "1"), g_bCalcPower)
	bind_pcvar_num(create_cvar("ze_knockback_vervelo", "1"), g_bEnableVerVelo)
	bind_pcvar_float(create_cvar("ze_knockback_ducking", "0.25"), g_flDucking)
	bind_pcvar_float(create_cvar("ze_knockback_distance", "500"), g_flRequiredDistance)

	bind_pcvar_float(create_cvar("ze_zombie_knockback", "200.0"), g_flZombieKnockback)
}

// Forward called before init
public plugin_cfg()
{
	new szName[MAX_NAME_LENGTH], iWpn
	for (iWpn = CSW_P228; iWpn < CSW_LAST_WEAPON; iWpn++)
	{
		// Useless weapon?
		if (g_flWeaponPower[iWpn] == -1.0)
			continue

		// Get weapon name.
		get_weaponname(iWpn, szName, charsmax(szName))

		// Load weapon classname from externel file.
		if (!amx_load_setting_float(ZE_SETTING_RESOURCES, "Knockback System", szName[7], g_flWeaponPower[iWpn]))
			amx_save_setting_float(ZE_SETTING_RESOURCES, "Knockback System", szName[7], g_flWeaponPower[iWpn])
	}
}

// Forward called when player disconnected from the server.
public client_disconnected(id)
{
	// Reset Var.
	g_flKnockbackUsed[id] = 0.0
	g_bCustomKnockback[id] = false
}

// Forward allows precaching game files (called before init).
public fw_TraceAttack_Post(iVictim, iAttacker, Float:flDamage, Float:vDirection[3], iTraceHandle, iDamageType)
{
	// Invalid player?
	if ((iVictim == iAttacker) || !is_user_connected(iAttacker))
		return
	
	// Victim isn't zombie or attacker isn't human
	if (!ze_is_user_zombie_ex(iVictim) || ze_is_user_zombie_ex(iAttacker))
		return
	
	// Not bullet damage
	if (!(iDamageType & DMG_BULLET))
		return
	
	// Knockback only if damage is done to victim
	if ((flDamage <= 0.0) || (get_tr2(iTraceHandle, TR_pHit) != iVictim))
		return
		
	// Static's.
	static Float:vVicOrigin[3], Float:vAttOrigin[3], Float:vVelocity[3], iDucking, iCurWpn

	// Get origin of victim and attacker
	get_entvar(iVictim, var_origin, vVicOrigin)
	get_entvar(iAttacker, var_origin, vAttOrigin)
	
	// Max distance exceeded?
	if (vector_distance(vVicOrigin, vAttOrigin) > g_flRequiredDistance)
		return 
	
	// Get victim's velocity
	get_entvar(iVictim, var_velocity, vVelocity)
	
	if (g_flDucking > 0.0)
		iDucking = get_entvar(iVictim, var_flags) & (FL_DUCKING|FL_ONGROUND) == (FL_DUCKING|FL_ONGROUND)

	// Player in crouch position?
	if (iDucking && (g_flDucking > 0.0))
		xs_vec_mul_scalar(vDirection, g_flDucking, vDirection)

	// Use damage on knockback calculation?
	if (g_bCalcDamage) xs_vec_mul_scalar(vDirection, flDamage, vDirection)
	
	// Get current attacker's weapon id
	iCurWpn = get_user_weapon(iAttacker)
	
	// Use weapon power on knockback calculation?
	if (g_bCalcPower && (g_flWeaponPower[iCurWpn] > 0.0))
		xs_vec_mul_scalar(vDirection, g_flWeaponPower[iCurWpn], vDirection)
	
	// Custom knockback used?
	if (g_bCustomKnockback[iVictim]) 
		xs_vec_mul_scalar(vDirection, g_flKnockbackUsed[iVictim]/100.0, vDirection)
	else 
		xs_vec_mul_scalar(vDirection, g_flZombieKnockback/100.0, vDirection)

	// Add up the new vector
	xs_vec_add(vVelocity, vDirection, vDirection)
	
	// Should knockback also affect vertical velocity?
	if (!g_bEnableVerVelo) vDirection[2] = vVelocity[2]
	
	// Set the knockback'd victim's velocity
	set_entvar(iVictim, var_velocity, vDirection)
}

/**
 * Functions of natives:
 */
public native_ze_get_user_knockback(id)
{
	// Player not found or ins't Zombie?
	if (!is_user_connected(id) || !ze_is_user_zombie_ex(id))
		return -1
	
	// Return knockback used.
	return floatround(g_bCustomKnockback[id] ? g_flKnockbackUsed[id] : g_flZombieKnockback)
}

public Float:native_ze_get_user_knockback_f(id)
{
	// Player not found or ins't Zombie?
	if (!is_user_connected(id) || !ze_is_user_zombie_ex(id))
		return -1.00
	
	// Return knockback used.
	return g_bCustomKnockback[id] ? g_flKnockbackUsed[id] : g_flZombieKnockback
}

public native_ze_set_user_knockback(id, Float:flKb)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console with details.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}

	// Player is not Zombie?
	if (!ze_is_user_zombie_ex(id))
		return false

	// Enable custom knockback.
	g_bCustomKnockback[id] = true

	// Save knockback speed.
	g_flKnockbackUsed[id] = flKb
	return true
}

public native_ze_reset_user_knockback(id)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console with details.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}

	// Reset Var.
	g_flKnockbackUsed[id] = 0.0
	g_bCustomKnockback[id] = false
	return true
}