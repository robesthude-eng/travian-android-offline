package com.robesthud.tribesera.ui

import android.graphics.Bitmap
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.font.createFontFamilyResolver
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.test.core.app.ApplicationProvider
import com.robesthud.tribesera.engine.Balance
import com.robesthud.tribesera.engine.BuildingType
import com.robesthud.tribesera.engine.Engine
import com.robesthud.tribesera.engine.GameSettings
import com.robesthud.tribesera.engine.GameState
import com.robesthud.tribesera.engine.RES
import com.robesthud.tribesera.engine.Race
import com.robesthud.tribesera.engine.Res
import com.robesthud.tribesera.engine.UnitKind
import com.robesthud.tribesera.engine.Units
import com.robesthud.tribesera.engine.Village
import com.robesthud.tribesera.engine.WorldGen
import com.robesthud.tribesera.ui.art.IsoGrid
import com.robesthud.tribesera.ui.art.drawBuilding
import com.robesthud.tribesera.ui.art.drawResourceField
import com.robesthud.tribesera.ui.art.drawResourceGlyph
import com.robesthud.tribesera.ui.art.drawUnitGlyph
import com.robesthud.tribesera.ui.screens.buildBoard
import com.robesthud.tribesera.ui.screens.drawFieldScene
import com.robesthud.tribesera.ui.screens.drawVillageScene
import com.robesthud.tribesera.ui.screens.drawWorldMap
import com.robesthud.tribesera.ui.theme.Pal
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

/**
 * Рендер игровой графики в настоящие PNG без телефона и без эмулятора.
 *
 * Вся картинка в игре рисуется кодом, а значит её можно нарисовать в обычный
 * bitmap и посмотреть. Тест ловит то, что не видит компилятор: пустые сцены,
 * постройки, уехавшие за пределы плитки, невидимые в темноте цвета.
 * Файлы складываются в `app/build/screenshots`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ArtRenderTest {

    private val outDir = File("build/screenshots").apply { mkdirs() }

    /** Рисует блок в bitmap заданного размера и сохраняет его на диск. */
    private fun render(name: String, width: Int, height: Int, block: DrawScope.() -> Unit): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(android.graphics.Canvas(bitmap))
        CanvasDrawScope().draw(
            Density(3f),
            LayoutDirection.Ltr,
            canvas,
            Size(width.toFloat(), height.toFloat()),
        ) { block() }
        File(outDir, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        return bitmap
    }

    /** Сколько различимых цветов в картинке — грубая проверка «не пустой холст». */
    private fun distinctColours(b: Bitmap): Int {
        val seen = HashSet<Int>()
        var y = 0
        while (y < b.height) {
            var x = 0
            while (x < b.width) {
                seen += b.getPixel(x, y) and 0xF8F8F8F8.toInt()
                x += 7
            }
            y += 7
        }
        return seen.size
    }

    private fun developedWorld(): Pair<GameState, Village> {
        val g = WorldGen.create(
            GameSettings(playerName = "Вождь", race = Race.IMPERIUM, opponents = 5, seed = 20250808L),
        )
        val v = g.villagesOf(0).first()
        for (i in v.fieldLevel.indices) v.fieldLevel[i] = 3 + (i % 8)

        val plan = listOf(
            BuildingType.WAREHOUSE to 8,
            BuildingType.GRANARY to 7,
            BuildingType.BARRACKS to 6,
            BuildingType.ACADEMY to 5,
            BuildingType.SMITHY to 4,
            BuildingType.STABLE to 5,
            BuildingType.MARKET to 3,
            BuildingType.RESIDENCE to 5,
            BuildingType.CRANNY to 3,
            BuildingType.WORKSHOP to 2,
            BuildingType.WONDER to 4,
        )
        var slot = 0
        for ((type, level) in plan) {
            while (slot < Balance.SLOT_RALLY && v.slotType[slot] >= 0) slot++
            if (slot >= Balance.SLOT_RALLY) break
            v.slotType[slot] = type.ordinal
            v.slotLevel[slot] = level
            slot++
        }
        v.slotLevel[v.slotOf(BuildingType.MAIN)] = 9
        v.slotLevel[Balance.SLOT_WALL] = 8
        v.slotLevel[Balance.SLOT_RALLY] = 4
        for (u in Units.of(Race.IMPERIUM)) {
            v.troops[u.id] = if (u.kind == UnitKind.INFANTRY) 120 else 20
        }
        repeat(600) { Engine.tick(g, 0.5) }
        return g to v
    }

    @Test
    fun fieldsSceneLooksLikeALandscape() {
        val (_, v) = developedWorld()
        val w = 1080
        val h = 1500
        val bitmap = render("02-fields", w, h) {
            drawRect(Pal.bg, size = Size(w.toFloat(), h.toFloat()))
            val layout = buildBoard(5, 4, w.toFloat(), h.toFloat(), setOf(2 to 1, 2 to 2), 0.26f, 0.97f)
            drawFieldScene(layout, v, selected = 3)
        }
        assertTrue("сцена полей не должна быть одноцветной", distinctColours(bitmap) > 40)
    }

    @Test
    fun villageSceneShowsBuildings() {
        val (_, v) = developedWorld()
        val w = 1080
        val h = 1500
        val bitmap = render("03-village", w, h) {
            drawRect(Pal.bg, size = Size(w.toFloat(), h.toFloat()))
            val layout = buildBoard(5, 4, w.toFloat(), h.toFloat(), setOf(2 to 1, 2 to 2), 0.30f, 0.96f)
            drawVillageScene(layout, v, selected = 1)
        }
        assertTrue("деревня должна быть богата деталями", distinctColours(bitmap) > 60)
    }

    @Test
    fun worldMapShowsVillagesAndOases() {
        val (g, v) = developedWorld()
        val w = 1080
        val h = 1500
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        val measurer = TextMeasurer(
            defaultFontFamilyResolver = createFontFamilyResolver(ctx),
            defaultDensity = Density(3f),
            defaultLayoutDirection = LayoutDirection.Ltr,
        )
        val bitmap = render("04-map", w, h) {
            drawRect(Pal.bgDeep, size = Size(w.toFloat(), h.toFloat()))
            val tile = 150f
            val grid0 = IsoGrid(Balance.MAP_SIZE, Balance.MAP_SIZE, 0f, 0f, tile, tile * 0.56f)
            val c = grid0.center(v.x.toFloat(), v.y.toFloat())
            val grid = IsoGrid(
                Balance.MAP_SIZE, Balance.MAP_SIZE,
                w / 2f - c.x, h / 2f - c.y, tile, tile * 0.56f,
            )
            drawWorldMap(g, grid, v.x to v.y, measurer, 1.2f)
        }
        assertTrue("на карте должно быть на что смотреть", distinctColours(bitmap) > 40)
    }

    @Test
    fun everyBuildingHasItsOwnSilhouette() {
        val types = BuildingType.entries
        val cols = 4
        val rows = (types.size + cols - 1) / cols
        val cellW = 260
        val cellH = 220
        val w = cols * cellW
        val h = rows * cellH
        val bitmap = render("05-buildings", w, h) {
            drawRect(Pal.bg, size = Size(w.toFloat(), h.toFloat()))
            types.forEachIndexed { i, type ->
                val cx = (i % cols) * cellW + cellW / 2f
                val cy = (i / cols) * cellH + cellH * 0.62f
                drawBuilding(type, Offset(cx, cy), cellW * 0.82f, cellH * 0.38f, level = 8)
            }
        }
        assertTrue("витрина построек не должна быть пустой", distinctColours(bitmap) > 60)
    }

    @Test
    fun everyUnitKindHasItsOwnSilhouette() {
        val kinds = UnitKind.entries
        val cellW = 220
        val w = kinds.size * cellW
        val h = 260
        val bitmap = render("06-units", w, h) {
            drawRect(Pal.bg, size = Size(w.toFloat(), h.toFloat()))
            kinds.forEachIndexed { i, kind ->
                val cx = i * cellW + cellW / 2f
                drawUnitGlyph(kind, Offset(cx, h / 2f), 150f, Pal.player(i))
            }
        }
        assertTrue("силуэты войск должны рисоваться", distinctColours(bitmap) > 20)
    }

    @Test
    fun resourceGlyphsAreDistinct() {
        val w = 4 * 200
        val h = 200
        val bitmap = render("07-resources", w, h) {
            drawRect(Pal.bg, size = Size(w.toFloat(), h.toFloat()))
            RES.forEachIndexed { i, r: Res ->
                drawResourceGlyph(Offset(i * 200f + 100f, h / 2f), 120f, r)
            }
        }
        assertTrue("значки ресурсов должны рисоваться", distinctColours(bitmap) > 12)
    }

    @Test
    fun fieldArtChangesWithLevel() {
        val levels = listOf(1, 5, 10, 16, 20)
        val cellW = 240
        val cellH = 180
        val w = levels.size * cellW
        val h = RES.size * cellH
        val bitmap = render("08-field-levels", w, h) {
            drawRect(Pal.bg, size = Size(w.toFloat(), h.toFloat()))
            RES.forEachIndexed { row, r ->
                levels.forEachIndexed { col, level ->
                    drawResourceField(
                        center = Offset(col * cellW + cellW / 2f, row * cellH + cellH / 2f),
                        w = cellW * 0.92f,
                        h = cellH * 0.86f,
                        res = r,
                        level = level,
                        selected = false,
                        seed = row * 10 + col,
                    )
                }
            }
        }
        assertTrue("поля разных уровней должны отличаться", distinctColours(bitmap) > 60)
    }
}
