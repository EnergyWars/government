package com.wafflehq.feedback.ui.components

import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.VisualTransformation
import com.wafflehq.feedback.ui.theme.AppRadius
import com.wafflehq.feedback.ui.theme.AppRole
import com.wafflehq.feedback.ui.theme.AppTheme

enum class TextFieldVariant {
    Outlined, Filled
}

@Composable
fun AppTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    role: AppRole,
    variant: TextFieldVariant = TextFieldVariant.Outlined,
    isError: Boolean = false,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    minLines: Int = 1,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    singleLine: Boolean = false,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    supportingText: String? = null,
) {
    val t = AppTheme.tokens.textField
    val r = t.forRole(role)

    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        modifier = modifier,
        enabled = enabled,
        isError = isError,
        singleLine = singleLine,
        minLines = minLines,
        visualTransformation = visualTransformation,
        supportingText = supportingText?.let { { Text(it) } },
        keyboardOptions = keyboardOptions,
        shape = RoundedCornerShape(AppRadius.textField),
        colors = TextFieldDefaults.colors(
            focusedContainerColor   = r.background,
            unfocusedContainerColor = r.background,
            disabledContainerColor  = t.disabledBackground,
            focusedTextColor        = r.content,
            unfocusedTextColor      = r.content,
            disabledTextColor       = t.disabledContent,
            focusedLabelColor       = r.labelFocused,
            unfocusedLabelColor     = r.labelUnfocused,
            focusedIndicatorColor   = r.borderFocused,
            unfocusedIndicatorColor = r.borderUnfocused,
            errorIndicatorColor     = r.errorBorder,
            errorLabelColor         = r.errorLabel,
        ),
    )
}
