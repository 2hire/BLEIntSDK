package io.twohire.bleintsdk.client

enum class CommandType(val rawValue: String) {
    Start("start"),
    Stop("stop"),
    Noop("noop"),
    Locate("locate"),
    EndSession("end_session");

    companion object {
        fun fromRawValue(name: String) =
            values()
                .reduceOrNull { acc, commandType -> if (commandType.rawValue == name) commandType else acc }
    }
}
