//
//  MessageModel.swift
//  YOLO
//
//  Created by 施炎培 on 2024/11/29.
//  Copyright © 2024 Ultralytics. All rights reserved.
//

struct ChatResponse: Codable {
    let threadID: String
    let message: String
    let requiredActions: [RequiredAction]
    let runID: String?
    
    enum CodingKeys: String, CodingKey {
        case threadID = "thread_id"
        case message
        case requiredActions = "required_actions"
        case runID = "run_id"
    }
}

// Required Action Class
struct RequiredAction: Codable {
    let toolCallID: String
    let functionName: String
    let arguments: String?
    
    enum CodingKeys: String, CodingKey {
        case toolCallID = "tool_call_id"
        case functionName = "function_name"
        case arguments = "arguments"
    }
}


