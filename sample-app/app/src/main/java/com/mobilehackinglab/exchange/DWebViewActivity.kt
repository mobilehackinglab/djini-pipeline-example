package com.mobilehackinglab.exchange

import android.annotation.SuppressLint
import android.os.Bundle
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.mobilehackinglab.exchange.databinding.ActivityDwebViewBinding
import com.tencent.smtt.sdk.WebViewClient

class DWebViewActivity : AppCompatActivity() {

    private lateinit var binding: ActivityDwebViewBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityDwebViewBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val urlToLoad = intent.getStringExtra("url_to_load")

        binding.dwebview.settings.apply {
            domStorageEnabled = true
            javaScriptCanOpenWindowsAutomatically = false
            allowFileAccess = false
            setAllowFileAccessFromFileURLs(false)
            setAllowUniversalAccessFromFileURLs(false)
            allowContentAccess = false
            setSupportMultipleWindows(false)
        }

        binding.dwebview.webViewClient = WebViewClient()

        binding.dwebview.addJavascriptObject(JsApi(this), null)

        if (urlToLoad != null && urlToLoad.startsWith("http")) {
            binding.dwebview.loadUrl(urlToLoad)
        } else {
            finish()
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (binding.dwebview.canGoBack()) {
                    binding.dwebview.goBack()
                } else {
                    finish()
                }
            }
        })
    }
}
