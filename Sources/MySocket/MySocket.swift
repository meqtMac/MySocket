import Foundation
import System
//import Darwin

public let defaultPort: UInt16 = 10000

public struct MySockAddress {
    var Csockaddr_in: sockaddr_in
    public init(port: UInt16, sockFamily: Int32 = AF_INET, sAddr: UInt32 = INADDR_ANY) {
        self.Csockaddr_in = sockaddr_in()
        Csockaddr_in.sin_port = port.bigEndian
        Csockaddr_in.sin_family = sa_family_t(sockFamily)
        Csockaddr_in.sin_addr.s_addr = sAddr
    }
    
    public init(port: UInt16, sockFamily: Int32 = AF_INET, ipv4: UnsafePointer<CChar>) {
        var sockaddr_in = sockaddr_in()
        sockaddr_in.sin_port = port.bigEndian
        sockaddr_in.sin_family = sa_family_t(sockFamily)
        let _ = withUnsafeMutableBytes(of: &sockaddr_in.sin_addr.s_addr) { rawBufferPointer in
            inet_pton(AF_INET, ipv4, rawBufferPointer.baseAddress!)
        }
        self.Csockaddr_in = sockaddr_in
    }
}


public struct Socket: ~Copyable {
    /// The file descriptor of the socket.
    public let socketFileDescriptor: FileDescriptor
    
    private var port: UInt16?
    
    public mutating func bind(address: MySockAddress) throws {
        self.port = address.Csockaddr_in.sin_port.bigEndian
        
        let bindResult = withUnsafePointer(to: address.Csockaddr_in) { addressPtr in
            addressPtr.withMemoryRebound(to: Darwin.sockaddr.self, capacity: 1) { pointer in
                return Darwin.bind(socketFileDescriptor.rawValue,
                                   pointer,
                                   socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult != -1 else {
            throw SocketError.bindFailed
        }
    }
    
    public func connect(address: MySockAddress) throws {
        let connectResult = withUnsafePointer(to: address.Csockaddr_in) { addressPtr in
            addressPtr.withMemoryRebound(to: Darwin.sockaddr.self, capacity: 1) { pointer in
                return Darwin.connect(
                    socketFileDescriptor.rawValue,
                    pointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard connectResult != -1 else {
            throw SocketError.connectFailed
        }
    }
    
    public func listen() throws {
        let listenResult = Darwin.listen(socketFileDescriptor.rawValue, SOMAXCONN)
        guard listenResult != -1 else {
            throw SocketError.listenFailed
        }
        print("Server started. Listening on port \(self.port!)")
    }
    
    public func accept() throws -> Socket {
        return try Socket(Darwin.accept(self.socketFileDescriptor.rawValue, nil, nil))
    }
    
    
    public init(_ socketFileDescriptor: Int32) throws {
        guard socketFileDescriptor != -1 else { throw SocketError.createFailed }
        self.socketFileDescriptor = FileDescriptor(rawValue: socketFileDescriptor)
    }
    
    /// Sends data over the socket.
    /// - Parameter data: The data to send.
    /// - Throws: SocketError if sending fails.
    public func send(_ data: Data) throws {
        try socketFileDescriptor.writeAll(data)
    }
    
    public func send(_ int: Int) throws {
        let _ = try withUnsafeBytes(of: int.bigEndian) {
            try socketFileDescriptor.writeAll(Data($0))
        }
    }
    
    /// Receives data from the socket.
    /// - Returns: The received data.
    /// - Throws: SocketError if receiving fails.
    public func receive() throws -> Data {
        var receivedData = Data(capacity: 4096)
        // MARK: ?
        let _ = try receivedData.withUnsafeMutableBytes { rawBufferPointer in
            let _ = try socketFileDescriptor.read(into: rawBufferPointer)
        }
        
        return receivedData
    }
    
    public func receiveInt() throws -> Int {
        let data = try self.receive()
        guard data.count == MemoryLayout<Int>.size else {
            throw SocketError.memoryLayoutDontMatch
        }
        
        return try data.withUnsafeBytes { rawBufferPointer in
            let bufferPointer = rawBufferPointer.bindMemory(to: Int.self)
            guard let first = bufferPointer.first else {
                throw SocketError.memoryLayoutDontMatch
            }
            return first.bigEndian
        }
        
        
    }
    
    /// Closes the socket.
    public consuming func close() {
        do {
            try socketFileDescriptor.close()
        }catch {
            print(error.localizedDescription)
        }
    }
    
    deinit {
        do {
            try socketFileDescriptor.close()
        }catch{
            print(error.localizedDescription)
        }
    }
    
    /// Sends a file over the socket.
    /// - Parameter data: The file data to send.
    /// - Throws: SocketError if sending fails.
    public func sendFile(data: Data) throws {
        let fileSize = data.count
        try send(fileSize)
        print("send fileSize: \(fileSize) bytes")
        let bufferSize = 4096 // Adjust the buffer size as per your needs
        
        var bytesSent = 0
        
        while bytesSent < fileSize {
            let remainingSize = fileSize - bytesSent
            let bufferSizeToSend = min(bufferSize, remainingSize)
            let buffer = data.subdata(in: bytesSent..<bytesSent+bufferSizeToSend)
            
            try send(buffer) // Send the buffer of file data
            
            bytesSent += bufferSizeToSend
        }
        print("finished send bytes: \(bytesSent)")
    }
    
    /// Extracts an integer from the provided data.
    /// - Parameter data: The data containing the integer.
    /// - Returns: The extracted integer, or nil if extraction fails.
    //    func extractInt(from data: Data) throw -> Int {
    //        guard data.count == MemoryLayout<Int>.size else {
    //            return nil // Data size does not match the size of an Int
    //        }
    //
    //        var intValue: Int = 0
    //
    //        data.withUnsafeBytes { rawBufferPointer in
    //            let bufferPointer = rawBufferPointer.bindMemory(to: Int.self)
    //            intValue = bufferPointer.first!.bigEndian
    //        }
    //
    //        return intValue
    //    }
    
    /// Receives a file from the socket.
    /// - Returns: The received file data, or nil if receiving fails.
    /// - Throws: SocketError if receiving fails.
    public func receiveFile() throws -> Data? {
        let fileSize = try receiveInt()
        print("receiving file size: \(fileSize)")
        
        var receivedData = Data()
        var bytesReceived = 0
        
        let bufferSize = 4096 // Adjust the buffer size as per your needs
        
        while bytesReceived < fileSize {
            let remainingSize = fileSize - bytesReceived
            let bufferSizeToReceive = min(bufferSize, remainingSize)
            
            let buffer = try receive() // Receive the buffer of file data
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
    case connectFailed
    case memoryLayoutDontMatch
}


