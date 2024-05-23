//
//  HomeController.swift
//  Lambda
//
//  Created by Maxim Dmitrochenko on 24.03.2024.
//

import UIKit
import FirebaseStorage
import FirebaseAuth

class UserProfileController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    // MARK: - Variables
    
    // MARK: - UI Components
    private let profileImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "LambdaProfileImage")
        iv.tintColor = .white
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 105
        iv.layer.borderWidth = 5.0
        iv.layer.borderColor = UIColor(named: "Blue")?.cgColor
        return iv
    }()

    private let newImageButton = CustomButton(title: "New Image", fontSize: .small)
    
    private let label: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.textAlignment = .left
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.text = "Loading..."
        label.numberOfLines = 2
        return label
    }()
    
    private let subLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.text = "Error"
        return label
    }()
    
    let containerView: UIView = {
        let uv = UIView()
        uv.clipsToBounds = true
        uv.layer.cornerRadius = 0
        uv.layer.borderWidth = 2.0
        if #available(iOS 13.0, *) {
            uv.backgroundColor = UIColor.systemGray6
            uv.layer.borderColor = UIColor.systemGray4.cgColor
        } else {
            uv.backgroundColor = UIColor.systemGray
            uv.layer.borderColor = UIColor.systemGray2.cgColor
        }
        
        return uv
    }()
    
    // MARK: - Lifecycle
    init() {
        super.init(nibName: nil, bundle: nil)
            
        
        updateColorsForCurrentTheme()
        
        newImageButton.addTarget(self, action: #selector(didTapNewImage), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // TODO: - Add Custom Errors Alert
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.setupUI()

        self.view.backgroundColor = .systemBackground
        
        AuthService.shared.fetchUser { [weak self] user, error in
            guard let self = self else { return }
            
            if let error = error {
                AlertManager.showFetchingUserError(on: self, with: error)
                return
            }
            
            if let user = user {
                self.label.text = "Hello, \(user.username)!"
                self.subLabel.text = "email: \(user.email)"
                
                UserDefaults.standard.set(user.email, forKey: "email")
                UserDefaults.standard.set(user.username, forKey: "username")
                UserDefaults.standard.set(user.profileImageUrl, forKey: "imageUrl")
                //UserDefaults.standard.set(, forKey: "username")
                
                
                if let url = URL(string: user.profileImageUrl) {
                    let task = URLSession.shared.dataTask(with: url) { data, response, error in
                        guard let data = data, error == nil else {
                            return
                        }
                        
                        DispatchQueue.main.async {
                            var image = UIImage(data: data) ?? UIImage(resource: .lambdaLogoCircled)
                            image = self.cropToSquare(image: image)
                            self.profileImageView.image = image
                        }
                    }
                    task.resume()
                }
            }
        }
    }
    
    
    func cropToSquare(image: UIImage) -> UIImage {
        let cgImage = image.cgImage!
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let size = min(width, height)
        
        let x = (width - size) / 2
        let y = (height - size) / 2
        
        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        let croppedImage = cgImage.cropping(to: cropRect)!
        
        return UIImage(cgImage: croppedImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        
        self.view.addSubview(profileImageView)
        self.view.addSubview(newImageButton)
        self.view.addSubview(containerView)
        containerView.addSubview(label)
        containerView.addSubview(subLabel)
        
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        newImageButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        
        
        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 120),
            profileImageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 210),
            profileImageView.heightAnchor.constraint(equalToConstant: 210),
            
            newImageButton.topAnchor.constraint(equalTo: self.profileImageView.bottomAnchor, constant: 7),
            newImageButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            
            
            containerView.topAnchor.constraint(equalTo: self.newImageButton.bottomAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: -5),
            containerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: 5),
            containerView.bottomAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 20),
            
            
            label.topAnchor.constraint(equalTo: self.containerView.topAnchor, constant: 20),
            label.centerXAnchor.constraint(equalTo: self.containerView.centerXAnchor),
            label.widthAnchor.constraint(equalTo: self.containerView.widthAnchor, multiplier: 0.8),
            
            
            subLabel.topAnchor.constraint(equalTo: self.label.bottomAnchor, constant: 20),
            subLabel.leadingAnchor.constraint(equalTo: self.label.leadingAnchor),
            subLabel.widthAnchor.constraint(equalTo: self.label.widthAnchor)
        ])
    }
    
    // MARK: - Selectors
    @objc private func didTapNewImage() {
        let alert = UIAlertController(title: nil, message: "Upload With", preferredStyle: .alert)
        let cameraAction = UIAlertAction(title: "camera", style: .default) { (action) in self.chooseImage(source: .camera)
        }
        let photoLibAction = UIAlertAction(title: "photo", style: .default) { (action) in self.chooseImage(source: .photoLibrary)
        }
        let cancelAction = UIAlertAction(title: "cancel", style: .cancel)
        
        alert.addAction(cameraAction)
        alert.addAction(photoLibAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    

    private func chooseImage(source: UIImagePickerController.SourceType) {
        if UIImagePickerController.isSourceTypeAvailable(source){
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = true
            imagePicker.sourceType = source
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let editedImage = info[.editedImage] as? UIImage {
            let croppedImage = cropToSquare(image: editedImage)
            profileImageView.image = croppedImage
            uploadImageToFirebase(image: croppedImage)
        } else if let originalImage = info[.originalImage] as? UIImage {
            let croppedImage = cropToSquare(image: originalImage)
            profileImageView.image = croppedImage
            uploadImageToFirebase(image: croppedImage)
        }
        profileImageView.contentMode = .scaleAspectFit
        profileImageView.clipsToBounds = true
        picker.dismiss(animated: true, completion: nil)
    }

    func uploadImageToFirebase(image: UIImage) {
        guard let email = Auth.auth().currentUser?.email else { return }
        let updateRequest = UpdateUserProfileImageRequest(email: email, image: image)
        AuthService.shared.updateUserProfileImage(with: updateRequest) { error in
            if let error = error {
                // Обработка ошибки загрузки изображения в Firebase
                print("Ошибка загрузки изображения в Firebase: \(error.localizedDescription)")
            } else {
                // Успешная загрузка изображения в Firebase
                print("Изображение успешно загружено в Firebase")
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Обновляем цвета краев для новой темы
        updateColorsForCurrentTheme()
    }
    
    func updateColorsForCurrentTheme() {
        if #available(iOS 13.0, *) {
            if traitCollection.userInterfaceStyle == .dark {
                containerView.backgroundColor = UIColor.systemGray6
                containerView.layer.borderColor = UIColor.systemGray4.cgColor
                print("dark")
            } else {
                containerView.backgroundColor = UIColor.systemGray6
                containerView.layer.borderColor = UIColor.systemGray4.cgColor
                print("light")
            }
        } else {
            // Для старых версий iOS
            containerView.backgroundColor = UIColor.systemGray
            containerView.layer.borderColor = UIColor.systemGray2.cgColor
            print("old")
        }
    }
}
