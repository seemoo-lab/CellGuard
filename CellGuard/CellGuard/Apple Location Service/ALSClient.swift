//
//  ALSClient.swift
//  CellGuard
//
//  Created by Lukas Arnold on 01.01.23.
//

import Foundation
import OSLog

// https://github.com/apple/swift-protobuf/blob/main/Documentation/API.md#message-api

enum ALSClientError: Error {
    case httpStatus(URLResponse?)
    case httpNoData(URLResponse?)
}

enum ALSTechnology {
    case GSM
    case SCDMA
    case LTE
    case NR
    case CDMA
}

struct ALSLocation {
    var latitude = 0.0
    var longitude = 0.0
    var accuracy = 0
    var reach = 0
    var score = 0
    
    init(fromProto proto: AlsProto_Location) {
        self.latitude = Double(proto.latitude) * pow(10, -8)
        self.longitude = Double(proto.longitude) * pow(10, -8)
        self.accuracy = Int(proto.accuracy)
        self.reach = Int(proto.reach)
        self.score = Int(proto.score)
    }
    
    func isValid() -> Bool {
        return self.accuracy > 0
    }
}

struct ALSCell {
    var technology: ALSTechnology
    var country = 0
    var network = 0
    var area = 0
    var cell: Int64 = 0
    var location: ALSLocation? = nil
    
    func hasCellId() -> Bool {
        return self.cell >= 0
    }
    
    func isValid() -> Bool {
        return location?.isValid() ?? false
    }
    
    init(technology: ALSTechnology, country: Int, network: Int, area: Int, cell: Int64) {
        self.technology = technology
        self.country = country
        self.network = network
        self.area = area
        self.cell = cell
    }
    
    init(fromGsmProto proto: AlsProto_GsmCell) {
        self.technology = .GSM
        self.country = Int(proto.mcc)
        self.network = Int(proto.mnc)
        self.area = Int(proto.lacID)
        self.cell = Int64(proto.cellID)
        self.location = ALSLocation(fromProto: proto.location)
    }
    
    init(fromScdmaProto proto: AlsProto_ScdmaCell) {
        self.technology = .SCDMA
        self.country = Int(proto.mcc)
        self.network = Int(proto.mnc)
        self.area = Int(proto.lacID)
        self.cell = Int64(proto.cellID)
        self.location = ALSLocation(fromProto: proto.location)
    }
    
    init(fromLteProto proto: AlsProto_LteCell) {
        self.technology = .LTE
        self.country = Int(proto.mcc)
        self.network = Int(proto.mnc)
        self.area = Int(proto.tacID)
        self.cell = Int64(proto.cellID)
        self.location = ALSLocation(fromProto: proto.location)
    }
    
    init(fromNRProto proto: AlsProto_Nr5GCell) {
        self.technology = .NR
        self.country = Int(proto.mcc)
        self.network = Int(proto.mnc)
        self.area = Int(proto.tacID)
        self.cell = Int64(proto.cellID)
        self.location = ALSLocation(fromProto: proto.location)
    }
    
    init(fromCdmaProto proto: AlsProto_CdmaCell) {
        self.technology = .CDMA
        self.country = Int(proto.mcc)
        self.network = Int(proto.sid)
        self.area = Int(proto.nid)
        self.cell = Int64(proto.bsid)
        self.location = ALSLocation(fromProto: proto.location)
    }
    
    
    func toGsmProto() -> AlsProto_GsmCell {
        AlsProto_GsmCell.with {
            $0.mcc = Int32(self.country)
            $0.mnc = Int32(self.network)
            $0.lacID = Int32(self.area)
            $0.cellID = Int64(self.cell)
        }
    }
    
    func toScdmaProto() -> AlsProto_ScdmaCell {
        AlsProto_ScdmaCell.with {
            $0.mcc = Int32(self.country)
            $0.mnc = Int32(self.network)
            $0.lacID = Int32(self.area)
            $0.cellID = Int32(self.cell)
        }
    }
    
    func toLteProto() -> AlsProto_LteCell {
        AlsProto_LteCell.with {
            $0.mcc = Int32(self.country)
            $0.mnc = Int32(self.network)
            $0.tacID = Int32(self.area)
            $0.cellID = Int32(self.cell)
        }
    }
    
    func toNRProto() -> AlsProto_Nr5GCell {
        AlsProto_Nr5GCell.with {
            $0.mcc = Int32(self.country)
            $0.mnc = Int32(self.network)
            $0.tacID = Int32(self.area)
            $0.cellID = Int64(self.cell)
        }
    }
    
    func toCDMAProto() -> AlsProto_CdmaCell {
        AlsProto_CdmaCell.with {
            $0.mcc = Int32(self.country)
            $0.sid = Int32(self.network)
            $0.nid = Int32(self.area)
            $0.bsid = Int32(self.cell)
        }
    }
}


/// The central access point for Apple's Location Service (ALS)
struct ALSClient {
    
    // https://swiftwithmajid.com/2022/04/06/logging-in-swift/
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ALSClient.self)
    )
    
    private let endpoint = URL(string: "https://gs-loc.apple.com/clls/wloc")!
    private let headers = [
        "User-Agent": "locationd/2420.8.11 CFNetwork/1206 Darwin/20.1.0",
        "Accept": "*/*",
        "Accept-Language": "en-us",
    ]
    private let serviceIdentifier = "com.apple.locationd"
    private let iOSVersion = "14.2.1.18B121"
    private let locale = "en_US"
    
    /// Request nearby celluluar cells from Apple's Location Service
    /// - Parameters:
    ///   - origin: the cell used as origin for the request, it doesn't require a location
    ///   - completion: called upon success with a list of nearby cells
    func requestCells(origin: ALSCell, completion: @escaping (Result<[ALSCell], Error>)->()) {
        let protoRequest = AlsProto_ALSLocationRequest.with {
            switch (origin.technology) {
            case .GSM:
                $0.gsmCells = [origin.toGsmProto()]
            case .SCDMA:
                $0.scdmaCells = [origin.toScdmaProto()]
            case .LTE:
                $0.lteCells = [origin.toLteProto()]
            case .NR:
                $0.nr5Gcells = [origin.toNRProto()]
            case .CDMA:
                $0.cdmaCells = [origin.toCDMAProto()]
            }
            $0.numberOfSurroundingCells = 0
            $0.numberOfSurroundingWifis = 1
            $0.surroundingWifiBands = [Int32(1)]
        }
        
        let data: Data;
        do {
            data = try protoRequest.serializedData()
        } catch {
            Self.logger.warning("Can't encode proto request: \(error)")
            completion(.failure(error))
            return
        }
        
        sendHttpRequest(protoData: data) { result in
            do {
                let protoResponse = try AlsProto_ALSLocationResponse(serializedData: try result.get())
                var cells: [ALSCell] = []
                cells.append(contentsOf: protoResponse.gsmCells.map {ALSCell(fromGsmProto: $0)})
                cells.append(contentsOf: protoResponse.scdmaCells.map {ALSCell(fromScdmaProto: $0)})
                cells.append(contentsOf: protoResponse.lteCells.map {ALSCell(fromLteProto: $0)})
                cells.append(contentsOf: protoResponse.nr5Gcells.map {ALSCell(fromNRProto: $0)})
                cells.append(contentsOf: protoResponse.cdmaCells.map {ALSCell(fromCdmaProto: $0)})
                completion(.success(cells))
            } catch {
                Self.logger.warning("Can't decode proto response: \(error)")
                completion(.failure(error))
                return
            }
        }
    }
    
    /// Send an HTTP request to Apple's Location Service.
    /// - Parameters:
    ///   - protoData: the encoded data of the protobuf request
    ///   - completion: called upon success with the binary protobuf data of the response
    private func sendHttpRequest(protoData: Data, completion: @escaping (Result<Data, Error>)->()) {
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
                Self.logger.warning("Client error: \(error)")
                completion(.failure(error))
                return
            }
            // Check if the HTTP response is okay
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                Self.logger.warning("Server error: \(String(describing: response))")
                completion(.failure(ALSClientError.httpStatus(response)))
                return
            }
            // Check the response body
            if let data = data {
                // If response data is provided, drop the first bytes because they also contain a binary TLV header in the format start + end + start + end + size, and invoke the callback.
                completion(.success(data.dropFirst(10)))
            } else {
                completion(.failure(ALSClientError.httpNoData(response)))
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
            Self.logger.warning("Failed to pack string '\(string)' into bytes")
        }
        
        return self.packLength(data.count) + data
    }
    
    /// Pack the given integer (length value) into a signed short (2 bytes) with big endianness.
    /// - Parameter length: the length integer to be packed
    /// - Returns: length as 2 byte value
    private func packLength(_ length: Int) -> Data {
        if length > Int16.max {
            Self.logger.warning("Failed to pack length into bytes as it is too long: \(length) > \(Int16.max)")
            return Data()
        }
        
        var shortLength = Int16(length).bigEndian
        // https://stackoverflow.com/a/43247959
        return Data(bytes: &shortLength, count: 2)
    }
    
}
