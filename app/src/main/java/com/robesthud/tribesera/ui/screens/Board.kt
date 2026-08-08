package com.robesthud.tribesera.ui.screens

import androidx.compose.ui.geometry.Offset
import com.robesthud.tribesera.ui.art.IsoGrid
import kotlin.math.min

/**
 * Раскладка изометрической площадки: сколько клеток, какого они размера и
 * где на экране. Одна и та же математика обслуживает и поля, и деревню.
 */
class BoardLayout(
    val grid: IsoGrid,
    val cells: List<Pair<Int, Int>>,
    val tileW: Float,
    val tileH: Float,
) {
    fun centerOf(index: Int): Offset {
        val (gx, gy) = cells[index]
        return grid.center(gx.toFloat(), gy.toFloat())
    }

    /** Ближайшая занятая клетка к точке касания, или -1. */
    fun hit(p: Offset): Int {
        var best = -1
        var bestD = Float.MAX_VALUE
        for (i in cells.indices) {
            val c = centerOf(i)
            // Расстояние в «ромбической» метрике: точнее прямоугольной проверки.
            val dx = kotlin.math.abs(p.x - c.x) / (tileW / 2f)
            val dy = kotlin.math.abs(p.y - c.y) / (tileH / 2f)
            val d = dx + dy
            if (d < bestD) {
                bestD = d
                best = i
            }
        }
        return if (bestD <= 1.35f) best else -1
    }
}

/**
 * @param exclude клетки, отданные под центральный объект (деревню или площадь).
 * @param topPad запас сверху: постройки рисуются вверх от плитки.
 */
fun buildBoard(
    cols: Int,
    rows: Int,
    widthPx: Float,
    heightPx: Float,
    exclude: Set<Pair<Int, Int>> = emptySet(),
    topPad: Float = 0.32f,
    scale: Float = 1f,
    /**
     * Сплющенность плитки. Классические 0.5 дают слишком плоский ромб: на
     * портретном экране он занимает узкую полосу посередине. 0.7 сохраняет
     * изометрию, но заполняет кадр заметно лучше.
     */
    ratio: Float = 0.7f,
): BoardLayout {
    val span = (cols + rows) / 2f
    val usableH = heightPx / (1f + topPad)
    val tileW = min(widthPx / span, usableH / (span * ratio)) * scale
    val tileH = tileW * ratio

    val minX = (0 - (rows - 1)) * tileW / 2f
    val maxX = (cols - 1) * tileW / 2f
    val minY = 0f
    val maxY = (cols - 1 + rows - 1) * tileH / 2f

    val originX = widthPx / 2f - (minX + maxX) / 2f
    val originY = heightPx / 2f - (minY + maxY) / 2f + heightPx * topPad * 0.22f

    val cells = buildList {
        for (gy in 0 until rows) {
            for (gx in 0 until cols) {
                if ((gx to gy) in exclude) continue
                add(gx to gy)
            }
        }
    }
    return BoardLayout(IsoGrid(cols, rows, originX, originY, tileW, tileH), cells, tileW, tileH)
}

/** Порядок отрисовки: дальние клетки первыми, иначе постройки перекроются. */
fun BoardLayout.drawOrder(): List<Int> =
    cells.indices.sortedBy { cells[it].first + cells[it].second }
