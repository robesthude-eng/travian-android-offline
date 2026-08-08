package com.robesthud.tribesera.ui.art

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import com.robesthud.tribesera.engine.UnitKind
import com.robesthud.tribesera.ui.theme.Pal

/**
 * Силуэт рода войск. Одного взгляда должно хватать, чтобы отличить пехоту от
 * конницы, а осадную технику — от поселенцев.
 */
fun DrawScope.drawUnitGlyph(kind: UnitKind, center: Offset, s: Float, tint: Color) {
    when (kind) {
        UnitKind.INFANTRY -> {
            // щит и копьё
            drawLine(
                Pal.dirt, Offset(center.x + s * 0.34f, center.y + s * 0.44f),
                Offset(center.x + s * 0.22f, center.y - s * 0.5f), strokeWidth = s * 0.09f,
            )
            drawPath(
                poly(
                    Offset(center.x + s * 0.22f, center.y - s * 0.5f),
                    Offset(center.x + s * 0.32f, center.y - s * 0.3f),
                    Offset(center.x + s * 0.12f, center.y - s * 0.3f),
                ),
                Pal.stone,
            )
            val shield = poly(
                Offset(center.x - s * 0.36f, center.y - s * 0.36f),
                Offset(center.x + s * 0.06f, center.y - s * 0.36f),
                Offset(center.x + s * 0.06f, center.y + s * 0.12f),
                Offset(center.x - s * 0.15f, center.y + s * 0.44f),
                Offset(center.x - s * 0.36f, center.y + s * 0.12f),
            )
            drawPath(shield, tint)
            drawPath(shield, tint.darken(0.35f), style = Stroke(width = s * 0.06f))
        }

        UnitKind.CAVALRY -> {
            drawHorseGlyph(center, s, tint)
            drawLine(
                Pal.stone, Offset(center.x + s * 0.1f, center.y - s * 0.52f),
                Offset(center.x + s * 0.46f, center.y + s * 0.06f), strokeWidth = s * 0.08f,
            )
        }

        UnitKind.SCOUT -> {
            drawHorseGlyph(center, s * 0.86f, tint.lighten(0.15f))
            drawCircle(Pal.gold, s * 0.12f, Offset(center.x + s * 0.34f, center.y - s * 0.42f))
        }

        UnitKind.SIEGE -> {
            drawCircle(Pal.dirtLo, s * 0.16f, Offset(center.x - s * 0.26f, center.y + s * 0.3f))
            drawCircle(Pal.dirtLo, s * 0.16f, Offset(center.x + s * 0.24f, center.y + s * 0.3f))
            drawLine(tint, Offset(center.x - s * 0.42f, center.y + s * 0.16f), Offset(center.x + s * 0.42f, center.y + s * 0.16f), strokeWidth = s * 0.12f)
            drawLine(tint, Offset(center.x - s * 0.18f, center.y + s * 0.16f), Offset(center.x + s * 0.22f, center.y - s * 0.44f), strokeWidth = s * 0.1f)
            drawCircle(Pal.stone, s * 0.14f, Offset(center.x + s * 0.26f, center.y - s * 0.5f))
        }

        UnitKind.CHIEF -> {
            drawLine(Pal.dirt, Offset(center.x - s * 0.24f, center.y + s * 0.46f), Offset(center.x - s * 0.24f, center.y - s * 0.5f), strokeWidth = s * 0.09f)
            drawPath(
                poly(
                    Offset(center.x - s * 0.24f, center.y - s * 0.5f),
                    Offset(center.x + s * 0.46f, center.y - s * 0.3f),
                    Offset(center.x - s * 0.24f, center.y - s * 0.06f),
                ),
                tint,
            )
            drawCircle(Pal.gold, s * 0.1f, Offset(center.x - s * 0.24f, center.y - s * 0.56f))
        }

        UnitKind.SETTLER -> {
            // повозка с поклажей
            drawRoundRect(
                tint, Offset(center.x - s * 0.44f, center.y - s * 0.16f),
                Size(s * 0.88f, s * 0.42f), CornerRadius(s * 0.08f, s * 0.08f),
            )
            drawPath(
                poly(
                    Offset(center.x - s * 0.36f, center.y - s * 0.16f),
                    Offset(center.x, center.y - s * 0.56f),
                    Offset(center.x + s * 0.36f, center.y - s * 0.16f),
                ),
                Color(0xFFEDE3C8),
            )
            drawCircle(Pal.dirtLo, s * 0.15f, Offset(center.x - s * 0.26f, center.y + s * 0.32f))
            drawCircle(Pal.dirtLo, s * 0.15f, Offset(center.x + s * 0.26f, center.y + s * 0.32f))
        }
    }
}

private fun DrawScope.drawHorseGlyph(center: Offset, s: Float, tint: Color) {
    drawRoundRect(
        tint, Offset(center.x - s * 0.44f, center.y - s * 0.12f),
        Size(s * 0.8f, s * 0.36f), CornerRadius(s * 0.16f, s * 0.16f),
    )
    drawRoundRect(
        tint, Offset(center.x + s * 0.2f, center.y - s * 0.46f),
        Size(s * 0.22f, s * 0.4f), CornerRadius(s * 0.09f, s * 0.09f),
    )
    drawLine(tint.darken(0.2f), Offset(center.x - s * 0.28f, center.y + s * 0.2f), Offset(center.x - s * 0.3f, center.y + s * 0.5f), strokeWidth = s * 0.1f)
    drawLine(tint.darken(0.2f), Offset(center.x + s * 0.22f, center.y + s * 0.2f), Offset(center.x + s * 0.26f, center.y + s * 0.5f), strokeWidth = s * 0.1f)
    drawLine(tint.lighten(0.2f), Offset(center.x - s * 0.44f, center.y - s * 0.06f), Offset(center.x - s * 0.6f, center.y + s * 0.12f), strokeWidth = s * 0.08f)
}
