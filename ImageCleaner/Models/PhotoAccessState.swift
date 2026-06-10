import Photos

/// Semantic Photos-access state the UI binds to. Derived from
/// `PHAuthorizationStatus` so views never branch on PhotoKit enums directly.
///
/// `.limited` maps to `needsFullAccess`: PhotoPrune cleans the *whole* library,
/// and limited access only exposes the user-picked subset — useless for the job.
enum PhotoAccessState: Equatable {
    /// `.notDetermined` — never asked. Show the priming screen, then request.
    case needsPriming
    /// `.authorized` — full access. The only state in which scanning runs.
    case granted
    /// `.limited` — only user-selected photos. Prompt for full access.
    case needsFullAccess
    /// `.denied` — user said no. Recovery is via Settings only (iOS won't re-prompt).
    case denied
    /// `.restricted` — blocked by Screen Time / MDM. The user may be unable to change it.
    case restricted

    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .needsPriming
        case .authorized: self = .granted
        case .limited: self = .needsFullAccess
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .denied
        }
    }

    /// Scanning is permitted only with full access.
    var allowsScanning: Bool { self == .granted }
}
