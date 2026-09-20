import AppKit
import Combine
import EventKit
import Foundation

public struct UpcomingCalendarEvent: Sendable, Equatable {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    
    public var formattedTime: String {
        if isAllDay {
            return "All Day"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
    
    public var displayText: String {
        "\(title) · \(formattedTime)"
    }
}

@MainActor
public final class CalendarService: ObservableObject {
    public static let shared = CalendarService()
    
    @Published public private(set) var nextEvent: UpcomingCalendarEvent?
    @Published public private(set) var hasPermission: Bool = false
    @Published public private(set) var weekEvents: [String: [UpcomingCalendarEvent]] = [:]
    
    private var eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    
    public static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private init() {
        checkPermissionAndFetch()
        
        // Listen for Calendar updates
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchUpcomingEvents()
            }
            .store(in: &cancellables)

        // Periodic refresh every 60 seconds — also re-evaluates permission so the
        // widget self-heals if the user grants access in System Settings while the
        // app is running (an accessory app rarely fires didBecomeActive).
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPermissionAndFetch()
            }
            .store(in: &cancellables)

        // Automatically re-check when user returns to LazyNotch from System Settings
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkPermissionAndFetch()
            }
            .store(in: &cancellables)
    }

    public func events(for date: Date) -> [UpcomingCalendarEvent] {
        let key = Self.dayKey(for: date)
        if let cached = weekEvents[key] {
            return cached
        }
        guard hasPermission else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: date) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let found = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                UpcomingCalendarEvent(
                    title: $0.title ?? "Event",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay
                )
            }
        weekEvents[key] = found
        return found
    }

    public func openCalendarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func requestAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        NSLog("[LazyNotch Calendar] requestAccess called with status: %ld", status.rawValue)
        if #available(macOS 14.0, *) {
            if status == .fullAccess {
                hasPermission = true
                fetchUpcomingEvents()
                return
            }
        } else {
            if status == .authorized {
                hasPermission = true
                fetchUpcomingEvents()
                return
            }
        }

        if status == .denied || status == .restricted {
            openCalendarSettings()
            return
        }

        // Detect a TCC "silent denial" (no prompt shown, instant NO). When that
        // happens the user needs System Settings — TCC will never prompt again.
        let requestStartedAt = Date()
        let handleResult: @MainActor (Bool, Error?) -> Void = { [weak self] granted, error in
            guard let self else { return }
            if let error {
                NSLog("[LazyNotch Calendar] access request error: \(error.localizedDescription)")
            }
            self.hasPermission = granted
            let wasInstant = Date().timeIntervalSince(requestStartedAt) < 0.5
            if granted {
                self.fetchUpcomingEvents()
            } else if wasInstant {
                // Denied without prompting (stale TCC state): send the user to
                // System Settings so they can flip the switch manually.
                NSLog("[LazyNotch Calendar] request denied instantly (no prompt shown); opening Calendar settings")
                self.openCalendarSettings()
            }
            // If a prompt WAS shown and the user declined, do nothing — the
            // widget keeps its "Connect Calendar Access" button.
        }

        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                Task { @MainActor in
                    handleResult(granted, error)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                Task { @MainActor in
                    handleResult(granted, error)
                }
            }
        }
    }

    public func checkPermissionAndFetch() {
        self.eventStore = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        NSLog("[LazyNotch Calendar] Current authorization status: %ld (3=authorized/fullAccess)", status.rawValue)

        let isAuthorized: Bool
        if #available(macOS 14.0, *) {
            isAuthorized = (status == .fullAccess || status.rawValue == 3)
        } else {
            isAuthorized = (status == .authorized || status.rawValue == 3)
        }

        if isAuthorized {
            hasPermission = true
            fetchUpcomingEvents()
        } else if status == .notDetermined {
            // NEVER auto-prompt: requests must come only from the explicit
            // "Connect Calendar Access" button in the calendar widget. Auto-prompting
            // here made the system permission dialog (and System Settings) pop open
            // whenever the app merely became active.
            hasPermission = false
        } else {
            // Test if events can actually be fetched (in case TCC granted without updating status cache)
            let cal = Calendar.current
            let today = Date()
            let predicate = eventStore.predicateForEvents(withStart: cal.startOfDay(for: today), end: today, calendars: nil)
            let testEvents = eventStore.events(matching: predicate)
            if !testEvents.isEmpty {
                hasPermission = true
                fetchUpcomingEvents()
            } else {
                hasPermission = false
            }
        }
    }
    
    public func fetchUpcomingEvents() {
        guard hasPermission else { return }
        
        let cal = Calendar.current
        let today = Date()
        guard let startDate = cal.date(byAdding: .day, value: -4, to: cal.startOfDay(for: today)),
              let endDate = cal.date(bySettingHour: 23, minute: 59, second: 59, of: cal.date(byAdding: .day, value: 4, to: today) ?? today) else {
            return
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        var grouped: [String: [UpcomingCalendarEvent]] = [:]
        for event in ekEvents {
            let key = Self.dayKey(for: event.startDate)
            let item = UpcomingCalendarEvent(
                title: event.title ?? "Event",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay
            )
            grouped[key, default: []].append(item)
        }
        self.weekEvents = grouped
        
        let todayKey = Self.dayKey(for: today)
        let todayEvents = grouped[todayKey] ?? []
        self.nextEvent = todayEvents.first(where: { $0.endDate >= today }) ?? todayEvents.first
    }
}
