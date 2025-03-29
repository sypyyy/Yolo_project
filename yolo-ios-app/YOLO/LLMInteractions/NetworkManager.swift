//
//  NetworkManager.swift
//  YOLO
//
//  Created by 施炎培 on 2024/11/20.
//  Copyright © 2024 Ultralytics. All rights reserved.
//

import Foundation

class NetworkManager {
    static let isNetworkLocal = true
    static let shared = NetworkManager()
    private let session = URLSession.shared
    
    static var baseUrl: String {
        get {
            NetworkManager.isNetworkLocal ? "http://192.168.1.42:8000" : "http://django-env.eba-dpmriiwt.us-west-1.elasticbeanstalk.com"
        }
    }
    
    private init() {}

    class RequestBuilder {
        private var request: URLRequest
        
        init(url: URL) {
            self.request = URLRequest(url: url)
        }
        
        func setMethod(_ method: String) -> RequestBuilder {
            request.httpMethod = method
            return self
        }
        
        func setHeaders(_ headers: [String: String]) -> RequestBuilder {
            headers.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }
            return self
        }
        
        func addHeader(key: String, value: String) -> RequestBuilder {
            request.addValue(value, forHTTPHeaderField: key)
            return self
        }
        
        func setQueryItems(_ queryItems: [URLQueryItem]) -> RequestBuilder {
            guard var urlComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) else {
                return self
            }
            urlComponents.queryItems = queryItems
            if let urlWithQuery = urlComponents.url {
                request.url = urlWithQuery
            }
            return self
        }
        
        func setBody(_ body: Data?) -> RequestBuilder {
            request.httpBody = body
            return self
        }
        
        func modifyRequest(_ modifier: (URLRequest) -> URLRequest) -> RequestBuilder {
            request = modifier(request)
            return self
        }
        
        func build() -> URLRequest {
            return request
        }
    }
    
    func makeRequest(builder: RequestBuilder, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let request = builder.build()
        session.dataTask(with: request) { data, response, error in
            completion(data, response, error)
        }.resume()
    }
    
    func makeRequestAsync(builder: RequestBuilder) async throws -> (Data, URLResponse) {
        let request = builder.build()
        let (data, response) = try await session.data(for: request)
        return (data, response)
    }
}

