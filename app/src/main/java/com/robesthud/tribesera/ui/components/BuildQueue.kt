package com.robesthud.tribesera.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.robesthud.tribesera.engine.BuildingType
import com.robesthud.tribesera.engine.Engine
import com.robesthud.tribesera.engine.RES
import com.robesthud.tribesera.engine.Units
import com.robesthud.tribesera.engine.Village
import com.robesthud.tribesera.engine.formatDuration
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.theme.Pal

/** Полоска активных строек: что строится, сколько осталось, отмена. */
@Composable
fun BuildQueueStrip(vm: GameViewModel, v: Village, modifier: Modifier = Modifier) {
    if (v.buildQueue.isEmpty()) return
    LazyRow(
        modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(v.buildQueue.size) { index ->
            val job = v.buildQueue.getOrNull(index) ?: return@items
            val title = if (job.field) {
                "${RES[job.type].title} · ${job.targetLevel} ур."
            } else {
                "${BuildingType.entries[job.type].title} · ${job.targetLevel} ур."
            }
            val progress = 1f - (job.remaining / job.totalTime).toFloat().coerceIn(0f, 1f)
            Row(
                Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(Pal.surfaceHi)
                    .padding(start = 10.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.width(130.dp)) {
                    Text(title, style = MaterialTheme.typography.labelMedium, color = Pal.text, maxLines = 1)
                    Spacer(Modifier.height(4.dp))
                    ProgressBar(progress, Modifier.fillMaxWidth(), tone = Pal.gold)
                    Spacer(Modifier.height(3.dp))
                    Text(
                        formatDuration(job.remaining),
                        style = MaterialTheme.typography.labelSmall,
                        color = Pal.textFaint,
                    )
                }
                Box(
                    Modifier
                        .size(28.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .clickable { Engine.cancelJob(v, job); vm.bump() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Close, null, tint = Pal.textFaint, modifier = Modifier.size(15.dp))
                }
            }
        }
    }
}

/** Полоска найма — то же самое, но для казармы, конюшни и мастерской. */
@Composable
fun TrainQueueStrip(vm: GameViewModel, v: Village, modifier: Modifier = Modifier) {
    if (v.trainQueue.isEmpty()) return
    LazyRow(
        modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(v.trainQueue.size) { index ->
            val job = v.trainQueue.getOrNull(index) ?: return@items
            val def = Units[job.unitId]
            val perUnit = job.perUnit
            val progress = (job.progress / perUnit).toFloat().coerceIn(0f, 1f)
            Row(
                Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(Pal.surfaceLo)
                    .padding(start = 10.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.width(126.dp)) {
                    Text("${def.title} ×${job.left}", style = MaterialTheme.typography.labelMedium, color = Pal.text, maxLines = 1)
                    Spacer(Modifier.height(4.dp))
                    ProgressBar(progress, Modifier.fillMaxWidth(), tone = Pal.jade)
                }
                Box(
                    Modifier
                        .size(28.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .clickable { Engine.cancelTraining(v, job); vm.bump() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Close, null, tint = Pal.textFaint, modifier = Modifier.size(15.dp))
                }
            }
        }
    }
}
