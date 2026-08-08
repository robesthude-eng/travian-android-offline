package com.robesthud.tribesera.ui.screens

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.robesthud.tribesera.engine.GameState
import com.robesthud.tribesera.engine.RES
import com.robesthud.tribesera.engine.Report
import com.robesthud.tribesera.engine.ReportKind
import com.robesthud.tribesera.engine.formatAmount
import com.robesthud.tribesera.engine.formatDuration
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.components.ResIcon
import com.robesthud.tribesera.ui.components.SectionTitle
import com.robesthud.tribesera.ui.components.Tag
import com.robesthud.tribesera.ui.theme.Pal
import kotlin.math.abs

// ==========================================================================
// Отчёты
// ==========================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportsSheet(vm: GameViewModel, g: GameState, onClose: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var expanded by remember { mutableIntStateOf(-1) }
    val reports = g.reports.filter { it.ownerId == 0 }

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.fillMaxHeight(0.9f)) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Отчёты", style = MaterialTheme.typography.headlineSmall, color = Pal.text)
                    Text(
                        "Бои, разведка и события партии",
                        style = MaterialTheme.typography.bodySmall,
                        color = Pal.textDim,
                    )
                }
                if (reports.any { !it.read }) {
                    Box(
                        Modifier
                            .clip(RoundedCornerShape(9.dp))
                            .background(Pal.surfaceHi)
                            .clickable { g.reports.forEach { it.read = true }; vm.bump() }
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                    ) {
                        Text("Прочитано", style = MaterialTheme.typography.labelSmall, color = Pal.textDim)
                    }
                }
            }
            Spacer(Modifier.height(10.dp))
            LazyColumn(Modifier.weight(1f).padding(horizontal = 16.dp)) {
                if (reports.isEmpty()) {
                    item {
                        Text(
                            "Пока тихо. Отчёты появятся после первого похода или нападения.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Pal.textFaint,
                            modifier = Modifier.padding(20.dp),
                        )
                    }
                }
                items(reports.size, key = { reports[it].id }) { i ->
                    val r = reports[i]
                    ReportCard(
                        report = r,
                        now = g.time,
                        expanded = expanded == r.id,
                        onToggle = {
                            expanded = if (expanded == r.id) -1 else r.id
                            r.read = true
                            vm.bump()
                        },
                    )
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}

@Composable
private fun ReportCard(report: Report, now: Double, expanded: Boolean, onToggle: () -> Unit) {
    val tone = when {
        report.kind == ReportKind.SYSTEM -> Pal.textDim
        report.kind == ReportKind.CONQUEST -> Pal.gold
        report.success -> Pal.jade
        else -> Pal.danger
    }
    Column(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Pal.surfaceLo)
            .border(1.dp, if (report.read) Pal.outlineSoft else tone.copy(alpha = 0.5f), RoundedCornerShape(14.dp))
            .clickable(onClick = onToggle)
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(9.dp).clip(RoundedCornerShape(5.dp)).background(tone))
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(report.title, style = MaterialTheme.typography.titleSmall, color = Pal.text)
                Text(report.subtitle, style = MaterialTheme.typography.bodySmall, color = tone)
            }
            Text(
                "${formatDuration(now - report.time)} назад",
                style = MaterialTheme.typography.labelSmall,
                color = Pal.textFaint,
            )
        }
        if (report.loot.any { abs(it) > 1.0 }) {
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                for (r in RES) {
                    val v = report.loot[r.ordinal]
                    if (abs(v) < 1.0) continue
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ResIcon(r, 13.dp)
                        Spacer(Modifier.width(3.dp))
                        Text(
                            (if (v > 0) "+" else "−") + formatAmount(abs(v)),
                            style = MaterialTheme.typography.labelSmall,
                            color = if (v > 0) Pal.jade else Pal.danger,
                        )
                    }
                }
            }
        }
        AnimatedVisibility(expanded) {
            Column(Modifier.padding(top = 10.dp)) {
                for (line in report.lines) {
                    Text(
                        line,
                        style = MaterialTheme.typography.bodySmall,
                        color = if (line == "—") Pal.outlineSoft else Pal.textDim,
                        modifier = Modifier.padding(vertical = 1.dp),
                    )
                }
            }
        }
    }
}

// ==========================================================================
// Таблица очков
// ==========================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LeaderboardSheet(g: GameState, onClose: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val board = g.leaderboard()

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = state,
        containerColor = Pal.surface,
        contentColor = Pal.text,
    ) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
            Text("Положение в партии", style = MaterialTheme.typography.headlineSmall, color = Pal.text)
            Text(
                "До конца ${formatDuration(g.timeLeft)}. Очки — за постройки, население и войска.",
                style = MaterialTheme.typography.bodySmall,
                color = Pal.textDim,
            )
            Spacer(Modifier.height(16.dp))
            board.forEachIndexed { index, (player, score) ->
                LeaderRow(index + 1, player.name, player.race.title, player.personality.title, score, g.villagesOf(player.id).size, player.human, player.defeated, player.colorIndex)
            }
            Spacer(Modifier.height(14.dp))
            SectionTitle("Как выиграть")
            Spacer(Modifier.height(6.dp))
            Text(
                "· Достроить Чудо света до 10 уровня в столице\n" +
                    "· Отобрать у соперников все деревни\n" +
                    "· Или просто быть первым по очкам, когда выйдет время",
                style = MaterialTheme.typography.bodyMedium,
                color = Pal.textDim,
            )
        }
    }
}

@Composable
private fun LeaderRow(
    place: Int,
    name: String,
    race: String,
    personality: String,
    score: Int,
    villages: Int,
    human: Boolean,
    defeated: Boolean,
    colorIndex: Int,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(if (human) Pal.gold.copy(alpha = 0.10f) else Pal.surfaceLo)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            "$place",
            style = MaterialTheme.typography.titleMedium,
            color = if (place == 1) Pal.gold else Pal.textFaint,
            modifier = Modifier.width(24.dp),
        )
        Box(Modifier.size(10.dp).clip(RoundedCornerShape(5.dp)).background(Pal.player(colorIndex)))
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    name,
                    style = MaterialTheme.typography.titleSmall,
                    color = if (defeated) Pal.textFaint else Pal.text,
                    fontWeight = if (human) FontWeight.Bold else FontWeight.SemiBold,
                )
                if (human) {
                    Spacer(Modifier.width(6.dp))
                    Tag("вы", Pal.gold)
                }
                if (defeated) {
                    Spacer(Modifier.width(6.dp))
                    Tag("выбыл", Pal.danger)
                }
            }
            Text(
                "$race · $personality · деревень $villages",
                style = MaterialTheme.typography.labelSmall,
                color = Pal.textDim,
            )
        }
        Text("$score", style = MaterialTheme.typography.titleMedium, color = if (place == 1) Pal.gold else Pal.text)
    }
}
