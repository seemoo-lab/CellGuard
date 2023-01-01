//
//  ALSClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import Foundation

// https://github.com/apple/swift-protobuf/blob/main/Documentation/API.md#message-api

struct ALSLocation {
    var latitude = 0.0
    var longitude = 0.0
    var accuracy = 0
    var reach = 0
    var score = 0
    
    init(fromProto proto: AlsProto_ALSLocationResponse.ResponseCellLocation) {
        self.latitude = Double(proto.latitude) * pow(10, -8)
        self.longitude = Double(proto.longitude) * pow(10, -8)
        self.accuracy = Int(proto.accuracy)
        self.reach = Int(proto.reach)
        self.score = Int(proto.score)
    }
}

struct ALSCell {
    var mcc = 0
    var mnc = 0
    var tac = 0
    var cellId = 0
    var location: ALSLocation? = nil
    
    func hasCellId() -> Bool {
        return self.cellId >= 0
    }
    
    func isValid() -> Bool {
        // TODO: Implement correctly
        return true;
    }
    
    init(fromProto proto: AlsProto_ALSLocationResponse.ResponseCell) {
        self.mcc = Int(proto.mcc)
        self.mnc = Int(proto.mnc)
        self.tac = Int(proto.tacID)
        self.cellId = Int(proto.cellID)
        self.location = ALSLocation(fromProto: proto.location)
    }
    
    func toProto() -> AlsProto_ALSLocationRequest.RequestCell {
        AlsProto_ALSLocationRequest.RequestCell.with {
            $0.mcc = Int32(self.mcc)
            $0.mnc = Int32(self.mnc)
            $0.tacID = Int32(self.tac)
            $0.cellID = Int64(self.cellId)
        }
    }
}


/// The central access poin for Apple's Location Service (ALS)
struct ALSClient {
    
    let endpoint = URL(string: "https://gs-loc.apple.com/clls/wloc")!
    let headers = [
        "User-Agent": "locationd/2420.8.11 CFNetwork/1206 Darwin/20.1.0",
        "Accept": "*/*",
        "Accept-Language": "en-us",
    ]
    let serviceIdentifier = "com.apple.locationd"
    let iOSVersion = "14.2.1.18B121"
    let locale = "en_US"
    
    /// Request nearby celluluar cells from Apple's Location Service
    /// - Parameters:
    ///   - origin: the cell used as origin for the request, it doesn't require a location
    ///   - completion: called upon success with a list of nearby cells
    func requestCells(origin: ALSCell, completion: @escaping ([ALSCell])->()) {
        let protoRequest = AlsProto_ALSLocationRequest.with {
            $0.cell = origin.toProto()
            $0.unknown3 = 0
            $0.unknown4 = 1
            $0.unknown31 = 1
        }
        
        let data: Data;
        do {
            data = try protoRequest.serializedData()
        } catch {
            print("Can't encode proto request: \(error)")
            return
        }
        
        sendHttpRequest(protoData: data) { resultData in
            do {
                let protoResponse = try AlsProto_ALSLocationResponse(serializedData: resultData)
                completion(protoResponse.cells.map { ALSCell(fromProto: $0) });
            } catch {
                print("Can't decode proto response: \(error)")
                return
            }
        }
    }
    
    /// Send an HTTP request to Apple's Location Service.
    /// - Parameters:
    ///   - protoData: the encoded data of the protobuf request
    ///   - completion: called upon success with the binary protobuf data of the response
    private func sendHttpRequest(protoData: Data, completion: @escaping (Data)->()) {
        // Why we esacpe the parameter complection? https://www.donnywals.com/what-is-escaping-in-swift/
        
        // First build a binary request header and then append the length and the binary of the protobuf request
        let body = self.buildRequestHeader() + self.packLength(protoData.count) + protoData
        
        // Create a POST request in Swift (https://stackoverflow.com/a/58356848)
        var request = URLRequest(url: self.endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.allHTTPHeaderFields = self.headers
        
        // Execute the HTTP request using GCD (https://developer.apple.com/documentation/foundation/url_loading_system/fetching_website_data_into_memory?language=objc)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Check if error is set and if yes execute block (https://stackoverflow.com/a/25193174)
            if let error = error {
                // TODO: Handle client error
                print("Client error: \(error)")
                return
            }
            // CHeck if the HTTP response is okay
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                // TODO: Handle server error
                print("Server error: \(String(describing: response))")
                return
            }
            // Check the response body
            if let data = data {
                // If response data is provided, drop the first bytes because they also contain a binary TLV header in the format start + end + start + end + size, and invoke the callback.
                completion(data.dropFirst(10))
            }
        }
        task.resume()
    }
    
    /// Build the TLV (type length value) header bytes for an ALS request.
    /// - Returns: header bytes for a request to ALS
    private func buildRequestHeader() -> Data {
        // Reference: https://www.appelsiini.net/2017/reverse-engineering-location-services/
        
        // Fixed bytes indicating the start and end of a section in the header
        let start = Data([0x00, 0x01])
        let end = Data([0x00, 0x00])
        
        var header = Data()
        
        // Build the first section of header bytes
        header += start
        header += self.packString(self.locale)
        header += self.packString(self.serviceIdentifier)
        header += self.packString(self.iOSVersion)
        header += end
        
        // Build the second section of header bytes
        header += start
        header += end
        
        return header
    }
    
    /// Pack the given string into bytes by putting its length as a prefix.
    /// - Parameter string: the string to be packed
    /// - Returns: the packed bytes of the string
    private func packString(_ string: String) -> Data {
        let data = string.data(using: .utf8) ?? Data()
        if data.isEmpty {
            print("Failed to pack string '\(string)' into bytes")
        }
        
        return self.packLength(data.count) + data
    }
    
    /// Pack the given integer (length value) into a signed short (2 bytes) with big endianness.
    /// - Parameter length: the length integer to be packed
    /// - Returns: length as 2 byte value
    private func packLength(_ length: Int) -> Data {
        if length > Int16.max {
            print("Failed to pack length into bytes as it is too long: \(length) > \(Int16.max)")
            return Data()
        }
        
        var shortLength = Int16(length).bigEndian
        // https://stackoverflow.com/a/43247959
        return Data(bytes: &shortLength, count: 2)
    }
    
}
