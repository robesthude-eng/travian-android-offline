package com.robesthud.tribesera.ui.art

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import com.robesthud.tribesera.ui.theme.Pal
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * Изометрия «два к одному»: клетка сетки превращается в ромб, а вся сцена —
 * в наклонную площадку. Всё рисуется векторами, без единой картинки.
 */
class IsoGrid(
    val cols: Int,
    val rows: Int,
    val originX: Float,
    val originY: Float,
    val tileW: Float,
    val tileH: Float,
) {
    fun center(gx: Float, gy: Float): Offset = Offset(
        originX + (gx - gy) * tileW / 2f,
        originY + (gx + gy) * tileH / 2f,
    )

    fun cellRect(gx: Int, gy: Int): Rect {
        val c = center(gx.toFloat(), gy.toFloat())
        return Rect(Offset(c.x - tileW / 2f, c.y - tileH / 2f), Size(tileW, tileH))
    }

    /** Обратное преобразование — для попадания пальцем по клетке. */
    fun cellAt(p: Offset): Pair<Int, Int> {
        val dx = p.x - originX
        val dy = p.y - originY
        val gx = (dx / tileW + dy / tileH)
        val gy = (dy / tileH - dx / tileW)
        return Math.round(gx) to Math.round(gy)
    }
}

fun diamondPath(center: Offset, w: Float, h: Float): Path = Path().apply {
    moveTo(center.x, center.y - h / 2f)
    lineTo(center.x + w / 2f, center.y)
    lineTo(center.x, center.y + h / 2f)
    lineTo(center.x - w / 2f, center.y)
    close()
}

/** Ромб-плитка с боковой «толщиной», чтобы земля выглядела объёмной. */
fun DrawScope.drawTile(
    center: Offset,
    w: Float,
    h: Float,
    top: Color,
    side: Color,
    depth: Float = h * 0.28f,
    outline: Color? = null,
) {
    if (depth > 0f) {
        val skirt = Path().apply {
            moveTo(center.x - w / 2f, center.y)
            lineTo(center.x, center.y + h / 2f)
            lineTo(center.x + w / 2f, center.y)
            lineTo(center.x + w / 2f, center.y + depth)
            lineTo(center.x, center.y + h / 2f + depth)
            lineTo(center.x - w / 2f, center.y + depth)
            close()
        }
        drawPath(skirt, side)
    }
    val top1 = diamondPath(center, w, h)
    drawPath(
        top1,
        Brush.linearGradient(
            listOf(top, top.mix(Color.Black, 0.18f)),
            start = Offset(center.x - w / 2f, center.y - h / 2f),
            end = Offset(center.x + w / 2f, center.y + h / 2f),
        ),
    )
    if (outline != null) drawPath(top1, outline, style = Stroke(width = 1.4f))
}

/** Мягкая тень под объектом. */
fun DrawScope.drawBlob(center: Offset, w: Float, h: Float, color: Color) {
    drawPath(diamondPath(center, w, h), color)
}

fun Color.mix(other: Color, t: Float): Color = Color(
    red = red + (other.red - red) * t,
    green = green + (other.green - green) * t,
    blue = blue + (other.blue - blue) * t,
    alpha = alpha + (other.alpha - alpha) * t,
)

fun Color.lighten(t: Float) = mix(Color.White, t)
fun Color.darken(t: Float) = mix(Color.Black, t)

/**
 * Многоугольник по точкам. Offset — value class, поэтому vararg недоступен:
 * вместо него перегрузки на три, четыре и пять вершин.
 */
fun poly(pts: List<Offset>): Path = Path().apply {
    moveTo(pts[0].x, pts[0].y)
    for (i in 1 until pts.size) lineTo(pts[i].x, pts[i].y)
    close()
}

fun poly(a: Offset, b: Offset, c: Offset): Path = poly(listOf(a, b, c))
fun poly(a: Offset, b: Offset, c: Offset, d: Offset): Path = poly(listOf(a, b, c, d))
fun poly(a: Offset, b: Offset, c: Offset, d: Offset, e: Offset): Path = poly(listOf(a, b, c, d, e))

fun DrawScope.fillPoly(path: Path, color: Color) = drawPath(path, color, style = Fill)

/** Хвойное дерево — базовый строительный блок пейзажа. */
fun DrawScope.drawConifer(base: Offset, height: Float, tint: Color = Pal.grass) {
    val w = height * 0.52f
    drawRect(
        color = Pal.dirtLo,
        topLeft = Offset(base.x - height * 0.05f, base.y - height * 0.18f),
        size = Size(height * 0.1f, height * 0.18f),
    )
    var y = base.y - height * 0.12f
    var layerW = w
    var i = 0
    while (i < 3) {
        val layerH = height * 0.34f
        val p = poly(
            Offset(base.x, y - layerH * 1.35f),
            Offset(base.x + layerW / 2f, y),
            Offset(base.x - layerW / 2f, y),
        )
        fillPoly(p, tint.darken(0.12f * (2 - i)))
        y -= layerH * 0.62f
        layerW *= 0.76f
        i++
    }
}

/** Лиственное дерево — округлая крона из трёх кругов. */
fun DrawScope.drawBush(base: Offset, size: Float, tint: Color) {
    drawCircle(tint.darken(0.15f), size * 0.42f, Offset(base.x - size * 0.22f, base.y - size * 0.3f))
    drawCircle(tint, size * 0.46f, Offset(base.x + size * 0.18f, base.y - size * 0.36f))
    drawCircle(tint.lighten(0.1f), size * 0.34f, Offset(base.x, base.y - size * 0.62f))
}

/** Камень с бликом. */
fun DrawScope.drawRock(center: Offset, size: Float, tint: Color = Pal.stone) {
    val p = poly(
        Offset(center.x - size * 0.5f, center.y + size * 0.28f),
        Offset(center.x - size * 0.32f, center.y - size * 0.18f),
        Offset(center.x + size * 0.06f, center.y - size * 0.42f),
        Offset(center.x + size * 0.46f, center.y - size * 0.06f),
        Offset(center.x + size * 0.38f, center.y + size * 0.3f),
    )
    fillPoly(p, tint)
    val hi = poly(
        Offset(center.x - size * 0.32f, center.y - size * 0.18f),
        Offset(center.x + size * 0.06f, center.y - size * 0.42f),
        Offset(center.x + size * 0.02f, center.y - size * 0.02f),
    )
    fillPoly(hi, tint.lighten(0.22f))
}

/** Флажок на древке — им помечаются штабные постройки. */
fun DrawScope.drawBanner(base: Offset, height: Float, color: Color) {
    drawLine(
        Pal.dirtLo,
        Offset(base.x, base.y),
        Offset(base.x, base.y - height),
        strokeWidth = height * 0.07f,
    )
    val f = poly(
        Offset(base.x, base.y - height),
        Offset(base.x + height * 0.42f, base.y - height * 0.86f),
        Offset(base.x, base.y - height * 0.66f),
    )
    fillPoly(f, color)
}

/** Точка на окружности — вспомогательное для радиальных раскладок. */
fun ring(center: Offset, radius: Float, angle: Float): Offset =
    Offset(center.x + cos(angle) * radius, center.y + sin(angle) * radius)

/**
 * Задник для изометрических площадок: гряды холмов и перелески.
 *
 * Ромб на портретном экране физически не может занять весь кадр — его высота
 * жёстко связана с шириной. Поэтому пустое место вокруг не оставляют пустым,
 * а превращают в долину, в которой стоит деревня.
 */
fun DrawScope.drawValleyBackdrop(seed: Int = 0) {
    val w = size.width
    val h = size.height
    val rnd = Random(seed * 104729 + 17)

    // Дальняя гряда — самая тёмная и размытая.
    drawPath(
        hillPath(w, h * 0.30f, h * 0.10f, 3, rnd),
        Pal.grassLo.darken(0.52f),
    )
    drawPath(
        hillPath(w, h * 0.38f, h * 0.09f, 4, rnd),
        Pal.grassLo.darken(0.40f),
    )
    // Ближняя гряда, на которой уже различимы деревья.
    drawPath(
        hillPath(w, h * 0.46f, h * 0.07f, 5, rnd),
        Pal.grassLo.darken(0.30f),
    )
    repeat(14) {
        val x = rnd.nextFloat() * w
        val y = h * (0.40f + rnd.nextFloat() * 0.08f)
        drawConifer(Offset(x, y), h * (0.030f + rnd.nextFloat() * 0.022f), Pal.grass.darken(0.42f))
    }
    // Передний план: трава у нижней кромки и редкие деревья по углам.
    drawPath(
        hillPath(w, h * 1.02f, h * 0.05f, 4, rnd),
        Pal.grassLo.darken(0.34f),
    )
    repeat(8) {
        val left = rnd.nextBoolean()
        val x = if (left) rnd.nextFloat() * w * 0.16f else w - rnd.nextFloat() * w * 0.16f
        val y = h * (0.62f + rnd.nextFloat() * 0.32f)
        drawConifer(Offset(x, y), h * (0.045f + rnd.nextFloat() * 0.03f), Pal.grass.darken(0.30f))
    }
}

/** Волнистая линия холмов: базовая высота плюс несколько горбов. */
private fun hillPath(w: Float, baseY: Float, amp: Float, humps: Int, rnd: Random): Path {
    val p = Path()
    p.moveTo(0f, baseY + amp)
    var x = 0f
    val step = w / humps
    var up = true
    while (x < w) {
        val next = x + step
        val peak = baseY - amp * (if (up) 1.0f else 0.45f) * (0.6f + rnd.nextFloat() * 0.7f)
        p.cubicTo(x + step * 0.35f, peak, x + step * 0.65f, peak, next, baseY + amp * 0.25f)
        x = next
        up = !up
    }
    p.lineTo(w, baseY + amp * 4f)
    p.lineTo(0f, baseY + amp * 4f)
    p.close()
    return p
}
