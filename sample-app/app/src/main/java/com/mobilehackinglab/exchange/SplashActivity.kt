package com.mobilehackinglab.exchange

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class SplashActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val tokenManager = TokenManager(applicationContext)
        val targetIntent: Intent

        if (tokenManager.getToken() != null) {
            targetIntent = Intent(this, MainActivity::class.java).apply {
                data = intent.data
                action = intent.action
            }
        } else {
            targetIntent = Intent(this, LoginActivity::class.java)
        }

        startActivity(targetIntent)
        finish() // Close the SplashActivity
    }

}
