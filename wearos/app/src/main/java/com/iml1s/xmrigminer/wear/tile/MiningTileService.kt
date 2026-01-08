package com.iml1s.xmrigminer.wear.tile

import android.content.Context
import androidx.wear.protolayout.*
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.*
import androidx.wear.protolayout.LayoutElementBuilders.*
import androidx.wear.protolayout.ResourceBuilders.*
import androidx.wear.protolayout.TimelineBuilders.*
import androidx.wear.protolayout.material.*
import androidx.wear.protolayout.material.layouts.*
import androidx.wear.tiles.*
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.runBlocking

/**
 * XMRig Mining Stats Tile
 * Shows hashrate and mining status at a glance
 */
class MiningTileService : TileService() {

    private lateinit var dataClient: DataClient

    override fun onCreate() {
        super.onCreate()
        dataClient = Wearable.getDataClient(this)
    }

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest) =
        runBlocking {
            val stats = getMiningStats()
            Tile.Builder()
                .setResourcesVersion(RESOURCES_VERSION)
                .setFreshnessIntervalMillis(5000) // Update every 5 seconds
                .setTileTimeline(
                    Timeline.Builder()
                        .addTimelineEntry(
                            TimelineEntry.Builder()
                                .setLayout(
                                    Layout.Builder()
                                        .setRoot(createTileLayout(stats))
                                        .build()
                                )
                                .build()
                        )
                        .build()
                )
                .build()
        }

    override fun onTileResourcesRequest(requestParams: RequestBuilders.ResourcesRequest) =
        Resources.Builder()
            .setVersion(RESOURCES_VERSION)
            .build()

    private fun createTileLayout(stats: MiningStats): LayoutElement {
        val deviceParams = DeviceParametersBuilders.DeviceParameters.Builder()
            .setScreenWidthDp(200)
            .setScreenHeightDp(200)
            .build()

        return PrimaryLayout.Builder(deviceParams)
            .setResponsiveContentInsetEnabled(true)
            .setContent(
                Column.Builder()
                    .setWidth(expand())
                    .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
                    .addContent(
                        // Status indicator
                        Text.Builder()
                            .setText(if (stats.isRunning) "⚡ Mining" else "⏸ Stopped")
                            .setTypography(Typography.TYPOGRAPHY_CAPTION1)
                            .setColor(argb(if (stats.isRunning) 0xFF10B981.toInt() else 0xFF94A3B8.toInt()))
                            .build()
                    )
                    .addContent(Spacer.Builder().setHeight(dp(8f)).build())
                    .addContent(
                        // Hashrate
                        Text.Builder()
                            .setText("%.1f".format(stats.hashrate))
                            .setTypography(Typography.TYPOGRAPHY_DISPLAY1)
                            .setColor(argb(0xFF7C3AED.toInt()))
                            .build()
                    )
                    .addContent(
                        Text.Builder()
                            .setText("H/s")
                            .setTypography(Typography.TYPOGRAPHY_CAPTION2)
                            .setColor(argb(0xFF94A3B8.toInt()))
                            .build()
                    )
                    .addContent(Spacer.Builder().setHeight(dp(12f)).build())
                    .addContent(
                        // Shares
                        Row.Builder()
                            .setWidth(expand())
                            .setVerticalAlignment(VERTICAL_ALIGN_CENTER)
                            .addContent(
                                Text.Builder()
                                    .setText("✓ ${stats.accepted}")
                                    .setTypography(Typography.TYPOGRAPHY_CAPTION1)
                                    .setColor(argb(0xFF10B981.toInt()))
                                    .build()
                            )
                            .addContent(Spacer.Builder().setWidth(dp(16f)).build())
                            .addContent(
                                Text.Builder()
                                    .setText("✗ ${stats.rejected}")
                                    .setTypography(Typography.TYPOGRAPHY_CAPTION1)
                                    .setColor(argb(0xFFEF4444.toInt()))
                                    .build()
                            )
                            .build()
                    )
                    .build()
            )
            .build()
    }

    private suspend fun getMiningStats(): MiningStats {
        return try {
            val dataItems = dataClient.getDataItems().await()
            val statsItem = dataItems.find { it.uri.path == PATH_MINING_STATS }
            if (statsItem != null) {
                val dataMap = DataMapItem.fromDataItem(statsItem).dataMap
                MiningStats(
                    isRunning = dataMap.getBoolean("isRunning", false),
                    hashrate = dataMap.getDouble("hashrate", 0.0),
                    accepted = dataMap.getLong("sharesAccepted", 0),
                    rejected = dataMap.getLong("sharesRejected", 0)
                )
            } else {
                MiningStats()
            }
        } catch (e: Exception) {
            MiningStats()
        }
    }

    data class MiningStats(
        val isRunning: Boolean = false,
        val hashrate: Double = 0.0,
        val accepted: Long = 0,
        val rejected: Long = 0
    )

    companion object {
        private const val RESOURCES_VERSION = "1"
        private const val PATH_MINING_STATS = "/mining/stats"
    }
}
