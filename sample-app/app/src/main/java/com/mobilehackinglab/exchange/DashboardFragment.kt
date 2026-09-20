package com.mobilehackinglab.exchange

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.mobilehackinglab.exchange.databinding.FragmentDashboardBinding

class DashboardFragment : Fragment() {

    private var _binding: FragmentDashboardBinding? = null
    private val binding get() = _binding!!

    // URLs for our promo banners. One is safe, one is the exploit.
    private val promoUrls = listOf(
        "https://mhl-cex-auth-worker.arnotstacc.workers.dev/promo/0",
        "https://mhl-cex-auth-worker.arnotstacc.workers.dev/promo/1"
    )

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDashboardBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // The list of images for the slider, now with the summer bonus
        val images = listOf(R.drawable.promo_banner)

        // Set up the adapter for the ViewPager2
        val adapter = PromoSliderAdapter(images) { position ->
            // This code runs when a promo banner is clicked
            val urlToLoad = promoUrls[position]
            launchWebView(urlToLoad)
        }

        binding.promoViewpager.adapter = adapter

        // Optional: Add visual effects to make the slider look good
        binding.promoViewpager.offscreenPageLimit = 1
        binding.promoViewpager.clipToPadding = false
        binding.promoViewpager.clipChildren = false
    }

    private fun launchWebView(url: String) {
        val intent = Intent(activity, DWebViewActivity::class.java).apply {
            putExtra("url_to_load", url)
        }
        startActivity(intent)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
