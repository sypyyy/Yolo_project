//
//  InteractionView.swift
//  YOLO
//
//  Created by 施炎培 on 2024/11/20.
//  Copyright © 2024 Ultralytics. All rights reserved.
//
import SwiftUI
import AVFoundation
import Speech
import CoreLocation

struct SpeechToTextView: View {
    @State private var isListening = false
    @State private var speechText = "Press and hold the button to start speaking..."
    @State private var isSpeakDisabled = false
    private let model = InteractionModel()
    private let speechRecognizer = SpeechRecognizer.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            MapView()
            Text(speechText)
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding()
            
            Button(action: {}, label: {
                Text(isListening ? "Listening..." : "Hold to Speak")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isListening ? Color.red : Color.blue)
                    .cornerRadius(10)
            })
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isListening {
                            isListening = true
                            speechRecognizer.startRecognition { text in
                                self.speechText = text
                            }
                        }
                    }
                    .onEnded { _ in
                        if isListening {
                            isSpeakDisabled = true
                            isListening = false
                            speechRecognizer.stopRecognition()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                                isSpeakDisabled = false
                                Task.detached {
                                    await model.sendMessage(msg: speechText)
                                }
                        
                            })
                        }
                    }
            )
            .disabled(isSpeakDisabled)
            .padding(.bottom, 10)
            Button(action: {
                model.refreshConversation()
            }, label: {
                Text("Refresh Conversation")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(10)
            })
            .padding(.bottom, 40)
            
            /*
            Button {
                let destination = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                
                NavigationHandler.navigateWithGoogleMaps(
                    to: destination,
                    destinationName: "San Francisco",
                    travelMode: "walking",
                    isAccessibilityMode: true
                )
            } label: {
                Text("test navigation")
            }
             */

        }
        .onAppear {
            
            print("fhbrsddrj")
        }
    }
     
}



struct SpeechToTextView_Previews: PreviewProvider {
    static var previews: some View {
        SpeechToTextView()
    }
}


