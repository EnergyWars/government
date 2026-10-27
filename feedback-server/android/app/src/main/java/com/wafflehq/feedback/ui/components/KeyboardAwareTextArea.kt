package com.wafflehq.feedback.ui.components

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.LocalTextSelectionColors
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.TextFieldColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.takeOrElse
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollDispatcher
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.findRootCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.wafflehq.feedback.R
import com.wafflehq.feedback.ui.theme.AppRadius
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun KeyboardAwareTextArea(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    textStyle: TextStyle = LocalTextStyle.current,
    label: @Composable (() -> Unit)? = null,
    placeholder: @Composable (() -> Unit)? = null,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null,
    prefix: @Composable (() -> Unit)? = null,
    suffix: @Composable (() -> Unit)? = null,
    supportingText: @Composable (() -> Unit)? = null,
    isError: Boolean = false,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    minLines: Int = 1,
    maxLines: Int = Int.MAX_VALUE,
    interactionSource: MutableInteractionSource? = null,
    shape: Shape = RoundedCornerShape(AppRadius.textField),
    colors: TextFieldColors = OutlinedTextFieldDefaults.colors(),
) {
    var textFieldValueState by remember { mutableStateOf(TextFieldValue(text = value)) }
    val textFieldValue = textFieldValueState.copy(text = value)
    SideEffect {
        if (textFieldValue.selection != textFieldValueState.selection ||
            textFieldValue.composition != textFieldValueState.composition
        ) {
            textFieldValueState = textFieldValue
        }
    }
    var lastTextValue by remember(value) { mutableStateOf(value) }

    KeyboardAwareTextArea(
        value = textFieldValue,
        onValueChange = { newValue ->
            textFieldValueState = newValue
            val textChanged = lastTextValue != newValue.text
            lastTextValue = newValue.text
            if (textChanged) onValueChange(newValue.text)
        },
        modifier = modifier,
        enabled = enabled,
        readOnly = readOnly,
        textStyle = textStyle,
        label = label,
        placeholder = placeholder,
        leadingIcon = leadingIcon,
        trailingIcon = trailingIcon,
        prefix = prefix,
        suffix = suffix,
        supportingText = supportingText,
        isError = isError,
        visualTransformation = visualTransformation,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        minLines = minLines,
        maxLines = maxLines,
        interactionSource = interactionSource,
        shape = shape,
        colors = colors,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun KeyboardAwareTextArea(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    textStyle: TextStyle = LocalTextStyle.current,
    label: @Composable (() -> Unit)? = null,
    placeholder: @Composable (() -> Unit)? = null,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null,
    prefix: @Composable (() -> Unit)? = null,
    suffix: @Composable (() -> Unit)? = null,
    supportingText: @Composable (() -> Unit)? = null,
    isError: Boolean = false,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    minLines: Int = 1,
    maxLines: Int = Int.MAX_VALUE,
    interactionSource: MutableInteractionSource? = null,
    shape: Shape = RoundedCornerShape(AppRadius.textField),
    colors: TextFieldColors = OutlinedTextFieldDefaults.colors(),
) {
    val interaction = interactionSource ?: remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    val textColor = textStyle.color.takeOrElse {
        when {
            !enabled -> colors.disabledTextColor
            isError -> colors.errorTextColor
            focused -> colors.focusedTextColor
            else -> colors.unfocusedTextColor
        }
    }
    val mergedTextStyle = textStyle.merge(TextStyle(color = textColor))
    val cursorColor = if (isError) colors.errorCursorColor else colors.cursorColor
    val errorDescription = stringResource(R.string.textarea_error)

    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    val tracker = remember { TextAreaScrollTracker() }
    val session = remember { TextAreaScrollSession() }
    val dispatcher = remember { NestedScrollDispatcher() }
    val safeDrawing = WindowInsets.safeDrawing
    val currentValue by rememberUpdatedState(value)
    val currentTransformation by rememberUpdatedState(visualTransformation)

    fun ensureCursorVisible() {
        scope.launch {
            val delta = session.scrollDelta(currentValue, currentTransformation, safeDrawing, density)
            if (delta != 0f) {
                dispatcher.dispatchPostScroll(
                    consumed = Offset.Zero,
                    available = Offset(0f, -delta),
                    source = NestedScrollSource.SideEffect
                )
            }
        }
    }

    val imeBottom = WindowInsets.ime.getBottom(density)
    LaunchedEffect(imeBottom) {
        if (tracker.onImeBottomChanged(imeBottom)) {
            delay(TextAreaDefaults.IME_SETTLE_DELAY_MILLIS)
            ensureCursorVisible()
        }
    }

    CompositionLocalProvider(LocalTextSelectionColors provides colors.textSelectionColors) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = modifier
                .nestedScroll(PassThroughNestedScroll, dispatcher)
                .semantics(mergeDescendants = true) {
                    if (isError) error(errorDescription)
                }
                .padding(top = if (label != null) TextAreaDefaults.labelTopPadding else 0.dp)
                .defaultMinSize(
                    minWidth = OutlinedTextFieldDefaults.MinWidth,
                    minHeight = OutlinedTextFieldDefaults.MinHeight
                )
                .onFocusChanged { if (tracker.onFocusChanged(it.isFocused)) ensureCursorVisible() },
            enabled = enabled,
            readOnly = readOnly,
            textStyle = mergedTextStyle,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            singleLine = false,
            maxLines = maxLines,
            minLines = minLines,
            visualTransformation = visualTransformation,
            onTextLayout = { result ->
                session.layoutResult = result
                if (tracker.onTextLayout(value.text)) ensureCursorVisible()
            },
            interactionSource = interaction,
            cursorBrush = SolidColor(cursorColor),
            decorationBox = { innerTextField ->
                OutlinedTextFieldDefaults.DecorationBox(
                    value = value.text,
                    innerTextField = {
                        Box(
                            modifier = Modifier.onGloballyPositioned { session.coordinates = it },
                            propagateMinConstraints = true
                        ) {
                            innerTextField()
                        }
                    },
                    enabled = enabled,
                    singleLine = false,
                    visualTransformation = visualTransformation,
                    interactionSource = interaction,
                    isError = isError,
                    label = label,
                    placeholder = placeholder,
                    leadingIcon = leadingIcon,
                    trailingIcon = trailingIcon,
                    prefix = prefix,
                    suffix = suffix,
                    supportingText = supportingText,
                    colors = colors,
                    container = {
                        OutlinedTextFieldDefaults.Container(
                            enabled = enabled,
                            isError = isError,
                            interactionSource = interaction,
                            colors = colors,
                            shape = shape
                        )
                    }
                )
            }
        )
    }
}

private val PassThroughNestedScroll = object : NestedScrollConnection {}

internal class TextAreaScrollSession {
    var layoutResult: TextLayoutResult? = null
    var coordinates: LayoutCoordinates? = null

    fun scrollDelta(
        value: TextFieldValue,
        transformation: VisualTransformation,
        insets: WindowInsets,
        density: Density
    ): Float {
        val layout = layoutResult ?: return 0f
        val field = coordinates?.takeIf { it.isAttached } ?: return 0f
        val transformedOffset = transformation
            .filter(value.annotatedString)
            .offsetMapping
            .originalToTransformed(value.selection.end)
        val offset = transformedOffset.coerceIn(0, layout.layoutInput.text.length)
        val cursor = layout.getCursorRect(offset)
        val fieldHeight = field.size.height.toFloat()
        val top = TextAreaAutoScroll.clampToField(cursor.top, fieldHeight)
        val bottom = TextAreaAutoScroll.clampToField(cursor.bottom, fieldHeight)
        val root = field.findRootCoordinates()
        return TextAreaAutoScroll.scrollDelta(
            cursorTop = field.localToRoot(Offset(0f, top)).y,
            cursorBottom = field.localToRoot(Offset(0f, bottom)).y,
            viewportTop = insets.getTop(density).toFloat(),
            viewportBottom = root.size.height.toFloat() - insets.getBottom(density)
        )
    }
}
