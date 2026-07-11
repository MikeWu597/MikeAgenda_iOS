import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    @Published var isInShenzhen = false
    @Published var isInHongKong = false
    @Published var locationChecked = false
    @Published var currentLocation: CLLocation?
    @Published var manualCity: String? = nil

    private let manager = CLLocationManager()
    private let cacheKeySZ = "mikeagenda.inShenzhen"
    private let cacheKeyHK = "mikeagenda.inHongKong"
    private var isTracking = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        isInShenzhen = UserDefaults.standard.bool(forKey: cacheKeySZ)
        isInHongKong = UserDefaults.standard.bool(forKey: cacheKeyHK)
    }

    func requestLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationChecked = true
            return
        }
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            locationChecked = true
        }
    }

    func startTracking() {
        guard !isTracking,
              CLLocationManager.locationServicesEnabled(),
              manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
        else { return }
        isTracking = true
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status != .notDetermined {
            locationChecked = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let inSZ = isInShenzhenArea(loc)
        let inHK = isInHongKongArea(loc)
        isInShenzhen = inSZ
        isInHongKong = inHK
        locationChecked = true
        UserDefaults.standard.set(inSZ, forKey: cacheKeySZ)
        UserDefaults.standard.set(inHK, forKey: cacheKeyHK)
        currentLocation = loc
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationChecked = true
    }

    private func isInShenzhenArea(_ location: CLLocation) -> Bool {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        return lat >= 22.45 && lat <= 22.85 && lon >= 113.75 && lon <= 114.65
    }

    private func isInHongKongArea(_ location: CLLocation) -> Bool {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        return lat >= 22.15 && lat <= 22.55 && lon >= 113.83 && lon <= 114.4
    }
}
