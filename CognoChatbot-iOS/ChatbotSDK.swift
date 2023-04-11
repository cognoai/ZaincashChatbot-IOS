//
//  ChatbotSDK.swift
//  CognoChatbot-iOS
//
//  Created by Khirish Meshram on 02/05/22.
//

import Foundation
import WebKit
import AVFoundation
import Speech

public class ChatbotSDK: UIViewController, UIWebViewDelegate, WKUIDelegate, WKNavigationDelegate {
    
    var webViewGlobal: WKWebView = WKWebView()
    let webViewController = UIViewController()
    var customView: UITextView = UITextView()
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    let audioSession = AVAudioSession.sharedInstance()
    let synth = AVSpeechSynthesizer()
    
//  Access token verification
    public func verifyToken(viewController: UIViewController, completion: @escaping (Bool) -> ()) {
        
        let url = URL(string: Constants.botUrl + Constants.tokenVerificationUrl)!
        var request = URLRequest(url: url)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        let parameters: [String: Any] = [
            "bot_id": Constants.customerID,
            "access_token": Constants.accessToken
        ]
        
        request.httpBody = parameters.percentEncoded()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let response = response as? HTTPURLResponse,
                  error == nil
            else { return }
            
            guard (200 ... 299) ~= response.statusCode else { return }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any]
                
                if let jsonData = json, jsonData["status"] as? Int == 200 {
                    Constants.isTokenVerify = true
                    
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } else {
                    Constants.isTokenVerify = false
                    
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
                
            } catch let error as NSError {
                print(error)
            }
        }
        
        task.resume()
    }

// Check and expire livechat session id
    public func verifyLiveChatSessionID(viewController: UIViewController) {

        if Constants.mobileLiveChatSessionID == "" {
            return
        }

        let url = URL(string: Constants.botUrl + Constants.livechatSessionIDVerificationUrl)!
        var request = URLRequest(url: url)

        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"

        let parameters: [String: Any] = [
            "livechat_session_id": Constants.mobileLiveChatSessionID,
        ]

        request.httpBody = parameters.percentEncoded()

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let response = response as? HTTPURLResponse,
                  error == nil
            else { return }

            guard (200 ... 299) ~= response.statusCode else { return }

            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any]

                if let jsonData = json, jsonData["status"] as? Int == 440 {
                    Constants.mobileLiveChatSessionID = ""
                }

            } catch let error as NSError {
                print(error)
            }
        }

        task.resume()
    }
    
    
//  Display & configure webview while token verification is true
    public func dispWebView(viewController: UIViewController) {
        
        verifyLiveChatSessionID(viewController: self)
        if Constants.isTokenVerify {
            let config: WKWebViewConfiguration = WKWebViewConfiguration()
            config.preferences.javaScriptCanOpenWindowsAutomatically = true
            config.userContentController.add(self, name: "close")
            config.userContentController.add(self, name: "speechToText")
            config.userContentController.add(self, name: "textToVoice")
            config.userContentController.add(self, name: "terminateTextToVoice")
            config.userContentController.add(self, name: "reloadChatbot")
            config.userContentController.add(self, name: "setChatbotSessionID")
            config.userContentController.add(self, name: "setLiveChatSessionID")
            config.userContentController.add(self, name: "reloadChatbotForLiveChat")
            config.userContentController.add(self, name: "setSelectedLanguage")
            
            
            var webView: WKWebView? = nil {
                didSet {
                    webView?.navigationDelegate = self
                    webView?.uiDelegate = self
                }
            }
            
            webView = WKWebView()
            if #available(iOS 13.0, *) {
                let preferences: WKWebpagePreferences = WKWebpagePreferences()
                if #available(iOS 14.0, *) {
                    preferences.allowsContentJavaScript = true
                } else {
                    webView?.configuration.preferences.javaScriptEnabled = true
                }
                webView?.configuration.defaultWebpagePreferences = preferences
            } else {
                let preferencesWK = WKPreferences()
                preferencesWK.javaScriptEnabled = true
                webView?.configuration.preferences = preferencesWK
            }
            
            webView = WKWebView(frame: webViewController.view.frame, configuration: config)
            webView?.translatesAutoresizingMaskIntoConstraints = true
            webView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            guard let wv = webView else { return }
            webViewController.view.addSubview(wv)
//  Change string url to with verified url
            if let _url = URL(string: Constants.botUrl + "/chat/index/?id=" + Constants.customerID + "&channel=iOS&mobile_session_id=" + Constants.mobileChatbotSessionID + "&livechat_session_id=" + Constants.mobileLiveChatSessionID + "&selected_language=" + Constants.chatbotSelectedLanguage) {
                let request = URLRequest(url: _url)
                webView?.load(request)
            }
            webViewController.modalPresentationStyle = .fullScreen
            viewController.present(webViewController, animated: true, completion: nil)
            webViewGlobal = wv
        }
    }
    
//  Text to Voice Conversion
    public func textToVoice(text: String, lang: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
        if utterance.voice == nil {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        synth.speak(utterance)
    }
    
//  Start recording audio
    private func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        do {
            try audioSession.setCategory(AVAudioSession.Category.record, mode: AVAudioSession.Mode.measurement, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        self.recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            var isFinal = false
            
            if result != nil {
                self.customView.text = result?.bestTranscription.formattedString ?? ""
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        self.audioEngine.prepare()
        
        do {
            try self.audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
    }
// Navigate webview according to url
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            if url.description.lowercased().range(of: "http://") != nil ||
                url.description.lowercased().range(of: "https://") != nil ||
                url.description.lowercased().range(of: "mailto:") != nil ||
                url.description.lowercased().range(of: "tel://") != nil ||
                url.description.lowercased().range(of: "&channel=ios") != nil {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        return nil
    }

}

//  Handle User response for Webview Interface
extension ChatbotSDK: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        if message.name == "close" {
            webViewController.dismiss(animated: true) {
                self.webViewGlobal.cleanAllCookies()
                self.webViewGlobal.refreshCookies()
            }
        } else if message.name == "speechToText" {

            startRecording()
            var alertStyle = UIAlertController.Style.actionSheet
            var width: CGFloat = CGFloat()
            if (UIDevice.current.userInterfaceIdiom == .pad) {
                alertStyle = UIAlertController.Style.alert
            }
            
            let alertController = UIAlertController(title: "\n\n\n\n\n\n", message: nil, preferredStyle: alertStyle)
            let margin: CGFloat = 8.0
            width = alertController.view.bounds.size.width
            
            if (UIDevice.current.userInterfaceIdiom == .pad) {
                width = 290
            }
            
            let rect = CGRect(x: margin, y: margin, width: width - margin * 4.0, height: 100.0)
            
            customView = UITextView(frame: rect)
            customView.backgroundColor = UIColor.clear
            customView.font = UIFont(name: "Helvetica", size: 20)
            customView.text = "Say something, I'm listening!"
            alertController.view.addSubview(customView)
            
            let doneAction = UIAlertAction(title: "DONE", style: UIAlertAction.Style.cancel, handler: { _ in
                if let voiceText = self.customView.text {
                    self.audioEngine.stop()
                    self.recognitionRequest?.endAudio()
                    self.webViewGlobal.evaluateJavaScript("speech_intent_for_ios('\(voiceText)')", completionHandler: nil)
                }
            })
            alertController.addAction(doneAction)
            
            if let presenter = alertController.popoverPresentationController {
                presenter.sourceView = self.view
                presenter.permittedArrowDirections = .init(rawValue: 0)
                presenter.sourceRect = webViewController.view.bounds
            }
            
            webViewController.present(alertController, animated: true, completion: nil)
            
        } else if message.name == "textToVoice" {
            let sentData = message.body as! Dictionary<String, String>
            if let message: String = sentData["message_to_be_spoken"], let language: String = sentData["selected_language"] {
                textToVoice(text: message, lang: language)
            }
            
        } else if message.name == "terminateTextToVoice" {
            synth.stopSpeaking(at: .immediate)
        } else if message.name == "reloadChatbot" {
            Constants.mobileChatbotSessionID  = ""
            Constants.mobileLiveChatSessionID = ""
            if let _url = URL(string: Constants.botUrl + "/chat/index/?id=" + Constants.customerID + "&channel=iOS&mobile_session_id=" + Constants.mobileChatbotSessionID + "&livechat_session_id=" + Constants.mobileLiveChatSessionID + "&selected_language=" + Constants.chatbotSelectedLanguage) {
                let request = URLRequest(url: _url)
                webViewGlobal.load(request)
            }
        } else if message.name == "reloadChatbotForLiveChat" {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1){
                
                if let _url = URL(string: Constants.botUrl + "/chat/index/?id=" + Constants.customerID + "&channel=iOS&mobile_session_id=" + Constants.mobileChatbotSessionID + "&livechat_session_id=" + Constants.mobileLiveChatSessionID + "&selected_language=" + Constants.chatbotSelectedLanguage) {
                    let request = URLRequest(url: _url)
                    self.webViewGlobal.load(request)
                }
            }
        } else if message.name == "setChatbotSessionID" {
            
            let sentData = message.body as! Dictionary<String, String>
            Constants.mobileChatbotSessionID = sentData["mobile_session_id"] ?? ""
        } else if message.name == "setLiveChatSessionID" {
            
            let sentData = message.body as! Dictionary<String, String>
            Constants.mobileLiveChatSessionID = sentData["livechat_session_id"] ?? ""
        } else if message.name == "setSelectedLanguage" {
            
            let sentData = message.body as! Dictionary<String, String>
            Constants.chatbotSelectedLanguage = sentData["selected_language"] ?? ""
        }
    }
}

extension Dictionary {
    func percentEncoded() -> Data? {
        return map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        var allowed = CharacterSet.urlQueryAllowed
        
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        
        return allowed
    }()
}

//  Clear old webview data clear cache
extension WKWebView {
    
    func cleanAllCookies() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
            }
        }
    }
    
    func refreshCookies() {
        self.configuration.processPool = WKProcessPool()
    }
}


