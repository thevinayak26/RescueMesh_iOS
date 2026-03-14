import Foundation
import CoreLocation

/// A dead-simple, standalone location tracker used ONLY for the SOS system.
/// Does not depend on LocationStateManager or any protocol wrappers.
/// Uses startUpdatingLocation() for continuous fixes and caches every coordinate to UserDefaults.
final class SOSLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = SOSLocationManager()
    
    private let locationManager = CLLocationManager()
    
    // The latest live coordinate
    private(set) var latestCoordinate: CLLocationCoordinate2D?
    private(set) var latestTimestamp: Date?
    
    // UserDefaults keys for persistence
    private let latKey = "sos.cached.latitude"
    private let lonKey = "sos.cached.longitude"
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        // Load cached coordinates from last session
        let cachedLat = UserDefaults.standard.double(forKey: latKey)
        let cachedLon = UserDefaults.standard.double(forKey: lonKey)
        if cachedLat != 0.0 || cachedLon != 0.0 {
            latestCoordinate = CLLocationCoordinate2D(latitude: cachedLat, longitude: cachedLon)
            print("📍 SOS: Loaded cached location: \(cachedLat), \(cachedLon)")
        }
    }
    
    // MARK: - Public API
    
    /// Call this once at app launch (e.g., from ChatViewModel.init).
    /// Requests permission and starts continuous updates.
    func startTracking() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            print("📍 SOS: Requesting location permission...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 SOS: Location authorized — starting continuous updates")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("⚠️ SOS: Location denied/restricted. Will use cached location if available.")
        @unknown default:
            break
        }
    }
    
    /// Returns the best available coordinate right now.
    /// Priority: live fix > cached from UserDefaults
    func getBestCoordinate() -> CLLocationCoordinate2D? {
        if let coord = latestCoordinate {
            return coord
        }
        // Fallback to UserDefaults
        let lat = UserDefaults.standard.double(forKey: latKey)
        let lon = UserDefaults.standard.double(forKey: lonKey)
        if lat != 0.0 || lon != 0.0 {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let coord = location.coordinate
        latestCoordinate = coord
        latestTimestamp = location.timestamp
        
        // Cache immediately to UserDefaults
        UserDefaults.standard.set(coord.latitude, forKey: latKey)
        UserDefaults.standard.set(coord.longitude, forKey: lonKey)
        
        print("📍 SOS GPS Fix: \(coord.latitude), \(coord.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ SOS Location Error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("📍 SOS: Authorization changed to \(status.rawValue)")
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
