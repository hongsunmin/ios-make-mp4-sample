//
//  H26xError.swift
//  MakeMP4Sample
//
//  Created by 201510003 on 2023/05/17.
//

import Foundation

enum H26xError: Error, CustomStringConvertible {
    case CMBlockBufferCreateWithMemoryBlock(OSStatus)
    case CMBlockBufferAppendBufferReference(OSStatus)
    case CMSampleBufferCreateReady(OSStatus)
    case CMVideoFormatDescriptionCreateFromH26xParameterSets(OSStatus)
    
    var description: String {
        switch self {
        case let .CMBlockBufferCreateWithMemoryBlock(status):
            return "H26xError.CMBlockBufferCreateWithMemoryBlock(\(status))"
        case let .CMBlockBufferAppendBufferReference(status):
            return "H26xError.CMBlockBufferAppendBufferReference(\(status))"
        case let .CMSampleBufferCreateReady(status):
            return "H26xError.CMSampleBufferCreateReady(\(status))"
        case let .CMVideoFormatDescriptionCreateFromH26xParameterSets(status):
            return "H26xError.CMVideoFormatDescriptionCreateFromH26xParameterSets(\(status))"
        }
    }
}
