package com.wafflehq.feedback.ui.setup

import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiError
import com.wafflehq.feedback.data.api.ApiException
import com.wafflehq.feedback.data.api.HealthResponse
import com.wafflehq.feedback.data.connection.Connection
import com.wafflehq.feedback.testing.FakeConnectionStore
import com.wafflehq.feedback.testing.FakeDiscovery
import com.wafflehq.feedback.testing.FakeGateway
import com.wafflehq.feedback.testing.MainDispatcherRule
import kotlinx.coroutines.CompletableDeferred
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class SetupViewModelTest {

    @get:Rule
    val main = MainDispatcherRule()

    private val gateway = FakeGateway()
    private val discovery = FakeDiscovery()

    private fun viewModel(store: FakeConnectionStore = FakeConnectionStore()) = SetupViewModel(gateway, store, discovery)

    @Test
    fun `without history the host input is shown and empty`() {
        val viewModel = viewModel()

        assertTrue(viewModel.hostInputVisible.value)
        assertEquals("", viewModel.host.value)
    }

    @Test
    fun `with history the latest host is preselected`() {
        val viewModel = viewModel(FakeConnectionStore(history = listOf("10.0.0.2", "10.0.0.3")))

        assertEquals("10.0.0.2", viewModel.host.value)
        assertFalse(viewModel.hostInputVisible.value)
        assertEquals(listOf("10.0.0.2", "10.0.0.3"), viewModel.hostHistory.value)
    }

    @Test
    fun `selecting a new host shows the empty input and selecting history hides it`() {
        val viewModel = viewModel(FakeConnectionStore(history = listOf("10.0.0.2")))

        viewModel.onNewHostSelected()
        assertTrue(viewModel.hostInputVisible.value)
        assertEquals("", viewModel.host.value)

        viewModel.onHostSelected("10.0.0.2")
        assertFalse(viewModel.hostInputVisible.value)
        assertEquals("10.0.0.2", viewModel.host.value)
    }

    @Test
    fun `connect saves the connection after a successful health check`() {
        val store = FakeConnectionStore()
        val viewModel = viewModel(store)
        viewModel.onHostChange(" 192.168.1.5 ")

        viewModel.connect()

        assertEquals(SetupStatus.Connected, viewModel.status.value)
        assertEquals(listOf("192.168.1.5" to DEFAULT_PORT), gateway.healthCalls)
        assertEquals(Connection("192.168.1.5", DEFAULT_PORT), store.sessionState.value?.connection)
    }

    @Test
    fun `connect uses the custom port`() {
        val viewModel = viewModel()
        viewModel.onHostChange("host")
        viewModel.onPortOptionChange(PortOption.Custom)
        viewModel.onCustomPortChange("90a01")

        viewModel.connect()

        assertEquals("9001", viewModel.customPort.value)
        assertEquals(listOf("host" to 9001), gateway.healthCalls)
    }

    @Test
    fun `connect shows checking while the request runs`() {
        gateway.gate = CompletableDeferred()
        val viewModel = viewModel()
        viewModel.onHostChange("host")

        viewModel.connect()
        assertEquals(SetupStatus.Checking, viewModel.status.value)

        gateway.gate!!.complete(Unit)
        assertEquals(SetupStatus.Connected, viewModel.status.value)
    }

    @Test
    fun `connect validates host and port`() {
        val viewModel = viewModel()

        viewModel.connect()
        assertEquals(SetupStatus.Error(R.string.setup_error_host_missing), viewModel.status.value)

        viewModel.onHostChange("host")
        viewModel.onPortOptionChange(PortOption.Custom)
        viewModel.connect()
        assertEquals(SetupStatus.Error(R.string.setup_error_port_invalid), viewModel.status.value)
        assertTrue(gateway.healthCalls.isEmpty())
    }

    @Test
    fun `connect reports a server that is not a feedback server`() {
        gateway.healthResult = { HealthResponse(ok = false) }
        val store = FakeConnectionStore()
        val viewModel = viewModel(store)
        viewModel.onHostChange("host")

        viewModel.connect()

        assertEquals(SetupStatus.Error(R.string.setup_error_not_feedback_server), viewModel.status.value)
        assertEquals(null, store.sessionState.value)
    }

    @Test
    fun `connect reports network errors`() {
        gateway.healthResult = { throw ApiException(ApiError.Network) }
        val viewModel = viewModel()
        viewModel.onHostChange("host")

        viewModel.connect()

        assertEquals(SetupStatus.Error(R.string.error_network), viewModel.status.value)
        viewModel.dismissError()
        assertEquals(SetupStatus.Idle, viewModel.status.value)
    }

    @Test
    fun `dismissError keeps non error states`() {
        val viewModel = viewModel()
        viewModel.onHostChange("host")
        viewModel.connect()

        viewModel.dismissError()

        assertEquals(SetupStatus.Connected, viewModel.status.value)
    }

    @Test
    fun `discover fills the found host`() {
        discovery.result = "192.168.178.55"
        val viewModel = viewModel(FakeConnectionStore(history = listOf("10.0.0.2")))

        viewModel.discover()

        assertEquals("192.168.178.55", viewModel.host.value)
        assertTrue(viewModel.hostInputVisible.value)
        assertEquals(SetupStatus.Idle, viewModel.status.value)
        assertEquals(listOf(DEFAULT_PORT), discovery.ports)
    }

    @Test
    fun `discover reports when nothing was found`() {
        val viewModel = viewModel()

        viewModel.discover()

        assertEquals(SetupStatus.Error(R.string.setup_error_not_found), viewModel.status.value)
    }

    @Test
    fun `discover needs a valid port`() {
        val viewModel = viewModel()
        viewModel.onPortOptionChange(PortOption.Custom)

        viewModel.discover()

        assertEquals(SetupStatus.Error(R.string.setup_error_port_invalid), viewModel.status.value)
        assertTrue(discovery.ports.isEmpty())
    }
}
