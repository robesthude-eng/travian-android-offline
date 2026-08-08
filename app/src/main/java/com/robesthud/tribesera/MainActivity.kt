package com.robesthud.tribesera

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.robesthud.tribesera.ui.GameViewModel
import com.robesthud.tribesera.ui.Screen
import com.robesthud.tribesera.ui.screens.GameScreen
import com.robesthud.tribesera.ui.screens.MenuScreen
import com.robesthud.tribesera.ui.screens.ResultScreen
import com.robesthud.tribesera.ui.theme.Pal
import com.robesthud.tribesera.ui.theme.TribesEraTheme

class MainActivity : ComponentActivity() {

    private var vm: GameViewModel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent {
            TribesEraTheme {
                val model: GameViewModel = viewModel()
                vm = model
                Root(model)
            }
        }
    }

    /** Свернули приложение — партию на диск, чтобы ничего не потерялось. */
    override fun onPause() {
        super.onPause()
        vm?.saveNow()
    }
}

@Composable
private fun Root(vm: GameViewModel) {
    Box(Modifier.fillMaxSize().background(Pal.bg)) {
        when (vm.screen) {
            Screen.MENU -> MenuScreen(vm)
            Screen.GAME -> GameScreen(vm)
            Screen.RESULT -> ResultScreen(vm)
        }
    }
}
