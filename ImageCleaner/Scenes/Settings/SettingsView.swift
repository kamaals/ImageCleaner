import SwiftUI
import RevenueCatUI

struct SettingsView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(EntitlementStore.self) private var entitlements
    @State private var isShowingCustomerCenter = false

    var body: some View {
        @Bindable var theme = theme

        Form {
            // Discovery CTA for non-subscribers. Lives at the top of Settings
            // because (a) App Store reviewers expect a surfaced upgrade path
            // outside of destructive flows, and (b) it's the highest-converting
            // location for an in-app upsell. Hidden once the entitlement is
            // active — the post-purchase "Manage Subscription" row covers them.
            if !entitlements.isSubscribed {
                Section {
                    Button {
                        entitlements.presentPaywall()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Get PhotoPrune Pro")
                                    .font(AppFont.headline)
                                    .foregroundStyle(.primary)
                                Text("Clean your entire library")
                                    .font(AppFont.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Get PhotoPrune Pro")
                    .accessibilityHint("Opens the upgrade options")
                }
            }

            Section {
                Picker("Appearance", selection: $theme.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
                    .font(AppFont.caption)
            }

            Section {
                // RC's CustomerCenter handles cancel / restore / change-plan /
                // manage-billing on a per-user basis. For non-subscribers it
                // shows a "Restore Purchases" affordance, and for subscribers
                // it surfaces tier change + cancel flows wired straight to
                // App Store subscription management.
                Button {
                    isShowingCustomerCenter = true
                } label: {
                    HStack {
                        Text(entitlements.isSubscribed ? "Manage Subscription" : "Restore Purchases")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                .accessibilityLabel(entitlements.isSubscribed ? "Manage subscription" : "Restore purchases")
            } header: {
                Text(entitlements.isSubscribed ? "PhotoPrune Pro" : "Subscription")
                    .font(AppFont.caption)
            } footer: {
                if entitlements.isSubscribed {
                    Text("Cancel, change plan, or request a refund.")
                        .font(AppFont.caption)
                }
            }
        }
        .navigationTitle("Settings")
        .arrowBackButton()
        .sheet(isPresented: $isShowingCustomerCenter) {
            CustomerCenterView()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppTheme())
    .environment(EntitlementStore())
}
