# TOGs Deathmatch Team Balancer
(togdmteambalance)

Note: This is an old plugin of mine. I'm just moving it to Github.

After trying several team balancers, I found I was not happy with any of them. So, I decided to make my own.

This is a very simple balancer. Instead of checking teams every time a player dies, it checks them on configurable intervals. If the teams are unbalanced by a configurable amount, the plugin will move the next player that dies and is not immune and that is not in cooldown (unless cooldown is disabled).

Unlike the other plugins I tested, this one does not kill the player when moving them, so their score is unchanged (or level if it is a gungame server, etc.).

Players can be made immune to team balance if they have the flag defined by the cvar tdmtb_immuneflag.

For server owners who wish to make the time between checks far apart, I've also implemented an admin command to run the check.




## Installation:
Put togdmteambalance.smx in the following folder: /addons/sourcemod/plugins/


## CVars:
* **tdmtb_enable** - Enable plugin (0 = Disabled, 1 = Enabled).
* **tdmtb_immuneflag** - Flag to check for when balancing. Players with this flag or "teambalance_immunity" override will not be moved.
* **tdmtb_checktime** - Repeating time interval to check for unbalanced teams.
* **tdmtb_difference** - How many more players a team must have to be considered unbalanced.
* **tdmtb_cooldown_playercount** - How many players must be playing (on a team) before players cannot be moved until after a cooldown time.
* **tdmtb_cooldown_time** - Time after a player is moved during which they cannot be moved again (set to 0 to disable cooldown).

Note: After changing the cvars in your cfg file, be sure to RCon the new values to the server so that they take effect immediately.


## Admin Commands:
* sm_chkbal - Checks if teams are balanced. If unbalanced, sets plugin to balance next player that dies (unless immune or in cooldown, if applicable)
* sm_chkimm - Checks which players in the server are immune to Team Balance. Prints output to clients console.



## Changelog:
<details>
<summary>Click to Open Spoiler</summary>
<p>
1/14/18 (v2.0.1)
* Apparently view_as can be buggy for floats. Changed to just manually make it a absolute value for the difference.

1/14/18 (v2.0.1-debug)
* Created debug version to test for issues recently reported.

11/11/16 (v2.0)
* Changed to new syntax and updated code for entire plugin. Changes untested.

05/19/15 (v1.3) [Forgot to release on AM]
* Removed OnPluginEnd (it was pointless). No need to close handles to the timer in OnPluginEnd, since they are released when the plugin is unloaded anyways.
* Added a few more notifications to the player being moved.

05/30/14 (v1.2)
* Fixed problem i noticed in the code that the check immunity function could take off a players immunity.
* Fixed error that could have occured if check immunity or check balance functions were called via rcon (print to chat would cause an error, since client isnt in game).
* Added check to see if plugin is enabled before checks on player death.
* Added cooldown time (configurable via cvar) for players who are switched, as well as a minimum number of players (configurable via cvar) needed for the cooldowns to activate (and ability to disable cooldown time all together).

03/25/14 (v1.1)
* Fixed Immunity System.
* Added admin command to check which players in the server are immune.

03/25/14 (v1.0)
* Initial release.
</p>
</details>






### Check out my plugin list: http://www.togcoding.com/togcoding/index.php
