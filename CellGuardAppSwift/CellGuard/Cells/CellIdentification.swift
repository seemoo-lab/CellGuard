//
//  CellIdentification.swift
//  CellGuard
//
//  Created by Lukas Arnold on 19.10.24.
//

import Foundation

struct CellIdentification {
    
    // https://cidresolver.truong.fi
    
    public static func gsm(cellId: Int64) -> (bts: Int64, sector: Int64) {
        // https://www.erlang.com/topic/1-686/#post-36217
        // https://en.wikipedia.org/wiki/GSM_Cell_ID
        
        // Base Transceiver Station -> First five numbers
        let btsId = cellId / 10
        
        // Sector ID -> Last number
        // 0 = omnidirectional antenna
        // 1, 2, 3 = bisector or trisector antennas
        let sectorId = cellId % 10
        return (btsId, sectorId)
    }

    public static func umts(lcid: Int64) -> (rnc: Int64, cid: Int64) {
        // https://wiki.opencellid.org/wiki/Public:CellID
        // https://en.wikipedia.org/wiki/GSM_Cell_ID#:~:text=In%20UMTS%2C%20there%20is%20a,is%20just%20the%20Cell%20ID

        // UTRAN Cell ID (LCID) -> 28 Bits
        
        // Radio Network Controller (RNC) -> 12 Bits
        let rnc = lcid / (1 << 16)
        // Cell ID (CID) -> 16 Bits
        let cid = lcid % (1 << 16)
        
        return (rnc, cid)
    }

    public static func lte(eci: Int64) -> (eNodeB: Int64, sector: Int64) {
        // https://5g-tools.com/4g-lte-cell-id-eci-calculator/
        // https://telcomaglobal.com/p/formula-cell-id-eci-lte-networks
        // https://www.cellmapper.net/enbid?net=LTE
        
        // E-UTRAN Cell Identity (ECI) -> 28 Bits
        
        // eNodeB ID (Base Station) -> 20 Bits
        let eNodeB = eci / (1 << 8)
        // Sector ID -> 8 Bits
        let sector = eci % (1 << 8)
        
        return (eNodeB, sector)
    }
    
    public static  func nr(nci: Int64, sectorIdLength: Int) -> (gNodeB: Int64, sector: Int64) {
        // https://5g-tools.com/5g-nr-cell-identity-nci-calculator/

        // NR Cell Identity (NCI) -> 36 Bits
        
        // gNodeB ID (Base Station) -> 22..32 Bits (customizable)
        let gNodeBID: Int64 = nci / (1 << sectorIdLength)
        
        
        // Sector ID -> 4..14 Bits
        let sectorId = nci % (1 << sectorIdLength)
        
        return (gNodeBID, sectorId)
    }
}
