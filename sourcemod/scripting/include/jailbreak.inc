#if defined _jailbreak_included_
  #endinput
#endif
#define _jailbreak_included_

//Called when Freeday For All starts
forward JB_OnFreeday()

//Called when a Special Day starts
forward JB_OnSpecialDay()

//Called when Last Request starts
forward JB_OnLastRequest()

//Called when Simon die
forward JB_OnSimonDeath(client)

//Called when Simon gets removed with JB_RemoveSimon()
forward JB_OnSimonRemove(client)

//Returns the current Simon, if return = 0 then there is no Simon
native JB_GetSimon()

//Returns if there is an ongoing Freeday For All
native bool:JB_IsFreeday()

//Removes current Simon
native JB_RemoveSimon()

//Removes client Glow
native JB_RemoveGlow(client)

//Sets XM1337 to client
native JB_SetXM1337(client)

//Returns Special Day type
native JB_GetDayType()

//Returns Special Day mode
native JB_GetSpecialDay()

//Returns if there is an ongoing Special Day
native bool:JB_IsSpecialDay()

//Returns if there is an ongoing Last Request
native bool:JB_IsLastRequest()

//Sets Blast-Fire Protection to client
native JB_SetBFProtection(client)

//Sets Regeneration to client
native JB_SetRegeneration(client)

//Sets Panic Mode to client
native JB_SetPanicMode(client)

//Sets LongJump to client
native JB_SetLongJump(client)

//Sets MultiJump to client
native JB_SetMultiJump(client, jumps)

//Returns client dollars
native JB_GetClientDollars(client)

//Sets dollars to client
native JB_SetClientDollars(client, amount)

//Sets Glow to client
native JB_SetGlow(client, red, green, blue, alpha, style)