package com.robesthud.tribesera.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Castle
import androidx.compose.material.icons.filled.Grass
import androidx.compose.material.icons.filled.Map
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.Tab
import com.robesthud.tribesera.ui.components.TopBar
import com.robesthud.tribesera.ui.observe
import com.robesthud.tribesera.ui.theme.Pal
import kotlinx.coroutines.delay

@Composable
fun GameScreen(vm: GameViewModel) {
    val g = vm.observe() ?: return
    val v = vm.village ?: return

    var reports by remember { mutableStateOf(false) }
    var board by remember { mutableStateOf(false) }
    var pause by remember { mutableStateOf(false) }
    val unread = g.reports.count { it.ownerId == 0 && !it.read }

    Scaffold(
        containerColor = Pal.bg,
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            Column(Modifier.windowInsetsPadding(WindowInsets.statusBars)) {
                TopBar(
                    vm = vm,
                    g = g,
                    v = v,
                    unreadReports = unread,
                    onReports = { reports = true },
                    onLeaderboard = { board = true },
                    onMenu = { pause = true; vm.paused = true },
                )
            }
        },
        bottomBar = {
            NavigationBar(
                containerColor = Color(0xFF101C17),
                modifier = Modifier.windowInsetsPadding(WindowInsets.navigationBars),
            ) {
                for (t in Tab.entries) {
                    NavigationBarItem(
                        selected = vm.tab == t,
                        onClick = { vm.tab = t },
                        icon = {
                            Icon(
                                when (t) {
                                    Tab.FIELDS -> Icons.Filled.Grass
                                    Tab.VILLAGE -> Icons.Filled.Castle
                                    Tab.MAP -> Icons.Filled.Map
                                },
                                contentDescription = t.title,
                            )
                        },
                        label = { Text(t.title, style = MaterialTheme.typography.labelMedium) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Color(0xFF201604),
                            selectedTextColor = Pal.gold,
                            indicatorColor = Pal.gold,
                            unselectedIconColor = Pal.textFaint,
                            unselectedTextColor = Pal.textFaint,
                        ),
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (vm.tab) {
                Tab.FIELDS -> FieldsScreen(vm, g, v)
                Tab.VILLAGE -> VillageScreen(vm, g, v)
                Tab.MAP -> MapScreen(vm, g, v)
            }
            Toast(vm, Modifier.align(Alignment.BottomCenter))
        }
    }

    if (reports) ReportsSheet(vm, g) { reports = false }
    if (board) LeaderboardSheet(g) { board = false }
    if (pause) {
        PauseDialog(
            vm = vm,
            onResume = { pause = false; vm.paused = false },
        )
    }
}

/** Всплывающее сообщение об отказе — исчезает само. */
@Composable
private fun Toast(vm: GameViewModel, modifier: Modifier) {
    val msg = vm.message
    LaunchedEffect(msg) {
        if (msg != null) {
            delay(2200)
            vm.clearMessage()
        }
    }
    AnimatedVisibility(msg != null, modifier = modifier, enter = fadeIn(), exit = fadeOut()) {
        Box(
            Modifier
                .padding(16.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Color(0xE61E332B))
                .padding(horizontal = 16.dp, vertical = 11.dp),
        ) {
            Text(msg ?: "", style = MaterialTheme.typography.bodyMedium, color = Pal.warn)
        }
    }
}

@Composable
private fun PauseDialog(vm: GameViewModel, onResume: () -> Unit) {
    val g = vm.game
    AlertDialog(
        onDismissRequest = onResume,
        containerColor = Pal.surface,
        titleContentColor = Pal.text,
        textContentColor = Pal.textDim,
        title = { Text("Пауза") },
        text = {
            Column {
                Text("Мир остановлен: ни ресурсы, ни боты не двигаются.")
                Spacer(Modifier.height(10.dp))
                if (g != null) {
                    Text(
                        "Партия: ${g.settings.length.title}, сложность «${g.settings.difficulty.title}», " +
                            "соперников ${g.settings.opponents}.",
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onResume) {
                Text("Продолжить", color = Pal.gold)
            }
        },
        dismissButton = {
            Column {
                TextButton(onClick = { vm.saveNow(); vm.backToMenu() }) {
                    Text("Сохранить и выйти", color = Pal.textDim)
                }
                TextButton(onClick = { vm.abandonGame() }) {
                    Text("Сдаться и начать заново", color = Pal.danger)
                }
            }
        },
    )
}
