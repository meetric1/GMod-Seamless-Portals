# Using Seamless Portals with Hammer

## Setup
Before using Seamless Portals with Hammer, you have to install an additional FGD.
Firstly, drop the seamless_portals.fgd file into your GarrysMod\bin folder.
Then, for it to show up on Hammer, open Tools->Options->Game Configurations->Game Data files, press Add and choose the seamless_portals.fgd file.

![](https://i.imgur.com/tpkzAEG.png)

## Placing Portals
You can create a portal by placing a seamless_portal entity.

You have to calculate the portal position and size yourself. X and Y are height and length, they are simple.
For example, if you want your portal to fit into a 128x128 hole, just set X and Y to 127.9 and place the entity into the middle.
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

# Mapping Tips
Before jumping in, please watch this small section "Figuring out the cameras" of Coding Adventure to learn in a basic sense how the portal rendering works:
https://youtu.be/cWpFZbjtSQg?t=26
1. Ensure there is space behind the portal, so the virtual camera is setup properly
2. Do not make your portals super thin, they should be at least 8 units thick (z axis) to avoid flashing, thicker if possible
3. Portals effectively rerender the entire scene, so try and keep whatever world geometry is visible from a portal semi optimized.
4. Ensure the wall geometry around each portal seam is basically perfect, so you don't get stuck mid-teleport. Ground too, though the portals will attempt to extrude you upward as best they can.
5. Keep into consideration that if there is a wall behind your portal, it is possible that there will be some PVS problems, where the virtual camera cannot see information in front of the wall (I cannot fix this, unfortunately). Try and make sure there are no areaportals behind the seamless portals

<img width="277" height="104" alt="image" src="https://github.com/user-attachments/assets/efbdd48c-32e1-4b4a-93cf-338152b54bc5" />
