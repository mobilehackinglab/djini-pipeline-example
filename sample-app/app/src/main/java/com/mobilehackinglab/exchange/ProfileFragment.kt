package com.mobilehackinglab.exchange

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.mobilehackinglab.exchange.databinding.FragmentProfileBinding
import org.json.JSONObject

class ProfileFragment : Fragment() {

    private var _binding: FragmentProfileBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentProfileBinding.inflate(inflater, container, false)
        return binding.root
    }

    @SuppressLint("SetTextI18n")
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val tokenManager = TokenManager(requireContext())
        val tokenJsonString = tokenManager.getToken()

        // This block handles displaying user info OR the "Not Logged In" state
        if (tokenJsonString != null) {
            try {
                val fullJson = JSONObject(tokenJsonString)
                val jwt = fullJson.getJSONObject("data").getString("authtoken")
                val userProfile = JwtParser.parseToken(jwt)

                if (userProfile != null) {
                    binding.userNameText.text = userProfile.name
                    binding.userEmailText.text = userProfile.email
                    binding.userTierText.text = userProfile.tier
                    // Make logout button visible since user is logged in
                    binding.logoutButton.visibility = View.VISIBLE
                } else {
                    throw IllegalStateException("JWT could not be parsed.")
                }

            } catch (e: Exception) {
                Log.e("ProfileFragment", "Failed to parse token", e)
                binding.userNameText.text = "Error"
                binding.userEmailText.text = "Error"
                binding.userTierText.text = "Error"
                // Hide logout button if there's an error
                binding.logoutButton.visibility = View.GONE
            }
        } else {
            binding.userNameText.text = "Not Logged In"
            binding.userEmailText.text = "N/A"
            binding.userTierText.text = "N/A"
            // Hide logout button if user is not logged in
            binding.logoutButton.visibility = View.GONE
        }

        binding.helpCenterButton.setOnClickListener {
            val intent = Intent(activity, DWebViewActivity::class.java).apply {
                val helpUrl = "https://mhl-cex-auth-worker.arnotstacc.workers.dev/help"
                putExtra("url_to_load", helpUrl)
            }
            startActivity(intent)
        }

        binding.logoutButton.setOnClickListener {

            val managerToLogout = TokenManager(requireContext())
            managerToLogout.clearToken()

            val intent = Intent(activity, LoginActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }

            startActivity(intent)
            activity?.finish()
        }
    }


    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}

