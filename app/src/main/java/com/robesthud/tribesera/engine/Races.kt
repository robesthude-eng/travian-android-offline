package com.robesthud.tribesera.engine

import kotlinx.serialization.Serializable

/**
 * Три народа. Здания у всех одинаковые, различия — в войсках, их цене и в
 * наборе пассивных бонусов ниже.
 */
@Serializable
enum class Race(
    val title: String,
    val motto: String,
    val lore: String,
    /** Прибавка к обороне за каждый уровень стены. */
    val wallBonusPerLevel: Double,
    /** Множитель добычи, которую войско уносит из чужой деревни. */
    val lootMultiplier: Double,
    /** Множитель вместимости собственного тайника. */
    val crannyMultiplier: Double,
    /** Какую долю чужого тайника войско всё-таки вскрывает. */
    val crannyPiercing: Double,
    /** Можно ли одновременно строить поле и здание. */
    val parallelBuild: Boolean,
    /** Множитель скорости передвижения войск. */
    val marchSpeed: Double,
    val perks: List<String>,
) {
    IMPERIUM(
        title = "Империя",
        motto = "Дисциплина и камень",
        lore = "Тяжёлые легионы, дорогие войска и лучшие в мире стены. " +
            "Медленно разгоняется, но пробить её оборону почти невозможно.",
        wallBonusPerLevel = 0.030,
        lootMultiplier = 1.0,
        crannyMultiplier = 1.0,
        crannyPiercing = 0.0,
        parallelBuild = true,
        marchSpeed = 1.0,
        perks = listOf(
            "Стена даёт +3% обороны за уровень — вдвое больше остальных",
            "Строит поле и здание одновременно",
            "Дорогие, но самые сбалансированные войска",
        ),
    ),
    HORDE(
        title = "Орда",
        motto = "Ярость и добыча",
        lore = "Дешёвая и злая пехота, которая живёт грабежом. Слабые стены " +
            "и посредственная оборона — но враг разорён раньше, чем успеет это заметить.",
        wallBonusPerLevel = 0.020,
        lootMultiplier = 1.25,
        crannyMultiplier = 0.8,
        crannyPiercing = 0.33,
        parallelBuild = false,
        marchSpeed = 0.95,
        perks = listOf(
            "+25% к добыче из чужих деревень",
            "Вскрывает треть вражеского тайника",
            "Самые дешёвые войска в игре",
        ),
    ),
    SYLVAN(
        title = "Лесной народ",
        motto = "Скорость и хитрость",
        lore = "Быстрая конница, крепкая оборона и вместительные тайники. " +
            "Бьёт первым, уходит раньше, чем прилетит ответ.",
        wallBonusPerLevel = 0.025,
        lootMultiplier = 1.0,
        crannyMultiplier = 2.0,
        crannyPiercing = 0.0,
        parallelBuild = false,
        marchSpeed = 1.15,
        perks = listOf(
            "Войска движутся на 15% быстрее",
            "Тайник прячет вдвое больше ресурсов",
            "Лучшая в игре оборонительная конница",
        ),
    );

    /** Индексы юнитов этого народа в глобальном каталоге. */
    val unitRange: IntRange get() = (ordinal * UNITS_PER_RACE) until ((ordinal + 1) * UNITS_PER_RACE)
}

const val UNITS_PER_RACE = 10
