//
//  SceneDelegate.swift
//  Lambda
//
//  Created by Maxim Dmitrochenko on 20.03.2024.
//

import UIKit
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        //CallManager.shared.setUp(email: "user@example.com")
        self.setupWindow(with: scene)
        self.checkAuthentication()
    }
    
    private func setupWindow(with scene: UIScene) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        self.window?.makeKeyAndVisible()
    }
    
    public func checkAuthentication() {
        if Auth.auth().currentUser == nil {
            // go to sign in screen
            DispatchQueue.main.async { [weak self] in
                UIView.animate(withDuration: 0.25) {
                    self?.window?.layer.opacity = 0
                    
                } completion: { [weak self] _ in
                    
                    let nav = UINavigationController(rootViewController: LoginController())
                    nav.modalPresentationStyle = .fullScreen
                    self?.window?.rootViewController = nav
                    
                    UIView.animate(withDuration: 0.25) { [weak self] in
                        self?.window?.layer.opacity = 1
                    }
                }
            }
        } else {
            let vc = TabBarController()
            self.window?.rootViewController = vc
            CallManager.shared.setup(email: Auth.auth().currentUser?.email ?? "test@gmail.com")
            UIView.animate(withDuration: 0.25) { [weak self] in
                self?.window?.layer.opacity = 1
            }
        }
    }
}

