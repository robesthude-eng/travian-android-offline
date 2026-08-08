package com.robesthud.tribesera.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Проверки отдельных механик, до которых обычный прогон партии может и не
 * дойти: основание деревни, захват вождём, оазисы, голод и осадные орудия.
 */
class FeatureTest {

    private fun freshGame(seed: Long = 4242L): GameState =
        WorldGen.create(GameSettings(playerName = "Тест", opponents = 3, seed = seed))

    private fun advance(g: GameState, seconds: Double) {
        var t = 0.0
        while (t < seconds) {
            Engine.tick(g, 0.5)
            t += 0.5
        }
    }

    /** Крутит мир, пока не выполнится условие; возвращает false по таймауту. */
    private fun advanceUntil(g: GameState, limit: Double, predicate: () -> Boolean): Boolean {
        var t = 0.0
        while (t < limit) {
            if (predicate()) return true
            Engine.tick(g, 0.5)
            t += 0.5
        }
        return predicate()
    }

    /** Добыча, с которой войско возвращается домой. */
    private fun lootOnTheWayBack(g: GameState): Double =
        g.movements.filter { it.ownerId == 0 && it.kind == MoveKind.RETURN }.sumOf { it.loot.sum() }

    private fun freeCellNear(g: GameState, v: Village): Pair<Int, Int> {
        for (r in 1..5) {
            for (dx in -r..r) for (dy in -r..r) {
                val x = v.x + dx
                val y = v.y + dy
                if (x !in 0 until Balance.MAP_SIZE || y !in 0 until Balance.MAP_SIZE) continue
                if (g.villageAt(x, y) != null || g.oasisAt(x, y) != null) continue
                return x to y
            }
        }
        error("на карте не нашлось свободной клетки")
    }

    @Test
    fun settlersFoundANewVillage() {
        val g = freshGame()
        val home = g.villagesOf(0).first()
        val settler = Units.of(g.raceOf(0)).first { it.kind == UnitKind.SETTLER }
        home.troops[settler.id] = Units.SETTLERS_TO_FOUND

        val spot = freeCellNear(g, home)
        val army = emptyTroops()
        army[settler.id] = Units.SETTLERS_TO_FOUND

        val sent = Engine.send(g, home, spot.first, spot.second, MoveKind.SETTLE, army)
        assertTrue("поход поселенцев должен уйти: ${sent.reason}", sent.ok)
        assertEquals("поселенцы должны покинуть деревню", 0, home.troops[settler.id])

        advance(g, 900.0)
        val founded = g.villageAt(spot.first, spot.second)
        assertNotNull("на клетке должна появиться деревня", founded)
        assertEquals("новая деревня принадлежит игроку", 0, founded!!.ownerId)
        assertEquals("у игрока теперь две деревни", 2, g.villagesOf(0).size)
        assertTrue("новая деревня не столица", !founded.capital)
        assertTrue("в новой деревне есть главное здание", founded.level(BuildingType.MAIN) >= 1)
    }

    @Test
    fun chiefCapturesAVillage() {
        val g = freshGame()
        val home = g.villagesOf(0).first()
        val victim = g.villages.first { it.ownerId != 0 }
        victim.troops.indices.forEach { victim.troops[it] = 0 }

        val race = g.raceOf(0)
        val chief = Units.of(race).first { it.kind == UnitKind.CHIEF }
        val fighter = Units.of(race).first { it.kind == UnitKind.INFANTRY }

        var guard = 0
        while (victim.ownerId != 0 && guard++ < 10) {
            victim.troops.indices.forEach { victim.troops[it] = 0 }
            home.troops[fighter.id] = 400
            home.troops[chief.id] = 3
            val army = emptyTroops()
            army[fighter.id] = 400
            army[chief.id] = 3
            val sent = Engine.send(g, home, victim.x, victim.y, MoveKind.ATTACK, army)
            assertTrue("штурм должен уйти: ${sent.reason}", sent.ok)
            // Ждём ровно прибытия: лояльность восстанавливается со временем,
            // и растянутая пауза свела бы эффект вождей на нет.
            advanceUntil(g, 900.0) { g.movements.none { m -> m.ownerId == 0 && m.kind == MoveKind.ATTACK } }
        }

        assertEquals("после нескольких визитов вождей деревня меняет хозяина", 0, victim.ownerId)
        assertTrue("захваченная деревня начинает с невысокой лояльности", victim.loyalty <= 60.0)
        assertTrue("прежний гарнизон уничтожен", victim.troops.isEmptyArmy())
    }

    @Test
    fun raidingAnOasisClearsItAndAnnexes() {
        val g = freshGame()
        val home = g.villagesOf(0).first()
        // Главное здание 5 уровня даёт право удерживать один оазис.
        val mainSlot = home.slotOf(BuildingType.MAIN)
        home.slotLevel[mainSlot] = 5

        val oasis = g.oases.minByOrNull { dist(home.x, home.y, it.x, it.y) }!!
        val fighter = Units.of(g.raceOf(0)).first { it.kind == UnitKind.INFANTRY }
        home.troops[fighter.id] = 900
        val army = emptyTroops()
        army[fighter.id] = 900

        val sent = Engine.send(g, home, oasis.x, oasis.y, MoveKind.RAID, army)
        assertTrue("набег на оазис должен уйти: ${sent.reason}", sent.ok)
        advance(g, 2000.0)

        assertEquals("оазис должен достаться деревне игрока", home.id, oasis.ownerVillage)
        assertTrue("оазис числится за деревней", home.oasisIds.contains(oasis.id))
        val bonus = g.oasisBonus(home, RES[oasis.res])
        assertTrue("бонус оазиса должен применяться к добыче", bonus > 0.0)
    }

    @Test
    fun starvationKillsTroopsWhenGranaryIsEmpty() {
        val g = freshGame()
        val v = g.villagesOf(0).first()
        val fighter = Units.of(g.raceOf(0)).first { it.kind == UnitKind.INFANTRY }
        // Заведомо больше ртов, чем может прокормить деревня.
        v.troops[fighter.id] = 20000
        v.stock[Res.CROP.ordinal] = 0.0

        assertTrue("баланс зерна должен быть отрицательным", g.netOutput(v, Res.CROP) < 0)
        val before = v.troops[fighter.id]
        advance(g, 60.0)
        assertTrue("голод должен сокращать войско", v.troops[fighter.id] < before)
    }

    @Test
    fun ramsBreakTheWall() {
        val race = Race.HORDE
        val ram = Units.of(race).first { it.isRam }
        val attacker = emptyTroops()
        attacker[ram.id] = 120
        attacker[Units.of(race)[2].id] = 800

        val res = Combat.resolve(
            attacker, race, 0,
            listOf(DefenderGroup(1, emptyTroops())),
            Race.IMPERIUM, wallLevel = 12, raid = false,
        )
        assertTrue("тараны должны снести часть стены", res.wallLevelsDestroyed > 0)
        assertTrue("стена не может уйти в минус", res.wallLevelsDestroyed <= 12)
    }

    @Test
    fun catapultsDamageBuildings() {
        val race = Race.IMPERIUM
        val cat = Units.of(race).first { it.isCatapult }
        val attacker = emptyTroops()
        attacker[cat.id] = 60
        attacker[Units.of(race)[2].id] = 600

        val res = Combat.resolve(
            attacker, race, 0,
            listOf(DefenderGroup(1, emptyTroops())),
            Race.IMPERIUM, wallLevel = 0, raid = false,
            targetSlot = 3, targetSlotLevel = 8,
        )
        assertTrue("атака должна быть успешной", res.attackerWon)
        assertEquals("катапульты бьют по указанному слоту", 3, res.buildingHitSlot)
        assertTrue("здание должно пострадать", res.buildingLevelsDestroyed > 0)
    }

    @Test
    fun raidBringsLootHome() {
        val g = freshGame()
        val home = g.villagesOf(0).first()
        val victim = g.villages.first { it.ownerId != 0 }
        victim.troops.indices.forEach { victim.troops[it] = 0 }
        for (i in 0..3) victim.stock[i] = 1200.0
        for (i in 0..3) home.stock[i] = 0.0

        val fighter = Units.of(g.raceOf(0)).first { it.kind == UnitKind.INFANTRY }
        home.troops[fighter.id] = 200
        val army = emptyTroops()
        army[fighter.id] = 200

        assertTrue(Engine.send(g, home, victim.x, victim.y, MoveKind.RAID, army).ok)

        // Смотрим именно на обоз: склад жертвы к моменту проверки уже пополнят
        // её собственные поля, и сравнение «до/после» ничего не докажет.
        val returned = advanceUntil(g, 2000.0) { lootOnTheWayBack(g) > 0.0 }
        assertTrue("войско должно возвращаться с добычей", returned)
        assertTrue("обоз не может быть пустым", lootOnTheWayBack(g) > 100.0)

        advance(g, 2000.0)
        assertTrue("войско должно вернуться домой", home.troops[fighter.id] > 0)
        assertTrue("добыча должна лечь на склад", home.stock.sum() > 100.0)
    }

    @Test
    fun crannyHidesResourcesFromRaiders() {
        val g = freshGame()
        val home = g.villagesOf(0).first()
        val victim = g.villages.first { it.ownerId != 0 }
        victim.troops.indices.forEach { victim.troops[it] = 0 }
        // Ставим тайник высокого уровня и наполняем склад.
        val free = (0 until Balance.SLOT_RALLY).first { victim.slotType[it] < 0 }
        victim.slotType[free] = BuildingType.CRANNY.ordinal
        victim.slotLevel[free] = 10
        for (i in 0..3) victim.stock[i] = 800.0

        val hidden = victim.crannyHidden(g.raceOf(victim.ownerId))
        assertTrue("тайник 10 уровня должен прятать больше 800 каждого ресурса", hidden > 800.0)

        val fighter = Units.of(g.raceOf(0)).first { it.kind == UnitKind.INFANTRY }
        home.troops[fighter.id] = 300
        val army = emptyTroops()
        army[fighter.id] = 300

        assertTrue(Engine.send(g, home, victim.x, victim.y, MoveKind.RAID, army).ok)
        advanceUntil(g, 2000.0) { g.movements.any { m -> m.ownerId == 0 && m.kind == MoveKind.RETURN } }
        assertEquals("под тайником грабителям не достаётся ничего", 0.0, lootOnTheWayBack(g), 1.0)
    }

    @Test
    fun buildQueueRespectsRaceLimits() {
        val g = WorldGen.create(GameSettings(race = Race.IMPERIUM, opponents = 3, seed = 1L))
        val v = g.villagesOf(0).first()
        for (i in 0..3) v.stock[i] = 500000.0

        // Империя строит поле и здание одновременно, остальные — по очереди.
        assertEquals(4, Engine.queueCapacity(Race.IMPERIUM))
        assertEquals(3, Engine.queueCapacity(Race.HORDE))

        repeat(4) { Engine.upgradeField(g, v, it) }
        assertEquals("очередь не должна переполняться", 4, v.buildQueue.size)
        assertTrue("пятый заказ не влезает", Engine.upgradeField(g, v, 5) is Denied.QueueFull)
    }

    @Test
    fun cancellingRefundsMostOfTheCost() {
        val g = freshGame()
        val v = g.villagesOf(0).first()
        // Держимся ниже вместимости склада: возврат обрезается по ней, и на
        // переполненном складе «до» и «после» сравнивать нечего.
        for (i in 0..3) v.stock[i] = v.capOf(RES[i]) * 0.9
        val before = v.stock.sum()

        assertTrue(Engine.upgradeField(g, v, 0).ok)
        val afterPay = v.stock.sum()
        assertTrue("стройка должна списать ресурсы", afterPay < before)

        Engine.cancelJob(v, v.buildQueue.first())
        val afterRefund = v.stock.sum()
        assertTrue("возврат должен быть заметным", afterRefund > afterPay)
        assertTrue("но не полным — отмена стоит денег", afterRefund < before)
        assertTrue("очередь очищена", v.buildQueue.isEmpty())
    }

    @Test
    fun marketExchangesAtTheAdvertisedRate() {
        val g = freshGame()
        val v = g.villagesOf(0).first()
        val free = (0 until Balance.SLOT_RALLY).first { v.slotType[it] < 0 }
        v.slotType[free] = BuildingType.MARKET.ordinal
        v.slotLevel[free] = 10
        v.stock[Res.WOOD.ordinal] = 1000.0
        v.stock[Res.IRON.ordinal] = 0.0

        assertTrue(Engine.trade(g, v, Res.WOOD, Res.IRON, 500.0).ok)
        assertEquals(500.0, v.stock[Res.WOOD.ordinal], 0.001)
        assertEquals(500.0 * BuildingType.marketRate(10), v.stock[Res.IRON.ordinal], 0.001)
    }

    @Test
    fun requirementsBlockAdvancedBuildings() {
        val g = freshGame()
        val v = g.villagesOf(0).first()
        for (i in 0..3) v.stock[i] = 500000.0
        val free = (0 until Balance.SLOT_RALLY).first { v.slotType[it] < 0 }

        val denied = Engine.canBuild(g, v, free, BuildingType.WORKSHOP)
        assertTrue("мастерская требует академию 10", denied is Denied.Requirements)
        assertTrue(
            "текст требования должен называть здание",
            Engine.requirementsText(v, BuildingType.WORKSHOP)!!.contains("Академия"),
        )
    }
}
