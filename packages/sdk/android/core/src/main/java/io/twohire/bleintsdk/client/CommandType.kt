package io.twohire.bleintsdk.client

enum class CommandType(val rawValue: String) {
    Start("start"),
    Stop("stop"),
    EndSession("end_session");

    companion object {
        fun fromRawValue(name: String) =
            values()
                .reduceOrNull { acc, commandType -> if (commandType.rawValue == name) commandType else acc }
    }
}
