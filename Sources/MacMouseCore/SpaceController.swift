import AppKit
import CoreGraphics
import Darwin
import Foundation

@MainActor
final class SpaceController {
    private typealias CGSConnectionID = UInt32
    private typealias CGSSpaceID = UInt64
    private typealias CGError = Int32
    private typealias CGSMainConnectionIDFn = @convention(c) () -> CGSConnectionID
    private typealias CGSCopyManagedDisplaySpacesFn = @convention(c) (CGSConnectionID) -> Unmanaged<CFArray>
    private typealias CGSManagedDisplaySetCurrentSpaceFn = @convention(c) (CGSConnectionID, CFString, CGSSpaceID) -> CGError

    private struct ManagedSpace {
        let id: CGSSpaceID
        let type: Int

        var isDesktop: Bool {
            type == 0
        }
    }

    private struct ManagedDisplay {
        let identifier: String
        let currentSpaceID: CGSSpaceID
        let orderedSpaces: [ManagedSpace]
    }

    private struct Symbols {
        let handle: UnsafeMutableRawPointer
        let mainConnectionID: CGSMainConnectionIDFn
        let copyManagedDisplaySpaces: CGSCopyManagedDisplaySpacesFn
        let setCurrentSpace: CGSManagedDisplaySetCurrentSpaceFn
    }

    static let shared = SpaceController()

    private let symbols: Symbols?

    private init() {
        guard
            let handle = dlopen(
                "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
                RTLD_NOW
            ),
            let mainConnectionSymbol = dlsym(handle, "CGSMainConnectionID"),
            let copySpacesSymbol = dlsym(handle, "CGSCopyManagedDisplaySpaces"),
            let setCurrentSpaceSymbol = dlsym(handle, "CGSManagedDisplaySetCurrentSpace")
        else {
            symbols = nil
            return
        }

        symbols = Symbols(
            handle: handle,
            mainConnectionID: unsafeBitCast(mainConnectionSymbol, to: CGSMainConnectionIDFn.self),
            copyManagedDisplaySpaces: unsafeBitCast(copySpacesSymbol, to: CGSCopyManagedDisplaySpacesFn.self),
            setCurrentSpace: unsafeBitCast(setCurrentSpaceSymbol, to: CGSManagedDisplaySetCurrentSpaceFn.self)
        )
    }

    func moveSpace(offset: Int) -> Bool {
        guard
            offset == -1 || offset == 1,
            let symbols,
            let displayID = displayIDUnderPointer(),
            let displayIdentifier = displayIdentifier(for: displayID)
        else {
            return false
        }

        let connectionID = symbols.mainConnectionID()
        guard
            let managedDisplay = managedDisplay(
                withIdentifier: displayIdentifier,
                connectionID: connectionID,
                copyManagedDisplaySpaces: symbols.copyManagedDisplaySpaces
            ),
            let targetSpaceID = targetDesktopSpaceID(
                for: managedDisplay,
                offset: offset
            ),
            targetSpaceID != managedDisplay.currentSpaceID
        else {
            return false
        }

        let result = symbols.setCurrentSpace(
            connectionID,
            managedDisplay.identifier as CFString,
            targetSpaceID
        )
        return result == 0
    }

    private func targetDesktopSpaceID(
        for managedDisplay: ManagedDisplay,
        offset: Int
    ) -> CGSSpaceID? {
        let desktopSpaces = managedDisplay.orderedSpaces.filter(\.isDesktop)
        guard !desktopSpaces.isEmpty else {
            return nil
        }

        if let currentDesktopIndex = desktopSpaces.firstIndex(where: { space in
            space.id == managedDisplay.currentSpaceID
        }) {
            let targetIndex = currentDesktopIndex + offset
            guard desktopSpaces.indices.contains(targetIndex) else {
                return nil
            }

            return desktopSpaces[targetIndex].id
        }

        guard let currentOrderedIndex = managedDisplay.orderedSpaces.firstIndex(where: { space in
            space.id == managedDisplay.currentSpaceID
        }) else {
            return nil
        }

        var candidateIndex = currentOrderedIndex + offset
        while managedDisplay.orderedSpaces.indices.contains(candidateIndex) {
            let candidate = managedDisplay.orderedSpaces[candidateIndex]
            if candidate.isDesktop {
                return candidate.id
            }
            candidateIndex += offset
        }

        return nil
    }

    private func managedDisplay(
        withIdentifier identifier: String,
        connectionID: CGSConnectionID,
        copyManagedDisplaySpaces: CGSCopyManagedDisplaySpacesFn
    ) -> ManagedDisplay? {
        let rawDisplays = copyManagedDisplaySpaces(connectionID).takeRetainedValue() as NSArray

        for rawDisplay in rawDisplays {
            guard
                let display = rawDisplay as? NSDictionary,
                let candidateIdentifier = display["Display Identifier"] as? String,
                candidateIdentifier == identifier,
                let currentSpace = display["Current Space"] as? NSDictionary,
                let currentSpaceID = numericSpaceID(from: currentSpace),
                let rawSpaces = display["Spaces"] as? [NSDictionary]
            else {
                continue
            }

            let orderedSpaces = rawSpaces.compactMap(managedSpace(from:))
            return ManagedDisplay(
                identifier: candidateIdentifier,
                currentSpaceID: currentSpaceID,
                orderedSpaces: orderedSpaces
            )
        }

        return nil
    }

    private func managedSpace(from dictionary: NSDictionary) -> ManagedSpace? {
        guard let id = numericSpaceID(from: dictionary) else {
            return nil
        }

        let type = (dictionary["type"] as? NSNumber)?.intValue ?? 0
        return ManagedSpace(id: id, type: type)
    }

    private func numericSpaceID(from dictionary: NSDictionary) -> CGSSpaceID? {
        if let number = dictionary["ManagedSpaceID"] as? NSNumber {
            return number.uint64Value
        }

        if let number = dictionary["id64"] as? NSNumber {
            return number.uint64Value
        }

        return nil
    }

    private func displayIDUnderPointer() -> CGDirectDisplayID? {
        let pointerLocation = CGEvent(source: nil)?.location ?? .zero
        var displayID: CGDirectDisplayID = 0
        var displayCount: UInt32 = 0
        let result = withUnsafeMutablePointer(to: &displayID) { displayIDPtr in
            withUnsafeMutablePointer(to: &displayCount) { displayCountPtr in
                CGGetDisplaysWithPoint(pointerLocation, 1, displayIDPtr, displayCountPtr)
            }
        }

        guard result == .success, displayCount > 0 else {
            return nil
        }

        return displayID
    }

    private func displayIdentifier(for displayID: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return nil
        }

        return (CFUUIDCreateString(kCFAllocatorDefault, uuid) as String).uppercased()
    }
}
