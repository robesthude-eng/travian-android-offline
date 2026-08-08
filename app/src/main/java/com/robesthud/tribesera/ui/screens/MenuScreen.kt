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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.robesthud.tribesera.engine.Difficulty
import com.robesthud.tribesera.engine.GameSettings
import com.robesthud.tribesera.engine.Race
import com.robesthud.tribesera.engine.SessionLength
import com.robesthud.tribesera.engine.Units
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.art.darken
import com.robesthud.tribesera.ui.art.drawBanner
import com.robesthud.tribesera.ui.art.lighten
import com.robesthud.tribesera.ui.art.poly
import com.robesthud.tribesera.ui.components.ActionButton
import com.robesthud.tribesera.ui.components.GhostButton
import com.robesthud.tribesera.ui.components.SectionTitle
import com.robesthud.tribesera.ui.theme.Pal

@Composable
fun MenuScreen(vm: GameViewModel) {
    var race by remember { mutableStateOf(Race.IMPERIUM) }
    var difficulty by remember { mutableStateOf(Difficulty.NORMAL) }
    var length by remember { mutableStateOf(SessionLength.MEDIUM) }
    var opponents by remember { mutableIntStateOf(5) }
    var name by remember { mutableStateOf("Вождь") }
    val scroll = rememberScrollState()

    Column(
        Modifier
            .fillMaxSize()
            .background(Pal.screenGradient)
            .windowInsetsPadding(WindowInsets.systemBars)
            .verticalScroll(scroll)
            .padding(horizontal = 20.dp),
    ) {
        Spacer(Modifier.height(28.dp))
        Text(
            "ЭРА ПЛЕМЁН",
            style = MaterialTheme.typography.displaySmall,
            color = Pal.gold,
        )
        Text(
            "Оффлайновая стратегия: одна партия — от 40 минут до полутора часов",
            style = MaterialTheme.typography.bodyMedium,
            color = Pal.textDim,
        )

        if (vm.hasSave) {
            Spacer(Modifier.height(18.dp))
            ActionButton(
                "Продолжить партию",
                Modifier.fillMaxWidth(),
                icon = Icons.Filled.PlayArrow,
            ) { vm.continueGame() }
        }

        Spacer(Modifier.height(24.dp))
        SectionTitle("Народ")
        Spacer(Modifier.height(10.dp))
        for (r in Race.entries) {
            RaceCard(r, r == race) { race = r }
            Spacer(Modifier.height(10.dp))
        }

        Spacer(Modifier.height(12.dp))
        SectionTitle("Имя вождя")
        Spacer(Modifier.height(8.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Pal.surfaceLo)
                .border(1.dp, Pal.outlineSoft, RoundedCornerShape(12.dp))
                .padding(horizontal = 14.dp, vertical = 12.dp),
        ) {
            BasicTextField(
                value = name,
                onValueChange = { if (it.length <= 18) name = it },
                singleLine = true,
                textStyle = TextStyle(color = Pal.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold),
                cursorBrush = SolidColor(Pal.gold),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Spacer(Modifier.height(20.dp))
        SectionTitle("Длительность партии")
        Spacer(Modifier.height(8.dp))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            for (l in SessionLength.entries) {
                ChoiceRow(l.title, "", l == length) { length = l }
            }
        }

        Spacer(Modifier.height(20.dp))
        SectionTitle("Сложность соперников")
        Spacer(Modifier.height(8.dp))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            for (d in Difficulty.entries) {
                ChoiceRow(d.title, d.desc, d == difficulty) { difficulty = d }
            }
        }

        Spacer(Modifier.height(20.dp))
        SectionTitle("Соперников на карте: $opponents")
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (n in 3..7) {
                Box(
                    Modifier
                        .weight(1f)
                        .height(44.dp)
                        .clip(RoundedCornerShape(11.dp))
                        .background(if (n == opponents) Pal.gold.copy(alpha = 0.18f) else Pal.surfaceLo)
                        .border(
                            1.dp,
                            if (n == opponents) Pal.gold else Pal.outlineSoft,
                            RoundedCornerShape(11.dp),
                        )
                        .clickable { opponents = n },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        "$n",
                        style = MaterialTheme.typography.titleMedium,
                        color = if (n == opponents) Pal.gold else Pal.textDim,
                    )
                }
            }
        }

        Spacer(Modifier.height(26.dp))
        ActionButton("Начать партию", Modifier.fillMaxWidth(), icon = Icons.Filled.PlayArrow) {
            vm.newGame(
                GameSettings(
                    playerName = name,
                    race = race,
                    difficulty = difficulty,
                    length = length,
                    opponents = opponents,
                ),
            )
        }
        Spacer(Modifier.height(14.dp))
        Text(
            "Полностью оффлайн: соперники — локальный планировщик, никаких запросов в сеть.",
            style = MaterialTheme.typography.bodySmall,
            color = Pal.textFaint,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(36.dp))
    }
}

@Composable
private fun RaceCard(race: Race, selected: Boolean, onClick: () -> Unit) {
    val accent = when (race) {
        Race.IMPERIUM -> Color(0xFFC0563F)
        Race.HORDE -> Color(0xFF8C7BD8)
        Race.SYLVAN -> Color(0xFF4FB286)
    }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(
                Brush.horizontalGradient(
                    if (selected) listOf(accent.copy(alpha = 0.20f), Pal.surface)
                    else listOf(Pal.surface, Pal.surface),
                ),
            )
            .border(1.5.dp, if (selected) accent else Pal.outlineSoft, RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Canvas(
                Modifier
                    .size(54.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Pal.bgDeep),
            ) {
                drawCrest(race, Offset(size.width / 2f, size.height / 2f), size.minDimension * 0.8f, accent)
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(race.title, style = MaterialTheme.typography.titleLarge, color = if (selected) accent else Pal.text)
                Text(race.motto, style = MaterialTheme.typography.bodySmall, color = Pal.textDim)
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(race.lore, style = MaterialTheme.typography.bodySmall, color = Pal.textDim)
        Spacer(Modifier.height(8.dp))
        for (p in race.perks) {
            Row(Modifier.padding(vertical = 2.dp)) {
                Text("·  ", style = MaterialTheme.typography.bodySmall, color = accent)
                Text(p, style = MaterialTheme.typography.bodySmall, color = Pal.text)
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            Units.of(race).take(3).joinToString(" · ") { it.title },
            style = MaterialTheme.typography.labelSmall,
            color = Pal.textFaint,
        )
    }
}

/** Герб народа: щит с характерным символом. */
private fun DrawScope.drawCrest(race: Race, center: Offset, s: Float, accent: Color) {
    val shield = poly(
        Offset(center.x - s * 0.36f, center.y - s * 0.4f),
        Offset(center.x + s * 0.36f, center.y - s * 0.4f),
        Offset(center.x + s * 0.36f, center.y + s * 0.1f),
        Offset(center.x, center.y + s * 0.46f),
        Offset(center.x - s * 0.36f, center.y + s * 0.1f),
    )
    drawPath(shield, accent.darken(0.35f))
    drawPath(shield, accent, style = Stroke(width = s * 0.06f))
    when (race) {
        Race.IMPERIUM -> {
            // орлиные крылья и штандарт
            drawLine(accent.lighten(0.4f), Offset(center.x, center.y + s * 0.28f), Offset(center.x, center.y - s * 0.28f), strokeWidth = s * 0.07f)
            drawPath(
                poly(
                    Offset(center.x, center.y - s * 0.22f),
                    Offset(center.x - s * 0.26f, center.y - s * 0.02f),
                    Offset(center.x, center.y + s * 0.02f),
                ),
                accent.lighten(0.35f),
            )
            drawPath(
                poly(
                    Offset(center.x, center.y - s * 0.22f),
                    Offset(center.x + s * 0.26f, center.y - s * 0.02f),
                    Offset(center.x, center.y + s * 0.02f),
                ),
                accent.lighten(0.2f),
            )
        }
        Race.HORDE -> {
            // секира
            drawLine(Pal.dirt, Offset(center.x - s * 0.02f, center.y + s * 0.3f), Offset(center.x + s * 0.06f, center.y - s * 0.3f), strokeWidth = s * 0.07f)
            drawPath(
                poly(
                    Offset(center.x + s * 0.04f, center.y - s * 0.26f),
                    Offset(center.x + s * 0.3f, center.y - s * 0.12f),
                    Offset(center.x + s * 0.04f, center.y + s * 0.04f),
                ),
                accent.lighten(0.4f),
            )
            drawPath(
                poly(
                    Offset(center.x + s * 0.02f, center.y - s * 0.26f),
                    Offset(center.x - s * 0.24f, center.y - s * 0.12f),
                    Offset(center.x + s * 0.02f, center.y + s * 0.04f),
                ),
                accent.lighten(0.2f),
            )
        }
        Race.SYLVAN -> {
            // дуб и подкова
            drawCircle(accent.lighten(0.35f), s * 0.17f, Offset(center.x, center.y - s * 0.1f))
            drawCircle(accent.lighten(0.2f), s * 0.13f, Offset(center.x - s * 0.17f, center.y + s * 0.02f))
            drawCircle(accent.lighten(0.25f), s * 0.13f, Offset(center.x + s * 0.17f, center.y + s * 0.02f))
            drawLine(Pal.dirt, Offset(center.x, center.y + s * 0.06f), Offset(center.x, center.y + s * 0.3f), strokeWidth = s * 0.06f)
        }
    }
}

@Composable
private fun ChoiceRow(title: String, subtitle: String, selected: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(13.dp))
            .background(if (selected) Pal.gold.copy(alpha = 0.14f) else Pal.surfaceLo)
            .border(1.dp, if (selected) Pal.gold else Pal.outlineSoft, RoundedCornerShape(13.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(16.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(if (selected) Pal.gold else Color.Transparent)
                .border(1.5.dp, if (selected) Pal.gold else Pal.outline, RoundedCornerShape(8.dp)),
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                title,
                style = MaterialTheme.typography.titleSmall,
                color = if (selected) Pal.gold else Pal.text,
            )
            if (subtitle.isNotEmpty()) {
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = Pal.textDim)
            }
        }
    }
}

// --------------------------------------------------------------------------
// Итоги партии
// --------------------------------------------------------------------------

@Composable
fun ResultScreen(vm: GameViewModel) {
    val g = vm.game ?: return
    val winner = g.playerOrNull(g.winnerId)
    val youWon = winner?.human == true
    val scroll = rememberScrollState()

    Column(
        Modifier
            .fillMaxSize()
            .background(Pal.screenGradient)
            .windowInsetsPadding(WindowInsets.systemBars)
            .verticalScroll(scroll)
            .padding(horizontal = 20.dp),
    ) {
        Spacer(Modifier.height(40.dp))
        Canvas(Modifier.fillMaxWidth().height(90.dp)) {
            drawBanner(
                Offset(size.width / 2f - 40f, size.height),
                size.height * 0.9f,
                if (youWon) Pal.gold else Pal.danger,
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(
            if (youWon) "ПОБЕДА" else "ПАРТИЯ ОКОНЧЕНА",
            style = MaterialTheme.typography.displaySmall,
            color = if (youWon) Pal.gold else Pal.danger,
        )
        Text(
            if (youWon) g.winReason else "Победил ${winner?.name ?: "никто"} — ${g.winReason}",
            style = MaterialTheme.typography.bodyMedium,
            color = Pal.textDim,
        )

        Spacer(Modifier.height(24.dp))
        SectionTitle("Итоговая таблица")
        Spacer(Modifier.height(10.dp))
        g.leaderboard().forEachIndexed { i, (p, score) ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (p.human) Pal.gold.copy(alpha = 0.10f) else Pal.surfaceLo)
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${i + 1}",
                    style = MaterialTheme.typography.titleMedium,
                    color = if (i == 0) Pal.gold else Pal.textFaint,
                    modifier = Modifier.width(26.dp),
                )
                Column(Modifier.weight(1f)) {
                    Text(p.name, style = MaterialTheme.typography.titleSmall, color = Pal.text)
                    Text(
                        "${p.race.title} · деревень ${g.villagesOf(p.id).size} · убито ${p.kills}, потеряно ${p.losses}",
                        style = MaterialTheme.typography.labelSmall,
                        color = Pal.textDim,
                    )
                }
                Text("$score", style = MaterialTheme.typography.titleMedium, color = Pal.text)
            }
        }

        Spacer(Modifier.height(26.dp))
        ActionButton("Новая партия", Modifier.fillMaxWidth()) { vm.abandonGame() }
        Spacer(Modifier.height(10.dp))
        GhostButton("В главное меню", Modifier.fillMaxWidth()) { vm.abandonGame() }
        Spacer(Modifier.height(40.dp))
    }
}
