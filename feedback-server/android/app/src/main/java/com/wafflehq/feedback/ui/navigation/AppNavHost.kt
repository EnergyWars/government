package com.wafflehq.feedback.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.wafflehq.feedback.ui.home.HomeScreen
import com.wafflehq.feedback.ui.job.JobDetailScreen
import com.wafflehq.feedback.ui.login.LoginScreen
import com.wafflehq.feedback.ui.setup.SetupScreen
import kotlinx.serialization.Serializable

@Serializable
data object HomeRoute

@Serializable
data class JobDetailRoute(val jobId: Long)

@Composable
fun AppNavHost(gateViewModel: ConnectionGateViewModel = hiltViewModel()) {
    val gate by gateViewModel.gateState.collectAsStateWithLifecycle()
    when (gate) {
        GateState.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        GateState.NoConnection -> SetupScreen()
        GateState.NeedsLogin -> LoginScreen()
        GateState.Ready -> ReadyNavHost()
    }
}

@Composable
private fun ReadyNavHost() {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = HomeRoute) {
        composable<HomeRoute> {
            HomeScreen(onOpenJob = { navController.navigate(JobDetailRoute(it)) })
        }
        composable<JobDetailRoute> {
            JobDetailScreen(onBack = { navController.popBackStack() })
        }
    }
}
