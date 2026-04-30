import CoreLocation
import Foundation
import MapKit
import SwiftUI
import WeatherKit

/// FILE: Managers/OutdoorSuggestionsManager.swift
/// On-device weather (WeatherKit) + nearby “park” hint (MKLocalSearch). Fails quietly if permission or entitlement is missing.

@MainActor
final class OutdoorSuggestionsManager: NSObject, ObservableObject {
    @Published var weatherLine: String?
    @Published var nearbyLine: String?
    @Published var locationDenied: Bool = false
    @Published private(set) var weatherHint: RecommendationWeatherHint = .neutral

    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService()
    private var isStarted = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func startIfNeeded() {
        guard !isStarted else { return }
        isStarted = true
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    private func refresh(from location: CLLocation) async {
        let coord = location.coordinate
        await fetchWeather(for: location)
        await searchPark(coord: coord)
    }

    private func fetchWeather(for location: CLLocation) async {
        do {
            let weather = try await weatherService.weather(for: location)
            let condition = weather.currentWeather.condition
            switch condition {
            case .clear, .mostlyClear, .partlyCloudy:
                weatherHint = .sunny
                weatherLine = "Nice weather today ☀️ A short walk could help."
            case .rain, .drizzle, .heavyRain, .freezingRain, .sleet, .hail, .snow, .flurries, .blowingSnow, .blizzard, .hurricane, .tropicalStorm, .thunderstorms:
                weatherHint = .rainy
                weatherLine = nil
            default:
                weatherHint = .neutral
                weatherLine = nil
            }
        } catch {
            weatherHint = .neutral
            weatherLine = nil
            print("⚠️ WeatherKit: \(error.localizedDescription)")
        }
    }

    private func searchPark(coord: CLLocationCoordinate2D) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "park"
        request.region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 8000,
            longitudinalMeters: 8000
        )
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                nearbyLine = nil
                return
            }
            let name = item.name ?? "Park"
            let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distanceMeters = item.placemark.location.map { here.distance(from: $0) } ?? 0
            let miles = distanceMeters * 0.000_621_371
            let milesStr = miles < 0.1 ? String(format: "%.2f mi", max(miles, 0.01)) : String(format: "%.1f mi", miles)
            nearbyLine = "Nearby: \(name) (\(milesStr))"
        } catch {
            nearbyLine = nil
            print("⚠️ Local search: \(error.localizedDescription)")
        }
    }
}

extension OutdoorSuggestionsManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .denied, .restricted:
                locationDenied = true
            default:
                locationDenied = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            await refresh(from: loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location: \(error.localizedDescription)")
    }
}
