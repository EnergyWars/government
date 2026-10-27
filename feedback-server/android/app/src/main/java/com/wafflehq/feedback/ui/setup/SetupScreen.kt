package com.wafflehq.feedback.ui.setup

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.wafflehq.feedback.R
import com.wafflehq.feedback.ui.components.AppBanner
import com.wafflehq.feedback.ui.components.AppButton
import com.wafflehq.feedback.ui.components.AppCard
import com.wafflehq.feedback.ui.components.AppChip
import com.wafflehq.feedback.ui.components.AppTextField
import com.wafflehq.feedback.ui.components.ButtonVariant
import com.wafflehq.feedback.ui.components.CardVariant
import com.wafflehq.feedback.ui.components.ChipVariant
import com.wafflehq.feedback.ui.components.SettingsScaffold
import com.wafflehq.feedback.ui.theme.AppRole
import com.wafflehq.feedback.ui.theme.AppSpacing
import com.wafflehq.feedback.ui.theme.AppTheme

@Composable
fun SetupScreen(viewModel: SetupViewModel = hiltViewModel()) {
    val host by viewModel.host.collectAsStateWithLifecycle()
    val portOption by viewModel.portOption.collectAsStateWithLifecycle()
    val customPort by viewModel.customPort.collectAsStateWithLifecycle()
    val status by viewModel.status.collectAsStateWithLifecycle()
    val history by viewModel.hostHistory.collectAsStateWithLifecycle()
    val hostInputVisible by viewModel.hostInputVisible.collectAsStateWithLifecycle()
    val busy = status == SetupStatus.Checking || status == SetupStatus.Discovering

    SettingsScaffold(title = stringResource(R.string.setup_title), onBack = null, backDescription = null) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(AppSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.lg),
        ) {
            Text(
                text = stringResource(R.string.setup_intro),
                style = MaterialTheme.typography.bodyMedium,
                color = AppTheme.colors.onSurfaceVariant,
            )
            AppCard(variant = CardVariant.Outlined, modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(AppSpacing.lg),
                    verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
                ) {
                    Text(
                        text = stringResource(R.string.setup_host_title),
                        style = MaterialTheme.typography.titleMedium,
                        color = AppTheme.colors.onSurface,
                    )
                    HostChips(
                        history = history,
                        selected = host,
                        newHostSelected = hostInputVisible && history.isNotEmpty(),
                        onSelect = viewModel::onHostSelected,
                        onNewHost = viewModel::onNewHostSelected,
                    )
                    if (hostInputVisible) {
                        AppTextField(
                            value = host,
                            onValueChange = viewModel::onHostChange,
                            label = stringResource(R.string.setup_host_label),
                            role = AppRole.Primary,
                            singleLine = true,
                            enabled = !busy,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    AppButton(
                        text = stringResource(R.string.setup_discover),
                        role = AppRole.Primary,
                        variant = ButtonVariant.Outlined,
                        onClick = viewModel::discover,
                        enabled = !busy,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
            AppCard(variant = CardVariant.Outlined, modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(AppSpacing.lg),
                    verticalArrangement = Arrangement.spacedBy(AppSpacing.md),
                ) {
                    Text(
                        text = stringResource(R.string.setup_port_title),
                        style = MaterialTheme.typography.titleMedium,
                        color = AppTheme.colors.onSurface,
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm)) {
                        AppChip(
                            label = stringResource(R.string.setup_port_standard, DEFAULT_PORT),
                            role = AppRole.Primary,
                            variant = ChipVariant.Filter,
                            selected = portOption == PortOption.Standard,
                            onClick = { viewModel.onPortOptionChange(PortOption.Standard) },
                        )
                        AppChip(
                            label = stringResource(R.string.setup_port_custom),
                            role = AppRole.Primary,
                            variant = ChipVariant.Filter,
                            selected = portOption == PortOption.Custom,
                            onClick = { viewModel.onPortOptionChange(PortOption.Custom) },
                        )
                    }
                    if (portOption == PortOption.Custom) {
                        AppTextField(
                            value = customPort,
                            onValueChange = viewModel::onCustomPortChange,
                            label = stringResource(R.string.setup_port_label),
                            role = AppRole.Primary,
                            singleLine = true,
                            enabled = !busy,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
            if (busy) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                Text(
                    text = stringResource(
                        if (status == SetupStatus.Discovering) R.string.setup_discovering else R.string.setup_checking,
                    ),
                    style = MaterialTheme.typography.bodySmall,
                    color = AppTheme.colors.onSurfaceVariant,
                )
            }
            (status as? SetupStatus.Error)?.let { error ->
                AppBanner(
                    title = stringResource(R.string.setup_error_title),
                    body = stringResource(error.messageRes),
                    role = AppRole.Error,
                    icon = Icons.Outlined.ErrorOutline,
                    action = stringResource(R.string.action_dismiss) to viewModel::dismissError,
                )
            }
            AppButton(
                text = stringResource(R.string.setup_connect),
                role = AppRole.Primary,
                variant = ButtonVariant.Tonal,
                onClick = viewModel::connect,
                enabled = !busy && host.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun HostChips(
    history: List<String>,
    selected: String,
    newHostSelected: Boolean,
    onSelect: (String) -> Unit,
    onNewHost: () -> Unit,
) {
    if (history.isEmpty()) return
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        verticalArrangement = Arrangement.spacedBy(AppSpacing.sm),
    ) {
        history.forEach { entry ->
            AppChip(
                label = entry,
                role = AppRole.Primary,
                variant = ChipVariant.Filter,
                selected = !newHostSelected && entry == selected,
                onClick = { onSelect(entry) },
            )
        }
        AppChip(
            label = stringResource(R.string.setup_host_new),
            role = AppRole.Primary,
            variant = ChipVariant.Filter,
            selected = newHostSelected,
            onClick = onNewHost,
        )
    }
}
