# Using Seamless Portals with Hammer

## Setup
Before using Seamless Portals with Hammer, you have to install an additional FGD.
Firstly, drop the seamless_portals.fgd file into your GarrysMod\bin folder.
Then, for it to show up on Hammer, open Tools->Options->Game Configurations->Game Data files, press Add and choose the seamless_portals.fgd file.

![](https://i.imgur.com/tpkzAEG.png)

## Placing Portals
You can create a portal by placing a seamless_portal entity.

You have to calculate the portal position and size yourself. X and Y are height and length, they are simple.
For example, if you want your portal to fit into a 128x128 hole, just set X and Y to 128 and place the entity into the middle.
The Z size is how thick the back of the portal is. You will likely want to keep this greater than 7 to avoid flickering during teleport.
If you see Z-fighting, just place the portal further away from the wall or slightly adjust the scale of the Z axis.
The portal angles have to point from the portal surface side. You can see which way the entity is pointing by selecting it in the 2D view.

To connect your portals, you must name them with unique names and link them with the Linked Portal property.

### An example of two portals:
![](https://i.imgur.com/R8oYKH8.png)
![](https://i.imgur.com/yDXoxfJ.png)

Now the portals are set up. If you compile the map and run it with the addon turned on, you will see your portals working properly.

### Final result:
![](https://i.imgur.com/pGVx7lb.png)