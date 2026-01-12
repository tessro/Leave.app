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

struct APIResponse: Decodable {
    let ServiceDelivery: ServiceDelivery
}

struct ServiceDelivery: Decodable {
    let StopMonitoringDelivery: [StopMonitoringDeliveryItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle both single object and array responses from the API
        if let array = try? container.decode([StopMonitoringDeliveryItem].self, forKey: .StopMonitoringDelivery) {
            StopMonitoringDelivery = array
        } else if let single = try? container.decode(StopMonitoringDeliveryItem.self, forKey: .StopMonitoringDelivery) {
            StopMonitoringDelivery = [single]
        } else {
            StopMonitoringDelivery = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case StopMonitoringDelivery
    }
}

struct StopMonitoringDeliveryItem: Decodable {
    let MonitoredStopVisit: [MonitoredStopVisitItem]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle both single object and array responses from the API
        if let array = try? container.decode([MonitoredStopVisitItem].self, forKey: .MonitoredStopVisit) {
            MonitoredStopVisit = array
        } else if let single = try? container.decode(MonitoredStopVisitItem.self, forKey: .MonitoredStopVisit) {
            MonitoredStopVisit = [single]
        } else {
            MonitoredStopVisit = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case MonitoredStopVisit
    }
}

struct MonitoredStopVisitItem: Decodable {
    let MonitoredVehicleJourney: MonitoredVehicleJourney
}

struct MonitoredVehicleJourney: Decodable {
    let LineRef: String?
    let PublishedLineName: String?
    let DestinationName: String?
    let MonitoredCall: MonitoredCall?
    let Monitored: Bool?
}

struct MonitoredCall: Decodable {
    let ExpectedDepartureTime: String?
    let AimedDepartureTime: String?
    let ExpectedArrivalTime: String?
    let AimedArrivalTime: String?
}
