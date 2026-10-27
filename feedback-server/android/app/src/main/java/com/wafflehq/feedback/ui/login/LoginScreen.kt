package com.wafflehq.feedback.ui.login

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.wafflehq.feedback.R
import com.wafflehq.feedback.ui.components.AppBanner
import com.wafflehq.feedback.ui.components.AppButton
import com.wafflehq.feedback.ui.components.AppTextField
import com.wafflehq.feedback.ui.components.ButtonVariant
import com.wafflehq.feedback.ui.components.SettingsScaffold
import com.wafflehq.feedback.ui.theme.AppRole
import com.wafflehq.feedback.ui.theme.AppSpacing
import com.wafflehq.feedback.ui.theme.AppTheme

@Composable
fun LoginScreen(viewModel: LoginViewModel = hiltViewModel()) {
    val password by viewModel.password.collectAsStateWithLifecycle()
    val status by viewModel.status.collectAsStateWithLifecycle()
    val connection by viewModel.connectionLabel.collectAsStateWithLifecycle()
    val checking = status == LoginStatus.Checking

    SettingsScaffold(title = stringResource(R.string.login_title), onBack = null, backDescription = null) { padding ->
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
                text = stringResource(R.string.login_intro, connection.orEmpty()),
                style = MaterialTheme.typography.bodyMedium,
                color = AppTheme.colors.onSurfaceVariant,
            )
            AppTextField(
                value = password,
                onValueChange = viewModel::onPasswordChange,
                label = stringResource(R.string.login_password_label),
                role = AppRole.Primary,
                singleLine = true,
                enabled = !checking,
                isError = status is LoginStatus.Error,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                modifier = Modifier.fillMaxWidth(),
            )
            if (checking) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            (status as? LoginStatus.Error)?.let { error ->
                AppBanner(
                    title = stringResource(R.string.login_error_title),
                    body = stringResource(error.messageRes),
                    role = AppRole.Error,
                    icon = Icons.Outlined.ErrorOutline,
                )
            }
            AppButton(
                text = stringResource(R.string.login_submit),
                role = AppRole.Primary,
                variant = ButtonVariant.Tonal,
                onClick = viewModel::submit,
                enabled = !checking && password.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            )
            AppButton(
                text = stringResource(R.string.action_change_connection),
                role = AppRole.Neutral,
                variant = ButtonVariant.Text,
                onClick = viewModel::changeConnection,
                enabled = !checking,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
