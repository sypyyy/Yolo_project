//
//  SeenObjects.swift
//  YOLO
//
//  Created by 施炎培 on 2024/11/7.
//  Copyright © 2024 Ultralytics. All rights reserved.
//
import MapKit
import Vision

class SeenObject {
    let coordinate: CLLocationCoordinate2D
    let objectName: String
    let image: UIImage? = nil
    var distanceToUser: Double? = nil
    init(coordinate: CLLocationCoordinate2D, objectName: String) {
        self.coordinate = coordinate
        self.objectName = objectName
    }
}

extension SeenObject {
    func stringForLLM() -> String {
        return "Distance:\(distanceToUser)m, lat: \(coordinate.latitude), lon:\(coordinate.longitude)"
    }
}

func calculateRouteDistance(from sourceCoordinate: CLLocationCoordinate2D, to destinationCoordinate: CLLocationCoordinate2D) async -> Double? {
    let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
    let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)

    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: sourcePlacemark)
    request.destination = MKMapItem(placemark: destinationPlacemark)
    request.transportType = .automobile // Choose your transport type

    let directions = MKDirections(request: request)
    do {
           let response = try await directions.calculate()
           guard let route = response.routes.first else {
               print("No route found")
               return nil
           }
           return route.distance
    } catch {
        print("Failed to calculate route distance: \(error.localizedDescription)")
        return nil
    }
}


func calculateStraightDistance(from sourceCoordinate: CLLocationCoordinate2D, to destinationCoordinate: CLLocationCoordinate2D) -> Double {
    let sourceLocation = CLLocation(latitude: sourceCoordinate.latitude, longitude: sourceCoordinate.longitude)
    let destinationLocation = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
    
    let distanceInMeters = sourceLocation.distance(from: destinationLocation)
    return distanceInMeters // Distance in meters
}


class SeenObjectService: ObservableObject {
    static let shared = SeenObjectService()
    
    static let MinDistanceToAdd: Double = 20
    static let objDetectValidCount = 5
    let locationMgr = LocationManager.shared
    var seenObjects: [String : [SeenObject]] = [ : ]
    var reportedObjects: [String: Int] = [:]
    var timer: Timer? = nil
    
    func collectReportedObjects() {
        reportedObjects.keys.forEach { key in
            if(reportedObjects[key] ?? 0 >= SeenObjectService.objDetectValidCount) {
                sawObject(name : key)
            }
        }
        reportedObjects = [:]
    }
    
    func reportDetectedResults(results: [VNRecognizedObjectObservation]?) {
        //Start collecting the reported objects every 0.5s
        if(timer == nil) {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { timer in
                self.collectReportedObjects()
            })
        }
        guard let results = results else {return}
        results.forEach { observation in
            guard let label = observation.labels.first?.identifier else { return }
            if(reportedObjects.keys.contains(label)) {
                reportedObjects[label]? += 1
            } else {
                reportedObjects[label] = 1
            }
        }
    }
    
    func sawObject(name: String) {
        let newObj = SeenObject(coordinate: locationMgr.currentLocation, objectName: name)
        var shouldAdd = true
        seenObjects[name]?.forEach({ obj in
            if(calculateStraightDistance(from: obj.coordinate, to: newObj.coordinate) < SeenObjectService.MinDistanceToAdd) {
                shouldAdd = false
            }
        })
        if(shouldAdd) {
            if seenObjects.keys.contains(name) {
                //print("saw object!!!! \(name)")
                seenObjects[name]?.append(newObj)
            } else {
                //print("saw object!!!! \(name)")
                seenObjects[name] = [newObj]
            }
        }
    }
    
    func searchFor(target: String) async -> [SeenObject] {
        if var objs = seenObjects[target] {
            let userLocation = locationMgr.currentLocation
            for i in 0..<objs.count {
                let obj = objs[i]
                obj.distanceToUser = calculateStraightDistance(from: userLocation, to: obj.coordinate)
            }
            objs = objs.filter({ obj in
                obj.distanceToUser != nil
            }).sorted { a, b in
                guard let disA = a.distanceToUser, let disB = b.distanceToUser else {return false}
                return disA < disB
            }
            return objs
        }
        return []
    }
}
