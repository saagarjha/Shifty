//
//  NightShiftManager.swift
//  Shifty
//
//  Created by Saagar Jha on 1/13/18.
//

import Foundation

extension Time: Equatable {
    init?(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour,
            let minute = components.minute else {
                return nil
        }
        self.hour = Int32(hour)
        self.minute = Int32(minute)
    }
    
    public static func ==(lhs: Time, rhs: Time) -> Bool {
        return lhs.hour == rhs.hour && lhs.minute == rhs.minute
    }
}

extension Date {
    init?(_ time: Time) {
        var components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        components.hour = Int(time.hour)
        components.minute = Int(time.minute)
        if let date = Calendar.current.date(from: components) {
            self = date
        } else {
            return nil
        }
    }
}

enum NightShiftEvent {
    case enteredScheduledNightShift
    case exitedScheduledNightShift
    case userEnabledNightShift
    case userDisabledNightShift
    case nightShiftDisableTimerStarted
    case nightShiftDisableTimerEnded
    case nightShiftDisableRuleActivated
    case nightShiftDisableRuleDeactivated
}

enum ScheduleType: Equatable {
    case off
    case solar
    case custom(start: Time, end: Time)
    
    static func ==(lhs: ScheduleType, rhs: ScheduleType) -> Bool {
        switch (lhs, rhs) {
        case (.off, .off), (.solar, .solar):
            return true
        case (let .custom(leftStart, leftEnd), let custom(rightStart, rightEnd)):
            return leftStart == rightStart && leftEnd == rightEnd
        default:
            return false
        }
    }
}

enum NightShiftManager {
    private static let client = CBBlueLightClient()

    static var isCurrentlyInNightShiftSchedule: Bool = false
    static var nightShiftDisableTimer: Timer?

    private static var blueLightStatus: Status {
        var status: Status = Status()
        client.getBlueLightStatus(&status)
        return status
    }

    static var blueLightReductionAmount: Float {
        get {
            var strength: Float = 0
            client.getStrength(&strength)
            return strength
        }
        set {
            client.setStrength(newValue, commit: true)
        }
    }

    static var isNightShiftEnabled: Bool {
        get {
            return blueLightStatus.enabled.boolValue
        }
        set {
            client.setEnabled(newValue)
        }
    }

    static var supportsNightShift: Bool {
        get {
            return CBBlueLightClient.supportsBlueLightReduction()
        }
    }

    static var schedule: ScheduleType {
        get {
            switch blueLightStatus.mode {
            case 0:
                return .off
            case 1:
                return .solar
            case 2:
                return .custom(start: blueLightStatus.schedule.fromTime, end: blueLightStatus.schedule.toTime)
            default:
                assertionFailure("Unknown mode")
                return .off
            }
        }
        set {
            switch newValue {
            case .off:
                client.setMode(0)
            case .solar:
                client.setMode(1)
            case .custom(start: let start, end: let end):
                client.setMode(2)
                var schedule = Schedule(fromTime: start, toTime: end)
                client.setSchedule(&schedule)
            }
        }
    }

    private static let initialize: Void = {
        NightShiftManager.isCurrentlyInNightShiftSchedule = false
        NightShiftManager.nightShiftDisableTimer = nil
        // @convention block
        client.setStatusNotificationBlock {
            respond(to: isNightShiftEnabled ? .enteredScheduledNightShift : .exitedScheduledNightShift)
        }
    }()

    static func respond(to event: NightShiftEvent) {
//		switch event {
//
//		}
    }
}
