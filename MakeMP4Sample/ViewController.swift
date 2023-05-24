//
//  ViewController.swift
//  MakeMP4Sample
//
//  Created by 201510003 on 2023/05/17.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {
    
    enum CodeType {
        case H264
        case H265
    }
    
    private var sps: H264NALU?
    private var pps: H264NALU?
    
    private var vps_h265: H265NALU?
    private var sps_h265: H265NALU?
    private var pps_h265: H265NALU?
    
    var videoWriter: VideoWriter!
    
    var codeType: CodeType = .H264
    var worker: Thread?
    let maxFrameCount = 360
    var frameCount = 0

    @IBOutlet
    weak var activityIndicatorView: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        changeActivityIndicator(visibility: false)
    }
    
    @IBAction
    func codeTypeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1: codeType = .H265
        default: codeType = .H264
        }
    }
    
    @IBAction
    func touchedMakeMP4(_ sender: Any) {
        worker = Thread { [self] in
            changeActivityIndicator(visibility: true)
            initialize()
            if codeType == .H265 {
                self.processH265()
            } else {
                self.processH264()
            }
            
            changeActivityIndicator(visibility: false)
        }
        worker?.start()
    }
}

private extension ViewController {
    
    func initialize() {
        sps = nil
        pps = nil
        vps_h265 = nil
        sps_h265 = nil
        pps_h265 = nil
        videoWriter = nil
        frameCount = 0
    }
    
    func readH264NalData(_ fileHandle: FileHandle, offset: UInt64, nalu: inout H264NALU) -> Int {
        let nalStartCode: [UInt8] = [0, 0, 0, 1]
        
        let bufferCap = 512 * 1024
        fileHandle.seek(toFileOffset: offset)
        let data = fileHandle.readData(ofLength: bufferCap)
        var packetSize = -1
        data.withUnsafeBytes { p in
            var bufferBegin = p.startIndex + 4
            let bufferEnd = p.endIndex
            
            while bufferBegin <= bufferEnd {
                if p[bufferBegin] == 0x01 {
                    if memcmp(p.baseAddress?.advanced(by: bufferBegin - 3),
                              nalStartCode, 4) == 0 {
                        packetSize = bufferBegin - 3
                        Log.d("nalu size is \(packetSize)");
                        let pointer = UnsafePointer<UInt8>(
                            p.baseAddress!.advanced(by: 4)
                                .assumingMemoryBound(to: UInt8.self)
                        )
                        nalu = H264NALU(pointer, length: packetSize - 4)
                        break
                    }
                }
                
                bufferBegin += 1
            }
        }
        return packetSize
    }
    
    func processH264() {
        do {
            let fileName = "test.h264"
            let tokens = fileName.split(separator: ".")
            let name = String(tokens[0])
            let ext = String(tokens[1])
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
                Log.e("\(fileName) file not found")
                return
            }
            
            let fileHandle = try FileHandle(forReadingFrom: url)
            
            var offset: UInt64 = 0
            var bufferSize = 0
            repeat {
                var nalu = H264NALU()
                bufferSize = readH264NalData(fileHandle, offset: offset, nalu: &nalu)
                Log.d("read offset \(offset), size:\(bufferSize), \(nalu.naluTypeName)");
                if bufferSize > 0 {
                    switch nalu.type {
                    case .SPS:
                        self.sps = nalu
                    case .PPS:
                        self.pps = nalu
                        if videoWriter == nil {
                            let parameterSetPointers : [UnsafePointer<UInt8>] = [sps!.buffer.baseAddress!, pps!.buffer.baseAddress!]
                            let parameterSetSizes = [sps!.buffer.count, pps!.buffer.count]
                            var formatDescription: CMFormatDescription?
                            let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                                allocator: kCFAllocatorDefault,
                                parameterSetCount: 2,
                                parameterSetPointers: parameterSetPointers,
                                parameterSetSizes: parameterSetSizes,
                                nalUnitHeaderLength: 4,
                                formatDescriptionOut: &formatDescription
                            )
                            if status != noErr {
                                throw H26xError.CMVideoFormatDescriptionCreateFromH26xParameterSets(status)
                            }
                            
                            videoWriter = VideoWriter(formatDescription: formatDescription!)
                        }
                    case .IDR, .CodedSlice:
                        videoWriter.write(nalu: nalu)
                        frameCount += 1
                    default:
                        Log.e("Unprocessed types \(nalu.naluTypeName)")
                        break
                    }
                }
                
                offset += UInt64(bufferSize)

                Thread.sleep(forTimeInterval: 0.1)
            } while bufferSize > 0 && frameCount < maxFrameCount
        } catch {
            Log.e(error)
        }
        
        videoWriter.stopWriting { [self] status in
            Log.i("Done writing MP4")
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: videoWriter.url.path)
                let fileSize = attr[FileAttributeKey.size] as! UInt64
                Log.d("MP4 file size = \(fileSize)")
                savePhotoLibrary(atFileURL: videoWriter.url)
            } catch {
                Log.e(error)
            }
        }
    }
    
    func readH265NalData(_ fileHandle: FileHandle, offset: UInt64, nalu: inout H265NALU) -> Int {
        let nalStartCode: [UInt8] = [0, 0, 0, 1]
        
        let bufferCap = 512 * 1024
        fileHandle.seek(toFileOffset: offset)
        let data = fileHandle.readData(ofLength: bufferCap)
        var packetSize = -1
        data.withUnsafeBytes { p in
            var bufferBegin = p.startIndex + 4
            let bufferEnd = p.endIndex
            
            while bufferBegin <= bufferEnd {
                if p[bufferBegin] == 0x01 {
                    if memcmp(p.baseAddress?.advanced(by: bufferBegin - 3),
                              nalStartCode, 4) == 0 {
                        packetSize = bufferBegin - 3
                        Log.d("nalu size is \(packetSize)");
                        let pointer = UnsafePointer<UInt8>(
                            p.baseAddress!.advanced(by: 4)
                                .assumingMemoryBound(to: UInt8.self)
                        )
                        nalu = H265NALU(pointer, length: packetSize - 4)
                        break
                    }
                }
                
                bufferBegin += 1
            }
        }
        return packetSize
    }
    
    func processH265() {
        do {
            let fileName = "test.hevc"
            let tokens = fileName.split(separator: ".")
            let name = String(tokens[0])
            let ext = String(tokens[1])
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
                Log.e("\(fileName) file not found")
                return
            }
            
            let fileHandle = try FileHandle(forReadingFrom: url)
            
            var offset: UInt64 = 0
            var bufferSize = 0
            repeat {
                var nalu = H265NALU()
                bufferSize = readH265NalData(fileHandle, offset: offset, nalu: &nalu)
                Log.d("read offset \(offset), size:\(bufferSize), \(nalu.naluTypeName)");
                if bufferSize > 0 {
                    switch nalu.type {
                    case .VPS_NUT:
                        self.vps_h265 = nalu
                    case .SPS_NUT:
                        self.sps_h265 = nalu
                    case .PPS_NUT:
                        self.pps_h265 = nalu
                        if videoWriter == nil {
                            let parameterSetPointers : [UnsafePointer<UInt8>] = [
                                vps_h265!.buffer.baseAddress!,
                                sps_h265!.buffer.baseAddress!,
                                pps_h265!.buffer.baseAddress!
                            ]
                            let parameterSetSizes = [
                                vps_h265!.buffer.count,
                                sps_h265!.buffer.count,
                                pps_h265!.buffer.count
                            ]
                            var formatDescription: CMFormatDescription?
                            let status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                                allocator: kCFAllocatorDefault,
                                parameterSetCount: 3,
                                parameterSetPointers: parameterSetPointers,
                                parameterSetSizes: parameterSetSizes,
                                nalUnitHeaderLength: 4,
                                extensions: nil,
                                formatDescriptionOut: &formatDescription
                            )
                            if status != noErr {
                                throw H26xError.CMVideoFormatDescriptionCreateFromH26xParameterSets(status)
                            }

                            videoWriter = VideoWriter(formatDescription: formatDescription!)
                        }
                    case .PREFIX_SEI_NUT:
                        printHexDumpForBytes(bytes: nalu.buffer)
                    case .TRAIL_R, .IDR_N_LP, .CRA_NUT:
                        videoWriter.write(nalu: nalu)
                        frameCount += 1
                    default:
                        Log.e("Unprocessed types \(nalu.naluTypeName)")
                        break
                    }
                }
                
                offset += UInt64(bufferSize)

                Thread.sleep(forTimeInterval: 0.1)
            } while bufferSize > 0 && frameCount < maxFrameCount
        } catch {
            Log.e(error)
        }
        
        videoWriter.stopWriting { [self] status in
            Log.i("Done writing MP4")
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: videoWriter.url.path)
                let fileSize = attr[FileAttributeKey.size] as! UInt64
                Log.d("MP4 file size = \(fileSize)")
                savePhotoLibrary(atFileURL: videoWriter.url)
            } catch {
                Log.e(error)
            }
        }
    }
    
    func changeActivityIndicator(visibility: Bool) {
        let uiUpdate = { [weak self] in
            if visibility {
                self?.activityIndicatorView.isHidden = false
                self?.activityIndicatorView.startAnimating()
            } else {
                self?.activityIndicatorView.isHidden = true
                self?.activityIndicatorView.stopAnimating()
            }
        }
        
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                uiUpdate()
            }
        } else {
            uiUpdate()
        }
    }
    
    func savePhotoLibrary(atFileURL fileURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            }) { success, error in
                if success {
                    Log.i("Finished adding to the Photos app")
                } else {
                    Log.e("Failed to add to Photos app. reason:\(error)")
                }
            }
        }
    }
}
