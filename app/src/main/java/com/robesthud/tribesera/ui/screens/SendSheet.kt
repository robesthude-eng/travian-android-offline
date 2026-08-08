package com.robesthud.tribesera.ui.screens

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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.robesthud.tribesera.engine.Balance
import com.robesthud.tribesera.engine.BuildingType
import com.robesthud.tribesera.engine.Combat
import com.robesthud.tribesera.engine.Engine
import com.robesthud.tribesera.engine.GameState
import com.robesthud.tribesera.engine.MoveKind
import com.robesthud.tribesera.engine.UnitKind
import com.robesthud.tribesera.engine.Units
import com.robesthud.tribesera.engine.Village
import com.robesthud.tribesera.engine.dist
import com.robesthud.tribesera.engine.emptyTroops
import com.robesthud.tribesera.engine.formatAmount
import com.robesthud.tribesera.engine.formatDuration
import com.robesthud.tribesera.engine.travelTime
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.components.ActionButton
import com.robesthud.tribesera.ui.components.GhostButton
import com.robesthud.tribesera.ui.components.SectionTitle
import com.robesthud.tribesera.ui.components.StatLine
import com.robesthud.tribesera.ui.components.Tag
import com.robesthud.tribesera.ui.theme.Pal
import kotlin.math.roundToInt

// ==========================================================================
// Что находится на выбранной клетке и что с этим можно сделать
// ==========================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TargetSheet(
    vm: GameViewModel,
    g: GameState,
    home: Village,
    x: Int,
    y: Int,
    onClose: () -> Unit,
    onSend: (MoveKind) -> Unit,
) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val village = g.villageAt(x, y)
    val oasis = g.oasisAt(x, y)
    val d = dist(home.x, home.y, x, y)

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
            when {
                village != null -> {
                    val owner = g.playerOrNull(village.ownerId)
                    val mine = village.ownerId == 0
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(village.name, style = MaterialTheme.typography.headlineSmall, color = Pal.text)
                            Text(
                                "($x|$y) · ${owner?.name ?: "ничья"} · ${owner?.race?.title ?: ""}",
                                style = MaterialTheme.typography.bodySmall,
                                color = Pal.textDim,
                            )
                        }
                        Box(
                            Modifier
                                .size(12.dp)
                                .clip(RoundedCornerShape(6.dp))
                                .background(Pal.player(owner?.colorIndex ?: 1)),
                        )
                    }
                    Spacer(Modifier.height(14.dp))
                    StatLine("Расстояние", distanceLabel(home, x, y))
                    StatLine("Направление", deltaLabel(home, x, y))
                    StatLine("Население", village.population().toString())
                    if (mine) {
                        StatLine("Лояльность", "${village.loyalty.roundToInt()}%")
                        StatLine("Гарнизон", garrisonSummary(village))
                    } else {
                        StatLine("Стена", "${village.level(BuildingType.WALL)} ур.")
                        StatLine(
                            "Лояльность",
                            "${village.loyalty.roundToInt()}%",
                            if (village.loyalty < 60) Pal.warn else Pal.text,
                        )
                        StatLine("Гарнизон", "неизвестен — отправьте разведку", Pal.textFaint)
                    }
                    if (!owner?.personality?.title.isNullOrEmpty() && !mine) {
                        Spacer(Modifier.height(8.dp))
                        Tag("характер: ${owner!!.personality.title}", Pal.player(owner.colorIndex))
                    }

                    Spacer(Modifier.height(18.dp))
                    if (mine) {
                        if (village.id != home.id) {
                            ActionButton("Отправить подкрепление", Modifier.fillMaxWidth(), icon = Icons.Filled.Shield) {
                                onSend(MoveKind.REINFORCE)
                            }
                        } else {
                            Text(
                                "Это ваша деревня — выберите чужую клетку, чтобы отправить войска.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Pal.textFaint,
                            )
                        }
                    } else {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            ActionButton("Набег", Modifier.weight(1f), icon = Icons.Filled.Bolt) { onSend(MoveKind.RAID) }
                            ActionButton(
                                "Штурм", Modifier.weight(1f),
                                icon = Icons.Filled.Whatshot, tone = Pal.danger,
                            ) { onSend(MoveKind.ATTACK) }
                        }
                        Spacer(Modifier.height(8.dp))
                        GhostButton("Разведка", Modifier.fillMaxWidth(), icon = Icons.Filled.Visibility) {
                            onSend(MoveKind.SCOUT)
                        }
                    }
                }

                oasis != null -> {
                    Text(oasis.title, style = MaterialTheme.typography.headlineSmall, color = Pal.text)
                    Text("($x|$y)", style = MaterialTheme.typography.bodySmall, color = Pal.textDim)
                    Spacer(Modifier.height(14.dp))
                    StatLine("Бонус", "+${oasis.bonusPct}% к добыче")
                    StatLine("Расстояние", distanceLabel(home, x, y))
                    StatLine(
                        "Дикие звери",
                        if (oasis.wildDefense < 1) "разогнаны" else "оборона ~${r0(oasis.wildDefense)}",
                        if (oasis.wildDefense < 1) Pal.jade else Pal.warn,
                    )
                    StatLine("Запасы", formatAmount(oasis.stock))
                    val holder = g.village(oasis.ownerVillage)
                    StatLine(
                        "Владелец",
                        if (holder == null) "ничей" else "${holder.name} (${g.playerOrNull(holder.ownerId)?.name})",
                    )
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "Деревня может удерживать ${Engine.oasisCapacity(home)} оазис(ов) — " +
                            "предел растёт вместе с главным зданием.",
                        style = MaterialTheme.typography.bodySmall,
                        color = Pal.textFaint,
                    )
                    Spacer(Modifier.height(16.dp))
                    ActionButton("Отправить войско", Modifier.fillMaxWidth(), icon = Icons.Filled.Bolt) {
                        onSend(MoveKind.RAID)
                    }
                }

                else -> {
                    Text("Свободная земля", style = MaterialTheme.typography.headlineSmall, color = Pal.text)
                    Text("($x|$y)", style = MaterialTheme.typography.bodySmall, color = Pal.textDim)
                    Spacer(Modifier.height(14.dp))
                    StatLine("Расстояние", distanceLabel(home, x, y))
                    val settlers = home.troops.indices.sumOf {
                        if (Units[it].kind == UnitKind.SETTLER) home.troops[it] else 0
                    }
                    StatLine(
                        "Поселенцев дома",
                        "$settlers из ${Units.SETTLERS_TO_FOUND}",
                        if (settlers >= Units.SETTLERS_TO_FOUND) Pal.jade else Pal.textDim,
                    )
                    Spacer(Modifier.height(16.dp))
                    ActionButton(
                        "Основать деревню",
                        Modifier.fillMaxWidth(),
                        enabled = settlers >= Units.SETTLERS_TO_FOUND,
                        icon = Icons.Filled.Flag,
                    ) { onSend(MoveKind.SETTLE) }
                    if (settlers < Units.SETTLERS_TO_FOUND) {
                        Spacer(Modifier.height(8.dp))
                        Text(
                            "Поселенцы готовятся в резиденции с ${BuildingType.settlerSlots(5)} уровня.",
                            style = MaterialTheme.typography.bodySmall,
                            color = Pal.textFaint,
                        )
                    }
                }
            }
        }
    }
}

// ==========================================================================
// Выбор отряда и отправка
// ==========================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SendSheet(
    vm: GameViewModel,
    g: GameState,
    home: Village,
    x: Int,
    y: Int,
    kind: MoveKind,
    onClose: () -> Unit,
) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val selection = remember { mutableStateMapOf<Int, Int>() }
    var catTarget by remember { mutableIntStateOf(-1) }
    val race = g.raceOf(0)
    val present = home.troops.indices.filter { home.troops[it] > 0 }
    val snapshot = selection.toMap()

    val total = selectedTotal(snapshot)
    val speed = slowestSpeed(snapshot)
    val d = dist(home.x, home.y, x, y)
    val eta = if (speed > 0) travelTime(d, speed, race) else 0.0
    val hasSiege = snapshot.any { it.value > 0 && Units[it.key].kind == UnitKind.SIEGE }

    val army = remember(snapshot) {
        val a = emptyTroops()
        for ((id, n) in snapshot) a[id] = n
        a
    }
    val check = Engine.canSend(g, home, army, kind)

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.fillMaxHeight(0.93f)) {
            Column(Modifier.padding(horizontal = 20.dp)) {
                Text(kind.title, style = MaterialTheme.typography.headlineSmall, color = Pal.text)
                Text(
                    "из «${home.name}» на клетку ($x|$y) · ${distanceLabel(home, x, y)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Pal.textDim,
                )
                if (kind == MoveKind.RAID) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Набег щадит обе стороны: потери делятся пропорционально, войско уходит с добычей.",
                        style = MaterialTheme.typography.bodySmall,
                        color = Pal.textFaint,
                    )
                }
                if (kind == MoveKind.ATTACK) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Штурм — до последнего: проигравший теряет всё войско. Вождь в отряде сбивает лояльность.",
                        style = MaterialTheme.typography.bodySmall,
                        color = Pal.textFaint,
                    )
                }
            }
            Spacer(Modifier.height(10.dp))

            LazyColumn(Modifier.weight(1f).padding(horizontal = 16.dp)) {
                if (present.isEmpty()) {
                    item {
                        Text(
                            "В деревне нет войск. Наймите их в казарме или конюшне.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Pal.textFaint,
                            modifier = Modifier.padding(16.dp),
                        )
                    }
                }
                items(present.size, key = { present[it] }) { i ->
                    val id = present[i]
                    TroopPickRow(
                        id = id,
                        available = home.troops[id],
                        picked = selection[id] ?: 0,
                        onPick = { selection[id] = it.coerceIn(0, home.troops[id]) },
                    )
                }

                if (hasSiege && kind == MoveKind.ATTACK) {
                    item {
                        Spacer(Modifier.height(14.dp))
                        SectionTitle("Цель катапульт")
                        Spacer(Modifier.height(8.dp))
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            item {
                                CatChip("случайно", catTarget == -1) { catTarget = -1 }
                            }
                            items(BuildingType.entries.size) { bi ->
                                val bt = BuildingType.entries[bi]
                                CatChip(bt.title, catTarget == bt.ordinal) { catTarget = bt.ordinal }
                            }
                        }
                    }
                }
                item { Spacer(Modifier.height(16.dp)) }
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .background(Pal.surfaceLo)
                    .padding(horizontal = 20.dp, vertical = 12.dp),
            ) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("$total воинов", style = MaterialTheme.typography.labelMedium, color = Pal.textDim)
                    Text(
                        if (total > 0) "в пути ${formatDuration(eta)}" else "выберите войска",
                        style = MaterialTheme.typography.labelMedium,
                        color = Pal.gold,
                    )
                }
                Spacer(Modifier.height(4.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(
                        "Сила атаки ${r0(Combat.offensePower(army, home.level(BuildingType.SMITHY)))}",
                        style = MaterialTheme.typography.labelSmall,
                        color = Pal.textFaint,
                    )
                    Text(capacityHint(army, race), style = MaterialTheme.typography.labelSmall, color = Pal.textFaint)
                }
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    GhostButton("Все войска", Modifier.weight(1f)) {
                        for (id in present) {
                            if (Units[id].kind != UnitKind.SETTLER || kind == MoveKind.SETTLE) {
                                selection[id] = home.troops[id]
                            }
                        }
                    }
                    ActionButton(
                        text = if (check.ok) "Отправить" else check.reason,
                        modifier = Modifier.weight(1f),
                        enabled = check.ok,
                        tone = if (kind == MoveKind.ATTACK) Pal.danger else Pal.gold,
                    ) {
                        val r = Engine.send(g, home, x, y, kind, army, catTarget)
                        vm.report(r)
                        if (r.ok) onClose()
                    }
                }
            }
        }
    }
}

@Composable
private fun TroopPickRow(id: Int, available: Int, picked: Int, onPick: (Int) -> Unit) {
    val def = Units[id]
    Column(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Pal.surfaceLo)
            .border(
                1.dp,
                if (picked > 0) Pal.gold.copy(alpha = 0.5f) else Pal.outlineSoft,
                RoundedCornerShape(14.dp),
            )
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            UnitIcon(def, 40.dp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(def.title, style = MaterialTheme.typography.titleSmall, color = Pal.text)
                Text(
                    "дома $available · атака ${def.att} · скорость ${def.speed.toInt()}",
                    style = MaterialTheme.typography.labelSmall,
                    color = Pal.textDim,
                )
            }
            Text("$picked", style = MaterialTheme.typography.titleMedium, color = if (picked > 0) Pal.gold else Pal.textFaint)
        }
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            PickChip("−10") { onPick(picked - 10) }
            PickChip("−1") { onPick(picked - 1) }
            PickChip("+1") { onPick(picked + 1) }
            PickChip("+10") { onPick(picked + 10) }
            Spacer(Modifier.weight(1f))
            PickChip("все") { onPick(available) }
            PickChip("0") { onPick(0) }
        }
    }
}

@Composable
private fun PickChip(label: String, onClick: () -> Unit) {
    Box(
        Modifier
            .height(30.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(Pal.surfaceHi)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = Pal.text)
    }
}

@Composable
private fun CatChip(label: String, active: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .clip(RoundedCornerShape(9.dp))
            .background(if (active) Pal.danger.copy(alpha = 0.2f) else Pal.surfaceHi)
            .border(1.dp, if (active) Pal.danger else Color.Transparent, RoundedCornerShape(9.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 11.dp, vertical = 7.dp),
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = if (active) Pal.danger else Pal.textDim)
    }
}
