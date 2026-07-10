import Foundation
import MachO

@objc(DriftMonitor)
public class DriftMonitor: NSObject {

    private var timebaseInfo = mach_timebase_info_data_t()
    private var isMonitoring = false
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.chronos.drift.monitor", qos: .userInteractive)

    public typealias DriftCallback = (Double, Double, Double) -> Void
    public var onSnapshot: DriftCallback?

    override init() {
        super.init()
        guard mach_timebase_info(&timebaseInfo) == KERN_SUCCESS else {
            fatalError("Failed to initialize Mach timebase info.")
        }
    }

    /// Starts high-frequency clock sampling.
    /// - Parameter intervalMillis: Frequency of snapshots in milliseconds.
    public func startMonitoring(intervalMillis: Double = 100.0) {
        guard !isMonitoring else { return }
        isMonitoring = true

        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: .milliseconds(Int(intervalMillis)))
        
        timer?.setEventHandler { [weak self] in
            self?.captureSnapshot()
        }
        timer?.resume()
    }

    /// Stops the sampling process.
    public func stopMonitoring() {
        timer?.cancel()
        timer = nil
        isMonitoring = false
    }

    /// Captures a high-resolution snapshot of the system clock.
    /// Calculates the delta between Wall Clock (UTC) and Monotonic Mach Time.
    private func captureSnapshot() {
        // High resolution monotonic tick count
        let machTime = mach_absolute_time()
        
        // Wall clock time (Unix timestamp)
        let unixTime = Date().timeIntervalSince1970
        
        // Convert mach ticks to nanoseconds
        let nanos = Double(machTime) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
        let machSeconds = nanos / 1000000000.0
        
        // Drift context: The divergence between System Uptime (Monotonic) 
        // and the System Wall Clock (Variable/Network Synced).
        // This value localized allows detection of NTP adjustments or thermal throttling effects.
        let driftReference = unixTime - machSeconds

        onSnapshot?(unixTime, machSeconds, driftReference)
    }

    /// Returns the current offset specifically formatted for a forensic heartbeat.
    /// This allows the visualizer to map how far the local 'tick' has moved relative 
    /// to the last known network synchronization point.
    public func getCurrentMicroDrift() -> [String: Any] {
        let machTime = mach_absolute_time()
        let unixTime = Date().timeIntervalSince1970
        let nanos = Double(machTime) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
        let machSeconds = nanos / 1000000000.0
        
        return [
            "ts": unixTime,
            "mono": machSeconds,
            "diff": unixTime - machSeconds,
            "precision": "nanoseconds"
        ]
    }
}