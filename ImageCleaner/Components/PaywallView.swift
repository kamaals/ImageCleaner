import SwiftUI
import RevenueCat

/// Custom-coded paywall matching the PhotoPrune Figma design. Replaces the
/// dashboard-rendered `RevenueCatUI.PaywallView` so the layout, copy, plan-card
/// geometry and CTA treatment are owned by the app rather than the RevenueCat
/// dashboard.
///
/// Pricing, package availability and entitlement state still come from the
/// RevenueCat SDK — only the *presentation* is local. To wire this up:
///
/// 1. In the RevenueCat dashboard, ensure the current Offering contains a
///    `$rc_monthly` and an `$rc_annual` package (the standard identifiers).
///    The convenience accessors `offering.monthly` / `offering.annual` rely
///    on those exact IDs; if you used custom IDs, swap to
///    `offering.package(identifier:)`.
/// 2. Each package's `storeProduct` must map to a live product in App Store
///    Connect — `localizedPriceString` is what gets rendered on the cards.
/// 3. The entitlement attached to those packages must match
///    `EntitlementStore.entitlementID` ("PhotoPrune Pro").
struct AppPaywallView: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss

    @State private var offering: Offering?
    @State private var loadState: LoadState = .loading
    @State private var selectedPlan: Plan = .yearly
    @State private var isPurchasing = false
    @State private var errorAlert: PurchaseErrorAlert?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            content
        }
        .task { await loadOffering() }
        .alert(item: $errorAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView().tint(.black)
        case .failed(let reason):
            failureView(reason: reason)
        case .loaded:
            paywallScroll
        }
    }

    // MARK: - Scroll body

    private var paywallScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 36)
                premiumAccessLabel
                    .padding(.bottom, 8)
                heroTitle
                    .padding(.bottom, 32)
                featureList
                    .padding(.bottom, 24)
                Rectangle()
                    .fill(Color(red: 0.89, green: 0.89, blue: 0.89))
                    .frame(height: 0.5)
                    .padding(.bottom, 32)
                plansRow
                    .padding(.bottom, 36)
                ctaSection
                    .padding(.bottom, 20)
                restoreButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header (stair-step logo + wordmark)

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            stairLogo
            Text("Photo\nPrune")
                .font(AppFont.jost(size: 19, weight: 400))
                .foregroundStyle(Color(red: 0.17, green: 0.17, blue: 0.17))
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
    }

    /// Two squares — gray on top-left, black offset down-right by the square
    /// edge — forming the staircase mark from the Figma. Bounding box is the
    /// union of the two squares so siblings align off the *visual* top-left.
    private var stairLogo: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(red: 0.76, green: 0.76, blue: 0.76))
                .frame(width: 32, height: 32)
            Rectangle()
                .fill(Color.black)
                .frame(width: 32, height: 32)
                .offset(x: 18, y: 18)
        }
        .frame(width: 50, height: 50, alignment: .topLeading)
    }

    // MARK: - Hero copy

    private var premiumAccessLabel: some View {
        Text("PREMIUM ACCESS")
            .font(AppFont.jost(size: 16, weight: 500))
            .tracking(1.5)
            .foregroundStyle(Color(red: 0.54, green: 0.54, blue: 0.54))
    }

    private var heroTitle: some View {
        Text("CLEAN\nYOUR\nLIBRARY")
            .font(AppFont.jost(size: 52, weight: 900))
            .foregroundStyle(Color(red: 0.06, green: 0.06, blue: 0.06))
            .lineSpacing(-6)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.7)
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Self.features, id: \.self) { text in
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Rectangle()
                            .stroke(Color.black, lineWidth: 0.5)
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.black)
                    }
                    Text(text)
                        .font(AppFont.jost(size: 19, weight: 300))
                        .foregroundStyle(.black)
                }
            }
        }
    }

    private static let features: [String] = [
        "Scan your entire photo library",
        "Find & remove duplicate photos",
        "Detect & clear screenshots",
        "Remove blank & dark photos",
        "Unlimited scans, forever",
    ]

    // MARK: - Plan cards

    private var plansRow: some View {
        HStack(spacing: 12) {
            planCard(.monthly)
            planCard(.yearly)
        }
    }

    private func planCard(_ plan: Plan) -> some View {
        let isSelected = selectedPlan == plan
        let isBestValue = plan == .yearly
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedPlan = plan
            }
        } label: {
            ZStack(alignment: .top) {
                planCardBody(plan, isSelected: isSelected)
                if isBestValue {
                    bestValueBadge
                        .offset(y: -13)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(plan.headerLabel) plan, \(priceText(for: plan))"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var bestValueBadge: some View {
        Text("BEST VALUE")
            .font(AppFont.jost(size: 13, weight: 600))
            .tracking(1)
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 0.5))
    }

    private func planCardBody(_ plan: Plan, isSelected: Bool) -> some View {
        let mutedOnSelected = Color(red: 0.78, green: 0.78, blue: 0.78)
        let mutedOnPlain = Color(red: 0.54, green: 0.54, blue: 0.54)
        let mutedFooter = isSelected ? mutedOnSelected : mutedOnPlain

        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 18)
            Text(plan.headerLabel)
                .font(AppFont.jost(size: 15, weight: 500))
                .tracking(1)
                .foregroundStyle(mutedFooter)
            Spacer().frame(height: 10)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(priceText(for: plan))
                    .font(AppFont.jost(size: 30, weight: 900))
                    .foregroundStyle(isSelected ? .white : .black)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !plan.priceSuffix.isEmpty {
                    Text(plan.priceSuffix)
                        .font(AppFont.jost(size: 14, weight: 400))
                        .foregroundStyle(mutedFooter)
                }
            }
            Spacer().frame(height: 14)
            Text(plan.footnote)
                .font(AppFont.jost(size: 13, weight: 500))
                .foregroundStyle(mutedFooter)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .background(isSelected ? Color.black : Color.white)
        .overlay(
            Rectangle().stroke(
                isSelected ? Color.black : Color(red: 0.86, green: 0.86, blue: 0.86),
                lineWidth: 0.5
            )
        )
    }

    private func priceText(for plan: Plan) -> String {
        guard let package = package(for: plan) else { return "—" }
        return package.storeProduct.localizedPriceString
    }

    // MARK: - CTA (offset black drop-shadow + white button face)

    private var ctaSection: some View {
        ZStack(alignment: .topLeading) {
            // Drop-shadow rectangle, nudged down-right of the face.
            Rectangle()
                .fill(Color.black)
                .frame(height: 52)
                .offset(x: 6, y: 8)

            Button(action: purchaseSelected) {
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 0.5))
                    if isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        Text("START \(selectedPlan.ctaSuffix)")
                            .font(AppFont.jost(size: 16, weight: 500))
                            .tracking(2)
                            .foregroundStyle(.black)
                    }
                }
                .frame(height: 52)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || package(for: selectedPlan) == nil)
            .opacity(package(for: selectedPlan) == nil ? 0.4 : 1)
        }
        .padding(.trailing, 6)
        .padding(.bottom, 8)
    }

    private var restoreButton: some View {
        HStack {
            Spacer()
            Button {
                Task { await restore() }
            } label: {
                Text("Restore Purchases")
                    .font(AppFont.jost(size: 16, weight: 500))
                    .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.41))
                    .underline()
            }
            .disabled(isPurchasing)
            Spacer()
        }
    }

    // MARK: - Load / error views

    private func failureView(reason: String) -> some View {
        VStack(spacing: 16) {
            Text("Couldn't load subscription options")
                .font(AppFont.jost(size: 17, weight: 500))
                .multilineTextAlignment(.center)
            Text(reason)
                .font(AppFont.jost(size: 14, weight: 400))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await loadOffering() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
        }
        .padding(32)
    }

    // MARK: - Package lookup

    private func package(for plan: Plan) -> Package? {
        switch plan {
        case .monthly: return offering?.monthly
        case .yearly: return offering?.annual
        }
    }

    // MARK: - Actions

    private func loadOffering() async {
        loadState = .loading
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                offering = current
                loadState = .loaded
            } else {
                loadState = .failed("No current offering configured in RevenueCat.")
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func purchaseSelected() {
        guard let package = package(for: selectedPlan) else { return }
        isPurchasing = true
        Task {
            do {
                let result = try await Purchases.shared.purchase(package: package)
                isPurchasing = false
                guard !result.userCancelled else { return }
                let unlocked = result.customerInfo.entitlements[EntitlementStore.entitlementID]?.isActive == true
                guard unlocked else {
                    errorAlert = handlePurchaseError(PaywallError.purchaseDidNotUnlockEntitlement)
                    return
                }
                entitlements.consumePendingActionIfAny()
                dismiss()
            } catch {
                isPurchasing = false
                errorAlert = handlePurchaseError(error)
            }
        }
    }

    private func restore() async {
        isPurchasing = true
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPurchasing = false
            if info.entitlements[EntitlementStore.entitlementID]?.isActive == true {
                entitlements.consumePendingActionIfAny()
                dismiss()
            } else {
                errorAlert = PurchaseErrorAlert(
                    title: "Nothing to restore",
                    message: "We didn't find an active PhotoPrune Pro purchase on this Apple ID."
                )
            }
        } catch {
            isPurchasing = false
            errorAlert = handlePurchaseError(error)
        }
    }

    /// Maps a RevenueCat / StoreKit error into the alert the user actually
    /// sees. Returns `nil` to suppress the alert entirely (used for user
    /// cancellation, which is technically an error path but not one the user
    /// needs reassurance about).
    ///
    /// Most cancellations don't reach this function — `Purchases.shared.purchase`
    /// returns `userCancelled: true` without throwing — but the SK2 path can
    /// still bubble `.purchaseCancelledError`, so we guard it here too.
    ///
    /// Error codes that aren't enumerated fall through to the generic copy
    /// using RC's `localizedDescription`. Adding a new branch is preferable to
    /// dropping users into the default whenever we identify a recoverable case.
    private func handlePurchaseError(_ error: Error) -> PurchaseErrorAlert? {
        let nsError = error as NSError
        let code = RevenueCat.ErrorCode(rawValue: nsError.code)

        switch code {
        case .purchaseCancelledError:
            // User dismissed the StoreKit sheet themselves — they know what
            // happened, an alert just gets in their way.
            return nil

        case .networkError:
            return PurchaseErrorAlert(
                title: "Connection issue",
                message: "We couldn't reach the App Store. Check your internet connection and try again."
            )

        case .paymentPendingError:
            return PurchaseErrorAlert(
                title: "Payment pending",
                message: "Your payment is awaiting approval (e.g. Ask to Buy). PhotoPrune Pro will unlock automatically once it clears."
            )

        case .productNotAvailableForPurchaseError:
            return PurchaseErrorAlert(
                title: "Not available",
                message: "This subscription isn't available in your region right now. Please try again later."
            )

        case .purchaseNotAllowedError:
            return PurchaseErrorAlert(
                title: "Purchases disabled",
                message: "In-app purchases are restricted on this device. Check Settings → Screen Time → Content & Privacy Restrictions → iTunes & App Store Purchases."
            )

        case .productAlreadyPurchasedError:
            return PurchaseErrorAlert(
                title: "Already purchased",
                message: "You already own PhotoPrune Pro on this Apple ID. Tap Restore Purchases to unlock it on this device."
            )

        case .receiptAlreadyInUseError:
            return PurchaseErrorAlert(
                title: "Different Apple ID",
                message: "This purchase is linked to a different Apple ID. Sign in with that account in Settings and tap Restore Purchases."
            )

        case .ineligibleError:
            return PurchaseErrorAlert(
                title: "Not eligible",
                message: "This offer isn't available on your account."
            )

        case .invalidReceiptError, .missingReceiptFileError:
            return PurchaseErrorAlert(
                title: "Receipt unavailable",
                message: "We couldn't verify your purchase receipt. Try Restore Purchases, or restart the app and try again."
            )

        case .storeProblemError:
            return PurchaseErrorAlert(
                title: "App Store unreachable",
                message: "The App Store is having trouble right now. Please try again in a moment."
            )

        default:
            return PurchaseErrorAlert(
                title: "Purchase failed",
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Types

    private enum Plan: Hashable {
        case monthly, yearly

        var headerLabel: String {
            switch self {
            case .monthly: "MONTHLY"
            case .yearly: "YEARLY"
            }
        }

        var priceSuffix: String {
            switch self {
            case .monthly: "/mo"
            case .yearly: "/yr"
            }
        }

        var footnote: String {
            switch self {
            case .monthly: "Billed monthly"
            case .yearly: "Billed yearly"
            }
        }

        var ctaSuffix: String {
            switch self {
            case .monthly: "MONTHLY"
            case .yearly: "YEARLY"
            }
        }
    }

    private enum LoadState {
        case loading
        case loaded
        case failed(String)
    }

    private enum PaywallError: LocalizedError {
        case purchaseDidNotUnlockEntitlement

        var errorDescription: String? {
            switch self {
            case .purchaseDidNotUnlockEntitlement:
                "Purchase completed but the PhotoPrune Pro entitlement isn't active yet. Try restoring purchases."
            }
        }
    }
}

/// Single source of truth for a paywall-surfaced error message. Identifiable
/// so it drives the `.alert(item:)` modifier.
struct PurchaseErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
