package com.wafflehq.feedback.ui.components

import androidx.compose.ui.unit.Dp
import com.wafflehq.feedback.ui.theme.AppSpacing

object TextAreaDefaults {
    val labelTopPadding: Dp = AppSpacing.sm
    const val IME_SETTLE_DELAY_MILLIS: Long = 100L
}

object TextAreaAutoScroll {

    fun scrollDelta(
        cursorTop: Float,
        cursorBottom: Float,
        viewportTop: Float,
        viewportBottom: Float
    ): Float {
        if (viewportBottom <= viewportTop) return 0f
        if (cursorBottom - cursorTop >= viewportBottom - viewportTop) return cursorTop - viewportTop
        return when {
            cursorTop < viewportTop -> cursorTop - viewportTop
            cursorBottom > viewportBottom -> cursorBottom - viewportBottom
            else -> 0f
        }
    }

    fun clampToField(value: Float, fieldHeight: Float): Float =
        if (fieldHeight > 0f) value.coerceIn(0f, fieldHeight) else value
}

class TextAreaScrollTracker {

    var isFocused: Boolean = false
        private set

    var imeBottom: Int = 0
        private set

    private var lastText: String? = null

    fun onFocusChanged(focused: Boolean): Boolean {
        isFocused = focused
        if (!focused) lastText = null
        return focused
    }

    fun onImeBottomChanged(bottom: Int): Boolean {
        val grew = bottom > imeBottom
        imeBottom = bottom
        return grew && isFocused
    }

    fun onTextLayout(text: String): Boolean {
        val previous = lastText
        lastText = text
        return isFocused && previous != null && previous != text
    }
}
