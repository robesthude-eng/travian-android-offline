package com.robesthud.tribesera.engine

import kotlin.math.floor
import kotlin.math.pow
import kotlin.random.Random

/** Одна сторона обороны: чьи это войска и сколько их. */
class DefenderGroup(val ownerId: Int, val troops: MutableList<Int>)

class BattleResult(
    val attackPower: Double,
    val defensePower: Double,
    val attackerWon: Boolean,
    /** Сколько атакующих полегло, по индексам каталога. */
    val attackerLosses: MutableList<Int>,
    /** Потери каждой обороняющейся группы в том же порядке, что и на входе. */
    val defenderLosses: List<MutableList<Int>>,
    /** Сколько уровней стены снесли тараны. */
    val wallLevelsDestroyed: Int,
    /** Сколько уровней здания снесли катапульты и какого именно. */
    val buildingHitSlot: Int,
    val buildingLevelsDestroyed: Int,
)

object Combat {

    /**
     * Классическая схема: атака сравнивается с обороной, взвешенной по доле
     * пехоты и конницы в атаке. Проигравший в штурме теряет всё, победитель —
     * долю, зависящую от того, насколько тяжело далась победа. Набег щадит
     * обе стороны: потери делятся пропорционально.
     */
    fun resolve(
        attacker: List<Int>,
        attackerRace: Race,
        attackerSmithy: Int,
        defenders: List<DefenderGroup>,
        defenderRace: Race,
        wallLevel: Int,
        raid: Boolean,
        targetSlot: Int = -1,
        targetSlotLevel: Int = 0,
        rnd: Random = Random.Default,
    ): BattleResult {
        // ------------------------------------------------------ сила атаки
        var attackPoints = 0.0
        var cavalryPoints = 0.0
        var ramPower = 0.0
        var catapultPower = 0.0
        for (i in attacker.indices) {
            val n = attacker[i]
            if (n == 0) continue
            val d = Units[i]
            val p = n.toDouble() * d.att
            attackPoints += p
            if (d.isCavalry) cavalryPoints += p
            if (d.isRam) ramPower += p
            if (d.isCatapult) catapultPower += p
        }
        val smithy = 1.0 + attackerSmithy * Balance.SMITHY_ATTACK_PER_LEVEL
        attackPoints *= smithy

        val cavShare = if (attackPoints <= 0.0) 0.0 else (cavalryPoints * smithy / attackPoints).coerceIn(0.0, 1.0)
        val infShare = 1.0 - cavShare

        // -------------------------------------------- тараны обрушают стену
        val wallDown = if (ramPower <= 0.0) 0 else
            floor(ramPower / (55.0 * (wallLevel + 1))).toInt().coerceIn(0, wallLevel)
        val effectiveWall = (wallLevel - wallDown).coerceAtLeast(0)

        // ---------------------------------------------------- сила обороны
        var defensePoints = Balance.VILLAGE_BASE_DEFENSE
        for (g in defenders) {
            for (i in g.troops.indices) {
                val n = g.troops[i]
                if (n == 0) continue
                val d = Units[i]
                defensePoints += n * (d.defI * infShare + d.defC * cavShare)
            }
        }
        defensePoints *= 1.0 + effectiveWall * defenderRace.wallBonusPerLevel

        // ------------------------------------------------------------ итог
        val attackerWon = attackPoints > defensePoints
        val attFrac: Double
        val defFrac: Double
        if (attackerWon) {
            val ratio = if (attackPoints <= 0.0) 1.0 else (defensePoints / attackPoints).coerceIn(0.0, 1.0)
            if (raid) {
                attFrac = ratio / (1.0 + ratio)
                defFrac = 1.0 / (1.0 + ratio)
            } else {
                attFrac = ratio.pow(1.5)
                defFrac = 1.0
            }
        } else {
            val ratio = if (defensePoints <= 0.0) 1.0 else (attackPoints / defensePoints).coerceIn(0.0, 1.0)
            if (raid) {
                attFrac = 1.0 / (1.0 + ratio)
                defFrac = ratio / (1.0 + ratio)
            } else {
                attFrac = 1.0
                defFrac = ratio.pow(1.5)
            }
        }

        val attackerLosses = applyLosses(attacker, attFrac, rnd)
        val defenderLosses = defenders.map { applyLosses(it.troops, defFrac, rnd) }

        // ------------------------------------------------ катапульты бьют
        var levelsDown = 0
        if (attackerWon && catapultPower > 0.0 && targetSlot >= 0 && targetSlotLevel > 0) {
            var power = catapultPower
            var lvl = targetSlotLevel
            while (lvl > 0 && power >= 70.0 * lvl) {
                power -= 70.0 * lvl
                lvl--
                levelsDown++
            }
        }

        return BattleResult(
            attackPower = attackPoints,
            defensePower = defensePoints,
            attackerWon = attackerWon,
            attackerLosses = attackerLosses,
            defenderLosses = defenderLosses,
            wallLevelsDestroyed = if (attackerWon) wallDown else 0,
            buildingHitSlot = if (levelsDown > 0) targetSlot else -1,
            buildingLevelsDestroyed = levelsDown,
        )
    }

    /**
     * Дробные потери округляются вероятностно: 0.4 убитых — это 40% шанс
     * потерять ещё одного бойца, а не молчаливое списание в ноль.
     */
    private fun applyLosses(troops: List<Int>, fraction: Double, rnd: Random): MutableList<Int> {
        val f = fraction.coerceIn(0.0, 1.0)
        val out = MutableList(troops.size) { 0 }
        for (i in troops.indices) {
            val n = troops[i]
            if (n == 0) continue
            val exact = n * f
            var killed = floor(exact).toInt()
            if (rnd.nextDouble() < exact - killed) killed++
            out[i] = killed.coerceIn(0, n)
        }
        return out
    }

    /**
     * Разведка — отдельная короткая стычка: разведчики против разведчиков.
     * Проигравшие погибают целиком, победитель приносит данные.
     */
    fun resolveScouting(
        attacker: List<Int>,
        defenders: List<DefenderGroup>,
        wallLevel: Int,
        defenderRace: Race,
    ): Boolean {
        var att = 0.0
        for (i in attacker.indices) {
            if (attacker[i] > 0 && Units[i].kind == UnitKind.SCOUT) att += attacker[i] * Units[i].defI.toDouble()
        }
        var def = 10.0
        for (g in defenders) {
            for (i in g.troops.indices) {
                if (g.troops[i] > 0 && Units[i].kind == UnitKind.SCOUT) def += g.troops[i] * Units[i].defI.toDouble()
            }
        }
        def *= 1.0 + wallLevel * defenderRace.wallBonusPerLevel * 0.5
        return att > def
    }

    /** Оценка боевой силы отряда — для интерфейса и решений ботов. */
    fun offensePower(troops: List<Int>, smithy: Int = 0): Double {
        var p = 0.0
        for (i in troops.indices) if (troops[i] > 0) p += troops[i] * Units[i].att.toDouble()
        return p * (1.0 + smithy * Balance.SMITHY_ATTACK_PER_LEVEL)
    }

    fun defensePower(troops: List<Int>, wallLevel: Int = 0, race: Race = Race.IMPERIUM): Double {
        var p = Balance.VILLAGE_BASE_DEFENSE
        for (i in troops.indices) if (troops[i] > 0) p += troops[i] * (Units[i].defI + Units[i].defC) / 2.0
        return p * (1.0 + wallLevel * race.wallBonusPerLevel)
    }
}
