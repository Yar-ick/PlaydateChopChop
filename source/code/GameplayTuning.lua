GameplayTuning = {
    -- Crank positions in degrees. Chopping turns from upper toward lower
    -- through decreasing angles (including across 0). Keep the arc under 180.
    KNIFE_UPPER_ANGLE = 300,
    KNIFE_LOWER_ANGLE = 270,

    -- Placement for the current artwork. Keep the original diagonal knife orientation.
    KNIFE_IMAGE_ROTATION = 0,
    KNIFE_IMAGE_SCALE = 0.5,
    -- Contact point on the cutting edge, as fractions of image dimensions.
    KNIFE_BLADE_ANCHOR_X = 0.707,
    KNIFE_BLADE_ANCHOR_Y = 0.44,
    KNIFE_LIFT = 30,
    -- Forward/back travel along the blade during a full crank stroke (pixels).
    KNIFE_STROKE_TRAVEL = 24,
    -- Horizontal change per vertical pixel along the blade's cutting edge.
    CUT_SLOPE = -0.45,
    CUT_REFERENCE_Y = 141,
    CARROT_X = 64,
    CARROT_Y = 65,
    CARROT_SCALE = 1,
    CARROT_BODY_START_X = 184,
    CARROT_BODY_END_X = 316,
    BOARD_Y = 152,

    -- Ingredient mechanics. Speed is full knife travels per second.
    TOMATO_MAX_SPEED = 3,
    TOMATO_CRUSH_MULTIPLIER = 0.35,
    CUCUMBER_SLIP_MIN = 4,
    CUCUMBER_SLIP_MAX = 10,
    CUCUMBER_MAX_OFFSET = 24,
    POTATO_ROLL_CHANCE = 70,
    POTATO_MAX_ROLL = 9,
    FOOD_SETTLE_TIME = 0.18,
    ONION_LAYER_EVERY = 3,
    ONION_LAYER_SECONDS = 1.8,

    -- Degrees of tolerance around the working arc and raised position.
    CRANK_OVERSHOOT = 30,
    READY_BELOW_UPPER = 25,
    READY_ABOVE_UPPER = 15,
    -- Fraction of travel remaining when the blade makes contact.
    CHOP_HEIGHT_THRESHOLD = 0.06,
}
