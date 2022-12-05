# GMod-Seamless-Portals [![made with - mee++](https://img.shields.io/badge/made_with-mee%2B%2B-2ea44f)](https://)  
[![](https://img.youtube.com/vi/lgiPHZdTGxs/0.jpg)](http://www.youtube.com/watch?v=lgiPHZdTGxs "")

### Description
My seamless portals addon for Garry’s mod. This is a mod that adds an entity called the Seamless Portal, and a functioning portal gun!
You can spawn the Portals in the spawn menu, or by using the portal gun in the weapons tab.

### Installation
To install this addon, download and unzip the contents and put it in your Garry’s mod addon folder

### Features
 * More seamless
 * Working wall & floor portals
 * Prediction for multiplayer & players with high ping
 * Floor extrusion if your player gets stuck in the ground
 * Sounds travel through
 * Black skybox fix
 * Optimized [`util.TraceLine`][ref-trln] implementation
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
|`ents.Create("seamless_portal")`|Creates a portal entity|
|`portal:LinkPortal(portal2)`|Links 2 portals together|
|`portal:SetSize(vector)`|Sets the size of the portal in source units|
|`portal:SetDisableBackface(bool)`|Disables/Enables the back material on the portal|

|Getters **(SHARED)**|Description|
|:---|:---|
|`portal:GetSize()`|Self-explanatory, default is `Vector(50, 50, 8)`|
|`portal:GetExitPortal()`|Gets the portal's exit, `nil` or `NULL` entity if there is none|
|`portal:GetDisableBackface()`|Self-explanatory, default is `false`|

### Credits
 * Fafy2801 for finding a fix for the black skybox
 * PeteBroccoli for improving the networking system
 * WasabiThumb for fixing a black halo glitch & adding [`util.TraceLine`][ref-trln] functionality
 * WasabiThumb for also making a 'portal creator & linker' tool
 * [dvdvideo1234][ref-dvd] for making accurate portal gun surface angles & some optimizations

[ref-ws]: https://steamcommunity.com/sharedfiles/filedetails/?id=2773737445
[ref-dsc]: https://discord.gg/vdsgHsFrx2
[ref-dvd]: https://steamcommunity.com/id/dvd_video
[ref-trln]: https://wiki.facepunch.com/gmod/util.TraceLine
