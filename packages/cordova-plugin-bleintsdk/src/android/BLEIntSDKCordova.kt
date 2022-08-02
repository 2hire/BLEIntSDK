package io.twohire.cordova.bleintsdk

import android.content.Context
import android.util.Base64
import io.twohire.bleintsdk.client.*
import io.twohire.bleintsdk.utils.BLEIntSDKException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.apache.cordova.CallbackContext
import org.apache.cordova.CordovaPlugin
import org.apache.cordova.PluginResult
import org.json.JSONArray
import org.json.JSONObject


class BLEIntSDKCordova : CordovaPlugin() {
    var scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    val context: Context
        get() = cordova.activity.applicationContext

    companion object {
        private var client: Client? = null

        private fun getClientInstance(): Client {
            if (this.client == null) {
                this.client = Client()
            }

            return this.client!!
        }
    }

    override fun execute(
        action: String,
        args: JSONArray,
        callbackContext: CallbackContext
    ): Boolean {
        when (action) {
            "sessionSetup" -> {
                this.sessionSetup(args, callbackContext)
            }
            "connect" -> {
                this.connect(args, callbackContext)
            }
            "sendCommand" -> {
                this.sendCommand(args, callbackContext)
            }
            "endSession" -> {
                this.endSession(callbackContext)
            }
            else -> {
                return false
            }
        }

        return true
    }

    private fun sessionSetup(args: JSONArray, callbackContext: CallbackContext) {
        try {
            val accessToken = args.getString(0)
            val commands = args.getJSONObject(1)
            val publicKey = args.getString(2)

            getClientInstance().let {
                it.sessionSetup(
                    this.context,
                    SessionConfig(
                        accessToken, publicKey,
                        buildCommands(commands)
                    )
                )

                callbackContext.sendPluginResult(
                    PluginResult(PluginResult.Status.OK, true)
                )
            }
        } catch (e: BLEIntSDKException) {
            e.printStackTrace()
            callbackContext.error(e.toJSONObject { "Something went wrong while creating ($it)" })
        } catch (e: Exception) {
            e.printStackTrace()
            callbackContext.error("Something went wrong while creating (${e.message})")
        }
    }

    private fun connect(args: JSONArray, callbackContext: CallbackContext) {
        this.scope.launch {
            try {
                getClientInstance().let {
                    val address = args.getString(0)

                    callbackContext.sendPluginResult(
                        PluginResult(
                            PluginResult.Status.OK,
                            it.connectToVehicle(address, context).toJSONObject()
                        )
                    )
                }
            } catch (e: BLEIntSDKException) {
                e.printStackTrace()
                callbackContext.error(e.toJSONObject { "Something went wrong while connecting to vehicle ($it)" })
            } catch (e: Exception) {
                e.printStackTrace()
                callbackContext.error("Something went wrong while connecting to vehicle (${e.message})")
            }
        }
    }

    private fun sendCommand(args: JSONArray, callbackContext: CallbackContext) =
        this.scope.launch {
            try {
                val commandType = CommandType.fromRawValue(args.getString(0))

                if (commandType !== null) {
                    getClientInstance().let {
                        callbackContext.sendPluginResult(
                            PluginResult(
                                PluginResult.Status.OK,
                                it.sendCommand(commandType).toJSONObject()
                            )
                        )
                    }
                } else {
                    callbackContext.error("Command not found")
                }
            } catch (e: BLEIntSDKException) {
                e.printStackTrace()
                callbackContext.error(e.toJSONObject { "Something went wrong while sending command to vehicle ($it)" })
            } catch (error: Exception) {
                error.printStackTrace()

                callbackContext.error(
                    "Something went wrong while sending command to vehicle",
                )
            }
        }

    private fun endSession(callbackContext: CallbackContext) =
        this.scope.launch {
            try {
                getClientInstance().let {
                    callbackContext.sendPluginResult(
                        PluginResult(
                            PluginResult.Status.OK,
                            it.endSession().toJSONObject()
                        )
                    )
                }
            } catch (e: BLEIntSDKException) {
                e.printStackTrace()
                callbackContext.error(e.toJSONObject { "Something went wrong while ending session ($it)" })
            } catch (error: Exception) {
                error.printStackTrace()
                callbackContext.error("Something went wrong while ending session")
            }
        }
}

internal fun buildCommands(map: JSONObject): Commands {
    val commands: MutableMap<CommandType, String> = mutableMapOf()

    CommandType.values().forEach {
        if (map.has(it.rawValue)) {
            map.getString(it.rawValue).let { value ->
                commands[it] = value
            }
        }
    }

    return commands
}

internal fun CommandResponse.toJSONObject(): JSONObject =
    JSONObject()
        .put("success", this.success)
        .put("payload", Base64.encodeToString(this.additionalPayload, Base64.DEFAULT))

internal fun BLEIntSDKException.toJSONObject(getMessage: (m: String) -> String): JSONObject =
    JSONObject().put("code", this.error.code).put("message", getMessage(this.error.description))