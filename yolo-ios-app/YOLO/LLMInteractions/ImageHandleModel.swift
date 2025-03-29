//
//  ImageHandleModel.swift
//  YOLO
//
//  Created by 施炎培 on 2024/10/31.
//  Copyright © 2024 Ultralytics. All rights reserved.
//
//MARK: This file is deprecated
import Foundation
import UIKit
import Vision

struct DetectedItem {
    let label: String
    let confidence: Float
    let box: CGRect
    let region: ObjectRegion
}

class ImageHandleModel {
    
    static let shared = ImageHandleModel()
    static let API_KEY = "sk-proj-iVKblkN8Hhl7pc6vNdwnT3BlbkFJFQlBki5ZkyFKCctF8ES5"
    static let API_URL = "https://api.openai.com/v1/chat/completions"
    static let instructions = [
        "Move straight forward", "Move left-forward", "Turn left",
        "Move left-backward", "Step back", "Move right-backward",
        "Turn right", "Move right-forward"
    ]
    static let SYS_INSTRUCTIONS = """
        You are a helpful daily assistant for visually impaired people.
        """
    
    var targetItem: String = "orange"
    
    func setNewTarget(target: String) {
        targetItem = target
    }
    
    func getGuidance(detectionResults: [DetectedItem], item: String, imageBase64: String, completion: @escaping (String?) -> Void) {
        let systemContent = """
        \(ImageHandleModel.SYS_INSTRUCTIONS)
        """
        let userContent = """
        Hello, I am visually impaired and need your assistance to complete the task of 'Searching for the target object in a supermarket'.
        Here is where I stand, and the scene depicted in the image is the view in front of me. Here are the objects around me: \(detectionResults).
        The target object I want to search for is \(item). Could you please guide me to it?
        """

        // Create JSON payload
        let json: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": [
                    ["type": "text", "text": userContent],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
                ]]
            ]
        ]

        // Serialize JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            completion(nil)
            return
        }
        
        // Set up request
        var request = URLRequest(url: URL(string: ImageHandleModel.API_URL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(ImageHandleModel.API_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Execute request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            // Parse response
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                
                completion(nil)
                return}
            guard let choices = jsonResponse["choices"] as? [[String: Any]] else  {
                completion(nil)
                return}
            guard let message = choices.first?["message"] as? [String: Any] else {
                completion(nil)
                return
            }
            guard let guidanceText = message["content"] as? String else {
                completion(nil)
                return
            }
            completion(guidanceText)
            
        }
        
        task.resume()
    }
}


#if YOLO
extension ViewController {
    
    @objc func sendCurrentFrame() {
        
        DispatchQueue.main.async {
            guard let currentFrameImage = self.captureCurrentFrame() else {
                print("Failed to capture current frame.")
                return
            }
            
            // Get bounding box data
            //let boundingBoxes = self.getBoundingBoxesData()
            // Convert image to base64
            guard let imageBase64 = encodeImageToBase64(image: currentFrameImage) else {
                print("Failed to encode image to base64.")
                return
            }
            
            guard let results = self.latestResults else {
                print("No detection results available from YOLO.")
                return}
            let detectedItems = self.detectObjects(from: results, in: self.videoPreview)
            
            // Send guidance request
            ImageHandleModel.shared.getGuidance(detectionResults: detectedItems, item: ImageHandleModel.shared.targetItem, imageBase64: imageBase64) { guidanceText in
                DispatchQueue.main.async {
                    guard let guidanceText = guidanceText else {
                        print("No guidance received.")
                        return
                    }
                    SpeechSpeaker.shared.speak(text: guidanceText)
                    print("Guidance: \(guidanceText)")
                }
            }
        }
        
        
        
    }
 
    //This one has issue, right now it does not draw bounding boxes
    func captureCurrentFrame() -> UIImage? {
        guard let image = self.lastCapturedImage else {
            return nil
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(at: CGPoint.zero)

        // Draw bounding boxes
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return image
        }

        context.saveGState()

        // Adjust the coordinate system
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        // Calculate the scale factor between the image and the videoPreview
        let scaleX = image.size.width / videoPreview.bounds.width
        let scaleY = image.size.height / videoPreview.bounds.height

        for i in 0..<boundingBoxViews.count {
            if !boundingBoxViews[i].shapeLayer.isHidden {
                // Get the frame and label
                let boundingBoxView = boundingBoxViews[i]
                let frame = boundingBoxView.shapeLayer.frame
                let label = boundingBoxView.textLayer.string as? String ?? ""

                // Adjust frame to match image coordinates
                let adjustedFrame = CGRect(
                    x: frame.origin.x * scaleX,
                    y: frame.origin.y * scaleY,
                    width: frame.size.width * scaleX,
                    height: frame.size.height * scaleY
                )

                // Set the color and line width
                context.setStrokeColor(boundingBoxView.shapeLayer.strokeColor ?? UIColor.red.cgColor)
                context.setLineWidth(boundingBoxView.shapeLayer.lineWidth)

                // Draw rectangle
                context.stroke(adjustedFrame)
                // Draw label above the bounding box
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.black.withAlphaComponent(0.7)
                ]
                let textSize = label.size(withAttributes: textAttributes)
                let textOrigin = CGPoint(x: adjustedFrame.origin.x, y: adjustedFrame.origin.y - textSize.height)
                let textRect = CGRect(origin: textOrigin, size: textSize)
                label.draw(in: textRect, withAttributes: textAttributes)
            }
        }

        context.saveGState()

        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        //saveImageToPhotos(image: resultImage)
        return resultImage
    }
    
    func detectObjects(from observations: [VNRecognizedObjectObservation], in view: UIView) -> [DetectedItem] {
        let width = view.bounds.width
        let height = view.bounds.height
        var detectedItems: [DetectedItem] = []

        for observation in observations {
            guard let label = observation.labels.first?.identifier else { continue }
            let confidence = observation.labels.first?.confidence ?? 0
            let boundingBox = observation.boundingBox

            // Calculate bounding box coordinates in pixels
            let x1 = boundingBox.minX * width
            let y1 = boundingBox.minY * height
            let x2 = boundingBox.maxX * width
            let y2 = boundingBox.maxY * height
            let box = CGRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)

            // Determine object region
            let region = getRegion(x1: x1, x2: x2, y1: y1, y2: y2, width: width, height: height)

            // Create a DetectedItem and append to array
            let detectedItem = DetectedItem(label: label, confidence: confidence, box: box, region: region)
            detectedItems.append(detectedItem)
        }
        
        return detectedItems
    }

}
#endif
