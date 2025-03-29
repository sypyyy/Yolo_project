//
//  InteractionModel.swift
//  YOLO
//
//  Created by 施炎培 on 2024/11/29.
//  Copyright © 2024 Ultralytics. All rights reserved.
//
import Foundation

class InteractionModel {
    
    func refreshConversation() {
        let url = URL(string: "\(NetworkManager.baseUrl)/refesh_thread/")!
        let builder = NetworkManager.RequestBuilder(url: url)
            .setMethod("POST")
        
        NetworkManager.shared.makeRequest(builder: builder) { data, response, error in
            
        }
    }
    
    func sendMessage(msg: String) {
        
        let url = URL(string: "\(NetworkManager.baseUrl)/chat/")!

        let builder = NetworkManager.RequestBuilder(url: url)
            .setMethod("POST")
            .addHeader(key: "Content-Type", value: "application/json")
            .setBody("{\"text\": \"\(msg)\"}".data(using: .utf8))

        NetworkManager.shared.makeRequest(builder: builder) { data, response, error in
            if let error = error {
                print("Error:", error)
                return
            }
            if let data = data, let _ = response {
                //print("Response:", response)
                //print("Data:", String(data: data, encoding: .utf8) ?? "")
                do {
                        let decodedResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                        print("Decoded Response: \(decodedResponse)")
                    self.handleChatResponse(decodedResponse)
                    } catch {
                        print("Decoding Error: \(error)")
                        print("\(String(data: data, encoding: .utf8))")
                    }
            }
        }
    }
    
    actor ActionRequestManager {
        private var request: ClientActionCompleteRequest

        init(runID: String) {
            request = ClientActionCompleteRequest(toolOutput: [], runId: runID)
        }

        func addToolOutput(toolCallId: String, output: String) {
            request.addToolOutput(toolCallId: toolCallId, output: output)
        }
        
        func getRequest() -> ClientActionCompleteRequest {
            return request
        }
    }

    
    func handleChatResponse(_ resp: ChatResponse) {
        if !resp.requiredActions.isEmpty, let runID = resp.runID {
            
            let actionCompleteRequest = ActionRequestManager(runID: runID)
            let group = DispatchGroup()
            let queue = DispatchQueue.global()
            resp.requiredActions.forEach { action in
                let funcName = action.functionName
                if(funcName == "search_recently_seen_objects") {
                    handle_search_recent_object_action(group: group, action: action, actionCompleteRequest: actionCompleteRequest)
                } else if(funcName == "navigate_user_to") {
                    handle_navigate_user_action(group: group, action: action, actionCompleteRequest: actionCompleteRequest)
                }
            }
            group.notify(queue: DispatchQueue.global()) {[weak self] in
                guard let self = self else {return}
                Task {
                    await self.sendActionComplete(request: actionCompleteRequest.getRequest())
                }
            }
            
        }
        else if(resp.message.contains("Text Inference")) {
            TextDetectManager.shared.llmResponse = resp.message
        }
        else {
            if(!SpeechRecognizer.shared.isListening) {
                SpeechSpeaker.shared.speak(text: resp.message)
            }
        }
    }
    
    private func handle_search_recent_object_action(group: DispatchGroup, action: RequiredAction, actionCompleteRequest: ActionRequestManager) {
        group.enter()
        let argumentsAsJson = JSONHelper(action.arguments ?? "")
        guard let keyword = argumentsAsJson.get("keyword")?.asString() else {
            print("Missing argument for search_recently_seen_objects!!!")
            group.leave()
            return
        }
        Task {
            
            NotificationCenter.default.post(
                                name: .askedTOPerformSeenObjectSearch,
                                object: nil,
                                userInfo: ["searchString": keyword]
                            )
            let results = await SeenObjectService.shared.searchFor(target: keyword).map { obj in
                obj.stringForLLM()
            }
            await actionCompleteRequest.addToolOutput(toolCallId: action.toolCallID, output: "\(results)")
            //addToolOutput(toolCallId: , output: )
            group.leave()
        }
    
    }
    
    private func handle_navigate_user_action(group: DispatchGroup, action: RequiredAction, actionCompleteRequest: ActionRequestManager) {
        group.enter()
        let argumentsAsJson = JSONHelper(action.arguments ?? "")
        guard let lat = argumentsAsJson.get("latitude")?.asDouble(),
        let lon = argumentsAsJson.get("longitude")?.asDouble()
        else {
            print("Missing argument for navigate_user_to!!!")
            group.leave()
            return
        }
        Task {
            
            NavigationHandler.navigateWithGoogleMaps(to: .init(latitude: .init(floatLiteral: lat), longitude: .init(floatLiteral: lon)), destinationName: "")
            await actionCompleteRequest.addToolOutput(toolCallId: action.toolCallID, output: "navigationCompleted")
            //addToolOutput(toolCallId: , output: )
            group.leave()
        }
    
    }
    
    func sendActionComplete(request: ClientActionCompleteRequest) {
        // Define the URL
        let url = URL(string: "\(NetworkManager.baseUrl)/client_action_done/")!

        let requestPayload = request
        do {
            let jsonData = try JSONEncoder().encode(requestPayload)
            
            // Create the request using the NetworkManager
            let builder = NetworkManager.RequestBuilder(url: url)
                .setMethod("POST")
                .addHeader(key: "Content-Type", value: "application/json")
                .setBody(jsonData)
            
            NetworkManager.shared.makeRequest(builder: builder) { data, response, error in
                if let error = error {
                    print("Error:", error)
                    return
                }
                if let data = data, let _ = response {
                    //print("Response:", response)
                    //print("Data:", String(data: data, encoding: .utf8) ?? "")
                    do {
                            let decodedResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                            print("Decoded Response: \(decodedResponse)")
                        self.handleChatResponse(decodedResponse)
                        } catch {
                            print("Decoding Error: \(error)")
                        }
                }
            }
        } catch {
            print("Failed to encode request payload:", error)
        }

    }
}
