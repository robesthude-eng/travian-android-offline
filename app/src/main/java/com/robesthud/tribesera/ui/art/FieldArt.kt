package com.robesthud.tribesera.ui.art

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import com.robesthud.tribesera.engine.Res
import com.robesthud.tribesera.ui.theme.Pal
import kotlin.math.min
import kotlin.random.Random

/**
 * Ресурсное поле на изометрической плитке. Чем выше уровень, тем плотнее
 * застроен участок — лес гуще, карьер глубже, поле колосистее.
 */
fun DrawScope.drawResourceField(
    center: Offset,
    w: Float,
    h: Float,
    res: Res,
    level: Int,
    selected: Boolean,
    seed: Int,
) {
    val rnd = Random(seed * 7919 + res.ordinal)
    val density = min(6, 1 + level / 3)

    when (res) {
        Res.WOOD -> {
            drawTile(center, w, h, Pal.grass.lighten(0.05f), Pal.grassLo.darken(0.25f))
            clipPath(diamondPath(center, w, h)) {
                repeat(density + 1) {
                    val ox = (rnd.nextFloat() - 0.5f) * w * 0.62f
                    val oy = (rnd.nextFloat() - 0.5f) * h * 0.5f
                    drawConifer(Offset(center.x + ox, center.y + oy + h * 0.1f), h * (0.75f + rnd.nextFloat() * 0.35f))
                }
            }
            if (level >= 8) {
                drawRect(
                    Pal.dirt,
                    Offset(center.x - w * 0.1f, center.y + h * 0.16f),
                    Size(w * 0.2f, h * 0.07f),
                )
            }
        }

        Res.CLAY -> {
            drawTile(center, w, h, Pal.clay.darken(0.34f), Pal.clay.darken(0.55f))
            clipPath(diamondPath(center, w, h)) {
                // Ступени карьера: чем выше уровень, тем больше колец.
                val rings = 2 + level / 5
                for (i in 0 until rings) {
                    val k = 1f - i * (0.7f / rings)
                    drawPath(
                        diamondPath(Offset(center.x, center.y + h * 0.04f * i), w * 0.78f * k, h * 0.78f * k),
                        Pal.clay.darken(0.2f - i * 0.03f),
                    )
                }
                drawPath(
                    diamondPath(Offset(center.x, center.y + h * 0.1f), w * 0.24f, h * 0.24f),
                    Pal.water.mix(Pal.clay, 0.45f),
                )
                repeat(density) {
                    val ox = (rnd.nextFloat() - 0.5f) * w * 0.66f
                    val oy = (rnd.nextFloat() - 0.5f) * h * 0.5f
                    drawRock(Offset(center.x + ox, center.y + oy), h * 0.24f, Pal.clay.lighten(0.08f))
                }
            }
        }

        Res.IRON -> {
            drawTile(center, w, h, Pal.stoneLo.mix(Pal.grassLo, 0.35f), Pal.stoneLo.darken(0.4f))
            clipPath(diamondPath(center, w, h)) {
                repeat(density + 1) {
                    val ox = (rnd.nextFloat() - 0.5f) * w * 0.66f
                    val oy = (rnd.nextFloat() - 0.5f) * h * 0.55f
                    drawRock(Offset(center.x + ox, center.y + oy), h * (0.3f + rnd.nextFloat() * 0.28f), Pal.stone)
                }
                // Рудные жилы поблёскивают тем ярче, чем выше уровень.
                repeat(density * 2) {
                    val ox = (rnd.nextFloat() - 0.5f) * w * 0.6f
                    val oy = (rnd.nextFloat() - 0.5f) * h * 0.5f
                    drawCircle(Pal.iron.lighten(0.25f), h * 0.035f, Offset(center.x + ox, center.y + oy))
                }
                if (level >= 6) {
                    // вход в штольню
                    val p = poly(
                        Offset(center.x - w * 0.1f, center.y + h * 0.14f),
                        Offset(center.x - w * 0.08f, center.y + h * 0.02f),
                        Offset(center.x + w * 0.08f, center.y + h * 0.02f),
                        Offset(center.x + w * 0.1f, center.y + h * 0.14f),
                    )
                    fillPoly(p, Color(0xFF1A1A1C))
                    drawLine(
                        Pal.dirt, Offset(center.x - w * 0.11f, center.y + h * 0.02f),
                        Offset(center.x + w * 0.11f, center.y + h * 0.02f), strokeWidth = h * 0.05f,
                    )
                }
            }
        }

        Res.CROP -> {
            drawTile(center, w, h, Pal.crop.mix(Pal.grass, 0.42f), Pal.grassLo.darken(0.3f))
            clipPath(diamondPath(center, w * 0.94f, h * 0.94f)) {
                val rows = 5 + level / 4
                for (i in 0..rows) {
                    val t = i / rows.toFloat()
                    val a = Offset(center.x - w / 2f + w * t, center.y + h * (t - 0.5f) * 0f)
                    drawLine(
                        Pal.crop.mix(Pal.grass, 0.15f - t * 0.05f),
                        Offset(a.x, center.y - h / 2f),
                        Offset(a.x + w * 0.16f, center.y + h / 2f),
                        strokeWidth = w * 0.035f,
                    )
                }
                if (level >= 5) {
                    repeat(min(4, level / 5)) { i ->
                        val ox = (i - 1.2f) * w * 0.2f
                        drawSheaf(Offset(center.x + ox, center.y + h * 0.16f), h * 0.34f)
                    }
                }
            }
        }
    }

    if (selected) {
        drawPath(diamondPath(center, w * 1.02f, h * 1.02f), Pal.gold, style = Stroke(width = 3f))
    }
}

/** Сноп: пара конусов и перевязь. */
private fun DrawScope.drawSheaf(base: Offset, size: Float) {
    val p = poly(
        Offset(base.x, base.y - size),
        Offset(base.x + size * 0.3f, base.y),
        Offset(base.x - size * 0.3f, base.y),
    )
    fillPoly(p, Pal.crop.lighten(0.1f))
    drawLine(
        Pal.dirt, Offset(base.x - size * 0.24f, base.y - size * 0.3f),
        Offset(base.x + size * 0.24f, base.y - size * 0.3f), strokeWidth = size * 0.12f,
    )
}

/** Значок ресурса для панелей: маленький, читаемый, без текста. */
fun DrawScope.drawResourceGlyph(center: Offset, size: Float, res: Res) {
    when (res) {
        Res.WOOD -> {
            // бревно с торцом
            drawRoundRectPath(center, size * 1.05f, size * 0.52f, Pal.wood)
            drawCircle(Pal.wood.lighten(0.28f), size * 0.26f, Offset(center.x - size * 0.4f, center.y))
            drawCircle(Pal.wood.darken(0.2f), size * 0.14f, Offset(center.x - size * 0.4f, center.y))
        }
        Res.CLAY -> {
            val p = poly(
                Offset(center.x - size * 0.5f, center.y + size * 0.32f),
                Offset(center.x - size * 0.3f, center.y - size * 0.26f),
                Offset(center.x + size * 0.22f, center.y - size * 0.42f),
                Offset(center.x + size * 0.5f, center.y + size * 0.1f),
                Offset(center.x + size * 0.24f, center.y + size * 0.36f),
            )
            fillPoly(p, Pal.clay)
            fillPoly(
                poly(
                    Offset(center.x - size * 0.3f, center.y - size * 0.26f),
                    Offset(center.x + size * 0.22f, center.y - size * 0.42f),
                    Offset(center.x + size * 0.05f, center.y - size * 0.02f),
                ),
                Pal.clay.lighten(0.22f),
            )
        }
        Res.IRON -> {
            // слиток
            val p = poly(
                Offset(center.x - size * 0.42f, center.y + size * 0.3f),
                Offset(center.x - size * 0.28f, center.y - size * 0.14f),
                Offset(center.x + size * 0.34f, center.y - size * 0.14f),
                Offset(center.x + size * 0.48f, center.y + size * 0.3f),
            )
            fillPoly(p, Pal.iron)
            fillPoly(
                poly(
                    Offset(center.x - size * 0.28f, center.y - size * 0.14f),
                    Offset(center.x - size * 0.16f, center.y - size * 0.36f),
                    Offset(center.x + size * 0.46f, center.y - size * 0.36f),
                    Offset(center.x + size * 0.34f, center.y - size * 0.14f),
                ),
                Pal.iron.lighten(0.25f),
            )
        }
        Res.CROP -> {
            drawLine(
                Pal.crop.darken(0.25f), Offset(center.x, center.y + size * 0.42f),
                Offset(center.x, center.y - size * 0.34f), strokeWidth = size * 0.12f,
            )
            for (i in 0..3) {
                val y = center.y - size * 0.3f + i * size * 0.18f
                drawCircle(Pal.crop, size * 0.13f, Offset(center.x - size * 0.16f, y))
                drawCircle(Pal.crop.lighten(0.15f), size * 0.13f, Offset(center.x + size * 0.16f, y))
            }
        }
    }
}

private fun DrawScope.drawRoundRectPath(center: Offset, w: Float, h: Float, color: Color) {
    drawRoundRect(
        color,
        topLeft = Offset(center.x - w / 2f, center.y - h / 2f),
        size = Size(w, h),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(h / 2f, h / 2f),
    )
}
