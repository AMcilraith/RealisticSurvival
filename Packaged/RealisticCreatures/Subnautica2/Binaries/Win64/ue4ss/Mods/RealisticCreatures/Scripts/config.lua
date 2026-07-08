return {
    logEnabled = true,

    -- AI tick interval in milliseconds
    aiTickMs = 1000,

    -- Seconds between full-world creature scans (FindAllOf)
    creatureScanTtlSeconds = 5.0,

    -- Seconds to cache nearest-base lookup (avoids FindAllOf every AI tick)
    baseLocationCacheSeconds = 30.0,

    -- Teleport nudges fight native AI and are expensive; off by default
    aiPhysicalNudgeEnabled = false,

    -- Population balance tick interval in milliseconds (5 min)
    populationTickMs = 300000,

    -- Max creatures with full AI simultaneously (beyond this -> forced IDLE)
    maxActiveCreatures = 30,

    -- Detection radius in UE units (1m = 100 units)
    maxDetectionRadius = 8000,

    -- Hunger / Energy / Fear
    hungerRatePerTick = 0.5,
    huntHungerThreshold = 70,
    energyRestorePerTick = 2.0,
    energyCostPerTick = 1.5,
    restEnergyThreshold = 20,
    fleeFearThreshold = 60,
    fearDecayPerTick = 5.0,
    fearFromPredatorPerTick = 12.0,

    -- FSM timing (seconds)
    huntAbandonSeconds = 15,
    restMinSeconds = 30,
    restMaxSeconds = 90,
    fleeCooldownSeconds = 8,

    -- Movement nudge per tick (UE units) during HUNT/FLEE overlay
    huntMoveStep = 80.0,
    fleeMoveStep = 100.0,
    idleSpeedMultiplier = 0.3,
    huntSpeedMultiplier = 1.0,
    fleeSpeedMultiplier = 1.0,

    -- Combat (ecosystem / AI)
    killRange = 450.0,
    attackCooldownSeconds = 1.0,
    defaultPredatorDamage = 30.0,
    destroyOnDeath = false,
    deathDestroyDelayMs = 150,

    -- Player combat (KillableCreatures-style)
    toolDamage = 20.0,
    oneHitKill = false,
    maxHitDistance = 260.0,
    hitCooldownSeconds = 0.25,
    swingInputCooldownSeconds = 0.22,
    multiToolKnifeHitDamageEnabled = true,
    visualDeath = true,
    maxDeadCreatures = 5,
    deadSinkTicks = 150,
    deadSinkStep = -0.75,
    deadForwardDriftStep = 0.12,
    deadSideDriftStep = 0.18,
    deadDriftIntervalMs = 80,
    corpseRollTicks = 24,
    moonCorpseRollTicks = 18,
    corpseRollIntervalMs = 80,
    moonCorpseSideRoll = true,
    moonCorpseRollAngle = 90.0,
    hitFxEnabled = true,
    hitFxPreloadDelayMs = 3500,
    hitFxScale = 1.6,
    hitFxCooldownSeconds = 0.28,
    hitFxAssetPaths = {
        "/Game/VFX/Creatures/Damage/NS_StringyBlood.NS_StringyBlood",
        "/Game/VFX/Impacts/Knife/NS_KnifeImpact_OrganicSoft_01.NS_KnifeImpact_OrganicSoft_01",
    },
    logHits = false,

    ecosystemGracePeriodMs = 60000,

    -- Population balance
    populationLowRatio = 0.30,
    populationHighRatio = 1.50,
    starvationDamagePerTick = 2.0,
    overcrowdDamagePerTick = 1.5,

    -- Flora / plant growth (blocked only after sustained high creature prey)
    floraEnabled = true,
    floraPreyHighRatio = 1.20,
    floraPreyBlockRatio = 1.50,
    floraLowRatio = 0.30,
    floraRecoverRatio = 0.45,
    floraStarvationDamagePerTick = 2.0,

    -- One-way cascade (requires sustained pressure across population ticks)
    cascadeStressGainPerTick = 6.0,
    cascadeStressDecayPerTick = 2.0,
    cascadeStressThreshold = 75.0,
    cascadeSustainedTicksRequired = 4,
    preyStressFromFloraThreshold = 55.0,
    predatorStressFromPreyThreshold = 50.0,
    preyRecoverRatio = 0.40,

    -- Water slugs (prey, flora-linked respawn)
    slugPatterns = { "waterslug", "WaterSlug" },

    -- Prey respawn (creature prey only; slugs use flora-linked slug respawn)
    preyRespawnEnabled = true,
    preyRespawnSeconds = 300,
    slugRespawnEnabled = true,
    slugRespawnSeconds = 300,
    slugFloraSlowMaxMultiplier = 5.0,
    slugCheckIntervalMs = 30000,

    -- Predator collapse when prey starves out (via cascade)
    preyCollapseRatio = 0.25,
    preyCollapsePredatorDamagePerTick = 3.0,

    -- Tadpole collision damage to creatures
    tadpoleImpactDamageEnabled = true,
    tadpoleImpactDamage = 25.0,
    tadpoleImpactCooldownSeconds = 0.75,

    -- Player impact
    vehicleNoiseRadius = 4000,
    predatorKillBoostSeconds = 600,
    predatorKillBoostHungerReduction = 0.5,
    baseConstructionRadius = 5000,
    baseFleeFearBoost = 40.0,
    feedingCalmSeconds = 300,
    feedingHungerReduction = 50.0,

    -- Creature health profiles (pattern -> health/damage)
    creatureHealth = {
        { pattern = "CollectorLeviathan", health = 6000.0, damage = 120.0 },
        { pattern = "ShiverLeviathan_Male", health = 1000.0, damage = 80.0 },
        { pattern = "ShiverLeviathan", health = 4000.0, damage = 100.0 },
        { pattern = "NeedlerShark", health = 300.0, damage = 45.0 },
        { pattern = "NibblerShark", health = 220.0, damage = 35.0 },
        { pattern = "Marrowbreach", health = 450.0, damage = 50.0 },
        { pattern = "Houndgar", health = 180.0, damage = 30.0 },
        { pattern = "FourEye", health = 220.0, damage = 35.0 },
        { pattern = "TwinEel", health = 180.0, damage = 30.0 },
        { pattern = "Sandspear", health = 170.0, damage = 28.0 },
        { pattern = "JetoCaris", health = 120.0, damage = 25.0 },
        { pattern = "Halfmoon", health = 40.0, damage = 5.0 },
        { pattern = "Geordie", health = 40.0, damage = 5.0 },
        { pattern = "FlashFish", health = 50.0, damage = 6.0 },
        { pattern = "Bullethead", health = 60.0, damage = 8.0 },
        { pattern = "Quadrate", health = 40.0, damage = 5.0 },
        { pattern = "SeaOlive", health = 40.0, damage = 4.0 },
        { pattern = "JellyRing", health = 80.0, damage = 10.0 },
        { pattern = "SurgeJelly", health = 80.0, damage = 10.0 },
        { pattern = "SpineyTail", health = 90.0, damage = 12.0 },
        { pattern = "Pneumo", health = 150.0, damage = 15.0 },
    },

    fallbackHealth = 100.0,
    fallbackDamage = 20.0,

    foodChain = {
        {
            predator = "ShiverLeviathan",
            prey     = { "NeedlerShark", "NibblerShark", "Marrowbreach", "Houndgar" },
        },
        {
            predator = "CollectorLeviathan",
            prey     = { "Halfmoon", "Geordie", "FlashFish", "Bullethead", "Quadrate" },
        },
        {
            predator = "NeedlerShark",
            prey     = { "Halfmoon", "Geordie", "FlashFish", "Bullethead", "SeaOlive" },
        },
        {
            predator = "NibblerShark",
            prey     = { "Halfmoon", "Geordie", "Quadrate", "SeaOlive" },
        },
        {
            predator = "Marrowbreach",
            prey     = { "JellyRing", "SurgeJelly", "SpineyTail", "Pneumo" },
        },
        {
            predator = "Houndgar",
            prey     = { "Halfmoon", "Geordie", "FlashFish" },
        },
        {
            predator = "FourEye",
            prey     = { "Halfmoon", "Geordie", "FlashFish", "Bullethead" },
        },
    },
}
