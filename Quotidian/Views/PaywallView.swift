import StoreKit
import SwiftUI

struct PaywallView: View {
    let trigger: PaywallTrigger
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String?
    @State private var isPurchasing = false

    private var monthly: Product? {
        subscriptions.products.first { $0.id == SubscriptionManager.monthlyID }
    }

    private var annual: Product? {
        subscriptions.products.first { $0.id == SubscriptionManager.annualID }
    }

    private var selectedProduct: Product? {
        subscriptions.products.first { $0.id == selectedProductID } ?? annual ?? monthly
    }

    private var annualSavingsPercent: Int? {
        guard let monthly, let annual, monthly.price > 0 else { return nil }
        let yearlyAtMonthlyRate = monthly.price * 12
        guard yearlyAtMonthlyRate > annual.price else { return nil }
        let savings = (yearlyAtMonthlyRate - annual.price) / yearlyAtMonthlyRate * 100
        return NSDecimalNumber(decimal: savings).intValue
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        header

                        featureList

                        if subscriptions.isLoadingProducts {
                            ProgressView()
                                .tint(Theme.accent)
                                .padding(.top, 12)
                        } else if subscriptions.products.isEmpty {
                            Text("Subscription options aren't available right now.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        } else {
                            pricingOptions
                        }

                        if let error = subscriptions.purchaseError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        subscribeButton

                        restoreButton

                        Text("Subscriptions auto-renew until cancelled. Manage or cancel anytime in Settings > Apple ID > Subscriptions.")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)

                        HStack(spacing: 6) {
                            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .underline()
                            Text("·")
                            Link("Privacy Policy", destination: URL(string: "https://os281411-ops.github.io/Quotidian_app/privacy-policy.html")!)
                                .underline()
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
        .presentationBackground(Theme.background)
        .task {
            if subscriptions.products.isEmpty {
                await subscriptions.loadProducts()
            }
            if selectedProductID == nil {
                selectedProductID = annual?.id ?? monthly?.id
            }
        }
        .onChange(of: subscriptions.isSubscribed) { _, subscribed in
            if subscribed { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(Theme.accent)
            Text(trigger.headline)
                .font(Theme.Font.serif(26, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(trigger.message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow("infinity", "Unlimited saves in your Library")
            featureRow("books.vertical.fill", "The full quote archive, searchable and unlimited")
            featureRow("apps.iphone", "Home screen widget with today's quote")
            featureRow("square.and.arrow.up", "Shareable, styled quote cards")
            featureRow("flame.fill", "A monthly streak freeze")
            featureRow("paintpalette.fill", "Curated colour themes")
            featureRow("bell.badge.fill", "A second daily reminder")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private func featureRow(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }

    private var pricingOptions: some View {
        VStack(spacing: 12) {
            if let annual {
                pricingRow(
                    product: annual,
                    periodLabel: "per year",
                    badge: annualSavingsPercent.map { "Save \($0)%" }
                )
            }
            if let monthly {
                pricingRow(product: monthly, periodLabel: "per month", badge: nil)
            }
        }
    }

    private func pricingRow(product: Product, periodLabel: String, badge: String?) -> some View {
        let isSelected = selectedProductID == product.id
        return Button {
            selectedProductID = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName.isEmpty ? product.displayPrice : product.displayName)
                            .font(Theme.Font.serif(17, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .trackedCaps(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.accent))
                                .foregroundStyle(Theme.background)
                        }
                    }
                    Text("\(product.displayPrice) \(periodLabel)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Theme.divider, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var subscribeButton: some View {
        Button {
            guard let selectedProduct else { return }
            isPurchasing = true
            Task {
                await subscriptions.purchase(selectedProduct)
                isPurchasing = false
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView().tint(Theme.background)
                } else {
                    Text("Subscribe")
                        .font(.subheadline.weight(.bold))
                        .trackedCaps(1.5)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(Theme.accent))
            .foregroundStyle(Theme.background)
        }
        .disabled(selectedProduct == nil || isPurchasing)
        .opacity(selectedProduct == nil ? 0.5 : 1)
    }

    private var restoreButton: some View {
        Button {
            Task { await subscriptions.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview {
    PaywallView(trigger: .saveLimit)
        .environmentObject(SubscriptionManager())
}
