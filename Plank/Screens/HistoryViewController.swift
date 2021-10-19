//
//  HistoryViewController.swift
//  Plank
//

import UIKit

class HistoryViewController: UIViewController {
  @IBOutlet private weak var tableView: UITableView!
  
  private var history: [Training] = []
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.dataSource = self
    tableView.allowsSelection = false
    tableView.backgroundColor = .clear
    tableView.alwaysBounceVertical = false
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    guard let data = UserDefaults.standard.data(forKey: "history"),
          let history = try? JSONDecoder().decode([Training].self, from: data) else { return }
    self.history = history.reversed()
    
    tableView.reloadData()
  }
  
  @IBAction private func close(_ sender: Any) {
    dismiss(animated: true, completion: nil)
  }
}

// MARK: - UITableViewDataSource

extension HistoryViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return history.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath)
    let index = indexPath.row
    guard index >= 0, index < history.count else { return UITableViewCell() }
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMMM yyyy, HH:mm"
    (cell.viewWithTag(1) as? UILabel)?.text = formatter.string(from: history[index].date)
    (cell.viewWithTag(2) as? UILabel)?.text = "\(history[index].time) сек."
    cell.backgroundColor = .clear
    return cell
  }
}
