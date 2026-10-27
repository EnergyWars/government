package com.wafflehq.feedback.di

import com.wafflehq.feedback.data.api.ApkSource
import com.wafflehq.feedback.data.api.FeedbackApi
import com.wafflehq.feedback.data.api.ServerGateway
import com.wafflehq.feedback.data.api.StatusProbe
import com.wafflehq.feedback.data.connection.ConnectionRepository
import com.wafflehq.feedback.data.connection.ConnectionStore
import com.wafflehq.feedback.data.crypto.KeystoreCipher
import com.wafflehq.feedback.data.crypto.SecretCipher
import com.wafflehq.feedback.data.discovery.HostDiscovery
import com.wafflehq.feedback.data.discovery.NetworkDiscovery
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
abstract class BindsModule {

    @Binds
    abstract fun bindConnectionStore(impl: ConnectionRepository): ConnectionStore

    @Binds
    abstract fun bindSecretCipher(impl: KeystoreCipher): SecretCipher

    @Binds
    abstract fun bindServerGateway(impl: FeedbackApi): ServerGateway

    @Binds
    abstract fun bindApkSource(impl: FeedbackApi): ApkSource

    @Binds
    abstract fun bindStatusProbe(impl: FeedbackApi): StatusProbe

    @Binds
    abstract fun bindHostDiscovery(impl: NetworkDiscovery): HostDiscovery
}
