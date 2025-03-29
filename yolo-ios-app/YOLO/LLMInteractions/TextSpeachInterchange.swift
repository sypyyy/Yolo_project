//
//  TextSpeachInterchange.swift
//  YOLO
//
//  Created by 施炎培 on 2024/10/31.
//  Copyright © 2024 Ultralytics. All rights reserved.
//

import AVFoundation
import Speech
import NaturalLanguage
import UIKit

class SpeechRecognizer {
    static let shared = SpeechRecognizer()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var onResult: ((String) -> Void) = {_ in }
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition not authorized")
            }
        }
    }
    
    var isListening = false
    
    func startRecognition(onResult: @escaping (String) -> Void) {
        if(isListening) {
            return
        }
        isListening = true
        SpeechSpeaker.shared.stopSpeaking()
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to reset audio session: \(error.localizedDescription)")
        }
        self.onResult = onResult
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine couldn't start: \(error.localizedDescription)")
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                onResult(result.bestTranscription.formattedString)
            }
            if error != nil {
                print("error stopping!!!")
                self.stopRecognition()
            }
        }
    }
    
    func stopRecognition() {
        isListening = false
        self.onResult("")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
    }
}

class SpeechSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    
    static let shared = SpeechSpeaker()
    
    
    //TTS
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }

    func speak(text: String) {
        /*
        if let googleMapsURL = URL(string: "https://www.google.com/maps/@42.585444,13.007813,6z") {
            if UIApplication.shared.canOpenURL(googleMapsURL) {
                UIApplication.shared.open(googleMapsURL, options: [:], completionHandler: nil)
            } else {
                print("Google Maps is not installed.")
            }
        }
         */
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set audio session: \(error.localizedDescription)")
        }
        SpeechRecognizer.shared.stopRecognition()
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate) // Stop immediately, or use `.word` to finish the current word
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }
    
    /*
    //STT
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // This is the completion handler we'll call when we find the main noun.
    var onNounDetected: ((String?) -> Void)?

    // Start speech recognition
    func startListening() {
        // Check for permissions
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else {
                print("Speech recognition not authorized.")
                return
            }
            DispatchQueue.main.async {
                self.startRecognitionSession()
            }
        }
    }
    
    private var lastUserSpokeTimeStamp: Date? = Date()
    private var lastRecognizedText: String = ""
    private func startRecognitionSession() {
        // Configure the audio session for recording
        /*
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(., mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        */
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        recognitionRequest?.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            self.lastUserSpokeTimeStamp = Date()
            if let result = result, !self.speechSynthesizer.isSpeaking {
                let confidence = result.bestTranscription.segments[0].confidence
                print(confidence)
                let currentText = result.bestTranscription.formattedString
                self.lastRecognizedText = currentText
                
                print("Recognized Text: \(self.lastRecognizedText)")
                Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
                    
                    if let lastTime = self.lastUserSpokeTimeStamp {
                        if Date().timeIntervalSince(lastTime) >= 1.5, currentText == self.lastRecognizedText {
                            timer.invalidate()
                            let recognizedText = self.lastRecognizedText
                            let mainNoun = self.extractMainNoun(from: self.lastRecognizedText)
                            print("Main Noun: \(mainNoun)")
                            print("End of Text: \(recognizedText)")
                            if let mainNoun = mainNoun, let onNounDetected = self.onNounDetected {
                                onNounDetected(mainNoun)
                            }
                            self.handleEndOfSpeech()
                        }
                    }
                }
                
            }
            
             
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            if(!self.speechSynthesizer.isSpeaking) {
                self.recognitionRequest?.append(buffer)
            }
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    private func handleEndOfSpeech() {
        self.lastRecognizedText = ""
        // Cancel the current recognition task to stop capturing input
        recognitionTask?.cancel()
        recognitionTask = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        
        // Restart recognition
        startRecognitionSession()
    }

    private func extractMainNoun(from text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        var mainNoun: String?

      
            // For multiple words, use enumerateTags as before
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
                if tag == .noun {
                    mainNoun = String(text[tokenRange])
                    return false  // Stop after finding the first noun
                }
                return true  // Continue searching
            }
        
        
        return mainNoun
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
     
     */
}

/*
extension ViewController {
    func setupSpeechHandler() {
        // Set up completion handler to handle detected noun
        speechHandler.onNounDetected = { [weak self] noun in
            guard let noun = noun else {
                print("No noun detected.")
                return
            }
            print("Detected noun: \(noun)")
            // Optionally, call the capture-and-process function with the detected noun
            let imageHandler = ImageHandleModel.shared
            self?.speechHandler.speak(text: "Looking for \(noun)")
            imageHandler.setNewTarget(target: noun)
            self?.sendCurrentFrame()
        }
        speechHandler.startListening()
    }
}
*/
