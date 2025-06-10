//
//  MultipointViewController.swift
//  ABMate
//
//  Created by Bluetrum on 2023/6/13.
//

import UIKit
import DeviceManager
import RxSwift
import RxRelay
import Toaster

class MultipointViewController: UIViewController {
    
    private let viewModel = SharedViewModel.shared
    private let disposeBag = DisposeBag()
    
    private var descriptionLabel: UILabel!
    private var functionView: UIView! // contains functionNameLabel & enableSwitch
    private var functionNameLabel: UILabel!
    private var enableSwitch: UISwitch!
    private var tableView: UITableView!
    
    private var multipoint: Multipoint?

    private var localBluetoothAddress: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "multipoint".localized
        
        localBluetoothAddress = UserSettings.localBluetoothAddress
        
        setupViews()
        setupObservers()
    }
    
    private func setupViews() {
        let containView = self.view!
        
        // Gérer d'abord la FunctionView
        
        functionView = UIView()
        containView.addSubview(functionView)
        
        functionNameLabel = {
            let label = UILabel()
            label.text = "multipoint".localized
            label.sizeToFit()
            return label
        }()
        functionView.addSubview(functionNameLabel)
        
        enableSwitch = {
            let `switch` = UISwitch()
            `switch`.addTarget(self, action: #selector(clickSwitch(_:)), for: .valueChanged)
            `switch`.sizeToFit()
            return `switch`
        }()
        functionView.addSubview(enableSwitch)
        
        functionNameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            functionNameLabel.topAnchor.constraint(equalTo: functionView.topAnchor, constant: 4),
            functionNameLabel.bottomAnchor.constraint(equalTo: functionView.bottomAnchor, constant: -4),
            functionNameLabel.leadingAnchor.constraint(equalTo: functionView.leadingAnchor),
        ])
        
        enableSwitch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            enableSwitch.topAnchor.constraint(equalTo: functionView.topAnchor, constant: 4),
            enableSwitch.bottomAnchor.constraint(equalTo: functionView.bottomAnchor, constant: -4),
            enableSwitch.trailingAnchor.constraint(equalTo: functionView.trailingAnchor),
        ])
        
        // Gérer ensuite le ContainView
        
        descriptionLabel = {
            let label = UILabel()
            label.textColor = .gray
            label.numberOfLines = 0
            label.text = "multipoint_desc".localized
            label.sizeToFit()
            return label
        }()
        containView.addSubview(descriptionLabel)
        
        tableView = {
            let tableView = UITableView()
            tableView.dataSource = self
            tableView.delegate = self
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
            return tableView
        }()
        containView.addSubview(tableView)
        
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: containView.layoutMarginsGuide.topAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: containView.layoutMarginsGuide.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: containView.layoutMarginsGuide.trailingAnchor),
        ])
        
        functionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            functionView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor),
            functionView.leadingAnchor.constraint(equalTo: containView.layoutMarginsGuide.leadingAnchor),
            functionView.trailingAnchor.constraint(equalTo: containView.layoutMarginsGuide.trailingAnchor),
        ])
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: functionView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: containView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: containView.bottomAnchor),
        ])
    }
    
    private func setupObservers() {
        viewModel.deviceMultipointStatus.subscribeOnNext { [unowned self] in
            self.enableSwitch.isOn = ($0 == true)
        }.disposed(by: disposeBag)
        
        viewModel.deviceMultipointInfo.subscribeOnNext { [unowned self] in
            if let multipoint = $0 {
                // Si aucune adresse locale n'est enregistrée et qu'un seul appareil est présent, c'est celui de la machine
                if UserSettings.localBluetoothAddress == nil,
                   multipoint.endpoints.count == 1 {
                    let address = multipoint.endpoints[0].address
                    UserSettings.localBluetoothAddress = address
                    self.localBluetoothAddress = address
                }
            }
            
            // Refresh Table
            self.multipoint = $0
            self.tableView.reloadData()
        }.disposed(by: disposeBag)
    }
    
    @objc
    private func clickSwitch(_ `switch`: UISwitch) {
        let isOn = `switch`.isOn
        let multipoint = viewModel.deviceMultipointInfo.value
        
        var request: Request
        // Si la désactivation est demandée avec plusieurs appareils connectés, il faut aussi envoyer la commande de déconnexion
        // Actuellement seule la connexion à deux appareils est gérée
        if !isOn, let multipoint, multipoint.endpoints.count > 1 {
            let endpoints = multipoint.endpoints
            
            // Filtrer l'adresse locale
            
            if let localBluetoothAddress = UserSettings.localBluetoothAddress {
                let filteredEndpoints = endpoints.filter { endpoint in
                    endpoint.address.compare(localBluetoothAddress, options: .caseInsensitive) != .orderedSame
                }
                // Prendre la dernière adresse déconnectée (il doit y en avoir au moins une)
                let endpoint = filteredEndpoints.last!
                request = MultipointRequest.disableRequest(addressToDisconnect: endpoint.addressBytes)
            } else {
                // Filtrer le nom local
                let localName = UIDevice.current.name
                let filteredEndpoints = endpoints.filter { endpoint in
                    endpoint.bluetoothName.compare(localName, options: .caseInsensitive) != .orderedSame
                }
                // Après filtrage, s'il reste au moins un appareil, utiliser le dernier à déconnecter
                if filteredEndpoints.count > 0 {
                    let endpoint = filteredEndpoints.last!
                    request = MultipointRequest.disableRequest(addressToDisconnect: endpoint.addressBytes)
                } else {
                    // Utiliser la dernière adresse déconnectée
                    let endpoint = endpoints.last!
                    request = MultipointRequest.disableRequest(addressToDisconnect: endpoint.addressBytes)
                }
            }
        } else {
            request = MultipointRequest.enableRequest(enable: isOn)
        }
        
        viewModel.sendRequest(request) { result, timeout in
            if timeout {
                Toast(text: "request_timeout".localized).show()
            } else if let result = result {
                if result {
                    Toast(text: "request_succeeded".localized).show()
                } else {
                    Toast(text: "request_failed".localized).show()
                }
            }
        }
    }
}

extension MultipointViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return multipoint?.endpoints.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "connections".localized
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Peu de données : on instancie directement UITableViewCell,
        // sinon il faudrait sous-classer pour utiliser detailTextLabel
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "UITableViewCell")
        
        let endpoint = multipoint!.endpoints[indexPath.row]
        
        cell.textLabel?.text = endpoint.bluetoothName
        
        cell.detailTextLabel?.text = {
            if let localBluetoothAddress, endpoint.address.compare(localBluetoothAddress, options: .caseInsensitive) == .orderedSame {
                return "this_phone".localized
            } else if endpoint.bluetoothName.compare(UIDevice.current.name, options: .caseInsensitive) == .orderedSame {
                return "this_phone".localized
            } else {
                return endpoint.isConnected ? "connected".localized : "disconnected".localized
            }
        }()
        
        cell.accessoryType = .detailButton
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let endpoint = multipoint!.endpoints[indexPath.row]
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        
        let connectAction = UIAlertAction(title: "connect".localized, style: .default) { _ in
            self.viewModel.sendRequest(MultipointRequest.connectRequest(addressToConnect: endpoint.addressBytes))
        }
        let disconnectAction = UIAlertAction(title: "disconnect".localized, style: .default) { _ in
            self.viewModel.sendRequest(MultipointRequest.disconnectRequest(addressToDisconnect: endpoint.addressBytes))
        }
        let unpairAction = UIAlertAction(title: "unpair".localized, style: .default) { _ in
            self.viewModel.sendRequest(MultipointRequest.unpairRequest(addressToUnpair: endpoint.addressBytes))
        }
        let cancelAction = UIAlertAction(title: "cancel".localized, style: .cancel)
        
        if endpoint.isConnected {
            alertController.addAction(disconnectAction)
        } else {
            alertController.addAction(connectAction)
        }
        alertController.addAction(unpairAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
}
