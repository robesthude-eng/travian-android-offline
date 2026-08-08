package com.robesthud.tribesera.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.robesthud.tribesera.engine.Balance
import com.robesthud.tribesera.engine.Denied
import com.robesthud.tribesera.engine.Engine
import com.robesthud.tribesera.engine.GameState
import com.robesthud.tribesera.engine.RES
import com.robesthud.tribesera.engine.Res
import com.robesthud.tribesera.engine.Village
import com.robesthud.tribesera.engine.formatDuration
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.art.drawBanner
import com.robesthud.tribesera.ui.art.drawBush
import com.robesthud.tribesera.ui.art.drawResourceField
import com.robesthud.tribesera.ui.art.drawTile
import com.robesthud.tribesera.ui.art.drawValleyBackdrop
import com.robesthud.tribesera.ui.art.lighten
import com.robesthud.tribesera.ui.art.darken
import com.robesthud.tribesera.ui.art.mix
import com.robesthud.tribesera.ui.art.poly
import com.robesthud.tribesera.ui.components.ActionButton
import com.robesthud.tribesera.ui.components.BuildQueueStrip
import com.robesthud.tribesera.ui.components.CostRow
import com.robesthud.tribesera.ui.components.LevelBadge
import com.robesthud.tribesera.ui.components.ResIcon
import com.robesthud.tribesera.ui.components.SectionTitle
import com.robesthud.tribesera.ui.components.StatLine
import com.robesthud.tribesera.ui.components.Tag
import com.robesthud.tribesera.ui.theme.Pal
import kotlin.math.roundToInt

fun fieldTitle(r: Res): String = when (r) {
    Res.WOOD -> "Лесопилка"
    Res.CLAY -> "Глиняный карьер"
    Res.IRON -> "Железный рудник"
    Res.CROP -> "Зерновое поле"
}

@Composable
fun FieldsScreen(vm: GameViewModel, g: GameState, v: Village) {
    var selected by remember { mutableIntStateOf(-1) }

    Column(Modifier.fillMaxSize()) {
        BuildQueueStrip(vm, v)
        BoxWithConstraints(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(Color(0xFF16281F), Color(0xFF102019), Color(0xFF0C1713)),
                    ),
                ),
        ) {
            val density = LocalDensity.current
            val wPx = with(density) { maxWidth.toPx() }
            val hPx = with(density) { maxHeight.toPx() }
            val layout = remember(wPx, hPx) {
                buildBoard(5, 4, wPx, hPx, exclude = setOf(2 to 1, 2 to 2), topPad = 0.26f, scale = 0.97f)
            }
            val badgePx = with(density) { 22.dp.toPx() }

            Canvas(
                Modifier
                    .fillMaxSize()
                    .pointerInput(layout) {
                        detectTapGestures { p ->
                            val i = layout.hit(p)
                            if (i >= 0) selected = i
                        }
                    },
            ) {
                drawFieldScene(layout, v, selected)
            }

            layout.cells.indices.forEach { i ->
                if (i >= v.fieldLevel.size) return@forEach
                val c = layout.centerOf(i)
                Box(
                    Modifier.offset {
                        IntOffset(
                            (c.x - badgePx / 2f).roundToInt(),
                            (c.y + layout.tileH * 0.16f).roundToInt(),
                        )
                    },
                ) {
                    LevelBadge(v.fieldLevel[i], tone = Pal.res(v.fieldType[i]))
                }
            }

            OutputSummary(
                g, v,
                Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 8.dp),
            )
        }
    }

    if (selected >= 0) {
        FieldSheet(vm, g, v, selected) { selected = -1 }
    }
}

/** Сводка «сколько и чего капает» — прямо над полями. */
@Composable
private fun OutputSummary(g: GameState, v: Village, modifier: Modifier = Modifier) {
    Row(
        modifier
            .background(Color(0x99101B16), androidx.compose.foundation.shape.RoundedCornerShape(14.dp))
            .padding(horizontal = 12.dp, vertical = 7.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        for (r in RES) {
            val rate = g.netOutput(v, r)
            Row(verticalAlignment = Alignment.CenterVertically) {
                ResIcon(r, 14.dp)
                Spacer(Modifier.padding(horizontal = 2.dp))
                Text(
                    String.format("%.1f/с", rate),
                    style = MaterialTheme.typography.labelMedium,
                    color = if (rate < 0) Pal.danger else Pal.textDim,
                )
            }
        }
    }
}

// --------------------------------------------------------------------------
// Отрисовка сцены
// --------------------------------------------------------------------------

internal fun DrawScope.drawFieldScene(layout: BoardLayout, v: Village, selected: Int) {
    drawValleyBackdrop(seed = 7)

    val order = layout.drawOrder()
    for (i in order) {
        if (i >= v.fieldLevel.size) continue
        val c = layout.centerOf(i)
        drawResourceField(
            center = c,
            w = layout.tileW,
            h = layout.tileH,
            res = RES[v.fieldType[i]],
            level = v.fieldLevel[i],
            selected = i == selected,
            seed = i,
        )
    }

    // Деревня в центре площадки — на двух зарезервированных клетках.
    val a = layout.grid.center(2f, 1f)
    val b = layout.grid.center(2f, 2f)
    val hub = Offset((a.x + b.x) / 2f, (a.y + b.y) / 2f)
    drawTile(hub, layout.tileW * 1.25f, layout.tileH * 1.5f, Pal.dirt.mix(Pal.grass, 0.3f), Pal.dirtLo, depth = layout.tileH * 0.18f)
    drawVillageCluster(hub, layout.tileW * 0.72f)
}

private fun DrawScope.drawVillageCluster(center: Offset, s: Float) {
    fun hut(cx: Float, baseY: Float, w: Float, wall: Color, roof: Color) {
        val wallH = w * 0.5f
        drawRect(wall, Offset(cx - w / 2f, baseY - wallH), androidx.compose.ui.geometry.Size(w, wallH))
        drawPath(
            poly(
                Offset(cx - w * 0.62f, baseY - wallH),
                Offset(cx, baseY - wallH - w * 0.42f),
                Offset(cx + w * 0.62f, baseY - wallH),
            ),
            roof,
        )
    }
    drawBush(Offset(center.x - s * 0.7f, center.y + s * 0.18f), s * 0.4f, Pal.grass.lighten(0.05f))
    // Порядок строго от дальнего к ближнему: иначе большой дом в центре
    // закрывает крыши боковых изб и они превращаются в голые прямоугольники.
    hut(center.x, center.y - s * 0.06f, s * 0.52f, Color(0xFFE0CFA6), Color(0xFFB44A38))
    hut(center.x - s * 0.34f, center.y + s * 0.1f, s * 0.42f, Color(0xFFCBB68C), Color(0xFF9E5A3E))
    hut(center.x + s * 0.3f, center.y + s * 0.16f, s * 0.38f, Color(0xFFBFA87E), Color(0xFF8B4F36))
    drawBanner(Offset(center.x + s * 0.6f, center.y + s * 0.06f), s * 0.55f, Pal.gold)
}

// --------------------------------------------------------------------------
// Карточка поля
// --------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FieldSheet(vm: GameViewModel, g: GameState, v: Village, slot: Int, onClose: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val res = RES[v.fieldType[slot]]
    val level = v.fieldLevel[slot]
    val next = Engine.fieldNextLevel(v, slot)
    val queued = next - 1 > level
    val cost = Balance.fieldCost(res, next - 1)
    val time = Balance.fieldTime(next - 1) / Balance.buildSpeedup(v.level(com.robesthud.tribesera.engine.BuildingType.MAIN))
    val check = Engine.canUpgradeField(g, v, slot)

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                ResIcon(res, 26.dp)
                Spacer(Modifier.padding(horizontal = 5.dp))
                Column {
                    Text(fieldTitle(res), style = MaterialTheme.typography.headlineSmall, color = Pal.text)
                    Text("Уровень $level из ${Balance.MAX_FIELD_LEVEL}", style = MaterialTheme.typography.bodySmall, color = Pal.textDim)
                }
                Spacer(Modifier.weight(1f))
                if (queued) Tag("в очереди", Pal.gold)
            }
            Spacer(Modifier.height(16.dp))

            SectionTitle("Добыча")
            Spacer(Modifier.height(6.dp))
            StatLine("Сейчас", String.format("%.2f/с", Balance.fieldOutput(level)))
            if (next <= Balance.MAX_FIELD_LEVEL) {
                StatLine(
                    "После улучшения",
                    String.format("%.2f/с", Balance.fieldOutput(next)),
                    Pal.jade,
                )
            }
            StatLine("Всего по деревне", String.format("%.1f/с", g.netOutput(v, res)))

            Spacer(Modifier.height(16.dp))
            if (next <= Balance.MAX_FIELD_LEVEL) {
                SectionTitle("Стоимость улучшения до $next ур.")
                Spacer(Modifier.height(8.dp))
                CostRow(cost, v.stock)
                Spacer(Modifier.height(6.dp))
                Text("Время: ${formatDuration(time)}", style = MaterialTheme.typography.bodySmall, color = Pal.textDim)
                Spacer(Modifier.height(16.dp))
                ActionButton(
                    text = if (check.ok) "Улучшить до $next уровня" else check.reason,
                    enabled = check.ok,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    val r: Denied = Engine.upgradeField(g, v, slot)
                    vm.report(r)
                    if (r.ok) onClose()
                }
            } else {
                Text("Поле развито до предела.", style = MaterialTheme.typography.bodyMedium, color = Pal.gold)
            }
        }
    }
}
