package com.wafflehq.feedback.ui.home

import androidx.annotation.StringRes
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wafflehq.feedback.R
import com.wafflehq.feedback.data.api.ApiException
import com.wafflehq.feedback.data.api.Job
import com.wafflehq.feedback.data.api.ServerGateway
import com.wafflehq.feedback.data.api.ServerStatus
import com.wafflehq.feedback.data.connection.ConnectionStore
import com.wafflehq.feedback.data.download.ApkDownload
import com.wafflehq.feedback.data.download.ApkDownloader
import com.wafflehq.feedback.data.download.ApkOutcome
import com.wafflehq.feedback.ui.format.apiErrorMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

const val MAX_FEEDBACK_LENGTH = 20_000

data class HomeUiState(
    val status: ServerStatus? = null,
    val jobs: List<Job> = emptyList(),
    val latestApk: Long? = null,
    val loading: Boolean = true,
    @param:StringRes val loadError: Int? = null,
    val feedback: String = "",
    val resume: Boolean = true,
    val sending: Boolean = false,
    val cancelTarget: Job? = null,
    @param:StringRes val message: Int? = null,
) {
    val canSend: Boolean get() = feedback.isNotBlank() && feedback.length <= MAX_FEEDBACK_LENGTH && !sending
    val feedbackTooLong: Boolean get() = feedback.length > MAX_FEEDBACK_LENGTH
}

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val gateway: ServerGateway,
    private val store: ConnectionStore,
    private val downloader: ApkDownloader,
) : ViewModel() {

    private val _state = MutableStateFlow(HomeUiState())
    val state: StateFlow<HomeUiState> = _state.asStateFlow()

    val connectionLabel: StateFlow<String?> = store.session
        .map { it?.connection?.label }
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    val download: StateFlow<ApkDownload?> = downloader.active
    val apkOutcome: StateFlow<ApkOutcome?> = downloader.outcome
    val cachedApks: StateFlow<Set<Long>> = downloader.cachedJobIds

    suspend fun refresh() {
        try {
            val (statusValue, jobList) = coroutineScope {
                val status = async { gateway.status() }
                val jobs = async { gateway.jobs() }
                status.await() to jobs.await()
            }
            _state.update {
                it.copy(
                    status = statusValue,
                    jobs = jobList.jobs,
                    latestApk = jobList.latestApk ?: statusValue.latestApk,
                    loading = false,
                    loadError = null,
                )
            }
        } catch (error: ApiException) {
            _state.update { it.copy(loading = false, loadError = apiErrorMessage(error.error)) }
        }
    }

    fun onFeedbackChange(value: String) {
        _state.update { it.copy(feedback = value) }
    }

    fun onResumeChange(value: Boolean) {
        _state.update { it.copy(resume = value) }
    }

    fun send() {
        val current = _state.value
        if (!current.canSend) return
        _state.update { it.copy(sending = true) }
        viewModelScope.launch {
            try {
                gateway.sendFeedback(current.feedback.trim(), current.resume)
                _state.update { it.copy(sending = false, feedback = "", message = R.string.home_feedback_sent) }
                refresh()
            } catch (error: ApiException) {
                _state.update { it.copy(sending = false, message = apiErrorMessage(error.error)) }
            }
        }
    }

    fun buildOnly() {
        if (_state.value.sending) return
        _state.update { it.copy(sending = true) }
        viewModelScope.launch {
            try {
                gateway.buildApk()
                _state.update { it.copy(sending = false, message = R.string.home_build_queued) }
                refresh()
            } catch (error: ApiException) {
                _state.update { it.copy(sending = false, message = apiErrorMessage(error.error)) }
            }
        }
    }

    fun requestCancel(job: Job) {
        _state.update { it.copy(cancelTarget = job) }
    }

    fun dismissCancel() {
        _state.update { it.copy(cancelTarget = null) }
    }

    fun confirmCancel() {
        val target = _state.value.cancelTarget ?: return
        _state.update { it.copy(cancelTarget = null) }
        viewModelScope.launch {
            try {
                gateway.cancel(target.id)
                _state.update { it.copy(message = R.string.home_job_cancelled) }
                refresh()
            } catch (error: ApiException) {
                _state.update { it.copy(message = apiErrorMessage(error.error)) }
            }
        }
    }

    fun downloadApk(jobId: Long) {
        if (!downloader.request(jobId)) {
            _state.update { it.copy(message = R.string.home_download_busy) }
        }
    }

    fun consumeApkOutcome() {
        val outcome = downloader.outcome.value
        if (outcome is ApkOutcome.Failed) {
            _state.update { it.copy(message = apiErrorMessage(outcome.error)) }
        }
        downloader.consumeOutcome()
    }

    fun consumeMessage() {
        _state.update { it.copy(message = null) }
    }

    fun logout() {
        viewModelScope.launch { store.clearPassword() }
    }

    fun changeConnection() {
        viewModelScope.launch { store.clear() }
    }
}
