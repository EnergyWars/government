package com.wafflehq.feedback.ui.home

import android.content.ActivityNotFoundException
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.outlined.Cancel
import androidx.compose.material.icons.outlined.CloudOff
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.SwapHoriz
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.DownloadProgress
import com.wafflehq.feedback.data.api.Job
import com.wafflehq.feedback.data.api.ServerStatus
import com.wafflehq.feedback.data.api.fraction
import com.wafflehq.feedback.data.download.ApkDownload
import com.wafflehq.feedback.data.download.ApkOutcome
import com.wafflehq.feedback.data.download.installApkIntent
import com.wafflehq.feedback.ui.common.EmptyState
import com.wafflehq.feedback.ui.common.PollingEffect
import com.wafflehq.feedback.ui.components.AppBanner
import com.wafflehq.feedback.ui.components.AppButton
import com.wafflehq.feedback.ui.components.AppCard
import com.wafflehq.feedback.ui.components.AppDialog
import com.wafflehq.feedback.ui.components.AppIconButton
import com.wafflehq.feedback.ui.components.AppStatusPill
import com.wafflehq.feedback.ui.components.ButtonVariant
import com.wafflehq.feedback.ui.components.CardVariant
import com.wafflehq.feedback.ui.components.IconButtonVariant
import com.wafflehq.feedback.ui.components.KeyboardAwareTextArea
import com.wafflehq.feedback.ui.components.SettingsScaffold
import com.wafflehq.feedback.ui.components.SettingsSwitchRow
import com.wafflehq.feedback.ui.format.formatEpochSeconds
import com.wafflehq.feedback.ui.format.kindLabel
import com.wafflehq.feedback.ui.format.statusLabel
import com.wafflehq.feedback.ui.format.statusRole
import com.wafflehq.feedback.ui.theme.AppRole
import com.wafflehq.feedback.ui.theme.AppSpacing
import com.wafflehq.feedback.ui.theme.AppTheme

private val FEEDBACK_MIN_HEIGHT = 140.dp
private const val FEEDBACK_PREVIEW_LINES = 3

@Composable
fun HomeScreen(onOpenJob: (Long) -> Unit, viewModel: HomeViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val connection by viewModel.connectionLabel.collectAsStateWithLifecycle()
    val download by viewModel.download.collectAsStateWithLifecycle()
    val outcome by viewModel.apkOutcome.collectAsStateWithLifecycle()
    val cached by viewModel.cachedApks.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val snackbar = remember { SnackbarHostState() }
    val messageText = state.message?.let { stringResource(it) }
    val installFailed = stringResource(R.string.home_install_failed)

    PollingEffect { viewModel.refresh() }

    LaunchedEffect(messageText) {
        if (messageText != null) {
            viewModel.consumeMessage()
            snackbar.showSnackbar(messageText)
        }
    }

    LaunchedEffect(outcome) {
        val ready = outcome as? ApkOutcome.Ready
        viewModel.consumeApkOutcome()
        if (ready != null) {
            try {
                context.startActivity(installApkIntent(context, ready.file))
            } catch (error: ActivityNotFoundException) {
                snackbar.showSnackbar(installFailed)
            }
        }
    }

    SettingsScaffold(
        title = stringResource(R.string.app_name),
        onBack = null,
        backDescription = null,
        snackbarHost = { SnackbarHost(snackbar) },
        actions = {
            AppIconButton(
                icon = Icons.Outlined.SwapHoriz,
                contentDescription = stringResource(R.string.action_change_connection),
                role = AppRole.Neutral,
                variant = IconButtonVariant.Standard,
                onClick = viewModel::changeConnection,
            )
            AppIconButton(
                icon = Icons.AutoMirrored.Outlined.Logout,
                contentDescription = stringResource(R.string.action_logout),
                role = AppRole.Neutral,
                variant = IconButtonVariant.Standard,
                onClick = viewModel::logout,
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).imePadding(),
            contentPadding = PaddingValues(AppSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
        ) {
            item(key = "status") {
                StatusCard(status = state.status, connection = connection.orEmpty(), loading = state.loading)
            }
            state.loadError?.let { error ->
                item(key = "error") {
                    AppBanner(
                        title = stringResource(R.string.home_load_error_title),
                        body = stringResource(error),
                        role = AppRole.Error,
                        icon = Icons.Outlined.CloudOff,
                    )
                }
            }
            item(key = "apk") {
                ApkCard(
                    latestApk = state.latestApk,
                    cached = state.latestApk != null && state.latestApk in cached,
                    download = download,
                    onDownload = viewModel::downloadApk,
                )
            }
            item(key = "feedback") {
                FeedbackCard(
                    state = state,
                    onFeedbackChange = viewModel::onFeedbackChange,
                    onResumeChange = viewModel::onResumeChange,
                    onSend = viewModel::send,
                    onBuildOnly = viewModel::buildOnly,
                )
            }
            item(key = "jobs_title") {
                Text(
                    text = stringResource(R.string.home_jobs_title),
                    style = MaterialTheme.typography.titleMedium,
                    color = AppTheme.colors.onSurface,
                    modifier = Modifier.padding(top = AppSpacing.sm),
                )
            }
            if (state.jobs.isEmpty() && !state.loading) {
                item(key = "jobs_empty") {
                    EmptyState(icon = Icons.Outlined.Inbox, text = stringResource(R.string.home_jobs_empty))
                }
            }
            items(state.jobs, key = { it.id }) { job ->
                JobCard(
                    job = job,
                    cached = job.id in cached,
                    onOpen = { onOpenJob(job.id) },
                    onCancel = { viewModel.requestCancel(job) },
                    onDownload = { viewModel.downloadApk(job.id) },
                    downloadEnabled = download == null,
                )
            }
        }
    }

    state.cancelTarget?.let { job ->
        AppDialog(
            onDismissRequest = viewModel::dismissCancel,
            title = stringResource(R.string.cancel_dialog_title),
            text = stringResource(R.string.cancel_dialog_text, job.id),
            confirmText = stringResource(R.string.cancel_dialog_confirm),
            onConfirm = viewModel::confirmCancel,
            dismissText = stringResource(R.string.action_back),
            onDismiss = viewModel::dismissCancel,
            confirmRole = AppRole.Error,
        )
    }
}

@Composable
private fun StatusCard(status: ServerStatus?, connection: String, loading: Boolean) {
    AppCard(role = AppRole.Primary, variant = CardVariant.Filled, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(AppSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
            ) {
                Text(
                    text = stringResource(R.string.home_status_title),
                    style = MaterialTheme.typography.titleMedium,
                    color = AppTheme.colors.primary.onContainer,
                    modifier = Modifier.weight(1f),
                )
                when {
                    status == null && loading -> CircularProgressIndicator(modifier = Modifier.padding(AppSpacing.xs))
                    status != null -> AppStatusPill(
                        text = stringResource(if (status.isBusy) R.string.home_state_busy else R.string.home_state_idle),
                        role = if (status.isBusy) AppRole.Warning else AppRole.Success,
                    )
                }
            }
            Text(
                text = stringResource(R.string.home_connection, connection),
                style = MaterialTheme.typography.bodySmall,
                color = AppTheme.colors.primary.onContainer,
            )
            if (status != null) {
                status.currentJob?.let { job ->
                    Text(
                        text = stringResource(R.string.home_current_job, job.id, stringResource(statusLabel(job.status))),
                        style = MaterialTheme.typography.bodyMedium,
                        color = AppTheme.colors.primary.onContainer,
                    )
                }
                Text(
                    text = stringResource(R.string.home_queued, status.queued),
                    style = MaterialTheme.typography.bodySmall,
                    color = AppTheme.colors.primary.onContainer,
                )
                Text(
                    text = stringResource(R.string.home_router, status.router.model, status.router.effort),
                    style = MaterialTheme.typography.bodySmall,
                    color = AppTheme.colors.primary.onContainer,
                )
            }
        }
    }
}

@Composable
private fun ApkCard(latestApk: Long?, cached: Boolean, download: ApkDownload?, onDownload: (Long) -> Unit) {
    AppCard(variant = CardVariant.Outlined, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(AppSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
        ) {
            Text(
                text = stringResource(R.string.home_apk_title),
                style = MaterialTheme.typography.titleMedium,
                color = AppTheme.colors.onSurface,
            )
            Text(
                text = if (latestApk == null) {
                    stringResource(R.string.home_apk_none)
                } else {
                    stringResource(R.string.home_apk_latest, latestApk)
                },
                style = MaterialTheme.typography.bodySmall,
                color = AppTheme.colors.onSurfaceVariant,
            )
            download?.let { DownloadProgressView(it.progress) }
            if (latestApk != null) {
                AppButton(
                    text = stringResource(if (cached) R.string.home_apk_install else R.string.home_apk_download),
                    role = AppRole.Primary,
                    variant = ButtonVariant.Tonal,
                    onClick = { onDownload(latestApk) },
                    enabled = download == null,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun DownloadProgressView(progress: DownloadProgress?) {
    val fraction = progress?.fraction()
    if (fraction == null) {
        LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
    } else {
        LinearProgressIndicator(progress = { fraction }, modifier = Modifier.fillMaxWidth())
    }
    if (progress != null) {
        Text(
            text = stringResource(
                R.string.home_download_progress,
                progress.bytesDownloaded / BYTES_PER_MEGABYTE,
                (progress.totalBytes ?: 0L) / BYTES_PER_MEGABYTE,
            ),
            style = MaterialTheme.typography.bodySmall,
            color = AppTheme.colors.onSurfaceVariant,
        )
    }
}

private const val BYTES_PER_MEGABYTE = 1_048_576L

@Composable
private fun FeedbackCard(
    state: HomeUiState,
    onFeedbackChange: (String) -> Unit,
    onResumeChange: (Boolean) -> Unit,
    onSend: () -> Unit,
    onBuildOnly: () -> Unit,
) {
    AppCard(variant = CardVariant.Outlined, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(AppSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
        ) {
            Text(
                text = stringResource(R.string.home_feedback_title),
                style = MaterialTheme.typography.titleMedium,
                color = AppTheme.colors.onSurface,
            )
            KeyboardAwareTextArea(
                value = state.feedback,
                onValueChange = onFeedbackChange,
                enabled = !state.sending,
                isError = state.feedbackTooLong,
                label = { Text(stringResource(R.string.home_feedback_label)) },
                supportingText = {
                    Text(stringResource(R.string.home_feedback_counter, state.feedback.length, MAX_FEEDBACK_LENGTH))
                },
                modifier = Modifier.fillMaxWidth().heightIn(min = FEEDBACK_MIN_HEIGHT),
            )
            SettingsSwitchRow(
                title = stringResource(R.string.home_resume_title),
                subtitle = stringResource(R.string.home_resume_subtitle),
                checked = state.resume,
                onCheckedChange = onResumeChange,
                enabled = !state.sending,
            )
            AppButton(
                text = stringResource(R.string.home_send),
                role = AppRole.Primary,
                variant = ButtonVariant.Tonal,
                onClick = onSend,
                enabled = state.canSend,
                modifier = Modifier.fillMaxWidth(),
            )
            AppButton(
                text = stringResource(R.string.home_build_only),
                role = AppRole.Primary,
                variant = ButtonVariant.Outlined,
                onClick = onBuildOnly,
                enabled = !state.sending,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun JobCard(
    job: Job,
    cached: Boolean,
    onOpen: () -> Unit,
    onCancel: () -> Unit,
    onDownload: () -> Unit,
    downloadEnabled: Boolean,
) {
    AppCard(variant = CardVariant.Outlined, modifier = Modifier.fillMaxWidth().clickable(onClick = onOpen)) {
        Column(
            modifier = Modifier.padding(AppSpacing.md),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
            ) {
                Text(
                    text = stringResource(R.string.job_title, job.id, stringResource(kindLabel(job.kind))),
                    style = MaterialTheme.typography.titleSmall,
                    color = AppTheme.colors.onSurface,
                    modifier = Modifier.weight(1f),
                )
                AppStatusPill(text = stringResource(statusLabel(job.status)), role = statusRole(job.status))
                if (job.isActive) {
                    AppIconButton(
                        icon = Icons.Outlined.Cancel,
                        contentDescription = stringResource(R.string.action_cancel_job),
                        role = AppRole.Neutral,
                        variant = IconButtonVariant.Standard,
                        onClick = onCancel,
                    )
                }
            }
            if (job.feedback.isNotBlank()) {
                Text(
                    text = job.feedback,
                    style = MaterialTheme.typography.bodyMedium,
                    color = AppTheme.colors.onSurface,
                    maxLines = FEEDBACK_PREVIEW_LINES,
                )
            }
            Text(
                text = jobMeta(job),
                style = MaterialTheme.typography.bodySmall,
                color = AppTheme.colors.onSurfaceVariant,
            )
            if (job.hasApk) {
                AppButton(
                    text = stringResource(if (cached) R.string.home_apk_install else R.string.home_apk_download),
                    role = AppRole.Primary,
                    variant = ButtonVariant.Text,
                    onClick = onDownload,
                    enabled = downloadEnabled,
                )
            }
        }
    }
}

@Composable
private fun jobMeta(job: Job): String {
    val created = formatEpochSeconds(job.createdAt)
    val model = job.model
    return if (model == null) {
        created
    } else {
        stringResource(R.string.job_meta_with_model, created, model, job.effort.orEmpty())
    }
}
