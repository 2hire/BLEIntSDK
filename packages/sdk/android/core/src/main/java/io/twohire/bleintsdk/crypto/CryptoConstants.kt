package io.twohire.bleintsdk.crypto

import org.spongycastle.jce.provider.BouncyCastleProvider

internal class CryptoConstants {
    companion object {
        const val CURVE_NAME = "secp256k1"
        const val ALGORITHM_NAME = "ECDH"
        const val PROVIDER_NAME = BouncyCastleProvider.PROVIDER_NAME
        const val CRYPTO_TRANSFORMATION = "AES/GCM/NoPadding"
        const val TAG_LENGTH = 16
        const val TAG_LENGTH_BIT = TAG_LENGTH * 8
        const val NONCE_LENGTH = 2 * 8
    }
}