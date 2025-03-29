//
//  ImageUtils.swift
//  YOLO
//
//  Created by 施炎培 on 2024/10/31.
//  Copyright © 2024 Ultralytics. All rights reserved.
//
//MARK: This file is deprecated
import UIKit
import Photos

enum ObjectRegion: String {
    case left = "left"
    case right = "right"
    case front = "front"
}

//For testing the image sent
func saveImageToPhotos(image: UIImage?) {
    guard let image = image else {return}
    PHPhotoLibrary.requestAuthorization { status in
        if status == .authorized {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        } else {
            print("Permission to access photos was denied.")
        }
    }
}

func encodeImageToBase64(image: UIImage) -> String? {
    // Compress the image as JPEG with a quality factor
    guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
    // Encode the Data as base64
    let base64String = imageData.base64EncodedString(options: .lineLength64Characters)
    return base64String
}

func getRegion(x1: CGFloat, x2: CGFloat, y1: CGFloat, y2: CGFloat, width: CGFloat, height: CGFloat) -> ObjectRegion {
    let line1Slope = height / (width / 3 - width / 4)
    let line1Intercept = -3 * height
    let line2Slope = height / (width / 3 * 2 - width / 4 * 3)
    let line2Intercept = 9 * height

    func isLeft(x: CGFloat, y: CGFloat) -> Bool {
        return y > line1Slope * x + line1Intercept
    }

    func isRight(x: CGFloat, y: CGFloat) -> Bool {
        return y > line2Slope * x + line2Intercept
    }

    let centerX = (x1 + x2) / 2
    let centerY = (y1 + y2) / 2

    if isLeft(x: centerX, y: centerY) {
        return .left
    } else if isRight(x: centerX, y: centerY) {
        return .right
    } else {
        return .front
    }
}

func removeDuplicates(from items: [[String: Any]]) -> [[String: Any]] {
    var uniqueItems: [[String: Any]] = []

    for item in items.reversed() {
        guard let box = item["box"] as? [CGFloat],
              box.count == 4 else { continue }

        var isDuplicate = false

        for uniqueItem in uniqueItems {
            guard let uniqueBox = uniqueItem["box"] as? [CGFloat],
                  uniqueBox.count == 4 else { continue }

            // Calculate Intersection over Union (IoU)
            let iou = calculateIoU(box1: box, box2: uniqueBox)
            if iou > 0.5 {  // Consider as duplicate if IoU is greater than 0.5
                isDuplicate = true
                break
            }
        }

        if !isDuplicate {
            uniqueItems.append(item)
        }
    }

    return uniqueItems
}

func calculateIoU(box1: [CGFloat], box2: [CGFloat]) -> CGFloat {
    let (x1, y1, x2, y2) = (box1[0], box1[1], box1[2], box1[3])
    let (ux1, uy1, ux2, uy2) = (box2[0], box2[1], box2[2], box2[3])

    let interX1 = max(x1, ux1)
    let interY1 = max(y1, uy1)
    let interX2 = min(x2, ux2)
    let interY2 = min(y2, uy2)
    let interArea = max(0, interX2 - interX1) * max(0, interY2 - interY1)

    let box1Area = (x2 - x1) * (y2 - y1)
    let box2Area = (ux2 - ux1) * (uy2 - uy1)
    let iou = interArea / (box1Area + box2Area - interArea)

    return iou
}





