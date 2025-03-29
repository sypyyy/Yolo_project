//
//  JSONUtils.swift
//  YOLO
//
//  Created by 施炎培 on 2024/12/5.
//  Copyright © 2024 Ultralytics. All rights reserved.
//

import Foundation

class JSONHelper {
    private var data: Any

    init(_ json: String) {
        if let jsonData = json.data(using: .utf8),
           let parsedData = try? JSONSerialization.jsonObject(with: jsonData, options: []) {
            self.data = parsedData
        } else {
            self.data = [:] // Fallback to an empty dictionary if parsing fails
        }
    }

    private init(data: Any) {
        self.data = data
    }

    func get(_ key: String) -> JSONHelper? {
        guard let dictionary = data as? [String: Any], let value = dictionary[key] else { return nil }
        return JSONHelper(data: value)
    }

    func getFromArray(_ index: Int) -> JSONHelper? {
        guard let array = data as? [Any], array.indices.contains(index) else { return nil }
        return JSONHelper(data: array[index])
    }

    func asString() -> String? {
        return data as? String
    }

    func asInt() -> Int? {
        return data as? Int
    }
    
    func asDouble() -> Double? {
        return data as? Double
    }

    func asArray() -> [Any]? {
        return data as? [Any]
    }

    func asDictionary() -> [String: Any]? {
        return data as? [String: Any]
    }
}
