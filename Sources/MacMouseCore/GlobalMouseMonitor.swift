import CoreGraphics
import Foundation

public final class GlobalMouseMonitor {
    private let store: ButtonAssignmentStore
    private let performer: ShortcutPerforming
    private let scrollSmoother: ScrollSmoother
    private let shouldHandleEvents: (CGEventType, CGEvent) -> Bool

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public init(
        store: ButtonAssignmentStore,
        performer: ShortcutPerforming,
        scrollSmoother: ScrollSmoother = ScrollSmoother(),
        shouldHandleEvents: @escaping (CGEventType, CGEvent) -> Bool = { _, _ in true }
    ) {
        self.store = store
        self.performer = performer
        self.scrollSmoother = scrollSmoother
        self.shouldHandleEvents = shouldHandleEvents
    }

    deinit {
        stop()
    }

    @discardableResult
    public func start() -> Bool {
        guard eventTap == nil else {
            return true
        }

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<GlobalMouseMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handle(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }

        runLoopSource = nil
        eventTap = nil
    }

    private func handle(
        proxy _: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard shouldHandleEvents(type, event) else {
            return Unmanaged.passUnretained(event)
        }

        if type == .scrollWheel, scrollSmoother.consume(event) {
            return nil
        }

        guard type == .otherMouseDown || type == .otherMouseUp else {
            return Unmanaged.passUnretained(event)
        }

        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        guard button > 1, let action = store.action(for: button) else {
            return Unmanaged.passUnretained(event)
        }

        if type == .otherMouseDown {
            performer.perform(action)
        }

        return nil
    }

    private var eventMask: CGEventMask {
        mask(for: .scrollWheel)
            |
        mask(for: .otherMouseDown)
            | mask(for: .otherMouseUp)
            | mask(for: .tapDisabledByTimeout)
            | mask(for: .tapDisabledByUserInput)
    }

    private func mask(for type: CGEventType) -> CGEventMask {
        CGEventMask(1) << type.rawValue
    }
}
