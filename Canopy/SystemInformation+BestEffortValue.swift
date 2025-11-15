//
//  SystemInformation+BestEffortValue.swift
//  Canopy
//
//  Created by Leptos on 11/15/25.
//

import Foundation

extension SystemInformation {
    enum BestEffortValue {
        case string(String)
        
        case signedInteger(Int)
        case unsignedInteger(UInt)
        
        case opaque([UInt8])
    }
    
    static func bestEffortValue(for rawBytes: [UInt8], metadata: ObjectMetadata?) -> BestEffortValue {
        guard let metadata else {
            return .opaque(rawBytes)
        }
        
        switch metadata.typeHeuristic {
        case .string:
            let value = String(nullTerminatedUTF8: rawBytes)
            return .string(value)
        case .signedInteger:
            if rawBytes.isEmpty {
                return .signedInteger(0)
            }
            
            let byteCount = rawBytes.count
            let decodedValue: BestEffortValue? = rawBytes.withUnsafeBytes { ptr in
                switch byteCount {
                case MemoryLayout<Int8>.size:
                    return BestEffortValue.signedInteger(Int(ptr.load(as: Int8.self)))
                case MemoryLayout<Int16>.size:
                    return BestEffortValue.signedInteger(Int(ptr.load(as: Int16.self)))
                case MemoryLayout<Int32>.size:
                    return BestEffortValue.signedInteger(Int(ptr.load(as: Int32.self)))
                case MemoryLayout<Int64>.size:
                    return BestEffortValue.signedInteger(Int(ptr.load(as: Int64.self)))
                default:
                    return nil
                }
            }
            return decodedValue ?? .opaque(rawBytes)
        case .unsignedInteger:
            if rawBytes.isEmpty {
                return .unsignedInteger(0)
            }
            
            let byteCount = rawBytes.count
            let decodedValue: BestEffortValue? = rawBytes.withUnsafeBytes { ptr in
                switch byteCount {
                case MemoryLayout<UInt8>.size:
                    return BestEffortValue.unsignedInteger(UInt(ptr.load(as: UInt8.self)))
                case MemoryLayout<UInt16>.size:
                    return BestEffortValue.unsignedInteger(UInt(ptr.load(as: UInt16.self)))
                case MemoryLayout<UInt32>.size:
                    return BestEffortValue.unsignedInteger(UInt(ptr.load(as: UInt32.self)))
                case MemoryLayout<UInt64>.size:
                    return BestEffortValue.unsignedInteger(UInt(ptr.load(as: UInt64.self)))
                default:
                    return nil
                }
            }
            return decodedValue ?? .opaque(rawBytes)
        case .opaque:
            return .opaque(rawBytes)
        }
    }
}
