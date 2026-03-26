import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://ioessfugnlhzjdllbuue.supabase.co")!
    static let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvZXNzZnVnbmxoempkbGxidXVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NTUzMDcsImV4cCI6MjA5MDAzMTMwN30.9Hrz5kSJCMxfgARn_l6kV6LA82g6kWmneG8qpFfjHEo"
}

final class SupabaseManager {
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.key
    )
}
