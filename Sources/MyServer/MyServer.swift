//
//  File.swift
//
//
//  Created by 蒋艺 on 2023/7/10.
//

import Foundation
import MySocket

let fileCount = 10
enum ServerError: Error {
    case readBinFailed
    case getUrlFailed(String)
}


@main
actor MyServer {
    let socket: Socket
    
    init(port: UInt16) throws {
        var serverSocket = try Socket(Darwin.socket(AF_INET, SOCK_STREAM, 0))
        let serverAddress = MySockAddress(port: port)
        try serverSocket.bind(address: serverAddress)
        self.socket = serverSocket
    }
    
    func accept() throws -> Socket {
        try socket.accept()
    }
    
    static func main() async throws {
        let server = try MyServer(port: defaultPort)
        
        let clientSocket = try await server.accept()
        
        // send meta data of video
        try clientSocket.send(fileCount)
        print("10 files to send.")
        
        let _ = try clientSocket.receive()
        print("start sending files:")
        
        for i in 1...10 {
            
            guard let fileURL = Bundle.module.url(forResource: "\(i)", withExtension: "bin") else {
                throw ServerError.getUrlFailed("\(i).bin")
            }
            
            let fileData = try Data(contentsOf: fileURL)
            try clientSocket.sendFile(data: fileData)
            print("\tSent \(fileURL.lastPathComponent) to client")
            let _ = try clientSocket.receive()
            
        }
    }
}

