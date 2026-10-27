package com.wafflehq.feedback.ui.format

import androidx.annotation.StringRes
import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiError
import com.wafflehq.feedback.data.api.Job
import com.wafflehq.feedback.ui.theme.AppRole
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlin.math.roundToLong

private const val SECONDS_PER_MINUTE = 60.0
private const val MILLIS_PER_SECOND = 1000.0

@StringRes
fun statusLabel(status: String): Int = when (status) {
    "queued" -> R.string.job_status_queued
    "route" -> R.string.job_status_route
    "agent" -> R.string.job_status_agent
    "build" -> R.string.job_status_build
    "done" -> R.string.job_status_done
    "failed" -> R.string.job_status_failed
    "cancelled" -> R.string.job_status_cancelled
    else -> R.string.job_status_unknown
}

fun statusRole(status: String): AppRole = when (status) {
    "route", "agent", "build" -> AppRole.Primary
    "done" -> AppRole.Success
    "failed" -> AppRole.Error
    "cancelled" -> AppRole.Warning
    else -> AppRole.Neutral
}

@StringRes
fun kindLabel(kind: String): Int = when (kind) {
    "build" -> R.string.job_kind_build
    else -> R.string.job_kind_feedback
}

@StringRes
fun jobErrorLabel(code: String): Int = when (code) {
    "agent_failed" -> R.string.job_error_agent_failed
    "agent_timeout" -> R.string.job_error_agent_timeout
    "build_failed" -> R.string.job_error_build_failed
    "build_timeout" -> R.string.job_error_build_timeout
    "apk_missing" -> R.string.job_error_apk_missing
    "interrupted" -> R.string.job_error_interrupted
    "cancelled" -> R.string.job_error_cancelled
    "internal_error" -> R.string.job_error_internal
    else -> R.string.job_error_unknown
}

@StringRes
fun apiErrorMessage(error: ApiError): Int = when (error) {
    ApiError.Network -> R.string.error_network
    ApiError.Unauthorized -> R.string.error_unauthorized
    ApiError.TooManyAttempts -> R.string.error_too_many_attempts
    ApiError.NotFound -> R.string.error_not_found
    ApiError.NotCancellable -> R.string.error_not_cancellable
    ApiError.InvalidRequest -> R.string.error_invalid_request
    ApiError.InvalidResponse -> R.string.error_invalid_response
    ApiError.Server -> R.string.error_server
    ApiError.IncompleteDownload -> R.string.error_incomplete_download
    ApiError.NoConnection -> R.string.error_no_connection
}

fun durationMinutes(job: Job): Long? {
    val started = job.startedAt ?: return null
    val finished = job.finishedAt ?: return null
    return ((finished - started) / SECONDS_PER_MINUTE).roundToLong().coerceAtLeast(1L)
}

fun formatEpochSeconds(
    seconds: Double,
    locale: Locale = Locale.getDefault(),
    zone: ZoneId = ZoneId.systemDefault(),
): String = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT)
    .withLocale(locale)
    .withZone(zone)
    .format(Instant.ofEpochMilli((seconds * MILLIS_PER_SECOND).roundToLong()))
