import Foundation

import IOKit
import IOKit.pwr_mgt

class PowerManager {

    var assertionID: IOPMAssertionID = 0

    func disableSleep(reason: String) {
        let reasonForActivity = reason as CFString
        IOPMAssertionCreateWithName( kIOPMAssertionTypeNoDisplaySleep as CFString,
                                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                    reasonForActivity,
                                                    &assertionID )
    }
    
    func enableSleep() {
        IOPMAssertionRelease(assertionID)
    }
}
