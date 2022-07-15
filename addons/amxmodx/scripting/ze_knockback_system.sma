#include <zombie_escape>
#include <xs>

// Weapon Power.
new Float:g_flWeaponPower[] = 
{
	-1.0,	// ---
	55.0,	// P228
	-1.0,	// ---
	120.0,	// SCOUT
	-1.0,	// ---
	200.0,	// XM1014
	-1.0,	// ---
	65.0,	// MAC10
	160.0,	// AUG
	-1.0,	// ---
	50.0,	// ELITE
	75.0,	// FIVESEVEN
	90.0,	// UMP45
	180.0,	// SG550
	150.0,	// GALIL
	150.0,	// FAMAS
	55.0,	// USP
	50.0,	// GLOCK18
	300.0,	// AWP
	65.0,	// MP5NAVY
	145.0,	// M249
	200.0,	// M3
	160.0,	// M4A1
	50.0,	// TMP
	190.5,	// G3SG1
	-1.0,	// ---
	80.0,	// DEAGLE
	160.0,	// SG552
	160.0,	// AK47
	-1.0,	// ---
	60.0	// P90
}


// Global Variables.
new bool:g_bPowerEnabled,
	bool:g_bVerticalVelocity,
	bool:g_bCustomKnockback[MAX_PLAYERS+1],
	bool:g_bCustomKnockbackDuck[MAX_PLAYERS+1],
	Float:g_flRequiredDistance,
	Float:g_flZombieKnockback,
	Float:g_flZombieKnockbackDuck,
	Float:g_flCustomKnockback[MAX_PLAYERS+1],
	Float:g_flCustomKnockbackDuck[MAX_PLAYERS+1]

// Forward allows registering natives.
public plugin_natives()
{
	register_native("ze_get_user_knockback", "native_get_user_knockback", 1)
	register_native("ze_set_user_knockback", "native_set_user_knockback", 1)
	register_native("ze_reset_user_knockback", "native_reset_user_knockback", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Knockback System", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Knockback System")

	// Hook Chains.
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "fw_TakeDamage_Post", 1)

	// Create CVars and Bind Cvars (Store the CVars values in global Variables).
	bind_pcvar_num(create_cvar("ze_knockback_power", "1"), g_bPowerEnabled)
	bind_pcvar_num(create_cvar("ze_knockback_vervelocity", "0"), g_bVerticalVelocity)
	bind_pcvar_float(create_cvar("ze_knockback_distance", "600.0"), g_flRequiredDistance)
	bind_pcvar_float(create_cvar("ze_zombie_knockback", "300.0"), g_flZombieKnockback)
	bind_pcvar_float(create_cvar("ze_zombie_knockback_duck", "150.0"), g_flZombieKnockbackDuck)
}

// Forward called after init.
public plugin_cfg()
{
	new szWeapon[MAX_NAME_LENGTH]
	for (new iWpn = CSW_P228; iWpn <= CSW_LAST_WEAPON; iWpn++)
	{
		// Useless weapon?
		if (g_flWeaponPower[iWpn] == -1.0)
			continue
		
		// Get weapon class.
		get_weaponname(iWpn, szWeapon, charsmax(szWeapon))

		// Load weapons power from settings file.
		if (!amx_load_setting_float(ZE_SETTING_RESOURCES, "Knockback System", szWeapon[7], g_flWeaponPower[iWpn]))
			amx_save_setting_float(ZE_SETTING_RESOURCES, "Knockback System", szWeapon[7], g_flWeaponPower[iWpn]) // Save default values in settings file, If doesn't loaded.
	}
}

// Forward called when player disconnected from server.
public client_disconnected(id)
{
	// Reset slot in variable.
	g_flCustomKnockback[id] = 0.0
	g_bCustomKnockback[id] = false
}

// Hook called after player take bullet damage.
public fw_TakeDamage_Post(iVictim, iInflector, iAttacker, Float:flDamage, iDamageType)
{
	// Invalid player or self damage?
	if (iVictim == iAttacker || !is_user_connected(iVictim) || !is_user_connected(iAttacker))
		return // Prevent execute rest of codes.
	
	// Victim isn't Zombie or Attacker isn't Human?
	if (!ze_is_user_zombie_ex(iVictim) || ze_is_user_zombie_ex(iAttacker))
		return // Prevent execute rest of codes.
	
	// Damage type ins't bullet?
	if (!(iDamageType & (DMG_BULLET|DMG_GRENADE)))
		return // Prevent execute rest of codes.
	
	// Knockback only if damage is done to Zombie?
	if (flDamage <= 0.0)
		return // Prevent execute rest of codes.
	
	// Static's.
	static Float:vVicOrigin[3], Float:vAttOrigin[3], Float:vVelocity[3], Float:flSpeed, Float:flDist, iWeapon

	// Get origin of victim and attacker.
	get_entvar(iVictim, var_origin, vVicOrigin)
	get_entvar(iAttacker, var_origin, vAttOrigin)
	
	// Get distance between two origin.
	flDist = vector_distance(vVicOrigin, vAttOrigin)

	// Max distance exceeded?
	if (flDist > g_flRequiredDistance)
		return // Prevent execute rest of codes.
	
	// Get weapon id of attacker.
	iWeapon = get_user_weapon(iAttacker)

	// Add weapon power.
	if (g_bPowerEnabled && (WeaponIdType:iWeapon != WEAPON_NONE))
		flSpeed = (g_bCustomKnockback[iVictim] ? g_flCustomKnockback[iVictim] : g_flZombieKnockback) + g_flWeaponPower[iWeapon] // Get knockback speed (Weapon power support).
	else
		flSpeed = (g_bCustomKnockback[iVictim] ? g_flCustomKnockback[iVictim] : g_flZombieKnockback) // Get knockback speed

	// Get new velocity.
	vVelocity[0] = ((vVicOrigin[0] - vAttOrigin[0]) / (flDist / flSpeed)) * 1.5
	vVelocity[1] = ((vVicOrigin[1] - vAttOrigin[1]) / (flDist / flSpeed)) * 1.5
	
	// Affect vertical velocity
	if (g_bVerticalVelocity)
		vVelocity[2] = (vVicOrigin[2] - vAttOrigin[2]) / (flDist / flSpeed)

	// Set Zombie new velocity.
	set_entvar(iVictim, var_velocity, vVelocity)
}

/**
 * Functions of natives:
 */
public native_get_user_knockback(id, &kbDuck)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return -1
	}

	// Player is not Zombie?
	if (!ze_is_user_zombie_ex(id))
		return -1

	// Store knockback duck in 
	kbDuck = floatround(g_bCustomKnockbackDuck[id] ? g_flCustomKnockback[id] : g_flZombieKnockbackDuck)
	
	// Return knockback.
	return floatround(g_bCustomKnockback[id] ? g_flCustomKnockback[id] : g_flZombieKnockback)
}

public native_set_user_knockback(id, Float:flKnockback, Float:flKnockbackDuck)
{
	// Player not found?
	if (!is_user_connected(id))
	{
		// Print error on server console.
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player id (%d)", id)
		return false
	}	
	
	// Player is not Zombie?
	if (!ze_is_user_zombie_ex(id))
		return false
	
	// Check Zombie has custom knockback?
	if (!g_bCustomKnockback[id])
	{
		// Set Zombie custom knockback.
		g_bCustomKnockback[id] = true
		g_flCustomKnockback[id] = flKnockback
	}
	else
	{
		// Change Zombie custom knockback.
		g_flCustomKnockback[id] = flKnockback
	}

	if (flKnockbackDuck > -1.0)
	{
		if (g_bCustomKnockbackDuck[id])
		{
			// Set Zombie custom knockback.
			g_bCustomKnockbackDuck[id] = true
			g_flCustomKnockbackDuck[id] = flKnockbackDuck			
		}
		else
		{
			// Change Zombie custom knockback duck.
			g_flCustomKnockbackDuck[id] = flKnockbackDuck	
		}
	}

	return true
}

public native_reset_user_knockback(id, bDuck)
{
	// Player not found?
	if (!is_user_connected(id))
		return false

	// Reset Zombie knockback.
	g_bCustomKnockback[id] = false
	g_flCustomKnockback[id] = 0.0
	
	// Reset Zombie knockback (duck)
	if (bDuck) 
	{
		g_bCustomKnockbackDuck[id] = false
		g_flCustomKnockbackDuck[id] = 0.0
	}

	return true
}