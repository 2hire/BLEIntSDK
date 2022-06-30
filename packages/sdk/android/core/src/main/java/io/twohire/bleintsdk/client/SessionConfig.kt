package io.twohire.bleintsdk.client

data class SessionConfig(val accessToken: String, val publicKey: String, val commands: Commands)

typealias Commands = Map<CommandType, String>
