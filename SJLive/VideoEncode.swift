//
//  VideoEncoder.swift
//  OSXAVFoundationDemo
//
//  Created by king on 16/8/2.
//  Copyright © 2016年 king. All rights reserved.
//

import Cocoa
import VideoToolbox
import AVFoundation
import CoreVideo


class VideoEncode: NSObject {

    private var h264File:String!
    private var fileHandle:FileHandle!
    var formatDescription:CMFormatDescription? = nil {
        didSet {
            guard !CMFormatDescriptionEqual(formatDescription, otherFormatDescription: oldValue) else {
                return
            }
            
            didSetFormatDescription(video: formatDescription)
        }
    }
    // 编码会话
    var session: VTCompressionSession?
    // 编码回调
    var callBack: VTCompressionOutputCallback = {(
        outputCallbackRefCon:UnsafeMutableRawPointer?,
        sourceFrameRefCon:UnsafeMutableRawPointer?,
        status:OSStatus,
        infoFlags:VTEncodeInfoFlags,
        sampleBuffer:CMSampleBuffer?
        ) in
    
        // 数据检查
        guard let sampleBuffer: CMSampleBuffer = sampleBuffer, status == noErr else { return }
        
        let encode: VideoEncode = unsafeBitCast(outputCallbackRefCon, to: VideoEncode.self)
        // 是否是h264的关键帧
        let isKeyframe = !CFDictionaryContainsKey(unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true), 0), to: CFDictionary.self), unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self))
        if isKeyframe {
            // h264的 pps、sps
            encode.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        }
        // h264具体视频帧内容
        encode.sampleOutput(video: sampleBuffer)
    }
    
    let defaultAttributes:[NSString: Any] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferOpenGLCompatibilityKey: true,
        ]
    private var width:Int32!
    private var height:Int32!
    
    private var attributes:[NSString: Any] {
        var attributes:[NSString: Any] = defaultAttributes
        attributes[kCVPixelBufferHeightKey] = 720
        attributes[kCVPixelBufferWidthKey] = 1280
        return attributes
    }
    
    var profileLevel:String = kVTProfileLevel_H264_Baseline_3_1 as String
    private var properties:[NSString: Any] {
        let isBaseline:Bool = profileLevel.contains("Baseline")
        var properties:[NSString: Any] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel,
            kVTCompressionPropertyKey_AverageBitRate: Int(1280*720),
            kVTCompressionPropertyKey_ExpectedFrameRate: NSNumber(value: 30.0),
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(value: 2.0),
            kVTCompressionPropertyKey_AllowFrameReordering: !isBaseline,
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": "Trim"
            ]
        ]
        if (!isBaseline) {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = kVTH264EntropyMode_CABAC
        }
        return properties
    }
    
    // MARK: 开始
    func start(widht: Int32 = 720, height: Int32 = 1280)  {
        
        // 创建编码会话
        VTCompressionSessionCreate(allocator: kCFAllocatorDefault,
                                   width: widht,
                                   height: height,
                                   codecType: kCMVideoCodecType_H264,
                                   encoderSpecification: nil,
                                   imageBufferAttributes: attributes as CFDictionary,
                                   compressedDataAllocator: nil,
                                   outputCallback: callBack,
                                   refcon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
                                   compressionSessionOut: &session)
        
        VTSessionSetProperties(session!, propertyDictionary: properties as CFDictionary)
        VTCompressionSessionPrepareToEncodeFrames(session!)
        
        // init filehandle
        let documentDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        h264File = documentDir[0] + "/demo.h264"
        
        do {
            try FileManager.default.removeItem(atPath: h264File)
            FileManager.default.createFile(atPath: h264File, contents: nil, attributes: nil)
            fileHandle = try FileHandle(forUpdating: NSURL(string: h264File)! as URL)
            //            print(fileHandle)
        } catch let error as NSError {
            print(error)
        }
    }
    
    func encodeImageBuffer(imageBuffer:CVImageBuffer, presentationTimeStamp:CMTime, presentationDuration:CMTime) {
        
        var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
        /// 开始编码
        VTCompressionSessionEncodeFrame(session!, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, duration: presentationDuration, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: &flags)
    }
    
    func endEncode()  {
        
        if let session = session {
            
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: CMTime.invalid)
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
    }
}

extension VideoEncode {
    
    // 264 description
    private func didSetFormatDescription(video formatDescription:CMFormatDescription?) {
        
        let sampleData =  NSMutableData()
        // let formatDesrciption :CMFormatDescriptionRef = CMSampleBufferGetFormatDescription(sampleBuffer!)!
        let sps = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1) //.alloc(1)
        let pps = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1) //.alloc(1)
        let spsLength = UnsafeMutablePointer<Int>.allocate(capacity: 1) //.alloc(1)
        let ppsLength = UnsafeMutablePointer<Int>.allocate(capacity: 1) //.alloc(1)
        let spsCount = UnsafeMutablePointer<Int>.allocate(capacity: 1) //.alloc(1)
        let ppsCount = UnsafeMutablePointer<Int>.allocate(capacity: 1) //.alloc(1)
        sps.initialize(to: nil) //initialize(nil)
        pps.initialize(to: nil) //initialize(nil)
        spsLength.initialize(to: 0) //initialize(0)
        ppsLength.initialize(to: 0) //initialize(0)
        spsCount.initialize(to: 0) //initialize(0)
        ppsCount.initialize(to: 0) //initialize(0)
        var err : OSStatus
        // 获取sps
        err = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription!, parameterSetIndex: 0, parameterSetPointerOut: sps, parameterSetSizeOut: spsLength, parameterSetCountOut: spsCount, nalUnitHeaderLengthOut: nil )
        if (err != noErr) {
            NSLog("An Error occured while getting h264 parameter")
        }
        // 获取pps
        err = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription!, parameterSetIndex: 1, parameterSetPointerOut: pps, parameterSetSizeOut: ppsLength, parameterSetCountOut: ppsCount, nalUnitHeaderLengthOut: nil )
        if (err != noErr) {
            NSLog("An Error occured while getting h264 parameter")
        }
        // 添加NALU开始码
        let naluStart:[UInt8] = [0x00, 0x00, 0x00, 0x01]
        sampleData.append(naluStart, length: naluStart.count)
        sampleData.append(sps.pointee!, length: spsLength.pointee)
        //sampleData.append(sps.memory, length: spsLength.memory)
        sampleData.append(naluStart, length: naluStart.count)
        sampleData.append(pps.pointee!, length: ppsLength.pointee)
        //appendBytes(pps.memory, length: ppsLength.memory)
        // 写入文件
        fileHandle.write(sampleData as Data)
        print(sampleData)
    }
    
    //
    private func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        print("get slice data!")
        // todo : write to h264 file
        let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
        var totalLength = Int()
        var length = Int()
        var dataPointer: UnsafeMutablePointer<Int8>? = nil
        
        let state = CMBlockBufferGetDataPointer(blockBuffer!, atOffset: 0, lengthAtOffsetOut: &length, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
        
        if state == noErr {
            var bufferOffset = 0;
            let AVCCHeaderLength = 4
            
            while bufferOffset < totalLength - AVCCHeaderLength {
                var NALUnitLength:UInt32 = 0
                memcpy(&NALUnitLength, dataPointer! + bufferOffset, AVCCHeaderLength)
                NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
                
                var naluStart:[UInt8] = [UInt8](repeating: 0x00, count: 4) //[UInt8](count: 4, repeatedValue: 0x00)
                naluStart[3] = 0x01
                let buffer:NSMutableData = NSMutableData()
                buffer.append(&naluStart, length: naluStart.count)
                buffer.append(dataPointer! + bufferOffset + AVCCHeaderLength, length: Int(NALUnitLength))
                fileHandle.write(buffer as Data)
                print(buffer)
                bufferOffset += (AVCCHeaderLength + Int(NALUnitLength))
            }
            
        }
    }

}
