package com.mobilehackinglab.exchange

import android.content.Context
import android.content.Intent
import android.webkit.JavascriptInterface
import org.json.JSONObject
import wendu.dsbridge.CompletionHandler

// The bridge needs context to access TokenManager and start new Activities
class JsApi(private val context: Context) {

    @JavascriptInterface
    fun getUserAuth(args: Any?, handler: CompletionHandler<Any>) {
        val tokenManager = TokenManager(context)
        val tokenJsonString = tokenManager.getToken()

        if (tokenJsonString != null) {
            handler.complete(JSONObject(tokenJsonString))
        } else {
            handler.complete(JSONObject().put("error", "No token found"))
        }
    }

    @JavascriptInterface
    fun openNewWindow(args: Any?) {
        try {
            if (args is JSONObject) {
                val url = args.optString("url")
                if (url.isNotEmpty() && url.startsWith("http")) {
                    val intent = Intent(context, DWebViewActivity::class.java).apply {
                        putExtra("url_to_load", url)
                    }
                    context.startActivity(intent)
                }
            }
        } catch (e: Exception) {
        }
    }
}
