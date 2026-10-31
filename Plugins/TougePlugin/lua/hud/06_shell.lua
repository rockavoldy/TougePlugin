-- Drawing helpers for the Initial D shells. Positions and sizes are in the shells' native
-- pixels; ShellScale converts them to screen units so the shells are drawn 1:1 at 1080p.

-- Opacity of everything drawn by the helpers while an element fades in or out, set by
-- DrawFaded (07_tween.lua). Faded applies it to a colour; nil means white.
local fadeAlpha = 1

local function Faded(color)
    color = color or rgbm(1, 1, 1, 1)
    if fadeAlpha >= 1 then
        return color
    end
    return rgbm(color.r, color.g, color.b, color.mult * fadeAlpha)
end

local function ShellScale()
    return scaling.get() * layout.shellScale
end

-- Draws an image with its top-left corner at shell position pos (window units).
local function DrawShellSprite(image, pos, size, color, uvMax)
    local s = ShellScale()
    local p1 = pos * s
    ui.drawImage(image, p1, p1 + size * s, Faded(color), vec2(0, 0), uvMax or vec2(1, 1))
end

-- Draws text in a shell rectangle, centered unless alignment is given, shrunk to fit its
-- width but not below minFontSize. Text that still does not fit is left-aligned and cut off
-- at the rectangle.
local function DrawShellText(text, textFont, fontSize, minFontSize, rectMin, rectMax, color, alignment)
    local width = rectMax.x - rectMin.x
    local fitted = FindFontSize(text, fontSize * layout.shellScale, textFont, width * layout.shellScale)
    fitted = math.max(fitted, minFontSize * layout.shellScale)
    local s = ShellScale()

    ui.pushDWriteFont(textFont)
    local overflows = ui.measureDWriteText(text, scaling.size(fitted)).x > width * s
    local horizontal = overflows and ui.Alignment.Start or (alignment or ui.Alignment.Center)
    ui.dwriteDrawTextClipped(text, scaling.size(fitted), rectMin * s, rectMax * s,
        horizontal, ui.Alignment.Center, false, Faded(color))
    ui.popDWriteFont()
end
