import Foundation

/// Shell open/closed state machine. Feature state stays separate from this.
enum ShellState: Equatable {
    case closed
    case opening
    case open
    case closing

    var isExpanded: Bool { self == .open || self == .opening }
}
