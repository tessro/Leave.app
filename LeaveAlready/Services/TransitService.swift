import Foundation

class TransitService: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let settings = SettingsManager.shared
    private let baseURL = "https://api.511.org/transit"

    func fetchDepartures(for route: ActiveRoute) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        guard !settings.apiKey.isEmpty else {
            await MainActor.run {
                errorMessage = "API key not set"
                isLoading = false
            }
            return
        }

        let stopCode = route.departureStation.id
        let operatorId = route.route.operatorId

        guard var components = URLComponents(string: "\(baseURL)/StopMonitoring") else {
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }

        components.queryItems = [
            URLQueryItem(name: "api_key", value: settings.apiKey),
            URLQueryItem(name: "agency", value: operatorId),
            URLQueryItem(name: "stopCode", value: stopCode),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else {
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TransitError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw TransitError.httpError(httpResponse.statusCode)
            }

            // Remove BOM if present (511 API sometimes includes it)
            let cleanedData: Data
            if data.starts(with: [0xEF, 0xBB, 0xBF]) {
                cleanedData = data.dropFirst(3)
            } else {
                cleanedData = data
            }

            let apiResponse = try JSONDecoder().decode(APIResponse.self, from: cleanedData)
            let departures = parseDepartures(from: apiResponse, for: route)

            await MainActor.run {
                self.departures = departures
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func parseDepartures(from response: APIResponse, for route: ActiveRoute) -> [Departure] {
        guard let delivery = response.ServiceDelivery.StopMonitoringDelivery.first,
              let visits = delivery.MonitoredStopVisit else {
            return []
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let altFormatter = ISO8601DateFormatter()
        altFormatter.formatOptions = [.withInternetDateTime]

        var departures: [Departure] = []

        for visit in visits {
            let journey = visit.MonitoredVehicleJourney

            // Filter by line if specified
            if !route.route.lineId.isEmpty {
                guard journey.LineRef == route.route.lineId else { continue }
            }

            // Filter by destination direction
            let destinationName = journey.DestinationName ?? ""
            let targetDestination = route.arrivalStation.name.lowercased()

            // Allow if destination contains our target or vice versa
            let matchesDestination = destinationName.lowercased().contains(targetDestination) ||
                                     targetDestination.contains(destinationName.lowercased()) ||
                                     route.route.lineId.isEmpty // If no line filter, show all

            guard matchesDestination || destinationName.isEmpty else { continue }

            guard let call = journey.MonitoredCall else { continue }

            let timeString = call.ExpectedDepartureTime ?? call.AimedDepartureTime ??
                            call.ExpectedArrivalTime ?? call.AimedArrivalTime ?? ""

            guard !timeString.isEmpty else { continue }

            var departureTime: Date?
            departureTime = dateFormatter.date(from: timeString)
            if departureTime == nil {
                departureTime = altFormatter.date(from: timeString)
            }

            guard let time = departureTime else { continue }

            // Skip departures in the past
            guard time > Date() else { continue }

            let departure = Departure(
                lineName: journey.PublishedLineName ?? journey.LineRef ?? "Train",
                destination: journey.DestinationName ?? route.arrivalStation.name,
                departureTime: time,
                isRealTime: journey.Monitored ?? false
            )

            departures.append(departure)
        }

        // Sort by departure time and take first 5
        return Array(departures.sorted { $0.departureTime < $1.departureTime }.prefix(5))
    }
}

enum TransitError: LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error: \(code)"
        }
    }
}
