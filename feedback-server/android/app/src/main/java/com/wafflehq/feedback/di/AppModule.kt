package com.wafflehq.feedback.di

import android.content.Context
import android.os.Environment
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStoreFile
import com.wafflehq.feedback.data.api.ApkSource
import com.wafflehq.feedback.data.download.ApkCache
import com.wafflehq.feedback.data.download.ApkDownloader
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import java.util.concurrent.TimeUnit
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import okhttp3.OkHttpClient

private const val CONNECT_TIMEOUT_SECONDS = 10L
private const val READ_TIMEOUT_SECONDS = 30L
private const val CONNECTION_STORE_NAME = "connection"

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .readTimeout(READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .writeTimeout(READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .followRedirects(false)
        .build()

    @Provides
    @Singleton
    fun provideConnectionDataStore(@ApplicationContext context: Context): DataStore<Preferences> =
        PreferenceDataStoreFactory.create { context.preferencesDataStoreFile(CONNECTION_STORE_NAME) }

    @Provides
    @Singleton
    fun provideApkCache(@ApplicationContext context: Context): ApkCache =
        ApkCache(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: context.filesDir)

    @Provides
    @Singleton
    fun provideApkDownloader(source: ApkSource, cache: ApkCache): ApkDownloader =
        ApkDownloader(source, cache, CoroutineScope(SupervisorJob() + Dispatchers.IO))
}
