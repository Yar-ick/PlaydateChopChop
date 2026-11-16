GameplayTuning = {
    SELECT_SOUND_VOLUME = 0.7,
    MENU_MUSIC_VOLUME = 0.28,
    GAME_MUSIC_VOLUME = 0.20,
    MUSIC_FADE_SECONDS = 0.35,
    MUSIC_BUFFER_SECONDS = 0.5,
    INGREDIENT_ENTER_SECONDS = 0.5,
    INGREDIENT_EXIT_SECONDS = 0.24,
    KNIFE_ENTER_DELAY = 0.07,
    INGREDIENT_SLIDE_PIXELS = 440,
    KNIFE_TRANSITION_LIFT = 180,
    CHOP_SAMPLE_VOLUME = 0.65,
    CHOP_PITCH_VARIATION = 0.06,
    CHALLENGE_SECONDS = 60,
    CHALLENGE_SPAWN_DELAY = 0.3,
    -- Relative travel: clockwise raises, counterclockwise lowers. Excess
    -- movement at either stop is discarded, so reversal responds immediately.
    KNIFE_TRAVEL_ANGLE = 30,
    KNIFE_READY_HEIGHT = 0.72,
    FOOD_COMPLETION_FRACTION = 0.05,

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
    CUT_REFERENCE_Y = 160,
    CARROT_X = 104,
    CARROT_Y = 103,
    CARROT_SCALE = 0.75,
    CARROT_BODY_START_X = 194,
    CARROT_BODY_END_X = 293,
    -- Board rectangle; BOARD_Y remains the knife's contact height.
    BOARD_LEFT = 34,
    BOARD_TOP = 106,
    BOARD_WIDTH = 332,
    BOARD_HEIGHT = 109,
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

    -- Fraction of travel remaining when the blade makes contact.
    CHOP_HEIGHT_THRESHOLD = 0.06,
}
