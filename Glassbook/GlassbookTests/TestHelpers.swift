import Foundation
@testable import Glassbook

// @testable import Glassbook pulls in transitive SwiftUI / UIKit / Combine,
// which conflict with Glassbook.Transaction (vs SwiftUI.Transaction),
// Glassbook.Category (vs UIKit.Category = OpaquePointer), and
// Glassbook.Subscription (vs Combine.Subscription protocol). Short-name
// typealiases would themselves be ambiguous, so tests use fully-qualified
// `Glassbook.Transaction` etc. directly. No helpers needed here.
