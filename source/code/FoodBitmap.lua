import "CoreLibs/graphics"
import "code/GameplayTuning"
FoodBitmap = {}
local gfx = playdate.graphics
local slope = GameplayTuning.CUT_SLOPE
local unpack = table.unpack
local mask, inverse, maskW, maskH

-- Read the silhouette once when loading the ingredient, never during a cut.
-- Potato rows are contiguous; retaining the stepped boundary also preserves
-- the uneven outline rather than approximating it with a rectangle or ellipse.
function FoodBitmap.outline(image)
    local w, h = image:getSize()
    local left, right = {}, {}
    for row = 0, h - 1 do
        local first, last
        for col = 0, w - 1 do
            if image:sample(col, row) ~= gfx.kColorClear then first = col; break end
        end
        if first then
            for col = w - 1, first, -1 do
                if image:sample(col, row) ~= gfx.kColorClear then last = col + 1; break end
            end
            left[#left+1], left[#left+2] = first, row
            left[#left+1], left[#left+2] = first, row+1
            right[#right+1], right[#right+2] = last, row
            right[#right+1], right[#right+2] = last, row+1
        end
    end
    for i = #right - 1, 1, -2 do
        left[#left+1], left[#left+2] = right[i], right[i+1]
    end
    return left
end

-- Clip local-coordinate polygon against the actual world-space cut line.
function FoodBitmap.clip(points, edge, x, y, food, keepLeft)
    local result = {}
    if #points == 0 then return result end
    local px, py = points[#points-1], points[#points]
    local pd = x + px - slope * (y + py - food.referenceY) - edge
    if not keepLeft then pd = -pd end
    for i = 1, #points, 2 do
        local cx, cy = points[i], points[i+1]
        local cd = x + cx - slope * (y + cy - food.referenceY) - edge
        if not keepLeft then cd = -cd end
        if (cd <= 0) ~= (pd <= 0) then
            local t = pd / (pd - cd)
            result[#result+1], result[#result+2] = px + (cx-px)*t, py + (cy-py)*t
        end
        if cd <= 0 then result[#result+1], result[#result+2] = cx, cy end
        px, py, pd = cx, cy, cd
    end
    return result
end

local function scratch(w, h)
    -- Playdate rejects stencil images narrower than 32 pixels. A cropped
    -- potato can be much narrower; pad scratch masks, never the source food.
    -- Reuse the same word-aligned buffer for widths in the same 32px bucket.
    local stencilW = math.max(32, math.ceil(w / 32) * 32)
    if stencilW ~= maskW or h ~= maskH then
        mask = gfx.image.new(stencilW, h, gfx.kColorBlack)
        inverse = gfx.image.new(stencilW, h, gfx.kColorBlack)
        maskW, maskH = stencilW, h
    end
end
local function fillMask(points)
    gfx.pushContext(mask)
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)
    if #points >= 6 then gfx.fillPolygon(unpack(points)) end
    gfx.popContext()
end
local function masked(image, stencil, w, h)
    local output = gfx.image.new(w, h, gfx.kColorClear)
    gfx.pushContext(output)
    gfx.setStencilImage(stencil)
    image:draw(0, 0)
    gfx.clearStencil()
    gfx.popContext()
    return output
end

-- One polygon mask and its exact inverse partition the source, so no pixels
-- are lost or duplicated at the cut. All bitmap work runs in native graphics.
function FoodBitmap.split(image, x, y, food, edge)
    local w, h = image:getSize()
    scratch(w, h)
    fillMask(FoodBitmap.clip({0,0,w,0,w,h,0,h}, edge, x, y, food, false))
    local slice = masked(image, mask, w, h)
    gfx.pushContext(inverse)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    mask:draw(0, 0)
    gfx.popContext()
    local remaining = masked(image, inverse, w, h)
    return slice, remaining
end

function FoodBitmap.section(image, x, y, food, left, right)
    local w, h = image:getSize()
    scratch(w, h)
    local points = {0,0,w,0,w,h,0,h}
    if left then points = FoodBitmap.clip(points, left, x, y, food, false) end
    if right then points = FoodBitmap.clip(points, right, x, y, food, true) end
    fillMask(points)
    return masked(image, mask, w, h)
end

function FoodBitmap.rotateOutline(points, angle, w, h, rw, rh)
    local c, s = math.cos(math.rad(angle)), math.sin(math.rad(angle))
    local result = {}
    for i = 1, #points, 2 do
        local x, y = points[i] - w/2, points[i+1] - h/2
        result[i], result[i+1] = c*x-s*y+rw/2, s*x+c*y+rh/2
    end
    return result
end

-- Crop and score bounds from the cached outline: O(boundary points), with no
-- image sampling. A one-pixel margin accommodates native rotation rounding.
function FoodBitmap.fit(image, x, y, food, points)
    assert(points, "Potato outline must be cached before cutting")
    local w, h = image:getSize()
    local left, top, right, bottom = w, h, 0, 0
    local first, last = math.huge, -math.huge
    for i = 1, #points, 2 do
        local px, py = points[i], points[i+1]
        if px < left then left = px end
        if px > right then right = px end
        if py < top then top = py end
        if py > bottom then bottom = py end
        local projected = x + px - slope * (y + py - food.referenceY)
        if projected < first then first = projected end
        if projected > last then last = projected end
    end
    if #points == 0 then return image, x, y, food.startX, food.startX+2, points end
    left, top = math.max(0, math.floor(left)-1), math.max(0, math.floor(top)-1)
    right, bottom = math.min(w, math.ceil(right)+1), math.min(h, math.ceil(bottom)+1)
    local cropped = image
    if left ~= 0 or top ~= 0 or right ~= w or bottom ~= h then
        cropped = gfx.image.new(right-left, bottom-top, gfx.kColorClear)
        gfx.pushContext(cropped)
        image:draw(-left, -top)
        gfx.popContext()
    end
    local shifted = {}
    for i = 1, #points, 2 do shifted[i], shifted[i+1] = points[i]-left, points[i+1]-top end
    return cropped, x+left, y+top, math.floor(first), math.ceil(last), shifted
end

-- Area follows the cached edible silhouette through clipping and rolling;
-- no bitmap reads or dependence on the potato's changing bounding-box width.
function FoodBitmap.area(points)
    if #points < 6 then return 0 end
    local area = 0
    local px, py = points[#points-1], points[#points]
    for i = 1, #points, 2 do
        local x, y = points[i], points[i+1]
        area = area + px*y - x*py
        px, py = x, y
    end
    return math.abs(area) * 0.5
end