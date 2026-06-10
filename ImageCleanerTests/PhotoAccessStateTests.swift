import Testing
import Photos
@testable import ImageCleaner

struct PhotoAccessStateTests {
    @Test
    func mapsEveryAuthorizationStatus() {
        #expect(PhotoAccessState(.notDetermined) == .needsPriming)
        #expect(PhotoAccessState(.authorized) == .granted)
        #expect(PhotoAccessState(.limited) == .needsFullAccess)
        #expect(PhotoAccessState(.denied) == .denied)
        #expect(PhotoAccessState(.restricted) == .restricted)
    }

    @Test
    func onlyGrantedAllowsScanning() {
        #expect(PhotoAccessState.granted.allowsScanning == true)
        #expect(PhotoAccessState.needsPriming.allowsScanning == false)
        #expect(PhotoAccessState.needsFullAccess.allowsScanning == false)
        #expect(PhotoAccessState.denied.allowsScanning == false)
        #expect(PhotoAccessState.restricted.allowsScanning == false)
    }
}
