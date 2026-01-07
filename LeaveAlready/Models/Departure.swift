import Foundation

struct Departure: Identifiable, Equatable {
    let id: UUID
    let lineName: String
    let destination: String
    let departureTime: Date
    let isRealTime: Bool

    init(id: UUID = UUID(), lineName: String, destination: String, departureTime: Date, isRealTime: Bool) {
        self.id = id
        self.lineName = lineName
        self.destination = destination
        self.departureTime = departureTime
        self.isRealTime = isRealTime
    }

    var minutesUntilDeparture: Int {
        let interval = departureTime.timeIntervalSince(Date())
        return max(0, Int(interval / 60))
    }

    var timeString: String {
        let minutes = minutesUntilDeparture
        if minutes == 0 {
            return "Now"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) min"
        }
    }
}

struct APIResponse: Codable {
    let ServiceDelivery: ServiceDelivery
}

struct ServiceDelivery: Codable {
    let StopMonitoringDelivery: [StopMonitoringDelivery]
}

struct StopMonitoringDelivery: Codable {
    let MonitoredStopVisit: [MonitoredStopVisit]?
}

struct MonitoredStopVisit: Codable {
    let MonitoredVehicleJourney: MonitoredVehicleJourney
}

struct MonitoredVehicleJourney: Codable {
    let LineRef: String?
    let PublishedLineName: String?
    let DestinationName: String?
    let MonitoredCall: MonitoredCall?
    let Monitored: Bool?
}

struct MonitoredCall: Codable {
    let ExpectedDepartureTime: String?
    let AimedDepartureTime: String?
    let ExpectedArrivalTime: String?
    let AimedArrivalTime: String?
}
