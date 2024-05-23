//
//  NewConversationViewController.swift
//  Lambda
//
//  Created by Maxim Dmitrochenko on 18.04.2024.
//

import UIKit
import JGProgressHUD

protocol NewConversationViewControllerDelegate: AnyObject {
    func didSelectUser(_ user: [String: String])
}

class NewConversationViewController: UIViewController {

    // MARK: - Variables
    weak var delegate: NewConversationViewControllerDelegate?
    
    public var completion: (([String: String]) -> (Void))?
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var users = [[String: String]]()
    private var results = [[String: String]]()
    
    private var hasFetched = false
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search For Users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tableView
    }()
    
    private let NoResultLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.textColor = .gray
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.text = "No Results"
        return label
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.topItem?.titleView = searchBar
        let button = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissSelf))
        button.tintColor = .systemBlue
        navigationItem.rightBarButtonItem = button
        searchBar.becomeFirstResponder()
        setupUI()
    }

    private func setupUI() {
        view.addSubview(NoResultLabel)
        view.addSubview(tableView)
        
        tableView.delegate = self
        tableView.dataSource = self
        NoResultLabel.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            NoResultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            NoResultLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            NoResultLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            NoResultLabel.heightAnchor.constraint(equalToConstant: 200),
            
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    
    // MARK: - Selectors
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
}

extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = results[indexPath.row]["username"]
        return cell
    }
    
    
    // MARK: - !!!
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath , animated: true)
        let targetUserData = results[indexPath.row]
        
        let otherUserEmail = targetUserData["email"] ?? ""
        
        // Проверяем, существует ли беседа с выбранным пользователем
        AuthService.shared.getAllConversations(for: otherUserEmail) { result in
            switch result {
            case .success(let conversations):
                // Если есть хотя бы одна беседа с выбранным пользователем, isNewConversation будет false
                let isNewConversation = conversations.isEmpty
                DispatchQueue.main.async {
                    let chatVC = UserChatViewController(with: otherUserEmail, isNewConversation: isNewConversation)
                    print("isNewConversation: \(isNewConversation)")
                    chatVC.title = targetUserData["username"]
                    chatVC.navigationItem.largeTitleDisplayMode = .never
                    
                    let navVC = UINavigationController(rootViewController: chatVC)
                    self.navigationController?.pushViewController(chatVC, animated: true)
                    //self.navigationController?.present(navVC, animated: true, completion: nil)
                }
            case .failure(let error):
                print("Ошибка при получении бесед: \(error)")
            }
        }
    }
}

extension NewConversationViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        results.removeAll()
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.isEmpty, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        
        searchBar.resignFirstResponder()
        
        results.removeAll()
        spinner.show(in: view)
        
        self.searchUsers(query: text)
    }
    
    func searchUsers(query: String) {
        if hasFetched {
            filterUsers(with: query)
        } else {
            AuthService.shared.fetchAllUsers(completion: { [weak self] result in
                switch result {
                case .success(let usersCollection):
                    self?.hasFetched = true
                    self?.users = usersCollection
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("Ошибка при получении пользователей: \(error)")
                }
            })
        }
    }

    func filterUsers(with term: String) {
        guard hasFetched else { return }
        
        self.spinner.dismiss()
        
        let query = term.lowercased()
        
        let filteredUsers: [[String: String]] = self.users.filter { user in
                guard let username = user["username"]?.lowercased(),
                      let userEmail = user["email"] else { return false }
                
                // Проверяем, что пользователь не является текущим пользователем
                let isNotCurrentUser = userEmail != UserDefaults.standard.string(forKey: "email")
                
                return isNotCurrentUser && username.contains(query)
            }
        
        self.results = filteredUsers
        updateUI()
    }
    
    func updateUI() {
        if results.isEmpty {
            self.NoResultLabel.isHidden = false
            self.tableView.isHidden = true
        } else {
            self.NoResultLabel.isHidden = true
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
}
