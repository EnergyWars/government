package com.wafflehq.feedback.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.wafflehq.feedback.ui.theme.AppRole
import com.wafflehq.feedback.ui.theme.AppSpacing
import com.wafflehq.feedback.ui.theme.AppTheme

private const val OUTLINE_ALPHA = 0.25f
private val TOP_BAR_HEIGHT = 56.dp

@Composable
fun SettingsScaffold(
    title: String,
    onBack: (() -> Unit)?,
    backDescription: String?,
    modifier: Modifier = Modifier,
    actions: @Composable RowScope.() -> Unit = {},
    snackbarHost: @Composable () -> Unit = {},
    content: @Composable (PaddingValues) -> Unit,
) {
    Scaffold(
        modifier = modifier,
        containerColor = AppTheme.colors.background,
        snackbarHost = snackbarHost,
        topBar = {
            Column(Modifier.fillMaxWidth().background(AppTheme.colors.surface).statusBarsPadding()) {
                SettingsTopBar(title = title, onBack = onBack, backDescription = backDescription, actions = actions)
            }
        },
        content = content,
    )
}

@Composable
fun SettingsTopBar(
    title: String,
    onBack: (() -> Unit)?,
    backDescription: String?,
    modifier: Modifier = Modifier,
    actions: @Composable RowScope.() -> Unit = {},
) {
    val colors = AppTheme.colors
    Column(modifier = modifier.fillMaxWidth().background(colors.surface)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(TOP_BAR_HEIGHT)
                .padding(horizontal = if (onBack != null) AppSpacing.sm else AppSpacing.lg),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm),
        ) {
            if (onBack != null) {
                AppIconButton(
                    icon = Icons.Outlined.ChevronLeft,
                    contentDescription = backDescription.orEmpty(),
                    role = AppRole.Neutral,
                    variant = IconButtonVariant.Standard,
                    onClick = onBack,
                )
            }
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                color = colors.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            actions()
        }
        HorizontalDivider(color = colors.outline.copy(alpha = OUTLINE_ALPHA))
    }
}

@Composable
fun SettingsSwitchRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = AppTheme.colors
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(AppSpacing.md),
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
            Text(text = title, style = MaterialTheme.typography.titleSmall, color = colors.onSurface)
            Text(text = subtitle, style = MaterialTheme.typography.bodySmall, color = colors.onSurfaceVariant)
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange, enabled = enabled)
    }
}
