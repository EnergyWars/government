package com.wafflehq.feedback.ui.components

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.DialogProperties
import com.wafflehq.feedback.ui.theme.AppRadius
import com.wafflehq.feedback.ui.theme.AppRole
import com.wafflehq.feedback.ui.theme.AppTheme

@Composable
fun AppDialog(
    onDismissRequest: () -> Unit,
    confirmButton: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    dismissButton: (@Composable () -> Unit)? = null,
    icon: (@Composable () -> Unit)? = null,
    title: (@Composable () -> Unit)? = null,
    text: (@Composable () -> Unit)? = null,
    properties: DialogProperties = DialogProperties(),
) {
    val colors = AppTheme.colors
    AlertDialog(
        onDismissRequest = onDismissRequest,
        confirmButton = confirmButton,
        modifier = modifier,
        dismissButton = dismissButton,
        icon = icon,
        title = title,
        text = text,
        shape = RoundedCornerShape(AppRadius.dialog),
        containerColor = colors.surface,
        iconContentColor = colors.primary.accent,
        titleContentColor = colors.onSurface,
        textContentColor = colors.onSurfaceVariant,
        tonalElevation = 1.dp,
        properties = properties,
    )
}

@Composable
fun AppDialog(
    onDismissRequest: () -> Unit,
    title: String,
    confirmText: String,
    onConfirm: () -> Unit,
    modifier: Modifier = Modifier,
    text: String? = null,
    dismissText: String? = null,
    onDismiss: (() -> Unit)? = null,
    confirmRole: AppRole = AppRole.Primary,
    confirmEnabled: Boolean = true,
) {
    AppDialog(
        onDismissRequest = onDismissRequest,
        modifier = modifier,
        title = { Text(title, style = MaterialTheme.typography.titleLarge) },
        text = text?.let { { Text(it, style = MaterialTheme.typography.bodyMedium) } },
        confirmButton = {
            AppDialogConfirmButton(text = confirmText, onClick = onConfirm, role = confirmRole, enabled = confirmEnabled)
        },
        dismissButton = if (dismissText != null && onDismiss != null) {
            { AppDialogDismissButton(text = dismissText, onClick = onDismiss) }
        } else {
            null
        },
    )
}

@Composable
fun AppDialogConfirmButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    role: AppRole = AppRole.Primary,
    enabled: Boolean = true,
) {
    AppButton(text = text, role = role, variant = ButtonVariant.Tonal, onClick = onClick, modifier = modifier, enabled = enabled)
}

@Composable
fun AppDialogDismissButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    AppButton(text = text, role = AppRole.Neutral, variant = ButtonVariant.Text, onClick = onClick, modifier = modifier, enabled = enabled)
}
