package io.twohire.bleintsdk.client

data class SessionConfig(val accessToken: String, val publicKey: String, val commands: Commands) {
    override fun toString(): String = "SessionConfig(accessToken: \"$accessToken\", publicKey: \"$publicKey\", commands: \"$commands\")"
}

typealias Commands = Map<CommandType, String>
