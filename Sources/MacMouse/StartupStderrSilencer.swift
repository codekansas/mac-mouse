import Darwin
import Foundation

@MainActor
enum StartupStderrSilencer {
    private static var savedStderrFileDescriptor: Int32 = -1
    private static var nullFileDescriptor: Int32 = -1
    private static var isActive = false

    static func activateIfNeeded() {
        guard shouldSilence, !isActive else {
            return
        }

        fflush(stderr)
        let savedDescriptor = dup(STDERR_FILENO)
        let nullDescriptor = open("/dev/null", O_WRONLY)
        guard savedDescriptor != -1, nullDescriptor != -1 else {
            if savedDescriptor != -1 {
                close(savedDescriptor)
            }
            if nullDescriptor != -1 {
                close(nullDescriptor)
            }
            return
        }

        savedStderrFileDescriptor = savedDescriptor
        nullFileDescriptor = nullDescriptor
        dup2(nullFileDescriptor, STDERR_FILENO)
        isActive = true
    }

    static func restoreIfNeeded() {
        guard isActive else {
            return
        }

        fflush(stderr)
        dup2(savedStderrFileDescriptor, STDERR_FILENO)
        close(savedStderrFileDescriptor)
        close(nullFileDescriptor)
        savedStderrFileDescriptor = -1
        nullFileDescriptor = -1
        isActive = false
    }

    private static var shouldSilence: Bool {
        Bundle.main.bundleURL.pathExtension.caseInsensitiveCompare("app") != .orderedSame
    }
}
