package com.wafflehq.feedback.ui.job

import androidx.annotation.StringRes
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiException
import com.wafflehq.feedback.data.api.Job
import com.wafflehq.feedback.data.api.ServerGateway
import com.wafflehq.feedback.ui.format.apiErrorMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

const val JOB_ID_ARGUMENT = "jobId"

data class JobDetailUiState(
    val job: Job? = null,
    val log: String = "",
    val loading: Boolean = true,
    @param:StringRes val error: Int? = null,
    val confirmCancel: Boolean = false,
    @param:StringRes val message: Int? = null,
)

@HiltViewModel
class JobDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val gateway: ServerGateway,
) : ViewModel() {

    val jobId: Long = checkNotNull(savedStateHandle.get<Long>(JOB_ID_ARGUMENT))

    private val _state = MutableStateFlow(JobDetailUiState())
    val state: StateFlow<JobDetailUiState> = _state.asStateFlow()

    val shouldPoll: Boolean get() = _state.value.job?.isActive ?: true

    suspend fun refresh() {
        try {
            val detail = gateway.job(jobId)
            _state.update { it.copy(job = detail.job, log = detail.log, loading = false, error = null) }
        } catch (error: ApiException) {
            _state.update { it.copy(loading = false, error = apiErrorMessage(error.error)) }
        }
    }

    fun requestCancel() {
        if (_state.value.job?.isActive == true) _state.update { it.copy(confirmCancel = true) }
    }

    fun dismissCancel() {
        _state.update { it.copy(confirmCancel = false) }
    }

    fun confirmCancel() {
        _state.update { it.copy(confirmCancel = false) }
        viewModelScope.launch {
            try {
                gateway.cancel(jobId)
                _state.update { it.copy(message = R.string.home_job_cancelled) }
                refresh()
            } catch (error: ApiException) {
                _state.update { it.copy(message = apiErrorMessage(error.error)) }
            }
        }
    }

    fun consumeMessage() {
        _state.update { it.copy(message = null) }
    }
}
