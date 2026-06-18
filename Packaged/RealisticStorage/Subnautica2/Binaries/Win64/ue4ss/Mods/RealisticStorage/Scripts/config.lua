local config = {
    inventory = {
        StartingSlots = 15,
        MaxSlots = 35,
        Increment = 5,
        MaxUpgrades = 3
    },
    hotbar = {
        StartingSlots = 6,
        MaxSlots = 8,
        Increment = 1,
        MaxUpgrades = 2
    },
    biomods = {
        -- Inventory starting amount, max, etc.
        -- Each threshold crossed grants +1 mod passive biomod slot (additive on top of vanilla).
        Milestones = {4, 8, 12, 16},
        -- Maximum extra passive slots granted by this mod (vanilla story slots are unaffected).
        MaxSlots = 4,
        -- Only count creature scans under /Game/Data/BioScans/.
        ScansPerCreatureOnly = true
    }
}

return config
