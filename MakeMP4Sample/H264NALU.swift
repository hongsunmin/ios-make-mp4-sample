//
//  NALU.swift
//  MakeMP4Sample
//
//  Created by 201510003 on 2023/05/17.
//

import Foundation
import AVFoundation

enum H264NALUType : UInt8, CustomStringConvertible {
    case Undefined = 0
    case CodedSlice = 1
    case DataPartitionA = 2
    case DataPartitionB = 3
    case DataPartitionC = 4
    case IDR = 5 // (Instantaneous Decoding Refresh) Picture
    case SEI = 6 // (Supplemental Enhancement Information)
    case SPS = 7 // (Sequence Parameter Set)
    case PPS = 8 // (Picture Parameter Set)
    case AccessUnitDelimiter = 9
    case EndOfSequence = 10
    case EndOfStream = 11
    case FilterData = 12
    // 13-23 [extended]
    // 24-31 [unspecified]

    var description : String {
        switch self {
        case .CodedSlice: return "CodedSlice"
        case .DataPartitionA: return "DataPartitionA"
        case .DataPartitionB: return "DataPartitionB"
        case .DataPartitionC: return "DataPartitionC"
        case .IDR: return "IDR"
        case .SEI: return "SEI"
        case .SPS: return "SPS"
        case .PPS: return "PPS"
        case .AccessUnitDelimiter: return "AccessUnitDelimiter"
        case .EndOfSequence: return "EndOfSequence"
        case .EndOfStream: return "EndOfStream"
        case .FilterData: return "FilterData"
        default: return "Undefined"
        }
    }
}

class H264NALU {
    
    private var bbuffer: CMBlockBuffer!
    private var bblen = [UInt8](repeating: 0, count: 8)
    
    public let buffer: UnsafeBufferPointer<UInt8>
    public let type: H264NALUType
    
    public var naluTypeName: String {
        return type.description
    }
    
    init(_ buffer: UnsafeBufferPointer<UInt8>) {
        var type: H264NALUType?
        self.buffer = buffer
        if buffer.count > 0 {
            let hb = buffer[0]
            if ((hb >> 7) & 0x01) == 0 { // zerobit
                type = H264NALUType(rawValue: (hb >> 0) & 0x1f)
            }
        }

        self.type = type == nil ? .Undefined : type!
    }
    
    deinit {
    }
    
    convenience init() {
        self.init(UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bitPattern: 0), count: 0))
    }
    
    convenience init(_ bytes: UnsafePointer<UInt8>, length: Int) {
        self.init(UnsafeBufferPointer<UInt8>(start: bytes, count: length))
    }
    
    func blockBuffer() throws -> CMBlockBuffer {
        if bbuffer != nil {
            return bbuffer
        }
        
        var biglen = CFSwapInt32HostToBig(UInt32(buffer.count))
        memcpy(&bblen, &biglen, 4)
        var _buffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: &bblen,
            blockLength: 4,
            blockAllocator: kCFAllocatorNull,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: 4,
            flags: 0,
            blockBufferOut: &_buffer
        )
        if status != noErr {
            throw H26xError.CMBlockBufferCreateWithMemoryBlock(status)
        }
        var bufferData: CMBlockBuffer?
        status = CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: UnsafeMutablePointer<UInt8>(mutating: buffer.baseAddress),
            blockLength: buffer.count,
            blockAllocator: kCFAllocatorNull,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: buffer.count,
            flags: 0,
            blockBufferOut: &bufferData
        )
        if status != noErr {
            throw H26xError.CMBlockBufferCreateWithMemoryBlock(status)
        }

        status = CMBlockBufferAppendBufferReference(
            _buffer!,
            targetBBuf: bufferData!,
            offsetToData: 0,
            dataLength: buffer.count,
            flags: 0
        )
        if status != noErr {
            throw H26xError.CMBlockBufferAppendBufferReference(status)
        }
        
        bbuffer = _buffer
        return bbuffer
    }
    
    func sampleBuffer(fd: CMVideoFormatDescription, pts: CMTime) throws -> CMSampleBuffer {
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        timingInfo.decodeTimeStamp = .invalid
        timingInfo.presentationTimeStamp = pts
        timingInfo.duration = .invalid
        let status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: try blockBuffer(),
            formatDescription: fd,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: [buffer.count + 4],
            sampleBufferOut: &sampleBuffer
        )
        if status != noErr {
            throw H26xError.CMSampleBufferCreateReady(status)
        }
        return sampleBuffer!
    }
}
