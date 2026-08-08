package com.robesthud.tribesera.engine

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.roundToInt

/**
 * Прогон целой партии без интерфейса. Тест ловит две вещи, которые иначе
 * вылезли бы только на телефоне: падения в движке и перекошенный баланс —
 * когда за отведённое время никто не успевает ничего построить или, наоборот,
 * экономика взрывается на первой минуте.
 */
class SimulationTest {

    private fun runSession(
        difficulty: Difficulty,
        length: SessionLength,
        opponents: Int,
        playHuman: Boolean = true,
        seed: Long = 12345L,
    ): GameState {
        val g = WorldGen.create(
            GameSettings(
                playerName = "Тест",
                race = Race.IMPERIUM,
                difficulty = difficulty,
                length = length,
                opponents = opponents,
                seed = seed,
            ),
        )
        var elapsed = 0.0
        while (!g.over && elapsed < length.seconds + 5.0) {
            Engine.tick(g, 0.5)
            elapsed += 0.5
            if (playHuman && (elapsed % 3.0) < 0.5) humanPolicy(g)
        }
        return g
    }

    /**
     * Простейшая политика за живого игрока: держать зерно в плюсе, расширять
     * склады, тянуть поля и понемногу нанимать войска. Это заодно проверяет,
     * что публичный API действий работает так, как им пользуется интерфейс.
     */
    private fun humanPolicy(g: GameState) {
        for (v in g.villagesOf(0)) {
            if (v.buildQueue.size < Engine.queueCapacity(g.raceOf(0))) {
                if (g.netOutput(v, Res.CROP) < 2.0) {
                    val slot = v.fieldType.indices
                        .filter { v.fieldType[it] == Res.CROP.ordinal }
                        .minByOrNull { v.fieldLevel[it] }
                    if (slot != null && Engine.upgradeField(g, v, slot).ok) continue
                }
                var stored = false
                for (r in RES) {
                    if (v.stock[r.ordinal] > v.capOf(r) * 0.85) {
                        val type = if (r == Res.CROP) BuildingType.GRANARY else BuildingType.WAREHOUSE
                        val existing = v.slotType.indices
                            .filter { v.slotType[it] == type.ordinal }
                            .maxByOrNull { v.slotLevel[it] }
                        stored = if (existing != null) {
                            Engine.upgradeBuilding(g, v, existing).ok
                        } else {
                            val free = (0 until Balance.SLOT_RALLY).firstOrNull { v.slotType[it] < 0 }
                            free != null && Engine.build(g, v, free, type).ok
                        }
                        if (stored) break
                    }
                }
                if (stored) continue
                if (v.level(BuildingType.MAIN) < 8) {
                    val slot = v.slotOf(BuildingType.MAIN)
                    if (slot >= 0 && Engine.upgradeBuilding(g, v, slot).ok) continue
                }
                if (v.level(BuildingType.ACADEMY) < 1) {
                    val free = (0 until Balance.SLOT_RALLY).firstOrNull { v.slotType[it] < 0 }
                    if (free != null && Engine.build(g, v, free, BuildingType.ACADEMY).ok) continue
                }
                if (v.level(BuildingType.BARRACKS) < 5) {
                    val slot = v.slotOf(BuildingType.BARRACKS)
                    val ok = if (slot >= 0) {
                        Engine.upgradeBuilding(g, v, slot).ok
                    } else {
                        val free = (0 until Balance.SLOT_RALLY).firstOrNull { v.slotType[it] < 0 }
                        free != null && Engine.build(g, v, free, BuildingType.BARRACKS).ok
                    }
                    if (ok) continue
                }
                val weakest = v.fieldLevel.indices.minByOrNull { v.fieldLevel[it] }
                if (weakest != null) Engine.upgradeField(g, v, weakest)
            }
            // Немного войск, когда склады заполняются.
            if (v.trainQueue.isEmpty() && v.stock[0] > v.capOf(Res.WOOD) * 0.5) {
                val unit = Units.of(g.raceOf(0)).firstOrNull { Engine.unitUnlocked(v, it) && it.kind == UnitKind.INFANTRY }
                if (unit != null) Engine.train(g, v, unit.id, 10)
            }
        }
    }

    @Test
    fun sessionEndsWithAWinner() {
        val g = runSession(Difficulty.NORMAL, SessionLength.MEDIUM, 5)
        assertTrue("партия должна закончиться за отведённое время", g.over)
        assertTrue("должен быть победитель", g.winnerId >= 0)
        assertTrue("должна быть причина победы", g.winReason.isNotBlank())
        val human = g.human
        println(
            "Финиш на ${(g.time / 60).roundToInt()}-й минуте: победил " +
                "${g.playerOrNull(g.winnerId)?.name} — ${g.winReason}",
        )
        println(
            "Живой игрок: деревень ${g.villagesOf(0).size}, очки ${g.score(0)}, " +
                "убито ${human.kills}, потеряно ${human.losses}, отчётов ${g.reports.size}",
        )
    }

    @Test
    fun economyGrowsToSensibleNumbers() {
        val g = runSession(Difficulty.NORMAL, SessionLength.MEDIUM, 5)
        val human = g.villagesOf(0)
        assertTrue("живой игрок не должен остаться без деревень на обычной сложности", human.isNotEmpty())

        val capital = human.first()
        val avgField = capital.fieldLevel.average()
        val main = capital.level(BuildingType.MAIN)
        println("Поля в среднем: ${"%.1f".format(avgField)}, главное здание: $main")
        println("Склад: ${capital.storageCap().roundToInt()}, население: ${capital.population()}")

        // Час игры должен приводить к заметно развитой деревне, но не к потолку.
        assertTrue("поля должны вырасти минимум до 6 уровня в среднем, было $avgField", avgField >= 6.0)
        assertTrue("поля не должны упираться в максимум — иначе баланс слишком щедрый", avgField < 19.0)
        assertTrue("главное здание должно вырасти", main >= 5)
    }

    @Test
    fun botsBuildAndFight() {
        val g = runSession(Difficulty.HARD, SessionLength.MEDIUM, 5)
        val bots = g.players.filter { !it.human }
        val built = bots.count { p -> g.villagesOf(p.id).any { it.level(BuildingType.MAIN) >= 5 } }
        val fighting = g.players.sumOf { it.kills }
        println("Ботов с развитой столицей: $built из ${bots.size}, всего погибло войск: $fighting")
        for (p in g.players) {
            val army = g.villagesOf(p.id).sumOf { v -> v.troops.sum() }
            val cap = g.villagesOf(p.id).firstOrNull()
            val levels = if (cap == null) "" else listOf(
                BuildingType.MAIN, BuildingType.WAREHOUSE, BuildingType.ACADEMY,
                BuildingType.BARRACKS, BuildingType.RESIDENCE, BuildingType.WALL,
            ).joinToString(" ") { "${it.title.take(4)}${cap.level(it)}" }
            println(
                "  ${p.name} (${p.personality.title}, ${p.race.title}): " +
                    "деревень ${g.villagesOf(p.id).size}, войск $army, " +
                    "очки ${g.score(p.id)}, убил ${p.kills}, потерял ${p.losses} | " +
                    "поля ${"%.1f".format(cap?.fieldLevel?.average() ?: 0.0)} | $levels",
            )
        }
        assertTrue("боты должны развивать столицы", built >= bots.size / 2)
        assertTrue("на сложной партии должны быть бои", fighting > 0)
    }

    @Test
    fun resourcesStayWithinBounds() {
        val g = runSession(Difficulty.BRUTAL, SessionLength.SHORT, 6)
        println(
            "Беспощадная 40-минутка: у игрока ${g.villagesOf(0).size} деревень, " +
                "победитель — ${g.playerOrNull(g.winnerId)?.name} (${g.winReason})",
        )
        for (v in g.villages) {
            for (r in RES) {
                val s = v.stock[r.ordinal]
                assertTrue("${v.name}: ${r.title} = $s", s >= -0.001)
                assertTrue("${v.name}: ${r.title} превысил склад", s <= v.capOf(r) + 1.0)
                assertTrue("${v.name}: ${r.title} — NaN", !s.isNaN())
            }
        }
    }

    @Test
    fun battleFavoursStrengthAndRaidsSpare() {
        val attacker = emptyTroops()
        attacker[Units.of(Race.HORDE).first().id] = 500 // дубинщики
        val defender = emptyTroops()
        defender[Units.of(Race.IMPERIUM)[1].id] = 40 // преторианцы

        val storm = Combat.resolve(
            attacker, Race.HORDE, 0,
            listOf(DefenderGroup(1, defender.toMutableList())),
            Race.IMPERIUM, wallLevel = 0, raid = false,
        )
        assertTrue("численный перевес должен решать", storm.attackerWon)
        assertEquals("в штурме проигравший теряет всё", 40, storm.defenderLosses[0].sum())

        val raid = Combat.resolve(
            attacker, Race.HORDE, 0,
            listOf(DefenderGroup(1, defender.toMutableList())),
            Race.IMPERIUM, wallLevel = 0, raid = true,
        )
        assertTrue("набег оставляет часть обороны в живых", raid.defenderLosses[0].sum() < 40)
    }

    @Test
    fun wallStrengthensDefence() {
        val attacker = emptyTroops()
        attacker[Units.of(Race.HORDE)[2].id] = 120 // секирщики
        val defender = emptyTroops()
        defender[Units.of(Race.IMPERIUM)[1].id] = 60

        val noWall = Combat.resolve(
            attacker, Race.HORDE, 0,
            listOf(DefenderGroup(1, defender.toMutableList())),
            Race.IMPERIUM, wallLevel = 0, raid = false,
        )
        val withWall = Combat.resolve(
            attacker, Race.HORDE, 0,
            listOf(DefenderGroup(1, defender.toMutableList())),
            Race.IMPERIUM, wallLevel = 20, raid = false,
        )
        assertTrue(
            "стена 20 уровня у Империи должна дать +60% обороны",
            withWall.defensePower > noWall.defensePower * 1.5,
        )
    }

    @Test
    fun saveRoundTripKeepsState() {
        val g = WorldGen.create(GameSettings(opponents = 4, seed = 777L))
        repeat(600) { Engine.tick(g, 0.5) }

        val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
        val text = json.encodeToString(GameState.serializer(), g)
        val restored = json.decodeFromString(GameState.serializer(), text)

        assertEquals(g.time, restored.time, 0.0001)
        assertEquals(g.villages.size, restored.villages.size)
        assertEquals(g.score(0), restored.score(0))
        assertEquals(
            g.villages.first().slotLevel.toList(),
            restored.villages.first().slotLevel.toList(),
        )
        // Восстановленный мир должен продолжать жить.
        repeat(100) { Engine.tick(restored, 0.5) }
        assertTrue(restored.time > g.time)
    }

    @Test
    fun unitCatalogIsConsistent() {
        assertEquals(Race.entries.size * UNITS_PER_RACE, Units.count)
        for (race in Race.entries) {
            val roster = Units.of(race)
            assertEquals("у народа ${race.title} должно быть $UNITS_PER_RACE юнитов", UNITS_PER_RACE, roster.size)
            assertEquals("последний юнит — поселенец", UnitKind.SETTLER, roster.last().kind)
            assertEquals("предпоследний — вождь", UnitKind.CHIEF, roster[UNITS_PER_RACE - 2].kind)
            assertTrue("должен быть хотя бы один таран", roster.any { it.isRam })
            assertTrue("должна быть хотя бы одна катапульта", roster.any { it.isCatapult })
            for (u in roster) {
                assertTrue("${u.title}: цена должна быть положительной", u.cost.total > 0)
                assertTrue("${u.title}: время найма должно быть положительным", u.trainSec > 0)
            }
        }
    }
}
