import Foundation
import Logging

internal class LoggingUtil {
    private static var _logger = Logging.Logger(label: Bundle.main.bundleIdentifier ?? "BundleIdentifier not set")

    static var logger: Logger {
        #if DEBUG
            Self._logger.logLevel = .debug
        #endif

        return Self._logger
    }
}
