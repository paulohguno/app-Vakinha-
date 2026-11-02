import Foundation
import CoreLocation
import Combine

// MARK: - Gerenciamento Nativo de Geolocalização (CoreLocation)
public class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    
    @Published public var userLocation: CLLocation?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var cityName: String = "Detectando..."
    @Published public var locationError: String?
    
    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        self.authorizationStatus = manager.authorizationStatus
    }
    
    public func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    public func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = loc
            self.reverseGeocode(loc)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }
    
    private func reverseGeocode(_ loc: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, error in
            if let pm = placemarks?.first {
                DispatchQueue.main.async {
                    let city = pm.locality ?? pm.subAdministrativeArea ?? "Região Atual"
                    let uf = pm.administrativeArea ?? ""
                    self.cityName = uf.isEmpty ? city : "\(city)/\(uf)"
                }
            }
        }
    }
    
    public func distance(to lat: Double?, lon: Double?) -> String {
        guard let userLoc = userLocation, let lat = lat, let lon = lon else { return "" }
        let target = CLLocation(latitude: lat, longitude: lon)
        let meters = userLoc.distance(from: target)
        if meters < 1000 {
            return "\(Int(meters))m de você"
        } else {
            return String(format: "%.1f km de você", meters / 1000.0)
        }
    }
}

