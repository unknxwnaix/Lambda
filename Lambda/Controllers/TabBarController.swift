//
//  TabBarController.swift
//  Lambda
//
//  Created by Maxim Dmitrochenko on 03.04.2024.
//

import UIKit

class TabBarController: UITabBarController {
    
    let containerView: UIView = {
        let uv = UIView()
        uv.clipsToBounds = true
        return uv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTabs()
        setupUI()
    }
    
    
    // MARK: - Tab Setup
    private func setupTabs() {
        
        let userProfile = self.createNav(title: "Profile", image: UIImage(systemName: "person.fill"), vc: UserProfileController(), navTitle: "Your Profile", navButtonTitle: "Logout", buttonTarget: LoginController(),  buttonAction: #selector(self.didTapLogout))
        // let callHistory = self.createNav(title: "History", image: UIImage(systemName: "clock.fill"), vc: CallHistoryController(), navTitle: "History")
        let userChats = self.createNav(title: "Chats", image: UIImage(systemName: "message.fill"), vc: userChatsViewController(), navTitle: "Your Chats",
            navButtonTitle: "Search", buttonTarget: LoginController(),  buttonAction: #selector(self.didTapComposeButton))
        let createCall = self.createNav(title: "New Call", image: UIImage(systemName: "phone.badge.plus.fill"), vc: CreateCallController())
        
        self.setViewControllers([userProfile, userChats, createCall], animated: true)
        
        
        self.tabBar.tintColor = .systemBlue
        setupTabAppearance(tab: self.tabBar)
    }
    
    private func setupUI() {
        self.view.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: self.view.topAnchor),
            containerView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            containerView.widthAnchor.constraint(equalTo: self.view.widthAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 60),
        ])
    }
    
    
    private func createNav(title: String, image: UIImage?, vc: UIViewController, navTitle: String? = nil, navButtonTitle: String? = nil, buttonTarget: UIViewController? = nil, buttonAction: Selector? = nil) -> UINavigationController {
        var nav = UINavigationController(rootViewController: vc)
        
        
        nav.tabBarItem.title = title
        nav.tabBarItem.image = image
        
        
        if navTitle != nil {
            nav.viewControllers.first?.navigationItem.title = navTitle
            if navButtonTitle != nil,
               buttonAction != nil,
               buttonTarget != nil {
               let button = UIBarButtonItem(title: navButtonTitle, style: .plain, target: buttonTarget, action: buttonAction)
                button.tintColor = .systemBlue
                nav.viewControllers.first?.navigationItem.rightBarButtonItem = button
            }

        }
        
        nav = setupNavAppearance(nav: nav)
        
        return nav
    }
    
    // MARK: - Setup Appearance By Theme
    private func setupNavAppearance(nav: UINavigationController) -> UINavigationController {
        if #available(iOS 13.0, *) {            nav.navigationBar.backgroundColor = UIColor.systemGray6
            containerView.backgroundColor = UIColor.systemGray6
        } else {
            nav.navigationBar.backgroundColor = UIColor.systemGray
            containerView.backgroundColor = UIColor.systemGray
        }
        
        return nav
    }
    
    private func setupTabAppearance(tab: UITabBar) {
        
        if #available(iOS 13.0, *) {
            tab.backgroundColor = UIColor.systemGray6
        } else {
            tab.backgroundColor = UIColor.systemGray
        }
    }
    
    // MARK: - Selectors
    
    @objc private func didTapLogout() {
        AuthService.shared.signOut { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                AlertManager.showLogoutError(on: self, with: error)
                return
            }
            if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                sceneDelegate.checkAuthentication()
            }
        }
    }
    
    @objc private func didTapComposeButton() {
        let vc = NewConversationViewController()
        vc.completion = { [weak self] result in
            self?.createNewConversation(result: result)
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    private func createNewConversation(result: [String: String]) {
        print("createNewConversation method")
        guard let username = result["username"], let email = result["email"] else {
            print("fail")
            return
        }
        print("success")
        print("\(username) + \(email)")
    }

}
