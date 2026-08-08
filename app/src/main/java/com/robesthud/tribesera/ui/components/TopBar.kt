package com.robesthud.tribesera.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Description
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.robesthud.tribesera.engine.BuildingType
import com.robesthud.tribesera.engine.GameState
import com.robesthud.tribesera.engine.RES
import com.robesthud.tribesera.engine.Res
import com.robesthud.tribesera.engine.Village
import com.robesthud.tribesera.engine.formatAmount
import com.robesthud.tribesera.engine.formatDuration
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.theme.Pal
import kotlin.math.roundToInt

@Composable
fun TopBar(
    vm: GameViewModel,
    g: GameState,
    v: Village,
    unreadReports: Int,
    onReports: () -> Unit,
    onLeaderboard: () -> Unit,
    onMenu: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(listOf(Color(0xFF14231D), Color(0xFF0F1B17))))
            .padding(horizontal = 10.dp, vertical = 6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            VillagePicker(vm, g, v, Modifier.weight(1f, fill = false))
            Spacer(Modifier.weight(1f))
            TimerChip(g)
            Spacer(Modifier.width(6.dp))
            IconPill(Icons.Filled.Description, unreadReports, onReports)
            Spacer(Modifier.width(4.dp))
            IconPill(Icons.Filled.EmojiEvents, 0, onLeaderboard)
            Spacer(Modifier.width(4.dp))
            IconPill(Icons.Filled.Menu, 0, onMenu)
        }
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (r in RES) {
                ResourceChip(g, v, r, Modifier.weight(1f))
            }
        }
        Spacer(Modifier.height(5.dp))
        FooterStats(g, v)
    }
}

@Composable
private fun VillagePicker(vm: GameViewModel, g: GameState, v: Village, modifier: Modifier = Modifier) {
    var open by remember { mutableStateOf(false) }
    val mine = g.villagesOf(0)
    Box(modifier) {
        Row(
            Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(Pal.surfaceHi)
                .clickable(enabled = mine.size > 1) { open = true }
                .padding(start = 10.dp, end = if (mine.size > 1) 4.dp else 10.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (v.capital) {
                Box(
                    Modifier.size(7.dp).clip(RoundedCornerShape(4.dp)).background(Pal.gold),
                )
                Spacer(Modifier.width(6.dp))
            }
            Text(v.name, style = MaterialTheme.typography.titleSmall, color = Pal.text, maxLines = 1)
            if (mine.size > 1) Icon(Icons.Filled.ArrowDropDown, null, tint = Pal.textDim, modifier = Modifier.size(20.dp))
        }
        DropdownMenu(open, { open = false }) {
            mine.forEach { village ->
                DropdownMenuItem(
                    text = {
                        Column {
                            Text(village.name, color = Pal.text, style = MaterialTheme.typography.titleSmall)
                            Text(
                                "(${village.x}|${village.y}) · население ${village.population()}",
                                color = Pal.textDim,
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    },
                    onClick = { vm.selectVillage(village.id); open = false },
                )
            }
        }
    }
}

@Composable
private fun TimerChip(g: GameState) {
    val left = g.timeLeft
    val urgent = left < 300
    Row(
        Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(if (urgent) Pal.danger.copy(alpha = 0.18f) else Pal.surfaceHi)
            .padding(horizontal = 9.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            formatDuration(left),
            style = MaterialTheme.typography.titleSmall,
            color = if (urgent) Pal.danger else Pal.textDim,
        )
    }
}

@Composable
private fun IconPill(icon: androidx.compose.ui.graphics.vector.ImageVector, badge: Int, onClick: () -> Unit) {
    Box {
        Box(
            Modifier
                .size(34.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(Pal.surfaceHi)
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, null, tint = Pal.textDim, modifier = Modifier.size(19.dp))
        }
        if (badge > 0) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .size(15.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(Pal.danger),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (badge > 9) "9+" else badge.toString(),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White,
                )
            }
        }
    }
}

@Composable
private fun ResourceChip(g: GameState, v: Village, r: Res, modifier: Modifier) {
    val amount = v.stock[r.ordinal]
    val cap = v.capOf(r)
    val rate = g.netOutput(v, r)
    val fill = (amount / cap).toFloat().coerceIn(0f, 1f)
    val full = fill > 0.95f
    Column(
        modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Pal.surfaceLo)
            .border(1.dp, if (full) Pal.danger.copy(alpha = 0.55f) else Pal.outlineSoft, RoundedCornerShape(10.dp))
            .padding(horizontal = 6.dp, vertical = 5.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ResIcon(r, 14.dp)
            Spacer(Modifier.width(4.dp))
            Text(
                formatAmount(amount),
                style = MaterialTheme.typography.bodySmall,
                color = if (full) Pal.danger else Pal.text,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )
        }
        Spacer(Modifier.height(3.dp))
        ProgressBar(fill, Modifier.fillMaxWidth().height(4.dp), tone = Pal.res(r.ordinal))
        Spacer(Modifier.height(2.dp))
        Text(
            (if (rate >= 0) "+" else "") + String.format("%.1f", rate),
            style = MaterialTheme.typography.labelSmall,
            color = if (rate < 0) Pal.danger else Pal.textFaint,
            maxLines = 1,
        )
    }
}

@Composable
private fun FooterStats(g: GameState, v: Village) {
    val pop = v.population()
    val queue = v.buildQueue.firstOrNull()
    Row(verticalAlignment = Alignment.CenterVertically) {
        Tag("Население $pop", Pal.textDim)
        Spacer(Modifier.width(6.dp))
        Tag("Очки ${g.score(0)}", Pal.gold)
        Spacer(Modifier.width(6.dp))
        val wall = v.level(BuildingType.WALL)
        if (wall > 0) Tag("Стена $wall", Pal.jade)
        Spacer(Modifier.weight(1f))
        if (queue != null) {
            Text(
                "Стройка: ${formatDuration(queue.remaining)}",
                style = MaterialTheme.typography.labelSmall,
                color = Pal.gold,
            )
        }
    }
}

/** Полоска «входящие атаки» — красная тревога поверх игрового поля. */
@Composable
fun AlertStrip(text: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(Pal.danger.copy(alpha = 0.16f))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(8.dp).clip(RoundedCornerShape(4.dp)).background(Pal.danger))
        Spacer(Modifier.width(8.dp))
        Text(text, style = MaterialTheme.typography.labelMedium, color = Pal.danger)
    }
}

/** Число с округлением — чтобы не тащить форматирование по всем экранам. */
fun rounded(v: Double): String = v.roundToInt().toString()
