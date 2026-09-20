package com.mobilehackinglab.exchange

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import com.mobilehackinglab.exchange.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.bottomNavigation.setOnItemSelectedListener { item ->
            val selectedFragment: Fragment = when (item.itemId) {
                R.id.nav_wallet -> WalletFragment()
                R.id.nav_profile -> ProfileFragment()
                else -> DashboardFragment()
            }
            loadFragment(selectedFragment)
            true
        }

        if (savedInstanceState == null) {
            loadFragment(DashboardFragment())
        }

        handleIntent(intent)
    }


    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun loadFragment(fragment: Fragment) {
        // Use the binding object to get the fragment container view
        supportFragmentManager.beginTransaction().replace(binding.fragmentContainer.id, fragment)
            .commit()
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_VIEW && intent.data?.scheme == "mhlcrypto") {
            val uri = intent.data!!

            if ("showPage" == uri.host) {
                val urlToLoad = uri.getQueryParameter("url")
                if (urlToLoad != null) {
                    val webViewIntent = Intent(this, DWebViewActivity::class.java).apply {
                        putExtra("url_to_load", urlToLoad)
                    }
                    startActivity(webViewIntent)
                }
            }
        }
    }
}
