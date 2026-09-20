package com.mobilehackinglab.exchange

// Correct import for the java-jwt library
import com.auth0.jwt.JWT
import com.auth0.jwt.interfaces.DecodedJWT

// The data class remains the same
data class UserProfile(
    val name: String,
    val email: String,
    val tier: String
)

object JwtParser {
    fun parseToken(token: String): UserProfile? {
        return try {
            // This is the correct way to decode a token with the java-jwt library
            val decodedJWT: DecodedJWT = JWT.decode(token)

            // Get claims from the decoded token
            val name = decodedJWT.getClaim("name").asString() ?: "N/A"
            val email = decodedJWT.getClaim("email").asString() ?: "john@doe.co"
            val tier = decodedJWT.getClaim("tier").asString() ?: "Standard"

            UserProfile(name, email, tier)
        } catch (e: Exception) {
            // Handle parsing exception gracefully
            null
        }
    }
}
