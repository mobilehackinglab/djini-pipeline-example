package com.mobilehackinglab.exchange

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.core.content.edit
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

class TokenManager(context: Context) {

    private val prefs: SharedPreferences
    private companion object {
        const val KEY_USER_AUTH = "user_auth_data"
    }

    init {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        prefs = EncryptedSharedPreferences.create(
            "secure_token_prefs", // The name of the encrypted file
            masterKeyAlias,
            context,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun saveToken(tokenJson: String) {
        // This saves the token under the KEY_USER_AUTH key
        prefs.edit { putString(KEY_USER_AUTH, tokenJson) }
    }

    fun getToken(): String? {
        // This retrieves the token from the KEY_USER_AUTH key
        return prefs.getString(KEY_USER_AUTH, null)
    }

    fun clearToken() {
        try {
            // This is the correct way to clear SharedPreferences
            prefs.edit { clear() }
        } catch (e: Exception) {
            Log.e("TokenManager", "Failed to clear token from SharedPreferences", e)
        }
    }
}
