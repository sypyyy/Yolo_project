//
//  d.swift
//  YOLO
//
//  Created by 施炎培 on 2024/11/6.
//  Copyright © 2024 Ultralytics. All rights reserved.
//
import SwiftUI
import MapKit
import Combine

extension Notification.Name {
    static let askedTOPerformSeenObjectSearch = Notification.Name("askedTOPerformSeenObjectSearch")
    
}

struct Location: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private var locationManager = CLLocationManager()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var locations: [Location] = [] // Stores Location objects to track path
    
    var currentLocation: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        self.locations.append(Location(coordinate: location.coordinate)) // Track the walking path
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error)")
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct MapView: View {
    @State private var searchText = ""
    
    @State var mapMarks: [Location] = []

    @StateObject private var locationManager = LocationManager.shared

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        VStack {
            TextField("Search location", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: mapMarks) { location in
                MapMarker(coordinate: location.coordinate, tint: .red)
                }
            .onReceive(Publishers.CombineLatest(Just(locationManager.latitude), Just(locationManager.longitude))) { _ in
                    if(calculateStraightDistance(from: locationManager.currentLocation, to: region.center)) > 20 {
                        DispatchQueue.main.async {
                            withAnimation {
                                updateRegion()
                            }
                        }
                    }
                    
                }
            /*
             
             */
        }
        .onSubmit {
            handleSearch() // Call your custom search logic on submit
        }
        .onReceive(NotificationCenter.default.publisher(for: .askedTOPerformSeenObjectSearch)) { notification in
            if let userInfo = notification.userInfo,
               let searchString = userInfo["searchString"] as? String {
                DispatchQueue.main.async {
                    searchText = searchString
                    handleSearch()
                }
                
            }
        }
        
        /*
        .overlay(
            //MapOverlayView(locations: locationManager.locations.map { $0.coordinate }),
            //alignment: .center
        )
         */
    }
    
    private func handleSearch() {
        // Implement your search logic here using searchText
        print("Searching for: \(searchText)")
        Task {
            let objs = await SeenObjectService.shared.searchFor(target: searchText.lowercased())
            await MainActor.run {
                mapMarks = objs.map {obj in
                    Location(coordinate: obj.coordinate)
                }
            }
            
        }
    }

    private func updateRegion() {
        region.center = CLLocationCoordinate2D(latitude: locationManager.latitude, longitude: locationManager.longitude)
    }
}

struct MapOverlayView: View {
    var locations: [CLLocationCoordinate2D]

    var body: some View {
        MapPolyline(locations: locations)
    }
}

struct MapPolyline: UIViewRepresentable {
    var locations: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays) // Clear previous overlays
        let polyline = MKPolyline(coordinates: locations, count: locations.count)
        mapView.addOverlay(polyline)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapPolyline

        init(_ parent: MapPolyline) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
