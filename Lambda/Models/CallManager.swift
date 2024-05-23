//
//  CallManager.swift
//  Lambda
//
//  Created by Maxim Dmitrochenko on 17.05.2024.
//

import Foundation
import StreamVideo
import StreamVideoUIKit
import StreamVideoSwiftUI

class CallManager {
    static let shared = CallManager()
    
    struct Constants {
        static let userToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiQXVycmFfU2luZyIsImlzcyI6Imh0dHBzOi8vcHJvbnRvLmdldHN0cmVhbS5pbyIsInN1YiI6InVzZXIvQXVycmFfU2luZyIsImlhdCI6MTcxNjI5NjkxNiwiZXhwIjoxNzE2OTAxNzIxfQ.RlF6RT24ZUFjrBHYNsWrtsYPKq5laDsnU0M0N_erF8I"
    }
    
    private var video: StreamVideo?
    private var videoUI: StreamVideoUI?
    public private(set) var callViewModel: CallViewModel?
    
    struct UserCredentials {
        let user: User
        let token: UserToken
    }
    
    func setup(email: String) {
        setupCallViewModel()
        
        //UserDefaults.set(UUID().uuidString, forKey: "thisUserId")
        
        let credential = UserCredentials(
            user: User(id: email, name: email),
            token: UserToken(rawValue: Constants.userToken))
        
        UserDefaults.standard.set(Constants.userToken, forKey: "key")
        
        let video = StreamVideo(
            apiKey: "mmhfdzb5evj2",
            user: credential.user,
            token: credential.token) { result in
                //Refresh
                result(.success(credential.token ))
            }
        
        let videoUI = StreamVideoUI(streamVideo: video)
        
        self.video = video
        self.videoUI = videoUI
    }
    
    private func setupCallViewModel() {
        guard callViewModel == nil else { return }
        DispatchQueue.main.async {
            self.callViewModel = CallViewModel()
        }
    }
}
