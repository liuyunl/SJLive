//
//  CameraCapture.swift
//  OSXAVFoundationDemo
//
//  Created by king on 16/8/1.
//  Copyright © 2016年 king. All rights reserved.
//

import Cocoa
import AVFoundation
import OpenGL
import CoreImage

protocol CameraCaptureDelegate: NSObjectProtocol {
    
    func CameraVideoOutput(sampleBuffer: CVImageBuffer!)

}

class CameraCapture: NSObject {

    let cameraQueue: DispatchQueue! = DispatchQueue(label: "com.king129") //dispatch_queue_create("com.king129", DISPATCH_QUEUE_SERIAL)
    var videoEncoder: VideoEncode = VideoEncode()
    
    var delegate: CameraCaptureDelegate?
    var captureSession: AVCaptureSession!
    var captureDevice: AVCaptureDevice!
    var captureDeviceInput: AVCaptureDeviceInput!
    var captureVideoDataOutput: AVCaptureVideoDataOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    func setup(fps: Int, sessionPreset: String?) -> AVCaptureVideoPreviewLayer? {
        
        captureSession = AVCaptureSession()
        if (sessionPreset != nil) {
            captureSession.sessionPreset = AVCaptureSession.Preset(rawValue: sessionPreset!)
        }
        captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        if captureDevice == nil {
            return nil
        }
        
        do {
            
           try captureDevice.lockForConfiguration()
        } catch let error {
            print(error)
        }
        
        captureDevice.unlockForConfiguration()
        do {
            captureDeviceInput =  try AVCaptureDeviceInput(device: captureDevice)
        } catch let error {
            print(error)
        }
        
        captureVideoDataOutput = AVCaptureVideoDataOutput()
        captureVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]

    
        captureVideoDataOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        
        if captureSession.canAddInput(captureDeviceInput) {
            captureSession.addInput(captureDeviceInput)
        }
        if captureSession.canAddOutput(captureVideoDataOutput) {
            captureSession.addOutput(captureVideoDataOutput)
        }
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        videoPreviewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        return videoPreviewLayer
    
    }
    
    func startRunning()  {
        captureSession.startRunning()
        videoEncoder.start()
    }
    func stopRunning() {
        captureSession.stopRunning()
        videoEncoder.endEncode()
    }
    func isRunning() -> Bool {
        return captureSession == nil ? false : captureSession.isRunning
    }
}

extension CameraCapture : AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        guard let image:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        delegate?.CameraVideoOutput(sampleBuffer: image)
//        videoEncoder.encodeImageBuffer(image, presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer), presentationDuration: CMSampleBufferGetDuration(sampleBuffer))
        // print("get camera image data! Yeh!")
    }
    
}
