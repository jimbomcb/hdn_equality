/*  

Hidden Equality
---------------

A super hacky method to add a new Hidden selection method, 
this selection method ensures everyone gets a chance to 
play the Hidden X amount of times and changes map
once everyone has had their turn.

Someone PLEASE show me a way to specificly pick someone
as Hidden rather than restarting the round until they get chosen.

*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>

#define HDN_TEAM_IRIS 2
#define HDN_TEAM_HIDDEN 3

#define RESTART_ROUND_DELAY 0.25
#define NEXTMAP_CHANGE_DELAY 5.0

#define CHAT_PREFIX  "Hidden Equality:"
#define AUTHSTR_LEN 64

new Handle:g_UserArray;
new Handle:g_cvarTotalCycles;
new g_iTotalCycles;

public Plugin:myinfo = 
{
  name = "Hidden Equality",
	author = "jimbomcb",
	description = "Ensures every player gets a chance to play the Hidden.",
	version = "1",
	url = "http://jimbomcb.net"
};

public OnPluginStart()
{
	HookEvent("player_team", Event_PlayerTeam);
	
	g_cvarTotalCycles = CreateConVar("hdn_equality_cycles","2","How many cycles should we run before changing to the next map?",FCVAR_PLUGIN|FCVAR_NOTIFY);
	
	new iStrBlockSize = ByteCountToCells(AUTHSTR_LEN);  
	g_UserArray = CreateArray( iStrBlockSize );
	
	PrintToServer("%s Plugin loaded.", CHAT_PREFIX );
}

public OnMapStart() 
{
	g_iTotalCycles = 0;
	ClearArray( g_UserArray );
	
	ServerCommand("hdn_selectmethod 2"); // Todo, improve or check this is set... Gross.
}

public Event_PlayerTeam(Handle:event, const String:szEventName[], bool:dontBroadcast)
{
	new iUserID = GetEventInt(event, "userid");
	new iClient = GetClientOfUserId(iUserID);
	new iNewTeam = GetEventInt(event, "team");
 
	decl String:szName[64];
	GetClientName(iClient, szName, sizeof(szName));
 
	// Check when we have our new Hidden.
	if ( iNewTeam == HDN_TEAM_HIDDEN ) 
	{	
		// Get our SteamID.
		decl String:szAuthString[AUTHSTR_LEN];
		if ( !GetClientAuthString( iClient, szAuthString, AUTHSTR_LEN ) ) return;
			
		new bool:bUserWasHidden = FindStringInArray( g_UserArray, szAuthString ) != -1;
		new iValidRemaining = RemainingPossibleHidden();
		
		// If they aren't in our history, allow.
		if ( !bUserWasHidden )
		{
			PrintToChatAll("%s %s has not been the Hidden this cycle, GLHF! (%i eligible player(s) remaining)",CHAT_PREFIX,szName, iValidRemaining-1);	
			PushArrayString( g_UserArray, szAuthString );
			return;
		}
		
		// If we have no remaining eligible players, we have reached the end of our cycle. Either restart cycle or change to next map.
		if ( iValidRemaining == 0 )
		{
			new iCycleLimit = GetConVarInt( g_cvarTotalCycles );
			g_iTotalCycles++;
			
			if ( g_iTotalCycles >= iCycleLimit )
			{
				PrintToChatAll("%s Everyone has had a chance to be the Hidden and we have completed %i cycles, changing to next map!", CHAT_PREFIX, g_iTotalCycles );			
				CreateTimer(NEXTMAP_CHANGE_DELAY, Timer_ChangeToNextMap);
			}
			else
			{
				PrintToChatAll("%s Everyone has had a chance to be the Hidden, restarting the cycle! (%i cycles remaining)", CHAT_PREFIX, iCycleLimit - g_iTotalCycles );
				ClearArray( g_UserArray );
				PushArrayString( g_UserArray, szAuthString );
			}
			
			return;
		}
		
		// They are in our history and we have players waiting to be Hidden, restart until we get valid player.
		PrintToChatAll("%s %s has already been the Hidden this cycle, attempting to find valid player. (%i eligible player(s) remaining)",CHAT_PREFIX,szName,iValidRemaining);	
		CreateTimer(RESTART_ROUND_DELAY, Timer_RestartRound);
	}
}

RemainingPossibleHidden( )
{
	new iRemaining = 0;
	
	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		if ( GetClientTeam(i) != HDN_TEAM_IRIS && GetClientTeam(i) != HDN_TEAM_HIDDEN )
			continue;
			
		if ( GetEntProp(i, Prop_Send, "m_bNoHidden", 1) == 1 ) // The user doesn't want to be hidden (?!)
			continue;
			
		decl String:szAuthString[AUTHSTR_LEN];
		if ( !GetClientAuthString( i, szAuthString, AUTHSTR_LEN ) ) continue;
			
		if ( FindStringInArray( g_UserArray, szAuthString ) != -1 )
			continue;
			
		iRemaining++;
	}
	
	return iRemaining;
}

public Action:Timer_RestartRound(Handle:timer)
{
	ServerCommand("hdn_restartround");	
}

public Action:Timer_ChangeToNextMap(Handle:timer)
{
	new String:sNextMap[64];
	if ( !GetNextMap(sNextMap, 64) ) return;

	ForceChangeLevel(sNextMap, "Completed required cycles.");
}
