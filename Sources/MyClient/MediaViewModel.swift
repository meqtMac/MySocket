//
//  File.swift
//
//
//  Created by 蒋艺 on 2023/7/10.
//
//

import Foundation
import SwiftUI
import MySocket
/// The data structure for storing bin data.
struct Bin: Comparable{
    /// Compares two `Bin` objects based on their sequence IDs.
    static func < (lhs: Bin, rhs: Bin) -> Bool {
        return lhs.seqId < rhs.seqId
    }
    
    /// The sequence ID of the bin, starting from 0.
    let seqId: Int
    /// The data of the bin.
    let data: Data
}

///
struct YpCbCrBlock: Comparable {
    static func < (lhs: YpCbCrBlock, rhs: YpCbCrBlock) -> Bool {
        lhs.seqId < rhs.seqId
    }
    
    /// The sequence ID of the YpCbCr block, starting from 0 and matching the bin it was decoded from.
    let seqId: Int
    /// The data of the YpCbCr block.
    let data: Data
}

/// The data structure for storing a frame.
struct Frame {
    /// The frame ID.
    let frameId: Int
    /// The CGImage of the frame.
    let cgImage: CGImage
}

//import Dispatch
//
/// The width of the frame
let frameWidth = 832
/// The height of the frame
let frameHeight = 480
/// The number of frames in a block
let blockFrames = 50

actor MediaViewModel: ObservableObject {
    @Published var cachedFrames: Int = 0
    @Published var currentFrame: Frame?
    
    /// Updates the current frame and returns its frame ID.
    /// - Returns: The frame ID of the current frame, or nil if there are no more frames.
    func updateCurrentFrame() -> Int? {
        if !frames.isEmpty {
            currentFrame = frames.removeFirst()
        }
        return currentFrame?.frameId
    }
    
    /// The data structure for storing bin data.
    var binData =  [Bin]()
    var YpCbCrBlocks: [YpCbCrBlock] = []
    var frames: [Frame] = []
    
    func append(bin: Bin) {
        binData.append(bin)
    }
    
    func append(block: YpCbCrBlock) {
        YpCbCrBlocks.append(block)
    }
    
    func append(frame: Frame) {
        frames.append(frame)
        cachedFrames += 1
    }
    
    nonisolated func run() async {
        let socketTask = Task.detached {
            do {
                let serverAddress = MySockAddress(port: defaultPort, ipv4: "127.0.0.1")
                let socket = try Socket(socket(AF_INET, SOCK_STREAM, 0))
                try socket.connect(address: serverAddress)
                let fileCount = try socket.receiveInt()
                try socket.send("received \(fileCount) to accept".data(using: .utf8)!)
                
                // recieve files
                for seq in 0..<fileCount {
                    if let fileData = try socket.receiveFile() {
                        try socket.send("received \(fileData.count) bytes".data(using: .utf8)!)
                        print("received \(fileData.count) bytes")
                        
                        await self.append(bin: Bin(seqId: seq, data: fileData))
                    }
                }
            }catch {
                print(error.localizedDescription)
            }
        }
        
        let decoderTask = Task.detached {
            do {
                for binDatum in await self.binData {
                    let decodedData = try myBinDecoder(seqId: binDatum.seqId, inputData: binDatum.data)
                    let block = YpCbCrBlock(seqId: binDatum.seqId, data: decodedData)
                    await self.append(block: block)
                }
            }catch {
                print(error.localizedDescription)
            }
        }
        
        let framizeTask = Task.detached {
            for block in await self.YpCbCrBlocks {
                let frames = getFramesFrom420YpCbCrBlock(block: block)
                for frame in frames {
                    await self.append(frame: frame)
                }
            }
        }
        
        // Wait for both tasks to finish
        /// Void. self stands for the return type of each group
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await socketTask.value }
            group.addTask { await decoderTask.value }
            group.addTask { await framizeTask.value }
            await group.waitForAll()
        }
    }
}
//
///// A view model class for media processing
//class MediaViewModel: ObservableObject {
//    /// The number of cached frames
//    @Published var cachedFrames: Int = 0
//    /// The current Frame on Screen
//    @Published var currentFrame: Frame?
//
//    /// Updates the current frame and returns its frame ID.
//    /// - Returns: The frame ID of the current frame, or nil if there are no more frames.
//    func updateCurrentFrame() -> Int? {
//        self.frameQueue.sync{
//            if !frames.isEmpty {
//                currentFrame = frames.removeFirst()
//            }
//        }
//        return currentFrame?.frameId
//    }
//
//    /// The data structure for storing bin data.
//    private var binData: [Bin] = []
//    /// protect exclusive access to binData
//    private let binQueue = DispatchQueue(label: "meqtmac.mediaExp02.bin")
//    private let binSemaphore = DispatchSemaphore(value: 0)
//
//    private var YpCbCrBlocks: [YpCbCrBlock] = []
//    /// protect exclusive access to blocks
//    private let blockQueue = DispatchQueue(label: "meqtmac.medixExp02.block")
//    private var blockSemaphore = DispatchSemaphore(value: 0)
//    /// use multithread to accelearte decodeing and with qos operation to have lower seqId with higher priority
//    private let decodingQueue = DispatchQueue(label: "meqtmac.mediaExp02.decodingQueue", attributes: .concurrent)
//
//    public var frames: [Frame] = []
//    /// protect exclusive access to frames
//    private let frameQueue = DispatchQueue(label: "meqtmac.medixExp02.frames")
//    // private var frameSemaphore = DispatchSemaphore(value: 0)
//
//    private var isDecoderThreadRunning = false
//
//    func startProcessing() {
//        isDecoderThreadRunning = true
//
//        // Start the socket thread
//        DispatchQueue.global().async {
//            self.socketThread()
//        }
//
//        // Start the myBinDecoder thread
//        DispatchQueue.global().async {
//            self.decoderThread()
//        }
//
//        DispatchQueue.global().async {
//            self.frameThread()
//        }
//    }
//
//    func stopProcessing() {
//        isDecoderThreadRunning = false
//    }
//
//    /// The socket thread for server-client communication.
//    private func socketThread() {
//        do {
//            let clientPort: UInt16 = 12345
//            var clientAddress = sockaddr_in()
//            clientAddress.sin_family = sa_family_t(AF_INET)
//            clientAddress.sin_port = clientPort.bigEndian
//
//            let _ = withUnsafeMutableBytes(of: &clientAddress.sin_addr.s_addr) { rawBuffer in
//                inet_pton(AF_INET, "127.0.0.1", rawBuffer.baseAddress!)
//            }
//
//            let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
//            guard socketFileDescriptor != -1 else {
//                print("Failed to create socket")
//                return
//            }
//
//            let connectResult = connect(socketFileDescriptor, sockaddr_cast(&clientAddress), socklen_t(MemoryLayout<sockaddr_in>.size))
//            guard connectResult != -1 else {
//                print("Failed to connect")
//                return
//            }
//
//            var socket = Socket(socketFileDescriptor: socketFileDescriptor)
//
//            // receive files number metadata from server
//            let filesData = try socket.receiveData()
//            guard let files = socket.extractInt(from: filesData) else {
//                print("Failed to get file numbers")
//                return
//            }
//            print("\(files) to receive")
//            try socket.sendData("received \(files) to accept".data(using: .utf8)!)
//
//            // recieve files
//            for seq in 0..<files {
//                if let fileData = try socket.receiveFile() {
//                    try socket.sendData("received \(fileData.count) bytes".data(using: .utf8)!)
//                    print("received \(fileData.count) bytes")
//
//                    // put received files to bin and assign sequenceId
//                    binQueue.sync {
//                        binData.append(Bin(seqId: seq, data: fileData))
//                        binSemaphore.signal() // Signal the decoder thread that data is available
//                    }
//                }
//            }
//
//            socket.close()
//        } catch {
//            print("Error: \(error)")
//        }
//    }
//
//    /// The decoder thread for decoding bin data.
//    private func decoderThread() {
//        while isDecoderThreadRunning {
//            binSemaphore.wait()
//            var bin: Bin?
//
//            binQueue.sync {
//                bin = binData.removeFirst()
//            }
//
//            if let processingBin = bin {
//                var block: YpCbCrBlock?
//                if let processedData = decoder(seqId: processingBin.seqId, inputData: processingBin.data) {
//                    block = YpCbCrBlock(seqId: processingBin.seqId, data: processedData)
//                }
//
//                if let decodedBlock = block {
//                    self.blockQueue.sync(flags: .barrier){
//                        self.YpCbCrBlocks.append(decodedBlock)
//                    }
//                    self.blockSemaphore.signal()
//                }
//            }
//        }
//    }
//
//    /// The frame thread for processing YpCbCr blocks and generating frames.
//    private func frameThread() {
//        while isDecoderThreadRunning {
//            blockSemaphore.wait()
//            var block: YpCbCrBlock?
//
//            blockQueue.sync(flags: .barrier) {
//                block = YpCbCrBlocks.removeFirst()
//            }
//
//            if let processingBlock = block {
//                let renderedFrames = getFramesFrom420YpCbCrBlock(block: processingBlock)
//
//                DispatchQueue.main.sync {
//                    self.cachedFrames += blockFrames
//                }
//
//                self.frameQueue.sync{
//                    self.frames.append(contentsOf: renderedFrames)
//                }
//            }
//        }
//    }
//}
//
