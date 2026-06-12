//
//  ARSessionDetailView.swift
//  ARchitect
//
//  Created by Jiyoon Lee on 4/10/25.
//

import UIKit

class ProjectDetailsViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    var project: [String: Any] = [:]
    var screenshotImage: UIImage?
    var projectName: String = ""
    var projectDescription: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismissal() // Add keyboard dismissal setup
    }

    func setupUI() {
        self.view.backgroundColor = .white

        // Adjust the frame to ensure the screenshot is visible and move everything up
        let imageView = UIImageView(frame: CGRect(x: 20, y: 40, width: self.view.frame.width - 40, height: self.view.frame.height / 4))
        imageView.image = screenshotImage
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true // Ensure the image fits within the frame
        self.view.addSubview(imageView)

        let titleTextField = UITextField(frame: CGRect(x: 20, y: imageView.frame.maxY + 10, width: self.view.frame.width - 40, height: 40))
        titleTextField.borderStyle = .roundedRect
        titleTextField.placeholder = "Enter project title"
        titleTextField.text = projectName
        titleTextField.delegate = self
        self.view.addSubview(titleTextField)

        let descriptionTextView = UITextView(frame: CGRect(x: 20, y: titleTextField.frame.maxY + 10, width: self.view.frame.width - 40, height: 100))
        descriptionTextView.layer.borderWidth = 1
        descriptionTextView.layer.borderColor = UIColor.lightGray.cgColor
        descriptionTextView.layer.cornerRadius = 8
        descriptionTextView.font = UIFont.systemFont(ofSize: 16)
        descriptionTextView.text = projectDescription
        descriptionTextView.delegate = self
        self.view.addSubview(descriptionTextView)

        // Add labels for all furniture used
        var currentY = descriptionTextView.frame.maxY + 10
        if let furnitureModels = project["furnitureModels"] as? [String] {
            for furniture in furnitureModels {
                let furnitureNameLabel = UILabel(frame: CGRect(x: 20, y: currentY, width: self.view.frame.width - 40, height: 20))
                furnitureNameLabel.text = furniture
                furnitureNameLabel.font = UIFont.systemFont(ofSize: 14)
                self.view.addSubview(furnitureNameLabel)
                currentY += 25
            }
        }

        // Add save and delete buttons in parallel
        let buttonWidth = (self.view.frame.width - 60) / 2

        let saveButton = UIButton(frame: CGRect(x: 20, y: currentY + 10, width: buttonWidth, height: 50))
        saveButton.setTitle("Save", for: .normal)
        saveButton.backgroundColor = .systemGreen
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveProjectDetails), for: .touchUpInside)
        self.view.addSubview(saveButton)

        let deleteButton = UIButton(frame: CGRect(x: saveButton.frame.maxX + 20, y: currentY + 10, width: buttonWidth, height: 50))
        deleteButton.setTitle("Delete", for: .normal)
        deleteButton.backgroundColor = .systemRed
        deleteButton.layer.cornerRadius = 8
        deleteButton.addTarget(self, action: #selector(confirmDeleteProject), for: .touchUpInside)
        self.view.addSubview(deleteButton)
    }

    func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGesture)
    }

    @objc func dismissKeyboard() {
        self.view.endEditing(true)
    }

    @objc func saveProjectDetails() {
        guard !projectName.isEmpty else {
            print("Error: Project name cannot be empty.")
            return
        }

        project["name"] = projectName
        project["description"] = projectDescription

        var allProjects = UserDefaults.standard.array(forKey: "allProjects") as? [[String: Any]] ?? []
        if let index = allProjects.firstIndex(where: { $0["screenshot"] as? Data == project["screenshot"] as? Data }) {
            allProjects[index]["name"] = projectName
            allProjects[index]["description"] = projectDescription
        } else {
            print("Error: Project not found in UserDefaults.")
        }
        UserDefaults.standard.set(allProjects, forKey: "allProjects")

        NotificationCenter.default.post(name: NSNotification.Name("ProjectSaved"), object: nil)

        // Show success alert
        showAlert(title: "Success", message: "Project saved successfully.") {
            self.dismiss(animated: true, completion: nil)
        }
    }

    @objc func confirmDeleteProject() {
        let alert = UIAlertController(
            title: "Delete Project",
            message: "Are you sure you want to delete this project? This action cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.deleteProject()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    
    func deleteProject() {
            var allProjects = UserDefaults.standard.array(forKey: "allProjects") as? [[String: Any]] ?? []
            if let index = allProjects.firstIndex(where: { $0["screenshot"] as? Data == project["screenshot"] as? Data }) {
                allProjects.remove(at: index)
                UserDefaults.standard.set(allProjects, forKey: "allProjects") // Persist deletion immediately
                UserDefaults.standard.synchronize() // Ensure changes are written to disk
            } else {
                print("Error: Project not found in UserDefaults.")
            }

        NotificationCenter.default.post(name: NSNotification.Name("ProjectDeleted"), object: nil)

        // Show success alert and navigate back to the FurnitureEntryView
        showAlert(title: "Success", message: "Project deleted successfully.") {
            if let navigationController = self.navigationController {
                navigationController.popViewController(animated: true)
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }


    }

    private func showAlert(title: String, message: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            completion()
        }))
        self.present(alert, animated: true, completion: nil)
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
            projectName = textField.text ?? "" // Update projectName when editing ends
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        projectDescription = textView.text
    }
}
