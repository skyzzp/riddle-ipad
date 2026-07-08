import SwiftUI
import UIKit

/// Visual-spec palette (cream + warm near-black). Display-only; never transmitted.
enum Theme {
    static let pageCream   = Color(red: 0xEF/255.0, green: 0xE4/255.0, blue: 0xCE/255.0)
    static let ink         = Color(red: 0x38/255.0, green: 0x34/255.0, blue: 0x2E/255.0)
    static let leatherBase = Color(red: 0x17/255.0, green: 0x11/255.0, blue: 0x0C/255.0)
    static let leatherHi   = Color(red: 0x2A/255.0, green: 0x20/255.0, blue: 0x18/255.0)
    static let gilt        = Color(red: 0xA8/255.0, green: 0x8A/255.0, blue: 0x4C/255.0)

    static let inkUIColor    = UIColor(red: 0x38/255.0, green: 0x34/255.0, blue: 0x2E/255.0, alpha: 1)   // aged ink: warm near-black, greyed
    static let creamUIColor  = UIColor(red: 0xEF/255.0, green: 0xE4/255.0, blue: 0xCE/255.0, alpha: 1)
    static let leatherUIBase = UIColor(red: 0x17/255.0, green: 0x11/255.0, blue: 0x0C/255.0, alpha: 1)
}
