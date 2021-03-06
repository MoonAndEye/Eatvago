//
//  fetchNearbyLocationManager.swift
//  Eatvago
//
//  Created by Ｍason Chang on 2017/7/28.
//  Copyright © 2017年 Ｍason Chang iOS#4. All rights reserved.
//

import UIKit
import Alamofire
import GoogleMaps
import GooglePlaces

protocol FetchLocationDelegate: class {
    func manager(_ manager: FetchNearbyLocationManager, didGet nearLocations: [Location], nextPageToken: String?)
    func manager(_ manager: FetchNearbyLocationManager, didFailWith error: Error)
    func manager(_ manager: FetchNearbyLocationManager, didFailWith noDataIn: String)
}

enum FetchError: Error {
    case invalidFormatted
}

class FetchNearbyLocationManager {
    
    weak var delegate: FetchLocationDelegate?
    
    var keyCount = 0
    
    //獲取地圖資訊的陣列
    var locations: [Location] = []
    
    var coordinate = CLLocationCoordinate2D()
    
    var radius = Double()
    
    var requestTimer = 0
    
    func requestNearbyLocation(coordinate: CLLocationCoordinate2D, radius: Double, keywordText: String) {

        self.coordinate = coordinate
        
        self.radius = radius
        
        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(coordinate.latitude),\(coordinate.longitude)&radius=\(radius)&type=restaurants&keyword=\(keywordText)&key=\(googleMapAPIKey[keyCount])"

        print(urlString)

        fetchRequestHandler(urlString: urlString, nextPageToken: "", keywordText: keywordText)
    }
    
    func fetchRequestHandler(urlString: String, nextPageToken: String, keywordText: String) {
        //清空之前的陣列
        locations = []
        
        var url = urlString
        
        //計算requestTimer
        self.requestTimer += 1
        
        if nextPageToken != "" && urlString == ""{
            
             url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?pagetoken=\(nextPageToken)&key=\(googleMapAPIKey[keyCount])"
            
        } else if url == "" {
            
            return
            
        } else { }
        
        print(url)
        
        Alamofire.request(url).responseJSON { (response) in

            let json = response.result.value
            
            guard
                let localJson = json as? [String: Any],
                let status = localJson["status"] as? String else {
                    
                    print("NO Status")
                    
                    self.delegate?.manager(self, didFailWith: FetchError.invalidFormatted)
                    
                    return
                    
            }

            //發出request失敗則重發
            if (status == "OVER_QUERY_LIMIT" || status == "INVALID_REQUEST") && self.requestTimer < 2 {
                
                if self.keyCount < 4 {
                    
                    if nextPageToken == "" {
                        
                        self.keyCount += 1
                        
                        self.requestNearbyLocation(coordinate: self.coordinate, radius: self.radius, keywordText: keywordText)
                        
                    } else {
                        
                        self.fetchRequestHandler(urlString: "", nextPageToken: nextPageToken, keywordText: keywordText)
                        
                    }
                } else {
                    
                    self.keyCount = 0
                    
                    if nextPageToken == "" {
                        
                        self.requestNearbyLocation(coordinate: self.coordinate, radius: self.radius, keywordText: keywordText)
                        
                    } else {
                        
                        self.fetchRequestHandler(urlString: "", nextPageToken: nextPageToken, keywordText: keywordText)
                        
                    }
                }
            }
            
            guard
                let results = localJson["results"] as? [[String: Any]],
                let pageToken = localJson["next_page_token"] as? String? else {
                    
                    self.delegate?.manager(self, didFailWith: FetchError.invalidFormatted)
                    
                    return
                    
            }
            
            if results.count == 0 {
                
                self.delegate?.manager(self, didFailWith: "請重新呼叫LocationManager")
                
                return
                
            }
            
            for result in results {
                // 不是所有都有priceLevel, rating所以特別拿出來
                // priceLevel = -1.0 代表此資料沒提供priceLevel
                var priceLevel = -1.0
                
                var rating = -1.0
                
                if result["price_level"] != nil && result["rating"] != nil {
                    
                    guard
                        let plevel = result["price_level"] as? Double,
                        let rlevel = result["rating"] as? Double else {
                        
                        self.delegate?.manager(self, didFailWith: FetchError.invalidFormatted)

                        return
                    }
                    
                    priceLevel = plevel
                    
                    rating = rlevel
                }
                
                var photoReference = ""
                
                if result["photos"] != nil {
                    
                    guard
                        let photos = result["photos"] as? [[String: Any]],
                        let reference = photos[0]["photo_reference"] as? String else {
                            
                            self.delegate?.manager(self, didFailWith: FetchError.invalidFormatted)
                            
                            return
                    }
                    
                    photoReference = reference
                    
                }

                guard
                    let geometry = result["geometry"] as? [String:Any],
                    let id = result["id"] as? String,
                    let name = result["name"] as? String,
                    let placeId = result["place_id"] as? String,
                    let types = result["types"] as? [String],
                    let location = geometry["location"] as? [String:Any],
                    let latitude = location["lat"] as? CLLocationDegrees,
                    let longitude = location["lng"] as? CLLocationDegrees else {
                        
                        self.delegate?.manager(self, didFailWith: FetchError.invalidFormatted)
                        
                        return
                }

                let locationData = Location(latitude: latitude,
                                            longitude: longitude,
                                            name: name,
                                            id: id,
                                            placeId: placeId,
                                            types: types,
                                            priceLevel: priceLevel,
                                            rating: rating,
                                            photoReference: photoReference)

                self.locations.append(locationData)
                
            }
            
            self.delegate?.manager(self, didGet: self.locations, nextPageToken: pageToken)
                        
        }
    }
}
