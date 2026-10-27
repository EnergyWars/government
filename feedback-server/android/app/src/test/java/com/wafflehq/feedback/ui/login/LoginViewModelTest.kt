package com.wafflehq.feedback.ui.login

import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiError
import com.wafflehq.feedback.data.api.ApiException
import com.wafflehq.feedback.data.connection.Connection
import com.wafflehq.feedback.data.connection.Session
import com.wafflehq.feedback.testing.FakeConnectionStore
import com.wafflehq.feedback.testing.FakeGateway
import com.wafflehq.feedback.testing.MainDispatcherRule
import kotlinx.coroutines.CompletableDeferred
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class LoginViewModelTest {

    @get:Rule
    val main = MainDispatcherRule()

    private val gateway = FakeGateway()
    private val store = FakeConnectionStore(Session(Connection("192.168.1.5", 8787), null))

    private fun viewModel() = LoginViewModel(gateway, store)

    @Test
    fun `shows the connection label`() {
        assertEquals("192.168.1.5:8787", viewModel().connectionLabel.value)
    }

    @Test
    fun `correct password is verified and stored`() {
        val viewModel = viewModel()
        viewModel.onPasswordChange("123")

        viewModel.submit()

        assertEquals(LoginStatus.LoggedIn, viewModel.status.value)
        assertEquals(listOf("123"), gateway.verifyCalls)
        assertEquals("123", store.sessionState.value?.password)
    }

    @Test
    fun `checking state while verifying`() {
        gateway.gate = CompletableDeferred()
        val viewModel = viewModel()
        viewModel.onPasswordChange("123")

        viewModel.submit()
        assertEquals(LoginStatus.Checking, viewModel.status.value)

        gateway.gate!!.complete(Unit)
        assertEquals(LoginStatus.LoggedIn, viewModel.status.value)
    }

    @Test
    fun `blank password is rejected locally`() {
        val viewModel = viewModel()
        viewModel.onPasswordChange("  ")

        viewModel.submit()

        assertEquals(LoginStatus.Error(R.string.login_error_empty), viewModel.status.value)
        assertTrue(gateway.verifyCalls.isEmpty())
    }

    @Test
    fun `wrong password shows a dedicated message and stores nothing`() {
        gateway.verifyResult = { throw ApiException(ApiError.Unauthorized, 401) }
        val viewModel = viewModel()
        viewModel.onPasswordChange("falsch")

        viewModel.submit()

        assertEquals(LoginStatus.Error(R.string.login_error_wrong), viewModel.status.value)
        assertNull(store.sessionState.value?.password)
    }

    @Test
    fun `other errors use the generic message`() {
        gateway.verifyResult = { throw ApiException(ApiError.TooManyAttempts, 429) }
        val viewModel = viewModel()
        viewModel.onPasswordChange("x")

        viewModel.submit()

        assertEquals(LoginStatus.Error(R.string.error_too_many_attempts), viewModel.status.value)
    }

    @Test
    fun `typing clears an error`() {
        val viewModel = viewModel()
        viewModel.submit()

        viewModel.onPasswordChange("1")

        assertEquals(LoginStatus.Idle, viewModel.status.value)
        assertEquals("1", viewModel.password.value)
    }

    @Test
    fun `missing connection is reported`() {
        store.sessionState.value = null
        val viewModel = viewModel()
        viewModel.onPasswordChange("123")

        viewModel.submit()

        assertEquals(LoginStatus.Error(R.string.error_no_connection), viewModel.status.value)
    }

    @Test
    fun `changeConnection clears the store`() {
        viewModel().changeConnection()

        assertNull(store.sessionState.value)
    }
}
