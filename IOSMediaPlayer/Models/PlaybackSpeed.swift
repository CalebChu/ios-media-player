import Foundation

public enum PlaybackSpeed: Double, CaseIterable, Identifiable, Codable {
    case half = 0.5
    case threeQuarters = 0.75
    case normal = 1.0
    case oneAndQuarter = 1.25
    case oneAndHalf = 1.5
    case oneAndThreeQuarters = 1.75
    case double = 2.0

    public var id: Double {
        return rawValue
    }

    public var title: String {
        switch self {
        case .half:
            return "0.5x"
        case .threeQuarters:
            return "0.75x"
        case .normal:
            return "1.0x"
        case .oneAndQuarter:
            return "1.25x"
        case .oneAndHalf:
            return "1.5x"
        case .oneAndThreeQuarters:
            return "1.75x"
        case .double:
            return "2.0x"
        }
    }

    public var rate: Float {
        return Float(rawValue)
    }

    public static func closest(to rate: Float) -> PlaybackSpeed {
        let doubleRate = Double(rate)
        return PlaybackSpeed.allCases.min(by: { abs($0.rawValue - doubleRate) < abs($1.rawValue - doubleRate) }) ?? .normal
    }
}
