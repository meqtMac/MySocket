//
//  File.swift
//
//
//  Created by 蒋艺 on 2023/7/10.
//

import Foundation

/// Runs the decoder operation on the input data and returns the output data.
/// - Parameters:
///   - inputData: The input data to be decoded.
/// - Returns: The output data produced by the decoder, or `nil` if the decoder failed or the output file is not found.
func myBinDecoder(seqId: Int, inputData: Data) throws -> Data {
    // The name of the temporary input file.
    let inputFileName = "\(seqId)tempInput.bin"
    // The name of the temporary output file.
    let outputFileName = "\(seqId)tempYuv"
    
    let fileManager = FileManager.default
    
    let inputFileURL = fileManager
        .temporaryDirectory
        .appendingPathComponent(inputFileName)
    
    let outputFileURL = fileManager
        .temporaryDirectory
        .appendingPathComponent(outputFileName)
    
    defer {
        do {
            try fileManager.removeItem(at: inputFileURL)
            try fileManager.removeItem(at: outputFileURL)
        } catch {
            fatalError("Can't remove input or output File")
        }
    }
    
    try inputData.write(to: inputFileURL)
    
    
    
    guard let decoderPath = Bundle.module.path(
        forResource: "TAppDecoder",
        ofType: nil,
        inDirectory: "Resources"
    ) else {
        throw MyClientError.decoderExecutableNotFound
    }
    
    let task = Process()
    let pipe = Pipe()
    
    task.launchPath = decoderPath
    task.arguments = ["-b", inputFileURL.path, "-o", outputFileURL.path]
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    
    return try Data(contentsOf: outputFileURL)
}
