package com.wafflehq.feedback.ui.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.wafflehq.feedback.ui.theme.AppSpacing
import com.wafflehq.feedback.ui.theme.AppTheme
import kotlinx.coroutines.delay

const val POLL_INTERVAL_MILLIS = 3_000L
private const val EMPTY_ICON_ALPHA = 0.38f
private val EMPTY_ICON_SIZE = 64.dp

@Composable
fun PollingEffect(intervalMillis: Long = POLL_INTERVAL_MILLIS, shouldPoll: () -> Boolean = { true }, block: suspend () -> Unit) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val currentBlock by rememberUpdatedState(block)
    val currentShouldPoll by rememberUpdatedState(shouldPoll)
    LaunchedEffect(lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            currentBlock()
            while (true) {
                delay(intervalMillis)
                if (currentShouldPoll()) currentBlock()
            }
        }
    }
}

@Composable
fun EmptyState(icon: ImageVector, text: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth().padding(AppSpacing.xl),
        verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = AppTheme.colors.onSurfaceVariant.copy(alpha = EMPTY_ICON_ALPHA),
            modifier = Modifier.size(EMPTY_ICON_SIZE),
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = AppTheme.colors.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}
