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
    case noCells(Data)
}

struct ALSQueryLocation: Equatable, Hashable {
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
    
    func applyTo(location: ALSLocation) {
        location.latitude = latitude
        location.longitude = longitude
        location.horizontalAccuracy = Double(accuracy)
        location.reach = Int32(reach)
        location.score = Int32(score)
    }
}

struct ALSQueryCell: CustomStringConvertible, Equatable, Hashable {
    var technology: ALSTechnology
    
    var country: Int32 = 0
    var network: Int32 = 0
    var area: Int32 = 0
    var cell: Int64 = 0
    
    var location: ALSQueryLocation? = nil
    var frequency: Int32? = nil
    
    func hasCellId() -> Bool {
        return self.cell >= 0
    }
    
    func isValid() -> Bool {
        return location?.isValid() ?? false
    }
    
    init(technology: ALSTechnology, country: Int32, network: Int32, area: Int32, cell: Int64) {
        self.technology = technology
        self.country = country
        self.network = network
        self.area = area
        self.cell = cell
    }
    
    init(fromGsmProto proto: AlsProto_GsmCell) {
        self.technology = .GSM
        self.country = proto.mcc
        self.network = proto.mnc
        self.area = proto.lacID
        self.cell = proto.cellID
        self.location = ALSQueryLocation(fromProto: proto.location)
        self.frequency = proto.arfcn
    }
    
    init(fromScdmaProto proto: AlsProto_ScdmaCell) {
        self.technology = .SCDMA
        self.country = proto.mcc
        self.network = proto.mnc
        self.area = proto.lacID
        self.cell = Int64(proto.cellID)
        self.location = ALSQueryLocation(fromProto: proto.location)
        self.frequency = proto.arfcn
    }
    
    init(fromLteProto proto: AlsProto_LteCell) {
        self.technology = .LTE
        self.country = proto.mcc
        self.network = proto.mnc
        self.area = proto.tacID
        self.cell = Int64(proto.cellID)
        self.location = ALSQueryLocation(fromProto: proto.location)
        self.frequency = proto.uarfcn
    }
    
    init(fromNRProto proto: AlsProto_Nr5GCell) {
        self.technology = .NR
        self.country = proto.mcc
        self.network = proto.mnc
        self.area = proto.tacID
        self.cell = proto.cellID
        self.location = ALSQueryLocation(fromProto: proto.location)
        self.frequency = proto.nrarfcn
    }
    
    init(fromCdmaProto proto: AlsProto_CdmaCell) {
        self.technology = .CDMA
        self.country = proto.mcc
        self.network = proto.sid
        self.area = proto.nid
        self.cell = Int64(proto.bsid)
        self.location = ALSQueryLocation(fromProto: proto.location)
        self.frequency = proto.bandclass
    }
    
    
    func toGsmProto() -> AlsProto_GsmCell {
        AlsProto_GsmCell.with {
            $0.mcc = self.country
            $0.mnc = self.network
            $0.lacID = self.area
            $0.cellID = self.cell
        }
    }
    
    func toScdmaProto() -> AlsProto_ScdmaCell {
        AlsProto_ScdmaCell.with {
            $0.mcc = self.country
            $0.mnc = self.network
            $0.lacID = self.area
            $0.cellID = Int32(self.cell)
        }
    }
    
    func toLteProto() -> AlsProto_LteCell {
        AlsProto_LteCell.with {
            $0.mcc = self.country
            $0.mnc = self.network
            $0.tacID = self.area
            $0.cellID = Int32(self.cell)
        }
    }
    
    func toNRProto() -> AlsProto_Nr5GCell {
        AlsProto_Nr5GCell.with {
            $0.mcc = self.country
            $0.mnc = self.network
            $0.tacID = self.area
            $0.cellID = self.cell
        }
    }
    
    func toCDMAProto() -> AlsProto_CdmaCell {
        AlsProto_CdmaCell.with {
            $0.mcc = self.country
            $0.sid = self.network
            $0.nid = self.area
            $0.bsid = Int32(self.cell)
        }
    }
    
    func applyTo(alsCell: ALSCell) {
        alsCell.country = self.country
        alsCell.network = self.network
        alsCell.area = self.area
        alsCell.cell = self.cell
        
        alsCell.frequency = self.frequency ?? -1
        alsCell.technology = self.technology.rawValue
    }
    
    var description: String {
        "ALSQueryCell(technology=\(self.technology), country=\(self.country), network=\(self.network), " +
        "area=\(self.area), cell=\(self.cell), " +
        "location=\(String(describing: self.location)), frequency=\(String(describing: self.frequency)))"
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
    
    /// Request nearby cellular cells from Apple's Location Service
    /// - Parameters:
    ///   - origin: the cell used as origin for the request, it doesn't require a location
    ///   - completion: called upon success with a list of nearby cells
    func requestCells(origin: ALSQueryCell) async throws -> [ALSQueryCell] {
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
            $0.surroundingWifiBands = [1]
        }
        
        let data: Data;
        do {
            data = try protoRequest.serializedData()
        } catch {
            Self.logger.warning("Can't encode proto request: \(error)")
            throw error
        }
        
        do {
            let httpData = try await sendHttpRequest(protoData: data)
            let protoResponse = try AlsProto_ALSLocationResponse(serializedData: httpData)
            var cells: [ALSQueryCell] = []
            cells.append(contentsOf: protoResponse.gsmCells.map {ALSQueryCell(fromGsmProto: $0)})
            cells.append(contentsOf: protoResponse.scdmaCells.map {ALSQueryCell(fromScdmaProto: $0)})
            cells.append(contentsOf: protoResponse.lteCells.map {ALSQueryCell(fromLteProto: $0)})
            cells.append(contentsOf: protoResponse.nr5Gcells.map {ALSQueryCell(fromNRProto: $0)})
            cells.append(contentsOf: protoResponse.cdmaCells.map {ALSQueryCell(fromCdmaProto: $0)})
            if !cells.isEmpty {
                return cells
            } else {
                throw ALSClientError.noCells(httpData)
            }
        } catch {
            Self.logger.warning("Can't decode proto response: \(error)")
            throw error
        }
    }
    
    /// Send an HTTP request to Apple's Location Service.
    /// - Parameters:
    ///   - protoData: the encoded data of the Protocol Buffer request
    ///   - completion: called upon success with the binary Protocol Buffer data of the response
    private func sendHttpRequest(protoData: Data) async throws -> Data {
        // Why we escape the parameter completion? https://www.donnywals.com/what-is-escaping-in-swift/
        
        // First build a binary request header and then append the length and the binary of the protobuf request
        let body = self.buildRequestHeader() + self.packLength(protoData.count) + protoData
        
        // Create a POST request in Swift (https://stackoverflow.com/a/58356848)
        var request = URLRequest(url: self.endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.allHTTPHeaderFields = self.headers
        
        // Execute the HTTP request using GCD (https://developer.apple.com/documentation/foundation/url_loading_system/fetching_website_data_into_memory?language=objc)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                // Check if error is set and if yes execute block (https://stackoverflow.com/a/25193174)
                if let error = error {
                    Self.logger.warning("Client error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                // Check if the HTTP response is okay
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    Self.logger.warning("Server error: \(String(describing: response))")
                    continuation.resume(throwing: ALSClientError.httpStatus(response))
                    return
                }
                // Check the response body
                if let data = data {
                    if !data.isEmpty {
                        // If response data is provided, drop the first bytes because they also contain a binary TLV header in the format start + end + start + end + size, and invoke the callback.
                        continuation.resume(returning: data.dropFirst(10))
                    } else {
                        continuation.resume(throwing: ALSClientError.httpNoData(response))
                    }
                } else {
                    continuation.resume(throwing: ALSClientError.httpNoData(response))
                }
            }
            task.resume()
        }
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
