//
//  AuthService.swift
//  Lambda
//
//  Created by Maxim Dmitrochenko on 29.03.2024.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import MessageKit

class AuthService {
    public static let shared = AuthService()
    
    private init() {}
    
    /// A method to register the user
    /// - Parameters:
    ///   - userRequest: The users information (email, password, username)
    ///   - completion: A completion with two values...
    ///   - Bool: wasRegistered – Determines if the user was registered and saved in database correctly
    ///   - Error?:  An optional error if firebase provides once
    public func registerUser(with userRequest: RegisterUserRequest, completion: @escaping (Bool, Error?) -> Void) {
        let username = userRequest.username
        let email = userRequest.email
        let password = userRequest.password
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let resultUser = result?.user else {
                completion(false, nil)
                return
            }
            
            let db = Firestore.firestore()
            
            db.collection("users").document(resultUser.uid).setData([
                "username": username,
                "email": email,
                "password": password,
                "image" : "https://firebasestorage.googleapis.com/v0/b/lambda-8aae7.appspot.com/o/LambdaProfileImage.png?alt=media&token=4ac3c924-ec85-40b7-84a3-92983559418b"
            ]) { error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                completion(true, nil)
            }
        }
    }
    
    public func signIn(with userRequest: LoginUserRequest, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(withEmail: userRequest.email, password: userRequest.password) { result, error in
            if let error = error {
                completion(error)
                return
            } else {
                completion(nil)
            }
        }
    }
    
    public func signOut(completion: @escaping (Error?) -> Void) {
        do {
            try Auth.auth().signOut()
            completion(nil)
        } catch let error {
            completion(error)
        }
    }
    
    public func forgotPassword (with email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            completion(error)
        }
    }
    
    
    // TODO: - Create An Alert With Error Get Data
    public func fetchUser(completion: @escaping (MyUser?, Error?) -> Void) {
        guard let userUID = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        db.collection("users")
            .document(userUID)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                if let snapshot = snapshot,
                   let snapshotData = snapshot.data(),
                   let username = snapshotData["username"] as? String,
                   let email = snapshotData["email"] as? String,
                   let profileImageUrl = snapshotData["image"] as? String{
                    let user = MyUser(username: username, email: email, userUID: userUID, profileImageUrl: profileImageUrl)
                    completion(user, nil)
                }
            }
    }
    
    public func fetchAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            var allUsersData: [[String: String]] = []
            
            if let snapshot = snapshot {
                for document in snapshot.documents {
                    let userData = document.data()
                    
                    if let username = userData["username"] as? String,
                       let email = userData["email"] as? String,
                       let profileImageUrl = userData["image"] as? String {
                        let user = ["username": username, "email": email, "profileImageUrl": profileImageUrl]
                        allUsersData.append(user)
                    }
                }
            }
            
            completion(.success(allUsersData))
        }
    }
    
    public func getProfileImageURLAndUsername(for email: String, completion: @escaping (URL?, String?) -> Void) {
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        
        usersRef.whereField("email", isEqualTo: email).getDocuments { snapshot, error in
            guard let document = snapshot?.documents.first, let imageURLString = document["image"] as? String, let username = document["username"] as? String else {
                completion(nil, nil)
                return
            }
            if let url = URL(string: imageURLString) {
                completion(url, username)
            } else {
                completion(nil, nil)
            }
        }
    }
    
    func getProfileImagesForChatParticipants(currentUserEmail: String, otherUserEmail: String, completion: @escaping (UIImage?, UIImage?) -> Void) {
            var currentUserImage: UIImage?
            var otherUserImage: UIImage?
            
            // Получаем фото текущего пользователя
            getProfileImageURLAndUsername(for: currentUserEmail) { currentUserImageURL, _ in
                guard let currentUserImageURL = currentUserImageURL else {
                    completion(nil, nil)
                    return
                }
                self.fetchImage(from: currentUserImageURL) { image in
                    currentUserImage = image
                    // Проверяем, есть ли фото другого пользователя
                    if let otherUserImage = otherUserImage {
                        completion(currentUserImage, otherUserImage)
                    }
                }
            }
            
            // Получаем фото другого пользователя
            getProfileImageURLAndUsername(for: otherUserEmail) { otherUserImageURL, _ in
                guard let otherUserImageURL = otherUserImageURL else {
                    completion(nil, nil)
                    return
                }
                self.fetchImage(from: otherUserImageURL) { image in
                    otherUserImage = image
                    // Проверяем, есть ли фото текущего пользователя
                    if let currentUserImage = currentUserImage {
                        completion(currentUserImage, otherUserImage)
                    }
                }
            }
        }
        
        // Метод для загрузки изображения по URL
        private func fetchImage(from imageURL: URL, completion: @escaping (UIImage?) -> Void) {
            URLSession.shared.dataTask(with: imageURL) { data, response, error in
                guard let data = data, error == nil else {
                    completion(nil)
                    return
                }
                let image = UIImage(data: data)
                completion(image)
            }.resume()
        }
    
    
    // TODO: - Custom Error
    public func updateUserProfileImage(with updateUserProfileImageRequest: UpdateUserProfileImageRequest, completion: @escaping (Error?) -> Void) {
        let email = updateUserProfileImageRequest.email
        //let image = updateUserProfileImageRequest.image
        
        let storageRef = Storage.storage().reference()
        
        let profileImageRef = storageRef.child("image/\(email).jpg")
        
        
        guard let imageData = updateUserProfileImageRequest.image.jpegData(compressionQuality: 0.8) else {
            // Обработка ошибки, если не удалось получить данные изображения
            return
        }
        
        let uploadTask = profileImageRef.putData(imageData, metadata: nil) { (_, error) in
            guard error == nil else {
                print("\(String(describing: error?.localizedDescription))")
                return
            }
        }
        
        let urlString = "https://firebasestorage.googleapis.com/v0/b/lambda-8aae7.appspot.com/o/image%2F\(email).jpg?alt=media&token=c5a95550-8e90-41c4-b5d3-f1f052a35097"

        
        // Сохранить URL изображения в коллекции пользователей
        guard let userUID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users")
            .document(userUID)
        
        

        
        userRef.setData(["image": urlString], merge: true) { error in
            if let error = error {
                // Обработка ошибки сохранения URL в коллекции пользователей
                completion(error)
            } else {
                // Успешное завершение операции
                completion(nil)
            }
        }
    }
}

// MARK: - Sending messages / conversations
extension AuthService {
    
    /*
     conversation => [
        [
            "conversation_id": "dfdfdfdfdfd",
            "other_user_email":
            "latest_message": => {
                "date": Date()
                "latest_message": "message"
                "is_read": true/false
            },
        ],
     ]
     
     
     "dfdfdfdfdfd" {
        "messages": [
            {
                "id": String,
                "type": text, photo, video and etc.,
                "content": String,
                "date": Date(),
                "sender_email": String,
                "is_read": true/false
            }
        ]
     }
     */
    
    
    /// Creates a new coversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("Failed fetching current user email from Auth")
            completion(false)
            return
        }
        
        guard otherUserEmail != currentUserEmail else {
            print("Cannot create conversation with yourself")
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let conversationsRef = db.collection("conversations")
        
        let newConversationRef = conversationsRef.document()
        let newConversationID = newConversationRef.documentID
        UserDefaults.standard.set(newConversationID, forKey: "conId")
        
        let messageDate = firstMessage.sentDate
        let dateString = UserChatViewController.dateFormatter.string(from: messageDate)
        
        var messageContent = ""
        if case .text(let messageText) = firstMessage.kind {
            messageContent = messageText
        }
        
        let newConversationData: [String: Any] = [
            "id": newConversationID,
            "members": [currentUserEmail, otherUserEmail],
            "latest_message": [
                "date": dateString,
                "message": messageContent,
                "sender": currentUserEmail,
                //"is_read": false
            ]
        ]
        
        newConversationRef.setData(newConversationData) { error in
            if let error = error {
                print("Error creating conversation: \(error)")
                completion(false)
            } else {
                print("Conversation created successfully")
                
                // Добавляем первое сообщение в беседу
                self.sendMessage(to: newConversationID, message: firstMessage) { success in
                    completion(success)
                }
            }
        }
    }

    public func sendMessage(to conversationID: String, message: Message, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("Failed fetching current user email from Auth")
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let messagesRef = db.collection("conversations").document(conversationID).collection("messages")
        
        // Получаем количество сообщений в коллекции
        messagesRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching message count: \(error)")
                completion(false)
                return
            }
            
            // Получаем количество сообщений
            let numberOfMessages = snapshot?.documents.count ?? 0
            
            let messageDate = message.sentDate
            let dateString = UserChatViewController.dateFormatter.string(from: messageDate)
            
            var messageContent = ""
            if case .text(let messageText) = message.kind {
                messageContent = messageText
                print("messageContent: \(messageContent)")
                print("messageText: \(messageText)")
            }
            
            let newMessageData: [String: Any] = [
                "sender": currentUserEmail,
                "content": messageContent as! String,
                "sentDate": dateString,
                //"isRead": false,
                "message_number": numberOfMessages
            ]
            
            // Добавляем новое сообщение
            messagesRef.addDocument(data: newMessageData) { error in
                if let error = error {
                    print("Error adding message: \(error)")
                    completion(false)
                } else {
                    print("Message added successfully")
                    completion(true)
                }
            }
        }
    }
        
    /// Fetches and returns all conversations for the user with the given email.
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        let db = Firestore.firestore()
        let conversationsRef = db.collection("conversations")
        
        conversationsRef.whereField("members", arrayContains: email).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            var conversations: [Conversation] = []
            
            for document in snapshot?.documents ?? [] {
                let data = document.data()
                let id = document.documentID
                let name = data["name"] as? String ?? ""
                let otherUserEmail = (data["members"] as? [String] ?? []).filter { $0 != email }.first ?? ""
                let latestMessageData = data["latest_message"] as? [String: Any] ?? [:]
                let latestMessage = LatestMessage(date: latestMessageData["date"] as? String ?? "",
                                                  text: latestMessageData["message"] as? String ?? ""
                                                  /*isRead: latestMessageData["is_read"] as? Bool ?? false*/)
                
                let conversation = Conversation(id: id, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessage)
                conversations.append(conversation)
            }
            
            completion(.success(conversations))
        }
    }
    
    /// Gets all messages for the conversation with the given ID.
    public func getAllMessagesForConversation(conversationID: String, selfSender: Sender, completion: @escaping (Result<[Message], Error>) -> Void) {
        print("Attempting to fetch messages for conversation \(conversationID)")
        let db = Firestore.firestore()
        let messagesRef = db.collection("conversations").document(conversationID).collection("messages")
        
        messagesRef.getDocuments { snapshot, error in
            if let error = error {
                print("Failed to fetch messages for conversation \(conversationID): \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("Successfully fetched messages for conversation \(conversationID)")
            var messages: [Message] = []
            for document in snapshot?.documents ?? [] {
                let data = document.data()
                let senderEmail = data["sender"] as! String
                let content = data["content"] as! String
                //let isRead = data["isRead"] as? Bool ?? false
                let sentDateString = data["sentDate"] as! String
                let messageNum = data["message_number"] as? Int ?? 0
                let sentDate = UserChatViewController.dateFormatter.date(from: sentDateString) ?? Date()

                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: senderEmail)
                let message = Message(sender: sender, messageId: document.documentID, sentDate: sentDate, kind: .text(content), messageNumber: messageNum )
                
                messages.append(message)
            }
            
            completion(.success(messages))
        }
    }
    
    public func listenForMessages(in conversationID: String, completion: @escaping (Result<Message, Error>) -> Void) -> ListenerRegistration? {
        let db = Firestore.firestore()
        let messagesRef = db.collection("conversations").document(conversationID).collection("messages")
        
        return messagesRef.addSnapshotListener { snapshot, error in
            if let error = error {
                // Выводим ошибку в консоль
                print("Error listening for messages: \(error.localizedDescription)")
                completion(.failure(error)) // Передаем ошибку обратно в вызывающий код
                return
            }
            
            guard let documents = snapshot?.documents else {
                return
            }
            
            for document in documents {
                let data = document.data()
                let senderEmail = data["sender"] as! String
                let content = data["content"] as! String
                //let isRead = data["isRead"] as? Bool ?? false
                let sentDateString = data["sentDate"] as! String
                let sentDate = UserChatViewController.dateFormatter.date(from: sentDateString) ?? Date()
                let messageNum = data["message_number"] as? Int ?? 0

                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: senderEmail)
                let message = Message(sender: sender, messageId: document.documentID, sentDate: sentDate, kind: .text(content), messageNumber: messageNum)
                
                completion(.success(message))
            }
        }
    }

    
    public func getConversationIDForUsers(currentUserEmail: String, otherUserEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        let db = Firestore.firestore()
        let conversationsRef = db.collection("conversations")
        
        // Проверяем, есть ли беседа между currentUserEmail и otherUserEmail
        conversationsRef.whereField("members", arrayContains: currentUserEmail).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            for document in snapshot?.documents ?? [] {
                let data = document.data()
                let conversationID = document.documentID
                
                // Проверяем, есть ли otherUserEmail в данной беседе
                if let members = data["members"] as? [String], members.contains(otherUserEmail) {
                    // Найдена беседа между currentUserEmail и otherUserEmail
                    completion(.success(conversationID))
                    return
                }
            }
        }
    }
    
    func getLastMessage(in conversationID: String, currentUserEmail: String, completion: @escaping (Result<Message, Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("conversations").document(conversationID).collection("messages")
            .order(by: "sentDate", descending: true)
            .limit(to: 1)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    completion(.failure(error))
                } else if let snapshot = snapshot {
                    if let document = snapshot.documents.first {
                        let data = document.data()
                        print("Received message data:", data) // Добавляем эту строку для вывода полученных данных
                        if let senderId = data["sender"] as? String,
                           let content = data["content"] as? String,
                           //let isRead = data["isRead"] as? Bool,
                           let sentDateString = data["sentDate"] as? String,
                           let messageNumber = data["message_number"] as? Int,
                           let sentDate = UserChatViewController.dateFormatter.date(from: sentDateString) {
                            let sender: Sender
                            if senderId == currentUserEmail {
                                sender = Sender(senderId: senderId, displayName: "You")
                            } else {
                                sender = Sender(senderId: senderId, displayName: senderId)
                            }
                            let message = Message(sender: sender as SenderType, messageId: document.documentID as! String, sentDate: sentDate, kind: .text(content as! String), messageNumber: messageNumber as! Int)
                            completion(.success(message))
                        } else {
                            completion(.failure(NSError(domain: "AuthService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse message"])))
                        }
                    } else {
                        completion(.failure(NSError(domain: "AuthService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No message found"])))
                    }
                }
            }
    }


    func getLastMessageDetails(in conversationID: String, currentUserEmail: String, completion: @escaping (Result<(text: String, date: Date, senderName: String), Error>) -> Void) {
        getLastMessage(in: conversationID, currentUserEmail: currentUserEmail) { result in
            switch result {
            case .success(let message):
                switch message.kind {
                case .text(let text):
                    let messageDetails = (text: text, date: message.sentDate, senderName: message.sender.senderId)
                    completion(.success(messageDetails))
                default:
                    completion(.failure(NSError(domain: "AuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Last message is not a text message"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func deleteConversation(conversationID: String, currentUserEmail: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let conversationRef = db.collection("conversations").document(conversationID)
        
        // Удаляем разговор из списка чатов
        conversationRef.delete { error in
            if let error = error {
                print("Error deleting conversation from Firestore: \(error.localizedDescription)")
                completion(false)
            } else {
                // Удаляем разговор из Firebase
                self.deleteMessages(for: conversationID) { success in
                    completion(success)
                }
            }
        }
    }

    private func deleteMessages(for conversationID: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let messagesRef = db.collection("conversations").document(conversationID).collection("messages")
        
        // Удаляем все сообщения из разговора
        messagesRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching messages to delete: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(true)
                return
            }
            
            let batch = db.batch()
            documents.forEach { batch.deleteDocument($0.reference) }
            
            batch.commit { error in
                if let error = error {
                    print("Error deleting messages: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("Messages deleted successfully")
                    completion(true)
                }
            }
        }
    }
    
    public func updateLatestMessage(for conversationID: String, with message: Message, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let conversationRef = db.collection("conversations").document(conversationID)
        
        var messageContent = ""
        if case .text(let messageText) = message.kind {
            messageContent = messageText as String
            print("messageContent: \(messageContent)")
            print("messageText: \(messageText)")
        }
        
        let messageDate = message.sentDate
        let dateString = UserChatViewController.dateFormatter.string(from: messageDate)
        
        let latestMessageData: [String: Any] = [
            "date": dateString,
            "message": messageContent,
            "sender": message.sender.senderId,
        ]
        
        // Обновляем поле latest_message у беседы
        conversationRef.updateData(["latest_message": latestMessageData]) { error in
            if let error = error {
                print("Error updating latest message: \(error)")
                completion(false)
            } else {
                print("Latest message updated successfully")
                completion(true)
            }
        }
    }
}
