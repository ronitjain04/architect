//
//  ARSessionFurnitureList.swift
//  ARchitect
//
//  Created by Jiyoon Lee on 4/10/25.
//

import UIKit

protocol FurnitureGalleryDelegate: AnyObject {
    func furnitureSelected(named modelName: String)
}

class FurnitureGalleryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    weak var delegate: FurnitureGalleryDelegate?
    let furnitureModels = ["Curved Comfort Chair", "Arm chair", "Folding_Table", "fridge"] // Updated to include local furniture models
    var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    func setupUI() {
        self.view.backgroundColor = .white
        self.title = "Furniture Gallery"

        tableView = UITableView(frame: self.view.bounds, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        self.view.addSubview(tableView)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return furnitureModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.text = furnitureModels[indexPath.row]
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedModel = furnitureModels[indexPath.row]
        delegate?.furnitureSelected(named: selectedModel) // Notify the delegate
        self.dismiss(animated: true, completion: nil) // Dismiss the view
    }
}
