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

func shell(_ launchPath: String) throws {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: launchPath)

    try task.run()
}
