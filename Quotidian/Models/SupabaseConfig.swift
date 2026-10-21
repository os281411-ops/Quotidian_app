import Foundation
import Supabase

/// The one connection to Quotidian's Supabase backend, shared by the whole app.
///
/// The publishable key is meant to live inside the app. It only identifies the
/// project; what anyone can read or change is decided by the access rules in
/// `backend/supabase/migrations`. Never put the *secret* (service role) key here.
enum SupabaseConfig {
    static let url = URL(string: "https://fvceusfilhbndnjrdlnx.supabase.co")!

    /// Supabase dashboard → Project Settings → API Keys → Publishable key
    /// (starts with `sb_publishable_`). If your project only shows the older
    /// "anon public" key, that works here too.
    static let publishableKey = "sb_publishable_jYC0EQEizYnwg92jXQePJA_vZiMAT2T"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.publishableKey,
    options: SupabaseClientOptions(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )
)
