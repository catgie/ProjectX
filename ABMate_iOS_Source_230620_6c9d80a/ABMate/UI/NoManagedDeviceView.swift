//
//  NoManagedDeviceView.swift
//  ABMate
//
//  Created by Bluetrum on 2023/5/4.
//

import Foundation

import UIKit
import SnapKit

private let MARGIN: CGFloat = 8

class NoManagedDeviceView: UIView {
    
    private var noDeviceImageView: UIImageView!
    private var noDeviceLabel: UILabel!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    private func setupViews() {
        backgroundColor = containerBackgroundColor
        roundCorners(radius: roundCornerRadius)
        
        // Everything is based on caseImageView
        
        let imageContainerView = UIView()
        addSubview(imageContainerView)
        
        // MARK: ImageView
        
        noDeviceImageView = UIImageView()
        noDeviceImageView.contentMode = .scaleAspectFit
        noDeviceImageView.image = UIImage(named: "no_device")
        
        imageContainerView.addSubview(noDeviceImageView)
        
        // MARK: Label
        
        noDeviceLabel = UILabel()
        noDeviceLabel.text = "connect_device_first".localized
        
        imageContainerView.addSubview(noDeviceLabel)
        
        // MARK: Layout ImageView & Label
        
        noDeviceImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
        }
        
        noDeviceLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(noDeviceImageView.snp.bottom).offset(MARGIN)
        }
        
        // MARK: Image Container View
        
        imageContainerView.snp.makeConstraints { make in
            make.top.equalTo(noDeviceImageView)
            make.bottom.equalTo(noDeviceLabel)
            make.centerX.equalToSuperview()
            make.width.equalTo(noDeviceImageView)
        }
        
        snp.makeConstraints { make in
            make.edges.equalTo(imageContainerView).inset(-MARGIN)
        }
    }
}

extension NoManagedDeviceView {
    private var containerBackgroundColor: UIColor { UIColor(white: 0.9, alpha: 1.0) }
    private var roundCornerRadius: CGFloat { 8 }
}
