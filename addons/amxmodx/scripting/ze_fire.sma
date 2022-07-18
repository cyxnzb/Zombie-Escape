#include <zombie_escape>

// Defination
#define TASK_BURN 100

// Default grenade explode sounds.
new const g_szFireGrenadeExplodeSound[][] = { "zombie_escape/grenade_explode.wav" }

// Default grenade player pain sounds.
new const g_szFireGrenadePlayerSound[][] =
{
	"zombie_escape/zombie_burn3.wav",
	"zombie_escape/zombie_burn4.wav",
	"zombie_escape/zombie_burn5.wav",
	"zombie_escape/zombie_burn6.wav",
	"zombie_escape/zombie_burn7.wav"
}

new g_v_szModelFireGrenade[MAX_MODEL_LENGTH] = "models/zombie_escape/v_grenade_fire.mdl"
new g_p_szModelFireGrenade[MAX_MODEL_LENGTH] = "models/zombie_escape/p_grenade_fire.mdl"
new g_w_szModelFireGrenade[MAX_MODEL_LENGTH] = "models/zombie_escape/w_grenade_fire.mdl"

new g_szGrenadeTrailSprite[MAX_MODEL_LENGTH] = "sprites/laserbeam.spr"
new g_szGrenadeRingSprite[MAX_MODEL_LENGTH] = "sprites/shockwave.spr"
new g_szGrenadeFireSprite[MAX_MODEL_LENGTH] = "sprites/flame.spr"
new g_szGrenadeSmokeSprite[MAX_MODEL_LENGTH] = "sprites/black_smoke3.spr"

// Global Variables.
new g_iTrailSpr, 
	g_iExplodeSpr,
	g_iFlameSpr,
	g_iSmokeSpr,
	g_iFireDuration,
	g_iFwUserBurn,
	g_iForwardReturn,
	g_iBurningDuration[MAX_PLAYERS+1],
	bool:g_bFireHudIcon,
	bool:g_bFireExplosion,
	bool:g_bHitType,
	Float:g_flFireRadius,
	Float:g_flFireDamage,
	Float:g_flFireSlowDown

// Dynamic Arrays.
new Array:g_aFireGrenadeExplodeSound
new Array:g_aFireGrenadePlayerSound

// Forward allows register new natives.
public plugin_natives()
{
	register_native("ze_zombie_in_fire", "native_ze_zombie_in_fire", 1)
	register_native("ze_set_fire_grenade", "native_ze_set_fire_grenade", 1)
	register_native("ze_set_fire_grenade_ex", "native_ze_set_fire_grenade_ex", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Fire Nade", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Fire Grenade")
	
	// Hook Chains
	RegisterHookChain(RG_CBasePlayer_Killed, "Fw_PlayerKilled_Post", 1)
	
	// Events
	register_event("HLTV", "New_Round", "a", "1=0", "2=0")
	
	// Fakemeta
	register_forward(FM_SetModel, "Fw_SetModel_Post")
	
	// Hams
	RegisterHam(Ham_Think, "grenade", "Fw_ThinkGrenade_Post")
	
	// Forwards
	g_iFwUserBurn = CreateMultiForward("ze_fire_pre", ET_CONTINUE, FP_CELL)
	
	// CVars.
	bind_pcvar_num(create_cvar("ze_fire_duration", "6"), g_iFireDuration)
	bind_pcvar_float(create_cvar("ze_fire_damage", "5"), g_flFireDamage)
	bind_pcvar_num(create_cvar("ze_fire_hud_icon", "1"), g_bFireHudIcon)
	bind_pcvar_num(create_cvar("ze_fire_explosion", "0"), g_bFireExplosion)
	bind_pcvar_float(create_cvar("ze_fire_slowdown", "0.1"), g_flFireSlowDown)
	bind_pcvar_float(create_cvar("ze_fire_radius", "240.0"), g_flFireRadius)
	bind_pcvar_num(create_cvar("ze_fire_hit_type", "0"), g_bHitType)
}

// Forward allows precaching game files (called before init)
public plugin_precache()
{
	// Initialize dynamic arrays.
	g_aFireGrenadeExplodeSound = ArrayCreate(MAX_SOUND_LENGTH, 1)
	g_aFireGrenadePlayerSound = ArrayCreate(MAX_SOUND_LENGTH, 1)
	
	// Load from external file
	amx_load_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "GRENADE FIRE EXPLODE", g_aFireGrenadeExplodeSound)
	amx_load_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "GRENADE FIRE PLAYER", g_aFireGrenadePlayerSound)
	
	// If we couldn't load custom sounds from file, use and save default ones
	
	new iIndex
	
	if (ArraySize(g_aFireGrenadeExplodeSound) == 0)
	{
		for (iIndex = 0; iIndex < sizeof g_szFireGrenadeExplodeSound; iIndex++)
			ArrayPushString(g_aFireGrenadeExplodeSound, g_szFireGrenadeExplodeSound[iIndex])
		
		// Save to external file
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "GRENADE FIRE EXPLODE", g_aFireGrenadeExplodeSound)
	}
	
	if (ArraySize(g_aFireGrenadePlayerSound) == 0)
	{
		for (iIndex = 0; iIndex < sizeof g_szFireGrenadePlayerSound; iIndex++)
			ArrayPushString(g_aFireGrenadePlayerSound, g_szFireGrenadePlayerSound[iIndex])
		
		// Save to external file
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "GRENADE FIRE PLAYER", g_aFireGrenadePlayerSound)
	}
	
	// Load from external file, save if not found
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "V_GRENADE FIRE", g_v_szModelFireGrenade, charsmax(g_v_szModelFireGrenade)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "V_GRENADE FIRE", g_v_szModelFireGrenade)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "P_GRENADE FIRE", g_p_szModelFireGrenade, charsmax(g_p_szModelFireGrenade)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "P_GRENADE FIRE", g_p_szModelFireGrenade)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "W_GRENADE FIRE", g_w_szModelFireGrenade, charsmax(g_w_szModelFireGrenade)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "W_GRENADE FIRE", g_w_szModelFireGrenade)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "TRAIL", g_szGrenadeTrailSprite, charsmax(g_szGrenadeTrailSprite)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "TRAIL", g_szGrenadeTrailSprite)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "RING", g_szGrenadeRingSprite, charsmax(g_szGrenadeRingSprite)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "RING", g_szGrenadeRingSprite)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "FIRE", g_szGrenadeFireSprite, charsmax(g_szGrenadeFireSprite)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "FIRE", g_szGrenadeFireSprite)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "SMOKE", g_szGrenadeSmokeSprite, charsmax(g_szGrenadeSmokeSprite)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "SMOKE", g_szGrenadeSmokeSprite)
	
	// Precache sounds
	
	new szSound[MAX_SOUND_LENGTH], iArrSize
	
	// Get number of sounds in dynamic array.
	iArrSize = ArraySize(g_aFireGrenadeExplodeSound)

	for (iIndex = 0; iIndex < iArrSize; iIndex++)
	{
		ArrayGetString(g_aFireGrenadeExplodeSound, iIndex, szSound, charsmax(szSound))
		precache_sound(szSound)
	}

	// Get number of sounds in dynamic array.
	iArrSize = ArraySize(g_aFireGrenadePlayerSound)	

	for (iIndex = 0; iIndex < iArrSize; iIndex++)
	{
		ArrayGetString(g_aFireGrenadePlayerSound, iIndex, szSound, charsmax(szSound))
		precache_sound(szSound)
	}
	
	// Precache Models
	precache_model(g_v_szModelFireGrenade)
	precache_model(g_p_szModelFireGrenade)
	precache_model(g_w_szModelFireGrenade)
	
	// Precache Sprites
	g_iTrailSpr = precache_model(g_szGrenadeTrailSprite)
	g_iExplodeSpr = precache_model(g_szGrenadeRingSprite)
	g_iFlameSpr = precache_model(g_szGrenadeFireSprite)
	g_iSmokeSpr = precache_model(g_szGrenadeSmokeSprite)
}

// Forward called after player humanized.
public ze_user_humanized(id)
{
	// Stop burning
	remove_task(id+TASK_BURN)
	g_iBurningDuration[id] = 0
	
	// Set player view and weapon Models.
	cs_set_player_view_model(id, CSW_HEGRENADE, g_v_szModelFireGrenade)
	cs_set_player_weap_model(id, CSW_HEGRENADE, g_p_szModelFireGrenade)
}

// Hook called every new Round.
public New_Round()
{
	// Set w_ models for grenades on ground
	new szModel[MAX_MODEL_LENGTH], iEntity = NULLENT
	while((iEntity = rg_find_ent_by_class(iEntity, "armoury_entity")))
	{
		get_entvar(iEntity, var_model, szModel, charsmax(szModel))
		
		if (equali(szModel, "models/w_hegrenade.mdl"))
			engfunc(EngFunc_SetModel, iEntity, g_w_szModelFireGrenade)
	}
}

// Hook called after player killed. 
public Fw_PlayerKilled_Post(iVictim, iAttacker)
{
	remove_task(iVictim+TASK_BURN)
	g_iBurningDuration[iVictim] = 0
}

// Forward called when player disconnected from server.
public client_disconnected(id)
{
	remove_task(id+TASK_BURN)
	g_iBurningDuration[id] = 0
}

public Fw_SetModel_Post(entity, const model[])
{
	// Entity is not grenade?
	if (strlen(model) < 8)
		return FMRES_IGNORED
	
	// Grenade is not thrown yet?
	if (get_entvar(entity, var_dmgtime) == 0.0)
		return FMRES_IGNORED
	
	// Owner of grenade is Zombie?
	if (ze_is_user_zombie_ex(get_entvar(entity, var_owner)))
		return FMRES_IGNORED
	
	// It's a hegrenade entity?
	if (model[9] == 'h' && model[10] == 'e')
	{
		// Set entity rendering (Red Glowshell)
		Set_Rendering(entity, kRenderFxGlowShell, 200, 0, 0, kRenderNormal, 16)
		
		// Set entity Trail (Follow Beam)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW) // TE id
		write_short(entity) // entity
		write_short(g_iTrailSpr) // sprite
		write_byte(10) // life
		write_byte(10) // width
		write_byte(200) // r
		write_byte(0) // g
		write_byte(0) // b
		write_byte(200) // brightness
		message_end()
		
		// Set entity grenade ID.
		set_entvar(entity, var_flTimeStepSound, 2222.0)
	}
	
	// Set w_ model
	if (equali(model, "models/w_hegrenade.mdl"))
	{
		engfunc(EngFunc_SetModel, entity, g_w_szModelFireGrenade)
		return FMRES_SUPERCEDE // Block set entity World Model.
	}
	
	return FMRES_IGNORED
}

// Hook called when grenade entity think.
public Fw_ThinkGrenade_Post(entity)
{
	// Invalid entity?
	if (is_nullent(entity)) return HAM_IGNORED
	
	// Grenade is not below yet?
	if (get_entvar(entity, var_dmgtime) > get_gametime())
		return HAM_IGNORED
	
	// Entity is not a FireNade.
	if (get_entvar(entity, var_flTimeStepSound) != 2222.0)
		return HAM_IGNORED
	
	// Fire explode.
	fire_explode(entity)
	
	// Default explosion of HE Grenade.
	if (g_bFireExplosion)
	{
		set_entvar(entity, var_flTimeStepSound, 0.0)
		return HAM_IGNORED
	}
	
	// Remove entity.
	engfunc(EngFunc_RemoveEntity, entity)
	return HAM_SUPERCEDE // Block property of entity.
}

fire_explode(ent)
{
	// Local Variables.
	new Float:origin[3], victim

	// Get origin of entity.
	get_entvar(ent, var_origin, origin)
	
	// Default explosion of hegrenade?
	if (!g_bFireExplosion)
	{
		create_blast2(origin)
		
		// Fire nade explode sound
		static szSound[MAX_SOUND_LENGTH]
		ArrayGetString(g_aFireGrenadeExplodeSound, random_num(0, ArraySize(g_aFireGrenadeExplodeSound) - 1), szSound, charsmax(szSound))
		emit_sound(ent, CHAN_WEAPON, szSound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	
	// Hit type?
	if (!g_bHitType)
	{
		victim = NULLENT

		// Find on Victim in field of explosive.
		while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, origin, g_flFireRadius)))
		{
			// Player not alive or Is not Zombie?
			if (!is_user_alive(victim) || !ze_is_user_zombie_ex(victim))
				continue
			
			// Burn victim.
			set_on_fire(victim)
		}
	}
	else
	{	
		// Local Variables.
		new Float:flVictimOrigin[3], Float:flFraction, iPlayers[MAX_PLAYERS], iAliveCount, tr

		// Get index of all alive players.
		get_players(iPlayers, iAliveCount, "ah")

		// Create new trace handle.
		tr = create_tr2()

		// Find on player 
		for (new iNum = 0; iNum < iAliveCount; iNum++)
		{
			// Get player index from Array.
			victim = iPlayers[iNum]

			// Player is not Zombie?
			if (!ze_is_user_zombie_ex(victim))
				continue
			
			// Get origin of victim.
			get_entvar(victim, var_origin, flVictimOrigin)
			
			// Check distance between victim and grenade!
			if(vector_distance(origin, flVictimOrigin) > g_flFireRadius)
				continue

			// Check player is located in field of grenade using Trace line.
			origin[2] += 2.0
			engfunc(EngFunc_TraceLine, origin, flVictimOrigin, DONT_IGNORE_MONSTERS, ent, tr)
			origin[2] -= 2.0
			
			// Get trace fraction.
			get_tr2(tr, TR_flFraction, flFraction)
			
			// Victim is located in field of grenade?
			if(flFraction != 1.0 && get_tr2(tr, TR_pHit) != victim)
				continue
			
			// Burn player.
			set_on_fire(victim)
		}
		
		// Free the trace handler
		free_tr2(tr)
	}
}

set_on_fire(victim, delay = -1)
{
	// Execute forward ze_fire_pre(id)
	ExecuteForward(g_iFwUserBurn, g_iForwardReturn, victim)

	// Forward has return value 1 or above?
	if (g_iForwardReturn >= ZE_STOP)
		return false;
	
	// Show Fire HUD Icon?
	if (g_bFireHudIcon)
	{
		message_begin(MSG_ONE_UNRELIABLE, msg_Damage, .player = victim)
		write_byte(0) // damage save
		write_byte(0) // damage take
		write_long(DMG_BURN) // damage type
		write_coord(0) // x
		write_coord(0) // y
		write_coord(0) // z
		message_end()
	}
	
	// Set fire duration.
	g_iBurningDuration[victim] += (delay <= -1) ? (g_iFireDuration * 5) : (delay * 5)

	remove_task(victim+TASK_BURN)
	set_task(0.2, "burning_flame", victim+TASK_BURN, _, _, "b")
	return true
}

// Burning Flames
public burning_flame(id)
{
	// Get player index.
	id -= TASK_BURN

	static origin[3]
	get_user_origin(id, origin)
	new flags = get_entvar(id, var_flags)
	
	if ((flags & FL_INWATER) || g_iBurningDuration[id] < 1)
	{
		// Smoke sprite
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
		write_byte(TE_SMOKE) // TE id
		write_coord(origin[0]) // x
		write_coord(origin[1]) // y
		write_coord(origin[2]-50) // z
		write_short(g_iSmokeSpr) // sprite
		write_byte(random_num(15, 20)) // scale
		write_byte(random_num(10, 20)) // framerate
		message_end()
		
		// Task not needed anymore
		remove_task(id+TASK_BURN)
		return;
	}
	
	// Randomly play burning zombie scream sounds
	if (random_num(1, 20) == 1)
	{
		static szSound[MAX_SOUND_LENGTH]
		ArrayGetString(g_aFireGrenadePlayerSound, random_num(0, ArraySize(g_aFireGrenadePlayerSound) - 1), szSound, charsmax(szSound))
		emit_sound(id, CHAN_VOICE, szSound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	
	// Fire slow down
	if ((flags & FL_ONGROUND) && g_flFireSlowDown > 0.0)
	{
		static Float:fVelocity[3]
		get_entvar(id, var_velocity, fVelocity)
		fVelocity[0] *= g_flFireSlowDown
		fVelocity[1] *= g_flFireSlowDown
		fVelocity[2] *= g_flFireSlowDown
		set_entvar(id, var_velocity, fVelocity)
	}
	
	static Float:flHealth

	// Get health of player.
	flHealth = get_entvar(id, var_health)
	
	if ((flHealth - g_flFireDamage) > 0.0)
		set_entvar(id, var_health, (flHealth - g_flFireDamage))
	
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_SPRITE) // TE id
	write_coord(origin[0]+random_num(-5, 5)) // x
	write_coord(origin[1]+random_num(-5, 5)) // y
	write_coord(origin[2]+random_num(-10, 10)) // z
	write_short(g_iFlameSpr) // sprite
	write_byte(random_num(5, 10)) // scale
	write_byte(200) // brightness
	message_end()
	
	g_iBurningDuration[id]--
}

// Fire Grenade: Fire Blast
create_blast2(const Float:origin[3])
{
	// Smallest ring
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	write_coord_f(origin[0]) // x
	write_coord_f(origin[1]) // y
	write_coord_f(origin[2]) // z
	write_coord_f(origin[0]) // x axis
	write_coord_f(origin[1]) // y axis
	write_coord_f(origin[2]+385.0) // z axis
	write_short(g_iExplodeSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(200) // red
	write_byte(100) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Medium ring
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	write_coord_f(origin[0]) // x
	write_coord_f(origin[1]) // y
	write_coord_f(origin[2]) // z
	write_coord_f(origin[0]) // x axis
	write_coord_f(origin[1]) // y axis
	write_coord_f(origin[2]+470.0) // z axis
	write_short(g_iExplodeSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(200) // red
	write_byte(50) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Largest ring
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, origin, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	write_coord_f(origin[0]) // x
	write_coord_f(origin[1]) // y
	write_coord_f(origin[2]) // z
	write_coord_f(origin[0]) // x axis
	write_coord_f(origin[1]) // y axis
	write_coord_f(origin[2]+555.0) // z axis
	write_short(g_iExplodeSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(200) // red
	write_byte(0) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
}

/**
 * Function of natives:
 */
public native_ze_zombie_in_fire(id)
{
	if (!is_user_alive(id))
		return NULLENT;
	
	return task_exists(id+TASK_BURN)
}

public native_ze_set_fire_grenade(id, set)
{
	if (!is_user_alive(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player (%d)", id)
		return NULLENT;
	}
	
	if (!set)
	{
		if (!task_exists(id+TASK_BURN))
			return true
		
		new origin[3]
		get_user_origin(id, origin)
		
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
		write_byte(TE_SMOKE) // TE id
		write_coord(origin[0]) // x
		write_coord(origin[1]) // y
		write_coord(origin[2]-50) // z
		write_short(g_iSmokeSpr) // sprite
		write_byte(random_num(15, 20)) // scale
		write_byte(random_num(10, 20)) // framerate
		message_end()
		
		remove_task(id+TASK_BURN)
		return true
	}
	
	return set_on_fire(id)
}

public native_ze_set_fire_grenade_ex(id, delay)
{
	if (!is_user_alive(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player (%d)", id)
		return NULLENT;
	}
	
	// Burn player.
	return set_on_fire(id, delay)
}