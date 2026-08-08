package com.robesthud.tribesera.engine

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.random.Random

/** Создание новой партии: карта, соперники, стартовые деревни и оазисы. */
object WorldGen {

    private val botNames = listOf(
        "Ардарих", "Брунхильда", "Виндекс", "Кассий Луп", "Морриган", "Тевтобод",
        "Сегимер", "Эпона", "Гундобад", "Луций Север", "Бренн", "Радагайс",
    )

    fun create(settings: GameSettings): GameState {
        val seed = if (settings.seed != 0L) settings.seed else System.nanoTime()
        val rnd = Random(seed)
        Engine.reseed(seed)
        Ai.reseed(seed)
        val g = GameState(settings.copy(seed = seed))

        val total = settings.opponents + 1
        // Идентификаторы игроков живут отдельно от идентификаторов объектов:
        // живой игрок всегда 0, боты — 1..N.
        g.players += Player(
            id = 0,
            name = settings.playerName.ifBlank { "Вождь" },
            race = settings.race,
            human = true,
            colorIndex = 0,
        )

        val names = botNames.shuffled(rnd)
        for (i in 1 until total) {
            val personality = when {
                i == 1 && settings.difficulty != Difficulty.EASY -> Personality.STRATEGIST
                i % 3 == 0 -> Personality.RUSHER
                i % 3 == 1 -> Personality.ECONOMIST
                else -> Personality.BALANCED
            }
            g.players += Player(
                id = i,
                name = names[(i - 1) % names.size],
                race = Race.entries[(i + settings.race.ordinal) % Race.entries.size],
                human = false,
                colorIndex = i % 8,
                personality = personality,
                thinkCooldown = rnd.nextDouble() * settings.difficulty.aiPeriod,
                warCooldown = 30.0 + rnd.nextDouble() * 60.0,
            )
        }

        placeVillages(g, rnd, total)
        placeOases(g, rnd)
        return g
    }

    private fun placeVillages(g: GameState, rnd: Random, total: Int) {
        val size = Balance.MAP_SIZE
        val center = size / 2
        val radius = (size / 2.0) * 0.62
        val startAngle = rnd.nextDouble() * 2 * PI

        for (i in 0 until total) {
            val angle = startAngle + 2 * PI * i / total
            var x = (center + cos(angle) * radius).roundToInt().coerceIn(1, size - 2)
            var y = (center + sin(angle) * radius).roundToInt().coerceIn(1, size - 2)
            // сдвигаем, если клетка уже занята
            var guard = 0
            while (g.villageAt(x, y) != null && guard++ < 50) {
                x = (x + rnd.nextInt(-1, 2)).coerceIn(1, size - 2)
                y = (y + rnd.nextInt(-1, 2)).coerceIn(1, size - 2)
            }
            val v = Engine.foundVillage(g, g.players[i].id, x, y, fieldStart = 2)
            v.capital = true
            for (r in 0..3) v.stock[r] = 1000.0
        }
    }

    private fun placeOases(g: GameState, rnd: Random) {
        val size = Balance.MAP_SIZE
        val wanted = (size * size / 16).coerceAtLeast(18)
        var placed = 0
        var guard = 0
        while (placed < wanted && guard++ < 4000) {
            val x = rnd.nextInt(size)
            val y = rnd.nextInt(size)
            if (g.villageAt(x, y) != null || g.oasisAt(x, y) != null) continue
            // Не лепим оазис вплотную к чужой столице.
            if (g.villages.any { dist(it.x, it.y, x, y) < 2.0 }) continue

            val double = rnd.nextDouble() < 0.22
            val r1 = rnd.nextInt(4)
            val r2 = if (double) (r1 + 1 + rnd.nextInt(3)) % 4 else -1
            val bonus = if (double) 25 else listOf(25, 25, 50).random(rnd)
            val o = Oasis(
                id = g.newId(),
                x = x, y = y,
                res = r1,
                bonusPct = bonus,
                res2 = r2,
                wildDefense = 250.0 + rnd.nextDouble() * 600.0 + bonus * 8.0,
                stock = rnd.nextDouble() * 800.0,
            )
            g.oases += o
            placed++
        }
    }
}
