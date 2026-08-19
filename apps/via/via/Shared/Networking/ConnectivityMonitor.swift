import Network

@MainActor
protocol ConnectivityMonitoring: AnyObject {
    var isConnected: Bool { get }
    var onChange: (@MainActor (Bool) -> Void)? { get set }
    func start()
}

@MainActor
final class NetworkConnectivityMonitor: ConnectivityMonitoring {
    private(set) var isConnected = true
    var onChange: (@MainActor (Bool) -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.via.connectivity")
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.publish(isConnected)
            }
        }
        monitor.start(queue: queue)
    }

    private func publish(_ newValue: Bool) {
        guard isConnected != newValue else { return }
        isConnected = newValue
        onChange?(newValue)
    }
}

@MainActor
final class InMemoryConnectivityMonitor: ConnectivityMonitoring {
    private(set) var isConnected: Bool
    var onChange: (@MainActor (Bool) -> Void)?

    init(isConnected: Bool = true) {
        self.isConnected = isConnected
    }

    func start() {}

    func update(isConnected: Bool) {
        self.isConnected = isConnected
        onChange?(isConnected)
    }
}
