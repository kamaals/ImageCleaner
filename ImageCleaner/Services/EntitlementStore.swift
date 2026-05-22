import Foundation
import RevenueCat
import os

/// Subscription state owner. Single source of truth for the `PhotoPrune Pro`
/// entitlement, plus the gate that delete sites call before destructive
/// actions. Purchase / restore UX is delegated to `RevenueCatUI`'s
/// `PaywallView` and `CustomerCenterView` — this store only observes the
/// resulting `CustomerInfo` and exposes whether the user is unlocked.
///
/// ## Setup
///
/// 1. Add the SPM dependency `https://github.com/RevenueCat/purchases-ios-spm`
///    and link both `RevenueCat` and `RevenueCatUI` to the app target.
/// 2. In `ImageCleanerApp.init` call
///    `Purchases.configure(withAPIKey: "…")` BEFORE creating an
///    `EntitlementStore` (this store reads `cachedCustomerInfo` synchronously
///    on init so paying users don't blink to "not subscribed" on cold launch).
/// 3. In the RevenueCat dashboard:
///    - Define an entitlement with id matching `Self.entitlementID`
///    - Create an offering with `monthly` and `lifetime` packages mapped to
///      your App Store Connect products
///    - Design a paywall under **Tools → Paywalls** and attach it to the
///      offering — `PaywallView()` pulls that layout automatically
@Observable
@MainActor
final class EntitlementStore {
    /// Entitlement identifier as configured in the RevenueCat dashboard.
    /// Must match exactly (spaces and casing included).
    static let entitlementID = "PhotoPrune Pro"

    /// `true` iff the user currently holds an active `PhotoPrune Pro`
    /// entitlement. Updated live via `Purchases.shared.customerInfoStream`.
    private(set) var isSubscribed = false

    /// Set when a delete-site has triggered the paywall via
    /// `requireEntitlement(then:)`. The app-root paywall sheet binds to this;
    /// clearing it dismisses the paywall and drops the pending action.
    var pendingPaywallAction: PendingPaywallAction?

    /// Loops `Purchases.shared.customerInfoStream` for the lifetime of the
    /// store. `[weak self]` inside the loop means the task self-terminates on
    /// next iteration once the store deallocates — and since this store lives
    /// for the entire app lifetime there's no realistic deinit to clean up.
    private var customerInfoTask: Task<Void, Never>?

    init() {
        // Apply cached state immediately so paying users don't flicker to
        // "not subscribed" while the network call resolves.
        if let cached = Purchases.shared.cachedCustomerInfo {
            apply(cached)
        }
        observeCustomerInfo()
    }

    // MARK: - Gating

    /// Runs `action` immediately if the user is entitled; otherwise stashes
    /// the closure and surfaces the paywall. The paywall consumes and fires
    /// the action on successful purchase / restore, or drops it on cancel.
    ///
    /// `beforePaywall` runs *only* on the gated path, immediately before the
    /// paywall is surfaced. Call sites triggered from inside a sheet pass
    /// their sheet's dismissal here: the app-wide paywall sheet is mounted at
    /// the app root and cannot present on top of an already-open sheet —
    /// SwiftUI silently queues it until that sheet closes. Subscribed users
    /// never reach this path.
    func requireEntitlement(
        beforePaywall: (@MainActor () -> Void)? = nil,
        then action: @MainActor @escaping () -> Void
    ) {
        if isSubscribed {
            action()
        } else {
            beforePaywall?()
            pendingPaywallAction = PendingPaywallAction(perform: action)
        }
    }

    /// Surfaces the paywall *without* gating an action. Used by discovery
    /// surfaces (e.g. Settings → "Get PhotoPrune Pro") where there's nothing
    /// queued — the user just wants to see what Pro offers. No-op for users
    /// who already hold the entitlement.
    func presentPaywall() {
        guard !isSubscribed else { return }
        pendingPaywallAction = PendingPaywallAction(perform: {})
    }

    /// Called by the paywall sheet's `onPurchaseCompleted` /
    /// `onRestoreCompleted` callbacks once entitlement is active. Fires the
    /// pending action and clears the binding (which dismisses the sheet).
    func consumePendingActionIfAny() {
        guard let action = pendingPaywallAction else { return }
        pendingPaywallAction = nil
        action.perform()
    }

    // MARK: - Customer info

    private func observeCustomerInfo() {
        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard let self else { break }
                await MainActor.run { self.apply(info) }
            }
        }
    }

    private func apply(_ info: CustomerInfo) {
        isSubscribed = info.entitlements[Self.entitlementID]?.isActive == true
    }

    private static let log = Logger(subsystem: "me.kamaal.ImageCleaner", category: "EntitlementStore")
}

/// A delete (or other destructive) action queued behind the paywall. The
/// paywall fires `perform` once the user has unlocked the entitlement.
struct PendingPaywallAction: Identifiable {
    let id = UUID()
    let perform: @MainActor () -> Void
}
