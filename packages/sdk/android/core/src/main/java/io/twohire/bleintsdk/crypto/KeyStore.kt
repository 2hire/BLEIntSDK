package io.twohire.bleintsdk.crypto

import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedFile
import androidx.security.crypto.MasterKeys
import io.twohire.bleintsdk.utils.toByteArray
import io.twohire.bleintsdk.utils.toHex
import java.io.File
import java.nio.charset.StandardCharsets

class KeyStore {
    companion object {
        private val tag = "${KeyStore::class.simpleName}"

        private val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)

        private fun saveOrUpdatePrivateKey(key: ECKeyPair, context: Context) {
            val privateKey = CryptoHelper.exportPKCS8PrivateKey(key.privateKey)
            val publicKey = CryptoHelper.compactPublicKey(key.publicKey)

            val data = (publicKey + privateKey).toHex().toByteArray(StandardCharsets.UTF_8)
            Log.d(tag, "Saving KeyPair in keystore")

            val file = getFile(context).also {
                deleteKeyPair(it)
            }

            getEncryptedFile(file, context).openFileOutput().apply {
                write(data)
                flush()
                close()
            }
        }

        private fun getPrivateKey(context: Context): ECKeyPair {
            val encryptedFile = getEncryptedFile(getFile(context), context)

            val bufferedReader =
                encryptedFile.openFileInput().bufferedReader(StandardCharsets.UTF_8)
            val byteArray = bufferedReader.readText().toByteArray()
            bufferedReader.close()

            val publicKey = CryptoHelper.wrapPublicKey(byteArray.sliceArray(0 until 33))
            val privateKey = CryptoHelper.wrapPKCS8PrivateKey(byteArray.drop(33).toByteArray())

            return ECKeyPair(privateKey, publicKey)
        }

        private fun generateAndSaveKeyPair(context: Context): ECKeyPair {
            Log.d(tag, "Generating KeyPair")

            val keyPair = CryptoHelper.generateKeyPair()

            this.saveOrUpdatePrivateKey(keyPair, context)

            return keyPair
        }

        fun getOrGeneratePrivateKey(context: Context): ECKeyPair {
            return try {
                this.getPrivateKey(context)
            } catch (error: Exception) {
                Log.d(tag, "Error while getting keys (${error.message}), regenerating")

                this.generateAndSaveKeyPair(context)
            }
        }

        fun deletePrivateKey(context: Context) = deleteKeyPair(getFile(context))

        private fun deleteKeyPair(file: File) = file.apply { if (this.exists()) this.delete() }

        private fun getFile(context: Context) = File(context.filesDir, "ble_private_data")

        private fun getEncryptedFile(file: File, context: Context) =
            EncryptedFile.Builder(
                file,
                context,
                masterKeyAlias,
                EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB
            ).build()
    }
}