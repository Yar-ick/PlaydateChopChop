GameplayTuning = {
    -- Crank positions in degrees. Chopping turns from upper toward lower
    -- through decreasing angles (including across 0). Keep the arc under 180.
    KNIFE_UPPER_ANGLE = 300,
    KNIFE_LOWER_ANGLE = 270,

    -- Degrees of tolerance around the working arc and raised position.
    CRANK_OVERSHOOT = 30,
    READY_BELOW_UPPER = 25,
    READY_ABOVE_UPPER = 15,
    -- Fraction of travel remaining when the blade makes contact.
    CHOP_HEIGHT_THRESHOLD = 0.06,
}
