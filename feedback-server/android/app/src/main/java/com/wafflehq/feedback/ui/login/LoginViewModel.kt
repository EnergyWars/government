package com.wafflehq.feedback.ui.login

import androidx.annotation.StringRes
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiError
import com.wafflehq.feedback.data.api.ApiException
import com.wafflehq.feedback.data.api.ServerGateway
import com.wafflehq.feedback.data.connection.ConnectionStore
import com.wafflehq.feedback.ui.format.apiErrorMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

sealed interface LoginStatus {
    data object Idle : LoginStatus
    data object Checking : LoginStatus
    data object LoggedIn : LoginStatus
    data class Error(@param:StringRes val messageRes: Int) : LoginStatus
}

@HiltViewModel
class LoginViewModel @Inject constructor(
    private val gateway: ServerGateway,
    private val store: ConnectionStore,
) : ViewModel() {

    val connectionLabel: StateFlow<String?> = store.session
        .map { it?.connection?.label }
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    private val _password = MutableStateFlow("")
    val password: StateFlow<String> = _password.asStateFlow()

    private val _status = MutableStateFlow<LoginStatus>(LoginStatus.Idle)
    val status: StateFlow<LoginStatus> = _status.asStateFlow()

    fun onPasswordChange(value: String) {
        _password.value = value
        dismissError()
    }

    fun submit() {
        val password = _password.value
        if (password.isBlank()) {
            _status.value = LoginStatus.Error(R.string.login_error_empty)
            return
        }
        viewModelScope.launch {
            val connection = store.session.first()?.connection
            if (connection == null) {
                _status.value = LoginStatus.Error(R.string.error_no_connection)
                return@launch
            }
            _status.value = LoginStatus.Checking
            _status.value = try {
                gateway.verifyPassword(connection.host, connection.port, password)
                store.savePassword(password)
                LoginStatus.LoggedIn
            } catch (error: ApiException) {
                LoginStatus.Error(
                    if (error.error == ApiError.Unauthorized) R.string.login_error_wrong else apiErrorMessage(error.error),
                )
            }
        }
    }

    fun changeConnection() {
        viewModelScope.launch { store.clear() }
    }

    fun dismissError() {
        if (_status.value is LoginStatus.Error) _status.value = LoginStatus.Idle
    }
}
