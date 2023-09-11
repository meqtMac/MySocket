//
//  File.swift
//
//
//  Created by 蒋艺 on 2023/7/10.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @StateObject private var mediaViewModel = MediaViewModel()
    @State private var isPaused = false
    @State private var speedConstant = 6
    @State private var counter = 0
    let timer = Timer.publish(every: 0.02/6.0, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack{
            Text("Hello, World.")
        }.onAppear {
            Task {
                await mediaViewModel.run()
            }
        }
        .onReceive(timer) { _ in
            Task {
                if !isPaused {
                    counter += 1
                    if counter % speedConstant == 0 {
                        let frameid = await mediaViewModel.updateCurrentFrame()
                        print(frameid)
                        if frameid == 499 {
                            isPaused = true
                        }
                    }
                }
            }
            
        }
        
    }
}

//struct ContentView: View {
//    /// view model
//    @StateObject private var meidaViewModel = MediaViewModel()
//    /// pause controller
//    @State private var isPaused = false
//    /// speed controller
//    @State private var speedConstant = 6
//    /// use counter and timer to update frames
//    @State private var counter = 0
//
//    let timer = Timer.publish(every: 0.02/6.0, on: .main, in: .common).autoconnect()
//
//    var body: some View {
//        VStack {
//            Button("Start Processing") {
//                meidaViewModel.startProcessing()
//                isPaused = false
//            }
//            if let image = meidaViewModel.currentFrame {
//                ZStack(alignment: .bottom) {
//                    Image(decorative: image.cgImage, scale: 1)
//                        .overlay(alignment: .bottom) {
//                            VStack{
//                                HStack{
//                                    // play and paused controller
//                                    Button {
//                                        isPaused.toggle()
//                                    } label: {
//                                        if isPaused {
//                                            Image(systemName: "play.fill")
//                                        }else{
//                                            Image(systemName: "pause.fill")
//                                        }
//                                    }
//                                    .padding(.horizontal)
//
//                                    // Speed Controller
//                                    Picker("Speed", selection: $speedConstant) {
//                                        Text("1/4").tag(24)
//                                        Text("1/2").tag(12)
//                                        Text("normal").tag(6)
//                                        Text("3/2").tag(4)
//                                        Text("2").tag(3)
//                                    }
//                                    .pickerStyle(.segmented)
//                                    .padding(.horizontal)
//                                }
//                                ZStack{
//                                    // play and cached progress view
//                                    ProgressView(value: Double(meidaViewModel.cachedFrames), total: 500)
//                                        .tint(.gray)
//                                    Slider(value: .constant(Double(image.frameId)), in: 0.0...500)
//                                }
//                            }
//                        }
//
//                }
//            }
//        }
//        .padding()
//        .onReceive(timer) { _  in
//            /// update frame.
//            if !isPaused {
//                counter += 1
//                if counter % speedConstant == 0 {
//                    let frameid = meidaViewModel.updateCurrentFrame()
//                    if frameid == 499 {
//                        isPaused = true
//                    }
//                }
//            }
//        }
//    }
//}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
