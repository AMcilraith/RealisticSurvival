local config = {
    -- Each threshold crossed grants +1 mod passive biomod slot (additive on top of vanilla).
    PassiveBiomodMilestones = { 3, 8, 15, 25 },
    -- Maximum extra passive slots granted by this mod (vanilla story slots are unaffected).
    MaxModPassiveSlots = 4,
    -- Only count creature scans under /Game/Data/BioScans/.
    ScansPerCreatureOnly = true,
    VerboseLogging = false
}

return config
