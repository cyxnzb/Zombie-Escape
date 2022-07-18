#include <zombie_escape>

// Defines
#define TASK_FROST_REMOVE 200
#define TASK_FREEZE 2018

// Default Sounds
new const g_szFrostGrenadeExplodeSound[][] = { "warcraft3/frostnova.wav" }
new const g_szFrostGrenadePlayerSound[][] = { "warcraft3/impalehit.wav" }
new const g_szFrostGrenadeBreakSound[][] = { "warcraft3/impalelaunch1.wav" }

// Default Models
new g_v_szFrostGrenadeModel[MAX_MODEL_LENGTH] = "models/zombie_escape/v_grenade_frost.mdl"
new g_p_szFrostGrenadeModel[MAX_MODEL_LENGTH] = "models/zombie_escape/p_grenade_frost.mdl"
new g_w_szFrostGrenadeModel[MAX_MODEL_LENGTH] = "models/zombie_escape/w_grenade_frost.mdl"

// Default Sprites
new g_szGrenadeTrailSprite[MAX_MODEL_LENGTH] = "sprites/laserbeam.spr"
new g_szGrenadeRingSprite[MAX_MODEL_LENGTH] = "sprites/shockwave.spr"
new g_szGrenadeGlassSprite[MAX_MODEL_LENGTH] = "models/glassgibs.mdl"

// Dynamic Arrays
new Array:g_aFrostGrenadeExplodeSound
new Array:g_aFrostGrenadePlayerSound
new Array:g_aFrostGrenadeBreakSound

// Enums (Renders)
enum _:RENDERS
{
	REN_FX,
	REN_MODE,
	Float:REN_COLORS[3],
	Float:REN_AMOUNT
}

// Enums (Forwards)
enum _:TOTAL_FORWARDS
{
	FW_USER_FREEZE_PRE = 0,
	FW_USER_UNFROZEN
}

// Variables
new g_iTrailSpr,
	g_iExplodeSpr,
	g_iGlassSpr, 
	g_iForwardReturn,
	g_iForwards[TOTAL_FORWARDS],
	bool:g_bHitType,
	bool:g_bFrostHudIcon,
	bool:g_bFrozenDamage,
	bool:g_bIsFrozen[MAX_PLAYERS+1],
	Float:g_flFrostRadius,
	Float:g_flFrostDuration

// Array's.
new g_pFrozenOldRendering[MAX_PLAYERS+1][RENDERS]

// Forward allows register new natives.
public plugin_natives()
{
	register_native("ze_zombie_in_forst", "native_ze_zombie_in_forst", 1)
	register_native("ze_set_frost_grenade", "native_ze_set_frost_grenade", 1)
	register_native("ze_set_frost_grenade_ex", "native_ze_set_frost_grenade_ex", 1)
}

// Forward called after server activation.
public plugin_init()
{
	// Load plugin.
	register_plugin("[ZE] Frost Nade", ZE_VERSION, AUTHORS, ZE_HOMEURL, "Frost Grenade")
	
	// Hook Chains
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "Fw_TraceAttack_Pre", 0)
	RegisterHookChain(RG_CBasePlayer_Killed, "Fw_PlayerKilled_Post", 1)
	RegisterHookChain(RG_CBasePlayer_PreThink, "Fw_PreThink_Post", 1)
	
	// Events
	register_event("HLTV", "New_Round", "a", "1=0", "2=0")
	
	// Hams
	RegisterHam(Ham_Think, "grenade", "Fw_ThinkGrenade_Post", 1)	
	
	// Fakemeta
	register_forward(FM_SetModel, "Fw_SetModel_Post", 1)
	
	// Forwards
	g_iForwards[FW_USER_FREEZE_PRE] = CreateMultiForward("ze_frost_pre", ET_CONTINUE, FP_CELL)
	g_iForwards[FW_USER_UNFROZEN] = CreateMultiForward("ze_frost_unfreeze", ET_IGNORE, FP_CELL)
	
	// Cvars.
	bind_pcvar_float(create_cvar("ze_frost_duration", "3"), g_flFrostDuration)
	bind_pcvar_num(create_cvar("ze_frost_hud_icon", "1"), g_bFrostHudIcon)
	bind_pcvar_num(create_cvar("ze_freeze_damage", "0"), g_bFrozenDamage)
	bind_pcvar_float(create_cvar("ze_freeze_radius", "240.0"), g_flFrostRadius)
	bind_pcvar_num(create_cvar("ze_freeze_hit_type", "0"), g_bHitType)
}

public plugin_precache()
{
	// Initialize arrays
	g_aFrostGrenadeExplodeSound = ArrayCreate(MAX_SOUND_LENGTH, 1)
	g_aFrostGrenadePlayerSound = ArrayCreate(MAX_SOUND_LENGTH, 1)
	g_aFrostGrenadeBreakSound = ArrayCreate(MAX_SOUND_LENGTH, 1)
	
	// Load from external file
	amx_load_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "FROST GRENADE EXPLODE", g_aFrostGrenadeExplodeSound)
	amx_load_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "FROST GRENADE PLAYER", g_aFrostGrenadePlayerSound)
	amx_load_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "FROST GRENADE BREAK", g_aFrostGrenadeBreakSound)
	
	// If we couldn't load custom sounds from file, use and save default ones
	
	new iIndex
	
	if (ArraySize(g_aFrostGrenadeExplodeSound) == 0)
	{
		for (iIndex = 0; iIndex < sizeof g_szFrostGrenadeExplodeSound; iIndex++)
			ArrayPushString(g_aFrostGrenadeExplodeSound, g_szFrostGrenadeExplodeSound[iIndex])
		
		// Save to external file
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "FROST GRENADE EXPLODE", g_aFrostGrenadeExplodeSound)
	}
	
	if (ArraySize(g_aFrostGrenadePlayerSound) == 0)
	{
		for (iIndex = 0; iIndex < sizeof g_szFrostGrenadePlayerSound; iIndex++)
			ArrayPushString(g_aFrostGrenadePlayerSound, g_szFrostGrenadePlayerSound[iIndex])
		
		// Save to external file
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "FROST GRENADE PLAYER", g_aFrostGrenadePlayerSound)
	}
	
	if (ArraySize(g_aFrostGrenadeBreakSound) == 0)
	{
		for (iIndex = 0; iIndex < sizeof g_szFrostGrenadeBreakSound; iIndex++)
			ArrayPushString(g_aFrostGrenadeBreakSound, g_szFrostGrenadeBreakSound[iIndex])
		
		// Save to external file
		amx_save_setting_string_arr(ZE_SETTING_RESOURCES, "Sounds", "FROST GRENADE BREAK", g_aFrostGrenadeBreakSound)
	}
	
	// Load from external file, save if not found
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "V_GRENADE FROST", g_v_szFrostGrenadeModel, charsmax(g_v_szFrostGrenadeModel)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "V_GRENADE FROST", g_v_szFrostGrenadeModel)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "P_GRENADE FROST", g_p_szFrostGrenadeModel, charsmax(g_p_szFrostGrenadeModel)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "P_GRENADE FROST", g_p_szFrostGrenadeModel)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "W_GRENADE FROST", g_w_szFrostGrenadeModel, charsmax(g_w_szFrostGrenadeModel)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Weapon Models", "W_GRENADE FROST", g_w_szFrostGrenadeModel)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "TRAIL", g_szGrenadeTrailSprite, charsmax(g_szGrenadeTrailSprite)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "TRAIL", g_szGrenadeTrailSprite)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "RING", g_szGrenadeRingSprite, charsmax(g_szGrenadeRingSprite)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "RING", g_szGrenadeRingSprite)
	if (!amx_load_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "GLASS", g_szGrenadeGlassSprite, charsmax(g_szGrenadeGlassSprite)))
		amx_save_setting_string(ZE_SETTING_RESOURCES, "Grenade Sprites", "GLASS", g_szGrenadeGlassSprite)
	
	// Precache sounds
	
	new szSound[MAX_SOUND_LENGTH], iArrSize
	
	// Get number of sounds in dynamic array
	iArrSize = ArraySize(g_aFrostGrenadeExplodeSound)

	for (iIndex = 0; iIndex < iArrSize; iIndex++)
	{
		ArrayGetString(g_aFrostGrenadeExplodeSound, iIndex, szSound, charsmax(szSound))
		precache_sound(szSound)
	}

	// Get number of sounds in dynamic array
	iArrSize = ArraySize(g_aFrostGrenadePlayerSound)

	for (iIndex = 0; iIndex < iArrSize; iIndex++)
	{
		ArrayGetString(g_aFrostGrenadePlayerSound, iIndex, szSound, charsmax(szSound))
		precache_sound(szSound)
	}

	// Get number of sounds in dynamic array
	iArrSize = ArraySize(g_aFrostGrenadeBreakSound)

	for (iIndex = 0; iIndex < iArrSize; iIndex++)
	{
		ArrayGetString(g_aFrostGrenadeBreakSound, iIndex, szSound, charsmax(szSound))
		precache_sound(szSound)
	}
	
	// Precache models
	precache_model(g_v_szFrostGrenadeModel)
	precache_model(g_p_szFrostGrenadeModel)
	precache_model(g_w_szFrostGrenadeModel)
	
	// Precache sprites
	g_iTrailSpr = precache_model(g_szGrenadeTrailSprite)
	g_iExplodeSpr = precache_model(g_szGrenadeRingSprite)
	g_iGlassSpr = precache_model(g_szGrenadeGlassSprite)
}

// Forward called after player humanized.
public ze_user_humanized(id)
{
	// Set custom grenade model
	cs_set_player_view_model(id, CSW_FLASHBANG, g_v_szFrostGrenadeModel)
	cs_set_player_weap_model(id, CSW_FLASHBANG, g_p_szFrostGrenadeModel)
	cs_set_player_view_model(id, CSW_SMOKEGRENADE, g_v_szFrostGrenadeModel)
	cs_set_player_weap_model(id, CSW_SMOKEGRENADE, g_p_szFrostGrenadeModel)
	
	// If frozen, remove freeze after player is cured
	if (g_bIsFrozen[id])
	{
		// Update rendering values first
		ApplyFrozenRendering(id)
		
		// Remove freeze right away and stop the task
		RemoveFreeze(id+TASK_FROST_REMOVE)
		remove_task(id+TASK_FROST_REMOVE)
	}
}

// Hook called when player pre-think.
public Fw_PreThink_Post(id)
{
	if (g_bIsFrozen[id])
		set_entvar(id, var_velocity, 0.0) // Stop and Freeze Zombie
}

// Forward called when playe disconnected from the server.
public client_disconnected(id)
{
	g_bIsFrozen[id] = false
	remove_task(id+TASK_FROST_REMOVE)
}

// Hook called every new Round.
public New_Round()
{
	remove_task(TASK_FREEZE)
	
	// Set w_ models for grenades on ground
	new szModel[MAX_MODEL_LENGTH], iEntity = NULLENT
	while((iEntity = rg_find_ent_by_class( iEntity, "armoury_entity")))
	{
		// Get model of entity.
		get_entvar(iEntity, var_model, szModel, charsmax(szModel))
		
		if (equali(szModel, "models/w_flashbang.mdl") || equali(szModel, "models/w_smokegrenade.mdl"))
			engfunc(EngFunc_SetModel, iEntity, g_w_szFrostGrenadeModel)
	}
}

// Hook called when player trace attack.
public Fw_TraceAttack_Pre(iVictim, iAttacker)
{
	// Block damage while frozen
	if (!g_bFrozenDamage && g_bIsFrozen[iVictim])
		return HC_SUPERCEDE
	return HC_CONTINUE
}

// Hook called after player killed.
public Fw_PlayerKilled_Post(iVictim)
{
	// Frozen player being killed
	if (g_bIsFrozen[iVictim])
	{
		// Remove freeze right away and stop the task
		RemoveFreeze(iVictim+TASK_FROST_REMOVE)
		remove_task(iVictim+TASK_FROST_REMOVE)
	}
}

// Hook called when set entity Model.
public Fw_SetModel_Post(entity, const model[])
{
	// Entity is not grenade?
	if (strlen(model) < 8) return FMRES_IGNORED
	
	// Grenade not yet thrown?
	if (get_entvar(entity, var_dmgtime) == 0.0) return FMRES_IGNORED
	
	// Grenade's owner is zombie?
	if (ze_is_user_zombie(get_entvar(entity, var_owner))) return FMRES_IGNORED

	// Flashbang or Smoke
	if ((model[9] == 'f' && model[10] == 'l') || (model[9] == 's' && model[10] == 'm'))
	{
		// Give it a glow
		Set_Rendering(entity, kRenderFxGlowShell, 0, 100, 200, kRenderNormal, 16);
		
		// And a colored trail
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW) // TE id
		write_short(entity) // entity
		write_short(g_iTrailSpr) // sprite
		write_byte(10) // life
		write_byte(10) // width
		write_byte(0) // r
		write_byte(100) // g
		write_byte(200) // b
		write_byte(200) // brightness
		message_end()
		
		// Set grenade type on the thrown grenade entity
		set_entvar(entity, var_flTimeStepSound, 3333.0)
	}
	
	// Set w_ model
	if (equali(model, "models/w_flashbang.mdl") || equali(model, "models/w_smokegrenade.mdl"))
	{
		engfunc(EngFunc_SetModel, entity, g_w_szFrostGrenadeModel)
		return FMRES_SUPERCEDE // Block set entity old Model.
	}
	
	return FMRES_IGNORED
}

// Hook called when grenade entity think.
public Fw_ThinkGrenade_Post(entity)
{
	// Invalid entity
	if (is_nullent(entity))
		return HAM_IGNORED
	
	// Check if it's time to go off
	if (get_entvar(entity, var_dmgtime) > get_gametime())
		return HAM_IGNORED
	
	// Check if it's one of our custom nades
	if (get_entvar(entity, var_flTimeStepSound) == 3333.0)
	{
		frost_explode(entity)
		return HAM_SUPERCEDE // Block property of grenade.		
	}
		
	return HAM_IGNORED
}

// Frost Grenade Explosion
frost_explode(ent)
{
	// Get origin
	new Float:origin[3], victim
	get_entvar(ent, var_origin, origin)
	
	// Make the explosion
	create_blast3(origin)
	
	// Frost nade explode sound
	new sound[MAX_SOUND_LENGTH]
	ArrayGetString(g_aFrostGrenadeExplodeSound, random_num(0, ArraySize(g_aFrostGrenadeExplodeSound) - 1), sound, charsmax(sound))
	emit_sound(ent, CHAN_WEAPON, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Collisions
	if (!g_bHitType)
	{
		victim = NULLENT
		
		while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, origin, g_flFrostRadius)))
		{
			// Only effect alive zombies, If player not released yet don't freeze him
			if (!is_user_alive(victim) || !ze_is_user_zombie_ex(victim))
				continue
			
			set_freeze(victim)
		}
	}
	else
	{
		new iPlayers[MAX_PLAYERS], iAliveCount
		new Float:flVictimOrigin[3], Float:flFraction, tr
		
		// Get index of all alive players.
		get_players(iPlayers, iAliveCount, "ah")

		// Create trace handle.
		tr = create_tr2()
		
		for(new iNum = 0; iNum < iAliveCount; iNum++)
		{
			// Get player index from Array.
			victim = iPlayers[iNum]

			// Player is not Zombie?
			if (!ze_is_user_zombie_ex(victim))
				continue
			
			// Get origin of victim.
			get_entvar(victim, var_origin, flVictimOrigin)
			
			// Get distance between nade and player			
			if(vector_distance(origin, flVictimOrigin) > g_flFrostRadius)
				continue
			
			// Check player if in field of grenade using Trace line.
			origin[2] += 2.0
			engfunc(EngFunc_TraceLine, origin, flVictimOrigin, DONT_IGNORE_MONSTERS, ent, tr)
			origin[2] -= 2.0
			
			// Get trace fraction.
			get_tr2(tr, TR_flFraction, flFraction)
			
			// Player in field of grenade?
			if(flFraction != 1.0 && get_tr2(tr, TR_pHit) != victim)
				continue;
			
			// Freeze player.
			set_freeze(victim)
		}
		
		// Free the trace handler
		free_tr2(tr)
	}
	
	// Remove grenade entity.
	engfunc(EngFunc_RemoveEntity, ent)
}

set_freeze(victim, Float:flUnFreeze = -1.0)
{
	// Already frozen
	if (g_bIsFrozen[victim])
		return false
	
	// Local Variables.
	new origin[3], sound[MAX_SOUND_LENGTH]

	// Allow other plugins to decide whether player should be frozen or not
	ExecuteForward(g_iForwards[FW_USER_FREEZE_PRE], g_iForwardReturn, victim)
	
	if (g_iForwardReturn >= ZE_STOP)
	{
		// Get player's origin
		get_user_origin(victim, origin)
		
		// Broken glass sound
		ArrayGetString(g_aFrostGrenadeBreakSound, random_num(0, ArraySize(g_aFrostGrenadeBreakSound) - 1), sound, charsmax(sound))
		emit_sound(victim, CHAN_BODY, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		// Glass shatter
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
		write_byte(TE_BREAKMODEL) // TE id
		write_coord(origin[0]) // x
		write_coord(origin[1]) // y
		write_coord(origin[2]+24) // z
		write_coord(16) // size x
		write_coord(16) // size y
		write_coord(16) // size z
		write_coord(random_num(-50, 50)) // velocity x
		write_coord(random_num(-50, 50)) // velocity y
		write_coord(25) // velocity z
		write_byte(10) // random velocity
		write_short(g_iGlassSpr) // model
		write_byte(10) // count
		write_byte(25) // life
		write_byte(0x01) // flags
		message_end()
		
		return false
	}
	
	// Freeze icon?
	if (g_bFrostHudIcon)
	{
		message_begin(MSG_ONE_UNRELIABLE, msg_Damage, _, victim)
		write_byte(0) // damage save
		write_byte(0) // damage take
		write_long(DMG_DROWN) // damage type - DMG_FREEZE
		write_coord(0) // x
		write_coord(0) // y
		write_coord(0) // z
		message_end()
	}
	
	// Set frozen flag
	g_bIsFrozen[victim] = true
	set_entvar(victim, var_maxspeed, 1.0)	

	// Freeze sound
	ArrayGetString(g_aFrostGrenadePlayerSound, random_num(0, ArraySize(g_aFrostGrenadePlayerSound) - 1), sound, charsmax(sound))
	emit_sound(victim, CHAN_BODY, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Add a blue tint to their screen
	message_begin(MSG_ONE, msg_ScreenFade, _, victim)
	write_short(0) // duration
	write_short(0) // hold time
	write_short(SF_FADE_ONLYONE) // fade type
	write_byte(0) // red
	write_byte(50) // green
	write_byte(200) // blue
	write_byte(100) // alpha
	message_end()
	
	// Update player entity rendering
	ApplyFrozenRendering(victim)
	
	// Set a task to remove the freeze
	if (flUnFreeze < 0.0)
		set_task(g_flFrostDuration, "RemoveFreeze", victim+TASK_FROST_REMOVE)
	else
		set_task(flUnFreeze, "RemoveFreeze", victim+TASK_FROST_REMOVE)
	return true
}

ApplyFrozenRendering(id)
{
	// Local Variables.
	new iRenderFx, iRenderMode, Float:flRenderColors[3], Float:flRenderAmount

	// Get current rendering
	iRenderFx = get_entvar(id, var_renderfx)
	iRenderMode = get_entvar(id, var_rendermode)
	get_entvar(id, var_rendercolor, flRenderColors)
	flRenderAmount = get_entvar(id, var_renderamt)
	
	// Already set, no worries...
	if (iRenderFx == kRenderFxGlowShell && 
		flRenderColors[0] == 0.0 && 
		flRenderColors[1] == 100.0 && 
		flRenderColors[2] == 200.0 && 
		iRenderMode == kRenderNormal && 
		flRenderAmount == 25.0
	) return
	
	// Save player's old rendering
	g_pFrozenOldRendering[id][REN_FX] = iRenderFx
	g_pFrozenOldRendering[id][REN_MODE] = iRenderMode
	g_pFrozenOldRendering[id][REN_COLORS] = flRenderColors
	g_pFrozenOldRendering[id][REN_AMOUNT] = flRenderAmount

	// Light blue glow while frozen
	Set_Rendering(id, kRenderFxGlowShell, 0, 100, 200, kRenderNormal, 25)
}

// Remove freeze task
public RemoveFreeze(id)
{
	// Get player index.
	id -= TASK_FROST_REMOVE

	// Remove frozen flag
	g_bIsFrozen[id] = false
	rg_reset_maxspeed(id) // This is will reset zombie speed, which leads to set zombie speed from ze_core.

	// Restore rendering
	new iRed = floatround(g_pFrozenOldRendering[id][REN_COLORS+0])
	new iGreen = floatround(g_pFrozenOldRendering[id][REN_COLORS+1])
	new iBlue = floatround(g_pFrozenOldRendering[id][REN_COLORS+2])

	Set_Rendering(id, g_pFrozenOldRendering[id][REN_FX], iRed, iGreen, iBlue, g_pFrozenOldRendering[id][REN_MODE], floatround(g_pFrozenOldRendering[id][REN_AMOUNT]))

	// Gradually remove screen's blue tint
	message_begin(MSG_ONE, msg_ScreenFade, .player = id)
	write_short((1<<12)) // duration
	write_short(0) // hold time
	write_short(0x0000) // fade type
	write_byte(0) // red
	write_byte(50) // green
	write_byte(200) // blue
	write_byte(100) // alpha
	message_end()
	
	// Broken glass sound
	new sound[MAX_SOUND_LENGTH]
	ArrayGetString(g_aFrostGrenadeBreakSound, random_num(0, ArraySize(g_aFrostGrenadeBreakSound) - 1), sound, charsmax(sound))
	emit_sound(id, CHAN_BODY, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Get player's origin
	new origin[3]
	get_user_origin(id, origin)
	
	// Glass shatter
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_BREAKMODEL) // TE id
	write_coord(origin[0]) // x
	write_coord(origin[1]) // y
	write_coord(origin[2]+24) // z
	write_coord(16) // size x
	write_coord(16) // size y
	write_coord(16) // size z
	write_coord(random_num(-50, 50)) // velocity x
	write_coord(random_num(-50, 50)) // velocity y
	write_coord(25) // velocity z
	write_byte(10) // random velocity
	write_short(g_iGlassSpr) // model
	write_byte(10) // count
	write_byte(25) // life
	write_byte(BREAK_GLASS) // flags
	message_end()
	
	ExecuteForward(g_iForwards[FW_USER_UNFROZEN], g_iForwardReturn, id)
}

// Frost Grenade: Freeze Blast
create_blast3(const Float:originF[3])
{
	// Smallest ring
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	write_coord_f(originF[0]) // x
	write_coord_f(originF[1]) // y
	write_coord_f(originF[2]) // z
	write_coord_f(originF[0]) // x axis
	write_coord_f(originF[1]) // y axis
	write_coord_f(originF[2]+385.0) // z axis
	write_short(g_iExplodeSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(100) // green
	write_byte(200) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Medium ring
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	write_coord_f(originF[0]) // x
	write_coord_f(originF[1]) // y
	write_coord_f(originF[2]) // z
	write_coord_f(originF[0]) // x axis
	write_coord_f(originF[1]) // y axis
	write_coord_f(originF[2]+470.0) // z axis
	write_short(g_iExplodeSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(100) // green
	write_byte(200) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Largest ring
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	write_coord_f(originF[0]) // x
	write_coord_f(originF[1]) // y
	write_coord_f(originF[2]) // z
	write_coord_f(originF[0]) // x axis
	write_coord_f(originF[1]) // y axis
	write_coord_f(originF[2]+555.0) // z axis
	write_short(g_iExplodeSpr) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(0) // red
	write_byte(100) // green
	write_byte(200) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
}


/**
 * Functions of natives:
 */
public native_ze_zombie_in_forst(id)
{
	if (!is_user_alive(id))
	{
		return -1
	}
	
	return g_bIsFrozen[id]
}

public native_ze_set_frost_grenade(id, set)
{
	if (!is_user_alive(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player (%d)", id)
		return -1;
	}
	
	// Unfreeze
	if (!set)
	{
		// Not frozen
		if (!g_bIsFrozen[id])
			return true
		
		// Remove freeze right away and stop the task
		RemoveFreeze(id+TASK_FROST_REMOVE)
		remove_task(id+TASK_FROST_REMOVE)
		return true
	}
	
	return set_freeze(id)
}

public native_ze_set_frost_grenade_ex(id, Float:delay)
{
	if (!is_user_alive(id))
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Player (%d)", id)
		return -1;
	}
	
	return set_freeze(id, delay)	
}