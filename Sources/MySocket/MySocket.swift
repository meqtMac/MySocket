// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Darwin

public struct MySockAddress {
    var Csockaddr_in: sockaddr_in
    public init(port: UInt16, sockFamily: Int32 = AF_INET, sAddr: UInt32 = INADDR_ANY) {
        self.Csockaddr_in = sockaddr_in()
        Csockaddr_in.sin_port = port.bigEndian
        Csockaddr_in.sin_family = sa_family_t(sockFamily)
        Csockaddr_in.sin_addr.s_addr = sAddr
    }
}

public struct Socket: ~Copyable {
    /// The file descriptor of the socket.
    public let socketFileDescriptor: Int32
    private var port: UInt16?
    
    // MARK: Buggy function call
    public mutating func bind(address: MySockAddress) throws {
        self.port = address.Csockaddr_in.sin_port.bigEndian
        
        let bindResult = withUnsafePointer(to: address.Csockaddr_in) { addressPtr in
            addressPtr.withMemoryRebound(to: Darwin.sockaddr.self, capacity: 1) { pointer in
                return Darwin.bind(socketFileDescriptor,
                                   pointer,
                                   socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult != -1 else {
            throw SocketError.bindFailed
        }
    }
    
    public func listen() throws {
        let listenResult = Darwin.listen(socketFileDescriptor, SOMAXCONN)
        guard listenResult != -1 else {
            throw SocketError.listenFailed
        }
        print("Server started. Listening on port \(self.port!)")
    }
    
    public func accept() throws -> Socket {
        return try Socket(Darwin.accept(self.socketFileDescriptor, nil, nil))
    }
    
    
    public init(_ socketFileDescriptor: Int32) throws {
        guard socketFileDescriptor != -1 else { throw SocketError.createFailed }
        self.socketFileDescriptor = socketFileDescriptor
    }
    
    /// Sends data over the socket.
    /// - Parameter data: The data to send.
    /// - Throws: SocketError if sending fails.
    public func sendData(_ data: Data) throws {
        try data.withUnsafeBytes { bufferPointer in
            let bufferAddress = bufferPointer.bindMemory(to: UInt8.self).baseAddress
            let bufferLength = bufferPointer.count
            
            let bytesSent = write(socketFileDescriptor, bufferAddress, bufferLength)
            guard bytesSent != -1 else {
                throw SocketError.sendFailed(String(errno))
            }
        }
    }
    
    /// Receives data from the socket.
    /// - Returns: The received data.
    /// - Throws: SocketError if receiving fails.
    public func receiveData() throws -> Data {
        var receivedData = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        let bytesRead = read(socketFileDescriptor, &buffer, bufferSize)
        guard bytesRead >= 0 else {
            throw SocketError.receiveFailed(String(errno))
        }
        receivedData.append(contentsOf: buffer[0..<bytesRead])
        return receivedData
    }
    
    /// Closes the socket.
    public consuming func close() {
        Darwin.close(socketFileDescriptor)
    }
    
    deinit {
        Darwin.close(socketFileDescriptor)
    }
    
    /// Sends a file over the socket.
    /// - Parameter data: The file data to send.
    /// - Throws: SocketError if sending fails.
    public func sendFile(data: Data) throws {
        let fileSize = data.count
        // send file byte count
        let fileSizeData = withUnsafeBytes(of: fileSize.bigEndian) { Data($0) }
        
        try sendData(fileSizeData) // Send the total file size to the other end
        print("send fileSize: \(fileSize)")
        let bufferSize = 4096 // Adjust the buffer size as per your needs
        
        var bytesSent = 0
        
        while bytesSent < fileSize {
            let remainingSize = fileSize - bytesSent
            let bufferSizeToSend = min(bufferSize, remainingSize)
            let buffer = data.subdata(in: bytesSent..<bytesSent+bufferSizeToSend)
            
            try sendData(buffer) // Send the buffer of file data
            
            bytesSent += bufferSizeToSend
        }
        print("finished send bytes: \(bytesSent)")
    }
    
    /// Extracts an integer from the provided data.
    /// - Parameter data: The data containing the integer.
    /// - Returns: The extracted integer, or nil if extraction fails.
    func extractInt(from data: Data) -> Int? {
        guard data.count == MemoryLayout<Int>.size else {
            return nil // Data size does not match the size of an Int
        }
        
        var intValue: Int = 0
        
        data.withUnsafeBytes { rawBufferPointer in
            let bufferPointer = rawBufferPointer.bindMemory(to: Int.self)
            intValue = bufferPointer.first!.bigEndian
        }
        
        return intValue
    }
    
    /// Receives a file from the socket.
    /// - Returns: The received file data, or nil if receiving fails.
    /// - Throws: SocketError if receiving fails.
    public func receiveFile() throws -> Data? {
        let fileSizeData = try receiveData()
        
        guard let fileSize = extractInt(from: fileSizeData.subdata(in: 0..<MemoryLayout<Int>.size)) else {
            return nil
        }
        print("receiving file size: \(fileSize)")
        
        var receivedData = Data()
        var bytesReceived = 0
        
        let bufferSize = 4096 // Adjust the buffer size as per your needs
        
        while bytesReceived < fileSize {
            let remainingSize = fileSize - bytesReceived
            let bufferSizeToReceive = min(bufferSize, remainingSize)
            
            let buffer = try receiveData() // Receive the buffer of file data
            receivedData.append(buffer)
            
            bytesReceived += bufferSizeToReceive
        }
        print("finished receiving file.")
        
        return receivedData
    }
}

/// An enumeration representing socket errors.
public enum SocketError: Error {
    case sendFailed(String)
    case receiveFailed(String)
    case createFailed
    case bindFailed
    case listenFailed
    case acceptFailed
}


