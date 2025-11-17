//
//  BestEffortValueView.swift
//  Canopy
//
//  Created by Leptos on 11/17/25.
//

import SwiftUI

struct BestEffortValueView: View {
    let value: SystemInformation.BestEffortValue
    
    var body: some View {
        switch value {
        case .string(let string):
            Text(string)
        case .signedInteger(let int):
            Text(int, format: .number)
        case .unsignedInteger(let uint):
            Text(uint, format: .number)
        case .opaque(let array):
            Text("opaque - \(array.count, format: .number) bytes")
        }
    }
}
