package com.robesthud.tribesera.engine

import kotlinx.serialization.Serializable
import kotlin.math.pow
import kotlin.math.roundToInt

@Serializable
enum class BuildCategory(val title: String) {
    INFRA("Инфраструктура"),
    MILITARY("Военные"),
    SPECIAL("Особые"),
}

/**
 * Здания одинаковы для всех народов — различаются только войска, которые в них
 * нанимают. [baseCost] — цена первого уровня, дальше умножается на [costFactor].
 */
@Serializable
enum class BuildingType(
    val title: String,
    val desc: String,
    val category: BuildCategory,
    val maxLevel: Int,
    val baseCost: Cost,
    val costFactor: Double,
    val baseTime: Double,
    val basePop: Int,
    /** Сколько таких зданий разрешено в одной деревне. */
    val maxInstances: Int = 1,
) {
    MAIN(
        "Главное здание", "Ускоряет любую стройку в деревне на 11% за уровень.",
        BuildCategory.INFRA, 20, Cost(70, 40, 60, 20), 1.40, 20.0, 2,
    ),
    WAREHOUSE(
        "Склад", "Хранит древесину, глину и железо. Всё, что не влезло, пропадает.",
        BuildCategory.INFRA, 20, Cost(130, 160, 90, 40), 1.35, 22.0, 1, maxInstances = 3,
    ),
    GRANARY(
        "Амбар", "Хранит зерно. Пустой амбар при отрицательном балансе — голод в войсках.",
        BuildCategory.INFRA, 20, Cost(80, 100, 70, 20), 1.35, 20.0, 1, maxInstances = 3,
    ),
    CRANNY(
        "Тайник", "Прячет часть ресурсов от грабителей.",
        BuildCategory.INFRA, 10, Cost(40, 50, 30, 10), 1.40, 15.0, 0, maxInstances = 3,
    ),
    MARKET(
        "Рынок", "Обмен ресурсов по курсу и отправка ресурсов в свои деревни.",
        BuildCategory.INFRA, 20, Cost(80, 70, 120, 70), 1.40, 40.0, 4,
    ),
    ACADEMY(
        "Академия", "Открывает новые типы войск. Чем выше уровень, тем серьёзнее список.",
        BuildCategory.MILITARY, 20, Cost(220, 160, 90, 40), 1.40, 50.0, 4,
    ),
    BARRACKS(
        "Казарма", "Нанимает пехоту. Каждый уровень ускоряет найм на 16%.",
        BuildCategory.MILITARY, 20, Cost(210, 140, 260, 120), 1.40, 45.0, 4,
    ),
    SMITHY(
        "Кузница", "+1.5% к атаке всех войск деревни за уровень.",
        BuildCategory.MILITARY, 20, Cost(180, 250, 500, 160), 1.40, 60.0, 4,
    ),
    STABLE(
        "Конюшня", "Нанимает конницу и разведчиков.",
        BuildCategory.MILITARY, 20, Cost(260, 140, 220, 100), 1.40, 55.0, 5,
    ),
    WORKSHOP(
        "Мастерская", "Нанимает тараны и катапульты — они ломают стены и здания.",
        BuildCategory.MILITARY, 20, Cost(460, 510, 600, 320), 1.40, 80.0, 3,
    ),
    RESIDENCE(
        "Резиденция", "Готовит поселенцев и вождей, защищает деревню от захвата.",
        BuildCategory.SPECIAL, 20, Cost(580, 460, 350, 180), 1.35, 70.0, 1,
    ),
    RALLY(
        "Точка сбора", "Отсюда уходят походы. Уровень ускоряет возвращение войск.",
        BuildCategory.SPECIAL, 20, Cost(110, 160, 90, 70), 1.35, 25.0, 0,
    ),
    WALL(
        "Стена", "Умножает оборону гарнизона. У Империи стена сильнее всех.",
        BuildCategory.SPECIAL, 20, Cost(110, 160, 70, 30), 1.35, 30.0, 0,
    ),
    WONDER(
        "Чудо света", "Достроить до 10 уровня — немедленная победа в партии.",
        BuildCategory.SPECIAL, Balance.WONDER_WIN_LEVEL, Cost(1500, 1400, 1700, 1100), 1.28, 60.0, 8,
    );

    fun costAt(level: Int): Cost = baseCost * costFactor.pow(level - 1)

    fun timeAt(level: Int): Double = baseTime * 1.28.pow(level - 1)

    /** Суммарное население, которое занимает здание, доросшее до уровня [level]. */
    fun popAt(level: Int): Int =
        if (level <= 0) 0 else (basePop * level.toDouble().pow(0.85)).roundToInt()

    /** Требования: какие здания и до какого уровня нужны, чтобы это построить. */
    val requirements: List<Pair<BuildingType, Int>>
        get() = when (this) {
            MAIN, CRANNY, RALLY, WALL -> emptyList()
            WAREHOUSE, GRANARY -> listOf(MAIN to 1)
            MARKET -> listOf(MAIN to 3, WAREHOUSE to 1, GRANARY to 1)
            ACADEMY -> listOf(MAIN to 3, RALLY to 1)
            BARRACKS -> listOf(MAIN to 3, RALLY to 1)
            SMITHY -> listOf(MAIN to 3, ACADEMY to 1)
            STABLE -> listOf(ACADEMY to 5, SMITHY to 3)
            WORKSHOP -> listOf(MAIN to 5, ACADEMY to 10)
            RESIDENCE -> listOf(MAIN to 5, ACADEMY to 5)
            WONDER -> listOf(MAIN to 10, WAREHOUSE to 12, RESIDENCE to 5)
        }

    /** Короткая строка «что даст следующий уровень». */
    fun effectAt(level: Int, race: Race): String = when (this) {
        MAIN -> "стройка быстрее в ${"%.2f".format(Balance.buildSpeedup(level))}×"
        WAREHOUSE -> "+${formatAmount(Balance.storage(level) - 1500.0)} к складу"
        GRANARY -> "+${formatAmount(Balance.storage(level) - 1500.0)} к амбару"
        CRANNY -> "прячет ${formatAmount(Balance.crannyCapacity(level) * race.crannyMultiplier)} каждого ресурса"
        MARKET -> "курс обмена ${"%.2f".format(marketRate(level))} и +${level} торговцев"
        ACADEMY -> "открыты войска до ${level} ранга"
        BARRACKS -> "найм пехоты быстрее в ${"%.2f".format(Balance.trainSpeedup(level))}×"
        SMITHY -> "+${(level * Balance.SMITHY_ATTACK_PER_LEVEL * 100).roundToInt()}% к атаке"
        STABLE -> "найм конницы быстрее в ${"%.2f".format(Balance.trainSpeedup(level))}×"
        WORKSHOP -> "найм осадных быстрее в ${"%.2f".format(Balance.trainSpeedup(level))}×"
        RESIDENCE -> "${settlerSlots(level)} мест под поселенцев, лояльность крепче на ${level * 5}%"
        RALLY -> "возврат войск быстрее на ${(level * 2)}%"
        WALL -> "+${(level * race.wallBonusPerLevel * 100).roundToInt()}% к обороне"
        WONDER -> if (level >= Balance.WONDER_WIN_LEVEL) "ПОБЕДА В ПАРТИИ" else "до победы ${Balance.WONDER_WIN_LEVEL - level} уровней"
    }

    companion object {
        /** Курс обмена на рынке: сколько получаешь за единицу отданного. */
        fun marketRate(level: Int): Double = 0.55 + 0.02 * level

        /** Сколько поселенцев/вождей одновременно содержит резиденция. */
        fun settlerSlots(level: Int): Int = when {
            level >= 15 -> 3
            level >= 10 -> 2
            level >= 5 -> 1
            else -> 0
        }
    }
}
