package com.wafflehq.feedback.ui.job

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CloudOff
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.Job
import com.wafflehq.feedback.ui.common.PollingEffect
import com.wafflehq.feedback.ui.components.AppBanner
import com.wafflehq.feedback.ui.components.AppButton
import com.wafflehq.feedback.ui.components.AppCard
import com.wafflehq.feedback.ui.components.AppDialog
import com.wafflehq.feedback.ui.components.AppStatusPill
import com.wafflehq.feedback.ui.components.ButtonVariant
import com.wafflehq.feedback.ui.components.CardVariant
import com.wafflehq.feedback.ui.components.SettingsScaffold
import com.wafflehq.feedback.ui.format.durationMinutes
import com.wafflehq.feedback.ui.format.formatEpochSeconds
import com.wafflehq.feedback.ui.format.jobErrorLabel
import com.wafflehq.feedback.ui.format.kindLabel
import com.wafflehq.feedback.ui.format.statusLabel
import com.wafflehq.feedback.ui.format.statusRole
import com.wafflehq.feedback.ui.theme.AppRole
import com.wafflehq.feedback.ui.theme.AppSpacing
import com.wafflehq.feedback.ui.theme.AppTextStyles
import com.wafflehq.feedback.ui.theme.AppTheme

@Composable
fun JobDetailScreen(onBack: () -> Unit, viewModel: JobDetailViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val messageText = state.message?.let { stringResource(it) }

    PollingEffect(shouldPoll = { viewModel.shouldPoll }) { viewModel.refresh() }

    LaunchedEffect(messageText) {
        if (messageText != null) {
            viewModel.consumeMessage()
            snackbar.showSnackbar(messageText)
        }
    }

    SettingsScaffold(
        title = stringResource(R.string.job_detail_title, viewModel.jobId),
        onBack = onBack,
        backDescription = stringResource(R.string.action_back),
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(AppSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
        ) {
            if (state.loading) item(key = "loading") { LinearProgressIndicator(modifier = Modifier.fillMaxWidth()) }
            state.error?.let { error ->
                item(key = "error") {
                    AppBanner(
                        title = stringResource(R.string.home_load_error_title),
                        body = stringResource(error),
                        role = AppRole.Error,
                        icon = Icons.Outlined.CloudOff,
                    )
                }
            }
            state.job?.let { job ->
                item(key = "summary") { JobSummary(job, onCancel = viewModel::requestCancel) }
                job.error?.let { code ->
                    item(key = "job_error") {
                        AppBanner(
                            title = stringResource(R.string.job_error_title),
                            body = stringResource(jobErrorLabel(code)),
                            role = AppRole.Error,
                            icon = Icons.Outlined.ErrorOutline,
                        )
                    }
                }
                job.routeReason?.let { reason ->
                    item(key = "route") {
                        AppBanner(
                            title = stringResource(R.string.job_route_title, job.model.orEmpty(), job.effort.orEmpty()),
                            body = reason,
                            role = AppRole.Primary,
                            icon = Icons.Outlined.Info,
                        )
                    }
                }
                job.summary?.takeIf { it.isNotBlank() }?.let { summary ->
                    item(key = "result") { TextSection(title = stringResource(R.string.job_summary_title), body = summary) }
                }
            }
            item(key = "log") { LogSection(state.log) }
        }
    }

    if (state.confirmCancel) {
        AppDialog(
            onDismissRequest = viewModel::dismissCancel,
            title = stringResource(R.string.cancel_dialog_title),
            text = stringResource(R.string.cancel_dialog_text, viewModel.jobId),
            confirmText = stringResource(R.string.cancel_dialog_confirm),
            onConfirm = viewModel::confirmCancel,
            dismissText = stringResource(R.string.action_back),
            onDismiss = viewModel::dismissCancel,
            confirmRole = AppRole.Error,
        )
    }
}

@Composable
private fun JobSummary(job: Job, onCancel: () -> Unit) {
    AppCard(variant = CardVariant.Outlined, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(AppSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        ) {
            AppStatusPill(text = stringResource(statusLabel(job.status)), role = statusRole(job.status))
            Text(
                text = stringResource(kindLabel(job.kind)),
                style = MaterialTheme.typography.titleMedium,
                color = AppTheme.colors.onSurface,
            )
            if (job.feedback.isNotBlank()) {
                SelectionContainer {
                    Text(text = job.feedback, style = MaterialTheme.typography.bodyMedium, color = AppTheme.colors.onSurface)
                }
            }
            Text(
                text = stringResource(R.string.job_created, formatEpochSeconds(job.createdAt)),
                style = MaterialTheme.typography.bodySmall,
                color = AppTheme.colors.onSurfaceVariant,
            )
            durationMinutes(job)?.let { minutes ->
                Text(
                    text = stringResource(R.string.job_duration, minutes),
                    style = MaterialTheme.typography.bodySmall,
                    color = AppTheme.colors.onSurfaceVariant,
                )
            }
            if (job.resume) {
                Text(
                    text = stringResource(R.string.job_resumed),
                    style = MaterialTheme.typography.bodySmall,
                    color = AppTheme.colors.onSurfaceVariant,
                )
            }
            if (job.isActive) {
                AppButton(
                    text = stringResource(R.string.action_cancel_job),
                    role = AppRole.Error,
                    variant = ButtonVariant.Tonal,
                    onClick = onCancel,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun TextSection(title: String, body: String) {
    AppCard(variant = CardVariant.Outlined, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(AppSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        ) {
            Text(text = title, style = MaterialTheme.typography.titleMedium, color = AppTheme.colors.onSurface)
            SelectionContainer {
                Text(text = body, style = MaterialTheme.typography.bodyMedium, color = AppTheme.colors.onSurface)
            }
        }
    }
}

@Composable
private fun LogSection(log: String) {
    AppCard(variant = CardVariant.Outlined, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(AppSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        ) {
            Text(
                text = stringResource(R.string.job_log_title),
                style = MaterialTheme.typography.titleMedium,
                color = AppTheme.colors.onSurface,
            )
            if (log.isBlank()) {
                Text(
                    text = stringResource(R.string.job_log_empty),
                    style = MaterialTheme.typography.bodySmall,
                    color = AppTheme.colors.onSurfaceVariant,
                )
            } else {
                SelectionContainer(modifier = Modifier.horizontalScroll(rememberScrollState())) {
                    Text(text = log, style = AppTextStyles.code, color = AppTheme.colors.onSurfaceVariant)
                }
            }
        }
    }
}
