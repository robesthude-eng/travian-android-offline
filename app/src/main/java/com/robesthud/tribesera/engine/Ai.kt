package com.robesthud.tribesera.engine

import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

/**
 * Оффлайновый соперник. Никакой сети и никаких запросов наружу: решения
 * принимает утилитарный планировщик, который каждые несколько секунд смотрит
 * на своё состояние, выбирает самое узкое место и вкладывается в него.
 *
 * Четыре характера ([Personality]) дают разный стиль игры, а сложность партии
 * меняет темп мышления, экономику и охоту до драки.
 */
object Ai {

    private var rnd = Random(0x5DEECE66DL)

    /** Партия детерминирована: один и тот же сид — один и тот же мир. */
    fun reseed(seed: Long) {
        rnd = Random(seed xor 0x5DEECE66DL)
    }

    /** Первые минуты партии боты не воюют — иначе старт превращается в лотерею. */
    private const val PEACE_TIME = 240.0

    /**
     * Дальше этого расстояния бот в поход не пойдёт. Значение подобрано под
     * размер карты: с любой стартовой позиции достижим любой соперник, иначе
     * крайние игроки выпадают из войны вовсе.
     */
    private const val MAX_MARCH = 18.0

    fun think(g: GameState, dt: Double) {
        val diff = g.settings.difficulty
        for (p in g.players) {
            if (p.human || p.defeated) continue

            p.thinkCooldown -= dt
            if (p.thinkCooldown <= 0.0) {
                p.thinkCooldown = diff.aiPeriod * (0.75 + rnd.nextDouble() * 0.5)
                for (v in g.villagesOf(p.id)) {
                    // Найм идёт первым: иначе стройка каждый раз выгребает казну
                    // подчистую и бот всю партию остаётся без армии.
                    manageTraining(g, p, v)
                    manageBuilding(g, p, v)
                }
                manageExpansion(g, p)
            }

            p.warCooldown -= dt
            if (p.warCooldown <= 0.0) {
                p.warCooldown = (40.0 / (diff.aiAggression * p.personality.raidWeight)) * (0.7 + rnd.nextDouble() * 0.6)
                if (g.time > PEACE_TIME) manageWar(g, p)
            }
        }
    }

    // ======================================================================
    // Строительство
    // ======================================================================

    private fun manageBuilding(g: GameState, p: Player, v: Village) {
        if (v.buildQueue.size >= Engine.queueCapacity(p.race)) return

        // 1. Голод важнее всего: без зерна армия тает сама собой.
        if (g.netOutput(v, Res.CROP) < 2.0) {
            if (upgradeWeakestField(g, v, Res.CROP)) return
        }

        // 2. Переполненный склад — это выброшенные ресурсы. Но склад нельзя
        //    гнать вперёд всей деревни: он привязан к уровню полей, иначе бот
        //    с хорошим доходом всю партию только и делает, что строит амбары.
        //    Излишки сверх потолка уходят в войска — этим занимается найм.
        val fieldCeiling = (v.fieldLevel.average() + 4).toInt()
        for (r in RES) {
            val cap = v.capOf(r)
            if (v.stock[r.ordinal] <= cap * 0.85) continue
            val type = if (r == Res.CROP) BuildingType.GRANARY else BuildingType.WAREHOUSE
            if (v.level(type) < fieldCeiling && raiseBuilding(g, v, type)) return
        }

        // 3. Главное здание рано окупается: ускоряет всю дальнейшую стройку.
        if (v.level(BuildingType.MAIN) < 5 && raiseBuilding(g, v, BuildingType.MAIN)) return

        // 4. Дальше решает отдача на вложенный ресурс. Поле даёт прирост
        //    добычи, здание — доступ к следующему этапу; и то и другое
        //    приводится к «сколько пользы на единицу затрат». Такой выбор
        //    сам перекладывает вложения из полей в город, когда поля дорожают.
        val income = RES.sumOf { g.netOutput(v, it).coerceAtLeast(0.0) }.coerceAtLeast(1.0)
        val scarce = scarcestResource(g, v)
        var bestScore = 0.0
        var bestAction: (() -> Boolean)? = null

        for (r in RES) {
            val slot = v.fieldType.indices
                .filter { v.fieldType[it] == r.ordinal }
                .minByOrNull { v.fieldLevel[it] } ?: continue
            val level = v.fieldLevel[slot]
            if (level >= Balance.MAX_FIELD_LEVEL) continue
            val cost = Balance.fieldCost(r, level)
            if (!v.canAfford(cost)) continue
            val gain = (Balance.fieldOutput(level + 1) - Balance.fieldOutput(level)) * resourceWeight(g, v, r, scarce)
            val score = gain / cost.total.coerceAtLeast(1)
            if (score > bestScore) {
                bestScore = score
                bestAction = { Engine.upgradeField(g, v, slot).ok }
            }
        }

        val goal = buildPlan(g, p, v).firstOrNull { v.level(it.first) < it.second }
        if (goal != null) {
            val type = goal.first
            val nextLevel = v.level(type) + 1
            val cost = type.costAt(nextLevel)
            if (v.canAfford(cost)) {
                val score = income * BUILDING_VALUE / cost.total.coerceAtLeast(1)
                if (score > bestScore) {
                    bestScore = score
                    bestAction = { raiseBuilding(g, v, type) }
                }
            }
        }

        if (bestAction != null && bestAction()) return

        // 5. Ничего выгодного не по карману — тянем самое слабое поле.
        upgradeWeakestField(g, v, scarce)
    }

    /**
     * Во сколько бот оценивает единицу пользы от здания относительно единицы
     * добычи в секунду. Константа откалибрована так, чтобы ранняя игра уходила
     * в поля, а поздняя — в город.
     */
    private const val BUILDING_VALUE = 0.02

    /** Насколько ценен прирост именно этого ресурса прямо сейчас. */
    private fun resourceWeight(g: GameState, v: Village, r: Res, scarce: Res): Double {
        var w = if (r == scarce) 1.5 else 1.0
        if (r == Res.CROP) {
            // Зерно нужно ровно до тех пор, пока баланс не станет уверенно плюсовым.
            val net = g.netOutput(v, Res.CROP)
            w *= if (net < 5.0) 2.5 else if (net < 25.0) 1.0 else 0.45
        }
        return w
    }

    private fun scarcestResource(g: GameState, v: Village): Res {
        var worst = Res.WOOD
        var worstValue = Double.MAX_VALUE
        for (r in RES) {
            val out = v.grossOutput(r, g.oasisBonus(v, r))
            val weight = if (r == Res.CROP) 0.75 else 1.0
            val value = out * weight
            if (value < worstValue) {
                worstValue = value
                worst = r
            }
        }
        return worst
    }

    private fun upgradeWeakestField(g: GameState, v: Village, res: Res): Boolean {
        val slot = v.fieldType.indices
            .filter { v.fieldType[it] == res.ordinal }
            .minByOrNull { v.fieldLevel[it] } ?: return false
        return Engine.upgradeField(g, v, slot).ok
    }

    /** Построить здание, если его нет, или поднять на уровень. */
    private fun raiseBuilding(g: GameState, v: Village, type: BuildingType): Boolean {
        val slot = v.slotType.indices
            .filter { v.slotType[it] == type.ordinal }
            .maxByOrNull { v.slotLevel[it] }
        if (slot != null && v.slotLevel[slot] < type.maxLevel) {
            if (Engine.upgradeBuilding(g, v, slot).ok) return true
        }
        if (v.instances(type) < type.maxInstances) {
            val free = freeSlot(v) ?: return false
            if (Engine.build(g, v, free, type).ok) return true
        }
        return false
    }

    private fun freeSlot(v: Village): Int? =
        (0 until Balance.SLOT_RALLY).firstOrNull { v.slotType[it] < 0 }

    /** Целевые уровни зданий: порядок задаёт приоритет. */
    private fun buildPlan(g: GameState, p: Player, v: Village): List<Pair<BuildingType, Int>> {
        val late = g.time > g.settings.length.seconds * 0.45
        val leading = g.leaderboard().firstOrNull()?.first?.id == p.id
        val plan = mutableListOf<Pair<BuildingType, Int>>()

        when (p.personality) {
            Personality.ECONOMIST -> {
                plan += BuildingType.MAIN to 10
                plan += BuildingType.WAREHOUSE to 6
                plan += BuildingType.GRANARY to 6
                plan += BuildingType.CRANNY to 6
                plan += BuildingType.ACADEMY to 5
                plan += BuildingType.RESIDENCE to 5
                plan += BuildingType.MARKET to 5
                plan += BuildingType.BARRACKS to 6
                plan += BuildingType.WALL to 6
                plan += BuildingType.RESIDENCE to 10
                plan += BuildingType.MAIN to 15
            }
            Personality.RUSHER -> {
                plan += BuildingType.RALLY to 3
                plan += BuildingType.ACADEMY to 3
                plan += BuildingType.BARRACKS to 8
                plan += BuildingType.WAREHOUSE to 5
                plan += BuildingType.GRANARY to 5
                plan += BuildingType.SMITHY to 5
                plan += BuildingType.ACADEMY to 10
                plan += BuildingType.STABLE to 8
                plan += BuildingType.MAIN to 10
                plan += BuildingType.RESIDENCE to 5
                plan += BuildingType.WORKSHOP to 5
                plan += BuildingType.RESIDENCE to 10
            }
            Personality.BALANCED -> {
                plan += BuildingType.MAIN to 6
                plan += BuildingType.WAREHOUSE to 5
                plan += BuildingType.GRANARY to 5
                plan += BuildingType.ACADEMY to 5
                plan += BuildingType.BARRACKS to 6
                plan += BuildingType.RESIDENCE to 5
                plan += BuildingType.WALL to 5
                plan += BuildingType.SMITHY to 4
                plan += BuildingType.STABLE to 6
                plan += BuildingType.RESIDENCE to 10
                plan += BuildingType.MAIN to 12
                plan += BuildingType.CRANNY to 5
            }
            Personality.STRATEGIST -> {
                // Адаптивный план: сначала закрывает то, чего объективно не хватает.
                plan += BuildingType.MAIN to 8
                plan += BuildingType.WAREHOUSE to 6
                plan += BuildingType.GRANARY to 6
                plan += BuildingType.ACADEMY to 5
                plan += BuildingType.BARRACKS to 8
                plan += BuildingType.RESIDENCE to 5
                plan += BuildingType.SMITHY to 6
                plan += BuildingType.WALL to 8
                plan += BuildingType.STABLE to 8
                plan += BuildingType.RESIDENCE to 10
                plan += BuildingType.MARKET to 5
                plan += BuildingType.WORKSHOP to 6
                plan += BuildingType.MAIN to 15
                plan += BuildingType.WAREHOUSE to 15
                plan += BuildingType.GRANARY to 15
            }
        }
        if (late && (leading || p.personality == Personality.STRATEGIST) && v.capital) {
            plan.add(0, BuildingType.WONDER to Balance.WONDER_WIN_LEVEL)
        }
        return plan
    }

    // ======================================================================
    // Найм войск
    // ======================================================================

    private fun manageTraining(g: GameState, p: Player, v: Village) {
        if (v.trainQueue.size >= 3) return
        val fill = RES.map { v.stock[it.ordinal] / v.capOf(it) }.average()
        // Пока склады пустые, ресурсы нужнее стройке.
        val threshold = 0.35 * (1.0 - p.personality.armyWeight) + 0.10
        if (fill < threshold) return

        // Ключевое ограничение: заказываем не «долю казны», а ровно столько,
        // сколько казарма успеет отработать за ближайшую минуту. Иначе бот
        // сливает весь доход в войска и всю партию стоит недостроенным.
        val pending = v.trainQueue.sumOf { job ->
            job.left * job.perUnit / Balance.trainSpeedup(v.level(Units[job.unitId].from))
        }
        // Когда склады трещат, копить дальше бессмысленно: излишки идут в армию.
        val surge = if (fill > 0.8) 3.0 else 1.0
        val budgetSec = (45.0 + 60.0 * p.personality.armyWeight) * surge
        if (pending > budgetSec) return

        val pick = pickUnit(g, p, v) ?: return
        val perUnit = pick.trainSec / Balance.trainSpeedup(v.level(pick.from))
        val wanted = ((budgetSec - pending) / perUnit).toInt()
        val count = min(wanted, Engine.affordableCount(v, pick))
        if (count <= 0) return
        Engine.train(g, v, pick.id, min(count, 60))
    }

    /** Выбор юнита: налётчику — атака, хозяину — оборона, остальным по ситуации. */
    private fun pickUnit(g: GameState, p: Player, v: Village): UnitDef? {
        val roster = Units.of(p.race).filter { Engine.unitUnlocked(v, it) && it.kind != UnitKind.SETTLER && it.kind != UnitKind.CHIEF }
        if (roster.isEmpty()) return null
        val wantOffense = when (p.personality) {
            Personality.RUSHER -> true
            Personality.ECONOMIST -> false
            Personality.BALANCED -> rnd.nextDouble() < 0.5
            Personality.STRATEGIST -> g.time > PEACE_TIME && rnd.nextDouble() < 0.6
        }
        val scored = roster.filter { it.kind != UnitKind.SCOUT || rnd.nextDouble() < 0.1 }
        if (scored.isEmpty()) return roster.first()
        return scored.maxByOrNull { u ->
            val power = if (wantOffense) u.att.toDouble() else (u.defI + u.defC) / 2.0
            power / max(1.0, u.cost.total.toDouble()) * 100.0
        }
    }

    // ======================================================================
    // Расширение
    // ======================================================================

    private fun manageExpansion(g: GameState, p: Player) {
        if (g.villagesOf(p.id).size >= 3) return
        val home = g.villagesOf(p.id).firstOrNull { v ->
            v.troops.indices.sumOf { if (Units[it].kind == UnitKind.SETTLER) v.troops[it] else 0 } >= Units.SETTLERS_TO_FOUND
        }
        if (home != null) {
            val spot = freeSpotNear(g, home.x, home.y) ?: return
            val army = emptyTroops()
            var need = Units.SETTLERS_TO_FOUND
            for (i in home.troops.indices) {
                if (Units[i].kind == UnitKind.SETTLER && home.troops[i] > 0 && need > 0) {
                    val take = min(need, home.troops[i])
                    army[i] = take
                    need -= take
                }
            }
            Engine.send(g, home, spot.first, spot.second, MoveKind.SETTLE, army)
            return
        }
        // Резиденция готова — заказываем поселенцев.
        val base = g.villagesOf(p.id).firstOrNull { it.level(BuildingType.RESIDENCE) >= 5 } ?: return
        val settler = Units.of(p.race).firstOrNull { it.kind == UnitKind.SETTLER } ?: return
        if (base.trainQueue.none { Units[it.unitId].kind == UnitKind.SETTLER }) {
            Engine.train(g, base, settler.id, Units.SETTLERS_TO_FOUND)
        }
    }

    private fun freeSpotNear(g: GameState, x: Int, y: Int): Pair<Int, Int>? {
        val size = Balance.MAP_SIZE
        for (r in 2..6) {
            val candidates = mutableListOf<Pair<Int, Int>>()
            for (dx in -r..r) for (dy in -r..r) {
                if (max(kotlin.math.abs(dx), kotlin.math.abs(dy)) != r) continue
                val nx = x + dx
                val ny = y + dy
                if (nx !in 0 until size || ny !in 0 until size) continue
                if (g.villageAt(nx, ny) != null || g.oasisAt(nx, ny) != null) continue
                candidates += nx to ny
            }
            if (candidates.isNotEmpty()) return candidates.random(rnd)
        }
        return null
    }

    // ======================================================================
    // Война
    // ======================================================================

    private fun manageWar(g: GameState, p: Player) {
        val diff = g.settings.difficulty
        for (v in g.villagesOf(p.id)) {
            if (v.level(BuildingType.RALLY) < 1) continue
            val power = Combat.offensePower(v.troops, v.level(BuildingType.SMITHY))
            if (power < 250.0) continue

            // Часть войска всегда остаётся дома — бот не раздевает деревню.
            val keepShare = when (p.personality) {
                Personality.RUSHER -> 0.15
                Personality.ECONOMIST -> 0.55
                else -> 0.35
            }

            val target = pickTarget(g, p, v, power * (1.0 - keepShare)) ?: continue
            val army = pickArmy(v, 1.0 - keepShare, target.wantsChief)

            if (army.isEmptyArmy()) continue
            val kind = if (target.wantsChief) MoveKind.ATTACK else if (target.oasis) MoveKind.RAID else {
                if (rnd.nextDouble() < 0.35 * diff.aiAggression) MoveKind.ATTACK else MoveKind.RAID
            }
            Engine.send(g, v, target.x, target.y, kind, army)
        }
    }

    private class Target(val x: Int, val y: Int, val oasis: Boolean, val wantsChief: Boolean)

    private fun pickTarget(g: GameState, p: Player, from: Village, power: Double): Target? {
        val diff = g.settings.difficulty
        // Плохие разведданные на низкой сложности: бот переоценивает себя или трусит.
        val noise = when (diff) {
            Difficulty.EASY -> 0.5 + rnd.nextDouble()
            Difficulty.NORMAL -> 0.8 + rnd.nextDouble() * 0.5
            else -> 1.0
        }

        val chiefsAtHome = from.troops.indices.sumOf { if (Units[it].kind == UnitKind.CHIEF) from.troops[it] else 0 }

        data class Candidate(val t: Target, val score: Double)
        val list = mutableListOf<Candidate>()

        for (v in g.villages) {
            if (v.ownerId == p.id) continue
            val d = dist(from.x, from.y, v.x, v.y)
            if (d > MAX_MARCH) continue
            val defense = Combat.defensePower(v.troops, v.level(BuildingType.WALL), g.raceOf(v.ownerId)) +
                v.reinforcements.sumOf { Combat.defensePower(it.troops) }
            val margin = power * noise / max(defense, 1.0)
            if (margin < 1.35) continue
            val loot = v.stock.sum()
            val human = g.playerOrNull(v.ownerId)?.human == true
            // Все слагаемые нормированы. Абсолютная добыча тут не годится:
            // сосед с большим складом всегда перевешивал бы беззащитную, но
            // небогатую деревню, и бот бесконечно бил бы в одну точку.
            val lootScore = 4.0 * loot / (loot + 15000.0)
            val easeScore = min(margin, 5.0) * 0.8
            var score = lootScore + easeScore - d * 0.15
            // Живой игрок — заметная, но не единственная цель.
            if (human) score *= 1.15 + 0.25 * diff.aiAggression
            // Разброс не даёт всем ботам ломиться в одну и ту же деревню:
            // без него выбор детерминирован и вся карта бьёт по одному соседу.
            score *= 0.75 + rnd.nextDouble() * 0.5
            val chief = chiefsAtHome > 0 && margin > 2.5 && v.loyalty < 100.0 || (chiefsAtHome > 0 && margin > 3.5)
            list += Candidate(Target(v.x, v.y, false, chief), score)
        }

        for (o in g.oases) {
            if (o.ownerVillage >= 0 && g.village(o.ownerVillage)?.ownerId == p.id) continue
            val d = dist(from.x, from.y, o.x, o.y)
            if (d > MAX_MARCH * 0.7) continue
            if (power * noise < o.wildDefense * 1.3) continue
            val score = 2.5 * o.stock / (o.stock + 2500.0) + o.bonusPct / 25.0 - d * 0.15
            list += Candidate(Target(o.x, o.y, true, false), score)
        }

        return list.maxByOrNull { it.score }?.t
    }

    private fun pickArmy(v: Village, share: Double, includeChief: Boolean): MutableList<Int> {
        val army = emptyTroops()
        for (i in v.troops.indices) {
            val n = v.troops[i]
            if (n <= 0) continue
            val def = Units[i]
            when (def.kind) {
                UnitKind.SETTLER -> {}
                UnitKind.CHIEF -> if (includeChief) army[i] = n
                UnitKind.SCOUT -> army[i] = (n * share * 0.3).toInt()
                else -> army[i] = (n * share).toInt()
            }
        }
        return army
    }
}
