//
//  NavigationHandler.swift
//  YOLO
//
//  Created by 施炎培 on 2025/1/30.
//  Copyright © 2025 Ultralytics. All rights reserved.
//

import UIKit
import CoreLocation

class NavigationHandler {
    
    // Check if Google Maps is installed
    static func isGoogleMapsInstalled() -> Bool {
        if let url = URL(string: "comgooglemaps://") {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }
    
    // Launch navigation with Google Maps
    static func navigateWithGoogleMaps(to destination: CLLocationCoordinate2D,
                                     destinationName: String,
                                     travelMode: String = "driving",
                                     isAccessibilityMode: Bool = false) {
        
        var urlComponents = URLComponents(string: "comgooglemaps-x-callback://")!
        
        // Your app's custom URL scheme - replace with your actual scheme
        let callbackScheme = "sypppGithubIoYoloNavigationCompleted://"
        
        // Base parameters
        var queryItems = [
                    URLQueryItem(name: "daddr", value: "\(destination.latitude),\(destination.longitude)"),
                    URLQueryItem(name: "dirflg", value: travelMode == "walking" ? "w" : "d"),
                    URLQueryItem(name: "directionsmode", value: travelMode),
                    URLQueryItem(name: "navigate", value: "true"),
                    URLQueryItem(name: "title", value: destinationName),
                    URLQueryItem(name: "x-source", value: "yolo"),
                    URLQueryItem(name: "x-success", value: callbackScheme)
        ]
        
    
        
        urlComponents.queryItems = queryItems
        
        if let url = urlComponents.url {
            print("\(url.absoluteString)")
            print("\(url)")
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    print("Failed to open Google Maps")
                    if let appStoreURL = URL(string: "https://apps.apple.com/app/google-maps/id585027354") {
                        UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
                    }
                }
            }
        }
    }
}
