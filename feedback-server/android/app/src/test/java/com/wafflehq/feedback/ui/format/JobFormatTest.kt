package com.wafflehq.feedback.ui.format

import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiError
import com.wafflehq.feedback.testing.testJob
import com.wafflehq.feedback.ui.theme.AppRole
import java.time.ZoneOffset
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class JobFormatTest {

    @Test
    fun `every status has a label`() {
        assertEquals(R.string.job_status_queued, statusLabel("queued"))
        assertEquals(R.string.job_status_route, statusLabel("route"))
        assertEquals(R.string.job_status_agent, statusLabel("agent"))
        assertEquals(R.string.job_status_build, statusLabel("build"))
        assertEquals(R.string.job_status_done, statusLabel("done"))
        assertEquals(R.string.job_status_failed, statusLabel("failed"))
        assertEquals(R.string.job_status_cancelled, statusLabel("cancelled"))
        assertEquals(R.string.job_status_unknown, statusLabel("neu"))
    }

    @Test
    fun `status roles follow their meaning`() {
        assertEquals(AppRole.Neutral, statusRole("queued"))
        listOf("route", "agent", "build").forEach { assertEquals(AppRole.Primary, statusRole(it)) }
        assertEquals(AppRole.Success, statusRole("done"))
        assertEquals(AppRole.Error, statusRole("failed"))
        assertEquals(AppRole.Warning, statusRole("cancelled"))
        assertEquals(AppRole.Neutral, statusRole("neu"))
    }

    @Test
    fun `kind labels`() {
        assertEquals(R.string.job_kind_build, kindLabel("build"))
        assertEquals(R.string.job_kind_feedback, kindLabel("feedback"))
        assertEquals(R.string.job_kind_feedback, kindLabel("other"))
    }

    @Test
    fun `job error codes map to texts`() {
        mapOf(
            "agent_failed" to R.string.job_error_agent_failed,
            "agent_timeout" to R.string.job_error_agent_timeout,
            "build_failed" to R.string.job_error_build_failed,
            "build_timeout" to R.string.job_error_build_timeout,
            "apk_missing" to R.string.job_error_apk_missing,
            "interrupted" to R.string.job_error_interrupted,
            "cancelled" to R.string.job_error_cancelled,
            "internal_error" to R.string.job_error_internal,
            "neu" to R.string.job_error_unknown,
        ).forEach { (code, text) -> assertEquals(code, text, jobErrorLabel(code)) }
    }

    @Test
    fun `every api error has a message`() {
        val messages = ApiError.entries.map(::apiErrorMessage)

        assertEquals(ApiError.entries.size, messages.toSet().size)
        assertEquals(R.string.error_unauthorized, apiErrorMessage(ApiError.Unauthorized))
        assertEquals(R.string.error_network, apiErrorMessage(ApiError.Network))
    }

    @Test
    fun `duration needs start and end and is at least one minute`() {
        assertNull(durationMinutes(testJob(startedAt = null, finishedAt = 10.0)))
        assertNull(durationMinutes(testJob(startedAt = 10.0, finishedAt = null)))
        assertEquals(1L, durationMinutes(testJob(startedAt = 0.0, finishedAt = 5.0)))
        assertEquals(3L, durationMinutes(testJob(startedAt = 0.0, finishedAt = 180.0)))
    }

    @Test
    fun `epoch seconds are formatted in the given zone`() {
        val formatted = formatEpochSeconds(0.0, Locale.GERMANY, ZoneOffset.UTC)

        assertEquals("01.01.70, 00:00", formatted)
    }
}
