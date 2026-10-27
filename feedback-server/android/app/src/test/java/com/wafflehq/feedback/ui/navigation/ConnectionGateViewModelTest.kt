package com.wafflehq.feedback.ui.navigation

import com.wafflehq.feedback.data.connection.Connection
import com.wafflehq.feedback.data.connection.Session
import com.wafflehq.feedback.testing.FakeConnectionStore
import com.wafflehq.feedback.testing.MainDispatcherRule
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class ConnectionGateViewModelTest {

    @get:Rule
    val main = MainDispatcherRule()

    private val connection = Connection("host", 8787)

    @Test
    fun `gate state follows the session`() {
        assertEquals(GateState.NoConnection, gateStateFor(null))
        assertEquals(GateState.NeedsLogin, gateStateFor(Session(connection, null)))
        assertEquals(GateState.NeedsLogin, gateStateFor(Session(connection, "")))
        assertEquals(GateState.Ready, gateStateFor(Session(connection, "123")))
    }

    @Test
    fun `view model reacts to session changes`() {
        val store = FakeConnectionStore()
        val viewModel = ConnectionGateViewModel(store)

        assertEquals(GateState.NoConnection, viewModel.gateState.value)
        store.sessionState.value = Session(connection, null)
        assertEquals(GateState.NeedsLogin, viewModel.gateState.value)
        store.sessionState.value = Session(connection, "123")
        assertEquals(GateState.Ready, viewModel.gateState.value)
    }
}
