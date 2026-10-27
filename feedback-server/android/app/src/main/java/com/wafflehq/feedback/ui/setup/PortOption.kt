package com.wafflehq.feedback.ui.setup

const val DEFAULT_PORT = 8787
private const val MIN_PORT = 1
private const val MAX_PORT = 65535
private const val MAX_PORT_DIGITS = 5

enum class PortOption(val port: Int?) {
    Standard(DEFAULT_PORT),
    Custom(null),
}

fun resolvePort(option: PortOption, customPort: String): Int? =
    option.port ?: customPort.trim().toIntOrNull()?.takeIf { it in MIN_PORT..MAX_PORT }

fun sanitizePortInput(value: String): String = value.filter(Char::isDigit).take(MAX_PORT_DIGITS)
