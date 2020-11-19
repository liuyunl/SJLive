//
//  LiveViewController.swift
//  SJLive
//
//  Created by king on 16/8/14.
//  Copyright © 2016年 king. All rights reserved.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {

    lazy var stopBtn: NSButton = {
        let btn = NSButton()
        btn.bezelStyle = .rounded
        btn.title = "停止采集"
        return btn
    }()
    
    lazy var recordRectBtn: NSButton = {
        
        let btn = NSButton()
        btn.bezelStyle = .rounded
        btn.title = "设置录制范围"
        return btn
    }()
    
    lazy var startRecordBtn: NSButton = {
        
        let btn = NSButton()
        btn.bezelStyle = .rounded
        btn.title = "开始录屏"
        return btn
    }()
    
    lazy var stopRecordBtn: NSButton = {
        
        let btn = NSButton()
        btn.bezelStyle = .rounded
        btn.title = "停止录屏"
        return btn
    }()
    
    lazy var audioPopUpButton:NSPopUpButton = {
        let button:NSPopUpButton = NSPopUpButton()
        button.action = #selector(selectAudio(sender:))
        let audios:[AnyObject]! = AVCaptureDevice.devices(for: AVMediaType.audio)
        for audio in audios {
            if let audio:AVCaptureDevice = audio as? AVCaptureDevice {
                button.addItem(withTitle: audio.localizedName)
            }
        }
        return button
    }()
    
    lazy var cameraPopUpButton:NSPopUpButton = {
        let button:NSPopUpButton = NSPopUpButton()
        button.action = #selector(selectCamera(sender:))
        let cameras:[AnyObject]! = AVCaptureDevice.devices(for: AVMediaType.video)
        button.addItem(withTitle: "屏幕录制")
        for camera in cameras {
            if let camera:AVCaptureDevice = camera as? AVCaptureDevice {
                button.addItem(withTitle: camera.localizedName)
            }
        }
        return button
    }()
    
    var VideoPreView: AVCaptureVideoPreviewLayer!
    lazy var recordScreen: RecordScreen = {
        
        let re = RecordScreen()
        return re
    }()
    
    lazy var paleyView: NSView = {
       
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.black.cgColor
        return v
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        view.layer?.backgroundColor = NSColor.red.cgColor
        // 添加约束
        let buttonSize = CGSize(width: 100, height: 30)
        stopBtn.frame = NSRect(origin: CGPoint(x: 10, y: view.frame.height-50), size: buttonSize)
        recordRectBtn.frame = NSRect(origin: CGPoint(x: stopBtn.frame.maxX+30, y: view.frame.height-50), size: buttonSize)
        startRecordBtn.frame = NSRect(origin: CGPoint(x: recordRectBtn.frame.maxX+10, y: view.frame.height-50), size: buttonSize)
        stopRecordBtn.frame = NSRect(origin: CGPoint(x: startRecordBtn.frame.maxX+10, y: view.frame.height-50), size: buttonSize)
        audioPopUpButton.frame = NSRect(origin: CGPoint(x: stopRecordBtn.frame.maxX+30, y: view.frame.height-50), size: buttonSize)
        cameraPopUpButton.frame = NSRect(origin: CGPoint(x: audioPopUpButton.frame.maxX+10, y: view.frame.height-50), size: CGSize(width: 150, height: 30))
        paleyView.frame = NSRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: view.frame.size.width, height: view.frame.size.height-60))

        // 添加事件
        stopBtn.target = self
        stopBtn.action = #selector(stopBtnClick)
        
        recordRectBtn.target = recordScreen
        recordRectBtn.action = #selector(recordScreen.setDisplayAndCropRect)
        
        startRecordBtn.target = recordScreen
        startRecordBtn.action = #selector(recordScreen.startRecording)
        
        stopRecordBtn.target = recordScreen
        stopRecordBtn.action = #selector(recordScreen.stopRecording)
        
        // 添加子控件
        view.addSubview(stopBtn)
        view.addSubview(recordRectBtn)
        view.addSubview(startRecordBtn)
        view.addSubview(stopRecordBtn)
        view.addSubview(audioPopUpButton)
        view.addSubview(cameraPopUpButton)
        view.addSubview(paleyView)
        
        createRecordScreen()
        
        VideoPreView.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        VideoPreView.frame = NSRect(origin: CGPoint(x: 0, y: 0), size: paleyView.layer!.bounds.size)
    }
    
    
    override func viewDidLayout() {
        super.viewDidLayout()
//        VideoPreView.frame = NSRect(origin: CGPointMake(0, 0), size: paleyView.bounds.size)
        print(paleyView.bounds.size)
    }
    @objc func stopBtnClick() {
        if stopBtn.title == "开始采集" {
            recordScreen.startRunning()
            stopBtn.title = "停止采集"
        } else {
            recordScreen.stopRunning()
            recordScreen.stopRecording()
            stopBtn.title = "开始采集"
        
        }
    }

    func createRecordScreen()  {
        if recordScreen.createCaptureSession() {
            VideoPreView = recordScreen.createCaptureVideoPreView()
            paleyView.layer?.addSublayer(VideoPreView)
            recordScreen.startRunning()
        }
    }
    
    @objc func selectAudio(sender:AnyObject) {
        if let device:AVCaptureDevice = deviceWithLocalizedName(
        localizedName: audioPopUpButton.itemTitles[audioPopUpButton.indexOfSelectedItem],
        mediaType: AVMediaType.audio.rawValue
        ) {
        
        recordScreen.switchAudioInputSource(device: device)
        }
    }
    
    @objc func selectCamera(sender:AnyObject) {
        if let device:AVCaptureDevice = deviceWithLocalizedName(
            localizedName: cameraPopUpButton.itemTitles[cameraPopUpButton.indexOfSelectedItem],
            mediaType: AVMediaType.video.rawValue
            ) {
            recordScreen.switchVideoInputSource(device: device)
        } else {
            recordScreen.switchVideoInputSource(device: nil)
        }
    }
}

extension ViewController : RecordScreenDelegate {
    
    func RecordScreenDidOutputSampleBuffer(sampleBuffer: CMSampleBuffer!) {
        
        if CMSampleBufferGetImageBuffer(sampleBuffer) != nil {
            
//            imageFromSamplePlanerPixelBuffer(imageBuffer)
        }
    }
}

extension ViewController {
    
    func imageFromSamplePlanerPixelBuffer(imageBuffer: CVImageBuffer!) {
    
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(data: baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: 0) else { return }
        let imageRef = context.makeImage()
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
        if imageRef != nil  {
            
            //.....
            
            
        }

    }
}

func deviceWithLocalizedName(localizedName:String, mediaType:String) -> AVCaptureDevice? {
    for device in AVCaptureDevice.devices() {
        guard let device:AVCaptureDevice = device as? AVCaptureDevice else {
            continue
        }
        if (device.hasMediaType(AVMediaType(rawValue: mediaType)) && device.localizedName == localizedName) {
            return device
        }
    }
    return nil
}
