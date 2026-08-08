package com.robesthud.tribesera.engine

import kotlinx.serialization.Serializable
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Четыре ресурса. Порядок фиксирован — по нему индексируются все массивы
 * склада, производства и добычи.
 */
@Serializable
enum class Res(val title: String, val short: String) {
    WOOD("Древесина", "Дер"),
    CLAY("Глина", "Гли"),
    IRON("Железо", "Жел"),
    CROP("Зерно", "Зер"),
}

val RES = Res.entries.toList()

/** Цена в четырёх ресурсах. Иммутабельна, складывается и масштабируется. */
@Serializable
data class Cost(
    val wood: Int = 0,
    val clay: Int = 0,
    val iron: Int = 0,
    val crop: Int = 0,
) {
    operator fun get(r: Res): Int = when (r) {
        Res.WOOD -> wood
        Res.CLAY -> clay
        Res.IRON -> iron
        Res.CROP -> crop
    }

    operator fun times(k: Double): Cost = Cost(
        (wood * k).roundToInt(),
        (clay * k).roundToInt(),
        (iron * k).roundToInt(),
        (crop * k).roundToInt(),
    )

    operator fun plus(o: Cost): Cost = Cost(wood + o.wood, clay + o.clay, iron + o.iron, crop + o.crop)

    val total: Int get() = wood + clay + iron + crop

    fun asList(): List<Int> = listOf(wood, clay, iron, crop)

    companion object {
        val ZERO = Cost()
        fun of(values: List<Int>) = Cost(values[0], values[1], values[2], values[3])
    }
}

/**
 * Все ручки баланса в одном месте. Сессия рассчитана на 40–60 минут реального
 * времени: экономика тикает в реальных секундах, поэтому числа здесь заметно
 * «быстрее» классических браузерных стратегий.
 */
object Balance {
    /** Слотов ресурсных полей в деревне: 4 леса, 4 глины, 4 железа, 6 зерна. */
    const val FIELD_SLOTS = 18

    /** Слотов под здания. Два последних зарезервированы под точку сбора и стену. */
    const val BUILD_SLOTS = 18
    const val SLOT_RALLY = 16
    const val SLOT_WALL = 17

    const val MAX_FIELD_LEVEL = 20

    /** Добыча одного поля уровня L, единиц в секунду. Нулевой уровень даёт крохи. */
    fun fieldOutput(level: Int): Double = if (level <= 0) 0.15 else 0.5 * level.toDouble().pow(1.4)

    /** Цена апгрейда поля с уровня L на L+1. */
    fun fieldCost(type: Res, level: Int): Cost {
        val base = 60.0 * 1.42.pow(level)
        return when (type) {
            Res.WOOD -> Cost((base * 1.0).roundToInt(), (base * 1.2).roundToInt(), (base * 0.9).roundToInt(), (base * 0.15).roundToInt())
            Res.CLAY -> Cost((base * 1.15).roundToInt(), (base * 1.0).roundToInt(), (base * 0.95).roundToInt(), (base * 0.15).roundToInt())
            Res.IRON -> Cost((base * 1.4).roundToInt(), (base * 1.3).roundToInt(), (base * 1.0).roundToInt(), (base * 0.3).roundToInt())
            Res.CROP -> Cost((base * 0.9).roundToInt(), (base * 1.0).roundToInt(), (base * 0.75).roundToInt(), (base * 0.1).roundToInt())
        }
    }

    /** Время стройки поля уровня L+1 без учёта главного здания, секунды. */
    fun fieldTime(level: Int): Double = 7.0 * 1.30.pow(level)

    /** Население, которое занимает поле уровня L. */
    fun fieldPop(level: Int): Int = if (level <= 0) 0 else (1 + level / 4)

    /** Главное здание сокращает любую стройку. */
    fun buildSpeedup(mainLevel: Int): Double = 1.0 + 0.11 * mainLevel

    /** Вместимость склада (дерево/глина/железо) и амбара (зерно). */
    fun storage(level: Int): Double = 1500.0 * 1.35.pow(level)

    /** Вместимость тайника: столько ресурсов каждого вида не достанется грабителю. */
    fun crannyCapacity(level: Int): Double = if (level <= 0) 0.0 else 400.0 * 1.4.pow(level - 1)

    /** Базовая оборона деревни без войск — чтобы одиночный дубинщик не сносил всё. */
    const val VILLAGE_BASE_DEFENSE = 40.0

    /**
     * Сколько зерна в секунду съедает одна единица содержания (житель или
     * единица прокорма войска).
     */
    const val UPKEEP_PER_SEC = 0.02

    /** Кузница: прибавка к атаке за уровень. */
    const val SMITHY_ATTACK_PER_LEVEL = 0.015

    /** Сколько секунд игрового времени нужно на восстановление 1% лояльности. */
    const val LOYALTY_REGEN_PER_SEC = 0.12

    /** Масштаб цен и времени найма войск — общая ручка темпа милитаризации. */
    const val UNIT_COST = 0.45
    const val UNIT_TIME = 0.42

    /** Казарма/конюшня/мастерская ускоряют найм. */
    fun trainSpeedup(buildingLevel: Int): Double = 1.0 + 0.16 * buildingLevel

    /** Размер карты (клеток по стороне). */
    const val MAP_SIZE = 21

    /**
     * Секунд на одну клетку пути для юнита со скоростью 1.
     * Время похода = дистанция / скорость юнита * эта константа.
     */
    const val TRAVEL_SEC_PER_CELL = 110.0

    /** Чудо света: уровень, на котором объявляется победа. */
    const val WONDER_WIN_LEVEL = 10
}

/** Округление вниз до целого с защитой от отрицательных значений. */
fun Double.floorNonNeg(): Int = if (this <= 0.0) 0 else this.toInt()

/** Компактное «12.3К» для больших чисел в интерфейсе. */
fun formatAmount(v: Double): String {
    val a = kotlin.math.abs(v)
    return when {
        a >= 1_000_000 -> String.format("%.1fМ", v / 1_000_000.0)
        a >= 10_000 -> String.format("%.0fК", v / 1000.0)
        a >= 1_000 -> String.format("%.1fК", v / 1000.0)
        else -> v.toInt().toString()
    }
}

/** «5м 20с» — для таймеров стройки и походов. */
fun formatDuration(seconds: Double): String {
    if (seconds <= 0) return "готово"
    val s = seconds.roundToInt()
    val h = s / 3600
    val m = (s % 3600) / 60
    val sec = s % 60
    return when {
        h > 0 -> "${h}ч ${m}м"
        m > 0 -> "${m}м ${sec}с"
        else -> "${sec}с"
    }
}
