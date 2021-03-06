//
//  MatchFetchLocationImageDelegate.swift
//  Eatvago
//
//  Created by Ｍason Chang on 2017/8/12.
//  Copyright © 2017年 Ｍason Chang iOS#4. All rights reserved.
//

import UIKit

extension MatchSuccessViewController: FetchLocationImageDelegate {
    
    func manager(_ manager: FetchLocationImageManager, didGet locationImage: UIImage, at indexPathRow: Int) {
        
        DispatchQueue.main.async {
            
            self.locations[indexPathRow].photo = locationImage
            
           self.listPagerView.reloadData()
        }
        
    }
    
    func manager(_ manager: FetchLocationImageManager, didFailWith error: Error) {
        
    }
    
}
