package  io.twohire.reactnative.bleintsdk

import android.util.Base64
import com.facebook.react.bridge.*
import io.twohire.bleintsdk.client.*
import io.twohire.bleintsdk.utils.BLEIntSDKException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.internal.toImmutableMap

class ReactNativeBleIntSdkModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val tag =
        "${ReactNativeBleIntSdkModule::class.simpleName}@${System.identityHashCode(this)}"
    var scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    companion object {
        private var client: Client? = null

        private fun getClientInstance(): Client {
            if (this.client == null) {
                this.client = Client()
            }

            return this.client!!
        }
    }

    override fun getName(): String {
        return "ReactNativeBleintSdk"
    }

    @ReactMethod
    fun sessionSetup(
        accessToken: String,
        commands: ReadableMap,
        publicKey: String,
        promise: Promise
    ) {
        try {
            getClientInstance().let {
                it.sessionSetup(
                    reactApplicationContext,
                    SessionConfig(accessToken, publicKey, buildCommands(commands))
                )

                promise.resolve(true)
            }
        } catch (sdkException: BLEIntSDKException) {
            sdkException.printStackTrace()

            promise.reject(
                sdkException.error.code,
                "Something went wrong while creating ${sdkException.error.description}",
                sdkException
            )
        } catch (error: Exception) {
            error.printStackTrace()

            promise.reject("error", "Something went wrong while creating", error)
        }
    }

    @ReactMethod
    fun connect(address: String, promise: Promise) {
        this.scope.launch {
            try {
                getClientInstance().let {
                    promise.resolve(
                        it.connectToVehicle(address)?.toWritableMap()
                    )
                }
            } catch (sdkException: BLEIntSDKException) {
                sdkException.printStackTrace()

                promise.reject(
                    sdkException.error.code,
                    "Something went wrong while connecting to vehicle ${sdkException.error.description}",
                    sdkException
                )
            } catch (error: Exception) {
                error.printStackTrace()

                promise.reject("error", "Something went wrong while connecting to vehicle", error)
            }
        }
    }

    @ReactMethod
    fun sendCommand(command: String, promise: Promise) =
        this.scope.launch {
            try {
                val commandType = CommandType.fromRawValue(command)

                if (commandType !== null) {
                    println(commandType.rawValue)
                    getClientInstance().let {
                        promise.resolve(
                            it.sendCommand(commandType).toWritableMap()
                        )
                    }
                } else {
                    promise.reject(
                        "command_not_found",
                        "Command not found",
                        IllegalStateException("BadDataError")
                    )
                }
            } catch (sdkException: BLEIntSDKException) {
                sdkException.printStackTrace()

                promise.reject(
                    sdkException.error.code,
                    "Something went wrong while sending command to vehicle ${sdkException.error.description}",
                    sdkException
                )
            } catch (error: Exception) {
                error.printStackTrace()

                promise.reject(
                    "error",
                    "Something went wrong while sending command to vehicle",
                    error
                )
            }
        }

    @ReactMethod
    fun endSession(promise: Promise) =
        this.scope.launch {
            try {
                getClientInstance().let {
                    val response = it.endSession()

                    promise.resolve(response.toWritableMap())
                }
            } catch (sdkException: BLEIntSDKException) {
                sdkException.printStackTrace()

                promise.reject(
                    sdkException.error.code,
                    "Something went wrong while ending session ${sdkException.error.description}",
                    sdkException
                )
            } catch (error: Exception) {
                error.printStackTrace()

                promise.reject("error", "Something went wrong while ending session", error)
            }
        }
}

internal fun buildCommands(map: ReadableMap): Commands {
    val commands: MutableMap<CommandType, String> = mutableMapOf()

    CommandType.values().forEach {
        map.getString(it.rawValue)?.let { value ->
            commands[it] = value
        }
    }

    return commands.toImmutableMap()
}

internal fun CommandResponse.toWritableMap(): WritableMap =
    Arguments.createMap().apply {
        putBoolean("success", this@toWritableMap.success)
        putString(
            "payload",
            Base64.encodeToString(
                this@toWritableMap.additionalPayload,
                Base64.NO_WRAP
            )
        )
    }

