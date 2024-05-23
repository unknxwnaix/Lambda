//
//  userChatsViewController.swift
//  Lambda
//
//  Created by Maxim Dmitrochenko on 03.04.2024.
//

import UIKit
import JGProgressHUD
import FirebaseAuth
import FirebaseFirestore
import SWTableViewCell

struct Conversation {
    let id: String
    let name: String
    let otherUserEmail: String
    var latestMessage: LatestMessage
}

struct LatestMessage {
    let date: String
    let text: String
    //let isRead: Bool
}

class userChatsViewController: UIViewController {
    // MARK: - Variables
    private var listener: ListenerRegistration?
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()
    
    // MARK: - UI Components
    private let chatsTableView: UITableView = {
        let tv = UITableView()
        tv.isHidden = true
        tv.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.identifier)
        return tv
    }()
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.text = "No Conversations!"
        label.textColor = .gray
        label.isHidden = true
        return label
    }()
    
    // MARK: - Lifecycle
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        updateNoConversationsLabelVisibility()
        super.viewDidLoad()
        self.setupUI()
        fetchConversations()
        startListeningForConversations()
    }
    
    private func startListeningForConversations() {
        guard let currentUserEmail = Auth.auth().currentUser?.email else {
            print("Failed fetching current user email from Auth")
            return
        }
        
        let db = Firestore.firestore()
        let conversationsRef = db.collection("conversations")
        
        // Установка слушателя изменений в коллекции "conversations"
        listener = conversationsRef.whereField("members", arrayContains: currentUserEmail)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening for conversations: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("Snapshot is nil")
                    return
                }
                
                // Обработка полученных данных
                snapshot.documentChanges.forEach { change in
                    if change.type == .added {
                        // Добавление новой беседы
                        let conversationData = change.document.data()
                        let id = change.document.documentID
                        let name = conversationData["name"] as? String ?? ""
                        let otherUserEmail = (conversationData["members"] as? [String] ?? []).filter { $0 != currentUserEmail }.first ?? ""
                        let latestMessageData = conversationData["latest_message"] as? [String: Any] ?? [:]
                        let latestMessage = LatestMessage(date: latestMessageData["date"] as? String ?? "",
                                                          text: latestMessageData["message"] as? String ?? ""
                                                          /*isRead: latestMessageData["is_read"] as? Bool ?? false*/)
                        
                        let newConversation = Conversation(id: id, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessage)
                        
                        // Добавляем новую беседу в массив и обновляем интерфейс
                        self.conversations.append(newConversation)
                        self.chatsTableView.reloadData()
                        self.updateNoConversationsLabelVisibility()
                    } else if change.type == .modified {
                        // Обновление существующей беседы
                        let modifiedConversationData = change.document.data()
                        let id = change.document.documentID
                        let latestMessageData = modifiedConversationData["latest_message"] as? [String: Any] ?? [:]
                        let latestMessage = LatestMessage(date: latestMessageData["date"] as? String ?? "",
                                                          text: latestMessageData["message"] as? String ?? ""
                                                          /*isRead: latestMessageData["is_read"] as? Bool ?? false*/)
                        self.updateNoConversationsLabelVisibility()
                        // Находим беседу с данным идентификатором и обновляем ее последнее сообщение
                        if let index = self.conversations.firstIndex(where: { $0.id == id }) {
                            self.conversations[index].latestMessage = latestMessage
                            // Обновляем соответствующую ячейку таблицы
                            let indexPath = IndexPath(row: index, section: 0)
                            print("indexPath: \(indexPath)")
                            self.chatsTableView.reloadRows(at: [indexPath], with: .automatic)
                        }
                        self.chatsTableView.reloadData()
                    } else if change.type == .removed{
                        self.handleConversationRemoved(change.document)
                        self.updateNoConversationsLabelVisibility()
                    }
                }
            }
    }
    
    private func handleConversationRemoved(_ document: QueryDocumentSnapshot) {
        // Получаем ID удаленного чата
        let conversationID = document.documentID
        
        // Удаляем чат из вашего массива чатов
        if let index = self.conversations.firstIndex(where: { $0.id == conversationID }) {
            self.conversations.remove(at: index)
            
            // Обновляем интерфейс
            DispatchQueue.main.async {
                if index != 0 {
                    self.chatsTableView.reloadData()
                } else {
                    self.conversations.removeAll()
                    self.chatsTableView.reloadData()
                }
            }
        }
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        chatsTableView.frame = view.bounds
    }
    
    
    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(chatsTableView)
        view.addSubview(noConversationsLabel)
        
        chatsTableView.delegate = self
        chatsTableView.dataSource = self
        chatsTableView.translatesAutoresizingMaskIntoConstraints = false
        noConversationsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            noConversationsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noConversationsLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            noConversationsLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            noConversationsLabel.heightAnchor.constraint(equalToConstant: 200),
        ])
    }
    
    private func fetchConversations() {
        chatsTableView.isHidden = false
        print("Fetching conversations...")
    }
}

extension userChatsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier, for: indexPath) as! ConversationTableViewCell
        
        // Получаем данные для соответствующей беседы
        let conversation = conversations[indexPath.row]
        
        // Настройка ячейки с использованием модели данных
        cell.configure(with: conversation)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let conversation = conversations[indexPath.row]
        
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { action, indexPath in
            // Получаем идентификатор беседы
            AuthService.shared.getConversationIDForUsers(currentUserEmail: UserDefaults.standard.value(forKey: "email") as! String, otherUserEmail: conversation.otherUserEmail) { result in
                switch result {
                case .success(let conversationID):
                    // Удаляем беседу с полученным идентификатором
                    AuthService.shared.deleteConversation(conversationID: conversationID, currentUserEmail: UserDefaults.standard.value(forKey: "email") as! String) { success in
                        if success {
                            // Удаляем беседу из массива
                            // self.conversations.remove(at: indexPath.row)
                            // Обновляем таблицу
                            self.chatsTableView.reloadData()
                            self.updateNoConversationsLabelVisibility()
                        } else {
                            // Ошибка при удалении
                            print("Failed to delete conversation")
                        }
                    }
                case .failure(let error):
                    // Ошибка при получении идентификатора беседы
                    print("Failed to get conversation ID:", error.localizedDescription)
                }
            }
        }
        return [deleteAction]
    }
    
    private func updateNoConversationsLabelVisibility() {
        DispatchQueue.main.async {
            // Если нет бесед, показываем лейбл, иначе скрываем его
            self.noConversationsLabel.isHidden = !self.conversations.isEmpty
            // Выводим в консоль информацию о наличии бесед
            if self.conversations.isEmpty {
                print("You have no converstaions")
            } else {
                print("Conversation is already created")
            }
        }
    }


    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Получаем данные о выбранной беседе
        let conversation = conversations[indexPath.row]
        
        // Получаем имя пользователя по его электронной почте
        AuthService.shared.getProfileImageURLAndUsername(for: conversation.otherUserEmail) { [weak self] imageURL, username in
            guard let self = self else { return }
            
            // Проверяем, удалось ли получить имя пользователя
            guard let otherUsername = username else {
                print("Failed to get username")
                return
            }
            
            // Передаем данные о пользователе в ChatViewController
            let vc = UserChatViewController(with: conversation.otherUserEmail, isNewConversation: false)
            UserDefaults.standard.set(conversation.id, forKey: "conId")
            vc.title = otherUsername // Имя пользователя как заголовок
            vc.navigationItem.largeTitleDisplayMode = .never
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}
