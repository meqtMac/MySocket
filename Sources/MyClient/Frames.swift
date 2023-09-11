//
//  File.swift
//  
//
//  Created by 蒋艺 on 2023/7/10.
//

//import Foundation

import Accelerate
/// Converts the YpCbCr block to grayscale images.
/// - Parameter block: The YpCbCr block to convert.
/// - Returns: An array of grayscale frames.
func getGrayscaleImagesFromYpChannel(block: YpCbCrBlock) -> [Frame] {
    var frames: [Frame] = []
    let colorSpace = CGColorSpaceCreateDeviceGray()
    let bytesPerPixel = 1
    let bitsPerComponent = 8
    let bytesPerRow = bytesPerPixel * frameWidth
    let bitmapInfo = CGImageAlphaInfo.none.rawValue
    
    for i in 0..<blockFrames {
        let frameBytes = frameWidth*frameHeight*3/2
        let frameGrayBytes = frameWidth*frameHeight
        let frameGrayRange = i*frameBytes ..< i*frameBytes+frameGrayBytes
        let frameId = block.seqId * blockFrames + i
        print("rendering \(frameId) frames.")
        
        var frameData = block.data.subdata(in: frameGrayRange)
        
        frameData.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: frameWidth,
                height: frameHeight,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )else {
                print("get frame error")
                fatalError("can't get frames")
            }
            
            guard let image = context.makeImage() else{
                fatalError("can't create image.")
            }
            frames.append(Frame(frameId: frameId, cgImage: image))
        }
    }
    return frames
}

/// Converts the 420YpCbCr block to frames.
/// - Parameter block: The 420YpCbCr block to convert.
/// - Returns: An array of frames.
func getFramesFrom420YpCbCrBlock(block: YpCbCrBlock) -> [Frame] {
    var frames: [Frame] = []
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * frameWidth
    
    // Create RGB color space
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    for i in 0..<blockFrames {
        let frameBytes = frameWidth*frameHeight*3/2
        let frameGrayBytes = frameWidth*frameHeight
        let frameYpRange = i*frameBytes ..< i*frameBytes+frameGrayBytes
        let frameCbRange = i*frameBytes + frameGrayBytes ..< i*frameBytes + 5*frameGrayBytes/4
        let frameCrRange = i*frameBytes + 5*frameGrayBytes/4 ..< i*frameBytes + frameBytes
        let frameId = block.seqId * blockFrames + i
        print("rendering \(frameId) frames.")
        
        let YpData = Array(block.data[frameYpRange])
        let CbData = Array(block.data[frameCbRange])
        let CrData = Array(block.data[frameCrRange])
        //TODO: convert 420YpCbCr to ARGB
        var imageBuffer = convert420YpCbCrToARGB8888(YpData: YpData, CbData: CbData, CrData: CrData)
        
        imageBuffer.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: frameWidth,
                height: frameHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else {
                print("get frame error")
                fatalError("can't get frames")
            }
            
            guard let image = context.makeImage() else{
                fatalError("can't create image.")
            }
            frames.append(Frame(frameId: frameId, cgImage: image))
        }
    }
    return frames
}

/// Converts the YpCbCr data to ARGB8888 format.
/// - Parameters:
///   - YpData: The Yp data.
///   - CbData: The Cb data.
///   - CrData: The Cr data.
/// - Returns: The ARGB8888 formatted data.
func convert420YpCbCrToARGB8888(YpData: [UInt8], CbData: [UInt8], CrData: [UInt8]) -> [UInt8] {
    print("convert")
    let CbUpScale = upscalePlanar8(CbData, width: frameWidth/2, height: frameHeight/2, scale: 2)
    let CrUpScale = upscalePlanar8(CrData, width: frameWidth/2, height: frameHeight/2, scale: 2)
    return interleave(y: YpData, cr: CbUpScale, cb: CrUpScale)
}

/// Upscales the planar 8-bit data.
/// - Parameters:
///   - data: The input data to upscale.
///   - width: The width of the data.
///   - height: The height of the data.
///   - scale: The scale factor.
/// - Returns: The upscaled data.
func upscalePlanar8(_ data: [UInt8], width: Int, height: Int, scale: Int) -> [UInt8] {
    precondition(data.count == width*height, "data shape doesn't match")
    return [UInt8](unsafeUninitializedCapacity: width*height*scale*scale ) { buffer, initializedCount in
        initializedCount = width*height*scale*scale
        data.withUnsafeBytes { dataBuffer in
            var imageBuffer = vImage_Buffer(
                data: UnsafeMutableRawPointer(mutating: dataBuffer.baseAddress!),
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: width)
            var outImageBuffer = vImage_Buffer(
                data: buffer.baseAddress!,
                height: vImagePixelCount(height*scale),
                width: vImagePixelCount(width*scale),
                rowBytes: width*scale)
            
            let _ = vImageScale_Planar8(
                &imageBuffer,
                &outImageBuffer,
                nil,
                vImage_Flags(kvImageNoFlags))
        }
    }
}

/// Interleaves the Yp, Cr, and Cb data to produce ARGB8888 formatted data.
/// - Parameters:
///   - y: The Yp data.
///   - cr: The Cr data.
///   - cb: The Cb data.
/// - Returns: The interleaved ARGB8888 formatted data.
func interleave(y: [UInt8], cr: [UInt8], cb: [UInt8]) -> [UInt8] {
    precondition(y.count == cr.count && y.count == cb.count, "count don't fit")
    let count = y.count
    
    let c = [Float](unsafeUninitializedCapacity: count) { buffer, initializedCount in
        initializedCount = count
        vDSP.convertElements(of: y, to: &buffer)
        vDSP.add(-16, buffer, result: &buffer)
        vDSP.multiply(298, buffer, result: &buffer)
    }
    
    let d = [Float](unsafeUninitializedCapacity: count) { buffer, initializedCount in
        initializedCount = count
        vDSP.convertElements(of: cr, to: &buffer)
        vDSP.add(-128, buffer, result: &buffer)
    }
    
    let e = [Float](unsafeUninitializedCapacity: count) { buffer, initializedCount in
        initializedCount = count
        vDSP.convertElements(of: cb, to: &buffer)
        vDSP.add(-128, buffer, result: &buffer)
    }
    
    let r = [Float](unsafeUninitializedCapacity: count) { buffer, initializedCount in
        initializedCount = count
        vDSP.add(128, vDSP.add(multiplication: (c, 1), multiplication: (e, 409)), result: &buffer)
        vDSP.divide(buffer, 256, result: &buffer)
    }
    
    let g = [Float](unsafeUninitializedCapacity: count) { buffer, initializedCount in
        initializedCount = count
        vDSP.add(multiplication: (d, -100), multiplication: (e, -208), result: &buffer)
        vDSP.add(c, buffer, result: &buffer)
        vDSP.add(128, buffer, result: &buffer)
        vDSP.divide(buffer, 256, result: &buffer)
    }
    
    let b = [Float](unsafeUninitializedCapacity: count) { buffer, initializedCount in
        initializedCount = count
        vDSP.add(multiplication: (c, 1), multiplication: (d, 516), result: &buffer)
        vDSP.add(128, buffer, result: &buffer)
        vDSP.divide(buffer, 256, result: &buffer)
    }
    
    let fTemp = [Float](unsafeUninitializedCapacity: count*4) { buffer, initializedCount in
        initializedCount = count*4
        let ptr = buffer.baseAddress!
        let mPtr = UnsafeMutablePointer(mutating: ptr)
        let length = vDSP_Length(count)
        vDSP.fill(&buffer, with: 0.0)
        
        vDSP_vadd(g, 1, ptr+1, 4, mPtr+1, 4, length) // g
        vDSP_vadd(b, 1, ptr+2, 4, mPtr+2, 4, length) // b
        vDSP_vadd([Float](repeating: 255, count: count), 1, ptr+3, 4, mPtr+3, 4, length) // alpha
        vDSP_vadd(r, 1, ptr, 4, mPtr, 4, length) // r
    }
    
    return [UInt8](unsafeUninitializedCapacity: count*4) { buffer, initializedCount in
        initializedCount = count*4
        vDSP.convertElements(of: fTemp, to: &buffer, rounding: .towardNearestInteger)
    }
}

