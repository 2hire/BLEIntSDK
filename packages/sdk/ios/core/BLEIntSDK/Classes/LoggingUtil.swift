import Foundation
import Logging

internal class LoggingUtil {
    static let logger = Logging.Logger(label: Bundle.main.bundleIdentifier ?? "BundleIdentifier not set")
}
