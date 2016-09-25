//
//  MessageListWidmannStyleViewController.swift
//  mclient
//
//  Created by Christopher Reitz on 23/09/2016.
//  Copyright © 2016 Christopher Reitz. All rights reserved.
//

import UIKit

class MessageListWidmannStyleViewController: UITableViewController {

    var board: MCLBoard?
    var thread: MCLThread?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = thread?.subject

        loadData()
    }

    func loadData() {
        print("yo")
    }
}
