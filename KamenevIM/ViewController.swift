//
//  ViewController.swift
//  KamenevIM
//
//  Created by  Ivan Kamenev on 30.01.2021.
//

import UIKit
import Foundation
import SystemConfiguration

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    //MARK: - UI element
    
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var companyPickerView: UIPickerView!
    @IBOutlet weak var companySymboLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var companyImage: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    //MARK: - Company dictionary
    
    private var companies = [String: String]()
    
    //MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemYellow
    
        companyPickerView.dataSource = self
        companyPickerView.delegate = self
        
        activityIndicator.hidesWhenStopped = true
        
        requestStocksList()
        requestQuoteUpdate()
    }
    
    //MARK: - UIPickerViewDataSource protocol
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return companies.keys.count
    }
    
    //MARK: - UIPickerViewDelegate protocol
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Array(companies.keys)[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        requestQuoteUpdate()
    }

    //MARK: - Private
    
    private func requestQuoteUpdate() {
        activityIndicator.startAnimating()
        companyNameLabel.text = "-"
        companySymboLabel.text = "-"
        priceLabel.text = "-"
        priceChangeLabel.text = "-"
        
        
        showAlert(message: "No internet connection")
        
        guard companies.count == 0 else {
        let selectedRow = companyPickerView.selectedRow(inComponent: 0)
        let selectedSymbol = Array(companies.values)[selectedRow]
        requestImage(for: selectedSymbol)
        requestQuote(for: selectedSymbol)
        return
        }
        requestQuote(for: "KOSS")
        requestImage(for: "KOSS")
    }
    
    private func requestQuote(for symbol: String) {
        let token = "pk_8608c575514e4575929f9417dde17788"
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/quote?token=\(token)") else {
            return
        }
        
        let dataTask = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            if
                let data = data,
                (response as? HTTPURLResponse)?.statusCode == 200,
                error == nil {
                self?.parseQoute(from: data)
            } else {
                self?.showAlert(message: "No internet connection")
                return
            }
        }
        
        dataTask.resume()
    }
    
    private func parseQoute(from data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let companyName = json["companyName"] as? String,
                let companySymbol = json["symbol"] as? String,
                let price = json["latestPrice"] as? Double,
                let priceChange = json["change"] as? Double
            else {
                self.showAlert(message: "Something is wrong with JSON")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.displayStockInfo(companyName: companyName,
                                       companySymbol: companySymbol,
                                       price: price,
                                       priceChange: priceChange)
            }
        } catch {
            print("JSON parsing error: " + error.localizedDescription)
            }
        }
    
    //MARK: - Loading company image
    
    private func loadingImageCompany(data: Data){
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let stringURL = json["url"] as? String
                else {
                    self.showAlert(message: "Something is wrong with JSON")
                    return
                }
            
            DispatchQueue.main.async { [self] in
                let url = URL(string: stringURL)
                let data = try? Data(contentsOf: url!)
                
                if let imageData = data {
                    companyImage.image = UIImage(data: imageData)
                }
                
            }
        } catch {
            print("JSON parsing error: " + error.localizedDescription)
        }
    }
    
    //MARK: - Request Image
    
    private func requestImage(for symbol: String) {
        let token = "pk_8608c575514e4575929f9417dde17788"
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/logo?token=\(token)") else {
            return
        }
        
        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
                else {
                    self.showAlert(message: "No internet connection")
                    return
            }
            self.loadingImageCompany(data: data)
        }
        
        dataTask.resume()
    }
    
    private func parseStocksList(data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            
            guard let jsonArray = jsonObject as? [[String: Any]] else {
                    self.showAlert(message: "Something is wrong with JSON")
                    return
            }

             DispatchQueue.main.async { [self] in
                for array in jsonArray {
                    guard let title = array["symbol"] as? String else { return }
                    guard let name = array["companyName"] as? String else { return }
                    companies[name] = title
                }
                
                companyPickerView.reloadAllComponents();
            }

        } catch {
            print("JSON parsing error: " + error.localizedDescription)
        }
    }
    
    
    private func requestStocksList() {
        let token = "pk_8608c575514e4575929f9417dde17788"
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/market/list/gainers?token=\(token)") else {
            return
        }
        
        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
                else {
                    self.showAlert(message: "No internet connection")
                    return
            }
            self.parseStocksList(data: data)
        }
        
        dataTask.resume()
    }
    
    //MARK: - Check our internet connection
    
    private func checkInternetConnection() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRoute = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRoute!, &flags) {
            return false
        }
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return (isReachable && !needsConnection)
    }
    
    
    private func retry(alertAction: UIAlertAction) {
        requestStocksList()
        requestQuoteUpdate()
    }
    
    private func showAlert(message: String) {
        if !checkInternetConnection() {
            let alert = UIAlertController(title: "Warning", message: message, preferredStyle: .alert)
            let action = UIAlertAction(title: "Try again", style: .default, handler: retry)
            alert.addAction(action)
            present(alert, animated: true, completion: nil)
        }
    }
        
    
    //MARK: - Display
    
    private func displayStockInfo(companyName: String,
                                  companySymbol: String,
                                  price: Double,
                                  priceChange: Double) {
        priceChangeLabel.textColor = .black
        activityIndicator.stopAnimating()
        companyNameLabel.text = companyName
        companySymboLabel.text = companySymbol
        priceLabel.text = "\(price)"
        priceChangeLabel.text = "\(priceChange)"
        
        //MARK: - Change color priceChange
        
        if priceChange > 0 {
            priceChangeLabel.textColor = .green
        } else if priceChange < 0 {
            priceChangeLabel.textColor = .red
        }
    }
}

 




