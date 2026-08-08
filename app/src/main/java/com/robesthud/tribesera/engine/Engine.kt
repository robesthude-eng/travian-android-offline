package com.robesthud.tribesera.engine

import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.random.Random

/** Почему действие невозможно — текст сразу готов к показу в интерфейсе. */
sealed class Denied(val reason: String) {
    object None : Denied("")
    class Requirements(val text: String) : Denied(text)
    class NotEnoughResources(val missing: Cost) : Denied("Не хватает ресурсов")
    object QueueFull : Denied("Очередь строительства занята")
    object MaxLevel : Denied("Достигнут максимальный уровень")
    object NoSlot : Denied("Нет свободного места")
    class Custom(val text: String) : Denied(text)

    val ok: Boolean get() = this is None
}

object Engine {

    private var rnd = Random(0x1234ABCDL)

    /** Сид партии задаёт и случайность боёв — прогон воспроизводим. */
    fun reseed(seed: Long) {
        rnd = Random(seed)
    }

    // ======================================================================
    // Такт мира
    // ======================================================================

    fun tick(g: GameState, dt: Double) {
        if (g.over) return
        g.time += dt

        for (v in g.villages) {
            produce(g, v, dt)
            advanceBuilding(g, v, dt)
            advanceTraining(g, v, dt)
            regenLoyalty(v, dt)
        }
        advanceOases(g, dt)
        advanceMovements(g)
        Ai.think(g, dt)
        checkEndConditions(g)
    }

    // ---------------------------------------------------------------- добыча

    private fun produce(g: GameState, v: Village, dt: Double) {
        for (r in RES) {
            val cap = v.capOf(r)
            val net = g.netOutput(v, r)
            v.stock[r.ordinal] = (v.stock[r.ordinal] + net * dt).coerceIn(0.0, cap)
        }
        // Пустой амбар при отрицательном балансе — войска начинают голодать.
        if (v.stock[Res.CROP.ordinal] <= 0.0 && g.netOutput(v, Res.CROP) < 0.0) {
            starve(v, dt)
        }
    }

    private fun starve(v: Village, dt: Double) {
        val toKill = ceil(dt * 2.0).toInt()
        var left = toKill
        while (left > 0) {
            val idx = v.troops.indices.filter { v.troops[it] > 0 }.maxByOrNull { v.troops[it] * Units[it].upkeep } ?: break
            val take = min(left, v.troops[idx])
            v.troops[idx] -= take
            left -= take
        }
    }

    // -------------------------------------------------------------- стройка

    private fun advanceBuilding(g: GameState, v: Village, dt: Double) {
        if (v.buildQueue.isEmpty()) return
        val race = g.raceOf(v.ownerId)
        val speed = Balance.buildSpeedup(v.level(BuildingType.MAIN))

        val active = mutableListOf<BuildJob>()
        val firstField = v.buildQueue.firstOrNull { it.field }
        val firstBuilding = v.buildQueue.firstOrNull { !it.field }
        if (race.parallelBuild) {
            firstField?.let { active += it }
            firstBuilding?.let { active += it }
        } else {
            v.buildQueue.firstOrNull()?.let { active += it }
        }

        val done = mutableListOf<BuildJob>()
        for (job in active) {
            job.remaining -= dt * speed
            if (job.remaining <= 0.0) done += job
        }
        for (job in done) {
            v.buildQueue.remove(job)
            if (job.field) {
                v.fieldLevel[job.slot] = job.targetLevel
            } else {
                v.slotType[job.slot] = job.type
                v.slotLevel[job.slot] = job.targetLevel
            }
            if (!job.field && job.type == BuildingType.WONDER.ordinal &&
                job.targetLevel >= Balance.WONDER_WIN_LEVEL
            ) {
                declareWinner(g, v.ownerId, "Чудо света достроено до ${Balance.WONDER_WIN_LEVEL} уровня")
            }
        }
    }

    // ------------------------------------------------------------------ найм

    private fun advanceTraining(g: GameState, v: Village, dt: Double) {
        if (v.trainQueue.isEmpty()) return
        val busy = mutableSetOf<BuildingType>()
        val finished = mutableListOf<TrainJob>()
        for (job in v.trainQueue) {
            val def = Units[job.unitId]
            if (!busy.add(def.from)) continue // эта казарма уже занята другим заказом
            val speed = Balance.trainSpeedup(v.level(def.from))
            job.progress += dt * speed
            while (job.progress >= job.perUnit && job.left > 0) {
                job.progress -= job.perUnit
                job.left--
                v.troops[job.unitId]++
            }
            if (job.left <= 0) finished += job
        }
        v.trainQueue.removeAll(finished)
    }

    private fun regenLoyalty(v: Village, dt: Double) {
        if (v.loyalty < 100.0) {
            v.loyalty = min(100.0, v.loyalty + Balance.LOYALTY_REGEN_PER_SEC * dt)
        }
    }

    // ----------------------------------------------------------------- оазисы

    private fun advanceOases(g: GameState, dt: Double) {
        for (o in g.oases) {
            o.stock = min(4000.0, o.stock + 1.6 * dt)
            if (o.ownerVillage < 0) {
                o.wildDefense = min(wildDefenseCap(o), o.wildDefense + 3.0 * dt)
            }
        }
    }

    private fun wildDefenseCap(o: Oasis): Double = 900.0 + o.bonusPct * 14.0

    // --------------------------------------------------------------- походы

    private fun advanceMovements(g: GameState) {
        val arrived = g.movements.filter { it.arrive <= g.time }
        if (arrived.isEmpty()) return
        for (m in arrived) {
            g.movements.remove(m)
            when (m.kind) {
                MoveKind.RETURN -> arriveHome(g, m)
                MoveKind.REINFORCE -> arriveReinforce(g, m)
                MoveKind.SETTLE -> arriveSettle(g, m)
                MoveKind.SCOUT -> arriveScout(g, m)
                MoveKind.RAID, MoveKind.ATTACK -> arriveAttack(g, m)
            }
        }
    }

    private fun arriveHome(g: GameState, m: Movement) {
        val home = g.village(m.fromVillage)
        if (home == null || home.ownerId != m.ownerId) {
            // Дом потерян, пока войско было в пути — идут в другую свою деревню.
            val fallback = g.villagesOf(m.ownerId).firstOrNull() ?: return
            fallback.troops.addTroops(m.troops)
            return
        }
        home.troops.addTroops(m.troops)
        for (i in 0..3) {
            home.stock[i] = min(home.capOf(RES[i]), home.stock[i] + m.loot[i])
        }
    }

    private fun arriveReinforce(g: GameState, m: Movement) {
        val target = g.village(m.targetVillage)
        if (target == null) {
            sendBack(g, m, emptyMutable(m.troops))
            return
        }
        if (target.ownerId == m.ownerId) {
            target.troops.addTroops(m.troops)
        } else {
            val group = target.reinforcements.firstOrNull { it.ownerId == m.ownerId }
            if (group != null) group.troops.addTroops(m.troops)
            else target.reinforcements += Reinforcement(m.ownerId, m.troops.toMutableList())
        }
    }

    private fun arriveSettle(g: GameState, m: Movement) {
        val occupied = g.villageAt(m.tx, m.ty) != null || g.oasisAt(m.tx, m.ty) != null
        if (occupied) {
            report(g, m.ownerId, ReportKind.SETTLE, "Место занято", "Поселенцы вернулись домой", success = false)
            sendBack(g, m, m.troops.toMutableList())
            return
        }
        val v = foundVillage(g, m.ownerId, m.tx, m.ty)
        report(
            g, m.ownerId, ReportKind.SETTLE, "Основана деревня «${v.name}»",
            "Поселенцы обжили клетку (${m.tx}|${m.ty})",
        )
    }

    private fun arriveScout(g: GameState, m: Movement) {
        val target = g.village(m.targetVillage)
        if (target == null) {
            sendBack(g, m, m.troops.toMutableList())
            return
        }
        val defenders = target.allDefenders().map { DefenderGroup(it.first, it.second.toMutableList()) }
        val success = Combat.resolveScouting(m.troops, defenders, target.level(BuildingType.WALL), g.raceOf(target.ownerId))
        if (success) {
            val lines = buildList {
                add("Гарнизон:")
                var any = false
                for (i in target.troops.indices) {
                    if (target.troops[i] > 0) { add("  ${Units[i].title} — ${target.troops[i]}"); any = true }
                }
                for (r in target.reinforcements) {
                    for (i in r.troops.indices) {
                        if (r.troops[i] > 0) { add("  ${Units[i].title} (подкрепление) — ${r.troops[i]}"); any = true }
                    }
                }
                if (!any) add("  пусто")
                add("Стена: ${target.level(BuildingType.WALL)} ур.")
                add("Склады: " + RES.joinToString(", ") { "${it.short} ${formatAmount(target.stock[it.ordinal])}" })
            }
            report(g, m.ownerId, ReportKind.SCOUT, "Разведка «${target.name}»", "Разведчики вернулись с данными", lines)
            sendBack(g, m, m.troops.toMutableList())
        } else {
            report(
                g, m.ownerId, ReportKind.SCOUT, "Разведка «${target.name}»",
                "Разведчики перехвачены и уничтожены", success = false,
            )
            report(
                g, target.ownerId, ReportKind.DEFENSE, "Перехвачена разведка",
                "Чужие разведчики у «${target.name}» уничтожены",
            )
        }
    }

    // ------------------------------------------------------------------ бой

    private fun arriveAttack(g: GameState, m: Movement) {
        if (m.targetOasis >= 0) {
            arriveOasisAttack(g, m)
            return
        }
        val target = g.village(m.targetVillage)
        if (target == null) {
            sendBack(g, m, m.troops.toMutableList())
            return
        }
        if (target.ownerId == m.ownerId) {
            target.troops.addTroops(m.troops)
            return
        }

        val attackerRace = g.raceOf(m.ownerId)
        val defenderRace = g.raceOf(target.ownerId)
        val from = g.village(m.fromVillage)
        val smithy = from?.level(BuildingType.SMITHY) ?: 0
        val wall = target.level(BuildingType.WALL)
        val raid = m.kind == MoveKind.RAID

        val groups = mutableListOf(DefenderGroup(target.ownerId, target.troops))
        for (r in target.reinforcements) groups += DefenderGroup(r.ownerId, r.troops)

        // catTarget — это тип здания; конкретный слот ищем уже в деревне цели.
        val chosen = m.catTarget.takeIf { it in BuildingType.entries.indices }
            ?.let { target.slotOf(BuildingType.entries[it]) } ?: -1
        val catSlot = if (chosen >= 0 && target.slotLevel[chosen] > 0) {
            chosen
        } else {
            target.slotType.indices.filter { target.slotType[it] >= 0 && target.slotLevel[it] > 0 }.randomOrNull(rnd) ?: -1
        }

        val res = Combat.resolve(
            attacker = m.troops,
            attackerRace = attackerRace,
            attackerSmithy = smithy,
            defenders = groups,
            defenderRace = defenderRace,
            wallLevel = wall,
            raid = raid,
            targetSlot = catSlot,
            targetSlotLevel = if (catSlot >= 0) target.slotLevel[catSlot] else 0,
            rnd = rnd,
        )

        // потери
        val attSurvivors = m.troops.toMutableList()
        attSurvivors.subTroops(res.attackerLosses)
        for ((i, grp) in groups.withIndex()) grp.troops.subTroops(res.defenderLosses[i])
        target.reinforcements.removeAll { it.troops.isEmptyArmy() }

        g.player(m.ownerId).losses += res.attackerLosses.sum()
        g.player(m.ownerId).kills += res.defenderLosses.sumOf { it.sum() }
        g.playerOrNull(target.ownerId)?.let {
            it.losses += res.defenderLosses.sumOf { l -> l.sum() }
            it.kills += res.attackerLosses.sum()
        }

        // разрушения
        if (res.wallLevelsDestroyed > 0) {
            val ws = target.slotOf(BuildingType.WALL)
            if (ws >= 0) target.slotLevel[ws] = (target.slotLevel[ws] - res.wallLevelsDestroyed).coerceAtLeast(0)
        }
        var wrecked = ""
        if (res.buildingHitSlot >= 0 && res.buildingLevelsDestroyed > 0) {
            val slot = res.buildingHitSlot
            val type = target.buildingAt(slot)
            target.slotLevel[slot] = (target.slotLevel[slot] - res.buildingLevelsDestroyed).coerceAtLeast(0)
            if (target.slotLevel[slot] == 0 && type != BuildingType.RALLY && type != BuildingType.WALL) {
                target.slotType[slot] = -1
            }
            wrecked = "${type?.title ?: "Здание"} −${res.buildingLevelsDestroyed} ур."
        }

        // добыча
        val loot = MutableList(4) { 0.0 }
        if (res.attackerWon) {
            val capacity = attSurvivors.carryCapacity(attackerRace)
            val hidden = target.crannyHidden(defenderRace) * (1.0 - attackerRace.crannyPiercing)
            var available = 0.0
            val avail = DoubleArray(4)
            for (i in 0..3) {
                avail[i] = (target.stock[i] - hidden).coerceAtLeast(0.0)
                available += avail[i]
            }
            if (available > 0.0) {
                val take = min(capacity, available)
                for (i in 0..3) {
                    val part = take * (avail[i] / available)
                    loot[i] = part
                    target.stock[i] -= part
                }
            }
        }

        // захват деревни
        var captured = false
        var loyaltyDrop = 0.0
        val chiefs = attSurvivors.indices.count { attSurvivors[it] > 0 && Units[it].kind == UnitKind.CHIEF }
        if (res.attackerWon && chiefs > 0 && !raid) {
            val chiefCount = attSurvivors.indices.sumOf { if (Units[it].kind == UnitKind.CHIEF) attSurvivors[it] else 0 }
            val resist = 1.0 + 0.05 * target.level(BuildingType.RESIDENCE)
            loyaltyDrop = chiefCount * (20.0 + rnd.nextDouble() * 8.0) / resist
            target.loyalty -= loyaltyDrop
            if (target.loyalty <= 0.0) {
                captured = true
                capture(g, target, m.ownerId)
            }
        }

        writeBattleReports(g, m, target, res, attSurvivors, loot, wrecked, captured, loyaltyDrop, raid)

        if (!attSurvivors.isEmptyArmy()) {
            // Вожди остаются в захваченной деревне, остальные возвращаются с добычей.
            if (captured) {
                for (i in attSurvivors.indices) if (Units[i].kind == UnitKind.CHIEF) attSurvivors[i] = 0
            }
            sendBack(g, m, attSurvivors, loot)
        }
        checkDefeat(g, target.ownerId)
    }

    private fun arriveOasisAttack(g: GameState, m: Movement) {
        val o = g.oases.firstOrNull { it.id == m.targetOasis }
        if (o == null) {
            sendBack(g, m, m.troops.toMutableList())
            return
        }
        val race = g.raceOf(m.ownerId)
        val attack = Combat.offensePower(m.troops, g.village(m.fromVillage)?.level(BuildingType.SMITHY) ?: 0)

        // Оборона оазиса — звери плюс гарнизон владельца, если он есть.
        var defense = o.wildDefense
        val ownerVillage = g.village(o.ownerVillage)
        if (ownerVillage != null && o.ownerVillage >= 0) defense += 60.0

        val survivors = m.troops.toMutableList()
        val won = attack > defense
        val frac = if (won) {
            (defense / max(attack, 1.0)).coerceIn(0.0, 1.0) * 0.6
        } else {
            1.0
        }
        for (i in survivors.indices) survivors[i] = (survivors[i] * (1.0 - frac)).roundToInt()

        val loot = MutableList(4) { 0.0 }
        if (won) {
            o.wildDefense = 0.0
            val cap = survivors.carryCapacity(race)
            val take = min(cap, o.stock)
            o.stock -= take
            for (i in 0..3) loot[i] = take / 4.0
            annexIfPossible(g, m, o)
        }

        report(
            g, m.ownerId, ReportKind.RAID,
            if (won) "Оазис взят" else "Оазис отбился",
            "${o.title} (${o.x}|${o.y})",
            listOf(
                "Атака: ${attack.roundToInt()} против обороны ${defense.roundToInt()}",
                "Потери: ${m.troops.sum() - survivors.sum()}",
                if (o.ownerVillage >= 0 && g.village(o.ownerVillage)?.ownerId == m.ownerId) {
                    "Оазис присоединён — бонус +${o.bonusPct}%"
                } else {
                    "Чтобы присоединить оазис, нужен свободный слот (главное здание)"
                },
            ),
            loot,
            won,
        )
        if (!survivors.isEmptyArmy()) sendBack(g, m, survivors, loot)
    }

    private fun annexIfPossible(g: GameState, m: Movement, o: Oasis) {
        val from = g.village(m.fromVillage) ?: return
        if (from.ownerId != m.ownerId) return
        val capacity = oasisCapacity(from)
        if (from.oasisIds.size >= capacity) return
        // отбираем у прежнего владельца
        g.village(o.ownerVillage)?.oasisIds?.remove(o.id)
        o.ownerVillage = from.id
        from.oasisIds += o.id
    }

    /** Сколько оазисов может удерживать деревня — зависит от главного здания. */
    fun oasisCapacity(v: Village): Int = when {
        v.level(BuildingType.MAIN) >= 15 -> 3
        v.level(BuildingType.MAIN) >= 10 -> 2
        v.level(BuildingType.MAIN) >= 5 -> 1
        else -> 0
    }

    private fun writeBattleReports(
        g: GameState,
        m: Movement,
        target: Village,
        res: BattleResult,
        attSurvivors: List<Int>,
        loot: List<Double>,
        wrecked: String,
        captured: Boolean,
        loyaltyDrop: Double,
        raid: Boolean,
    ) {
        val attackerName = g.playerOrNull(m.ownerId)?.name ?: "?"
        val lines = buildList {
            add("Сила атаки ${res.attackPower.roundToInt()} против обороны ${res.defensePower.roundToInt()}")
            add("—")
            for (i in m.troops.indices) {
                if (m.troops[i] > 0) {
                    val lost = res.attackerLosses[i]
                    add("${Units[i].title}: ${m.troops[i]} → потери $lost")
                }
            }
            add("—")
            var anyDef = false
            for (grp in res.defenderLosses.indices) {
                for (i in res.defenderLosses[grp].indices) {
                    if (res.defenderLosses[grp][i] > 0) {
                        add("Обороне: ${Units[i].title} −${res.defenderLosses[grp][i]}")
                        anyDef = true
                    }
                }
            }
            if (!anyDef) add("Обороняющиеся потерь не понесли")
            if (res.wallLevelsDestroyed > 0) add("Стена разрушена на ${res.wallLevelsDestroyed} ур.")
            if (wrecked.isNotEmpty()) add(wrecked)
            if (loyaltyDrop > 0) add("Лояльность −${loyaltyDrop.roundToInt()}% (осталось ${target.loyalty.coerceAtLeast(0.0).roundToInt()}%)")
            if (captured) add("ДЕРЕВНЯ ЗАХВАЧЕНА")
        }
        val verb = if (raid) "Набег на" else "Штурм"
        report(
            g, m.ownerId, ReportKind.RAID,
            "$verb «${target.name}»",
            if (res.attackerWon) "Победа" else "Поражение",
            lines, loot, res.attackerWon,
        )
        report(
            g, target.ownerId, ReportKind.DEFENSE,
            "Нападение на «${target.name}»",
            if (res.attackerWon) "Оборона пала — $attackerName" else "Атака отбита — $attackerName",
            lines, loot.map { -it }, !res.attackerWon,
        )
    }

    private fun capture(g: GameState, v: Village, newOwner: Int) {
        val oldOwner = v.ownerId
        v.ownerId = newOwner
        v.loyalty = 40.0
        v.capital = false
        v.troops.indices.forEach { v.troops[it] = 0 }
        v.reinforcements.clear()
        v.buildQueue.clear()
        v.trainQueue.clear()
        for (id in v.oasisIds.toList()) {
            g.oases.firstOrNull { it.id == id }?.ownerVillage = v.id
        }
        report(
            g, newOwner, ReportKind.CONQUEST, "Деревня «${v.name}» захвачена",
            "Теперь она работает на вас",
        )
        report(
            g, oldOwner, ReportKind.CONQUEST, "Потеряна деревня «${v.name}»",
            "Её забрал ${g.playerOrNull(newOwner)?.name ?: "враг"}", success = false,
        )
    }

    private fun sendBack(g: GameState, m: Movement, troops: MutableList<Int>, loot: List<Double> = listOf(0.0, 0.0, 0.0, 0.0)) {
        if (troops.isEmptyArmy()) return
        val home = g.village(m.fromVillage) ?: g.villagesOf(m.ownerId).firstOrNull() ?: return
        val race = g.raceOf(m.ownerId)
        val d = dist(m.tx, m.ty, home.x, home.y)
        val rallyBonus = 1.0 + 0.02 * home.level(BuildingType.RALLY)
        val t = travelTime(d, troops.marchSpeed(), race) / rallyBonus
        g.movements += Movement(
            id = g.newId(),
            ownerId = m.ownerId,
            fromVillage = home.id,
            targetVillage = home.id,
            tx = home.x, ty = home.y,
            kind = MoveKind.RETURN,
            troops = troops,
            start = g.time,
            arrive = g.time + t,
            loot = loot.toMutableList(),
        )
    }

    // ======================================================================
    // Победа и поражение
    // ======================================================================

    private fun checkDefeat(g: GameState, playerId: Int) {
        val p = g.playerOrNull(playerId) ?: return
        if (p.defeated) return
        if (g.villagesOf(playerId).isEmpty()) {
            p.defeated = true
            report(g, g.human.id, ReportKind.SYSTEM, "${p.name} выбывает", "Игрок потерял все деревни")
        }
    }

    private fun checkEndConditions(g: GameState) {
        if (g.over) return
        val alive = g.players.filter { !it.defeated }
        if (alive.size == 1) {
            declareWinner(g, alive[0].id, "Все соперники потеряли деревни")
            return
        }
        if (g.human.defeated) {
            g.over = true
            g.winnerId = g.leaderboard().firstOrNull { !it.first.human }?.first?.id ?: -1
            g.winReason = "Вы потеряли все деревни"
            return
        }
        if (g.time >= g.settings.length.seconds) {
            val best = g.leaderboard().first()
            declareWinner(g, best.first.id, "Время партии вышло — победа по очкам")
        }
    }

    private fun declareWinner(g: GameState, playerId: Int, reason: String) {
        g.over = true
        g.winnerId = playerId
        g.winReason = reason
    }

    // ======================================================================
    // Действия
    // ======================================================================

    /** Сколько всего заказов помещается в очередь стройки. */
    fun queueCapacity(race: Race): Int = if (race.parallelBuild) 4 else 3

    private fun queuedLevel(v: Village, field: Boolean, slot: Int): Int {
        var lvl = if (field) v.fieldLevel[slot] else v.slotLevel[slot]
        for (job in v.buildQueue) if (job.field == field && job.slot == slot) lvl = max(lvl, job.targetLevel)
        return lvl
    }

    // ------------------------------------------------------- ресурсные поля

    fun fieldNextLevel(v: Village, slot: Int): Int = queuedLevel(v, true, slot) + 1

    fun canUpgradeField(g: GameState, v: Village, slot: Int): Denied {
        val race = g.raceOf(v.ownerId)
        val next = fieldNextLevel(v, slot)
        if (next > Balance.MAX_FIELD_LEVEL) return Denied.MaxLevel
        if (v.buildQueue.size >= queueCapacity(race)) return Denied.QueueFull
        val cost = Balance.fieldCost(RES[v.fieldType[slot]], next - 1)
        if (!v.canAfford(cost)) return Denied.NotEnoughResources(missing(v, cost))
        return Denied.None
    }

    fun upgradeField(g: GameState, v: Village, slot: Int): Denied {
        val check = canUpgradeField(g, v, slot)
        if (!check.ok) return check
        val next = fieldNextLevel(v, slot)
        val cost = Balance.fieldCost(RES[v.fieldType[slot]], next - 1)
        v.pay(cost)
        val time = Balance.fieldTime(next - 1)
        v.buildQueue += BuildJob(true, slot, v.fieldType[slot], next, time, time)
        return Denied.None
    }

    // -------------------------------------------------------------- здания

    fun buildingNextLevel(v: Village, slot: Int): Int = queuedLevel(v, false, slot) + 1

    fun requirementsText(v: Village, type: BuildingType): String? {
        val missing = type.requirements.filter { v.level(it.first) < it.second }
        if (missing.isEmpty()) return null
        return "Нужно: " + missing.joinToString(", ") { "${it.first.title} ${it.second} ур." }
    }

    /** Какие здания вообще можно поставить в пустой слот. */
    fun availableBuildings(g: GameState, v: Village, slot: Int): List<BuildingType> {
        return BuildingType.entries.filter { t ->
            when (t) {
                BuildingType.RALLY, BuildingType.WALL -> false
                BuildingType.WONDER -> v.capital && v.instances(t) == 0
                else -> v.instances(t) < t.maxInstances
            }
        }
    }

    fun canBuild(g: GameState, v: Village, slot: Int, type: BuildingType): Denied {
        val race = g.raceOf(v.ownerId)
        if (v.slotType[slot] >= 0) return Denied.NoSlot
        if (v.instances(type) >= type.maxInstances) return Denied.Custom("Такое здание уже построено")
        if (type == BuildingType.WONDER && !v.capital) return Denied.Custom("Чудо света строится только в столице")
        requirementsText(v, type)?.let { return Denied.Requirements(it) }
        if (v.buildQueue.size >= queueCapacity(race)) return Denied.QueueFull
        val cost = type.costAt(1)
        if (!v.canAfford(cost)) return Denied.NotEnoughResources(missing(v, cost))
        return Denied.None
    }

    fun build(g: GameState, v: Village, slot: Int, type: BuildingType): Denied {
        val check = canBuild(g, v, slot, type)
        if (!check.ok) return check
        val cost = type.costAt(1)
        v.pay(cost)
        val time = type.timeAt(1)
        v.buildQueue += BuildJob(false, slot, type.ordinal, 1, time, time)
        return Denied.None
    }

    fun canUpgradeBuilding(g: GameState, v: Village, slot: Int): Denied {
        val type = v.buildingAt(slot) ?: return Denied.Custom("Пустой участок")
        val race = g.raceOf(v.ownerId)
        val next = buildingNextLevel(v, slot)
        if (next > type.maxLevel) return Denied.MaxLevel
        requirementsText(v, type)?.let { return Denied.Requirements(it) }
        if (v.buildQueue.size >= queueCapacity(race)) return Denied.QueueFull
        val cost = type.costAt(next)
        if (!v.canAfford(cost)) return Denied.NotEnoughResources(missing(v, cost))
        return Denied.None
    }

    fun upgradeBuilding(g: GameState, v: Village, slot: Int): Denied {
        val check = canUpgradeBuilding(g, v, slot)
        if (!check.ok) return check
        val type = v.buildingAt(slot)!!
        val next = buildingNextLevel(v, slot)
        val cost = type.costAt(next)
        v.pay(cost)
        val time = type.timeAt(next)
        v.buildQueue += BuildJob(false, slot, type.ordinal, next, time, time)
        return Denied.None
    }

    fun cancelJob(v: Village, job: BuildJob) {
        if (!v.buildQueue.remove(job)) return
        val cost = if (job.field) {
            Balance.fieldCost(RES[job.type], job.targetLevel - 1)
        } else {
            BuildingType.entries[job.type].costAt(job.targetLevel)
        }
        v.refund(cost * 0.8)
    }

    private fun missing(v: Village, cost: Cost): Cost = Cost(
        (cost.wood - v.stock[0]).coerceAtLeast(0.0).roundToInt(),
        (cost.clay - v.stock[1]).coerceAtLeast(0.0).roundToInt(),
        (cost.iron - v.stock[2]).coerceAtLeast(0.0).roundToInt(),
        (cost.crop - v.stock[3]).coerceAtLeast(0.0).roundToInt(),
    )

    // ---------------------------------------------------------------- войска

    fun unitUnlocked(v: Village, def: UnitDef): Boolean {
        if (v.level(def.from) < 1) return false
        return when (def.kind) {
            UnitKind.CHIEF, UnitKind.SETTLER -> v.level(BuildingType.RESIDENCE) >= def.rank
            else -> v.level(BuildingType.ACADEMY) >= def.rank
        }
    }

    fun unitLockReason(v: Village, def: UnitDef): String {
        if (v.level(def.from) < 1) return "Нужно здание: ${def.from.title}"
        return when (def.kind) {
            UnitKind.CHIEF, UnitKind.SETTLER -> "Нужна ${BuildingType.RESIDENCE.title} ${def.rank} ур."
            else -> "Нужна ${BuildingType.ACADEMY.title} ${def.rank} ур."
        }
    }

    /** Сколько таких юнитов деревня может оплатить прямо сейчас. */
    fun affordableCount(v: Village, def: UnitDef): Int {
        val c = def.cost
        var n = Int.MAX_VALUE
        val costs = c.asList()
        for (i in 0..3) {
            if (costs[i] > 0) n = min(n, (v.stock[i] / costs[i]).toInt())
        }
        return if (n == Int.MAX_VALUE) 999 else n
    }

    fun train(g: GameState, v: Village, unitId: Int, count: Int): Denied {
        val def = Units[unitId]
        if (def.race != g.raceOf(v.ownerId)) return Denied.Custom("Чужие войска не нанять")
        if (!unitUnlocked(v, def)) return Denied.Requirements(unitLockReason(v, def))
        val n = min(count, affordableCount(v, def))
        if (n <= 0) return Denied.NotEnoughResources(def.cost)
        if (def.kind == UnitKind.SETTLER || def.kind == UnitKind.CHIEF) {
            val slots = BuildingType.settlerSlots(v.level(BuildingType.RESIDENCE))
            val existing = v.troops.indices.sumOf {
                if (Units[it].kind == UnitKind.SETTLER || Units[it].kind == UnitKind.CHIEF) v.troops[it] else 0
            } + v.trainQueue.filter { Units[it.unitId].kind == UnitKind.SETTLER || Units[it.unitId].kind == UnitKind.CHIEF }.sumOf { it.left }
            if (existing + n > slots * Units.SETTLERS_TO_FOUND) {
                return Denied.Custom("Резиденция вмещает ${slots * Units.SETTLERS_TO_FOUND} поселенцев и вождей")
            }
        }
        v.pay(def.cost * n.toDouble())
        val existing = v.trainQueue.firstOrNull { it.unitId == unitId }
        if (existing != null) existing.left += n
        else v.trainQueue += TrainJob(unitId, n, def.trainSec)
        return Denied.None
    }

    fun cancelTraining(v: Village, job: TrainJob) {
        v.trainQueue.remove(job)
    }

    // ---------------------------------------------------------------- походы

    fun canSend(g: GameState, from: Village, troops: List<Int>, kind: MoveKind): Denied {
        if (from.level(BuildingType.RALLY) < 1) return Denied.Requirements("Нужна точка сбора")
        if (troops.isEmptyArmy()) return Denied.Custom("Не выбрано ни одного воина")
        for (i in troops.indices) if (troops[i] > from.troops[i]) return Denied.Custom("Столько войск нет дома")
        if (kind == MoveKind.SETTLE) {
            val settlers = troops.indices.sumOf { if (Units[it].kind == UnitKind.SETTLER) troops[it] else 0 }
            if (settlers < Units.SETTLERS_TO_FOUND) return Denied.Custom("Нужно ${Units.SETTLERS_TO_FOUND} поселенца")
        }
        return Denied.None
    }

    fun send(
        g: GameState,
        from: Village,
        tx: Int,
        ty: Int,
        kind: MoveKind,
        troops: List<Int>,
        catTarget: Int = -1,
    ): Denied {
        val check = canSend(g, from, troops, kind)
        if (!check.ok) return check
        val targetVillage = g.villageAt(tx, ty)
        val targetOasis = g.oasisAt(tx, ty)
        if (kind != MoveKind.SETTLE && targetVillage == null && targetOasis == null) {
            return Denied.Custom("На этой клетке некого атаковать")
        }
        if (kind == MoveKind.SETTLE && (targetVillage != null || targetOasis != null)) {
            return Denied.Custom("Клетка занята")
        }

        val army = troops.toMutableList()
        from.troops.subTroops(army)
        val race = g.raceOf(from.ownerId)
        val d = dist(from.x, from.y, tx, ty)
        val t = travelTime(d, army.marchSpeed(), race)
        g.movements += Movement(
            id = g.newId(),
            ownerId = from.ownerId,
            fromVillage = from.id,
            targetVillage = targetVillage?.id ?: -1,
            targetOasis = targetOasis?.id ?: -1,
            tx = tx, ty = ty,
            kind = kind,
            troops = army,
            start = g.time,
            arrive = g.time + t,
            catTarget = catTarget,
        )
        return Denied.None
    }

    /** Походы, летящие в сторону деревни (для панели «входящие»). */
    fun incoming(g: GameState, v: Village): List<Movement> = g.movements.filter {
        (it.targetVillage == v.id || (it.tx == v.x && it.ty == v.y)) &&
            it.ownerId != v.ownerId &&
            (it.kind == MoveKind.ATTACK || it.kind == MoveKind.RAID || it.kind == MoveKind.SCOUT)
    }

    fun outgoing(g: GameState, playerId: Int): List<Movement> =
        g.movements.filter { it.ownerId == playerId }

    // ------------------------------------------------------------------ рынок

    fun trade(g: GameState, v: Village, give: Res, take: Res, amount: Double): Denied {
        val market = v.level(BuildingType.MARKET)
        if (market < 1) return Denied.Requirements("Нужен рынок")
        if (give == take) return Denied.Custom("Обмен на тот же ресурс")
        if (v.stock[give.ordinal] < amount) return Denied.NotEnoughResources(Cost())
        val rate = BuildingType.marketRate(market)
        v.stock[give.ordinal] -= amount
        v.stock[take.ordinal] = min(v.capOf(take), v.stock[take.ordinal] + amount * rate)
        return Denied.None
    }

    // -------------------------------------------------------------- деревни

    fun foundVillage(g: GameState, ownerId: Int, x: Int, y: Int, fieldStart: Int = 1): Village {
        val v = Village(
            id = g.newId(),
            name = villageName(g, ownerId),
            ownerId = ownerId,
            x = x, y = y,
            capital = g.villagesOf(ownerId).isEmpty(),
            founded = g.time,
        )
        for (i in v.fieldLevel.indices) v.fieldLevel[i] = fieldStart
        v.slotType[0] = BuildingType.MAIN.ordinal
        v.slotLevel[0] = 1
        v.slotType[Balance.SLOT_RALLY] = BuildingType.RALLY.ordinal
        v.slotLevel[Balance.SLOT_RALLY] = 1
        v.slotType[Balance.SLOT_WALL] = BuildingType.WALL.ordinal
        v.slotLevel[Balance.SLOT_WALL] = 0
        g.villages += v
        return v
    }

    private val nameParts = listOf(
        "Дубрава", "Каменка", "Вольный Брод", "Сосновка", "Тихий Дол", "Ветрогорье",
        "Медвежий Угол", "Заречье", "Соколиный Стан", "Белый Ключ", "Гончарный Ряд",
        "Кузнечное", "Волчья Падь", "Journeys End", "Липовый Скат", "Ржаное Поле",
    )

    private fun villageName(g: GameState, ownerId: Int): String {
        val n = g.villagesOf(ownerId).size
        if (n == 0) return "Столица"
        val used = g.villages.map { it.name }.toSet()
        return nameParts.firstOrNull { it !in used } ?: "Поселение ${g.villages.size + 1}"
    }

    // ------------------------------------------------------------------ прочее

    fun report(
        g: GameState,
        ownerId: Int,
        kind: ReportKind,
        title: String,
        subtitle: String,
        lines: List<String> = emptyList(),
        loot: List<Double> = listOf(0.0, 0.0, 0.0, 0.0),
        success: Boolean = true,
    ) {
        // Отчёты нужны только живому игроку — бот их всё равно не читает.
        if (g.playerOrNull(ownerId)?.human != true) return
        g.reports.add(0, Report(g.newId(), ownerId, g.time, kind, title, subtitle, lines, loot, success))
        while (g.reports.size > 80) g.reports.removeAt(g.reports.size - 1)
    }

    private fun emptyMutable(sample: List<Int>): MutableList<Int> = MutableList(sample.size) { 0 }
}
