//
//  ARSessionScreenshot.swift
//  ARchitect
//
//  Created by Jiyoon Lee on 4/10/25.
//

import UIKit
import SwiftUI

class ScreenshotViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    var screenshotImage: UIImage?
    var activeTextView: UIView?
    var usedFurnitureModels: [String] = [] // Track furniture models used in the project
    var projectName: String = "" // Add property for project name
    var projectDescription: String = "" // Add property for project description

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardNotifications()
    }

    func setupUI() {
        self.view.backgroundColor = .white

        let imageView = UIImageView(frame: CGRect(x: 20, y: 100, width: self.view.frame.width - 40, height: self.view.frame.height / 2 - 100))
        imageView.image = screenshotImage
        imageView.contentMode = .scaleAspectFit
        self.view.addSubview(imageView)

        let titleTextField = UITextField(frame: CGRect(x: 20, y: imageView.frame.maxY + 20, width: self.view.frame.width - 40, height: 40))
        titleTextField.borderStyle = .roundedRect
        titleTextField.placeholder = "Enter project title"
        titleTextField.text = projectName
        titleTextField.delegate = self
        self.view.addSubview(titleTextField)

        let descriptionTextView = UITextView(frame: CGRect(x: 20, y: titleTextField.frame.maxY + 20, width: self.view.frame.width - 40, height: 100))
        descriptionTextView.layer.borderWidth = 1
        descriptionTextView.layer.borderColor = UIColor.lightGray.cgColor
        descriptionTextView.layer.cornerRadius = 8
        descriptionTextView.font = UIFont.systemFont(ofSize: 16)
        descriptionTextView.text = projectDescription
        descriptionTextView.delegate = self
        self.view.addSubview(descriptionTextView)

        // Add labels for all furniture used
        var currentY = descriptionTextView.frame.maxY + 20
        for furniture in usedFurnitureModels {
            let furnitureNameLabel = UILabel(frame: CGRect(x: 20, y: currentY, width: self.view.frame.width - 40, height: 20))
            furnitureNameLabel.text = furniture
            furnitureNameLabel.font = UIFont.systemFont(ofSize: 14)
            self.view.addSubview(furnitureNameLabel)
            currentY += 25
        }

        let saveButton = UIButton(frame: CGRect(x: (self.view.frame.width - 150) / 2, y: currentY + 20, width: 150, height: 50))
        saveButton.setTitle("Save", for: .normal)
        saveButton.backgroundColor = .systemGreen
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveProjectDetails), for: .touchUpInside)
        self.view.addSubview(saveButton)
    }

    func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        guard let activeTextView = activeTextView else { return }

        let keyboardHeight = keyboardFrame.height
        let bottomSpace = self.view.frame.height - (activeTextView.frame.origin.y + activeTextView.frame.height)

        if bottomSpace < keyboardHeight {
            self.view.frame.origin.y = -(keyboardHeight - bottomSpace + 20)
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        self.view.frame.origin.y = 0
    }

    @objc func saveProjectDetails() {
        // Convert the screenshot to Data
        guard let screenshotData = screenshotImage?.pngData() else {
            print("Error: Unable to save project. Screenshot is missing.")
            return
        }

        // Save project details locally
        let projectDetails: [String: Any] = [
            "name": projectName.isEmpty ? "Untitled Project" : projectName,
            "description": projectDescription.isEmpty ? "No description provided" : projectDescription,
            "screenshot": screenshotData,
            "furnitureModels": usedFurnitureModels
        ]

        // Save the project details to UserDefaults
        var allProjects = UserDefaults.standard.array(forKey: "allProjects") as? [[String: Any]] ?? []
        allProjects.append(projectDetails)
        UserDefaults.standard.set(allProjects, forKey: "allProjects")

        // Post notification to refresh the entry view
        NotificationCenter.default.post(name: NSNotification.Name("ProjectSaved"), object: nil)

        // Navigate back to the FurnitureEntryView
        self.dismiss(animated: true, completion: nil)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.placeholder == "Enter project title" {
            projectName = textField.text ?? ""
        }
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.placeholder == "Enter project title" {
            projectName = textField.text ?? ""
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        activeTextView = textView
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        projectDescription = textView.text
        activeTextView = nil
        textView.resignFirstResponder()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}
