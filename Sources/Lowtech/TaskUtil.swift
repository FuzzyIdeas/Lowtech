import Combine
import Foundation

public class Repeater {
    public init(
        every interval: TimeInterval,
        times: Int = 0,
        name: String? = nil,
        maxDuration: TimeInterval? = nil,
        tolerance: TimeInterval? = nil,
        runloop: RunLoop = .main,
        onFinish: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        let name = name ?? "every \(interval) seconds for \(times) times"
        let startTime = Date()
        var counter = 0

        self.name = name
        self.onCancel = onCancel

        timer = Timer.publish(every: interval, tolerance: tolerance, on: runloop, in: .default)
        task = timer
            .autoconnect()
            .sink { [weak self] d in
                if counter == 0 {
                    debug("Starting repeater '\(name)'")
                }

                counter += 1
                if let maxDuration, startTime.distance(to: d) > maxDuration {
                    debug("Repeater finished on maxDuration '\(name)'")
                    self?.stop()
                    onFinish?()
                    return
                }
                guard times <= 0 || counter < times else {
                    debug("Repeater finished on maxRunCount '\(name)'")
                    self?.stop()
                    onFinish?()
                    return
                }
                action()
            }
    }

    deinit {
        debug("Deinit repeater '\(self.name)'")
        stop()
        onCancel?()
    }

    public func stop() {
        debug("Stopping repeater '\(self.name)'")
        stopped = true
        task?.cancel()
        timer.connect().cancel()
    }

    var task: Cancellable?
    var onCancel: (() -> Void)?
    let timer: Timer.TimerPublisher
    let name: String
    var stopped = false
}
