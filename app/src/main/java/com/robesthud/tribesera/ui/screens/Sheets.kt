package com.robesthud.tribesera.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Map
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.robesthud.tribesera.engine.BuildingType
import com.robesthud.tribesera.engine.Cost
import com.robesthud.tribesera.engine.Engine
import com.robesthud.tribesera.engine.GameState
import com.robesthud.tribesera.engine.MoveKind
import com.robesthud.tribesera.engine.RES
import com.robesthud.tribesera.engine.Res
import com.robesthud.tribesera.engine.UnitDef
import com.robesthud.tribesera.engine.UnitKind
import com.robesthud.tribesera.engine.Units
import com.robesthud.tribesera.engine.Village
import com.robesthud.tribesera.engine.formatAmount
import com.robesthud.tribesera.engine.formatDuration
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.Tab
import com.robesthud.tribesera.ui.art.drawUnitGlyph
import com.robesthud.tribesera.ui.components.ActionButton
import com.robesthud.tribesera.ui.components.CostRow
import com.robesthud.tribesera.ui.components.GhostButton
import com.robesthud.tribesera.ui.components.ResIcon
import com.robesthud.tribesera.ui.components.SectionTitle
import com.robesthud.tribesera.ui.components.StatLine
import com.robesthud.tribesera.ui.components.Tag
import com.robesthud.tribesera.ui.theme.Pal
import kotlin.math.min
import kotlin.math.roundToInt

/** Иконка юнита: силуэт рода войск в цвете народа. */
@Composable
fun UnitIcon(def: UnitDef, size: androidx.compose.ui.unit.Dp = 40.dp, modifier: Modifier = Modifier) {
    val tint = when (def.race.ordinal) {
        0 -> Color(0xFFC0563F)
        1 -> Color(0xFF8C7BD8)
        else -> Color(0xFF4FB286)
    }
    Canvas(
        modifier
            .size(size)
            .clip(RoundedCornerShape(10.dp))
            .background(Brush.verticalGradient(listOf(Color(0xFF1D2F26), Color(0xFF14211B)))),
    ) {
        drawUnitGlyph(def.kind, Offset(this.size.width / 2f, this.size.height / 2f), this.size.minDimension * 0.78f, tint)
    }
}

// ==========================================================================
// Найм войск
// ==========================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrainSheet(vm: GameViewModel, g: GameState, v: Village, onClose: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val race = g.raceOf(v.ownerId)
    val roster = Units.of(race)
    val counts = remember { mutableStateMapOf<Int, Int>() }

    val total = remember(counts.toMap()) {
        var c = Cost()
        for ((id, n) in counts) if (n > 0) c += Units[id].cost * n.toDouble()
        c
    }

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.fillMaxHeight(0.92f)) {
            Column(Modifier.padding(horizontal = 20.dp)) {
                Text("Найм войск", style = MaterialTheme.typography.headlineSmall, color = Pal.text)
                Text(
                    "${race.title} · ${race.motto}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Pal.textDim,
                )
            }
            Spacer(Modifier.height(10.dp))
            LazyColumn(Modifier.weight(1f).padding(horizontal = 14.dp)) {
                items(roster.size, key = { roster[it].id }) { i ->
                    val def = roster[i]
                    UnitTrainRow(
                        def = def,
                        village = v,
                        count = counts[def.id] ?: 0,
                        onCount = { counts[def.id] = it },
                    )
                }
                item { Spacer(Modifier.height(12.dp)) }
            }
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(Pal.surfaceLo)
                    .padding(horizontal = 20.dp, vertical = 12.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Итого", style = MaterialTheme.typography.labelMedium, color = Pal.textFaint)
                    Spacer(Modifier.width(12.dp))
                    CostRow(total, v.stock, compact = true)
                }
                Spacer(Modifier.height(10.dp))
                val any = counts.values.any { it > 0 }
                ActionButton("Нанять", Modifier.fillMaxWidth(), enabled = any) {
                    for ((id, n) in counts.toMap()) {
                        if (n > 0) vm.report(Engine.train(g, v, id, n))
                    }
                    counts.clear()
                    onClose()
                }
            }
        }
    }
}

@Composable
private fun UnitTrainRow(def: UnitDef, village: Village, count: Int, onCount: (Int) -> Unit) {
    val unlocked = Engine.unitUnlocked(village, def)
    val maxAffordable = Engine.affordableCount(village, def)
    Column(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Pal.surfaceLo)
            .border(1.dp, if (count > 0) Pal.gold.copy(alpha = 0.5f) else Pal.outlineSoft, RoundedCornerShape(14.dp))
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            UnitIcon(def, 44.dp)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        def.title,
                        style = MaterialTheme.typography.titleSmall,
                        color = if (unlocked) Pal.text else Pal.textFaint,
                    )
                    Spacer(Modifier.width(6.dp))
                    Tag(def.kind.title, if (unlocked) Pal.jade else Pal.textFaint)
                }
                Spacer(Modifier.height(3.dp))
                Text(
                    "Атака ${def.att} · оборона ${def.defI}/${def.defC} · скорость ${def.speed.toInt()} · груз ${def.cap}",
                    style = MaterialTheme.typography.labelSmall,
                    color = Pal.textDim,
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        if (!unlocked) {
            Text(
                Engine.unitLockReason(village, def),
                style = MaterialTheme.typography.bodySmall,
                color = Pal.danger,
            )
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CostRow(def.cost, village.stock, compact = true)
                Spacer(Modifier.weight(1f))
                Text(
                    formatDuration(def.trainSec / com.robesthud.tribesera.engine.Balance.trainSpeedup(village.level(def.from))),
                    style = MaterialTheme.typography.labelSmall,
                    color = Pal.textFaint,
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                StepButton("−") { onCount((count - 1).coerceAtLeast(0)) }
                Spacer(Modifier.width(6.dp))
                Box(
                    Modifier
                        .width(58.dp)
                        .height(34.dp)
                        .clip(RoundedCornerShape(9.dp))
                        .background(Pal.bgDeep),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(count.toString(), style = MaterialTheme.typography.titleSmall, color = Pal.text)
                }
                Spacer(Modifier.width(6.dp))
                StepButton("+") { onCount(count + 1) }
                Spacer(Modifier.width(6.dp))
                StepButton("+10") { onCount(count + 10) }
                Spacer(Modifier.weight(1f))
                StepButton("макс") { onCount(maxAffordable) }
            }
        }
    }
}

@Composable
private fun StepButton(label: String, onClick: () -> Unit) {
    Box(
        Modifier
            .height(34.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(Pal.surfaceHi)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = Pal.text)
    }
}

// ==========================================================================
// Рынок
// ==========================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MarketSheet(vm: GameViewModel, g: GameState, v: Village, onClose: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var give by remember { mutableStateOf(Res.WOOD) }
    var take by remember { mutableStateOf(Res.IRON) }
    var amount by remember { mutableFloatStateOf(0f) }
    val level = v.level(BuildingType.MARKET)
    val rate = BuildingType.marketRate(level)
    val maxAmount = v.stock[give.ordinal].toFloat()

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
            Text("Рынок", style = MaterialTheme.typography.headlineSmall, color = Pal.text)
            Text(
                "Курс ${"%.2f".format(rate)} — каждый уровень рынка делает обмен выгоднее.",
                style = MaterialTheme.typography.bodySmall,
                color = Pal.textDim,
            )
            Spacer(Modifier.height(16.dp))

            SectionTitle("Отдать")
            Spacer(Modifier.height(6.dp))
            ResPicker(give) { give = it; amount = 0f }
            Spacer(Modifier.height(14.dp))
            SectionTitle("Получить")
            Spacer(Modifier.height(6.dp))
            ResPicker(take) { take = it }

            Spacer(Modifier.height(16.dp))
            Slider(
                value = amount,
                onValueChange = { amount = it },
                valueRange = 0f..maxAmount.coerceAtLeast(1f),
                colors = SliderDefaults.colors(
                    thumbColor = Pal.gold,
                    activeTrackColor = Pal.gold,
                    inactiveTrackColor = Pal.surfaceHi,
                ),
            )
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ResIcon(give, 15.dp)
                    Spacer(Modifier.width(4.dp))
                    Text("−${formatAmount(amount.toDouble())}", color = Pal.danger, style = MaterialTheme.typography.bodyMedium)
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ResIcon(take, 15.dp)
                    Spacer(Modifier.width(4.dp))
                    Text("+${formatAmount(amount * rate)}", color = Pal.jade, style = MaterialTheme.typography.bodyMedium)
                }
            }
            Spacer(Modifier.height(16.dp))
            ActionButton(
                "Обменять",
                Modifier.fillMaxWidth(),
                enabled = amount > 1f && give != take,
            ) {
                vm.report(Engine.trade(g, v, give, take, amount.toDouble()))
                amount = 0f
            }
        }
    }
}

@Composable
private fun ResPicker(selected: Res, onSelect: (Res) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for (r in RES) {
            val active = r == selected
            Row(
                Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (active) Pal.gold.copy(alpha = 0.18f) else Pal.surfaceLo)
                    .border(1.dp, if (active) Pal.gold else Pal.outlineSoft, RoundedCornerShape(10.dp))
                    .clickable { onSelect(r) }
                    .padding(horizontal = 10.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ResIcon(r, 15.dp)
                Spacer(Modifier.width(5.dp))
                Text(r.short, style = MaterialTheme.typography.labelMedium, color = if (active) Pal.gold else Pal.textDim)
            }
        }
    }
}

// ==========================================================================
// Точка сбора: гарнизон и походы
// ==========================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ArmySheet(vm: GameViewModel, g: GameState, v: Village, onClose: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val outgoing = Engine.outgoing(g, 0)
    val incoming = Engine.incoming(g, v)

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.fillMaxHeight(0.9f)) {
            Column(Modifier.padding(horizontal = 20.dp)) {
                Text("Точка сбора", style = MaterialTheme.typography.headlineSmall, color = Pal.text)
                Text(
                    "Гарнизон «${v.name}» и все походы вашего племени.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Pal.textDim,
                )
                Spacer(Modifier.height(12.dp))
                GhostButton("Выбрать цель на карте", Modifier.fillMaxWidth(), icon = Icons.Filled.Map) {
                    onClose()
                    vm.tab = Tab.MAP
                }
            }
            Spacer(Modifier.height(12.dp))
            LazyColumn(Modifier.weight(1f).padding(horizontal = 20.dp)) {
                item { SectionTitle("Гарнизон") }
                item { Spacer(Modifier.height(6.dp)) }
                val present = v.troops.indices.filter { v.troops[it] > 0 }
                if (present.isEmpty()) {
                    item {
                        Text("Деревня пуста — все дома, кроме войск.", style = MaterialTheme.typography.bodyMedium, color = Pal.textFaint)
                    }
                }
                items(present.size) { i ->
                    val id = present[i]
                    Row(Modifier.fillMaxWidth().padding(vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
                        UnitIcon(Units[id], 32.dp)
                        Spacer(Modifier.width(10.dp))
                        Text(Units[id].title, style = MaterialTheme.typography.bodyMedium, color = Pal.text, modifier = Modifier.weight(1f))
                        Text("${v.troops[id]}", style = MaterialTheme.typography.titleSmall, color = Pal.gold)
                    }
                }

                if (v.reinforcements.isNotEmpty()) {
                    item { Spacer(Modifier.height(14.dp)); SectionTitle("Чужие подкрепления") }
                    items(v.reinforcements.size) { i ->
                        val r = v.reinforcements[i]
                        val owner = g.playerOrNull(r.ownerId)?.name ?: "?"
                        Text(
                            "$owner — ${r.troops.sum()} воинов",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Pal.textDim,
                            modifier = Modifier.padding(vertical = 4.dp),
                        )
                    }
                }

                item { Spacer(Modifier.height(16.dp)); SectionTitle("Походы") }
                item { Spacer(Modifier.height(6.dp)) }
                if (outgoing.isEmpty() && incoming.isEmpty()) {
                    item {
                        Text("Сейчас никто никуда не идёт.", style = MaterialTheme.typography.bodyMedium, color = Pal.textFaint)
                    }
                }
                items(outgoing.size) { i ->
                    val m = outgoing[i]
                    MovementRow(
                        title = m.kind.title,
                        subtitle = "→ (${m.tx}|${m.ty}) · ${m.troops.sum()} воинов",
                        eta = m.arrive - g.time,
                        tone = if (m.kind == MoveKind.RETURN) Pal.jade else Pal.gold,
                    )
                }
                items(incoming.size) { i ->
                    val m = incoming[i]
                    MovementRow(
                        title = "Входящая: ${m.kind.title}",
                        subtitle = "от ${g.playerOrNull(m.ownerId)?.name ?: "?"}",
                        eta = m.arrive - g.time,
                        tone = Pal.danger,
                    )
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}

@Composable
private fun MovementRow(title: String, subtitle: String, eta: Double, tone: Color) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Pal.surfaceLo)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(8.dp).clip(RoundedCornerShape(4.dp)).background(tone))
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleSmall, color = Pal.text)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = Pal.textDim)
        }
        Text(formatDuration(eta), style = MaterialTheme.typography.labelMedium, color = tone)
    }
}

/** Сводка «сколько войск дома» — используется в карточках карты. */
fun garrisonSummary(v: Village): String {
    val total = v.troops.sum()
    if (total == 0) return "гарнизон пуст"
    val kinds = v.troops.indices.filter { v.troops[it] > 0 }
        .groupBy { Units[it].kind }
        .map { (kind, ids) -> "${kind.title} ${ids.sumOf { v.troops[it] }}" }
    return kinds.joinToString(", ")
}

/** Подсказка по грузоподъёмности выбранного отряда. */
fun capacityHint(troops: List<Int>, race: com.robesthud.tribesera.engine.Race): String {
    val cap = troops.indices.sumOf { if (troops[it] > 0) troops[it].toDouble() * Units[it].cap else 0.0 } * race.lootMultiplier
    return "унесут до ${formatAmount(cap)}"
}

/** Сколько всего юнитов выбрано. */
fun selectedTotal(sel: Map<Int, Int>): Int = sel.values.sum()

/** Минимальная скорость отряда — определяет время марша. */
fun slowestSpeed(sel: Map<Int, Int>): Double {
    var s = Double.MAX_VALUE
    for ((id, n) in sel) if (n > 0) s = min(s, Units[id].speed)
    return if (s == Double.MAX_VALUE) 0.0 else s
}

/** Есть ли в отряде вождь — от этого зависит, можно ли захватить деревню. */
fun hasChief(sel: Map<Int, Int>): Boolean = sel.any { it.value > 0 && Units[it.key].kind == UnitKind.CHIEF }

/** Есть ли поселенцы для основания деревни. */
fun settlerCount(sel: Map<Int, Int>): Int =
    sel.entries.sumOf { if (Units[it.key].kind == UnitKind.SETTLER) it.value else 0 }

/** Округление процента для интерфейса. */
fun pct(v: Double): String = "${(v * 100).roundToInt()}%"
