package com.wafflehq.feedback.ui.job

import androidx.lifecycle.SavedStateHandle
import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiError
import com.wafflehq.feedback.data.api.ApiException
import com.wafflehq.feedback.data.api.JobDetail
import com.wafflehq.feedback.testing.FakeGateway
import com.wafflehq.feedback.testing.MainDispatcherRule
import com.wafflehq.feedback.testing.testJob
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class JobDetailViewModelTest {

    @get:Rule
    val main = MainDispatcherRule()

    private val gateway = FakeGateway()

    private fun viewModel(id: Long = 7) = JobDetailViewModel(SavedStateHandle(mapOf(JOB_ID_ARGUMENT to id)), gateway)

    @Test
    fun `reads the job id from the navigation arguments`() {
        assertEquals(7L, viewModel().jobId)
    }

    @Test(expected = IllegalStateException::class)
    fun `missing job id fails fast`() {
        JobDetailViewModel(SavedStateHandle(), gateway)
    }

    @Test
    fun `refresh loads job and log`() = runTest {
        gateway.jobResult = { JobDetail(testJob(id = it, status = "agent"), "läuft") }
        val viewModel = viewModel()

        viewModel.refresh()

        val state = viewModel.state.value
        assertFalse(state.loading)
        assertEquals("agent", state.job?.status)
        assertEquals("läuft", state.log)
        assertTrue(viewModel.shouldPoll)
    }

    @Test
    fun `polling stops for finished jobs and runs before the first load`() = runTest {
        val viewModel = viewModel()
        assertTrue(viewModel.shouldPoll)

        viewModel.refresh()

        assertFalse(viewModel.shouldPoll)
    }

    @Test
    fun `refresh errors are shown`() = runTest {
        gateway.jobResult = { throw ApiException(ApiError.NotFound, 404) }
        val viewModel = viewModel()

        viewModel.refresh()

        assertEquals(R.string.error_not_found, viewModel.state.value.error)
        assertFalse(viewModel.state.value.loading)
    }

    @Test
    fun `cancel is only offered for active jobs`() = runTest {
        val viewModel = viewModel()
        viewModel.requestCancel()
        assertFalse(viewModel.state.value.confirmCancel)

        viewModel.refresh()
        viewModel.requestCancel()
        assertFalse(viewModel.state.value.confirmCancel)

        gateway.jobResult = { JobDetail(testJob(id = it, status = "build")) }
        viewModel.refresh()
        viewModel.requestCancel()
        assertTrue(viewModel.state.value.confirmCancel)
        viewModel.dismissCancel()
        assertFalse(viewModel.state.value.confirmCancel)
    }

    @Test
    fun `confirmCancel cancels and refreshes`() = runTest {
        gateway.jobResult = { JobDetail(testJob(id = it, status = "agent")) }
        val viewModel = viewModel()
        viewModel.refresh()
        viewModel.requestCancel()
        gateway.jobResult = { JobDetail(testJob(id = it, status = "cancelled")) }

        viewModel.confirmCancel()

        assertEquals(listOf(7L), gateway.cancelled)
        assertEquals("cancelled", viewModel.state.value.job?.status)
        assertEquals(R.string.home_job_cancelled, viewModel.state.value.message)
        assertFalse(viewModel.state.value.confirmCancel)
        viewModel.consumeMessage()
        assertNull(viewModel.state.value.message)
    }

    @Test
    fun `cancel failure is shown`() = runTest {
        gateway.cancelResult = { throw ApiException(ApiError.NotCancellable, 409) }
        val viewModel = viewModel()

        viewModel.confirmCancel()

        assertEquals(R.string.error_not_cancellable, viewModel.state.value.message)
    }
}
