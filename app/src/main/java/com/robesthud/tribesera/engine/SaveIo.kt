package com.robesthud.tribesera.engine

import android.content.Context
import kotlinx.serialization.json.Json
import java.io.File

/** Сохранение партии в файл. Всё локально — игра работает без сети. */
object SaveIo {

    private const val FILE = "session.json"

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private fun file(ctx: Context) = File(ctx.filesDir, FILE)

    fun save(ctx: Context, g: GameState) {
        runCatching { file(ctx).writeText(json.encodeToString(GameState.serializer(), g)) }
    }

    fun load(ctx: Context): GameState? = runCatching {
        val f = file(ctx)
        if (!f.exists()) return null
        json.decodeFromString(GameState.serializer(), f.readText())
    }.getOrNull()

    fun clear(ctx: Context) {
        runCatching { file(ctx).delete() }
    }

    fun hasSave(ctx: Context): Boolean = file(ctx).exists()
}
