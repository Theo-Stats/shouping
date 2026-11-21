import Foundation

struct WeatherSnapshot: Equatable, Sendable {
    let city: String
    let temperatureCelsius: Int
    let condition: String
    let symbolName: String
    let updatedAt: Date
}

enum WeatherServiceError: LocalizedError {
    case emptyCity
    case cityNotFound
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .emptyCity: return "请先填写城市。"
        case .cityNotFound: return "没有找到这个城市。"
        case .invalidResponse: return "天气服务返回了无法识别的数据。"
        case .httpStatus(let status): return "天气服务请求失败（HTTP \(status)）。"
        }
    }
}

struct WeatherService {
    private struct GeocodingResponse: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
        }

        let results: [Result]?
    }

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature2m: Double
            let weatherCode: Int

            enum CodingKeys: String, CodingKey {
                case temperature2m = "temperature_2m"
                case weatherCode = "weather_code"
            }
        }

        let current: Current
    }

    func fetch(city: String) async throws -> WeatherSnapshot {
        let normalizedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCity.isEmpty else { throw WeatherServiceError.emptyCity }

        var geocodingComponents = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        geocodingComponents.queryItems = [
            URLQueryItem(name: "name", value: normalizedCity),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "zh"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let geocoding: GeocodingResponse = try await request(geocodingComponents.url!)
        guard let location = geocoding.results?.first else {
            throw WeatherServiceError.cityNotFound
        }

        var forecastComponents = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        forecastComponents.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        let forecast: ForecastResponse = try await request(forecastComponents.url!)
        let description = Self.description(for: forecast.current.weatherCode)
        return WeatherSnapshot(
            city: location.name,
            temperatureCelsius: Int(forecast.current.temperature2m.rounded()),
            condition: description.text,
            symbolName: description.symbol,
            updatedAt: Date()
        )
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse else {
            throw WeatherServiceError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw WeatherServiceError.httpStatus(response.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WeatherServiceError.invalidResponse
        }
    }

    private static func description(for code: Int) -> (text: String, symbol: String) {
        switch code {
        case 0:
            return ("晴", "sun.max.fill")
        case 1...3:
            return ("多云", "cloud.sun.fill")
        case 45, 48:
            return ("有雾", "cloud.fog.fill")
        case 51...57:
            return ("毛毛雨", "cloud.drizzle.fill")
        case 61...67:
            return ("雨", "cloud.rain.fill")
        case 71...77:
            return ("雪", "cloud.snow.fill")
        case 80...82:
            return ("阵雨", "cloud.heavyrain.fill")
        case 85, 86:
            return ("阵雪", "cloud.snow.fill")
        case 95...99:
            return ("雷雨", "cloud.bolt.rain.fill")
        default:
            return ("天气", "cloud.fill")
        }
    }
}
