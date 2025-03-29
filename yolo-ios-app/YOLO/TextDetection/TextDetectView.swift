//
//  TextDetectView.swift
//  YOLO
//
//  Created by 施炎培 on 2025/2/7.
//  Copyright © 2025 Ultralytics. All rights reserved.
//

import SwiftUI
import AVFoundation
import Vision



class TextDetectManager: NSObject, ObservableObject {
    @Published var detectedText: String = ""
    @Published var sceneResults: [VNClassificationObservation] = []
    @Published var llmResponse: String = "No response yet"
    @Published var img: UIImage? = nil
    
    static let shared = TextDetectManager()
    
    
    
    override init() {
        super.init()
        //setupCaptureSession()
        //startCaptureTimer()
    }
    
    func detectText(img: UIImage?) {
        
        guard let img = img else {return}
        Task {
            performTextRecognition(image: img)
        }
        
    }
    
  
    
    
    private func performTextRecognition(image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let textRequest = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  !observations.isEmpty else { return }
            
            let detectedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: " ")
            
            DispatchQueue.main.async {
                self?.img = image
                self?.detectedText = detectedText
                //print("detected text!\(detectedText)")
                if !detectedText.isEmpty {
                    Task {
                        //InteractionModel().sendMessage(msg: "Pls guess the scene or the object based on this text detected by a phone camera:\(detectedText) You should only give short answers for example but not limited to: store sign: starbucks, book, laptop or unidentified, and u should always start the answer with 'Text Inference:'")
                    }
                    //self?.saveImageWithText(image: image, text: detectedText)
                }
            }
        }
        /*
        // Add scene analysis request
        let sceneRequest = VNClassifyImageRequest { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation] else { return }
            DispatchQueue.main.async {
                self?.sceneResults = Array(results.prefix(3)) // Top 3 scene results
            }
        }
        */
        try? requestHandler.perform([textRequest])
         
    }
    
    
}


struct TextDetectionCameraView: View {
    @StateObject private var cameraManager = TextDetectManager.shared
    
    var body: some View {
        VStack {
            
            
            VStack(alignment: .leading, spacing: 10) {
                if let img = cameraManager.img {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 300, height: 500)
                }
                Text("Detected Text:")
                    .font(.headline)
                Text(cameraManager.detectedText)
                    .font(.body)
                    .padding(.bottom)
                
                Text("\(cameraManager.llmResponse)")
                    .font(.headline)
                /*
                ForEach(cameraManager.sceneResults, id: \.identifier) { result in
                    HStack {
                        Text(result.identifier)
                            .font(.body)
                        Spacer()
                        Text("\(Int(result.confidence * 100))%")
                            .foregroundColor(.secondary)
                    }
                }
                 */
            }
            .padding()
            
            
        }
    }
}
