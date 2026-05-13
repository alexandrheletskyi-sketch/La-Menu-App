import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://ioessfugnlhzjdllbuue.supabase.co")!
    static let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvZXNzZnVnbmxoempkbGxidXVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NTUzMDcsImV4cCI6MjA5MDAzMTMwN30.9Hrz5kSJCMxfgARn_l6kV6LA82g6kWmneG8qpFfjHEo"
}

enum SupabaseManager {
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.key
    )

    static func uploadImage(
        data: Data,
        bucket: String,
        path: String
    ) async throws -> String {
        try await shared.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        return try shared.storage
            .from(bucket)
            .getPublicURL(path: path)
            .absoluteString
    }

    static func fetchSMSUsageOverview(profileId: UUID) async throws -> SMSUsageOverview {
        try await shared
            .from("subscription_plan_overview")
            .select("sms_limit, sms_remaining, sms_used_this_period")
            .eq("profile_id", value: profileId.uuidString)
            .single()
            .execute()
            .value
    }

    static func activateSubscriptionForCurrentProfile(
        planCode: String,
        provider: String = "apple",
        providerProductId: String
    ) async throws {
        do {
            let session = try await shared.auth.session

            print("👤 Supabase current user:", session.user.id.uuidString)
            print("📦 Activating plan:", planCode)
            print("🧾 Product ID:", providerProductId)

            let params: [String: String] = [
                "p_plan_code": planCode,
                "p_provider": provider,
                "p_provider_product_id": providerProductId
            ]

            try await shared
                .rpc("activate_subscription_for_current_profile", params: params)
                .execute()

            print("✅ RPC activate_subscription_for_current_profile completed:", params)
        } catch {
            print("❌ RPC activate_subscription_for_current_profile failed:")
            print(error)
            print("❌ localized:", error.localizedDescription)
            throw error
        }
    }
}
