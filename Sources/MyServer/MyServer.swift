//
//  File.swift
//
//
//  Created by 蒋艺 on 2023/7/10.
//

import Foundation
import MySocket

let fileCount = 10

@main
actor MyServer {
    
    static func main() throws {
        var serverSocket = try Socket(socket(AF_INET, SOCK_STREAM, 0))
        let serverAddress = MySockAddress(port: 12345)
        try serverSocket.bind(address: serverAddress)
        try serverSocket.listen()
        
        let clientSocket = try serverSocket.accept()
        // Send message to client indicating the expected size of the data
        let fileCountData = withUnsafeBytes(of: fileCount.bigEndian) { Data($0) }
        
        // send meta data of video
        try clientSocket.sendData(fileCountData)
        print("10 files to send.")
        
        let _ = try clientSocket.receiveData()
        print("start sending files:")
        
        for i in 1...10 {
            if let fileURL = Bundle.module.url(forResource: "\(i)", withExtension: "bin", subdirectory: "Bins") {
                if let fileData = try? Data(contentsOf: fileURL) {
                    do {
                        try clientSocket.sendFile(data: fileData)
                    }catch{
                        print(error.localizedDescription)
                    }
                    print("\tSent \(fileURL.lastPathComponent) to client")
                    // receive conformation before send next file.
                    let _ = try clientSocket.receiveData()
                }else{
                    print("\tFail to read \(i).bin")
                }
            }else{
                print("Failed to get fileURL of \(i).bin")
            }
        }
    }
}

