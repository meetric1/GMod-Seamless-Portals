# GMod-Seamless-Portals
[![](https://img.youtube.com/vi/lgiPHZdTGxs/0.jpg)](http://www.youtube.com/watch?v=lgiPHZdTGxs "")

### Description
My seamless portals addon for garrys mod. This is a mod that adds a entity called the Seamless Portal, and a functioning portal gun!
You can spawn the Portals in the spawnmenu, or by using the portal gun in the weapons tab.

### Installation
To install this addon, download and unzip the contents and put it in your garrys mod addon folder

### Features
 * More seamless
 * Working wall & floor portals
 * Prediction for multiplayer & players with high ping
 * Floor extrusion if your player gets stuck in the ground
 * Sounds travel through
 * Black skybox fix
 * Optimized traceline implementation
 * Includes non janky portal gun
 * Includes some tools to play with
 * Option for scalable portals to resize the player (using my player resizer)

**BEST RESULTS ARE IN A LOCAL SERVER BECAUSE I CANT DO PREDICTION IN SINGLEPLAYER!**

### Useful links
 * [Workshop addon on the steam community.][ref-ws]
 * [Discord server for discussing my addons.][ref-dsc]

### Developer API
|Setters **(SERVER ONLY)**|Description|
|:---|:---|
|`ents.Create("seamless_portal")`|Spawns a portal|
|`portal:LinkPortal(portal2)`|Links 2 portals together|
|`portal:SetExitSize(vector)`|Sets the size of the portal|
|`portal:SetDisableBackface(bool)`|Disables/Enables the back material on the portal|

|Getters **(SERVER & CLIENT)**|Description|
|:---|:---|
|`portal:GetPortalSize()`|Self explanatory, default is `Vector(1,1,1)`|
|`portal:GetExitPortal()`|Gets the portal's exit, `nil` or `NULL` entity if there is none|
|`portal:GetDisableBackface()`|Self explanatory, default is `false`|

### Creadits
 * Fafy2801 for finding a fix for the black skybox
 * PeteBroccoli for improving the networking system
 * WasabiThumb for fixing a black halo glitch & adding traceline functionality
 * WasabiThumb for also making a 'portal creator & linker' tool
 * [dvdvideo1234][ref-dvd] for making accurate portal gun surface angles & some optimizations

[ref-ws]: https://steamcommunity.com/sharedfiles/filedetails/?id=2773737445
[ref-dsc]: https://discord.gg/vdsgHsFrx2
[ref-dvd]: https://steamcommunity.com/id/dvd_video
