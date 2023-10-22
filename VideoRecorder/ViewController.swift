//
//  ViewController.swift
//  VideoRecorder
//
//  Created by 王文东 on 2023/10/15.
//

import UIKit

class ViewController: UIViewController {
    
    var recorder: VideoRecorder!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        recorder = VideoRecorder()
        recorder.dataSource = self
        recorder.delegate = self
        
        imageView.animationImages = [
            UIImage(named: "img2")!,
            UIImage(named: "img3")!,
            UIImage(named: "img4")!,
            UIImage(named: "img5")!,
            UIImage(named: "img6")!,
        ]
        imageView.animationDuration = 1 
        imageView.startAnimating()
    }

    @IBAction func startRecordAction(_ sender: Any) {
        recorder.startRecording(outputURL: getMp4Url(), size: CGSize(width: 200, height: 300))
    }
    
    @IBAction func stopRecordAction(_ sender: Any) {
        recorder.stopRecording()
    }
    
    
}

extension ViewController {
    
    func getMp4Url() -> URL {
        // 在您的代码中使用 getDocumentsDirectory 函数获取文档目录路径
        let documentsDirectory = getDocumentsDirectory()
        let videoFileName = "myVideo_\(Date()).mp4" // 指定您的视频文件名
        let outputURL = documentsDirectory.appendingPathComponent(videoFileName)
        return outputURL
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

extension ViewController: VideoRecorderDataSource, VideoRecorderDelegate {
    
    func videoRecorderWillAddImage(_ recorder: VideoRecorder) -> UIImage {
        let index = Int.random(in: 0...4)
        return imageView.animationImages![index]
    }
    
    func videoRecorder(_ recorder: VideoRecorder, didSaveVideoLength seconds: Int) {
        let minutes = seconds / 60
        let s = seconds % 60
        NSLog("video mm:ss \(minutes):\(s)", "")
    }
    
    func videoRecorderDidStopAuto(_ recorder: VideoRecorder) {
        NSLog("stopped ", "")
    }
    
}
