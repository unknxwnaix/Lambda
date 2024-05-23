//
//  ChatViewController.swift
//  Lambda
//
//  Created by Maxim Dmitrochenko on 18.04.2024.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import FirebaseFirestore
import FirebaseAuth
import Combine
import StreamVideo
import StreamVideoUIKit
import StreamVideoSwiftUI

struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
    public var messageNumber: Int
}

struct Sender: SenderType {
    public var photoURL: String?
    public var senderId: String
    public var displayName: String
}

class UserChatViewController: MessagesViewController {
    // MARK: - Variables
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    private var cancellables = Set<AnyCancellable>()
    private var activeCallView: UIView?
    
    private var lastMessage: Message?
    private var conversationId: String?
    
    private var listener: ListenerRegistration?
    
    public var otherUserEmail: String
    public var isNewConversation = false
    
    private var messages = [Message]()
    private var selfSender: Sender?
    
    private var selfAvatar: Avatar?
    private var otherUserAvatar: Avatar?
    
    init(with email: String, isNewConversation: Bool) {
        self.isNewConversation = isNewConversation
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil )
        print(UserDefaults.standard.value(forKey: "email"))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            view.addGestureRecognizer(tapGesture)
        
        messageInputBar.delegate = self
        
        // Загрузка данных о текущем пользователе и сообщений после загрузки представления
        fetchCurrentUser()
        
        let button = UIBarButtonItem(title: "Create Call", style: .done, target: self, action: #selector(createCall))
        button.tintColor = .systemBlue
        navigationItem.rightBarButtonItem = button
        
         listenForIncomingCalls()

    }
    
    private func getConversationId() {
        AuthService.shared.getConversationIDForUsers(currentUserEmail: UserDefaults.standard.value(forKey: "email") as! String, otherUserEmail: otherUserEmail) { [weak self] result in
            guard let self = self else {
                print("Self error")
                return
            }
            
            switch result {
            case .success(let conversationID):
                conversationId = conversationID
            case .failure(let error):
                print("Failed to get conversationID:", error.localizedDescription)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }
    
    private func fetchCurrentUser() {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            print("Error fetching current user's email")
            return
        }

        // Получаем фотографию профиля текущего пользователя
        AuthService.shared.getProfileImageURLAndUsername(for: currentUserEmail) { [weak self] imageURL, username in
            guard let self = self else { return }
            guard let username = username, let imageURL = imageURL else {
                print("Failed to fetch profile image and username for current user")
                return
            }

            // Создаем объект selfSender с данными о текущем пользователе
            self.selfSender = Sender(photoURL: imageURL.absoluteString, senderId: currentUserEmail, displayName: username)

            // Получаем фотографию профиля другого участника чата
            AuthService.shared.getProfileImageURLAndUsername(for: self.otherUserEmail) { [weak self] otherImageURL, _ in
                guard let self = self else { return }
                guard let otherImageURL = otherImageURL else {
                    print("Failed to fetch profile image and username for other user")
                    return
                }

                // Инициализируем экземпляр Avatar для текущего пользователя
                URLSession.shared.dataTask(with: imageURL) { data, _, error in
                    if let error = error {
                        print("Failed to fetch profile image for current user: \(error)")
                        return
                    }
                    guard let data = data, let image = UIImage(data: data) else {
                        print("Failed to convert profile image data to UIImage")
                        return
                    }
                    self.selfAvatar = Avatar(image: image, initials: "")
                }.resume()

                // Инициализируем экземпляр Avatar для другого участника чата
                URLSession.shared.dataTask(with: otherImageURL) { data, _, error in
                    if let error = error {
                        print("Failed to fetch profile image for other user: \(error)")
                        return
                    }
                    guard let data = data, let image = UIImage(data: data) else {
                        print("Failed to convert profile image data to UIImage")
                        return
                    }
                    self.otherUserAvatar = Avatar(image: image, initials: "")
                    DispatchQueue.main.async {
                        self.messagesCollectionView.reloadData()
                    }
                }.resume()
                loadMessages()
            }
        }
    }


    // Метод для очистки массива сообщений
    private func clearMessages() {
        messages.removeAll()
    }

    private func loadMessages() {
        guard let selfSender = self.selfSender else {
            print("Failed to get selfSender")
            return
        }
        
        AuthService.shared.getConversationIDForUsers(currentUserEmail: selfSender.senderId, otherUserEmail: otherUserEmail) { [weak self] result in
            guard let self = self else {
                print("Self error")
                return
            }
            
            switch result {
            case .success(let conversationID):
                print("Conversation ID: \(conversationID)")
                conversationId = conversationID
                self.fetchMessages(for: conversationID)
                
                // Устанавливаем слушателя на коллекцию сообщений для данной беседы
                self.listener = AuthService.shared.listenForMessages(in: conversationID) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success(let message):
                        // Проверяем, есть ли такое сообщение уже в массиве
                        if !self.messages.contains(where: { $0.messageId == message.messageId }) {
                            // Если сообщения нет в массиве, добавляем его
                            self.messages.append(message)
                            // Сортируем сообщения по дате
                            self.sortMessagesByDate()
                            // Обновляем интерфейс
                            self.messagesCollectionView.reloadData()
                            // Прокручиваем к последнему сообщению
                            self.messagesCollectionView.scrollToLastItem(animated: true)
                            // Обновляем последнее сообщение беседы
                            self.fetchMessages(for: conversationID)
                            if let lastMessage = self.lastMessage,
                                let conversationId = self.conversationId {
                                self.updateLatestMessageInDatabase(for: conversationId, with: lastMessage)
                            }
                        }
                    case .failure(let error):
                        print("Failed to receive message: \(error)")
                    }
                }
            case .failure(let error):
                print("Failed to get conversationID: \(error)")
            }
        }
    }

    private func updateLatestMessageInDatabase(for conversationID: String, with message: Message) {
        let db = Firestore.firestore()
        let conversationRef = db.collection("conversations").document(conversationID)
        
        let messageDate = message.sentDate
        let dateString = UserChatViewController.dateFormatter.string(from: messageDate)
        
        var messageContent = ""
        if case .text(let messageText) = message.kind {
            messageContent = messageText
            print("messageContent: \(messageContent)")
            print("messageText: \(messageText)")
        }
        
        let latestMessageData: [String: Any] = [
            "date": dateString,
            "message": messageContent,
            "sender": message.sender.senderId,
            //"is_read": false
        ]
        
        // Обновляем поле latest_message в документе беседы
        conversationRef.updateData(["latest_message": latestMessageData]) { error in
            if let error = error {
                print("Error updating latest message: \(error.localizedDescription)")
            } else {
                print("Latest message updated successfully")
            }
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // Метод для сортировки сообщений по дате
    private func sortMessagesByDate() {
        DispatchQueue.main.async {
            print("before sorting")
            for message in self.messages {
                print (message)
            }
            self.messages.sort { $0.messageNumber < $1.messageNumber }
            print("after sorting")
            for message in self.messages {
                print (message)
            }
            self.messagesCollectionView.reloadData()
            self.lastMessage = self.messages.last
        }
    }


    // Метод, который вызывается при выходе из контроллера или когда он больше не нужен
    deinit {
        if let listener = listener {
            listener.remove()
            print("Listener removed successfully")
        } else {
            print("Listener is nil")
        }
    }

    private func fetchMessages(for conversationID: String) {
        guard let selfSender = self.selfSender else {
            print("Failed to get selfSender")
            return
        }
        
        AuthService.shared.getAllMessagesForConversation(conversationID: conversationID, selfSender: selfSender) { [weak self] result in
            guard let self = self else {
                print("Self error")
                return
            }
            
            switch result {
            case .success(let messages):
                // После получения сообщений обновляем массив сообщений и обновляем интерфейс
                self.messages = messages
                print("Successfully loaded \(messages.count) messages.")
                //self.messagesCollectionView.reloadData()
                self.messagesCollectionView.scrollToLastItem(animated: false)
                self.sortMessagesByDate()
            case .failure(let error):
                print("Failed to load messages: \(error)")
            }
        }
    }
    
    @objc private func createCall() {
        view.endEditing(true)
        self.tabBarController?.tabBar.isHidden = true
        print("Trying to join a call")
        guard let callViewModel = CallManager.shared.callViewModel else {
            print("Error: callViewModel is nil")
            return
        }
        
        let callid = UUID().uuidString
        //callViewModel.joinCall(callType: .default, callId: "default_a90b7b4f-d605-4d18-baf0-4142d360eea7")
        callViewModel.startCall(callType: .default,
                                callId: callid, members: [])
        //showCallUI()
        
        self.messageInputBar.inputTextView.text = ""
        guard let selfSender =  self.selfSender,
              let messageId = createMessageId() else {
            print("error")
            return
        }
        
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text("*System Message*\nUser just start a call. Call id will be sent in next message. Tap and hold to copy following id"),
                              messageNumber: messages.count)
        let message2 = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                               kind: .text(callid as! String),
                              messageNumber: messages.count)
        
        AuthService.shared.getConversationIDForUsers(currentUserEmail: selfSender.senderId, otherUserEmail: otherUserEmail) { [weak self] result in
            guard let self = self else {
                print("Self error")
                return
            }
            
            switch result {
            case .success(let conversationID):
                print("Conversation ID: \(conversationID)")
                AuthService.shared.sendMessage(to: conversationID, message: message, completion: { success in
                    if success {
                        print("message 1 sent")
                        AuthService.shared.sendMessage(to: conversationID, message: message2, completion: { success in
                            if success {
                                print("message 2 sent")
                                self.messagesCollectionView.reloadData()
                                self.updateLatestMessageInDatabase(for: self.conversationId!, with: message2)
                            } else {
                                print("failed to sent")
                            }
                        })
                    } else {
                        print("failed to sent")
                    }
                })
                
            case .failure(let error):
                print("Failed to get conversationID: \(error)")
            }
        }
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


// MARK: - MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate

extension UserChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        guard let sender = selfSender else {
            fatalError("Self Sender is nil, email should be cached")
        }
        return sender
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        var avatar: Avatar?
        
        // Определяем, чье сообщение
        let messageSender = message.sender.senderId
        
        // Устанавливаем соответствующий аватар для текущего пользователя или другого участника чата
        if messageSender == selfSender?.senderId {
            avatar = UserDefaults.standard.value(forKey: "userImage") as? Avatar ?? selfAvatar
        } else {
            avatar = UserDefaults.standard.value(forKey: "otherUserImage") as? Avatar ?? otherUserAvatar
        }
        // Устанавливаем аватар
        avatarView.set(avatar: avatar ?? Avatar(image: UIImage(systemName: "person.circle"), initials: ""))
    }
    
    func messageStyle(for message: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> MessageStyle {
      let tail: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
      return .bubbleTail(tail, .curved)
    }
    
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> NSAttributedString? {
            // Проверяем, отправлено ли сообщение текущим пользователем
            if !isFromCurrentSender(message: message) {
                // Получаем имя отправителя сообщения
                let senderName = message.sender.displayName
                print("senderName: \(senderName)")
                // Создаем атрибутированный текст для имени получателя
                let attributedString = NSAttributedString(string: senderName, attributes: [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.gray])
                return attributedString
            }
            return nil
        }
    
    func textColor(for message: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> UIColor {
        .white
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        // Определяем, чье сообщение
        let messageSender = message.sender.senderId
        
        // Устанавливаем соответствующий цвет фона для текущего пользователя или другого участника чата
        if messageSender == selfSender?.senderId {
            // Цвет для сообщений текущего пользователя
            return UIColor(named: "Blue") ?? UIColor(red: 153 / 255, green: 204 / 255, blue: 255 / 255, alpha: 1)
        } else {
            // Цвет для сообщений другого участника чата
            return UIColor(red: 153 / 255, green: 204 / 255, blue: 255 / 255, alpha: 1)
        }
    }

    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
}

// MARK: - InputBarAccessoryViewDelegate

extension UserChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        
        self.messageInputBar.inputTextView.text = ""
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender =  self.selfSender,
              let messageId = createMessageId() else {
            print("error")
            return
        }
        
        print("sending: \(text)")
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text),
                              messageNumber: messages.count)
        if isNewConversation {
            self.messages.append(message)
            self.messagesCollectionView.reloadData()
            
            AuthService.shared.createNewConversation(with: otherUserEmail, firstMessage: message, completion: { success in
                if success {
                    print("message \(self.lastMessage) sent to \(self.conversationId)")
                    self.messageInputBar.inputTextView.text = ""
                    self.updateLatestMessageInDatabase(for: self.conversationId ?? UserDefaults.standard.value(forKey: "conId") as! String, with: message)
                    //print("message \(self.lastMessage) sent to \(self.conversationId)")
                } else {
                    print("failed to sent")
                }
            })
            
            isNewConversation = false
        } else {
            AuthService.shared.getConversationIDForUsers(currentUserEmail: selfSender.senderId, otherUserEmail: otherUserEmail) { [weak self] result in
                guard let self = self else {
                    print("Self error")
                    return
                }
                
                switch result {
                case .success(let conversationID):
                    print("Conversation ID: \(conversationID)")
                    AuthService.shared.sendMessage(to: conversationID, message: message, completion: { success in
                        if success {
                            print("message sent")
                            self.messagesCollectionView.reloadData()
                            self.updateLatestMessageInDatabase(for: self.conversationId!, with: message)
                        } else {
                            print("failed to sent")
                        }
                    })
                case .failure(let error):
                    print("Failed to get conversationID: \(error)")
                }
            }
        }
    }
    
    private func createMessageId() -> String? {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") else {
            print("error current user email")
            return nil
        }
        
        let dateString = UserChatViewController.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(currentUserEmail)_\(dateString)"
        print("created message id: \(newIdentifier)")
        return newIdentifier
    }
}
