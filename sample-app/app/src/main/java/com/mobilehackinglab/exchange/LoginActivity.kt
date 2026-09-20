package com.mobilehackinglab.exchange

import android.content.Intent
import android.os.Bundle
import android.util.Patterns
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.mobilehackinglab.exchange.databinding.ActivityLoginBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class LoginActivity : AppCompatActivity() {

    private lateinit var binding: ActivityLoginBinding
    private val client = OkHttpClient() // Reusable client for network calls

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.loginButton.setOnClickListener {
            // 1. Get the input from the UI fields.
            val email = binding.editTextEmail.text.toString().trim()
            val password = binding.editTextPassword.text.toString().trim()

            // 2. Pass the retrieved input to the validation function.
            if (validateInput(email, password)) {
                // 3. If validation succeeds, pass the same input to the login function.
                performLogin(email, password)
            }
        }
    }

    /**
     * Performs the network request to log the user in.
     * This now takes the email and password as parameters.
     */
    private fun performLogin(email: String, password: String) {
        lifecycleScope.launch(Dispatchers.IO) { // Use background thread for network call
            try {
                val jsonPayload = "{\"email\":\"$email\", \"password\":\"$password\"}"
                val requestBody = jsonPayload.toRequestBody("application/json; charset=utf-8".toMediaType())

                val request = Request.Builder()
                    // IMPORTANT: Make sure this URL is correct for your worker
                    .url("https://mhl-cex-auth-worker.arnotstacc.workers.dev/api/login")
                    .post(requestBody)
                    .build()

                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        val responseBody = response.body?.string() ?: throw Exception("Empty response body")
                        val receivedToken = JSONObject(responseBody).getString("authtoken")

                        // Save the token received from the server
                        val fullTokenData = """{ "code": "0", "data": { "authtoken": "$receivedToken" } }"""
                        TokenManager(applicationContext).saveToken(fullTokenData)

                        // Switch to the main thread to navigate to the next activity
                        withContext(Dispatchers.Main) {
                            goToMainActivity()
                        }
                    } else {
                        // Handle server-side errors (e.g., 400 Bad Request)
                        throw Exception("Login failed: ${response.code} ${response.message}")
                    }
                }
            } catch (e: Exception) {
                // Handle network errors or parsing exceptions
                withContext(Dispatchers.Main) {
                    Toast.makeText(applicationContext, "Login failed: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    private fun goToMainActivity() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(intent)
        finish() // Finish LoginActivity so user can't go back to it
    }

    /**
     * Validates user input and shows specific error messages on the UI fields.
     */
    private fun validateInput(email: String, password: String): Boolean {
        // Clear any previous errors
        binding.editTextEmail.error = null
        binding.editTextPassword.error = null

        // Validate Email Format
        if (!Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            binding.editTextEmail.error = "Please enter a valid email address"
            return false
        }

        // Validate Password Length
        if (password.length < 6) {
            binding.editTextPassword.error = "Password must be at least 6 characters"
            return false
        }

        // If all checks pass, the input is valid
        return true
    }
}

