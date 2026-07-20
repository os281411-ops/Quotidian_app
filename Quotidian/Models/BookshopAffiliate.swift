import Foundation

/// Bookshop.org affiliate settings.
///
/// Sign up at https://bookshop.org/affiliates/profile/introduction, then find
/// your numeric Affiliate ID on the "Affiliate Profile & Lists" page under
/// "Update My Profile." Paste it below as a string (e.g. "5780").
///
/// Until an ID is set, purchase links fall back to a plain Bookshop.org search
/// for the book — fully functional, just without affiliate credit.
enum BookshopAffiliate {
    static let id: String? = "17815"
}
