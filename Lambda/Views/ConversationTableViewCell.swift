import UIKit
import FirebaseFirestore
import SWTableViewCell

class ConversationTableViewCell: UITableViewCell {
    static let identifier = "ConversationTableViewCell"
    var messageListener: ListenerRegistration?
    static var otherUsername = ""
    
    private let deleteLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.backgroundColor = .red
        label.textAlignment = .center
        label.text = "Удалить"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .secondarySystemBackground
        imageView.layer.cornerRadius = 30
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let userMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.numberOfLines = 0
        label.text = "01/01/2000"
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timeMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.numberOfLines = 0
        label.text = "00:00"
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(profileImageView)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(userMessageLabel)
        
        contentView.addSubview(dateMessageLabel)
        contentView.addSubview(timeMessageLabel)
        
        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            profileImageView.widthAnchor.constraint(equalToConstant: 60),
            profileImageView.heightAnchor.constraint(equalToConstant: 60),
            
            
            usernameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            usernameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 10),
            usernameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -110),
            
            
            userMessageLabel.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: -5),
            userMessageLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 10),
            userMessageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -75),
            userMessageLabel.heightAnchor.constraint(equalToConstant: 30),
            
            dateMessageLabel.topAnchor.constraint(equalTo: usernameLabel.topAnchor),
            dateMessageLabel.leadingAnchor.constraint(equalTo: usernameLabel.trailingAnchor, constant: 10),
            dateMessageLabel.bottomAnchor.constraint(equalTo: usernameLabel.bottomAnchor),
            dateMessageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            
            timeMessageLabel.topAnchor.constraint(equalTo: userMessageLabel.topAnchor),
            timeMessageLabel.leadingAnchor.constraint(equalTo: userMessageLabel.trailingAnchor, constant: 10),
            timeMessageLabel.bottomAnchor.constraint(equalTo: userMessageLabel.bottomAnchor),
            timeMessageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    private func setProfileImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImageView.image = image
                }
            }
        }.resume()
    }
    
    public func configure(with conversation: Conversation) {
        let email = conversation.otherUserEmail
        AuthService.shared.getProfileImageURLAndUsername(for: email) { [weak self] url, username in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let url = url {
                    self.setProfileImage(from: url)
                }
                if let username = username {
                    self.usernameLabel.text = username
                    ConversationTableViewCell.otherUsername = username
                }
            }
        }
        
        guard let currentUserEmail = UserDefaults.standard.object(forKey: "email") as? String else {
            print("Failed to fetch current user email")
            return
        }
        
        AuthService.shared.getConversationIDForUsers(currentUserEmail: currentUserEmail, otherUserEmail: email) { [weak self] result in
            guard let self = self else {
                print("Self error")
                return
            }
            
            switch result {
            case .success(let conversationID):
                print("conversationID: \(conversationID)")
                AuthService.shared.getLastMessageDetails(in: conversationID, currentUserEmail: currentUserEmail) { result in
                    switch result {
                    case .success(let messageDetails):
                        var messageText = ""
                        if messageDetails.senderName == currentUserEmail {
                            messageText = "You: \(messageDetails.text)"
                        } else {
                            messageText = "\(ConversationTableViewCell.otherUsername): \(messageDetails.text)"
                        }
                        
                        DispatchQueue.main.async {
                            self.userMessageLabel.text = messageText
                            print("Last message: \(self.userMessageLabel.text)")
                            print("Last message: \(messageText)")
                        }
                        
                        // Вывод даты и времени последнего сообщения в консоль
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd/MM/yyyy"
                        let dateString = dateFormatter.string(from: messageDetails.date)
                        
                        let timeFormatter = DateFormatter()
                        timeFormatter.dateFormat = "HH:mm"
                        let timeString = timeFormatter.string(from: messageDetails.date)
                        
                        print("Last message date: \(dateString)")
                        self.dateMessageLabel.text = dateString
                        print("Last message time: \(timeString)")
                        self.timeMessageLabel.text = timeString
                    case .failure(let error):
                        print("Failed to fetch last message:", error.localizedDescription)
                    }
                }
            case .failure(let error):
                print("Failed to get conversationID:", error.localizedDescription)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Добавляем жест смахивания влево для удаления чата
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeGesture.direction = .left
        self.addGestureRecognizer(swipeGesture)
        
        // Добавляем элементы интерфейса на ячейку
        addSubview(deleteLabel)
        
        NSLayoutConstraint.activate([
            deleteLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            deleteLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            deleteLabel.widthAnchor.constraint(equalToConstant: 80),
            deleteLabel.heightAnchor.constraint(equalTo: heightAnchor)
        ])
    }

    // Обработка жеста смахивания
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.state == .changed {
            // Определяем, где произошел жест смахивания
            let location = gesture.location(in: self)
            // Проверяем, что жест смахивания был выполнен внутри ячейки
            if self.bounds.contains(location) {
                // Показываем элементы интерфейса для удаления
                deleteLabel.isHidden = false
                self.backgroundColor = UIColor.red.withAlphaComponent(0.3)
            }
        } else if gesture.state == .ended {
            // Скрываем элементы интерфейса для удаления
            deleteLabel.isHidden = true
            self.backgroundColor = .clear
        }
    }
}
