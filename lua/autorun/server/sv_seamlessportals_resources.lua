-- Requests for certain resources to be sent to clients. Required because most clients wont have the addon downloaded.
-- Shows the portal gun and seamless portal icon (for now, if any others are added it needs to be here)

-- TODO: Figure out which is more optimal, single file additions for quick development, or
-- workshop addition for automated client downloading of these resources.
resource.AddSingleFile("materials/entities/portal_gun.png")
resource.AddSingleFile("materials/entities/seamless_portal.png")