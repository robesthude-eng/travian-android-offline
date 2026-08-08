package com.robesthud.tribesera.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.robesthud.tribesera.engine.Balance
import com.robesthud.tribesera.engine.BuildCategory
import com.robesthud.tribesera.engine.BuildingType
import com.robesthud.tribesera.engine.Engine
import com.robesthud.tribesera.engine.GameState
import com.robesthud.tribesera.engine.Village
import com.robesthud.tribesera.engine.formatDuration
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.art.diamondPath
import com.robesthud.tribesera.ui.art.darken
import com.robesthud.tribesera.ui.art.drawBuilding
import com.robesthud.tribesera.ui.art.drawBush
import com.robesthud.tribesera.ui.art.drawEmptyPlot
import com.robesthud.tribesera.ui.art.drawTile
import com.robesthud.tribesera.ui.art.drawValleyBackdrop
import com.robesthud.tribesera.ui.art.lighten
import com.robesthud.tribesera.ui.art.mix
import com.robesthud.tribesera.ui.art.poly
import com.robesthud.tribesera.ui.components.ActionButton
import com.robesthud.tribesera.ui.components.BuildQueueStrip
import com.robesthud.tribesera.ui.components.CostRow
import com.robesthud.tribesera.ui.components.GhostButton
import com.robesthud.tribesera.ui.components.LevelBadge
import com.robesthud.tribesera.ui.components.SectionTitle
import com.robesthud.tribesera.ui.components.StatLine
import com.robesthud.tribesera.ui.components.Tag
import com.robesthud.tribesera.ui.components.TrainQueueStrip
import com.robesthud.tribesera.ui.theme.Pal
import kotlin.math.roundToInt

/** Что открылось поверх карточки здания. */
private enum class SubSheet { NONE, TRAIN, MARKET, ARMY }

@Composable
fun VillageScreen(vm: GameViewModel, g: GameState, v: Village) {
    var openSlot by remember { mutableIntStateOf(-1) }
    var buildMenuSlot by remember { mutableIntStateOf(-1) }
    var sub by remember { mutableStateOf(SubSheet.NONE) }

    Column(Modifier.fillMaxSize()) {
        BuildQueueStrip(vm, v)
        TrainQueueStrip(vm, v)
        BoxWithConstraints(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(listOf(Color(0xFF1A2C22), Color(0xFF122019), Color(0xFF0B1512))),
                ),
        ) {
            val density = LocalDensity.current
            val wPx = with(density) { maxWidth.toPx() }
            val hPx = with(density) { maxHeight.toPx() }
            val layout = remember(wPx, hPx) {
                buildBoard(5, 4, wPx, hPx, exclude = setOf(2 to 1, 2 to 2), topPad = 0.30f, scale = 0.96f)
            }
            val badgePx = with(density) { 22.dp.toPx() }

            Canvas(
                Modifier
                    .fillMaxSize()
                    .pointerInput(layout) {
                        detectTapGestures { p ->
                            val i = layout.hit(p)
                            if (i < 0 || i >= Balance.BUILD_SLOTS) return@detectTapGestures
                            if (v.slotType[i] >= 0) openSlot = i else buildMenuSlot = i
                        }
                    },
            ) {
                drawVillageScene(layout, v, openSlot)
            }

            for (i in 0 until Balance.BUILD_SLOTS) {
                if (v.slotType[i] < 0) continue
                val c = layout.centerOf(i)
                Box(
                    Modifier.offset {
                        IntOffset(
                            (c.x - badgePx / 2f).roundToInt(),
                            (c.y + layout.tileH * 0.18f).roundToInt(),
                        )
                    },
                ) {
                    LevelBadge(v.slotLevel[i], tone = if (v.slotLevel[i] == 0) Pal.textFaint else Pal.gold)
                }
            }

            VillageHud(g, v, Modifier.align(Alignment.TopStart).padding(10.dp))
        }
    }

    if (openSlot >= 0) {
        BuildingSheet(
            vm, g, v, openSlot,
            onClose = { openSlot = -1; sub = SubSheet.NONE },
            onSub = { sub = it },
        )
    }
    if (buildMenuSlot >= 0) {
        BuildMenuSheet(vm, g, v, buildMenuSlot) { buildMenuSlot = -1 }
    }
    when (sub) {
        SubSheet.TRAIN -> TrainSheet(vm, g, v) { sub = SubSheet.NONE }
        SubSheet.MARKET -> MarketSheet(vm, g, v) { sub = SubSheet.NONE }
        SubSheet.ARMY -> ArmySheet(vm, g, v) { sub = SubSheet.NONE }
        SubSheet.NONE -> Unit
    }
}

@Composable
private fun VillageHud(g: GameState, v: Village, modifier: Modifier) {
    val incoming = Engine.incoming(g, v)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Row(
            Modifier
                .background(Color(0x99101B16), RoundedCornerShape(12.dp))
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Лояльность ", style = MaterialTheme.typography.labelSmall, color = Pal.textFaint)
            Text(
                "${v.loyalty.roundToInt()}%",
                style = MaterialTheme.typography.labelMedium,
                color = if (v.loyalty < 60) Pal.danger else Pal.jade,
            )
        }
        if (incoming.isNotEmpty()) {
            val soonest = incoming.minByOrNull { it.arrive }!!
            Row(
                Modifier
                    .background(Pal.danger.copy(alpha = 0.22f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Атака через ${formatDuration(soonest.arrive - g.time)}",
                    style = MaterialTheme.typography.labelMedium,
                    color = Pal.danger,
                )
            }
        }
    }
}

// --------------------------------------------------------------------------
// Сцена деревни
// --------------------------------------------------------------------------

internal fun DrawScope.drawVillageScene(layout: BoardLayout, v: Village, selected: Int) {
    drawValleyBackdrop(seed = 3)

    val wallLevel = v.slotLevel.getOrElse(Balance.SLOT_WALL) { 0 }
    if (wallLevel > 0) drawWallRing(layout, wallLevel)

    // Площадь с колодцем на двух центральных клетках.
    val a = layout.grid.center(2f, 1f)
    val b = layout.grid.center(2f, 2f)
    val hub = Offset((a.x + b.x) / 2f, (a.y + b.y) / 2f)
    drawTile(hub, layout.tileW * 1.5f, layout.tileH * 1.9f, Pal.stoneLo.mix(Pal.dirt, 0.4f), Pal.dirtLo, depth = layout.tileH * 0.18f)
    drawWell(hub, layout.tileW * 0.34f)

    for (i in layout.drawOrder()) {
        if (i >= Balance.BUILD_SLOTS) continue
        val c = layout.centerOf(i)
        val typeIdx = v.slotType[i]
        if (typeIdx < 0) {
            drawEmptyPlot(c, layout.tileW, layout.tileH, i == selected)
        } else {
            drawBuilding(
                BuildingType.entries[typeIdx],
                c,
                layout.tileW,
                layout.tileH,
                v.slotLevel[i],
                i == selected,
            )
        }
    }
}

/** Частокол по периметру площадки — растёт вместе с уровнем стены. */
private fun DrawScope.drawWallRing(layout: BoardLayout, level: Int) {
    // Кольцо описывает всю площадку: центр — середина сетки, размер — её
    // диагональ плюс небольшой отступ под саму стену.
    val center = layout.grid.center(
        (layout.grid.cols - 1) / 2f,
        (layout.grid.rows - 1) / 2f,
    )
    val cx = center.x
    val cy = center.y
    val span = (layout.grid.cols + layout.grid.rows) / 2f + 0.3f
    val w = layout.tileW * span
    val h = layout.tileH * span
    val stroke = (2f + level * 0.45f).coerceAtMost(9f)
    drawPath(
        diamondPath(Offset(cx, cy), w, h),
        Pal.dirtLo.lighten(0.06f),
        style = Stroke(width = stroke + 4f),
    )
    drawPath(
        diamondPath(Offset(cx, cy), w, h),
        Color(0xFF9A7B52).darken(if (level > 10) 0.0f else 0.15f),
        style = Stroke(width = stroke),
    )
    // Башенки по углам появляются на высоких уровнях.
    if (level >= 6) {
        val pts = listOf(
            Offset(cx, cy - h / 2f), Offset(cx + w / 2f, cy),
            Offset(cx, cy + h / 2f), Offset(cx - w / 2f, cy),
        )
        val tw = layout.tileW * 0.20f
        val th = layout.tileH * 0.34f
        for (p in pts) {
            drawTile(Offset(p.x, p.y), tw * 1.5f, th * 0.7f, Pal.dirt, Pal.dirtLo, depth = th * 0.1f)
            drawRect(Color(0xFF8A6E48), Offset(p.x - tw / 2f, p.y - th), Size(tw, th))
            drawRect(Color(0xFF6E5537), Offset(p.x + tw * 0.18f, p.y - th), Size(tw * 0.32f, th))
            drawPath(
                poly(
                    Offset(p.x - tw * 0.85f, p.y - th),
                    Offset(p.x, p.y - th - tw * 0.9f),
                    Offset(p.x + tw * 0.85f, p.y - th),
                ),
                Color(0xFF5D4429),
            )
        }
    }
}

/** Колодец на площади: каменный оголовок, навес и пара бочек рядом. */
private fun DrawScope.drawWell(center: Offset, s: Float) {
    val baseY = center.y + s * 0.1f
    // каменный оголовок
    drawTile(Offset(center.x, baseY), s * 1.15f, s * 0.62f, Pal.stone, Pal.stoneLo, depth = s * 0.22f)
    drawPath(diamondPath(Offset(center.x, baseY - s * 0.06f), s * 0.62f, s * 0.34f), Color(0xFF16262B))
    // стойки и навес
    drawLine(Pal.dirt, Offset(center.x - s * 0.42f, baseY), Offset(center.x - s * 0.42f, baseY - s * 0.86f), strokeWidth = s * 0.11f)
    drawLine(Pal.dirt, Offset(center.x + s * 0.42f, baseY), Offset(center.x + s * 0.42f, baseY - s * 0.86f), strokeWidth = s * 0.11f)
    drawPath(
        poly(
            Offset(center.x - s * 0.68f, baseY - s * 0.84f),
            Offset(center.x, baseY - s * 1.24f),
            Offset(center.x + s * 0.68f, baseY - s * 0.84f),
        ),
        Color(0xFF9E5A3E),
    )
    // ведро на верёвке
    drawLine(Pal.dirtLo, Offset(center.x, baseY - s * 0.9f), Offset(center.x, baseY - s * 0.45f), strokeWidth = s * 0.04f)
    drawRect(Pal.dirt.lighten(0.15f), Offset(center.x - s * 0.1f, baseY - s * 0.48f), Size(s * 0.2f, s * 0.18f))
    // бочки и телега у края площади
    drawCircle(Color(0xFF8A6437), s * 0.2f, Offset(center.x - s * 1.25f, baseY + s * 0.12f))
    drawCircle(Color(0xFF9C7440), s * 0.17f, Offset(center.x - s * 0.95f, baseY + s * 0.3f))
    drawBush(Offset(center.x + s * 1.35f, baseY + s * 0.24f), s * 0.62f, Pal.grass.lighten(0.08f))
}

// --------------------------------------------------------------------------
// Карточка здания
// --------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BuildingSheet(
    vm: GameViewModel,
    g: GameState,
    v: Village,
    slot: Int,
    onClose: () -> Unit,
    onSub: (SubSheet) -> Unit,
) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val type = v.buildingAt(slot) ?: return
    val race = g.raceOf(v.ownerId)
    val level = v.slotLevel[slot]
    val next = Engine.buildingNextLevel(v, slot)
    val check = Engine.canUpgradeBuilding(g, v, slot)
    val cost = if (next <= type.maxLevel) type.costAt(next) else null
    val time = if (next <= type.maxLevel) type.timeAt(next) / Balance.buildSpeedup(v.level(BuildingType.MAIN)) else 0.0

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(type.title, style = MaterialTheme.typography.headlineSmall, color = Pal.text)
                    Text(
                        "Уровень $level из ${type.maxLevel}",
                        style = MaterialTheme.typography.bodySmall,
                        color = Pal.textDim,
                    )
                }
                if (next - 1 > level) Tag("в очереди", Pal.gold)
            }
            Spacer(Modifier.height(10.dp))
            Text(type.desc, style = MaterialTheme.typography.bodyMedium, color = Pal.textDim)
            Spacer(Modifier.height(14.dp))

            SectionTitle("Что даёт")
            Spacer(Modifier.height(6.dp))
            StatLine("Сейчас", if (level > 0) type.effectAt(level, race) else "не работает")
            if (next <= type.maxLevel) {
                StatLine("Уровень $next", type.effectAt(next, race), Pal.jade)
            }

            // Особые действия зданий.
            val action: Pair<String, SubSheet>? = when (type) {
                BuildingType.BARRACKS, BuildingType.STABLE, BuildingType.WORKSHOP, BuildingType.RESIDENCE ->
                    "Нанять войска" to SubSheet.TRAIN
                BuildingType.MARKET -> "Обменять ресурсы" to SubSheet.MARKET
                BuildingType.RALLY -> "Отправить войска" to SubSheet.ARMY
                else -> null
            }
            if (action != null && level > 0) {
                Spacer(Modifier.height(14.dp))
                GhostButton(
                    action.first,
                    Modifier.fillMaxWidth(),
                    icon = when (action.second) {
                        SubSheet.TRAIN -> Icons.Filled.Groups
                        SubSheet.MARKET -> Icons.Filled.SwapHoriz
                        else -> Icons.AutoMirrored.Filled.Send
                    },
                ) {
                    onClose()
                    onSub(action.second)
                }
            }

            Spacer(Modifier.height(16.dp))
            if (cost != null) {
                SectionTitle(if (level == 0) "Стоимость постройки" else "Стоимость улучшения до $next ур.")
                Spacer(Modifier.height(8.dp))
                CostRow(cost, v.stock)
                Spacer(Modifier.height(6.dp))
                Text("Время: ${formatDuration(time)}", style = MaterialTheme.typography.bodySmall, color = Pal.textDim)
                Spacer(Modifier.height(14.dp))
                ActionButton(
                    text = if (check.ok) (if (level == 0) "Построить" else "Улучшить до $next уровня") else check.reason,
                    enabled = check.ok,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    val r = Engine.upgradeBuilding(g, v, slot)
                    vm.report(r)
                    if (r.ok) onClose()
                }
            } else {
                Text("Здание развито до предела.", style = MaterialTheme.typography.bodyMedium, color = Pal.gold)
            }
        }
    }
}

// --------------------------------------------------------------------------
// Меню строительства на пустом участке
// --------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BuildMenuSheet(vm: GameViewModel, g: GameState, v: Village, slot: Int, onClose: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val race = g.raceOf(v.ownerId)
    val options = Engine.availableBuildings(g, v, slot)

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 20.dp)) {
            Text("Свободный участок", style = MaterialTheme.typography.headlineSmall, color = Pal.text)
            Text(
                "Выберите постройку. Требования проверяются по всей деревне.",
                style = MaterialTheme.typography.bodySmall,
                color = Pal.textDim,
            )
        }
        LazyColumn(Modifier.fillMaxWidth().padding(horizontal = 14.dp)) {
            for (cat in BuildCategory.entries) {
                val group = options.filter { it.category == cat }
                if (group.isEmpty()) continue
                item(key = "h${cat.name}") {
                    SectionTitle(cat.title, Modifier.padding(start = 6.dp, top = 12.dp, bottom = 6.dp))
                }
                items(group.size, key = { group[it].name }) { i ->
                    val type = group[i]
                    val check = Engine.canBuild(g, v, slot, type)
                    val req = Engine.requirementsText(v, type)
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(Pal.surfaceLo)
                            .border(1.dp, Pal.outlineSoft, RoundedCornerShape(14.dp))
                            .clickable(enabled = check.ok) {
                                val r = Engine.build(g, v, slot, type)
                                vm.report(r)
                                if (r.ok) onClose()
                            }
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        BuildingThumb(type, Modifier.size(52.dp))
                        Spacer(Modifier.size(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(
                                type.title,
                                style = MaterialTheme.typography.titleSmall,
                                color = if (req == null) Pal.text else Pal.textFaint,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Spacer(Modifier.height(3.dp))
                            if (req != null) {
                                Text(req, style = MaterialTheme.typography.bodySmall, color = Pal.danger)
                            } else {
                                Text(
                                    type.desc,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Pal.textDim,
                                    maxLines = 2,
                                )
                                Spacer(Modifier.height(5.dp))
                                CostRow(type.costAt(1), v.stock, compact = true)
                            }
                        }
                    }
                }
            }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

/** Миниатюра постройки для списков — тот же вектор, что и на карте деревни. */
@Composable
fun BuildingThumb(type: BuildingType, modifier: Modifier = Modifier, level: Int = 1) {
    Canvas(
        modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Brush.verticalGradient(listOf(Color(0xFF1E3128), Color(0xFF14241D)))),
    ) {
        val c = Offset(size.width / 2f, size.height * 0.62f)
        drawBuilding(type, c, size.width * 0.86f, size.height * 0.42f, level)
    }
}
