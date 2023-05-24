//
//  H265NALU.swift
//  MakeMP4Sample
//
//  Created by 201510003 on 2023/05/18.
//

import Foundation
import AVFoundation

enum H265NALUType : UInt8, CustomStringConvertible {
    case TRAIL_N = 0
    case TRAIL_R = 1
    case TSA_N = 2
    case TSA_R = 3
    case STSA_N = 4
    case STSA_R = 5
    case RADL_N = 6
    case RADL_R = 7
    case RASL_N = 8
    case RASL_R = 9
    //10-15 [reserved]
    case BLA_W_LP = 16
    case BLA_W_RADL = 17
    case BLA_N_LP = 18
    case IDR_W_RADL = 19
    case IDR_N_LP = 20
    case CRA_NUT = 21
    //22-31 [reserved]
    case VPS_NUT = 32
    case SPS_NUT = 33
    case PPS_NUT = 34
    case AUD_NUT = 35
    case EOS_NUT = 36
    case EOB_NUT = 37
    case FD_NUT = 38
    case PREFIX_SEI_NUT = 39
    case SUFFIX_SEI_NUT = 40
    // 41-47 [reserved]
    // 48-63 [unspecified]
    case Undefined = 63

    var description : String {
        switch self {
        case .TRAIL_N: return "TRAIL_N"
        case .TRAIL_R: return "TRAIL_R"
        case .TSA_N: return "TSA_N"
        case .TSA_R: return "TSA_R"
        case .STSA_N: return "STSA_N"
        case .STSA_R: return "STSA_R"
        case .RADL_N: return "RADL_N"
        case .RADL_R: return "RADL_R"
        case .RASL_N: return "RASL_N"
        case .RASL_R: return "RASL_R"
        case .BLA_W_LP: return "BLA_W_LP"
        case .BLA_W_RADL: return "BLA_W_RADL"
        case .BLA_N_LP: return "BLA_N_LP"
        case .IDR_W_RADL: return "IDR_W_RADL"
        case .IDR_N_LP: return "IDR_N_LP"
        case .CRA_NUT: return "CRA_NUT"
        case .VPS_NUT: return "VPS_NUT"
        case .SPS_NUT: return "SPS_NUT"
        case .PPS_NUT: return "PPS_NUT"
        case .AUD_NUT: return "AUD_NUT"
        case .EOS_NUT: return "EOS_NUT"
        case .EOB_NUT: return "EOB_NUT"
        case .FD_NUT: return "FD_NUT"
        case .PREFIX_SEI_NUT: return "PREFIX_SEI_NUT"
        case .SUFFIX_SEI_NUT: return "SUFFIX_SEI_NUT"
        default: return "Undefined"
        }
    }
}

class H265NALU {
    
    private var bbuffer: CMBlockBuffer!
    private var bblen = [UInt8](repeating: 0, count: 8)
    
    public let buffer: UnsafeBufferPointer<UInt8>
    public let type: H265NALUType
    
    public var naluTypeName: String {
        return type.description
    }
    
    init(_ buffer: UnsafeBufferPointer<UInt8>) {
        var type: H265NALUType?
        self.buffer = buffer
        if buffer.count > 0 {
            let hb = buffer.withUnsafeBytes { p -> UInt16 in
                p.load(as: UInt16.self)
            }
            if ((hb >> 15) & 0x01) == 0 { // zerobit
                type = H265NALUType(rawValue: UInt8((hb >> 0) & 0x7e) >> 1)
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
