package com.robesthud.tribesera.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat

// --------------------------------------------------------------------------
// Палитра: тёплое золото на глубоком хвойном фоне.
// --------------------------------------------------------------------------

object Pal {
    val bg = Color(0xFF0E1A17)
    val bgDeep = Color(0xFF091210)
    val surface = Color(0xFF16241F)
    val surfaceHi = Color(0xFF1E332B)
    val surfaceLo = Color(0xFF122019)
    val outline = Color(0xFF2C463B)
    val outlineSoft = Color(0xFF24382F)

    val gold = Color(0xFFE8B14C)
    val goldDim = Color(0xFFB88532)
    val jade = Color(0xFF4FB286)
    val danger = Color(0xFFE05C3E)
    val warn = Color(0xFFE8A33D)

    val text = Color(0xFFF2EEE4)
    val textDim = Color(0xFFA6B5AC)
    val textFaint = Color(0xFF6E8378)

    // Ресурсы
    val wood = Color(0xFF9B6B3F)
    val clay = Color(0xFFC96F44)
    val iron = Color(0xFF93A6B5)
    val crop = Color(0xFFE0B33F)

    fun res(index: Int) = when (index) {
        0 -> wood
        1 -> clay
        2 -> iron
        else -> crop
    }

    // Ландшафт
    val grass = Color(0xFF3E6B48)
    val grassLo = Color(0xFF2F5439)
    val grassHi = Color(0xFF4E8256)
    val dirt = Color(0xFF6E5637)
    val dirtLo = Color(0xFF4E3D27)
    val stone = Color(0xFF8C948F)
    val stoneLo = Color(0xFF5F6864)
    val water = Color(0xFF2E6E85)

    /** Цвета игроков на карте. */
    val players = listOf(
        Color(0xFF4FB286), // свой — нефрит
        Color(0xFFE05C3E),
        Color(0xFF7C6CE0),
        Color(0xFFE8B14C),
        Color(0xFF3FA0C9),
        Color(0xFFCF5FA8),
        Color(0xFF8FBF3F),
        Color(0xFFD98A3F),
    )

    fun player(index: Int) = players[index % players.size]

    val screenGradient = Brush.verticalGradient(listOf(bgDeep, bg, Color(0xFF10201A)))
}

private val scheme = darkColorScheme(
    primary = Pal.gold,
    onPrimary = Color(0xFF211603),
    primaryContainer = Pal.goldDim,
    onPrimaryContainer = Color(0xFF120C02),
    secondary = Pal.jade,
    onSecondary = Color(0xFF04160E),
    background = Pal.bg,
    onBackground = Pal.text,
    surface = Pal.surface,
    onSurface = Pal.text,
    surfaceVariant = Pal.surfaceHi,
    onSurfaceVariant = Pal.textDim,
    outline = Pal.outline,
    error = Pal.danger,
)

private fun display(size: Int, weight: FontWeight, spacing: Double = 0.0) = TextStyle(
    fontFamily = FontFamily.Default,
    fontWeight = weight,
    fontSize = size.sp,
    letterSpacing = spacing.sp,
)

private val typo = Typography(
    displaySmall = display(30, FontWeight.Black, (-0.5)),
    headlineMedium = display(24, FontWeight.Bold, (-0.3)),
    headlineSmall = display(20, FontWeight.Bold, (-0.2)),
    titleLarge = display(18, FontWeight.Bold),
    titleMedium = display(16, FontWeight.SemiBold),
    titleSmall = display(14, FontWeight.SemiBold, 0.1),
    bodyLarge = display(15, FontWeight.Normal),
    bodyMedium = display(13, FontWeight.Normal),
    bodySmall = display(12, FontWeight.Normal),
    labelLarge = display(14, FontWeight.SemiBold, 0.2),
    labelMedium = display(12, FontWeight.SemiBold, 0.3),
    labelSmall = display(10, FontWeight.Bold, 0.6),
)

@Composable
fun TribesEraTheme(content: @Composable () -> Unit) {
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as? Activity)?.window ?: return@SideEffect
            WindowCompat.setDecorFitsSystemWindows(window, false)
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
        }
    }
    MaterialTheme(colorScheme = scheme, typography = typo, content = content)
}

/** Скруглённость карточек по всему приложению. */
val CardRadius = 18.dp
val ChipRadius = 12.dp
