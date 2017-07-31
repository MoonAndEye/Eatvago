//
//  LocationStruct.swift
//  Eatvago
//
//  Created by Ｍason Chang on 2017/7/28.
//  Copyright © 2017年 Ｍason Chang iOS#4. All rights reserved.
//

import Foundation

struct Location {
    var latitude: Double
    var longitude: Double
    var name: String
    var id: String
    var placeId: String
    var types: [String]
    var priceLevel: Double?
    var rating: Double?
    var openingHours: [String: Any]
    var formattedPhoneNumber: String
    var reviewsText: [String]
    var website: String
    
    //一開始先找nearby使用的init
    init(latitude: Double, longitude: Double, name: String, id: String, placeId: String, types: [String], priceLevel: Double?, rating: Double?) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.id = id
        self.placeId = placeId
        self.types = types
        self.priceLevel = priceLevel
        self.rating = rating
        self.openingHours = [:]
        self.formattedPhoneNumber = ""
        self.reviewsText = []
        self.website = ""
    }
    
}