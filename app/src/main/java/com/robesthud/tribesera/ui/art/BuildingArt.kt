package com.robesthud.tribesera.ui.art

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import com.robesthud.tribesera.engine.BuildingType
import com.robesthud.tribesera.ui.theme.Pal

/** Палитра конкретного здания: стены, торец, крыша, акцент. */
private data class Skin(val wall: Color, val roof: Color, val accent: Color)

private fun skinOf(type: BuildingType): Skin = when (type) {
    BuildingType.MAIN -> Skin(Color(0xFFE3D2AC), Color(0xFFB44A38), Pal.gold)
    BuildingType.WAREHOUSE -> Skin(Color(0xFFB0834F), Color(0xFF6F5232), Color(0xFF8A6437))
    BuildingType.GRANARY -> Skin(Color(0xFFD8C08A), Color(0xFFCB9B45), Color(0xFFEBD08F))
    BuildingType.CRANNY -> Skin(Color(0xFF6B5A42), Color(0xFF3E3225), Color(0xFF8E7A57))
    BuildingType.MARKET -> Skin(Color(0xFFDCCFB2), Color(0xFFC5553F), Color(0xFFF0EAD8))
    BuildingType.ACADEMY -> Skin(Color(0xFFE8E4D6), Color(0xFF3E6E93), Color(0xFF9FC4DE))
    BuildingType.BARRACKS -> Skin(Color(0xFF8E7350), Color(0xFF4A4A4E), Color(0xFFC0453A))
    BuildingType.SMITHY -> Skin(Color(0xFF8E9095), Color(0xFF3A3A3D), Color(0xFFF08A2E))
    BuildingType.STABLE -> Skin(Color(0xFF9A7346), Color(0xFFC79E52), Color(0xFF5E4429))
    BuildingType.WORKSHOP -> Skin(Color(0xFF8B6B45), Color(0xFF5D482E), Color(0xFFB9B2A4))
    BuildingType.RESIDENCE -> Skin(Color(0xFFDCD6C6), Color(0xFF5B4A8C), Color(0xFFE8B14C))
    BuildingType.RALLY -> Skin(Color(0xFF8C6E4A), Color(0xFF6A4F32), Color(0xFFE05C3E))
    BuildingType.WALL -> Skin(Color(0xFF9AA0A2), Color(0xFF6B7173), Color(0xFF7F8688))
    BuildingType.WONDER -> Skin(Color(0xFFE7D08A), Color(0xFFCFA23F), Color(0xFFFFF2C4))
}

/**
 * Здание на изометрической плитке. Силуэты нарочно разные: игрок должен
 * узнавать постройку по форме, а не читать подпись.
 */
fun DrawScope.drawBuilding(
    type: BuildingType,
    center: Offset,
    w: Float,
    h: Float,
    level: Int,
    selected: Boolean = false,
) {
    val skin = skinOf(type)
    val baseY = center.y + h * 0.22f
    // Основание — утоптанная земля вокруг постройки.
    drawTile(center, w, h, Pal.dirt.mix(Pal.grass, 0.35f), Pal.dirtLo, depth = h * 0.2f)
    // Мягкая тень.
    drawBlob(Offset(center.x, baseY - h * 0.02f), w * 0.72f, h * 0.42f, Color(0x33000000))

    val s = h * 1.05f // базовый масштаб построек
    when (type) {
        BuildingType.MAIN -> {
            drawHall(center.x, baseY, s * 1.0f, skin)
            drawBanner(Offset(center.x + s * 0.42f, baseY - s * 0.1f), s * 0.7f, skin.accent)
        }

        BuildingType.WAREHOUSE -> {
            drawShed(center.x - s * 0.18f, baseY, s * 0.62f, skin)
            drawCrates(center.x + s * 0.34f, baseY, s * 0.34f, skin)
        }

        BuildingType.GRANARY -> {
            drawSilo(center.x - s * 0.16f, baseY, s * 0.5f, skin)
            drawSilo(center.x + s * 0.26f, baseY - s * 0.04f, s * 0.36f, skin)
        }

        BuildingType.CRANNY -> {
            // земляной холм с люком
            drawArcMound(center.x, baseY, s * 0.8f, s * 0.34f, skin.wall)
            val p = poly(
                Offset(center.x - s * 0.16f, baseY - s * 0.06f),
                Offset(center.x - s * 0.1f, baseY - s * 0.24f),
                Offset(center.x + s * 0.14f, baseY - s * 0.24f),
                Offset(center.x + s * 0.2f, baseY - s * 0.06f),
            )
            fillPoly(p, skin.roof)
            drawLine(skin.accent, Offset(center.x - s * 0.1f, baseY - s * 0.15f), Offset(center.x + s * 0.16f, baseY - s * 0.15f), strokeWidth = s * 0.04f)
        }

        BuildingType.MARKET -> {
            drawStall(center.x - s * 0.24f, baseY, s * 0.46f, skin)
            drawStall(center.x + s * 0.26f, baseY - s * 0.03f, s * 0.38f, skin)
        }

        BuildingType.ACADEMY -> {
            drawTemple(center.x, baseY, s * 0.92f, skin)
        }

        BuildingType.BARRACKS -> {
            drawShed(center.x, baseY, s * 0.86f, skin)
            // щит и копья у входа
            drawCircle(skin.accent, s * 0.13f, Offset(center.x - s * 0.4f, baseY - s * 0.16f))
            drawCircle(Color(0xFFEDE3C8), s * 0.06f, Offset(center.x - s * 0.4f, baseY - s * 0.16f))
            drawLine(Pal.dirtLo, Offset(center.x + s * 0.42f, baseY), Offset(center.x + s * 0.34f, baseY - s * 0.55f), strokeWidth = s * 0.045f)
            drawLine(Pal.dirtLo, Offset(center.x + s * 0.5f, baseY), Offset(center.x + s * 0.46f, baseY - s * 0.5f), strokeWidth = s * 0.045f)
        }

        BuildingType.SMITHY -> {
            drawShed(center.x - s * 0.06f, baseY, s * 0.74f, skin)
            // труба и горн
            drawRect(
                skin.wall.darken(0.25f),
                Offset(center.x + s * 0.3f, baseY - s * 0.86f),
                Size(s * 0.16f, s * 0.5f),
            )
            drawCircle(skin.accent, s * 0.1f, Offset(center.x + s * 0.38f, baseY - s * 0.92f))
            drawCircle(skin.accent.lighten(0.35f), s * 0.05f, Offset(center.x + s * 0.38f, baseY - s * 0.96f))
            drawCircle(skin.accent, s * 0.11f, Offset(center.x - s * 0.02f, baseY - s * 0.2f))
        }

        BuildingType.STABLE -> {
            drawShed(center.x, baseY, s * 0.88f, skin)
            // распахнутые ворота и силуэт коня
            drawRect(Color(0xFF2A2118), Offset(center.x - s * 0.16f, baseY - s * 0.42f), Size(s * 0.32f, s * 0.42f))
            drawHorse(center.x, baseY - s * 0.06f, s * 0.3f)
        }

        BuildingType.WORKSHOP -> {
            drawOpenFrame(center.x, baseY, s * 0.9f, skin)
            drawCatapult(center.x + s * 0.02f, baseY - s * 0.04f, s * 0.42f, skin)
        }

        BuildingType.RESIDENCE -> {
            drawTower(center.x - s * 0.38f, baseY, s * 0.34f, s * 0.9f, skin)
            drawHall(center.x + s * 0.06f, baseY, s * 0.72f, skin)
            drawTower(center.x + s * 0.46f, baseY, s * 0.3f, s * 0.76f, skin)
        }

        BuildingType.RALLY -> {
            // помост, барабан и знамя
            drawRoundRect(
                skin.wall,
                Offset(center.x - s * 0.42f, baseY - s * 0.16f),
                Size(s * 0.84f, s * 0.18f),
                CornerRadius(s * 0.05f, s * 0.05f),
            )
            drawRoundRect(
                skin.roof,
                Offset(center.x - s * 0.26f, baseY - s * 0.42f),
                Size(s * 0.3f, s * 0.28f),
                CornerRadius(s * 0.06f, s * 0.06f),
            )
            drawBanner(Offset(center.x + s * 0.26f, baseY - s * 0.14f), s * 0.85f, skin.accent)
        }

        BuildingType.WALL -> {
            drawPalisadeSegment(center.x, baseY, s, skin)
        }

        BuildingType.WONDER -> {
            drawZiggurat(center.x, baseY, s * 1.0f, skin, level)
        }
    }

    if (selected) {
        drawPath(diamondPath(center, w * 1.02f, h * 1.02f), Pal.gold, style = Stroke(width = 3f))
    }
}

// ==========================================================================
// Строительные блоки
// ==========================================================================

/** Дом с двускатной крышей и фронтоном. */
private fun DrawScope.drawHall(cx: Float, baseY: Float, s: Float, skin: Skin) {
    val w = s * 0.9f
    val wallH = s * 0.52f
    drawRect(skin.wall, Offset(cx - w / 2f, baseY - wallH), Size(w, wallH))
    drawRect(skin.wall.darken(0.2f), Offset(cx + w * 0.28f, baseY - wallH), Size(w * 0.22f, wallH))
    // крыша
    val roof = poly(
        Offset(cx - w * 0.62f, baseY - wallH),
        Offset(cx, baseY - wallH - s * 0.46f),
        Offset(cx + w * 0.62f, baseY - wallH),
    )
    fillPoly(roof, skin.roof)
    fillPoly(
        poly(
            Offset(cx, baseY - wallH - s * 0.46f),
            Offset(cx + w * 0.62f, baseY - wallH),
            Offset(cx + w * 0.3f, baseY - wallH),
        ),
        skin.roof.darken(0.2f),
    )
    // дверь и окна
    drawRect(Color(0xFF3A2A1C), Offset(cx - w * 0.11f, baseY - wallH * 0.72f), Size(w * 0.22f, wallH * 0.72f))
    drawRect(skin.roof.darken(0.35f), Offset(cx - w * 0.36f, baseY - wallH * 0.78f), Size(w * 0.14f, wallH * 0.3f))
}

/** Вытянутый амбар-сарай. */
private fun DrawScope.drawShed(cx: Float, baseY: Float, s: Float, skin: Skin) {
    val w = s * 1.0f
    val wallH = s * 0.44f
    drawRect(skin.wall, Offset(cx - w / 2f, baseY - wallH), Size(w, wallH))
    // брёвна
    var y = baseY - wallH + s * 0.08f
    while (y < baseY) {
        drawLine(skin.wall.darken(0.16f), Offset(cx - w / 2f, y), Offset(cx + w / 2f, y), strokeWidth = s * 0.02f)
        y += s * 0.11f
    }
    val roof = poly(
        Offset(cx - w * 0.6f, baseY - wallH),
        Offset(cx - w * 0.2f, baseY - wallH - s * 0.36f),
        Offset(cx + w * 0.2f, baseY - wallH - s * 0.36f),
        Offset(cx + w * 0.6f, baseY - wallH),
    )
    fillPoly(roof, skin.roof)
    fillPoly(
        poly(
            Offset(cx + w * 0.2f, baseY - wallH - s * 0.36f),
            Offset(cx + w * 0.6f, baseY - wallH),
            Offset(cx + w * 0.24f, baseY - wallH),
        ),
        skin.roof.darken(0.18f),
    )
}

/** Круглый амбар с конической крышей. */
private fun DrawScope.drawSilo(cx: Float, baseY: Float, s: Float, skin: Skin) {
    val w = s * 0.66f
    val wallH = s * 0.62f
    drawRoundRect(
        skin.wall,
        Offset(cx - w / 2f, baseY - wallH),
        Size(w, wallH),
        CornerRadius(w * 0.18f, w * 0.18f),
    )
    drawRect(skin.wall.darken(0.18f), Offset(cx + w * 0.16f, baseY - wallH), Size(w * 0.34f, wallH))
    fillPoly(
        poly(
            Offset(cx - w * 0.72f, baseY - wallH),
            Offset(cx, baseY - wallH - s * 0.42f),
            Offset(cx + w * 0.72f, baseY - wallH),
        ),
        skin.roof,
    )
    drawLine(skin.accent, Offset(cx - w * 0.3f, baseY - wallH * 0.5f), Offset(cx + w * 0.3f, baseY - wallH * 0.5f), strokeWidth = s * 0.035f)
}

private fun DrawScope.drawCrates(cx: Float, baseY: Float, s: Float, skin: Skin) {
    val c = skin.accent
    drawRect(c, Offset(cx - s * 0.5f, baseY - s * 0.5f), Size(s * 0.5f, s * 0.5f))
    drawRect(c.darken(0.2f), Offset(cx - s * 0.05f, baseY - s * 0.42f), Size(s * 0.42f, s * 0.42f))
    drawRect(c.lighten(0.12f), Offset(cx - s * 0.3f, baseY - s * 0.92f), Size(s * 0.44f, s * 0.42f))
    drawLine(c.darken(0.4f), Offset(cx - s * 0.5f, baseY - s * 0.25f), Offset(cx, baseY - s * 0.25f), strokeWidth = s * 0.05f)
}

/** Торговый прилавок с полосатым тентом. */
private fun DrawScope.drawStall(cx: Float, baseY: Float, s: Float, skin: Skin) {
    drawRect(skin.wall.darken(0.3f), Offset(cx - s * 0.42f, baseY - s * 0.34f), Size(s * 0.84f, s * 0.34f))
    val awningY = baseY - s * 0.34f
    val stripes = 5
    for (i in 0 until stripes) {
        val x0 = cx - s * 0.5f + i * (s / stripes)
        fillPoly(
            poly(
                Offset(x0, awningY),
                Offset(x0 + s / stripes, awningY),
                Offset(x0 + s / stripes * 0.82f, awningY - s * 0.3f),
                Offset(x0 + s / stripes * 0.18f, awningY - s * 0.3f),
            ),
            if (i % 2 == 0) skin.roof else skin.accent,
        )
    }
    drawLine(Pal.dirtLo, Offset(cx - s * 0.46f, awningY - s * 0.3f), Offset(cx - s * 0.46f, baseY), strokeWidth = s * 0.045f)
    drawLine(Pal.dirtLo, Offset(cx + s * 0.46f, awningY - s * 0.3f), Offset(cx + s * 0.46f, baseY), strokeWidth = s * 0.045f)
}

/** Академия: колонны и фронтон. */
private fun DrawScope.drawTemple(cx: Float, baseY: Float, s: Float, skin: Skin) {
    val w = s * 0.92f
    val wallH = s * 0.5f
    drawRect(skin.wall.darken(0.12f), Offset(cx - w / 2f - s * 0.05f, baseY - s * 0.08f), Size(w + s * 0.1f, s * 0.08f))
    val cols = 4
    for (i in 0 until cols) {
        val x = cx - w / 2f + w * (i + 0.5f) / cols
        drawRoundRect(
            skin.wall,
            Offset(x - w * 0.06f, baseY - wallH),
            Size(w * 0.12f, wallH - s * 0.06f),
            CornerRadius(w * 0.03f, w * 0.03f),
        )
    }
    drawRect(skin.wall.lighten(0.1f), Offset(cx - w / 2f - s * 0.04f, baseY - wallH - s * 0.08f), Size(w + s * 0.08f, s * 0.08f))
    fillPoly(
        poly(
            Offset(cx - w * 0.6f, baseY - wallH - s * 0.08f),
            Offset(cx, baseY - wallH - s * 0.46f),
            Offset(cx + w * 0.6f, baseY - wallH - s * 0.08f),
        ),
        skin.roof,
    )
    drawCircle(skin.accent, s * 0.07f, Offset(cx, baseY - wallH - s * 0.2f))
}

private fun DrawScope.drawTower(cx: Float, baseY: Float, w: Float, hgt: Float, skin: Skin) {
    drawRect(skin.wall, Offset(cx - w / 2f, baseY - hgt), Size(w, hgt))
    drawRect(skin.wall.darken(0.18f), Offset(cx + w * 0.18f, baseY - hgt), Size(w * 0.32f, hgt))
    fillPoly(
        poly(
            Offset(cx - w * 0.72f, baseY - hgt),
            Offset(cx, baseY - hgt - w * 1.05f),
            Offset(cx + w * 0.72f, baseY - hgt),
        ),
        skin.roof,
    )
    drawRect(Color(0xFF2C2418), Offset(cx - w * 0.16f, baseY - hgt * 0.62f), Size(w * 0.32f, hgt * 0.26f))
}

/** Мастерская: открытый навес на столбах. */
private fun DrawScope.drawOpenFrame(cx: Float, baseY: Float, s: Float, skin: Skin) {
    val w = s * 0.98f
    val topY = baseY - s * 0.62f
    drawLine(skin.wall, Offset(cx - w / 2f, baseY), Offset(cx - w / 2f, topY), strokeWidth = s * 0.07f)
    drawLine(skin.wall, Offset(cx + w / 2f, baseY), Offset(cx + w / 2f, topY), strokeWidth = s * 0.07f)
    fillPoly(
        poly(
            Offset(cx - w * 0.62f, topY),
            Offset(cx - w * 0.16f, topY - s * 0.3f),
            Offset(cx + w * 0.16f, topY - s * 0.3f),
            Offset(cx + w * 0.62f, topY),
        ),
        skin.roof,
    )
    drawRect(skin.wall.darken(0.3f), Offset(cx - w / 2f, baseY - s * 0.1f), Size(w, s * 0.1f))
}

private fun DrawScope.drawCatapult(cx: Float, baseY: Float, s: Float, skin: Skin) {
    drawCircle(Pal.dirtLo, s * 0.16f, Offset(cx - s * 0.3f, baseY - s * 0.16f))
    drawCircle(Pal.dirtLo, s * 0.16f, Offset(cx + s * 0.3f, baseY - s * 0.16f))
    drawLine(skin.accent, Offset(cx - s * 0.42f, baseY - s * 0.2f), Offset(cx + s * 0.42f, baseY - s * 0.2f), strokeWidth = s * 0.1f)
    drawLine(skin.accent, Offset(cx - s * 0.2f, baseY - s * 0.2f), Offset(cx + s * 0.24f, baseY - s * 0.78f), strokeWidth = s * 0.09f)
    drawCircle(Pal.stone, s * 0.13f, Offset(cx + s * 0.28f, baseY - s * 0.84f))
}

private fun DrawScope.drawHorse(cx: Float, baseY: Float, s: Float) {
    // Светлее проёма, иначе силуэт тонет в темноте ворот.
    val c = Color(0xFFB08A5A)
    drawRoundRect(c, Offset(cx - s * 0.5f, baseY - s * 0.7f), Size(s, s * 0.42f), CornerRadius(s * 0.2f, s * 0.2f))
    drawRoundRect(c, Offset(cx + s * 0.22f, baseY - s * 1.02f), Size(s * 0.26f, s * 0.42f), CornerRadius(s * 0.1f, s * 0.1f))
    drawLine(c, Offset(cx - s * 0.3f, baseY - s * 0.32f), Offset(cx - s * 0.3f, baseY), strokeWidth = s * 0.1f)
    drawLine(c, Offset(cx + s * 0.28f, baseY - s * 0.32f), Offset(cx + s * 0.28f, baseY), strokeWidth = s * 0.1f)
}

private fun DrawScope.drawArcMound(cx: Float, baseY: Float, w: Float, hgt: Float, color: Color) {
    val p = androidx.compose.ui.graphics.Path().apply {
        moveTo(cx - w / 2f, baseY)
        cubicTo(cx - w * 0.36f, baseY - hgt * 1.6f, cx + w * 0.36f, baseY - hgt * 1.6f, cx + w / 2f, baseY)
        close()
    }
    drawPath(p, color)
}

/** Кусок частокола — из него собирается кольцо стены вокруг деревни. */
private fun DrawScope.drawPalisadeSegment(cx: Float, baseY: Float, s: Float, skin: Skin) {
    val n = 5
    for (i in 0 until n) {
        val x = cx - s * 0.44f + i * (s * 0.88f / (n - 1))
        val hh = s * (0.42f + (i % 2) * 0.06f)
        drawRoundRect(
            skin.wall,
            Offset(x - s * 0.06f, baseY - hh),
            Size(s * 0.12f, hh),
            CornerRadius(s * 0.06f, s * 0.06f),
        )
    }
    drawLine(skin.roof, Offset(cx - s * 0.48f, baseY - s * 0.22f), Offset(cx + s * 0.48f, baseY - s * 0.22f), strokeWidth = s * 0.05f)
}

/** Чудо света: ступенчатая пирамида, которая растёт вместе с уровнем. */
private fun DrawScope.drawZiggurat(cx: Float, baseY: Float, s: Float, skin: Skin, level: Int) {
    val steps = (2 + level.coerceIn(0, 10) * 0.5f).toInt().coerceIn(2, 7)
    var y = baseY
    var w = s * 1.0f
    for (i in 0 until steps) {
        val hh = s * 0.16f
        drawRect(
            if (i % 2 == 0) skin.wall else skin.wall.darken(0.12f),
            Offset(cx - w / 2f, y - hh),
            Size(w, hh),
        )
        drawRect(skin.roof.copy(alpha = 0.6f), Offset(cx - w / 2f, y - hh), Size(w, hh * 0.16f))
        y -= hh
        w *= 0.82f
    }
    // навершие светится
    drawCircle(skin.accent.copy(alpha = 0.35f), s * 0.24f, Offset(cx, y - s * 0.1f))
    drawCircle(skin.accent, s * 0.1f, Offset(cx, y - s * 0.1f))
}

/** Пустой участок: колышки и табличка «строить». */
fun DrawScope.drawEmptyPlot(center: Offset, w: Float, h: Float, selected: Boolean) {
    drawTile(center, w, h, Pal.dirt.mix(Pal.grass, 0.55f), Pal.dirtLo, depth = h * 0.18f)
    drawPath(
        diamondPath(center, w * 0.62f, h * 0.62f),
        Pal.gold.copy(alpha = 0.35f),
        style = Stroke(width = 2f, pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(8f, 7f))),
    )
    val s = h * 0.34f
    drawLine(Pal.gold.copy(alpha = 0.75f), Offset(center.x - s * 0.4f, center.y), Offset(center.x + s * 0.4f, center.y), strokeWidth = 3f)
    drawLine(Pal.gold.copy(alpha = 0.75f), Offset(center.x, center.y - s * 0.4f), Offset(center.x, center.y + s * 0.4f), strokeWidth = 3f)
    if (selected) {
        drawPath(diamondPath(center, w * 1.02f, h * 1.02f), Pal.gold, style = Stroke(width = 3f))
    }
}
