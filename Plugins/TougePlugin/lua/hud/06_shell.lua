-- Drawing helpers for the Initial D shells. Positions and sizes are in the shells' native
-- pixels; ShellScale converts them to screen units so the shells are drawn 1:1 at 1080p.

local function ShellScale()
    return scaling.get() * layout.shellScale
end

-- Draws an image with its top-left corner at shell position pos (window units).
local function DrawShellSprite(image, pos, size, color, uvMax)
    local s = ShellScale()
    local p1 = pos * s
    ui.drawImage(image, p1, p1 + size * s, color or rgbm(1, 1, 1, 1), vec2(0, 0), uvMax or vec2(1, 1))
end

-- Draws text centered in a shell rectangle, shrunk to fit its width but not below
-- minFontSize. Text that still does not fit is left-aligned and cut off at the rectangle.
local function DrawShellText(text, textFont, fontSize, minFontSize, rectMin, rectMax, color)
    local width = rectMax.x - rectMin.x
    local fitted = FindFontSize(text, fontSize * layout.shellScale, textFont, width * layout.shellScale)
    fitted = math.max(fitted, minFontSize * layout.shellScale)
    local s = ShellScale()

    ui.pushDWriteFont(textFont)
    local overflows = ui.measureDWriteText(text, scaling.size(fitted)).x > width * s
    local alignment = overflows and ui.Alignment.Start or ui.Alignment.Center
    ui.dwriteDrawTextClipped(text, scaling.size(fitted), rectMin * s, rectMax * s,
        alignment, ui.Alignment.Center, false, color)
    ui.popDWriteFont()
end

-- Draws a header label (such as the shells' "DRIVER") at shell position pos.
local function DrawShellLabel(text, pos, fontSize, color)
    ui.pushDWriteFont(fontSemiBold)
    ui.dwriteDrawText(text, scaling.size(fontSize * layout.shellScale), pos * ShellScale(), color)
    ui.popDWriteFont()
end

-- Draws a number with position-digit sprites, centered on shell x centerX.
local function DrawShellNumber(value, centerX, y, digitSize, color)
    local text = tostring(math.floor(value + 0.5))
    local left = centerX - #text * digitSize.x / 2
    for i = 1, #text do
        local digit = tonumber(text:sub(i, i))
        if digit ~= nil then
            DrawShellSprite(idSprites.positionDigits[digit], vec2(left + (i - 1) * digitSize.x, y), digitSize, color)
        end
    end
end
