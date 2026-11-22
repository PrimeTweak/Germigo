import CoreMotion
import Observation

/// How far the phone leans sideways, from -1 (left edge down) to 1 (right edge down), smoothed.
/// It reads the motion sensors only between start and stop; nothing is stored or sent.
@MainActor
@Observable
final class TiltSensor {
    static let shared = TiltSensor()

    private(set) var lean = 0.0
    @ObservationIgnored private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let sideways = motion?.gravity.x else { return }
            MainActor.assumeIsolated {
                self?.follow(sideways)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        lean = 0
    }

    /// Eases toward the new reading so the mascot sways instead of jittering.
    private func follow(_ sideways: Double) {
        lean += (max(-1, min(1, sideways)) - lean) * 0.2
    }
}
