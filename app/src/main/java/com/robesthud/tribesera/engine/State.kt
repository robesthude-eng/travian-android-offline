package com.robesthud.tribesera.engine

import kotlinx.serialization.Serializable
import kotlin.math.roundToInt
import kotlin.math.sqrt

// --------------------------------------------------------------------------
// Настройки партии
// --------------------------------------------------------------------------

@Serializable
enum class Difficulty(
    val title: String,
    val desc: String,
    /** Множитель добычи ресурсов у ботов. */
    val aiEconomy: Double,
    /** Как часто бот принимает решения, секунды. */
    val aiPeriod: Double,
    /** Насколько охотно бот идёт в атаку. */
    val aiAggression: Double,
) {
    EASY("Спокойная", "Боты развиваются медленно и редко нападают", 0.75, 6.0, 0.5),
    NORMAL("Обычная", "Честная партия: у ботов те же правила, что и у вас", 1.0, 4.0, 1.0),
    HARD("Сложная", "Боты богаче, думают чаще и бьют по слабым местам", 1.35, 2.5, 1.4),
    BRUTAL("Беспощадная", "Соперники не прощают ни одной ошибки", 1.75, 1.5, 1.9),
}

@Serializable
enum class SessionLength(val title: String, val seconds: Double) {
    SHORT("Быстрая — 40 минут", 40 * 60.0),
    MEDIUM("Обычная — 60 минут", 60 * 60.0),
    LONG("Долгая — 90 минут", 90 * 60.0),
}

@Serializable
data class GameSettings(
    val playerName: String = "Вождь",
    val race: Race = Race.IMPERIUM,
    val difficulty: Difficulty = Difficulty.NORMAL,
    val length: SessionLength = SessionLength.MEDIUM,
    val opponents: Int = 5,
    val seed: Long = 0L,
)

// --------------------------------------------------------------------------
// Игроки
// --------------------------------------------------------------------------

/** Характер бота определяет, во что он вкладывает ресурсы. */
@Serializable
enum class Personality(val title: String, val econWeight: Double, val armyWeight: Double, val raidWeight: Double) {
    ECONOMIST("Хозяин", 0.80, 0.20, 0.4),
    BALANCED("Расчётливый", 0.55, 0.45, 1.0),
    RUSHER("Налётчик", 0.35, 0.65, 1.8),
    STRATEGIST("ИИ-стратег", 0.55, 0.45, 1.3),
}

@Serializable
data class Player(
    val id: Int,
    val name: String,
    val race: Race,
    val human: Boolean,
    val colorIndex: Int,
    val personality: Personality = Personality.BALANCED,
    var defeated: Boolean = false,
    var thinkCooldown: Double = 0.0,
    var warCooldown: Double = 0.0,
    /** Накопленный «выигрыш» очков за уничтоженные войска — для итоговой таблицы. */
    var kills: Int = 0,
    var losses: Int = 0,
)

// --------------------------------------------------------------------------
// Деревня
// --------------------------------------------------------------------------

@Serializable
data class BuildJob(
    /** true — ресурсное поле, false — здание в слоте деревни. */
    val field: Boolean,
    val slot: Int,
    val type: Int,
    val targetLevel: Int,
    val totalTime: Double,
    var remaining: Double,
)

@Serializable
data class TrainJob(
    val unitId: Int,
    var left: Int,
    val perUnit: Double,
    var progress: Double = 0.0,
)

/** Чужие войска, стоящие в деревне на обороне. */
@Serializable
data class Reinforcement(
    val ownerId: Int,
    val troops: MutableList<Int>,
)

@Serializable
data class Village(
    val id: Int,
    var name: String,
    var ownerId: Int,
    val x: Int,
    val y: Int,
    var capital: Boolean = false,
    val fieldType: MutableList<Int> = defaultFieldTypes(),
    val fieldLevel: MutableList<Int> = MutableList(Balance.FIELD_SLOTS) { 0 },
    val slotType: MutableList<Int> = MutableList(Balance.BUILD_SLOTS) { -1 },
    val slotLevel: MutableList<Int> = MutableList(Balance.BUILD_SLOTS) { 0 },
    val stock: MutableList<Double> = mutableListOf(750.0, 750.0, 750.0, 750.0),
    val troops: MutableList<Int> = emptyTroops(),
    val reinforcements: MutableList<Reinforcement> = mutableListOf(),
    var loyalty: Double = 100.0,
    val buildQueue: MutableList<BuildJob> = mutableListOf(),
    val trainQueue: MutableList<TrainJob> = mutableListOf(),
    val oasisIds: MutableList<Int> = mutableListOf(),
    /** Юниты, ушедшие в поход, — чтобы показывать «в пути» в интерфейсе. */
    var founded: Double = 0.0,
) {
    // ---------------------------------------------------------------- здания

    /** Максимальный уровень здания данного типа в деревне (0 — нет такого). */
    fun level(type: BuildingType): Int {
        var best = 0
        for (i in slotType.indices) {
            if (slotType[i] == type.ordinal) best = maxOf(best, slotLevel[i])
        }
        return best
    }

    fun instances(type: BuildingType): Int = slotType.count { it == type.ordinal }

    fun slotOf(type: BuildingType): Int = slotType.indexOfFirst { it == type.ordinal }

    fun buildingAt(slot: Int): BuildingType? =
        slotType[slot].takeIf { it >= 0 }?.let { BuildingType.entries[it] }

    // -------------------------------------------------------------- экономика

    /** Валовая добыча ресурса в секунду с учётом бонусов оазисов. */
    fun grossOutput(res: Res, oasisBonus: Double): Double {
        var out = 0.0
        for (i in fieldType.indices) {
            if (fieldType[i] == res.ordinal) out += Balance.fieldOutput(fieldLevel[i])
        }
        return out * (1.0 + oasisBonus)
    }

    fun population(): Int {
        var pop = 0
        for (l in fieldLevel) pop += Balance.fieldPop(l)
        for (i in slotType.indices) {
            val t = slotType[i]
            if (t >= 0) pop += BuildingType.entries[t].popAt(slotLevel[i])
        }
        return pop
    }

    /** Сколько единиц содержания висит на деревне: население плюс войска. */
    fun upkeepPoints(): Int {
        var upkeep = troops.upkeep()
        for (r in reinforcements) upkeep += r.troops.upkeep()
        return population() + upkeep
    }

    /** Потребление зерна в секунду. */
    fun cropDrain(): Double = upkeepPoints() * Balance.UPKEEP_PER_SEC

    fun storageCap(): Double {
        var cap = 1500.0
        for (i in slotType.indices) {
            if (slotType[i] == BuildingType.WAREHOUSE.ordinal) cap += Balance.storage(slotLevel[i]) - 1500.0
        }
        return cap
    }

    fun granaryCap(): Double {
        var cap = 1500.0
        for (i in slotType.indices) {
            if (slotType[i] == BuildingType.GRANARY.ordinal) cap += Balance.storage(slotLevel[i]) - 1500.0
        }
        return cap
    }

    fun capOf(res: Res): Double = if (res == Res.CROP) granaryCap() else storageCap()

    fun crannyHidden(race: Race): Double {
        var c = 0.0
        for (i in slotType.indices) {
            if (slotType[i] == BuildingType.CRANNY.ordinal) c += Balance.crannyCapacity(slotLevel[i])
        }
        return c * race.crannyMultiplier
    }

    fun canAfford(cost: Cost): Boolean =
        stock[0] >= cost.wood && stock[1] >= cost.clay && stock[2] >= cost.iron && stock[3] >= cost.crop

    fun pay(cost: Cost) {
        stock[0] -= cost.wood
        stock[1] -= cost.clay
        stock[2] -= cost.iron
        stock[3] -= cost.crop
    }

    fun refund(cost: Cost) {
        for (i in 0..3) stock[i] = (stock[i] + cost.asList()[i]).coerceAtMost(capOf(RES[i]))
    }

    /** Суммарная оборона всех стоящих здесь войск против заданного состава атаки. */
    fun allDefenders(): List<Pair<Int, List<Int>>> = buildList {
        add(ownerId to troops)
        for (r in reinforcements) add(r.ownerId to r.troops)
    }

    fun score(): Int {
        var s = 0
        for (l in fieldLevel) s += l * 2
        for (i in slotType.indices) if (slotType[i] >= 0) s += slotLevel[i] * 3
        return s
    }
}

/** Классическая раскладка 4 леса / 4 глины / 4 железа / 6 зерна. */
fun defaultFieldTypes(): MutableList<Int> = mutableListOf(
    Res.CROP.ordinal, Res.WOOD.ordinal, Res.CLAY.ordinal, Res.IRON.ordinal,
    Res.CROP.ordinal, Res.WOOD.ordinal, Res.CLAY.ordinal, Res.IRON.ordinal,
    Res.CROP.ordinal, Res.WOOD.ordinal, Res.CLAY.ordinal, Res.IRON.ordinal,
    Res.CROP.ordinal, Res.WOOD.ordinal, Res.CLAY.ordinal, Res.IRON.ordinal,
    Res.CROP.ordinal, Res.CROP.ordinal,
)

// --------------------------------------------------------------------------
// Оазисы
// --------------------------------------------------------------------------

@Serializable
data class Oasis(
    val id: Int,
    val x: Int,
    val y: Int,
    val res: Int,
    val bonusPct: Int,
    /** Второй ресурс для двойных оазисов, иначе -1. */
    val res2: Int = -1,
    var ownerVillage: Int = -1,
    /** Оборона диких зверей: обнуляется при захвате, медленно восстанавливается. */
    var wildDefense: Double = 0.0,
    var stock: Double = 0.0,
) {
    fun bonusFor(r: Res): Double = when (r.ordinal) {
        res, res2 -> bonusPct / 100.0
        else -> 0.0
    }

    val title: String
        get() = if (res2 >= 0) {
            "Оазис ${RES[res].title.lowercase()} и ${RES[res2].title.lowercase()}"
        } else {
            "Оазис ${RES[res].title.lowercase()}"
        }
}

// --------------------------------------------------------------------------
// Походы
// --------------------------------------------------------------------------

@Serializable
enum class MoveKind(val title: String) {
    RAID("Набег"),
    ATTACK("Штурм"),
    REINFORCE("Подкрепление"),
    SETTLE("Основание деревни"),
    SCOUT("Разведка"),
    RETURN("Возвращение"),
}

@Serializable
data class Movement(
    val id: Int,
    val ownerId: Int,
    val fromVillage: Int,
    val targetVillage: Int = -1,
    val targetOasis: Int = -1,
    val tx: Int = 0,
    val ty: Int = 0,
    val kind: MoveKind,
    val troops: MutableList<Int>,
    val start: Double,
    var arrive: Double,
    val loot: MutableList<Double> = mutableListOf(0.0, 0.0, 0.0, 0.0),
    /** Тип здания, по которому бьют катапульты (ordinal); -1 — случайная цель. */
    val catTarget: Int = -1,
) {
    fun progress(now: Double): Double =
        ((now - start) / (arrive - start).coerceAtLeast(0.001)).coerceIn(0.0, 1.0)
}

// --------------------------------------------------------------------------
// Отчёты
// --------------------------------------------------------------------------

@Serializable
enum class ReportKind { RAID, DEFENSE, SCOUT, SYSTEM, CONQUEST, SETTLE }

@Serializable
data class Report(
    val id: Int,
    val ownerId: Int,
    val time: Double,
    val kind: ReportKind,
    val title: String,
    val subtitle: String,
    val lines: List<String> = emptyList(),
    val loot: List<Double> = listOf(0.0, 0.0, 0.0, 0.0),
    val success: Boolean = true,
    var read: Boolean = false,
)

// --------------------------------------------------------------------------
// Мир
// --------------------------------------------------------------------------

@Serializable
data class GameState(
    val settings: GameSettings,
    var time: Double = 0.0,
    val players: MutableList<Player> = mutableListOf(),
    val villages: MutableList<Village> = mutableListOf(),
    val oases: MutableList<Oasis> = mutableListOf(),
    val movements: MutableList<Movement> = mutableListOf(),
    val reports: MutableList<Report> = mutableListOf(),
    var nextId: Int = 1,
    var over: Boolean = false,
    var winnerId: Int = -1,
    var winReason: String = "",
) {
    fun newId(): Int = nextId++

    fun player(id: Int): Player = players.first { it.id == id }

    fun playerOrNull(id: Int): Player? = players.firstOrNull { it.id == id }

    fun village(id: Int): Village? = villages.firstOrNull { it.id == id }

    fun villagesOf(playerId: Int): List<Village> = villages.filter { it.ownerId == playerId }

    fun villageAt(x: Int, y: Int): Village? = villages.firstOrNull { it.x == x && it.y == y }

    fun oasisAt(x: Int, y: Int): Oasis? = oases.firstOrNull { it.x == x && it.y == y }

    val human: Player get() = players.first { it.human }

    val timeLeft: Double get() = (settings.length.seconds - time).coerceAtLeast(0.0)

    /** Суммарный бонус оазисов, привязанных к деревне. */
    fun oasisBonus(v: Village, r: Res): Double {
        var b = 0.0
        for (id in v.oasisIds) {
            val o = oases.firstOrNull { it.id == id } ?: continue
            b += o.bonusFor(r)
        }
        return b
    }

    /**
     * Фора ботов на высокой сложности. Живой игрок всегда играет по базовым
     * правилам — сложность меняет только соперников.
     */
    fun outputMultiplier(playerId: Int): Double =
        if (playerOrNull(playerId)?.human != false) 1.0 else settings.difficulty.aiEconomy

    fun netOutput(v: Village, r: Res): Double {
        val gross = v.grossOutput(r, oasisBonus(v, r)) * outputMultiplier(v.ownerId)
        return if (r == Res.CROP) gross - v.cropDrain() else gross
    }

    fun raceOf(playerId: Int): Race = playerOrNull(playerId)?.race ?: Race.IMPERIUM

    fun score(playerId: Int): Int {
        var s = 0
        for (v in villagesOf(playerId)) {
            s += v.score() + v.population()
            for (i in v.troops.indices) {
                if (v.troops[i] > 0) s += (v.troops[i] * (Units[i].att + Units[i].defI + Units[i].defC) / 300.0).roundToInt()
            }
        }
        for (m in movements) {
            if (m.ownerId != playerId) continue
            for (i in m.troops.indices) {
                if (m.troops[i] > 0) s += (m.troops[i] * (Units[i].att + Units[i].defI + Units[i].defC) / 300.0).roundToInt()
            }
        }
        return s
    }

    fun leaderboard(): List<Pair<Player, Int>> =
        players.map { it to score(it.id) }.sortedByDescending { it.second }
}

/** Евклидова дистанция между клетками карты. */
fun dist(x1: Int, y1: Int, x2: Int, y2: Int): Double {
    val dx = (x1 - x2).toDouble()
    val dy = (y1 - y2).toDouble()
    return sqrt(dx * dx + dy * dy)
}

/** Время похода в секундах. */
fun travelTime(distance: Double, speed: Double, race: Race): Double =
    (distance / (speed * race.marchSpeed)) * Balance.TRAVEL_SEC_PER_CELL
