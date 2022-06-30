package io.twohire.bleintsdk.crypto

import org.spongycastle.jce.interfaces.ECPrivateKey
import org.spongycastle.jce.interfaces.ECPublicKey

data class ECKeyPair(
    var privateKey: ECPrivateKey, var publicKey: ECPublicKey
)