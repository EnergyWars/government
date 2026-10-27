package com.wafflehq.feedback.ui.home

import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiError
import com.wafflehq.feedback.data.api.ApiException
import com.wafflehq.feedback.data.api.JobList
import com.wafflehq.feedback.data.api.ServerStatus
import com.wafflehq.feedback.data.download.ApkCache
import com.wafflehq.feedback.data.download.ApkDownloader
import com.wafflehq.feedback.data.download.ApkOutcome
import com.wafflehq.feedback.testing.FakeApkSource
import com.wafflehq.feedback.testing.FakeConnectionStore
import com.wafflehq.feedback.testing.FakeGateway
import com.wafflehq.feedback.testing.MainDispatcherRule
import com.wafflehq.feedback.testing.testJob
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class HomeViewModelTest {

    @get:Rule
    val main = MainDispatcherRule()

    @get:Rule
    val temp = TemporaryFolder()

    private val gateway = FakeGateway()
    private val store = FakeConnectionStore.ready()
    private val source = FakeApkSource()

    private fun TestScope.viewModel() = HomeViewModel(gateway, store, ApkDownloader(source, ApkCache(temp.root), backgroundScope))

    @Test
    fun `refresh loads status and jobs`() = runTest {
        gateway.statusResult = { ServerStatus(state = "busy", queued = 2, latestApk = 4) }
        gateway.jobsResult = { JobList(listOf(testJob(id = 4, hasApk = true)), latestApk = 4) }
        val viewModel = viewModel()

        viewModel.refresh()

        val state = viewModel.state.value
        assertFalse(state.loading)
        assertTrue(state.status!!.isBusy)
        assertEquals(listOf(4L), state.jobs.map { it.id })
        assertEquals(4L, state.latestApk)
        assertNull(state.loadError)
        assertEquals("192.168.1.5:8787", viewModel.connectionLabel.value)
    }

    @Test
    fun `latest apk falls back to the status value`() = runTest {
        gateway.statusResult = { ServerStatus(latestApk = 9) }
        val viewModel = viewModel()

        viewModel.refresh()

        assertEquals(9L, viewModel.state.value.latestApk)
    }

    @Test
    fun `refresh errors are shown and cleared by the next success`() = runTest {
        gateway.jobsResult = { throw ApiException(ApiError.Network) }
        val viewModel = viewModel()

        viewModel.refresh()
        assertEquals(R.string.error_network, viewModel.state.value.loadError)
        assertFalse(viewModel.state.value.loading)

        gateway.jobsResult = { JobList() }
        viewModel.refresh()
        assertNull(viewModel.state.value.loadError)
    }

    @Test
    fun `send posts trimmed feedback, clears the text and refreshes`() = runTest {
        val viewModel = viewModel()
        viewModel.onFeedbackChange("  Mehr Gold  ")
        viewModel.onResumeChange(false)

        viewModel.send()

        assertEquals(listOf("Mehr Gold" to false), gateway.sent)
        assertEquals("", viewModel.state.value.feedback)
        assertFalse(viewModel.state.value.sending)
        assertEquals(R.string.home_feedback_sent, viewModel.state.value.message)
        assertEquals(1, gateway.jobsCalls)
    }

    @Test
    fun `send is blocked while sending`() = runTest {
        gateway.gate = CompletableDeferred()
        val viewModel = viewModel()
        viewModel.onFeedbackChange("Text")

        viewModel.send()
        assertTrue(viewModel.state.value.sending)
        assertFalse(viewModel.state.value.canSend)
        viewModel.send()
        viewModel.buildOnly()
        gateway.gate!!.complete(Unit)

        assertEquals(1, gateway.sent.size)
        assertEquals(0, gateway.buildCalls)
    }

    @Test
    fun `blank or too long feedback cannot be sent`() = runTest {
        val viewModel = viewModel()

        viewModel.onFeedbackChange("   ")
        viewModel.send()
        viewModel.onFeedbackChange("x".repeat(MAX_FEEDBACK_LENGTH + 1))
        assertTrue(viewModel.state.value.feedbackTooLong)
        viewModel.send()

        assertTrue(gateway.sent.isEmpty())
    }

    @Test
    fun `send failure keeps the text and shows the error`() = runTest {
        gateway.sendResult = { _, _ -> throw ApiException(ApiError.InvalidRequest, 400) }
        val viewModel = viewModel()
        viewModel.onFeedbackChange("Text")

        viewModel.send()

        assertEquals("Text", viewModel.state.value.feedback)
        assertEquals(R.string.error_invalid_request, viewModel.state.value.message)
        assertFalse(viewModel.state.value.sending)
    }

    @Test
    fun `buildOnly queues a build`() = runTest {
        val viewModel = viewModel()

        viewModel.buildOnly()

        assertEquals(1, gateway.buildCalls)
        assertEquals(R.string.home_build_queued, viewModel.state.value.message)
    }

    @Test
    fun `buildOnly failure is shown`() = runTest {
        gateway.buildResult = { throw ApiException(ApiError.Server, 500) }
        val viewModel = viewModel()

        viewModel.buildOnly()

        assertEquals(R.string.error_server, viewModel.state.value.message)
        assertFalse(viewModel.state.value.sending)
    }

    @Test
    fun `cancel asks first and then cancels the job`() = runTest {
        val viewModel = viewModel()
        val target = testJob(id = 3, status = "agent")

        viewModel.requestCancel(target)
        assertEquals(target, viewModel.state.value.cancelTarget)
        viewModel.confirmCancel()

        assertNull(viewModel.state.value.cancelTarget)
        assertEquals(listOf(3L), gateway.cancelled)
        assertEquals(R.string.home_job_cancelled, viewModel.state.value.message)
    }

    @Test
    fun `dismissing the cancel dialog does nothing`() = runTest {
        val viewModel = viewModel()
        viewModel.requestCancel(testJob(id = 3, status = "agent"))

        viewModel.dismissCancel()
        viewModel.confirmCancel()

        assertTrue(gateway.cancelled.isEmpty())
    }

    @Test
    fun `cancel failure is shown`() = runTest {
        gateway.cancelResult = { throw ApiException(ApiError.NotCancellable, 409) }
        val viewModel = viewModel()
        viewModel.requestCancel(testJob(id = 3, status = "done"))

        viewModel.confirmCancel()

        assertEquals(R.string.error_not_cancellable, viewModel.state.value.message)
    }

    @Test
    fun `downloadApk downloads and exposes the ready outcome`() = runTest {
        val viewModel = viewModel()

        viewModel.downloadApk(4)
        advanceUntilIdle()

        assertTrue(viewModel.apkOutcome.value is ApkOutcome.Ready)
        assertEquals(setOf(4L), viewModel.cachedApks.value)
        viewModel.consumeApkOutcome()
        assertNull(viewModel.apkOutcome.value)
        assertNull(viewModel.state.value.message)
    }

    @Test
    fun `a second download while one runs shows a hint`() = runTest {
        source.gate = CompletableDeferred()
        val viewModel = viewModel()

        viewModel.downloadApk(4)
        viewModel.downloadApk(5)

        assertEquals(R.string.home_download_busy, viewModel.state.value.message)
        assertEquals(4L, viewModel.download.value?.jobId)
        source.gate!!.complete(Unit)
        advanceUntilIdle()
    }

    @Test
    fun `failed download outcome becomes a message`() = runTest {
        source.failure = ApiError.IncompleteDownload
        val viewModel = viewModel()

        viewModel.downloadApk(4)
        advanceUntilIdle()
        viewModel.consumeApkOutcome()

        assertEquals(R.string.error_incomplete_download, viewModel.state.value.message)
        assertNull(viewModel.apkOutcome.value)
        viewModel.consumeMessage()
        assertNull(viewModel.state.value.message)
    }

    @Test
    fun `logout clears only the password and changeConnection everything`() = runTest {
        val viewModel = viewModel()

        viewModel.logout()
        assertNull(store.sessionState.value?.password)
        assertEquals("192.168.1.5", store.sessionState.value?.connection?.host)

        viewModel.changeConnection()
        assertNull(store.sessionState.value)
    }
}
