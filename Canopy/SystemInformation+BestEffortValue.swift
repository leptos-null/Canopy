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
            
            let decodedValue: BestEffortValue? = rawBytes.withUnsafeBytes { ptr in
                if let value = BestEffortValue.signedInteger(from: ptr, as: Int8.self) { return value }
                if let value = BestEffortValue.signedInteger(from: ptr, as: Int16.self) { return value }
                if let value = BestEffortValue.signedInteger(from: ptr, as: Int32.self) { return value }
                if let value = BestEffortValue.signedInteger(from: ptr, as: Int64.self) { return value }
                return nil
            }
            return decodedValue ?? .opaque(rawBytes)
        case .unsignedInteger:
            if rawBytes.isEmpty {
                return .unsignedInteger(0)
            }
            
            let decodedValue: BestEffortValue? = rawBytes.withUnsafeBytes { ptr in
                if let value = BestEffortValue.unsignedInteger(from: ptr, as: UInt8.self) { return value }
                if let value = BestEffortValue.unsignedInteger(from: ptr, as: UInt16.self) { return value }
                if let value = BestEffortValue.unsignedInteger(from: ptr, as: UInt32.self) { return value }
                if let value = BestEffortValue.unsignedInteger(from: ptr, as: UInt64.self) { return value }
                return nil
            }
            return decodedValue ?? .opaque(rawBytes)
        case .opaque:
            return .opaque(rawBytes)
        }
    }
}

private extension SystemInformation.BestEffortValue {
    static func signedInteger<T>(from buffer: UnsafeRawBufferPointer, as type: T.Type) -> Self? where T: FixedWidthInteger, T: SignedInteger {
        guard (buffer.count == MemoryLayout<T>.size) else { return nil }
        return .signedInteger(Int(buffer.load(as: T.self)))
    }
    
    static func unsignedInteger<T>(from buffer: UnsafeRawBufferPointer, as type: T.Type) -> Self? where T: FixedWidthInteger, T: UnsignedInteger {
        guard (buffer.count == MemoryLayout<T>.size) else { return nil }
        return .unsignedInteger(UInt(buffer.load(as: T.self)))
    }
}
