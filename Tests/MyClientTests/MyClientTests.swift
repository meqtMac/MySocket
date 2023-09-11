//
//  MyClientTests.swift
//
//
//  Created by 蒋艺 on 2023/7/10.
//

import XCTest
@testable import MyClient

final class MyClientTests: XCTestCase {
    
    func testPerformanceDecode() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        self.measure(
            metrics: [
                XCTCPUMetric(),
                XCTClockMetric(),
                XCTMemoryMetric(),
                XCTStorageMetric()
            ]
        ) {
            guard let url = Bundle.module.url(
                forResource: "1",
                withExtension: "bin",
                subdirectory: "Resources"
            ) else {
                fatalError("Didn't find data")
            }
            
            
            XCTAssertNoThrow {
                let data = try! Data(contentsOf: url)
                let _ = try myBinDecoder(seqId: 1, inputData: data)
            }
        }
    }
    
    
}
