package com.robesthud.tribesera.ui

import android.app.Application
import android.os.SystemClock
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.robesthud.tribesera.engine.Denied
import com.robesthud.tribesera.engine.Engine
import com.robesthud.tribesera.engine.GameSettings
import com.robesthud.tribesera.engine.GameState
import com.robesthud.tribesera.engine.SaveIo
import com.robesthud.tribesera.engine.Village
import com.robesthud.tribesera.engine.WorldGen
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.min

enum class Screen { MENU, GAME, RESULT }

enum class Tab(val title: String) {
    FIELDS("Поля"),
    VILLAGE("Деревня"),
    MAP("Карта"),
}

/**
 * Держит партию и крутит игровой цикл. Состояние мира — обычный объект,
 * поэтому перерисовку запускает счётчик [frame]: любой экран, который читает
 * мир, сначала читает счётчик и тем самым подписывается на такты.
 */
class GameViewModel(app: Application) : AndroidViewModel(app) {

    var screen by mutableStateOf(Screen.MENU)
        private set

    var game: GameState? = null
        private set

    var frame by mutableIntStateOf(0)
        private set

    var tab by mutableStateOf(Tab.VILLAGE)

    var selectedVillageId by mutableIntStateOf(-1)

    var message by mutableStateOf<String?>(null)

    var paused by mutableStateOf(false)

    /** Клетка карты, на которую нужно центрироваться при открытии вкладки. */
    var mapFocus by mutableStateOf<Pair<Int, Int>?>(null)

    private var loop: Job? = null
    private var lastTick = 0L
    private var sinceSave = 0.0

    val hasSave: Boolean get() = SaveIo.hasSave(getApplication())

    // ------------------------------------------------------------------ жизнь

    fun newGame(settings: GameSettings) {
        val g = WorldGen.create(settings)
        game = g
        selectedVillageId = g.villagesOf(0).firstOrNull()?.id ?: -1
        tab = Tab.VILLAGE
        screen = Screen.GAME
        paused = false
        bump()
        startLoop()
    }

    fun continueGame(): Boolean {
        val g = SaveIo.load(getApplication()) ?: return false
        game = g
        selectedVillageId = g.villagesOf(0).firstOrNull()?.id ?: -1
        screen = if (g.over) Screen.RESULT else Screen.GAME
        paused = false
        bump()
        startLoop()
        return true
    }

    fun abandonGame() {
        loop?.cancel()
        loop = null
        SaveIo.clear(getApplication())
        game = null
        screen = Screen.MENU
        bump()
    }

    fun backToMenu() {
        loop?.cancel()
        loop = null
        game?.let { SaveIo.save(getApplication(), it) }
        screen = Screen.MENU
        bump()
    }

    fun saveNow() {
        game?.let { SaveIo.save(getApplication(), it) }
    }

    private fun startLoop() {
        loop?.cancel()
        lastTick = SystemClock.elapsedRealtime()
        loop = viewModelScope.launch {
            while (isActive) {
                delay(90)
                val now = SystemClock.elapsedRealtime()
                val dt = (now - lastTick) / 1000.0
                lastTick = now
                val g = game ?: continue
                if (paused || g.over) {
                    if (g.over && screen == Screen.GAME) {
                        screen = Screen.RESULT
                        saveNow()
                    }
                    continue
                }
                simulate(g, dt)
                sinceSave += dt
                if (sinceSave > 12.0) {
                    sinceSave = 0.0
                    saveNow()
                }
                bump()
            }
        }
    }

    /**
     * Догоняем реальное время кусками: пока приложение было свёрнуто, мир
     * продолжал жить, но считать один гигантский такт нельзя — бой и ИИ
     * рассчитаны на короткие интервалы.
     */
    private fun simulate(g: GameState, rawDt: Double) {
        var left = min(rawDt, 20 * 60.0)
        var guard = 0
        while (left > 0.0 && guard++ < 2000 && !g.over) {
            val step = min(left, 0.5)
            Engine.tick(g, step)
            left -= step
        }
        if (g.over && screen == Screen.GAME) {
            screen = Screen.RESULT
            saveNow()
        }
    }

    fun bump() {
        frame++
    }

    // ---------------------------------------------------------------- удобства

    val villages: List<Village>
        get() = game?.villagesOf(0) ?: emptyList()

    val village: Village?
        get() {
            val g = game ?: return null
            return g.village(selectedVillageId)?.takeIf { it.ownerId == 0 } ?: g.villagesOf(0).firstOrNull()
        }

    fun selectVillage(id: Int) {
        selectedVillageId = id
        bump()
    }

    fun focusMap(x: Int, y: Int) {
        mapFocus = x to y
        tab = Tab.MAP
        bump()
    }

    /** Показывает причину отказа, если действие не прошло. */
    fun report(result: Denied) {
        if (!result.ok) message = result.reason
        bump()
    }

    fun clearMessage() {
        message = null
    }

    override fun onCleared() {
        loop?.cancel()
        saveNow()
        super.onCleared()
    }
}

/** Читает счётчик кадров и отдаёт мир — вызывать в начале любого игрового экрана. */
@Composable
fun GameViewModel.observe(): GameState? {
    @Suppress("UNUSED_EXPRESSION")
    frame
    return game
}
