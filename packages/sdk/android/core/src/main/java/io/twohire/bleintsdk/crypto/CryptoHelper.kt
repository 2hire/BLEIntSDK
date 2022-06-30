package io.twohire.bleintsdk.crypto

import org.spongycastle.jce.ECNamedCurveTable
import org.spongycastle.jce.interfaces.ECPrivateKey
import org.spongycastle.jce.interfaces.ECPublicKey
import org.spongycastle.jce.provider.BouncyCastleProvider
import org.spongycastle.jce.spec.ECPublicKeySpec
import java.security.*
import java.security.spec.ECGenParameterSpec
import java.security.spec.PKCS8EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlin.experimental.and

internal class CryptoHelper {
    companion object {

        private val keyFactory
            get() = KeyFactory.getInstance(
                CryptoConstants.ALGORITHM_NAME,
                CryptoConstants.PROVIDER_NAME
            )
        private val parameterSpec
            get() =
                ECNamedCurveTable.getParameterSpec(CryptoConstants.CURVE_NAME)

        init {
            Security.addProvider(BouncyCastleProvider())
        }

        fun compactPublicKey(key: ECPublicKey): ByteArray {
            val y = key.q.yCoord.encoded
            val x = key.q.xCoord.encoded

            val out = ByteArray(33)
            out[0] = (2).toByte().plus(y[y.size - 1] and 1).toByte()

            System.arraycopy(x, 0, out, 1, x.size)

            return out
        }

        fun exportPKCS8PrivateKey(key: ECPrivateKey): ByteArray {
            val ecPrivateKey =
                keyFactory.generatePrivate(PKCS8EncodedKeySpec(key.encoded))

            return ecPrivateKey.encoded
        }

        fun wrapPublicKey(bytes: ByteArray): ECPublicKey {
            if (bytes.size != 33) {
                throw IllegalArgumentException("Invalid key length, needed 33 found ${bytes.size}")
            }

            val decodedPoint = parameterSpec.curve.decodePoint(bytes)

            return keyFactory.generatePublic(
                ECPublicKeySpec(
                    decodedPoint,
                    parameterSpec
                )
            ) as ECPublicKey
        }

        fun wrapPKCS8PrivateKey(bytes: ByteArray): ECPrivateKey {
            return keyFactory.generatePrivate(
                PKCS8EncodedKeySpec(bytes)
            ) as ECPrivateKey
        }

        fun generateKeyPair(): ECKeyPair {
            val keyPairGenerator = KeyPairGenerator.getInstance(
                CryptoConstants.ALGORITHM_NAME,
                CryptoConstants.PROVIDER_NAME
            )
            val keyGenSpec = ECGenParameterSpec(CryptoConstants.CURVE_NAME)

            keyPairGenerator.initialize(keyGenSpec, SecureRandom())
            val keyPair = keyPairGenerator.generateKeyPair()

            return ECKeyPair(keyPair.private as ECPrivateKey, keyPair.public as ECPublicKey)
        }

        fun sharedSecret(privateKey: PrivateKey, publicKey: PublicKey): SecretKeySpec {
            val keyAgreement = KeyAgreement.getInstance(
                CryptoConstants.ALGORITHM_NAME,
                CryptoConstants.PROVIDER_NAME
            )

            keyAgreement.init(privateKey)
            keyAgreement.doPhase(publicKey, true)

            val secret = keyAgreement.generateSecret(CryptoConstants.ALGORITHM_NAME).encoded
            val digest = MessageDigest.getInstance("SHA-256").digest(secret)

            return SecretKeySpec(digest, CryptoConstants.ALGORITHM_NAME)
        }

        fun encrypt(data: ByteArray, privateKey: PrivateKey, publicKey: PublicKey): SealedBox {
            val nonceBytes = SecureRandom().generateSeed(CryptoConstants.NONCE_LENGTH)
            val parameterSpec =
                GCMParameterSpec(CryptoConstants.TAG_LENGTH_BIT, nonceBytes, 0, nonceBytes.size)

            val sharedSecret = sharedSecret(privateKey, publicKey)

            val cipher = Cipher.getInstance(CryptoConstants.CRYPTO_TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, sharedSecret, parameterSpec)

            val cipherText = ByteArray(cipher.getOutputSize(data.size))

            var encryptLength = cipher.update(
                data, 0,
                data.size, cipherText, 0
            )
            encryptLength += cipher.doFinal(cipherText, encryptLength)

            val tagBytes = ByteArray(CryptoConstants.TAG_LENGTH)
            System.arraycopy(
                cipherText,
                cipherText.size - CryptoConstants.TAG_LENGTH,
                tagBytes,
                0,
                CryptoConstants.TAG_LENGTH
            )

            val cipherBytes = ByteArray(cipherText.size - CryptoConstants.TAG_LENGTH)
            System.arraycopy(cipherText, 0, cipherBytes, 0, cipherBytes.size)

            return SealedBox(cipherBytes, parameterSpec.iv, tagBytes)
        }

        fun decrypt(sealedBox: SealedBox, privateKey: PrivateKey, publicKey: PublicKey): ByteArray {
            val parameterSpec =
                GCMParameterSpec(
                    CryptoConstants.TAG_LENGTH_BIT,
                    sealedBox.nonce,
                    0,
                    CryptoConstants.NONCE_LENGTH
                )
            val sharedSecret = sharedSecret(privateKey, publicKey)

            val cipher = Cipher.getInstance(CryptoConstants.CRYPTO_TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, sharedSecret, parameterSpec)

            val cipheredBytes = sealedBox.data + sealedBox.tag

            val decryptedBytes = ByteArray(cipher.getOutputSize(cipheredBytes.size))

            var decryptLength = cipher.update(
                cipheredBytes, 0,
                cipheredBytes.size, decryptedBytes, 0
            )
            decryptLength += cipher.doFinal(decryptedBytes, decryptLength)

            return decryptedBytes
        }
    }
}