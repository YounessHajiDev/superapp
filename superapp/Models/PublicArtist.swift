//
//  PublicArtist.swift
//  superapp
//
//  Created by Youness Haji on 2025-09-18.
//

import Foundation
import CoreLocation

struct PublicArtist: Identifiable, Equatable, Codable {
    let id: String              
    let displayName: String
    let city: String?
    let address: String?        // NEW: Full address for better geocoding
    let styles: String?
    let coverURL: String?
    let rating: Double?
    let latitude: Double?
    let longitude: Double?

    init(id: String,
         displayName: String,
         city: String? = nil,
         address: String? = nil,
         styles: String? = nil,
         coverURL: String? = nil,
         rating: Double? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil) {
        self.id = id
        self.displayName = displayName
        self.city = city
        self.address = address
        self.styles = styles
        self.coverURL = coverURL
        self.rating = rating
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D? {
        if let lat = latitude, let lon = longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    /// Full location string for geocoding (prioritize address over city)
    var fullLocation: String? {
        if let address = address, !address.isEmpty {
            if let city = city, !city.isEmpty {
                return "\(address), \(city)"
            }
            return address
        }
        return city
    }
}
