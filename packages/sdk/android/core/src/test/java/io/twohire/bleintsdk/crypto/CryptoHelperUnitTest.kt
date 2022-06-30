package io.twohire.bleintsdk.crypto

import org.junit.Assert.*
import org.junit.Test

val EXTERNAL_PUBLIC_KEY = byteArrayOf(
    3,
    -83,
    47,
    -91,
    -66,
    117,
    18,
    -78,
    -114,
    -80,
    1,
    -115,
    46,
    -41,
    -95,
    90,
    123,
    46,
    38,
    6,
    -52,
    -21,
    44,
    -8,
    17,
    98,
    -56,
    24,
    123,
    -34,
    -62,
    83,
    21
)

val EXTERNAL_PRIVATE_KEY = byteArrayOf(
    48,
    -127,
    -115,
    2,
    1,
    0,
    48,
    16,
    6,
    7,
    42,
    -122,
    72,
    -50,
    61,
    2,
    1,
    6,
    5,
    43,
    -127,
    4,
    0,
    10,
    4,
    118,
    48,
    116,
    2,
    1,
    1,
    4,
    32,
    -102,
    16,
    -83,
    -112,
    39,
    -59,
    88,
    82,
    -83,
    -52,
    -89,
    127,
    -42,
    34,
    -89,
    -122,
    45,
    29,
    -25,
    14,
    18,
    14,
    -95,
    48,
    84,
    12,
    -32,
    27,
    -1,
    -71,
    11,
    115,
    -96,
    7,
    6,
    5,
    43,
    -127,
    4,
    0,
    10,
    -95,
    68,
    3,
    66,
    0,
    4,
    -83,
    47,
    -91,
    -66,
    117,
    18,
    -78,
    -114,
    -80,
    1,
    -115,
    46,
    -41,
    -95,
    90,
    123,
    46,
    38,
    6,
    -52,
    -21,
    44,
    -8,
    17,
    98,
    -56,
    24,
    123,
    -34,
    -62,
    83,
    21,
    80,
    103,
    -50,
    -126,
    125,
    107,
    -80,
    -60,
    27,
    -65,
    -53,
    -58,
    -18,
    -17,
    -55,
    -37,
    -73,
    -76,
    80,
    -120,
    -92,
    -66,
    -107,
    -27,
    -106,
    126,
    0,
    73,
    -96,
    -106,
    18,
    61
)

class CryptoHelperUnitTest {
    @Test
    fun generatePrivateKeyAndFormat() {
        val keyPair = CryptoHelper.generateKeyPair()

        assertNotNull(keyPair)
        assertNotNull(keyPair.publicKey)
        assertNotNull(keyPair.privateKey)

        val compactPublicKey = CryptoHelper.compactPublicKey(keyPair.publicKey)
        val formattedPrivateKey = CryptoHelper.exportPKCS8PrivateKey(keyPair.privateKey)

        assertEquals(33, compactPublicKey.size)
        assertEquals(144, formattedPrivateKey.size)
    }

    @Test
    fun encryptAndDecryptWithTheSameKeyPair() {
        val message = "testMessage"

        val keyPair = CryptoHelper.generateKeyPair()
        val encryptData = CryptoHelper.encrypt(
            message.toByteArray(charset("UTF-8")),
            keyPair.privateKey,
            keyPair.publicKey
        )

        assertNotNull(encryptData.data)
        assertEquals(11, encryptData.data.size)

        assertNotNull(encryptData.nonce)
        assertEquals(16, encryptData.nonce.size)

        assertNotNull(encryptData.tag)
        assertEquals(16, encryptData.tag.size)

        val decryptData = CryptoHelper.decrypt(encryptData, keyPair.privateKey, keyPair.publicKey)

        assertNotNull(decryptData)
        assertEquals(message, String(decryptData, charset("UTF-8")))
    }

    @Test
    fun wrapPublicKey() {
        val publicKey = CryptoHelper.wrapPublicKey(EXTERNAL_PUBLIC_KEY)

        assertNotNull(publicKey)
        assertNotEquals(0, publicKey.encoded.size)

        val formattedPublicKey = CryptoHelper.compactPublicKey(publicKey)
        assertArrayEquals(formattedPublicKey, EXTERNAL_PUBLIC_KEY)
    }

    @Test
    fun wrapPrivateKey() {
        val privateKey = CryptoHelper.wrapPKCS8PrivateKey(EXTERNAL_PRIVATE_KEY)

        assertNotNull(privateKey)
        assertNotEquals(0, privateKey.encoded.size)

        val formattedKey = CryptoHelper.exportPKCS8PrivateKey(privateKey)
        assertArrayEquals(EXTERNAL_PRIVATE_KEY, formattedKey)
    }

    @Test
    fun createSharedSecret() {
        val keyPair = CryptoHelper.generateKeyPair()
        assertNotNull(keyPair)

        val wrappedPublicKey = CryptoHelper.wrapPublicKey(EXTERNAL_PUBLIC_KEY)
        assertNotNull(wrappedPublicKey)

        val wrappedPrivateKey = CryptoHelper.wrapPKCS8PrivateKey(EXTERNAL_PRIVATE_KEY)
        assertNotNull(wrappedPrivateKey)

        val personalSharedSecret = CryptoHelper.sharedSecret(keyPair.privateKey, wrappedPublicKey)
        assertNotNull(personalSharedSecret)
        assertNotEquals(0, personalSharedSecret.encoded.size)

        val externalSharedSecret = CryptoHelper.sharedSecret(wrappedPrivateKey, keyPair.publicKey)
        assertNotNull(externalSharedSecret)
        assertNotEquals(0, externalSharedSecret.encoded.size)

        assertArrayEquals(personalSharedSecret.encoded, externalSharedSecret.encoded)
    }

    @Test
    fun encryptAndDecryptWithExternalPublicKey() {
        val message = "testMessage"

        val privateKey = CryptoHelper.generateKeyPair().privateKey
        assertNotNull(privateKey)

        val wrappedPublicKey = CryptoHelper.wrapPublicKey(EXTERNAL_PUBLIC_KEY)
        assertNotNull(wrappedPublicKey)

        val encryptData = CryptoHelper.encrypt(
            message.toByteArray(charset("UTF-8")),
            privateKey,
            wrappedPublicKey
        )

        assertNotNull(encryptData.data)
        assertEquals(11, encryptData.data.size)

        assertNotNull(encryptData.nonce)
        assertEquals(16, encryptData.nonce.size)

        assertNotNull(encryptData.tag)
        assertEquals(16, encryptData.tag.size)

        val decryptData = CryptoHelper.decrypt(encryptData, privateKey, wrappedPublicKey)

        assertNotNull(decryptData)
        assertEquals(message, String(decryptData, charset("UTF-8")))
    }

    @Test
    fun encryptBetweenTwoActors() {
        val message = "Hey Bob! It's a-me Alice!"

        val aliceKeyPair = CryptoHelper.generateKeyPair()
        val bobKeyPair = CryptoHelper.generateKeyPair()

        val encryptData = CryptoHelper.encrypt(
            message.toByteArray(charset("UTF-8")),
            aliceKeyPair.privateKey,
            bobKeyPair.publicKey
        )

        assertNotNull(encryptData.data)
        assertEquals(25, encryptData.data.size)

        assertNotNull(encryptData.nonce)
        assertEquals(16, encryptData.nonce.size)

        assertNotNull(encryptData.tag)
        assertEquals(16, encryptData.tag.size)

        val decryptData =
            CryptoHelper.decrypt(encryptData, bobKeyPair.privateKey, aliceKeyPair.publicKey)

        assertNotNull(decryptData)
        assertEquals(message, String(decryptData, charset("UTF-8")))
    }

    @Test(expected = javax.crypto.AEADBadTagException::class)
    fun encryptBetweenTwoActorsWithWrongKeys() {
        val message = "Hey Bob! It's a-me Alice!"

        val aliceKeyPair = CryptoHelper.generateKeyPair()
        val bobKeyPair = CryptoHelper.generateKeyPair()

        val encryptData = CryptoHelper.encrypt(
            message.toByteArray(charset("UTF-8")),
            aliceKeyPair.privateKey,
            bobKeyPair.publicKey
        )

        assertNotNull(encryptData.data)
        assertEquals(25, encryptData.data.size)

        assertNotNull(encryptData.nonce)
        assertEquals(16, encryptData.nonce.size)

        assertNotNull(encryptData.tag)
        assertEquals(16, encryptData.tag.size)

        CryptoHelper.decrypt(encryptData, bobKeyPair.privateKey, bobKeyPair.publicKey)
    }
}