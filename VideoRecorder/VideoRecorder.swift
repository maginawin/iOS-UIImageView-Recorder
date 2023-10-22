//
//  VideoRecorder.swift
//  VideoRecorder
//
//  Created by 王文东 on 2023/10/15.
//

import UIKit
import AVFoundation
import CoreVideo

protocol VideoRecorderDataSource: NSObjectProtocol {
    func videoRecorderWillAddImage(_ recorder: VideoRecorder) -> UIImage
}

protocol VideoRecorderDelegate: NSObjectProtocol {
    
    func videoRecorder(_ recorder: VideoRecorder, didSaveVideoLength seconds: Int)
    
    func videoRecorderDidStopAuto(_ recorder: VideoRecorder)
}

class VideoRecorder {
    
    weak var dataSource: VideoRecorderDataSource?
    weak var delegate: VideoRecorderDelegate?
    
    // frame is 30
    var frame: Float = 1.0 / 30.0
    var frameMaxCount: Int = 3600 * 30 // 1 hour
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL!
    private var frameCount: Int = 0
    private var frameTimer: Timer?
    
    func startRecording(outputURL: URL, size: CGSize) {
        stopRecording()
        self.outputURL = outputURL
        do {
            guard let _ = dataSource else {
                NSLog("please set dataSource first", "")
                return
            }
            
            frameCount = 0
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            assetWriter?.shouldOptimizeForNetworkUse = true 
            
            // 配置视频输出设置
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            let sourceBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: sourceBufferAttributes)
            
            assetWriter?.add(videoInput!)
            
            if assetWriter?.startWriting() == true {
                assetWriter?.startSession(atSourceTime: CMTime.zero)
                frameTimer = Timer.scheduledTimer(timeInterval: TimeInterval(frame), target: self, selector: #selector(addFrame), userInfo: nil, repeats: true)
            }
        } catch {
            print("Error initializing video recording: \(error)")
            stopRecording()
        }
    }
    
    @objc func addFrame() {
        if let pixelBufferAdaptor = pixelBufferAdaptor {
            if frameCount < frameMaxCount {
                guard let image = dataSource?.videoRecorderWillAddImage(self) else {
                    return
                }
                if let pixelBuffer = pixelBufferFromImage(image: image) {
                    let presentationTime = CMTimeMake(value: Int64(frameCount), timescale: 30)
                    if videoInput?.isReadyForMoreMediaData ?? false {
                        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        frameCount += 1
                        let seconds = Int(Float(frameCount) * frame)
                        DispatchQueue.main.async {
                            self.delegate?.videoRecorder(self, didSaveVideoLength: seconds)
                        }
                    }
                }
            } else {
                // 如果图像帧已经添加完毕，自动停止录制
                stopRecording { success in
                    if success {
                        print("Video recording completed.")
                    } else {
                        print("Error stopping video recording.")
                    }
                }
            }
        }
    }
    
    func stopRecording() {
        stopRecording { _ in }
    }
    
    private func stopRecording(completion: @escaping (Bool) -> Void) {
        frameTimer?.invalidate()
        videoInput?.markAsFinished()
        let endAction = {
            DispatchQueue.main.async {
                self.delegate?.videoRecorderDidStopAuto(self)
            }
            completion(true)
        }
        if assetWriter?.status == .writing {
            assetWriter?.finishWriting {
                endAction()
            }
        } else {
            endAction()
        }
    }
    
    fileprivate func pixelBufferFromImage(image: UIImage) -> CVPixelBuffer? {
        return pixelBufferFromJPEGImage(image: image)
    }

}

extension VideoRecorder {

    fileprivate func pixelBufferFromJPEGImage(image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let imageWidth = cgImage.width
        let imageHeight = cgImage.height

        let options: [NSString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, imageWidth, imageHeight, kCVPixelFormatType_32ARGB, options as CFDictionary, &pixelBuffer)

        if status != kCVReturnSuccess {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        let context = CGContext(data: pixelData,
                                width: imageWidth,
                                height: imageHeight,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
    
}
