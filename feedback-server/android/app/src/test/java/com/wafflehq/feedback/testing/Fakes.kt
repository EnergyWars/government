package com.wafflehq.feedback.testing

import com.wafflehq.feedback.data.api.ApiError
import com.wafflehq.feedback.data.api.ApiException
import com.wafflehq.feedback.data.api.ApkSource
import com.wafflehq.feedback.data.api.CancelResponse
import com.wafflehq.feedback.data.api.DownloadProgress
import com.wafflehq.feedback.data.api.HealthResponse
import com.wafflehq.feedback.data.api.Job
import com.wafflehq.feedback.data.api.JobDetail
import com.wafflehq.feedback.data.api.JobList
import com.wafflehq.feedback.data.api.ServerGateway
import com.wafflehq.feedback.data.api.ServerStatus
import com.wafflehq.feedback.data.connection.Connection
import com.wafflehq.feedback.data.connection.ConnectionStore
import com.wafflehq.feedback.data.connection.Session
import com.wafflehq.feedback.data.connection.applyHostHistory
import com.wafflehq.feedback.data.crypto.SecretCipher
import com.wafflehq.feedback.data.discovery.HostDiscovery
import java.io.File
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.rules.TestWatcher
import org.junit.runner.Description

@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(val dispatcher: TestDispatcher = UnconfinedTestDispatcher()) : TestWatcher() {
    override fun starting(description: Description) {
        Dispatchers.setMain(dispatcher)
    }

    override fun finished(description: Description) {
        Dispatchers.resetMain()
    }
}

fun testJob(
    id: Long = 1,
    status: String = "done",
    kind: String = "feedback",
    feedback: String = "Mehr Gold",
    hasApk: Boolean = false,
    model: String? = null,
    effort: String? = null,
    error: String? = null,
    startedAt: Double? = null,
    finishedAt: Double? = null,
) = Job(
    id = id,
    kind = kind,
    status = status,
    feedback = feedback,
    createdAt = 1_700_000_000.0,
    startedAt = startedAt,
    finishedAt = finishedAt,
    hasApk = hasApk,
    model = model,
    effort = effort,
    error = error,
)

class FakeConnectionStore(
    session: Session? = null,
    history: List<String> = emptyList(),
) : ConnectionStore {
    val sessionState = MutableStateFlow(session)
    val historyState = MutableStateFlow(history)
    override val session = sessionState
    override val hostHistory = historyState

    override suspend fun saveConnection(host: String, port: Int) {
        sessionState.value = Session(Connection(host, port), null)
        historyState.value = applyHostHistory(historyState.value, host)
    }

    override suspend fun savePassword(password: String) {
        sessionState.value = sessionState.value?.copy(password = password)
    }

    override suspend fun clearPassword() {
        sessionState.value = sessionState.value?.copy(password = null)
    }

    override suspend fun clear() {
        sessionState.value = null
    }

    companion object {
        fun ready(password: String = "123") = FakeConnectionStore(Session(Connection("192.168.1.5", 8787), password))
    }
}

class FakeGateway : ServerGateway {
    var healthResult: () -> HealthResponse = { HealthResponse(ok = true) }
    var verifyResult: (String) -> ServerStatus = { ServerStatus() }
    var statusResult: () -> ServerStatus = { ServerStatus() }
    var jobsResult: () -> JobList = { JobList() }
    var jobResult: (Long) -> JobDetail = { JobDetail(testJob(id = it)) }
    var sendResult: (String, Boolean) -> Job = { text, _ -> testJob(id = 10, status = "queued", feedback = text) }
    var buildResult: () -> Job = { testJob(id = 11, status = "queued", kind = "build", feedback = "") }
    var cancelResult: (Long) -> CancelResponse = { CancelResponse(it) }
    var gate: CompletableDeferred<Unit>? = null

    val healthCalls = mutableListOf<Pair<String, Int>>()
    val verifyCalls = mutableListOf<String>()
    val sent = mutableListOf<Pair<String, Boolean>>()
    val cancelled = mutableListOf<Long>()
    var buildCalls = 0
    var statusCalls = 0
    var jobsCalls = 0

    override suspend fun health(host: String, port: Int): HealthResponse {
        healthCalls += host to port
        gate?.await()
        return healthResult()
    }

    override suspend fun verifyPassword(host: String, port: Int, password: String): ServerStatus {
        verifyCalls += password
        gate?.await()
        return verifyResult(password)
    }

    override suspend fun status(): ServerStatus {
        statusCalls++
        return statusResult()
    }

    override suspend fun jobs(): JobList {
        jobsCalls++
        return jobsResult()
    }

    override suspend fun job(id: Long): JobDetail = jobResult(id)

    override suspend fun sendFeedback(feedback: String, resume: Boolean): Job {
        sent += feedback to resume
        gate?.await()
        return sendResult(feedback, resume)
    }

    override suspend fun buildApk(): Job {
        buildCalls++
        gate?.await()
        return buildResult()
    }

    override suspend fun cancel(id: Long): CancelResponse {
        cancelled += id
        return cancelResult(id)
    }
}

class FakeApkSource : ApkSource {
    var gate: CompletableDeferred<Unit>? = null
    var failure: ApiError? = null
    var content: ByteArray = byteArrayOf(1, 2, 3)
    val requested = mutableListOf<Long>()

    override suspend fun downloadApk(jobId: Long, destination: File, onProgress: (DownloadProgress) -> Unit): File {
        requested += jobId
        onProgress(DownloadProgress(0, content.size.toLong(), 0.0, null))
        gate?.await()
        failure?.let { throw ApiException(it) }
        destination.parentFile?.mkdirs()
        destination.writeBytes(content)
        onProgress(DownloadProgress(content.size.toLong(), content.size.toLong(), 0.0, 0))
        return destination
    }
}

class FakeDiscovery(var result: String? = null) : HostDiscovery {
    val ports = mutableListOf<Int>()

    override suspend fun discoverHost(port: Int): String? {
        ports += port
        return result
    }
}

class ReversingCipher : SecretCipher {
    var failDecrypt = false

    override fun encrypt(plainText: String): String = plainText.reversed()

    override fun decrypt(encoded: String): String {
        check(!failDecrypt)
        return encoded.reversed()
    }
}
