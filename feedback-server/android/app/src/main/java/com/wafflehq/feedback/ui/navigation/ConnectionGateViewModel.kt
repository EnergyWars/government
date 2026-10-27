package com.wafflehq.feedback.ui.navigation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wafflehq.feedback.data.connection.ConnectionStore
import com.wafflehq.feedback.data.connection.Session
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

sealed interface GateState {
    data object Loading : GateState
    data object NoConnection : GateState
    data object NeedsLogin : GateState
    data object Ready : GateState
}

fun gateStateFor(session: Session?): GateState = when {
    session == null -> GateState.NoConnection
    session.password.isNullOrEmpty() -> GateState.NeedsLogin
    else -> GateState.Ready
}

@HiltViewModel
class ConnectionGateViewModel @Inject constructor(store: ConnectionStore) : ViewModel() {
    val gateState: StateFlow<GateState> = store.session
        .map(::gateStateFor)
        .stateIn(viewModelScope, SharingStarted.Eagerly, GateState.Loading)
}
