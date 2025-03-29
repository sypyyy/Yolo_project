//
//  RequestViewModel.swift
//  YOLO
//
//  Created by 施炎培 on 2024/11/29.
//  Copyright © 2024 Ultralytics. All rights reserved.
//
import Foundation

class ClientActionCompleteRequest: Codable {
    class ToolOutput: Codable {
        let toolCallId: String
        let output: String
        
        enum CodingKeys: String, CodingKey {
            case toolCallId = "tool_call_id"
            case output
        }
        
        init(toolCallId: String, output: String) {
            self.toolCallId = toolCallId
            self.output = output
        }
    }
    
    var toolOutput: [ToolOutput]
    let runId: String
    
    enum CodingKeys: String, CodingKey {
        case toolOutput = "tool_output"
        case runId = "run_id"
    }
    
    init(toolOutput: [ToolOutput], runId: String) {
        self.toolOutput = toolOutput
        self.runId = runId
    }
    
    // Method to add a tool output dynamically
    func addToolOutput(toolCallId: String, output: String) {
        self.toolOutput.append(ToolOutput(toolCallId: toolCallId, output: output))
    }
}
