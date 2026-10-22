import Foundation
import Supabase

/// Which Supabase project the app talks to.
///
/// * Quotidian (App Store / Archive / Release) always uses the LIVE project.
/// * Quotidian Dev (Xcode Run / Debug) uses the DEV project, unless the
///   Developer Menu's "Use Live Database" switch is on, or the dev details
///   below haven't been filled in yet.
///
/// Publishable keys are meant to live inside the app. They only identify a
/// project; what anyone can read or change is decided by the access rules in
/// `backend/supabase/migrations`. Never put a *secret* (service role) key here.
enum SupabaseConfig {
    // LIVE project ("os281411-ops's Project"): real users, App Store app.
    private static let liveURL = "https://fvceusfilhbndnjrdlnx.supabase.co"
    private static let liveKey = "sb_publishable_jYC0EQEizYnwg92jXQePJA_vZiMAT2T"

    // DEV project ("Quotidian Dev"): test data, dev app.
    // Supabase → Quotidian Dev → Project Settings → API Keys / Data API.
    private static let devURL = "PASTE_DEV_PROJECT_URL_HERE"   // e.g. "https://abcdefgh.supabase.co"
    private static let devKey = "PASTE_DEV_PUBLISHABLE_KEY_HERE"

    #if DEBUG
    /// True when this build talks to the dev project.
    static let isDevDatabase: Bool = {
        let devIsSetUp = devURL.hasPrefix("https://") && !devKey.hasPrefix("PASTE")
        let wantsLive = UserDefaults.standard.bool(forKey: "debug.useLiveDatabase")
        return devIsSetUp && !wantsLive
    }()
    #else
    static let isDevDatabase = false
    #endif

    static var url: URL { URL(string: isDevDatabase ? devURL : liveURL)! }
    static var publishableKey: String { isDevDatabase ? devKey : liveKey }
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.publishableKey,
    options: SupabaseClientOptions(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )
)
