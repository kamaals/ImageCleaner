# App Review Response — PhotoPrune

Rejection type: **Guideline 2.1 — request for additional information** (metadata, not a binary bug).
Action: paste the **App Review Information → Notes** block below into App Store Connect, attach a
screen recording, and resubmit. Reply to the Resolution Center message pointing to the updated Notes.

---

## 1. App Review Information → Notes (copy-paste this)

```
APP PURPOSE & TARGET AUDIENCE
PhotoPrune helps people reclaim storage on their iPhone by finding and removing
clutter in their photo library: exact/near-duplicate photos, blank or near-blank
images, and screenshots. It solves the problem of a photo library bloated with
redundant images that are tedious to clean up by hand. Target audience: everyday
iPhone users who run low on storage and want a fast, private way to tidy their
Camera Roll. All photo analysis runs ON-DEVICE; photos never leave the phone.

NO ACCOUNT REQUIRED
There is no login, registration, or user account of any kind. No demo credentials
are needed. The app works immediately after granting Photo Library access.

HOW TO SET UP & ACCESS MAIN FEATURES
1. Launch the app. On first launch it presents a Photo Library access screen.
2. Tap to continue and, at the iOS system prompt, choose "Allow Full Access"
   (Full Access is needed to scan the whole library and to delete selected items).
3. The app scans the library on-device and opens the Results screen with three
   categories: Duplicates, Blank Photos, and Screenshots.
4. Open any category to review items in a grid, select the ones to remove, and tap
   delete. Deletion uses the standard iOS confirmation (items go to "Recently
   Deleted" in Photos and can be recovered there).
5. Selecting items to delete beyond the free allowance presents the subscription
   paywall (see below). Reviewing/scanning is free.

PAID FEATURES / SUBSCRIPTION FLOW
PhotoPrune offers an auto-renewable subscription ("PhotoPrune Pro") that unlocks
unlimited deletions:
  - Monthly: 2.99 USD / month
  - Yearly:  19.99 USD / year
The paywall shows each plan's title, length, and price, with a Restore Purchases
option and links to the Terms of Use (EULA) and Privacy Policy. Purchases are
processed by Apple via StoreKit (subscription management handled through
RevenueCat). To reach it: tap delete on selected photos past the free limit, or
open Settings → Upgrade.

PERMISSIONS REQUESTED
  - Photo Library (NSPhotoLibraryUsageDescription): required to scan for
    duplicates/blanks/screenshots and to delete the items the user selects.
That is the only sensitive-data permission. No camera, location, contacts,
microphone, tracking (ATT), or notifications are requested.

EXTERNAL SERVICES / SDKs
  - Apple StoreKit — in-app purchase / subscription processing.
  - RevenueCat — subscription state management (wraps StoreKit). No personal data
    or photos are sent; it manages purchase entitlements only.
  - No analytics, no advertising SDK, no AI service, no third-party data provider.
    All image analysis (duplicate/blank/screenshot detection) is performed locally
    on the device.

REGIONAL DIFFERENCES
The app's features and content are identical in every region. The only regional
variation is subscription price, which is localized automatically by the App Store.
There is no geo-gated content or region-specific behavior.

REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. PhotoPrune is a personal utility. It does not operate in a
regulated industry and does not include or distribute protected third-party
material. It only acts on the user's own photos, on-device.

DEVICES & OS TESTED   <-- EDIT THIS LIST to match what YOU actually tested on
  - iPhone <model>, iOS <version>   (must include at least one PHYSICAL device)
  - iPhone <model>, iOS <version>
```

> Replace the **DEVICES & OS TESTED** lines with the real physical devices/OS you tested on.
> Apple reviews on physical hardware and explicitly asks for this list — do not leave placeholders,
> and make sure at least one is a real device running the current iOS (not just the Simulator).

---

## 2. Screen recording (you must capture this on a PHYSICAL device)

Record on a real iPhone running the latest iOS, screen recording on, and **start from a
cold launch**. Follow this shot list so it covers every flow Apple named:

1. Launch the app from the Home Screen (show the icon tap + launch).
2. Show the Photo Library permission screen → tap continue → **show the iOS system
   permission prompt** → choose "Allow Full Access". (This satisfies "any prompts
   requesting access to sensitive data.")
3. Let the scan run; show the Results screen with the three categories.
4. Open a category (e.g. Duplicates), select a few photos.
5. Trigger the **paywall**: attempt a delete past the free limit (or Settings → Upgrade).
   Show the plans, prices, Restore button, and the Terms/Privacy links. You do NOT
   have to complete a purchase, but showing the full paywall is required.
6. Dismiss the paywall, then demonstrate a real deletion within the free allowance and
   show the confirmation.

Keep it ~30–90 seconds. No account/login/account-deletion flows exist, so none are needed.
Upload it in App Review Information (attachment) or host it and link it in the Notes.

---

## 3. Paywall Guideline 3.1.2 fix — DONE ✅

`PaywallView` now displays, below the Restore button:
  - Subscription title + length + price per plan ✅
  - Auto-renew disclosure: "Subscription automatically renews unless canceled at least 24 hours
    before the end of the current period. Manage or cancel anytime in your App Store account settings." ✅
  - Tappable **Terms of Use** → https://photoprune.darkmatter.it.com/eula (verified HTTP 200) ✅
  - Tappable **Privacy Policy** → https://photoprune.darkmatter.it.com/privacy-policy (verified HTTP 200) ✅

Still confirm in App Store Connect that the same Privacy Policy URL is set under App Information,
and that the subscription group localization lists title/duration/price.
