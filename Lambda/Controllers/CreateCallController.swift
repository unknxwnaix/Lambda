//
//  CreateCallController.swift
//  Lambda
//
//  Created by Maxim Dmitrochenko on 03.04.2024.
//

import UIKit
import Combine
import StreamVideo
import StreamVideoUIKit
import StreamVideoSwiftUI

class CreateCallController: UIViewController {
    
    private var cancellables = Set<AnyCancellable>()
    private var activeCallView: UIView?
    
    let callIdField: UITextField = {
        let tf = UITextField()
        tf.textColor = .label
        tf.tintColor = .systemBlue
        tf.textAlignment = .left
        tf.font = .systemFont(ofSize: 17, weight: .semibold)
        
        tf.layer.cornerRadius = 11
        tf.backgroundColor = .secondarySystemBackground
        
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 17, height: 0))
        tf.leftViewMode = .always
        
        tf.attributedPlaceholder = NSAttributedString(string: "Push The Call Id Here", attributes: [NSAttributedString.Key.foregroundColor : UIColor.secondaryLabel])
        tf.autocapitalizationType = .sentences
        tf.autocorrectionType = .default
        return tf
    }()
    
    private let button: UIButton = {
        let button = UIButton()
        button.setTitle("Join Call", for: .normal)
        button.backgroundColor = .systemBlue
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.layer.cornerRadius = 10
        //    button.setImage(UIImage(systemName: "plus"), for: .normal)?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
//        let button = UIBarButtonItem(title: "Create Call", style: .done, target: self, action: #selector(createCall))
//        button.tintColor = .systemPurple
//        navigationItem.rightBarButtonItem = button
        setupUI()
        self.button.addTarget(self, action: #selector(createCall), for: .touchUpInside)
        listenForIncomingCalls()
    }
    
    private func setupUI() {
        self.view.addSubview(button)
        self.view.addSubview(callIdField)
        button.translatesAutoresizingMaskIntoConstraints = false
        callIdField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: 35),
            button.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.6),
            button.heightAnchor.constraint(equalToConstant: 45),
            
            callIdField.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            callIdField.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -35),
            callIdField.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.6),
            callIdField.heightAnchor.constraint(equalToConstant: 45),
        ])
    }
    
    @objc private func createCall() {
        view.endEditing(true)
        if callIdField == nil { return }
        self.tabBarController?.tabBar.isHidden = true
        print("Trying to join a call")
        guard let callViewModel = CallManager.shared.callViewModel else {
            print("Error: callViewModel is nil")
            return
        }
        
        callViewModel.joinCall(callType: .default, callId: self.callIdField.text ?? "")
//        callViewModel.startCall(callType: .default,
//                                callId: UUID().uuidString, members: [])
        showCallUI()
    }
    
    private func listenForIncomingCalls() {
        guard let callViewModel = CallManager.shared.callViewModel else {
            print("Error: callViewModel is nil in listenForIncomingCalls")
            return
        }
        
        callViewModel.$callingState.sink { [weak self] newState in
            switch newState {
            case .incoming(_):
                DispatchQueue.main.async {
                    self?.showCallUI()
                }
            case .idle:
                DispatchQueue.main.async {
                    self?.hideCallUI()
                    self?.tabBarController?.tabBar.isHidden = false
                }
            default:
                print("Error: Unexpected state in listenForIncomingCalls")
                break
            }
        }
        .store(in: &cancellables)
    }
    
    private func showCallUI() {
        print("Trying to show call UI")
        guard let callViewModel = CallManager.shared.callViewModel else {
            print("Error: callViewModel is nil in showCallUI")
            return
        }
        
        let callVC = CallViewController.make(with: callViewModel)
        addChild(callVC)
        callVC.view.frame = view.bounds
        view.addSubview(callVC.view)
        callVC.didMove(toParent: self)
        activeCallView = callVC.view
    }
    
    private func hideCallUI() {
        activeCallView?.removeFromSuperview()
        activeCallView = nil
    }
}
