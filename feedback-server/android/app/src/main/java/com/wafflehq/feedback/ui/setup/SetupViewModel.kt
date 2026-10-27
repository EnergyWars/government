package com.wafflehq.feedback.ui.setup

import androidx.annotation.StringRes
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiException
import com.wafflehq.feedback.data.api.ServerGateway
import com.wafflehq.feedback.data.connection.ConnectionStore
import com.wafflehq.feedback.data.discovery.HostDiscovery
import com.wafflehq.feedback.ui.format.apiErrorMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

sealed interface SetupStatus {
    data object Idle : SetupStatus
    data object Checking : SetupStatus
    data object Discovering : SetupStatus
    data object Connected : SetupStatus
    data class Error(@param:StringRes val messageRes: Int) : SetupStatus
}

@HiltViewModel
class SetupViewModel @Inject constructor(
    private val gateway: ServerGateway,
    private val store: ConnectionStore,
    private val discovery: HostDiscovery,
) : ViewModel() {

    private val _host = MutableStateFlow("")
    val host: StateFlow<String> = _host.asStateFlow()

    private val _portOption = MutableStateFlow(PortOption.Standard)
    val portOption: StateFlow<PortOption> = _portOption.asStateFlow()

    private val _customPort = MutableStateFlow("")
    val customPort: StateFlow<String> = _customPort.asStateFlow()

    private val _newHost = MutableStateFlow(false)

    private val _status = MutableStateFlow<SetupStatus>(SetupStatus.Idle)
    val status: StateFlow<SetupStatus> = _status.asStateFlow()

    val hostHistory: StateFlow<List<String>> = store.hostHistory
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val hostInputVisible: StateFlow<Boolean> = combine(hostHistory, _newHost) { history, new ->
        new || history.isEmpty()
    }.stateIn(viewModelScope, SharingStarted.Eagerly, true)

    init {
        viewModelScope.launch {
            val remembered = store.hostHistory.first()
            if (remembered.isNotEmpty() && _host.value.isEmpty() && !_newHost.value) {
                _host.value = remembered.first()
            }
        }
    }

    fun onHostChange(value: String) {
        _host.value = value
    }

    fun onHostSelected(value: String) {
        _newHost.value = false
        _host.value = value
    }

    fun onNewHostSelected() {
        _newHost.value = true
        _host.value = ""
    }

    fun onPortOptionChange(option: PortOption) {
        _portOption.value = option
    }

    fun onCustomPortChange(value: String) {
        _customPort.value = sanitizePortInput(value)
    }

    fun connect() {
        val host = _host.value.trim()
        val port = resolvePort(_portOption.value, _customPort.value)
        when {
            host.isEmpty() -> _status.value = SetupStatus.Error(R.string.setup_error_host_missing)
            port == null -> _status.value = SetupStatus.Error(R.string.setup_error_port_invalid)
            else -> viewModelScope.launch {
                _status.value = SetupStatus.Checking
                _status.value = try {
                    if (gateway.health(host, port).ok) {
                        store.saveConnection(host, port)
                        SetupStatus.Connected
                    } else {
                        SetupStatus.Error(R.string.setup_error_not_feedback_server)
                    }
                } catch (error: ApiException) {
                    SetupStatus.Error(apiErrorMessage(error.error))
                }
            }
        }
    }

    fun discover() {
        val port = resolvePort(_portOption.value, _customPort.value)
        if (port == null) {
            _status.value = SetupStatus.Error(R.string.setup_error_port_invalid)
            return
        }
        viewModelScope.launch {
            _status.value = SetupStatus.Discovering
            val found = discovery.discoverHost(port)
            if (found != null) {
                _newHost.value = true
                _host.value = found
                _status.value = SetupStatus.Idle
            } else {
                _status.value = SetupStatus.Error(R.string.setup_error_not_found)
            }
        }
    }

    fun dismissError() {
        if (_status.value is SetupStatus.Error) _status.value = SetupStatus.Idle
    }
}
