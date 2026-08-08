package com.robesthud.tribesera.engine

import kotlinx.serialization.Serializable

@Serializable
enum class UnitKind(val title: String) {
    INFANTRY("Пехота"),
    CAVALRY("Конница"),
    SCOUT("Разведка"),
    SIEGE("Осадные"),
    CHIEF("Вождь"),
    SETTLER("Поселенец"),
}

/**
 * Описание боевой единицы. [att]/[defI]/[defC] — атака и оборона против пехоты
 * и против конницы; именно эта пара делает «оборонительных» и «атакующих»
 * юнитов разными, а не один общий параметр силы.
 */
@Serializable
data class UnitDef(
    val id: Int,
    val race: Race,
    val title: String,
    val kind: UnitKind,
    val att: Int,
    val defI: Int,
    val defC: Int,
    /** Клеток в час; время похода = дистанция / speed * Balance.TRAVEL_SEC_PER_CELL. */
    val speed: Double,
    /** Сколько ресурсов уносит из чужой деревни. */
    val cap: Int,
    /** Сколько зерна съедает в час. */
    val upkeep: Int,
    val rawCost: Cost,
    val rawTime: Double,
    val from: BuildingType,
    /** Требуемый уровень академии (для вождя и поселенца — уровень резиденции). */
    val rank: Int,
    val note: String = "",
) {
    val cost: Cost get() = rawCost * Balance.UNIT_COST
    val trainSec: Double get() = rawTime * Balance.UNIT_TIME
    val isCavalry: Boolean get() = kind == UnitKind.CAVALRY || kind == UnitKind.SCOUT

    /** Номер юнита внутри своего народа: одинаковые роли стоят на одних местах. */
    val slot: Int get() = id % UNITS_PER_RACE
    val isRam: Boolean get() = kind == UnitKind.SIEGE && slot == 6
    val isCatapult: Boolean get() = kind == UnitKind.SIEGE && slot == 7
}

/** Каталог войск: по 10 на народ, индекс = race.ordinal * 10 + слот. */
object Units {

    val all: List<UnitDef> = buildList {
        // ---------------------------------------------------------------- Империя
        add(u(0, Race.IMPERIUM, "Легионер", UnitKind.INFANTRY, 40, 35, 50, 6.0, 50, 1, Cost(120, 100, 150, 30), 33.0, BuildingType.BARRACKS, 0, "Универсальная пехота: держит удар и сама бьёт"))
        add(u(1, Race.IMPERIUM, "Преторианец", UnitKind.INFANTRY, 30, 65, 35, 5.0, 20, 1, Cost(100, 130, 160, 70), 39.0, BuildingType.BARRACKS, 1, "Стена щитов против чужой пехоты"))
        add(u(2, Race.IMPERIUM, "Империанец", UnitKind.INFANTRY, 70, 40, 25, 7.0, 50, 1, Cost(150, 160, 210, 80), 45.0, BuildingType.BARRACKS, 5, "Основной ударный пехотинец"))
        add(u(3, Race.IMPERIUM, "Конный дозор", UnitKind.SCOUT, 0, 20, 10, 16.0, 0, 2, Cost(140, 160, 20, 40), 30.0, BuildingType.STABLE, 3, "Разведывает гарнизон и склады"))
        add(u(4, Race.IMPERIUM, "Конница Империи", UnitKind.CAVALRY, 120, 65, 50, 14.0, 100, 3, Cost(550, 440, 320, 100), 55.0, BuildingType.STABLE, 5, "Быстрый грабитель с большими сумками"))
        add(u(5, Race.IMPERIUM, "Цезарская конница", UnitKind.CAVALRY, 180, 80, 105, 10.0, 70, 4, Cost(550, 640, 800, 180), 70.0, BuildingType.STABLE, 10, "Лучшая тяжёлая конница в игре"))
        add(u(6, Race.IMPERIUM, "Таран", UnitKind.SIEGE, 60, 30, 75, 4.0, 0, 3, Cost(900, 360, 500, 70), 100.0, BuildingType.WORKSHOP, 10, "Ломает стену перед штурмом"))
        add(u(7, Race.IMPERIUM, "Огненная катапульта", UnitKind.SIEGE, 75, 60, 10, 3.0, 0, 6, Cost(950, 1350, 600, 90), 130.0, BuildingType.WORKSHOP, 15, "Сносит здания и поля противника"))
        add(u(8, Race.IMPERIUM, "Сенатор", UnitKind.CHIEF, 50, 40, 30, 4.0, 0, 5, Cost(4200, 3600, 5000, 3400), 200.0, BuildingType.RESIDENCE, 10, "Сбивает лояльность чужой деревни"))
        add(u(9, Race.IMPERIUM, "Поселенец", UnitKind.SETTLER, 0, 80, 80, 5.0, 0, 1, Cost(1600, 1400, 1900, 1500), 150.0, BuildingType.RESIDENCE, 5, "Трое основывают новую деревню"))

        // ------------------------------------------------------------------ Орда
        add(u(10, Race.HORDE, "Дубинщик", UnitKind.INFANTRY, 40, 20, 5, 7.0, 60, 1, Cost(95, 75, 40, 40), 22.0, BuildingType.BARRACKS, 0, "Дёшев и многочислен — идеальный грабитель"))
        add(u(11, Race.HORDE, "Копейщик", UnitKind.INFANTRY, 10, 35, 60, 7.0, 40, 1, Cost(145, 70, 85, 40), 30.0, BuildingType.BARRACKS, 1, "Держит конницу"))
        add(u(12, Race.HORDE, "Секирщик", UnitKind.INFANTRY, 60, 30, 30, 6.0, 50, 1, Cost(130, 120, 170, 70), 40.0, BuildingType.BARRACKS, 3, "Главная ударная сила Орды"))
        add(u(13, Race.HORDE, "Лазутчик", UnitKind.SCOUT, 0, 10, 5, 9.0, 0, 1, Cost(160, 100, 50, 50), 28.0, BuildingType.BARRACKS, 5, "Пеший разведчик, дешёвый и незаметный"))
        add(u(14, Race.HORDE, "Паладин", UnitKind.CAVALRY, 55, 100, 40, 10.0, 110, 2, Cost(370, 270, 290, 75), 60.0, BuildingType.STABLE, 5, "Оборонительная конница с большим рюкзаком"))
        add(u(15, Race.HORDE, "Всадник Орды", UnitKind.CAVALRY, 150, 50, 75, 9.0, 80, 3, Cost(450, 515, 480, 80), 68.0, BuildingType.STABLE, 10, "Тяжёлый кулак Орды"))
        add(u(16, Race.HORDE, "Стенобой", UnitKind.SIEGE, 65, 30, 80, 4.0, 0, 3, Cost(1000, 300, 350, 70), 100.0, BuildingType.WORKSHOP, 10, "Лучший таран в игре"))
        add(u(17, Race.HORDE, "Камнемёт", UnitKind.SIEGE, 50, 60, 10, 3.0, 0, 6, Cost(900, 1200, 600, 60), 130.0, BuildingType.WORKSHOP, 15, "Разрушает постройки"))
        add(u(18, Race.HORDE, "Вождь", UnitKind.CHIEF, 40, 60, 40, 4.0, 0, 4, Cost(3500, 3200, 4200, 3000), 190.0, BuildingType.RESIDENCE, 10, "Самый дешёвый захватчик деревень"))
        add(u(19, Race.HORDE, "Поселенец", UnitKind.SETTLER, 10, 80, 80, 5.0, 0, 1, Cost(1500, 1300, 1800, 1400), 150.0, BuildingType.RESIDENCE, 5, "Трое основывают новую деревню"))

        // ---------------------------------------------------------- Лесной народ
        add(u(20, Race.SYLVAN, "Фаланга", UnitKind.INFANTRY, 15, 40, 50, 7.0, 35, 1, Cost(100, 130, 55, 30), 25.0, BuildingType.BARRACKS, 0, "Дешёвая универсальная оборона"))
        add(u(21, Race.SYLVAN, "Мечник", UnitKind.INFANTRY, 65, 35, 20, 6.0, 45, 1, Cost(140, 150, 185, 60), 38.0, BuildingType.BARRACKS, 1, "Пехотный таран лесных"))
        add(u(22, Race.SYLVAN, "Следопыт", UnitKind.SCOUT, 0, 20, 10, 17.0, 0, 2, Cost(170, 150, 20, 40), 30.0, BuildingType.STABLE, 3, "Самая быстрая разведка"))
        add(u(23, Race.SYLVAN, "Гром Тевтата", UnitKind.CAVALRY, 90, 25, 40, 19.0, 75, 2, Cost(350, 450, 230, 60), 50.0, BuildingType.STABLE, 5, "Молниеносный набег — прилетает раньше ответа"))
        add(u(24, Race.SYLVAN, "Друид-всадник", UnitKind.CAVALRY, 45, 115, 55, 16.0, 35, 2, Cost(360, 330, 280, 120), 58.0, BuildingType.STABLE, 5, "Лучшая оборона против пехоты"))
        add(u(25, Race.SYLVAN, "Эдуйская конница", UnitKind.CAVALRY, 140, 60, 165, 13.0, 65, 3, Cost(500, 620, 675, 170), 75.0, BuildingType.STABLE, 10, "И бьёт, и держит чужую конницу"))
        add(u(26, Race.SYLVAN, "Таран лесных", UnitKind.SIEGE, 50, 30, 105, 4.0, 0, 3, Cost(950, 555, 330, 75), 100.0, BuildingType.WORKSHOP, 10, "Ломает стену"))
        add(u(27, Race.SYLVAN, "Требушет", UnitKind.SIEGE, 70, 45, 10, 3.0, 0, 6, Cost(960, 1450, 630, 90), 130.0, BuildingType.WORKSHOP, 15, "Дальнобойное разрушение"))
        add(u(28, Race.SYLVAN, "Вождь друидов", UnitKind.CHIEF, 40, 50, 50, 5.0, 0, 4, Cost(3800, 3400, 4600, 3200), 195.0, BuildingType.RESIDENCE, 10, "Быстрее прочих вождей"))
        add(u(29, Race.SYLVAN, "Поселенец", UnitKind.SETTLER, 0, 80, 80, 5.0, 0, 1, Cost(1550, 1350, 1850, 1450), 150.0, BuildingType.RESIDENCE, 5, "Трое основывают новую деревню"))
    }

    private fun u(
        id: Int, race: Race, title: String, kind: UnitKind,
        att: Int, defI: Int, defC: Int, speed: Double, cap: Int, upkeep: Int,
        cost: Cost, time: Double, from: BuildingType, rank: Int, note: String,
    ) = UnitDef(id, race, title, kind, att, defI, defC, speed, cap, upkeep, cost, time, from, rank, note)

    val count: Int get() = all.size

    operator fun get(id: Int): UnitDef = all[id]

    fun of(race: Race): List<UnitDef> = all.filter { it.race == race }

    /** Сколько поселенцев нужно, чтобы основать деревню. */
    const val SETTLERS_TO_FOUND = 3
}

/** Пустой отряд — вектор длиной в весь каталог. */
fun emptyTroops(): MutableList<Int> = MutableList(Units.count) { 0 }

fun List<Int>.troopTotal(): Int = sum()

fun List<Int>.isEmptyArmy(): Boolean = all { it == 0 }

fun MutableList<Int>.addTroops(other: List<Int>) {
    for (i in indices) this[i] += other[i]
}

fun MutableList<Int>.subTroops(other: List<Int>) {
    for (i in indices) this[i] = (this[i] - other[i]).coerceAtLeast(0)
}

/** Грузоподъёмность отряда с учётом бонуса народа. */
fun List<Int>.carryCapacity(race: Race): Double {
    var c = 0.0
    for (i in indices) if (this[i] > 0) c += this[i] * Units[i].cap
    return c * race.lootMultiplier
}

/** Самый медленный юнит определяет скорость всего похода. */
fun List<Int>.marchSpeed(): Double {
    var s = Double.MAX_VALUE
    for (i in indices) if (this[i] > 0) s = minOf(s, Units[i].speed)
    return if (s == Double.MAX_VALUE) 6.0 else s
}

fun List<Int>.upkeep(): Int {
    var u = 0
    for (i in indices) if (this[i] > 0) u += this[i] * Units[i].upkeep
    return u
}
