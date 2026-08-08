package com.robesthud.tribesera.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CenterFocusStrong
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.robesthud.tribesera.engine.Balance
import com.robesthud.tribesera.engine.GameState
import com.robesthud.tribesera.engine.MoveKind
import com.robesthud.tribesera.engine.Oasis
import com.robesthud.tribesera.engine.RES
import com.robesthud.tribesera.engine.Village
import com.robesthud.tribesera.engine.dist
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.art.IsoGrid
import com.robesthud.tribesera.ui.art.darken
import com.robesthud.tribesera.ui.art.diamondPath
import com.robesthud.tribesera.ui.art.drawConifer
import com.robesthud.tribesera.ui.art.drawTile
import com.robesthud.tribesera.ui.art.lighten
import com.robesthud.tribesera.ui.art.mix
import com.robesthud.tribesera.ui.art.poly
import com.robesthud.tribesera.ui.theme.Pal
import kotlin.math.abs
import kotlin.math.roundToInt

@Composable
fun MapScreen(vm: GameViewModel, g: GameState, home: Village) {
    var scale by remember { mutableFloatStateOf(1f) }
    var pan by remember { mutableStateOf(Offset.Zero) }
    var target by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var sendKind by remember { mutableStateOf<MoveKind?>(null) }
    val measurer = rememberTextMeasurer()
    // Счётчик «вернуться к своим»: меняется по кнопке и заново запускает
    // центрирование, даже если координаты фокуса остались прежними.
    var recenter by remember { mutableIntStateOf(0) }

    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF0D1A20), Color(0xFF0A1418)))),
    ) {
        val wPx = with(androidx.compose.ui.platform.LocalDensity.current) { maxWidth.toPx() }
        val hPx = with(androidx.compose.ui.platform.LocalDensity.current) { maxHeight.toPx() }
        val baseTile = 74f

        // Центрируемся на столице при первом открытии, по кнопке и по запросу
        // из других экранов.
        LaunchedEffect(vm.mapFocus, home.id, recenter, wPx, hPx) {
            if (wPx <= 0f || hPx <= 0f) return@LaunchedEffect
            val focus = vm.mapFocus ?: (home.x to home.y)
            val g0 = IsoGrid(
                Balance.MAP_SIZE, Balance.MAP_SIZE, 0f, 0f,
                baseTile * scale, baseTile * 0.56f * scale,
            )
            val c = g0.center(focus.first.toFloat(), focus.second.toFloat())
            pan = Offset(wPx / 2f - c.x, hPx / 2f - c.y)
            vm.mapFocus = null
        }

        Canvas(
            Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    detectTransformGestures { _, drag, zoom, _ ->
                        val newScale = (scale * zoom).coerceIn(0.55f, 2.2f)
                        pan += drag
                        scale = newScale
                    }
                }
                .pointerInput(Unit) {
                    detectTapGestures { p ->
                        val grid = IsoGrid(
                            Balance.MAP_SIZE, Balance.MAP_SIZE,
                            pan.x, pan.y, baseTile * scale, baseTile * 0.56f * scale,
                        )
                        val (cx, cy) = grid.cellAt(p)
                        if (cx in 0 until Balance.MAP_SIZE && cy in 0 until Balance.MAP_SIZE) {
                            target = cx to cy
                        }
                    }
                },
        ) {
            val grid = IsoGrid(
                Balance.MAP_SIZE, Balance.MAP_SIZE,
                pan.x, pan.y, baseTile * scale, baseTile * 0.56f * scale,
            )
            drawWorldMap(g, grid, target, measurer, scale)
        }

        // Кнопка «к своей столице».
        Box(
            Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp)
                .size(46.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Pal.surfaceHi)
                .clickable { recenter++ },
            contentAlignment = Alignment.Center,
        ) {
            androidx.compose.material3.Icon(
                Icons.Filled.CenterFocusStrong, null,
                tint = Pal.gold, modifier = Modifier.size(22.dp),
            )
        }

        MapLegend(Modifier.align(Alignment.TopStart).padding(10.dp))
    }

    val t = target
    if (t != null && sendKind == null) {
        TargetSheet(
            vm, g, home, t.first, t.second,
            onClose = { target = null },
            onSend = { kind -> sendKind = kind },
        )
    }
    if (t != null && sendKind != null) {
        SendSheet(
            vm, g, home, t.first, t.second, sendKind!!,
            onClose = { sendKind = null; target = null },
        )
    }
}

@Composable
private fun MapLegend(modifier: Modifier) {
    Row(
        modifier
            .background(Color(0x99101B16), RoundedCornerShape(12.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(9.dp).clip(RoundedCornerShape(5.dp)).background(Pal.player(0)))
        Spacer(Modifier.width(5.dp))
        Text("свои", style = MaterialTheme.typography.labelSmall, color = Pal.textDim)
        Spacer(Modifier.width(12.dp))
        Box(Modifier.size(9.dp).clip(RoundedCornerShape(5.dp)).background(Pal.player(1)))
        Spacer(Modifier.width(5.dp))
        Text("соперники", style = MaterialTheme.typography.labelSmall, color = Pal.textDim)
        Spacer(Modifier.width(12.dp))
        Box(Modifier.size(9.dp).clip(RoundedCornerShape(5.dp)).background(Pal.jade.darken(0.2f)))
        Spacer(Modifier.width(5.dp))
        Text("оазисы", style = MaterialTheme.typography.labelSmall, color = Pal.textDim)
    }
}

// --------------------------------------------------------------------------
// Отрисовка карты
// --------------------------------------------------------------------------

internal fun DrawScope.drawWorldMap(
    g: GameState,
    grid: IsoGrid,
    selected: Pair<Int, Int>?,
    measurer: TextMeasurer,
    scale: Float,
) {
    val tw = grid.tileW
    val th = grid.tileH

    // Рисуем только то, что попадает на экран.
    for (gy in 0 until Balance.MAP_SIZE) {
        for (gx in 0 until Balance.MAP_SIZE) {
            val c = grid.center(gx.toFloat(), gy.toFloat())
            if (c.x < -tw || c.x > size.width + tw || c.y < -th * 3 || c.y > size.height + th * 3) continue

            val oasis = g.oasisAt(gx, gy)
            val village = g.villageAt(gx, gy)
            val h = ((gx * 31 + gy * 17) % 7)
            val ground = when {
                oasis != null -> Pal.grass.lighten(0.12f)
                village != null -> Pal.dirt.mix(Pal.grass, 0.4f)
                h < 2 -> Pal.grass.darken(0.12f)
                h < 5 -> Pal.grass.darken(0.04f)
                else -> Pal.grass.mix(Pal.crop, 0.18f).darken(0.08f)
            }
            drawTile(c, tw * 0.97f, th * 0.97f, ground, ground.darken(0.42f), depth = th * 0.16f)

            if (oasis != null) drawOasisMarker(c, tw, th, oasis)
            if (village != null) drawVillageMarker(g, c, tw, th, village, measurer, scale)
            else if (oasis == null && h == 3) drawConifer(Offset(c.x, c.y + th * 0.1f), th * 0.5f, Pal.grass.darken(0.2f))

            if (selected != null && selected.first == gx && selected.second == gy) {
                drawPath(diamondPath(c, tw, th), Pal.gold, style = Stroke(width = 3f))
            }
        }
    }

    // Свои походы: линия от источника к цели и метка на текущей позиции.
    for (m in g.movements) {
        if (m.ownerId != 0) continue
        val from = g.village(m.fromVillage) ?: continue
        val a = grid.center(from.x.toFloat(), from.y.toFloat())
        val b = grid.center(m.tx.toFloat(), m.ty.toFloat())
        val tone = when (m.kind) {
            MoveKind.RETURN -> Pal.jade
            MoveKind.REINFORCE -> Pal.player(4)
            MoveKind.SETTLE -> Pal.gold
            else -> Pal.danger
        }
        drawLine(tone.copy(alpha = 0.5f), a, b, strokeWidth = 2f)
        val p = m.progress(g.time).toFloat()
        val pos = Offset(a.x + (b.x - a.x) * p, a.y + (b.y - a.y) * p)
        drawCircle(tone, th * 0.16f, pos)
        drawCircle(Color.White.copy(alpha = 0.7f), th * 0.06f, pos)
    }

    // Чужие атаки, летящие в наши деревни.
    for (m in g.movements) {
        if (m.ownerId == 0) continue
        if (m.kind != MoveKind.ATTACK && m.kind != MoveKind.RAID) continue
        val tv = g.village(m.targetVillage) ?: continue
        if (tv.ownerId != 0) continue
        val from = g.village(m.fromVillage) ?: continue
        val a = grid.center(from.x.toFloat(), from.y.toFloat())
        val b = grid.center(tv.x.toFloat(), tv.y.toFloat())
        val p = m.progress(g.time).toFloat()
        val pos = Offset(a.x + (b.x - a.x) * p, a.y + (b.y - a.y) * p)
        drawLine(Pal.danger.copy(alpha = 0.35f), a, b, strokeWidth = 2f)
        drawCircle(Pal.danger, th * 0.18f, pos)
    }
}

private fun DrawScope.drawOasisMarker(c: Offset, tw: Float, th: Float, o: Oasis) {
    drawCircle(Pal.water.copy(alpha = 0.55f), th * 0.26f, Offset(c.x, c.y + th * 0.05f))
    drawConifer(Offset(c.x - tw * 0.16f, c.y + th * 0.12f), th * 0.62f, Pal.grass.lighten(0.18f))
    drawConifer(Offset(c.x + tw * 0.14f, c.y + th * 0.2f), th * 0.5f, Pal.grass.lighten(0.08f))
    // Точка ресурса, который усиливает оазис.
    drawCircle(Pal.res(o.res), th * 0.12f, Offset(c.x + tw * 0.24f, c.y - th * 0.28f))
    if (o.res2 >= 0) drawCircle(Pal.res(o.res2), th * 0.1f, Offset(c.x + tw * 0.34f, c.y - th * 0.14f))
    if (o.ownerVillage >= 0) {
        drawPath(diamondPath(c, tw * 0.9f, th * 0.9f), Pal.jade.copy(alpha = 0.8f), style = Stroke(width = 2f))
    }
}

private fun DrawScope.drawVillageMarker(
    g: GameState,
    c: Offset,
    tw: Float,
    th: Float,
    v: Village,
    measurer: TextMeasurer,
    scale: Float,
) {
    val owner = g.playerOrNull(v.ownerId)
    val tone = Pal.player(owner?.colorIndex ?: 1)
    val s = th * 0.9f
    val baseY = c.y + th * 0.16f

    // Домик
    drawRect(Color(0xFFD8C49A), Offset(c.x - s * 0.3f, baseY - s * 0.42f), androidx.compose.ui.geometry.Size(s * 0.6f, s * 0.42f))
    drawPath(
        poly(
            Offset(c.x - s * 0.44f, baseY - s * 0.42f),
            Offset(c.x, baseY - s * 0.8f),
            Offset(c.x + s * 0.44f, baseY - s * 0.42f),
        ),
        tone,
    )
    // Кольцо владельца
    drawPath(diamondPath(c, tw * 0.86f, th * 0.86f), tone.copy(alpha = 0.85f), style = Stroke(width = 2.2f))
    if (v.capital) {
        drawCircle(Pal.gold, th * 0.09f, Offset(c.x + tw * 0.28f, c.y - th * 0.3f))
    }

    if (scale > 0.8f) {
        val label = if (v.ownerId == 0) v.name else (owner?.name ?: "?")
        val layout = measurer.measure(
            label,
            style = TextStyle(
                fontSize = (11 * scale).coerceIn(10f, 15f).sp,
                fontWeight = FontWeight.SemiBold,
                color = Pal.text,
            ),
        )
        val pos = Offset(c.x - layout.size.width / 2f, baseY + th * 0.14f)
        // Подложка: без неё светлый текст теряется на светлой траве.
        drawRoundRect(
            color = Color(0xB3081310),
            topLeft = Offset(pos.x - 5f, pos.y - 2f),
            size = androidx.compose.ui.geometry.Size(
                layout.size.width + 10f,
                layout.size.height + 4f,
            ),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(6f, 6f),
        )
        drawText(layout, topLeft = pos)
    }
}

/** Расстояние в клетках, округлённое для интерфейса. */
fun distanceLabel(from: Village, x: Int, y: Int): String =
    String.format("%.1f клеток", dist(from.x, from.y, x, y))

/** Модуль разницы координат — для подсказок о направлении. */
fun deltaLabel(from: Village, x: Int, y: Int): String {
    val dx = x - from.x
    val dy = y - from.y
    val h = if (dx >= 0) "восток" else "запад"
    val vlabel = if (dy >= 0) "юг" else "север"
    return "${abs(dx)} на $h, ${abs(dy)} на $vlabel"
}

/** Округление до целого — короткий помощник для подписей. */
fun r0(v: Double): String = v.roundToInt().toString()
