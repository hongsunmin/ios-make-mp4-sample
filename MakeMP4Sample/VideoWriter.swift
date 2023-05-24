//
//  VideoWriter.swift
//  MakeMP4Sample
//
//  Created by 201510003 on 2023/05/17.
//

import Foundation
import AVFoundation

class VideoWriter {
    
    var avAssetWriter: AVAssetWriter
    var avAssetWriterInput: AVAssetWriterInput
    
    var url: URL
    
    var fd: CMFormatDescription!
    var pts: CMTime = .zero
    var duration = CMTime(value: 33333333, timescale: 1000000000)
    
    init(formatDescription: CMFormatDescription) {
        fd = formatDescription
        avAssetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: fd)
        avAssetWriterInput.expectsMediaDataInRealTime = false
        do {
            let directory = try VideoWriter.directoryForNewVideo()
            url = directory.appendingPathComponent(UUID.init().uuidString.appending(".mp4"))
            avAssetWriter = try AVAssetWriter(url: url, fileType: AVFileType.mp4)
            avAssetWriter.add(avAssetWriterInput)
            avAssetWriter.movieFragmentInterval = .invalid
        } catch {
            fatalError("Could not initialize avAssetWriter \(error)")
        }
    }
    
    func write(nalu: H264NALU) {
        guard let buffer = try? nalu.sampleBuffer(fd: fd, pts: pts) else {
            Log.e("Cound not make sampleBuffer")
            return
        }
        
        if avAssetWriter.status == .unknown {
            avAssetWriter.startWriting()
            avAssetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
        }
        if avAssetWriterInput.isReadyForMoreMediaData {
            if avAssetWriterInput.append(buffer) {
                pts = CMTimeAdd(duration, pts)
            } else if let error = avAssetWriter.error {
                Log.e("Failed to append sample buffer: \(error)")
            }
        }
    }
    
    func write(nalu: H265NALU) {
        guard let buffer = try? nalu.sampleBuffer(fd: fd, pts: pts) else {
            Log.e("Cound not make sampleBuffer")
            return
        }
        
        if avAssetWriter.status == .unknown {
            avAssetWriter.startWriting()
            avAssetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
        }
        if avAssetWriterInput.isReadyForMoreMediaData {
            if avAssetWriterInput.append(buffer) {
                pts = CMTimeAdd(duration, pts)
            } else if let error = avAssetWriter.error {
                Log.e("Failed to append sample buffer: \(error)")
            }
        }
    }
    
    func stopWriting(completionHandler handler: @escaping (AVAssetWriter.Status) -> Void) {
        avAssetWriter.finishWriting {
            handler(self.avAssetWriter.status)
        }
    }
    
    static func directoryForNewVideo() throws -> URL {
        let videoDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("videos")
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        let dateDir = videoDir?.appendingPathComponent(formatter.string(from:Date()))
        try FileManager.default.createDirectory(atPath: (dateDir?.path)!, withIntermediateDirectories: true, attributes: nil)
        return dateDir!
    }
}
