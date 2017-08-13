//
//  UploadUserPhotoManager.swift
//  Eatvago
//
//  Created by Ｍason Chang on 2017/8/13.
//  Copyright © 2017年 Ｍason Chang iOS#4. All rights reserved.
//

import UIKit
import Firebase
import FirebaseStorage

protocol UploadOrDownLoadUserPhotoDelegate:class {
    
    func manager(_ manager: UploadOrDownLoadUserPhotoManager, uploadSuccessNotion: String)
    
    func manager(_ manager: UploadOrDownLoadUserPhotoManager, downloadImageURL: URL)
    
    func manager(_ manager: UploadOrDownLoadUserPhotoManager, errorDescription: String?)
    
    
}


class UploadOrDownLoadUserPhotoManager {
    
    weak var delegate: UploadOrDownLoadUserPhotoDelegate?
    
    
    func uploadUserPhoto(userPhoto: UIImage) {
        
        guard let userID = Auth.auth().currentUser?.uid else {
            return
        }
        
        let reference: DatabaseReference! = Database.database().reference().child("UserAccount").child(userID).child("UserPhotoURL")
        
        let storageRef = Storage.storage().reference().child("UserAccount").child(userID).child("UserPhoto")
        
        if let uploadData = UIImagePNGRepresentation(userPhoto) {
            
            
            storageRef.putData(uploadData, metadata: nil, completion: { (data, error) in
                
                if error != nil {
                    
                    self.delegate?.manager(self, errorDescription: error?.localizedDescription)
                    return
                    
                }
                
                
                if let uploadImageUrl = data?.downloadURL()?.absoluteString {
                    
                    reference.setValue(uploadImageUrl)
                    self.delegate?.manager(self, uploadSuccessNotion: "uploadImage Success")
                    
                }
                
            })
            
        }
    }
    
    func downLoadUserPhoto() {
        
        guard let userID = Auth.auth().currentUser?.uid else {
            return
        }
        
        let reference: DatabaseReference! = Database.database().reference().child("UserAccount").child(userID).child("UserPhotoURL")
        
        reference.observeSingleEvent(of: .value, with: { (snapshot) in
            
            if snapshot.exists() == false {
                
                self.delegate?.manager(self, errorDescription: "NO image can download")
                
                return
            }
            
            guard let photoURLString = snapshot.value as? String else {
                
                self.delegate?.manager(self, errorDescription: "download user photo fail")
                return
                
            }
            
            guard let photoURL = URL(string: photoURLString) else {
                
                self.delegate?.manager(self, errorDescription: "download user photo fail")
                return
                
            }
            
            print(photoURL)
            
            self.delegate?.manager(self, downloadImageURL: photoURL)
            
            })
        
    }
    
    
    
    
    
    
    
    
}