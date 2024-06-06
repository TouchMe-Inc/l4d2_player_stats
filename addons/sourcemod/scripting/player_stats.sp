#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <colors>


public Plugin myinfo = {
	name = "PlayerStats",
	author = "TouchMe",
	description = "Player rating stats",
	version = "build_0000",
	url = "https://github.com/TouchMe-Inc/l4d2_player_stats"
};


/*
 * Team.
 */
#define TEAM_NONE               0
#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

/*
 * Infected Class.
 */
#define SI_CLASS_SMOKER         1
#define SI_CLASS_BOOMER         2
#define SI_CLASS_HUNTER         3
#define SI_CLASS_SPITTER        4
#define SI_CLASS_JOCKEY         5
#define SI_CLASS_CHARGER        6
#define SI_CLASS_WITCH          7
#define SI_CLASS_TANK           8

// Other
#define DATABASE_CONFIG         "versus_stats"

// #define MIN_RANKED_SEC          RoundFloat(3600.0 * GetConVarFloat(g_cvHoursToStartRating))

// #define COST_I_INCAPACITATE     GetConVarFloat(g_cvInfectedIncapacitateCost)
// #define COST_I_KILL             GetConVarFloat(g_cvInfectedKillCost)
// #define COST_S_KILL             GetConVarFloat(g_cvSurvivorKillCost)
// #define COST_S_KILL_CI          GetConVarFloat(g_cvSurvivorKillCICost)
// #define COST_S_DEATH            GetConVarFloat(g_cvSurvivorDeathCost)
// #define COST_S_INCAPACITATED    GetConVarFloat(g_cvSurvivorIncapacitatedCost)
// #define COST_S_TEAMKILL         GetConVarFloat(g_cvSurvivorTeamkillCost)

/**
 * +-----------------+
 * | ps_players      |
 * +-----------------+
 * | int id          |
 * | char steam_id   |
 * | char last_name  |
 * | int last_visit  |
 * +-----------------+
 */
#define SQL_CREATE_TABLE_PLAYERS "\
	CREATE TABLE IF NOT EXISTS `ps_players` ( \
		id int(10) UNSIGNED NOT NULL auto_increment, \
		steam_id varchar(32) NOT NULL, \
		last_name varchar(65) NOT NULL, \
		last_visit int(10) UNSIGNED NOT NULL, \
		PRIMARY KEY (id) \
	);"

#define SQL_SELECT_PLAYER_BY_STEAMID "SELECT `id` FROM `ps_players` WHERE `steam_id`='%s' LIMIT 1;"
#define SQL_INSERT_PLAYER "INSERT INTO `ps_players` (`steam_id`,`last_name`,`last_visit`) VALUES ('%s','%s',%d);"
#define SQL_UPDATE_PLAYER "UPDATE `ps_players` SET `last_name`='%s',`last_visit`=%d WHERE `id`=%d;"
#define SQL_CLEAR_PLAYER "DELETE FROM `ps_players` WHERE `last_visit`<%d;"

/**
 * +-----------------+
 * | ps_stats        |
 * +-----------------+
 * | int id          |
 * | char name       |
 * +-----------------+
 */
#define SQL_CREATE_TABLE_STATS "\
	CREATE TABLE IF NOT EXISTS `ps_stats` ( \
		id int(10) UNSIGNED NOT NULL auto_increment, \
		name varchar(32) NOT NULL, \
		PRIMARY KEY (id) \
	);"

#define SQL_SELECT_STATS "SELECT `id`,`name` FROM `ps_stats`;"
#define SQL_INSERT_STAT_BY_NAME "INSERT INTO `ps_stats` (`name`) VALUES ('%s');"


/**
 * +-----------------+
 * | ps_configs      |
 * +-----------------+
 * | int id          |
 * | char name       |
 * +-----------------+
 */
#define SQL_CREATE_TABLE_CONFIGS "\
	CREATE TABLE IF NOT EXISTS ps_configs (\
		id int(10) UNSIGNED NOT NULL auto_increment, \
		name varchar(32) NOT NULL, \
		PRIMARY KEY (id) \
	);"

#define SQL_SELECT_CONFIG_BY_NAME "SELECT `id` FROM `ps_configs` WHERE `name`='%s' LIMIT 1;"
#define SQL_INSERT_CONFIG_BY_NAME "INSERT INTO `ps_configs` (`name`) VALUES ('%s');"

/**
 * +-----------------+
 * | ps_player_stats |
 * +-----------------+
 * | int id          |
 * | int config_id   |
 * | int player_id   |
 * | int stats_id    |
 * | int value       |
 * +-----------------+
 */
#define SQL_CREATE_TABLE_PLAYER_STATS "\
	CREATE TABLE IF NOT EXISTS `ps_player_stats` ( \
		id int(10) UNSIGNED NOT NULL auto_increment, \
		config_id int(10) UNSIGNED NOT NULL, \
		player_id int(10) UNSIGNED NOT NULL, \
		stats_id int(10) UNSIGNED NOT NULL, \
		value bigint(20) UNSIGNED NOT NULL, \
		PRIMARY KEY (id) \
	);"

#define SQL_INSERT_PLAYER_STATS_MULTIPLY "INSERT INTO `ps_player_stats` (`config_id`,`player_id`,`stats_id`,`value`) VALUES __ROWS__;"

/**
 * +-----------------+
 * | ps_player_rating|
 * +-----------------+
 * | int id          |
 * | int config_id   |
 * | int player_id   |
 * | float rating    |
 * +-----------------+
 */
#define SQL_CREATE_TABLE_PLAYER_RATING "\
	CREATE TABLE IF NOT EXISTS ps_player_rating ( \
		id int(10) UNSIGNED NOT NULL auto_increment, \
		config_id int(10) UNSIGNED NOT NULL, \
		player_id int(10) UNSIGNED NOT NULL, \
		rating float(10,3) UNSIGNED NOT NULL, \
		PRIMARY KEY (id) \
	);"



#define STATS_PLAYED_TIME               "PLAYED_TIME"

/*
 * Infected statistic.
 */
#define STATS_KILL_CI                   "KILL_CI"               /*< Surivivor Killed Common Infected */
#define STATS_KILL_CI_HS                "KILL_CI_HS"            /*< Surivivor Killed Common Infected (Headshot) */
#define STATS_KILL_WITCH                "KILL_WITCH"            /*< Surivivor Killed Witch */
#define STATS_KILL_WITCH_OS             "KILL_WITCH_OS"         /*< Surivivor Killed Witch in one shot */
#define STATS_KILL_SI                   "KILL_SI"               /*< Surivivor Killed Special Infected */
#define STATS_KILL_SI_HS                "KILL_SI_HS"            /*< Surivivor Killed Special Infected (Headshot) */
#define STATS_KILL_SMOKER               "KILL_SMOKER"           /*< Surivivor Killed Smoker */
#define STATS_KILL_BOOMER               "KILL_BOOMER"           /*< Surivivor Killed Boomer */
#define STATS_KILL_HUNTER               "KILL_HUNTER"           /*< Surivivor Killed Hunter */
#define STATS_KILL_SPITTER              "KILL_SPITTER"          /*< Surivivor Killed Spitter */
#define STATS_KILL_JOCKEY               "KILL_JOCKEY"           /*< Surivivor Killed Jockey */
#define STATS_KILL_CHARGER              "KILL_CHARGER"          /*< Surivivor Killed Changer */

/*
 * Weapon statistic.
 */
#define STATS_KILL_BY_SMG               "KILL_BY_SMG"           /*< Surivivor killed SI by SMG */
#define STATS_KILL_BY_SILENCED          "KILL_BY_SILENCED"      /*< Surivivor killed SI by SMG silenced */
#define STATS_KILL_BY_MP5               "KILL_BY_MP5"           /*< Surivivor killed SI by MP5 */
#define STATS_KILL_BY_PUMP              "KILL_BY_PUMP"          /*< Surivivor killed SI by Pump */
#define STATS_KILL_BY_CHROME            "KILL_BY_CHROME"        /*< Surivivor killed SI by Chrome */
#define STATS_KILL_BY_SCOUT             "KILL_BY_SCOUT"         /*< Surivivor killed SI by Scout */
#define STATS_KILL_BY_M16               "KILL_BY_M16"           /*< Surivivor killed SI by Rifle (M16) */
#define STATS_KILL_BY_DESERT            "KILL_BY_DESERT"        /*< Surivivor killed SI by Desert */
#define STATS_KILL_BY_AK47              "KILL_BY_AK47"          /*< Surivivor killed SI by AK47 */
#define STATS_KILL_BY_SG552             "KILL_BY_SG552"         /*< Surivivor killed SI by Sg552 */
#define STATS_KILL_BY_HUNTING           "KILL_BY_HUNTING"       /*< Surivivor killed SI by Hunting */
#define STATS_KILL_BY_MILITARY          "KILL_BY_MILITARY"      /*< Surivivor killed SI by Military */
#define STATS_KILL_BY_AWP               "KILL_BY_AWP"           /*< Surivivor killed SI by Awp */
#define STATS_KILL_BY_AUTO              "KILL_BY_AUTO"          /*< Surivivor killed SI by Auto */
#define STATS_KILL_BY_SPAS              "KILL_BY_SPAS"          /*< Surivivor killed SI by Spas */
#define STATS_KILL_BY_MAGNUM            "KILL_BY_MAGNUM"        /*< Surivivor killed SI by Magnum */
#define STATS_KILL_BY_PISTOL            "KILL_BY_PISTOL"        /*< Surivivor killed SI by Pistol */
#define STATS_KILL_BY_M60               "KILL_BY_M60"           /*< Surivivor killed SI by M60 */
#define STATS_KILL_BY_GL                "KILL_BY_GL"            /*< Surivivor killed SI by Grenade Launcher */
#define STATS_KILL_BY_MELEE             "KILL_BY_MELEE"         /*< Surivivor killed SI by Melee */
#define STATS_KILL_BY_PIPE              "KILL_BY_PIPE"          /*< Surivivor killed SI by Pipe */
#define STATS_KILL_BY_MOLOTOV           "KILL_BY_MOLOTOV"       /*< Surivivor killed SI by Molotov */
#define STATS_KILL_BY_NONE              "KILL_BY_NONE"          /*< Surivivor killed SI by none (e.g. Throwables) */

/*
 * Items statistic.
 */
#define STATS_USED_PILLS                "USED_PILLS"            /*< Surivivor used Pills */
#define STATS_USED_ADRENALINE           "USED_ADRENALINE"       /*< Surivivor used Adrenaline */
#define STATS_DEFIBRILLATE              "DEFIBRILLATE"          /*< Surivivor is defibrillated someone */
#define STATS_DEFIBRILLATED             "DEFIBRILLATED"         /*< Surivivor is defibrillated by someone */
#define STATS_HEAL                      "HEAL"                  /*< Surivivor used Medikit for healing someone */
#define STATS_HEALED                    "HEALED"                /*< Surivivor is healed by someone */
#define STATS_SELF_HEALED               "SELF_HEALED"           /*< Surivivor is healed by himself */

/*
 * Other.
 */
#define STATS_DAMAGE_SI_AS_SURVIVOR     "DAMAGE_SI_AS_SURVIVOR"  /*< Amount of damage made SI */
#define STATS_DAMAGE_SI_AS_INFECTED     "DAMAGE_SI_AS_INFECTED"  /*< Amount of damage made SI */
#define STATS_DAMAGE_TANK_AS_SURVIVOR   "DAMAGE_TANK_AS_SURVIVOR"/*< Amount of damage made Tank */
#define STATS_DAMAGE_TANK_AS_INFECTED   "DAMAGE_TANK_AS_INFECTED"/*< Amount of damage made Tank */
#define STATS_TEAMKILL_AS_SURVIVOR      "TEAMKILL_AS_SURVIVOR"   /*< Amount of Team kill */
#define STATS_TEAMKILL_AS_INFECTED      "TEAMKILL_AS_INFECTED"   /*< Amount of Team kill */
#define STATS_DEATH_AS_SURVIVOR         "DEATH_AS_SURVIVOR"      /*< Amount of death of surivivor */
#define STATS_DEATH_AS_INFECTED         "DEATH_AS_INFECTED"      /*< Amount of death of infected */
#define STATS_INCAPACITATED_BY_SURVIVOR "INCAPACITATED_BY_SURVIVOR"/*<   */
#define STATS_INCAPACITATED_BY_INFECTED "INCAPACITATED_BY_INFECTED"/*<   */
#define STATS_INCAPACITATE_AS_SURVIVOR  "INCAPACITATE_AS_SURVIVOR"/*< Amount of Incapacitating Surivivor */
#define STATS_INCAPACITATE_AS_INFECTED  "INCAPACITATE_AS_INFECTED"/*< Amount of Incapacitating Surivivor */
#define STATS_HURT_AS_SURVIVOR          "HURT_AS_SURVIVOR"        /*< Amount of damage hurt */
#define STATS_HURT_AS_INFECTED          "HURT_AS_INFECTED"        /*< Amount of damage hurt */

/*
 * Other.
 */
#define STATS_REVIVE                    "REVIVE"                  /*< Surivivor revived someone */
#define STATS_REVIVED                   "REVIVED"                 /*< Surivivor is revived by someone */
#define STATS_MET_A_TANK                "MET_A_TANK"              /*< Surivivor met a Tank */

static char STATS_LIST[][] = {
	STATS_PLAYED_TIME,

	STATS_KILL_CI,
	STATS_KILL_CI_HS,
	STATS_KILL_WITCH,
	STATS_KILL_WITCH_OS,
	STATS_KILL_SI,
	STATS_KILL_SI_HS,
	STATS_KILL_SMOKER,
	STATS_KILL_BOOMER,
	STATS_KILL_HUNTER,
	STATS_KILL_SPITTER,
	STATS_KILL_JOCKEY,
	STATS_KILL_CHARGER,

	STATS_KILL_BY_SMG,
	STATS_KILL_BY_SILENCED,
	STATS_KILL_BY_MP5,
	STATS_KILL_BY_PUMP,
	STATS_KILL_BY_CHROME,
	STATS_KILL_BY_SCOUT,
	STATS_KILL_BY_M16,
	STATS_KILL_BY_DESERT,
	STATS_KILL_BY_AK47,
	STATS_KILL_BY_SG552,
	STATS_KILL_BY_HUNTING,
	STATS_KILL_BY_MILITARY,
	STATS_KILL_BY_AWP,
	STATS_KILL_BY_AUTO,
	STATS_KILL_BY_SPAS,
	STATS_KILL_BY_MAGNUM,
	STATS_KILL_BY_PISTOL,
	STATS_KILL_BY_M60,
	STATS_KILL_BY_GL,
	STATS_KILL_BY_MELEE,
	STATS_KILL_BY_PIPE,
	STATS_KILL_BY_MOLOTOV,
	STATS_KILL_BY_NONE,

	STATS_USED_PILLS,
	STATS_USED_ADRENALINE,
	STATS_DEFIBRILLATE,
	STATS_DEFIBRILLATED,
	STATS_HEAL,
	STATS_HEALED,
	STATS_SELF_HEALED,

	STATS_DAMAGE_SI_AS_SURVIVOR,
	STATS_DAMAGE_SI_AS_INFECTED,
	STATS_DAMAGE_TANK_AS_SURVIVOR,
	STATS_DAMAGE_TANK_AS_INFECTED,
	STATS_TEAMKILL_AS_SURVIVOR,
	STATS_TEAMKILL_AS_INFECTED,
	STATS_DEATH_AS_SURVIVOR,
	STATS_DEATH_AS_INFECTED,
	STATS_INCAPACITATED_BY_SURVIVOR,
	STATS_INCAPACITATED_BY_INFECTED,
	STATS_INCAPACITATE_AS_SURVIVOR,
	STATS_INCAPACITATE_AS_INFECTED,
	STATS_HURT_AS_SURVIVOR,
	STATS_HURT_AS_INFECTED ,

	STATS_REVIVE,
	STATS_REVIVED,
	STATS_MET_A_TANK
};


enum PlayerState
{
	PlayerState_None,
	PlayerState_Loading,
	PlayerState_Loaded
}

enum struct Player
{
	int id;
	int playedTimeStartAt;
	int rank;
	PlayerState state;
	Handle stats;
}

Player g_tPlayers[MAXPLAYERS + 1];

bool
	g_bLate = false,
	g_bRoundIsLive = false,
	g_bIsFullTeams = false
;

ConVar
	g_cvSurvivorLimit = null, /*< survivor_limit */
	g_cvMaxPlayerZombies = null, /*< z_max_player_zombies */
	g_cvConfigName = null, /*< sm_ps_config */
	g_cvHoursToDeleteOldAccounts = null,
	g_cvHoursToStartRating = null,
	g_cvSurvivorKillCost = null,
	g_cvSurvivorKillCICost = null,
	g_cvSurvivorDeathCost = null,
	g_cvSurvivorIncapacitatedCost = null,
	g_cvSurvivorTeamkillCost = null,
	g_cvInfectedIncapacitateCost = null,
	g_cvInfectedKillCost = null
;

Handle g_hStats = null;
Handle g_hStatByWeapon = null;

Database g_hDatabase = null;

int g_iConfigId = -1;

/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	g_bLate = bLate;

	CreateNative("PlayerStats_GetClientRank", Native_GetClientRank);
	// CreateNative("VersusStats_GetClientRating", Native_GetClientRating);
	CreateNative("PlayerStats_GetClientStat", Native_GetClientStat);
	// CreateNative("VersusStats_GetClientPlayedTime", Native_GetClientPlayedTime);
	// CreateNative("VersusStats_GetClientState", Native_GetClientState);
	CreateNative("PlayerStats_GetHoursToStartRating", Native_GetHoursToStartRating);
	CreateNative("PlayerStats_GetDatabaseHandler", Native_GetDatabaseHandler);

	RegPluginLibrary("player_stats");

	return APLRes_Success;
}

/**
 * Player rank in statistics.
 *
 * @param hPlugin       Handle to the plugin
 * @param iParams       Number of parameters
 * @return              Return rank
 */
int Native_GetClientRank(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);

	if (!IsValidClient(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
	}

	if (!IsClientInGame(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	}

	return g_tPlayers[iClient].rank;
}

/**
 * Get calculated player rating.
 */
// any Native_GetClientRating(Handle plugin, int numParams)
// {
// 	int iClient = GetNativeCell(1);

// 	if (!IsValidClient(iClient)) {
// 		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
// 	}

// 	if (!IsClientInGame(iClient)) {
// 		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
// 	}

// 	return CalculatePlayerRating(iClient);
// }

/**
 * Get the numeric value of a statistics parameter.
 */
int Native_GetClientStat(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);

	if (!IsValidClient(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
	}

	if (!IsClientInGame(iClient)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
	}

	int iStatLength;
	GetNativeStringLength(2, iStatLength);

	char[] sStatName = new char[iStatLength];
	GetNativeString(2, sStatName, iStatLength);

	int iStatId;
	if (!GetTrieValue(g_hStats, sStatName, iStatId)) {
		return -2;
	}

	int iValue = 0;
	return (GetTrieValue(g_tPlayers[iClient].stats, sStatName, iValue) ? iValue : -1);
}

/**
 * Get statistics recording time.
 */
// int Native_GetClientPlayedTime(Handle plugin, int numParams)
// {
// 	int iClient = GetNativeCell(1);

// 	if (!IsValidClient(iClient)) {
// 		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
// 	}

// 	if (!IsClientInGame(iClient)) {
// 		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
// 	}

// 	return g_tPlayers[iClient].playedTime;
// }

/**
 * Getting status about loading statistics.
 */
// int Native_GetClientState(Handle plugin, int numParams)
// {
// 	int iClient = GetNativeCell(1);

// 	if (!IsValidClient(iClient)) {
// 		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
// 	}

// 	if (!IsClientInGame(iClient)) {
// 		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
// 	}

// 	return g_tPlayers[iClient].state;
// }

/**
 * Getting the minimum number of hours to start calculating rank.
 */
any Native_GetHoursToStartRating(Handle plugin, int numParams) {
	return GetConVarFloat(g_cvHoursToStartRating);
}

/**
 * Accessing the database to run queries.
 */
any Native_GetDatabaseHandler(Handle plugin, int numParams) {
	return g_hDatabase;
}

/**
 * Called when the plugin is fully initialized and all known external
 * references are resolved.
 */
public void OnPluginStart()
{
	/*
	 * ConVars.
	 */
	g_cvConfigName = CreateConVar("sm_ps_config", "", "The name of this configuration will be the key for recording statistics. Installs only once");
	g_cvHoursToDeleteOldAccounts = CreateConVar("sm_ps_hours_to_delete_old_accounts", "2160.0", "Number of hours to delete old accounts");
	g_cvHoursToStartRating = CreateConVar("sm_ps_hours_to_start_rating", "12.0", "Number of hours to start rating calculation");

	// g_cvSurvivorKillCost = CreateConVar("vs_s_kill_cost", "1.0"),
	// g_cvSurvivorKillCICost = CreateConVar("vs_s_kill_ci_cost", "0.02"),
	// g_cvSurvivorDeathCost = CreateConVar("vs_s_death_cost", "4.0"),
	// g_cvSurvivorIncapacitatedCost = CreateConVar("vs_s_incapacitated_cost", "2.0"),
	// g_cvSurvivorTeamkillCost = CreateConVar("vs_s_teamkill_cost", "16.0"),
	// g_cvInfectedIncapacitateCost = CreateConVar("vs_i_incapacitate_cost", "2.0"),
	// g_cvInfectedKillCost = CreateConVar("vs_i_kill_cost", "1.0");

	g_cvSurvivorLimit = FindConVar("survivor_limit");
	g_cvMaxPlayerZombies = FindConVar("z_max_player_zombies");

	/*
	 * Preparing to load the config.
	 */
	g_iConfigId = -1;
	HookConVarChange(g_cvConfigName, OnConfigNameChanged);

	/*
	 * Preparing trie for database check.
	 */
	FillStats(g_hStats = CreateTrie());

	/*
	 * Prepare Database.
	 */
	g_hDatabase = ConnectDatabase();

	ValidateDatabase(g_hDatabase);

	ClearDatabase(g_hDatabase);

	/*
	 * Prepare Kill Code for weapons.
	 */
	FillStatByWeapon(g_hStatByWeapon = CreateTrie());

	/*
	 * Events.
	 */
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Post);
	HookEvent("pills_used", Event_PillsUsed, EventHookMode_Post);
	HookEvent("adrenaline_used", Event_AdrenalineUsed, EventHookMode_Post);
	HookEvent("heal_success", Event_HealSuccess, EventHookMode_Post);
	HookEvent("defibrillator_used", Event_DefibrillatorUsed, EventHookMode_Post);
	HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
	HookEvent("infected_death", Event_InfectedDeath, EventHookMode_Post);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);

	if (g_bLate)
	{
		for (int iClient = 1; iClient <= MaxClients; iClient ++)
		{
			if (!IsRealClient(iClient)) {
				continue;
			}

			OnClientPostAdminCheck(iClient);
		}
	}
}

/**
 * Called when a console variable value is changed.
 */
public void OnConfigNameChanged(ConVar convar, const char[] sOldConfigName, const char[] sNewConfigName)
{
	if (sOldConfigName[0] == '\0' && sNewConfigName[0] != '\0')
	{
		char sQuery[96];
		FormatEx(sQuery, sizeof(sQuery), SQL_SELECT_CONFIG_BY_NAME, sNewConfigName);

		SQL_LockDatabase(g_hDatabase);

		Handle hSelect = SQL_Query(g_hDatabase, sQuery);

		SQL_UnlockDatabase(g_hDatabase);

		if (hSelect != INVALID_HANDLE)
		{
			if (SQL_GetRowCount(hSelect) > 0 && SQL_FetchRow(hSelect)) {
				g_iConfigId = SQL_FetchInt(hSelect, 0);
			}

			else
			{
				FormatEx(sQuery, sizeof(sQuery), SQL_INSERT_CONFIG_BY_NAME, sNewConfigName);

				Handle hInsert = SQL_Query(g_hDatabase, sQuery);

				if (hInsert != INVALID_HANDLE)
				{
					g_iConfigId = SQL_GetInsertId(hInsert);

					CloseHandle(hInsert);
				}
			}

			CloseHandle(hSelect);
		}
	}
}

/**
 * Round start event.
 */
void Event_PlayerLeftStartArea(Event event, const char[] sName, bool bDontBroadcast)
{
	g_bRoundIsLive = true;

	// if (g_bIsFullTeams) {
	// 	RunPlayedTime();
	// }
}

/**
 * Round end event.
 */
void Event_RoundEnd(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!g_bRoundIsLive) {
		return;
	}

	g_bRoundIsLive = false;

	// StopPlayedTime();

	// for (int iClient = 1; iClient <= MaxClients; iClient++)
	// {
	// 	if (!IsRealClient(iClient)) {
	// 		continue;
	// 	}

	// 	SaveClientData(iClient);
	// 	UpdateClientRank(iClient);
	// }
}

/**
 * Player change his team.
 */
void Event_PlayerTeam(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (g_iConfigId == -1) {
		return;
	}

	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsRealClient(iClient)) {
		return;
	}

	int iOldTeam = GetEventInt(event, "oldteam");
	int iNewTeam = GetEventInt(event, "team");

	if (iOldTeam == TEAM_NONE && iNewTeam == TEAM_SPECTATOR) {
		return;
	}

	// CreateTimer(0.1, Timer_PlayerTeam, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * Starts a timer for calculating players game statistics.
 */
// Action Timer_PlayerTeam(Handle hTimer)
// {
// 	bool bFullTeamBeforeCheck = g_bIsFullTeams;
// 	g_bIsFullTeams = IsFullTeams();

// 	if (g_bRoundIsLive)
// 	{
// 		if (bFullTeamBeforeCheck == false && g_bIsFullTeams == true) {
// 			RunPlayedTime();
// 		}

// 		else if (bFullTeamBeforeCheck == true && g_bIsFullTeams == false) {
// 			StopPlayedTime();
// 		}
// 	}

// 	return Plugin_Stop;
// }

/**
 * The survivor has become incapacitated.
 */
void Event_PlayerIncapacitated(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (!iVictim || !iAttacker) {
		return;
	}

	if (!IsClientSurvivor(iVictim)) {
		return;
	}

	int iAttackerTeam = GetClientTeam(iAttacker);

	if (iAttackerTeam == TEAM_SURVIVOR)
	{
		AddPlayerStats(iAttacker, STATS_INCAPACITATE_AS_SURVIVOR, 1);
		AddPlayerStats(iVictim, STATS_INCAPACITATED_BY_SURVIVOR, 1);
	}

	else if (iAttackerTeam == TEAM_INFECTED)
	{
		AddPlayerStats(iAttacker, STATS_INCAPACITATE_AS_INFECTED, 1);
		AddPlayerStats(iVictim, STATS_INCAPACITATED_BY_INFECTED, 1);
	}
}

/**
 * Surivivor used Pills.
 */
void Event_PillsUsed(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!iClient) {
		return;
	}

	AddPlayerStats(iClient, STATS_USED_PILLS, 1);
}


/**
 * Surivivor used Adrenaline.
 */
void Event_AdrenalineUsed(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!iClient) {
		return;
	}

	AddPlayerStats(iClient, STATS_USED_ADRENALINE, 1);
}

/**
 * Survivor has been cured.
 */
void Event_HealSuccess(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	int iTarget = GetClientOfUserId(GetEventInt(event, "subject"));

	if (!iClient || !iTarget) {
		return;
	}

	if (iClient != iTarget)
	{
		AddPlayerStats(iClient, STATS_HEAL, 1);
		AddPlayerStats(iTarget, STATS_HEALED, 1);
	}

	else
	{
		AddPlayerStats(iClient, STATS_SELF_HEALED, 1);
	}
}

/**
 * Surivivor used Defibrillator.
 */
void Event_DefibrillatorUsed(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	int iTarget = GetClientOfUserId(GetEventInt(event, "subject"));

	if (!iClient || !iTarget) {
		return;
	}

	AddPlayerStats(iClient, STATS_DEFIBRILLATE, 1);
	AddPlayerStats(iTarget, STATS_DEFIBRILLATED, 1);
}

/**
 * Survivor has been revived.
 */
void Event_ReviveSuccess(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	int iTarget = GetClientOfUserId(GetEventInt(event, "subject"));

	if (!iClient || !iTarget) {
		return;
	}

	AddPlayerStats(iClient, STATS_REVIVE, 1);
	AddPlayerStats(iTarget, STATS_REVIVED, 1);
}

/**
 * Surivivor Killed Common Infected.
 */
void Event_InfectedDeath(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iKiller = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (!iKiller || !IsClientSurvivor(iKiller)) {
		return;
	}

	AddPlayerStats(iKiller, STATS_KILL_CI, 1);

	if (GetEventBool(event, "headshot")) {
		AddPlayerStats(iKiller, STATS_KILL_CI_HS, 1);
	}
}

/**
 * Surivivor Killed Witch.
 */
void Event_WitchKilled(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iKiller = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!iKiller || !IsClientSurvivor(iKiller)) {
		return;
	}

	AddPlayerStats(iKiller, STATS_KILL_WITCH, 1);

	if (GetEventBool(event, "oneshot")) {
		AddPlayerStats(iKiller, STATS_KILL_WITCH_OS, 1);
	}
}

/**
 * TODO: REWORK
 * Surivivor met Tank.
 */
void Event_TankSpawn(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iTank = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!iTank || IsFakeClient(iTank)) {
		return;
	}

	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (!IsRealClient(iClient) || !IsClientSurvivor(iClient) || !IsPlayerAlive(iClient)) {
			continue;
		}

		AddPlayerStats(iClient, STATS_MET_A_TANK, 1);
	}
}

/**
 * Registers murder/death. Support all playable classes (Hunter, Smoker, Boomer, Tank, Survivors).
 */
void Event_PlayerDeath(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int iKiller = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (!iVictim || !iKiller) {
		return;
	}

	int iKillerTeam = GetClientTeam(iKiller);
	int iVictimTeam = GetClientTeam(iVictim);

	if (iKillerTeam == TEAM_SURVIVOR && iVictimTeam == TEAM_INFECTED)
	{
		AddPlayerStats(iVictim, STATS_DEATH_AS_INFECTED, 1);

		char sStatName[32];

		char sWeaponName[32]; GetEventString(event, "weapon", sWeaponName, sizeof(sWeaponName));

		if (GetTrieString(g_hStatByWeapon, sWeaponName, sStatName, sizeof(sStatName))) {
			AddPlayerStats(iKiller, sStatName, 1);
		} else {
			AddPlayerStats(iKiller, STATS_KILL_BY_NONE, 1);
		}

		switch (GetClientClass(iVictim))
		{
			case SI_CLASS_SMOKER: AddPlayerStats(iKiller, STATS_KILL_SMOKER, 1);
			case SI_CLASS_BOOMER: AddPlayerStats(iKiller, STATS_KILL_BOOMER, 1);
			case SI_CLASS_HUNTER: AddPlayerStats(iKiller, STATS_KILL_HUNTER, 1);
			case SI_CLASS_SPITTER: AddPlayerStats(iKiller, STATS_KILL_SPITTER, 1);
			case SI_CLASS_JOCKEY: AddPlayerStats(iKiller, STATS_KILL_JOCKEY, 1);
			case SI_CLASS_CHARGER: AddPlayerStats(iKiller, STATS_KILL_CHARGER, 1);
		}

		AddPlayerStats(iKiller, STATS_KILL_SI, 1);

		if (GetEventBool(event, "headshot")) {
			AddPlayerStats(iKiller, STATS_KILL_SI_HS, 1);
		}
	}

	else if (iKillerTeam == TEAM_INFECTED && iVictimTeam == TEAM_SURVIVOR) {
		AddPlayerStats(iVictim, STATS_DEATH_AS_SURVIVOR, 1);
	}

	else if (iKillerTeam == TEAM_SURVIVOR && iVictimTeam == TEAM_SURVIVOR)
	{
		AddPlayerStats(iKiller, STATS_TEAMKILL_AS_SURVIVOR, 1);
		AddPlayerStats(iVictim, STATS_DEATH_AS_SURVIVOR, 1);
	}

	else if (iKillerTeam == TEAM_INFECTED && iVictimTeam == TEAM_INFECTED)
	{
		AddPlayerStats(iKiller, STATS_TEAMKILL_AS_INFECTED, 1);
		AddPlayerStats(iVictim, STATS_DEATH_AS_INFECTED, 1);
	}
}

/**
 * Registers existing/caused damage.
 */
void Event_PlayerHurt(Event event, char[] sEventName, bool bDontBroadcast)
{
	if (!CanRecordStats()) {
		return;
	}

	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (!iVictim || !iAttacker) {
		return;
	}

	int iDamage = GetEventInt(event, "dmg_health");

	// if (IsClientSurvivor(iVictim) && IsClientInfected(iAttacker))
	// {
	// 	AddPlayerStats(iAttacker, I_DMG, iDamage);
	// 	AddPlayerStats(iVictim, S_HURT, iDamage);
	// }

	// else if (IsClientSurvivor(iAttacker) && IsClientInfected(iVictim))
	// {
	// 	if (IsClientTank(iVictim)) {
	// 		AddPlayerStats(iAttacker, S_DMG_TANK, !IsTankIncapacitated(iVictim) ? iDamage : 0);
	// 	} else {
	// 		AddPlayerStats(iAttacker, S_DMG, iDamage);
	// 	}

	// 	AddPlayerStats(iVictim, I_HURT, iDamage);
	// }
}

/**
 * Establishing a database connection.
 */
Database ConnectDatabase()
{
	char sError[512];
	Database db = null;

	if (SQL_CheckConfig(DATABASE_CONFIG)) {
		db = SQL_Connect(DATABASE_CONFIG, true, sError, sizeof(sError));
	} else {
		SetFailState("Configuration " ... DATABASE_CONFIG ... " not found in databases.cfg.");
	}

	if (db == null) {
		SetFailState("Could not connect to database: %s.", sError);
	}

	return db;
}

void ValidateDatabase(Database db)
{
	if (!AvailableDatabaseDriver(db)) {
		SetFailState("Unsupported database driver.");
	}

	if (CreateDatabaseTables(db) == false) {
		SetFailState("Create tables failure.");
	}

	if (CheckDatabaseStatsTable(db) == false) {
		SetFailState("Check `ps_stats` rows failure.");
	}
}

/**
 * Checking the database driver.
 */
bool AvailableDatabaseDriver(Database db)
{
	char ident[16]; db.Driver.GetIdentifier(ident, sizeof(ident));

	if (StrEqual(ident, "mysql", false)) {
		return true;
	}

	return false;
}

/**
 * Creating a table of players.
 */
bool CreateDatabaseTables(Database db)
{
	char SQL_CREATE_TABLES[][] = {
		SQL_CREATE_TABLE_PLAYERS,
		SQL_CREATE_TABLE_CONFIGS,
		SQL_CREATE_TABLE_STATS,
		SQL_CREATE_TABLE_PLAYER_STATS,
		SQL_CREATE_TABLE_PLAYER_RATING
	};

	SQL_LockDatabase(db);

	for (int iTable = 0; iTable < sizeof(SQL_CREATE_TABLES); iTable ++)
	{
		if (SQL_FastQuery(db, SQL_CREATE_TABLES[iTable])) {
			continue;
		}

		char sError[255];
		SQL_GetError(db, sError, sizeof(sError));
		LogError("Failed to query: %s", sError);

		SQL_UnlockDatabase(db);
		return false;
	}

	SQL_UnlockDatabase(db);

	return true;
}

bool CheckDatabaseStatsTable(Database db)
{
	SQL_LockDatabase(db);

	Handle hSelect = SQL_Query(db, SQL_SELECT_STATS);

	SQL_UnlockDatabase(db);

	if (hSelect == INVALID_HANDLE) {
		return false;
	}

	int iStatId;
	char sStatName[32];

	if (SQL_GetRowCount(hSelect) > 0)
	{
		while(SQL_FetchRow(hSelect))
		{
			iStatId = SQL_FetchInt(hSelect, 0);
			SQL_FetchString(hSelect, 1, sStatName, sizeof(sStatName));

			SetTrieValue(g_hStats, sStatName, iStatId);
		}
	}

	CloseHandle(hSelect);

	/*
	 *
	 */
	char sQuery[96];

	Handle hSnapshot = CreateTrieSnapshot(g_hStats);

	int iSize = TrieSnapshotLength(hSnapshot);

	for (int iIndex = 0; iIndex < iSize; iIndex ++)
	{
		GetTrieSnapshotKey(hSnapshot, iIndex, sStatName, sizeof(sStatName));
		GetTrieValue(g_hStats, sStatName, iStatId);

		if (iStatId != -1) {
			continue;
		}

		FormatEx(sQuery, sizeof(sQuery), SQL_INSERT_STAT_BY_NAME, sStatName);

		SQL_LockDatabase(db);

		Handle hInsert = SQL_Query(db, sQuery);

		SQL_UnlockDatabase(db);

		if (hInsert != INVALID_HANDLE)
		{
			iStatId = SQL_GetInsertId(hInsert);

			SetTrieValue(g_hStats, sStatName, iStatId);

			CloseHandle(hInsert);
		}
	}

	CloseHandle(hSnapshot);

	return true;
}

/**
 * Removing inactive players from the table.
 */
void ClearDatabase(Database db)
{
	int iMaxLastVisit = GetTime() - RoundFloat(3600.0 * GetConVarFloat(g_cvHoursToDeleteOldAccounts));

	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), SQL_CLEAR_PLAYER, iMaxLastVisit);

	SQL_LockDatabase(db);

	if (!SQL_FastQuery(db, sQuery))
	{
		char sError[255];
		SQL_GetError(db, sError, sizeof(sError));
		LogError("Failed to query: %s", sError);
	}

	SQL_UnlockDatabase(db);
}

void FillStats(Handle hStats)
{
	for (int iStat = 0; iStat < sizeof(STATS_LIST); iStat ++)
	{
		SetTrieValue(hStats, STATS_LIST[iStat], -1);
	}
}

/**
 * Initializing a weapon map whose key is the name of the weapon and whose
 * value is weapon_id.
 */
void FillStatByWeapon(Handle hStatByWeapon)
{
	char STATS_BY_WEAPON[][] = {
		"pistol",           STATS_KILL_BY_PISTOL,
		"smg",              STATS_KILL_BY_SMG,
		"pumpshotgun",      STATS_KILL_BY_PUMP,
		"autoshotgun",      STATS_KILL_BY_AUTO,
		"rifle",            STATS_KILL_BY_M16,
		"hunting_rifle",    STATS_KILL_BY_HUNTING,
		"smg_silenced",     STATS_KILL_BY_SILENCED,
		"shotgun_chrome",   STATS_KILL_BY_CHROME,
		"rifle_desert",     STATS_KILL_BY_DESERT,
		"sniper_military",  STATS_KILL_BY_MILITARY,
		"shotgun_spas",     STATS_KILL_BY_SPAS,
		"molotov",          STATS_KILL_BY_MOLOTOV,
		"pipe_bomb",        STATS_KILL_BY_PIPE,
		"melee",            STATS_KILL_BY_MELEE,
		"grenade_launcher", STATS_KILL_BY_GL,
		"rifle_ak47",       STATS_KILL_BY_AK47,
		"pistol_magnum",    STATS_KILL_BY_MAGNUM,
		"smg_mp5",          STATS_KILL_BY_MP5,
		"rifle_sg552",      STATS_KILL_BY_SG552,
		"sniper_awp",       STATS_KILL_BY_AWP,
		"sniper_scout",     STATS_KILL_BY_SCOUT,
		"rifle_m60",        STATS_KILL_BY_M60
	};

	for (int iStat = 0; iStat < sizeof(STATS_BY_WEAPON); iStat += 2)
	{
		SetTrieString(hStatByWeapon, STATS_BY_WEAPON[iStat], STATS_BY_WEAPON[iStat + 1]);
	}
}

/**
 * Loading Player Statistics.
 * Called once a client is authorized and fully in-game, and after all post-connection authorizations have been performed.
*/
public void OnClientPostAdminCheck(int iClient)
{
	if (!IsRealClient(iClient)) {
		return;
	}

	LoadClientData(iClient);
}

/**
 * Saving player statistics.
 * Called before client disconnected.
 */
public void OnClientDisconnect(int iClient)
{
	if (!IsRealClient(iClient)) {
		return;
	}

	BreakPlayedTime(iClient, GetTime());
	SaveClientData(iClient);
}

void BreakPlayedTime(int iClient, int iBreakTime)
{
	int iTimeStartAt = g_tPlayers[iClient].playedTimeStartAt;

	if (iTimeStartAt > 0)
	{
		AddPlayerStats(iClient, STATS_PLAYED_TIME, iBreakTime - iTimeStartAt);
		g_tPlayers[iClient].playedTimeStartAt = 0;
	}
}

void RunPlayedTime()
{
	int iTime = GetTime();

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsRealClient(iClient) || IsClientSpectator(iClient)) {
			continue;
		}

		g_tPlayers[iClient].playedTimeStartAt = iTime;
	}
}

void StopPlayedTime()
{
	int iTime = GetTime();

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsRealClient(iClient)) {
			continue;
		}

		BreakPlayedTime(iClient, iTime);
	}
}

bool CanRecordStats() {
	return true; //g_bRoundIsLive && g_bIsFullTeams;
}

/**
 * Loading all player statistics.
 */
void LoadClientData(int iClient)
{
	/*
	 * Reset all player statistics.
	 */
	g_tPlayers[iClient].id = 0;
	g_tPlayers[iClient].rank = 0;
	g_tPlayers[iClient].playedTimeStartAt = 0;
	g_tPlayers[iClient].state = PlayerState_None;
	g_tPlayers[iClient].stats = CreateTrie();

	char sSteamId[MAX_AUTHID_LENGTH]; GetClientAuthId(iClient, AuthId_SteamID64, sSteamId, sizeof(sSteamId));

	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), SQL_SELECT_PLAYER_BY_STEAMID, sSteamId);

	SQL_TQuery(g_hDatabase, Thread_GetPlayerId, sQuery, iClient);
}

void Thread_GetPlayerId(Handle owner, Handle hndl, const char[] sError, int iClient)
{
	if (hndl == null)
	{
		LogError("Thread_GetPlayerId failed! Reason: %s", sError);
		return;
	}

	if (SQL_GetRowCount(hndl) > 0 && SQL_FetchRow(hndl))
	{
		g_tPlayers[iClient].id = SQL_FetchInt(hndl, 0);
		g_tPlayers[iClient].state = PlayerState_Loading;
	}

	LogMessage("Thread_GetPlayerId %d", g_tPlayers[iClient].id);
}

/**
 * Save or update all player statistics.
 */
void SaveClientData(int iClient)
{
	// if (g_tPlayers[iClient].state != STATE_LOADED || g_tPlayers[iClient].playedTime == 0) {
	// 	return;
	// }

	char sName[MAX_NAME_LENGTH];
	GetClientName(iClient, sName, sizeof(sName));

	char sQuery[192];

	if (IsNewPlayer(iClient))
	{
		char sSteamId[MAX_AUTHID_LENGTH];
		GetClientAuthId(iClient, AuthId_SteamID64, sSteamId, sizeof(sSteamId));

		FormatEx(sQuery, sizeof(sQuery), SQL_INSERT_PLAYER, sSteamId, sName, GetTime());
		SQL_TQuery(g_hDatabase, Thread_InsertPlayer, sQuery, iClient);
	}

	else
	{
		FormatEx(sQuery, sizeof(sQuery), SQL_UPDATE_PLAYER, sName, GetTime(), g_tPlayers[iClient].id);
		SQL_TQuery(g_hDatabase, Thread_UpdatePlayer, sQuery, iClient);
	}
}

void Thread_InsertPlayer(Handle owner, Handle hndl, const char[] sError, int iClient)
{
	if (hndl == null)
	{
		LogError("Thread_InsertPlayer failed! Reason: %s", sError);
		return;
	}

	g_tPlayers[iClient].id = SQL_GetInsertId(hndl);

	InsertPlayerStats(iClient, g_tPlayers[iClient].stats);
}

void InsertPlayerStats(int iClient, Handle hPlayerStats)
{
	Handle hSnapshot = CreateTrieSnapshot(hPlayerStats);

	int iSize = TrieSnapshotLength(hSnapshot);

	if (!iSize) {
		return;
	}

	char sStat[32 * 4  + 4];
	int iStatsLength = GetTrieSize(hPlayerStats) * sizeof(sStat);
	char[] sStats = new char[iStatsLength];

	char sStatName[32];
	int iStatId, iStatValue;

	for (int iIndex = 0; iIndex < iSize; iIndex ++)
	{
		GetTrieSnapshotKey(hSnapshot, iIndex, sStatName, sizeof(sStatName));

		if (!GetTrieValue(g_hStats, sStatName, iStatId)
		|| iStatId == -1
		|| !GetTrieValue(g_tPlayers[iClient].stats, sStatName, iStatValue)) {
			continue;
		}

		if (sStats[0] != '\0') {
			StrCat(sStats, iStatsLength, ",");
		}

		FormatEx(sStat, sizeof(sStat), "(%d,%d,%d,%d)", g_iConfigId, g_tPlayers[iClient].id, iStatId, iStatValue);
		StrCat(sStats, iStatsLength, sStat);
	}

	CloseHandle(hSnapshot);

	int iQueryLength = 128 + iStatsLength;
	char[] sQuery = new char[iQueryLength];
	strcopy(sQuery, iQueryLength, SQL_INSERT_PLAYER_STATS_MULTIPLY);
	ReplaceString(sQuery, iQueryLength, "__ROWS__", sStats, false);

	LogMessage("InsertPlayerStats %s", sQuery);

	SQL_TQuery(g_hDatabase, Thread_InsertPlayerStats, sQuery, iClient);
}

void Thread_InsertPlayerStats(Handle owner, Handle hndl, const char[] sError, int iClient)
{
	if (hndl == null)
	{
		LogError("Thread_InsertPlayerStats failed! Reason: %s", sError);
		return;
	}

	LogMessage("Thread_InsertPlayerStats %d", g_tPlayers[iClient].id);
}

void Thread_UpdatePlayer(Handle owner, Handle hndl, const char[] sError, int iClient)
{
	if (hndl == null)
	{
		LogError("Thread_UpdatePlayer failed! Reason: %s", sError);
		return;
	}

	LogMessage("Thread_UpdatePlayer %d", g_tPlayers[iClient].id);

	UpdatePlayerStats(iClient, g_tPlayers[iClient].stats);
}

void UpdatePlayerStats(int iClient, Handle hPlayerStats)
{

}

/**
 * Update a player's rating, given that other players have played with this player.
 */
void UpdateClientRank(int iClient)
{
	// if (g_tPlayers[iClient].state != STATE_LOADED || IsNewPlayer(iClient) || g_tPlayers[iClient].playedTime < MIN_RANKED_SEC) {
	// 	return;
	// }

	// char sQuery[192];
	// FormatEx(sQuery, sizeof(sQuery), "SELECT (SELECT count(1) FROM vs_players b WHERE b.`rating`>a.`rating`)+1 as rank FROM vs_players a WHERE `id`=%d LIMIT 1;", g_tPlayers[iClient].id);

	// SQL_TQuery(g_hDatabase, UpdateClientRankThread, sQuery, iClient);
}

// void Thread_UpdateClientRank(Handle owner, Handle hndl, const char[] error, int iClient)
// {
// 	if (hndl == null)
// 	{
// 		LogError("UpdateClientRankThread failed! Reason: %s", error);
// 		return;
// 	}

// 	if (SQL_GetRowCount(hndl) > 0 && SQL_FetchRow(hndl)) {
// 		g_tPlayers[iClient].rank = SQL_FetchInt(hndl, 0);
// 	}
// }

/**
 * Player Pts Calculation.
 */
float CalculatePlayerRating(int iClient)
{
	// if (g_tPlayers[iClient].playedTime < MIN_RANKED_SEC) {
	// 	return 0.0;
	// }

	// float fPositive = float(g_tPlayers[iClient].stats[S_K_CI]) * COST_S_KILL_CI
	// 				+ float(g_tPlayers[iClient].stats[S_KILL]) * COST_S_KILL
	// 				+ float(g_tPlayers[iClient].stats[I_INCAPACITATE]) * COST_I_INCAPACITATE
	// 				+ float(g_tPlayers[iClient].stats[I_KILL]) * COST_I_KILL;

	// float fNegative = float(g_tPlayers[iClient].stats[S_DEATH]) * COST_S_DEATH
	// 				+ float(g_tPlayers[iClient].stats[S_INCAPACITATED]) * COST_S_INCAPACITATED
	// 				+ float(g_tPlayers[iClient].stats[S_TEAMKILL]) * COST_S_TEAMKILL;

	// float fRating = (fPositive - fNegative) / (g_tPlayers[iClient].playedTime);

	// return fRating > 0.0 ? fRating : 0.0;
	return 0.0;
}

void AddPlayerStats(int iClient, const char[] sStats, int iValue)
{
	// TODO: REMOVE IT
	if (!IsRealClient(iClient)) {
		return;
	}

	int iOldValue = 0;

	if (GetTrieValue(g_tPlayers[iClient].stats, sStats, iOldValue)) {
		SetTrieValue(g_tPlayers[iClient].stats, sStats, iOldValue + iValue);
	} else {
		SetTrieValue(g_tPlayers[iClient].stats, sStats, iValue);
	}

	LogMessage("%s %d", sStats, iValue);
}

bool IsNewPlayer(int iClient) {
	return g_tPlayers[iClient].id == 0;
}

bool IsFullTeams() {
	return true;
	//return (GetPlayerCount() == (GetConVarInt(g_cvSurvivorLimit) + GetConVarInt(g_cvMaxPlayerZombies)));
}

/*
 * Returns the number of players on the survivors and infected teams.
 */
int GetPlayerCount()
{
	int iCount = 0;

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsRealClient(iClient) || IsClientSpectator(iClient)) {
			continue;
		}

		iCount ++;
	}

	return iCount;
}

/**
 *
 */
bool IsValidClient(int iClient) {
	return (iClient > 0 && iClient <= MaxClients);
}

/**
 * Returns whether the player is survivor.
 */
bool IsClientSurvivor(int iClient) {
	return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}

/**
 * Returns whether the player is infected.
 */
bool IsClientInfected(int iClient) {
	return (GetClientTeam(iClient) == TEAM_INFECTED);
}

/**
 * Returns whether the player is spectator.
 */
bool IsClientSpectator(int iClient) {
	return (GetClientTeam(iClient) == TEAM_SPECTATOR);
}

/**
 *
 */
bool IsRealClient(int iClient) {
	return (IsClientInGame(iClient) && !IsFakeClient(iClient));
}

/**
 * Gets the client L4D1/L4D2 zombie class id.
 *
 * @param iClient    Client index.
 * @return L4D1      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=WITCH, 5=TANK, 6=NOT INFECTED
 * @return L4D2      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=SPITTER, 5=JOCKEY, 6=CHARGER, 7=WITCH, 8=TANK, 9=NOT INFECTED
 */
int GetClientClass(int iClient) {
	return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}

/**
 *
 */
bool IsClientTank(int iClient) {
	return (GetClientClass(iClient) == SI_CLASS_TANK);
}

/**
 *
 */
bool IsClientIncapacitated(int iClient) {
	return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

/**
 *
 */
bool IsTankIncapacitated(int iClient) {
	return (IsClientIncapacitated(iClient) || GetClientHealth(iClient) < 1);
}
