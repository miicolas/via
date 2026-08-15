import Foundation
@preconcurrency import MetricKit

/// Keeps MetricKit subscribed for the lifetime of the app without exporting
/// raw reports or user-derived values to Via's logs.
final class ViaMetricsSubscriber: NSObject, MXMetricManagerSubscriber {
    private let logger: ViaLogger

    init(logger: ViaLogger) {
        self.logger = logger
        super.init()
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        logger.metricReportsReceived(count: payloads.count)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        logger.diagnosticReportsReceived(count: payloads.count)
    }
}
