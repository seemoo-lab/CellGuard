//
//  VerificationStateLogEntries.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.06.24.
//

import SwiftUI

private func doubleString(_ value: Double, maxDigits: Int = 2) -> String {
    return String(format: "%.\(maxDigits)f", value)
}

// See: https://stackoverflow.com/a/35120978
private func coordinateToDMS(latitude: Double, longitude: Double) -> (latitude: String, longitude: String) {
    let latDegrees = abs(Int(latitude))
    let latMinutes = abs(Int((latitude * 3600).truncatingRemainder(dividingBy: 3600) / 60))
    let latSeconds = Double(abs((latitude * 3600).truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60)))

    let lonDegrees = abs(Int(longitude))
    let lonMinutes = abs(Int((longitude * 3600).truncatingRemainder(dividingBy: 3600) / 60))
    let lonSeconds = Double(abs((longitude * 3600).truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60) ))

    return (String(format: "%d° %d' %.4f\" %@", latDegrees, latMinutes, latSeconds, latitude >= 0 ? "N" : "S"),
            String(format: "%d° %d' %.4f\" %@", lonDegrees, lonMinutes, lonSeconds, longitude >= 0 ? "E" : "W"))
}

struct VerificationStateLogEntryView: View {

    @ObservedObject var logEntry: VerificationLog
    let stage: VerificationStage?

    var body: some View {
        Group {
            Section(header: Text("Stage: \(stage?.name ?? "ID \(logEntry.stageId)") (\(logEntry.stageNumber))"), footer: Text(stage?.description ?? "")) {
                CellDetailsRow("Status", "Completed")
                CellDetailsRow("Points", "\(logEntry.pointsAwarded) / \(logEntry.pointsMax)", color: pointsColor)
                CellDetailsRow("Duration", "\(doubleString(logEntry.duration, maxDigits: 4))s")
                if let relatedALSCell = logEntry.relatedCellALS {
                    NavigationLink {
                        LogRelatedALSCellView(alsCell: relatedALSCell)
                    } label: {
                        Text("Related ALS Cell")
                    }
                }
                if let relatedUserLocation = logEntry.relatedLocationUser {
                    NavigationLink {
                        LogRelatedUserLocationView(userLocation: relatedUserLocation)
                    } label: {
                        Text("Related User Location")
                    }
                }

                if let relatedALSCell = logEntry.relatedCellALS, let relatedUserLocation = logEntry.relatedLocationUser {
                    NavigationLink {
                        LogRelatedDistanceView(alsCell: relatedALSCell, userLocation: relatedUserLocation)
                    } label: {
                        Text("Related Distance")
                    }
                }

                if let relatedARIPackets = logEntry.relatedPacketARI?.compactMap({$0 as? PacketARI}), relatedARIPackets.count > 0 {
                    NavigationLink {
                        LogRelatedPacketsView(packets: relatedARIPackets)
                    } label: {
                        Text("Related ARI Packets")
                    }
                }
                if let relatedQMIPackets = logEntry.relatedPacketQMI?.compactMap({$0 as? PacketQMI}), relatedQMIPackets.count > 0 {
                    NavigationLink {
                        LogRelatedPacketsView(packets: relatedQMIPackets)
                    } label: {
                        Text("Related QMI Packets")
                    }
                }
            }
        }
    }

    var pointsColor: Color? {
        if logEntry.pointsMax == 0 {
            return nil
        }

        if logEntry.pointsAwarded == 0 {
            return .red
        } else if logEntry.pointsAwarded < logEntry.pointsMax {
            return .orange
        }

        return nil
    }
}

private struct LogRelatedALSCellView: View {

    let alsCell: CellALS

    var body: some View {
        let techFormatter = CellTechnologyFormatter.from(technology: alsCell.technology)

        List {
            Section(header: Text("Identification")) {
                CellDetailsRow("Technology", alsCell.technology ?? "Unknown")
                CellDetailsRow(techFormatter.country(), alsCell.country)
                CellDetailsRow(techFormatter.network(), alsCell.network)
                CellDetailsRow(techFormatter.area(), alsCell.area)
                CellDetailsRow(techFormatter.cell(), alsCell.cell)
            }

            if let importedDate = alsCell.imported {
                Section(header: Text("Date & Time")) {
                    CellDetailsRow("Queried at", mediumDateTimeFormatter.string(from: importedDate))
                }
            }
            if let alsLocation = alsCell.location {
                Section(header: Text("Location")) {
                    let (latitude, longitude) = coordinateToDMS(latitude: alsLocation.latitude, longitude: alsLocation.longitude)
                    CellDetailsRow("Latitude", latitude)
                    CellDetailsRow("Longitude", longitude)
                    CellDetailsRow("Accuracy", "± \(alsLocation.horizontalAccuracy)m")
                    CellDetailsRow("Reach", "\(alsLocation.reach)m")
                    CellDetailsRow("Score", alsLocation.score)
                }
            }

            Section(header: Text("Cell Properties")) {
                CellDetailsRow("\(techFormatter.frequency())", alsCell.frequency)
                CellDetailsRow("Physical Cell ID", alsCell.physicalCell)
            }
        }
        .navigationTitle("Related ALS Cell")
    }

}

private struct LogRelatedUserLocationView: View {

    let userLocation: LocationUser

    var body: some View {
        let (userLatitudeStr, userLongitudeStr) = coordinateToDMS(latitude: userLocation.latitude, longitude: userLocation.longitude)

        List {
            Section(header: Text("3D Position")) {
                CellDetailsRow("Latitude", userLatitudeStr)
                CellDetailsRow("Longitude", userLongitudeStr)
                CellDetailsRow("Horizontal Accuracy", "± \(doubleString(userLocation.horizontalAccuracy)) m")
                CellDetailsRow("Altitude", "\(doubleString(userLocation.altitude)) m")
                CellDetailsRow("Vertical Accuracy", "± \(doubleString(userLocation.verticalAccuracy)) m")
            }

            Section(header: Text("Speed")) {
                CellDetailsRow("Speed", "\(doubleString(userLocation.speed)) m/s")
                CellDetailsRow("Speed Accuracy", "± \(doubleString(userLocation.speedAccuracy)) m/s")
            }

            Section(header: Text("Metadata")) {
                CellDetailsRow("App in Background?", "\(userLocation.background)")
                if let collected = userLocation.collected {
                    CellDetailsRow("Recorded at", mediumDateTimeFormatter.string(from: collected))
                }
            }
        }
        .navigationTitle("Related User Location")
    }

}

private struct LogRelatedDistanceView: View {

    let alsCell: CellALS
    let userLocation: LocationUser
    @State var distance: CellLocationDistance?

    // TODO: Compute distance async

    var body: some View {
        List {
            if let distance = distance {
                CellDetailsRow("Distance", "\(doubleString(distance.distance / 1000.0)) km")
                CellDetailsRow("Corrected Distance", "\(doubleString(distance.correctedDistance() / 1000.0)) km")
                CellDetailsRow("Percentage of Trust", "\(doubleString((1 - distance.score()) * 100.0)) %")
            } else {
                Text("Calculating Distance")
            }
        }
        .navigationTitle("Related Distance")
        .onAppear {
            if let alsLocation = alsCell.location {
                distance = CellLocationDistance.distance(userLocation: userLocation, alsLocation: alsLocation)
            }
        }
    }

}

private struct LogRelatedPacketsView: View {

    let packets: [any Packet]

    var body: some View {
        List(packets, id: \.id) { packet in
            NavigationLink {
                if let qmiPacket = packet as? PacketQMI {
                    PacketQMIDetailsView(packet: qmiPacket)
                } else if let ariPacket = packet as? PacketARI {
                    PacketARIDetailsView(packet: ariPacket)
                }
            } label: {
                PacketCell(packet: packet, customInfo: customInfo(packet))
            }
        }
        .navigationTitle("Related Packets")
    }

    // TODO: Compute the custom info async

    func customInfo(_ packet: any Packet) -> Text? {
        if let qmiPacket = packet as? PacketQMI {
            if PacketConstants.qmiSignalIndication == qmiPacket.indication
                && PacketConstants.qmiSignalDirection.rawValue == qmiPacket.direction
                && PacketConstants.qmiSignalService == qmiPacket.service
                && PacketConstants.qmiSignalMessage == qmiPacket.message,
               let data = qmiPacket.data,
               let parsedPacket = try? ParsedQMIPacket(nsData: data),
               let parsedSignalInfo = try? ParsedQMISignalInfoIndication(qmiPacket: parsedPacket) {

                // So far we have seen no packet that contains NR & LTE signal strengths at the same time,
                // but we've encountered multiple NR packets that do not contain any signal info.
                var texts: [String] = []

                if let nr = parsedSignalInfo.nr, nr.rsrp != nil && nr.rsrq != nil && nr.snr != nil {
                    texts.append("NR: rsrp = \(formatSignalStrength(nr.rsrp, unit: "dBm")), rsrq = \(formatSignalStrength(nr.rsrq, unit: "dB")), snr = \(formatSignalStrength(nr.snr, unit: "dB"))")
                } else if let lte = parsedSignalInfo.lte {
                    texts.append("LTE: rssi = \(formatSignalStrength(lte.rssi, unit: "dBm")), rsrp = \(formatSignalStrength(lte.rsrp, unit: "dBm")), rsrq = \(formatSignalStrength(lte.rsrq, unit: "dB")), snr = \(formatSignalStrength(lte.snr, unit: "dB"))")
                } else if let gsmRssi = parsedSignalInfo.gsm {
                    texts.append("GSM: rssi = \(formatSignalStrength(gsmRssi, unit: "dBm"))")
                }

                if texts.count > 0 {
                    return Text(texts.joined(separator: "\n"))
                        .font(.system(size: 14))
                }
            }
        } else if let ariPacket = packet as? PacketARI {
            if PacketConstants.ariSignalDirection.rawValue == ariPacket.direction
                && PacketConstants.ariSignalGroup == ariPacket.group
                && PacketConstants.ariSignalType == ariPacket.type,
               let data = ariPacket.data,
               let parsedPacket = try? ParsedARIPacket(data: data),
               let parsedSignalInfo = try? ParsedARIRadioSignalIndication(ariPacket: parsedPacket) {
                let ssr = (Double(parsedSignalInfo.signalStrength) / Double(parsedSignalInfo.signalStrengthMax)) * 100
                let sqr = (Double(parsedSignalInfo.signalQuality) / Double(parsedSignalInfo.signalQualityMax)) * 100
                return Text("ssr = \(doubleString(ssr))%, sqr = \(doubleString(sqr))%")
                    .font(.system(size: 14))
            }
        }

        return nil
    }

    func formatSignalStrength(_ number: (any FixedWidthInteger)?, unit: String) -> String {
        if let number = number {
            // Casting number to String to remove the thousand dot
            // See: https://stackoverflow.com/a/64492495
            return "\(String(number))\(unit)"
        } else {
            return "N/A"
        }
    }

}
