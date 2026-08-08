package com.robesthud.tribesera.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.Offset
import com.robesthud.tribesera.engine.Cost
import com.robesthud.tribesera.engine.RES
import com.robesthud.tribesera.engine.Res
import com.robesthud.tribesera.engine.formatAmount
import com.robesthud.tribesera.ui.art.drawResourceGlyph
import com.robesthud.tribesera.ui.theme.CardRadius
import com.robesthud.tribesera.ui.theme.ChipRadius
import com.robesthud.tribesera.ui.theme.Pal

/** Значок ресурса — рисуется вектором, одинаково чёткий на любом экране. */
@Composable
fun ResIcon(res: Res, size: androidx.compose.ui.unit.Dp = 16.dp, modifier: Modifier = Modifier) {
    Canvas(modifier.size(size)) {
        drawResourceGlyph(Offset(this.size.width / 2f, this.size.height / 2f), this.size.minDimension, res)
    }
}

@Composable
fun Panel(
    modifier: Modifier = Modifier,
    tone: Color = Pal.surface,
    border: Color = Pal.outlineSoft,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .clip(RoundedCornerShape(CardRadius))
            .background(tone)
            .border(BorderStroke(1.dp, border), RoundedCornerShape(CardRadius))
            .padding(14.dp),
        content = content,
    )
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        color = Pal.textFaint,
        modifier = modifier,
    )
}

/** Крупная кнопка действия с золотой заливкой. */
@Composable
fun ActionButton(
    text: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    tone: Color = Pal.gold,
    onClick: () -> Unit,
) {
    val bg = if (enabled) {
        Brush.horizontalGradient(listOf(tone, tone.copy(alpha = 0.82f)))
    } else {
        Brush.horizontalGradient(listOf(Pal.surfaceHi, Pal.surfaceHi))
    }
    Row(
        modifier
            .clip(RoundedCornerShape(ChipRadius))
            .background(bg)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = if (enabled) Color(0xFF201604) else Pal.textFaint, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(
            text,
            style = MaterialTheme.typography.labelLarge,
            color = if (enabled) Color(0xFF201604) else Pal.textFaint,
        )
    }
}

@Composable
fun GhostButton(
    text: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .clip(RoundedCornerShape(ChipRadius))
            .border(BorderStroke(1.dp, if (enabled) Pal.outline else Pal.outlineSoft), RoundedCornerShape(ChipRadius))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 11.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = if (enabled) Pal.text else Pal.textFaint, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(text, style = MaterialTheme.typography.labelLarge, color = if (enabled) Pal.text else Pal.textFaint)
    }
}

/** Цена в четырёх ресурсах; нехватка подсвечивается красным. */
@Composable
fun CostRow(cost: Cost, stock: List<Double>?, modifier: Modifier = Modifier, compact: Boolean = false) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(if (compact) 8.dp else 12.dp)) {
        for (r in RES) {
            val need = cost[r]
            if (need == 0 && compact) continue
            val enough = stock == null || stock[r.ordinal] >= need
            Row(verticalAlignment = Alignment.CenterVertically) {
                ResIcon(r, if (compact) 13.dp else 15.dp)
                Spacer(Modifier.width(3.dp))
                Text(
                    formatAmount(need.toDouble()),
                    style = if (compact) MaterialTheme.typography.bodySmall else MaterialTheme.typography.bodyMedium,
                    color = if (enough) Pal.text else Pal.danger,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

/** Строка «параметр — значение». */
@Composable
fun StatLine(label: String, value: String, valueColor: Color = Pal.text) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 3.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = Pal.textDim)
        Text(value, style = MaterialTheme.typography.bodyMedium, color = valueColor, fontWeight = FontWeight.SemiBold)
    }
}

/** Кружок с уровнем — вешается на постройки и поля. */
@Composable
fun LevelBadge(level: Int, tone: Color = Pal.gold, dim: Boolean = false) {
    Box(
        Modifier
            .size(22.dp)
            .clip(RoundedCornerShape(11.dp))
            .background(if (dim) Pal.surfaceHi.copy(alpha = 0.92f) else Color(0xE60E1A17))
            .border(BorderStroke(1.5.dp, tone), RoundedCornerShape(11.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            level.toString(),
            style = MaterialTheme.typography.labelSmall,
            color = if (dim) Pal.textDim else tone,
        )
    }
}

@Composable
fun ProgressBar(progress: Float, modifier: Modifier = Modifier, tone: Color = Pal.jade, track: Color = Pal.surfaceLo) {
    val animated by animateFloatAsState(progress.coerceIn(0f, 1f), label = "progress")
    LinearProgressIndicator(
        progress = { animated },
        modifier = modifier.height(6.dp).clip(RoundedCornerShape(3.dp)),
        color = tone,
        trackColor = track,
        strokeCap = androidx.compose.ui.graphics.StrokeCap.Round,
        gapSize = 0.dp,
        drawStopIndicator = {},
    )
}

/** Маленькая метка-«таблетка». */
@Composable
fun Tag(text: String, tone: Color = Pal.jade, modifier: Modifier = Modifier) {
    Text(
        text,
        style = MaterialTheme.typography.labelSmall,
        color = tone,
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(tone.copy(alpha = 0.14f))
            .padding(horizontal = 7.dp, vertical = 3.dp),
    )
}
