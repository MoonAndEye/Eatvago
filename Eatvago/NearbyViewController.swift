//
//  NearbyViewController.swift
//  Eatvago
//
//  Created by Ｍason Chang on 2017/7/26.
//  Copyright © 2017年 Ｍason Chang iOS#4. All rights reserved.
//

import UIKit
import GoogleMaps
import GooglePlaces
import NVActivityIndicatorView
import FirebaseDatabase
import Firebase
import SCLAlertView
import FSPagerView

class NearbyViewController: UIViewController, FSPagerViewDataSource, FSPagerViewDelegate, NVActivityIndicatorViewable, UITabBarControllerDelegate {
    
    @IBOutlet weak var userPhotoImageView: UIImageView!

    @IBOutlet weak var userInfoTextView: UITextView!
    
    @IBOutlet weak var userInfoBackgroundView: UIView!
    
    @IBOutlet weak var storeNameLabel: UILabel!
    
    @IBOutlet weak var setUpFilterButton: UIButton!
    
    @IBOutlet weak var storeDurationTimeLabel: UILabel!
    
    @IBOutlet weak var storeDistanceLabel: UILabel!
    
    @IBOutlet weak var storeNavigationButton: UIButton!

    @IBOutlet weak var addToListButton: UIButton!
    
    @IBOutlet weak var mapView: UIView!
    
    @IBOutlet weak var loadingNVAView: NVActivityIndicatorView!
    
 
    
    //set up pager view
    
    @IBOutlet weak var storeImagePagerView: FSPagerView! {
        
        didSet {
            
            self.storeImagePagerView.register(FSPagerViewCell.self, forCellWithReuseIdentifier: "cell")
            self.typeIndex = 1
            
        }
    }
    
    fileprivate let transformerTypes: [FSPagerViewTransformerType] = [.crossFading,
                                                                      .zoomOut,
                                                                      .depth,
                                                                      .linear,
                                                                      .overlap,
                                                                      .ferrisWheel,
                                                                      .invertedFerrisWheel,
                                                                      .coverFlow,
                                                                      .cubic]
    fileprivate var typeIndex = 0 {
        didSet {
            let type = self.transformerTypes[typeIndex]
            self.storeImagePagerView.transformer = FSPagerViewTransformer(type:type)
            switch type {
            case .crossFading, .zoomOut, .depth:
                self.storeImagePagerView.itemSize = .zero // 'Zero' means fill the size of parent
            case .linear, .overlap:
                let transform = CGAffineTransform(scaleX: 0.6, y: 0.75)
                self.storeImagePagerView.itemSize = self.storeImagePagerView.frame.size.applying(transform)
            case .ferrisWheel, .invertedFerrisWheel:
                self.storeImagePagerView.itemSize = CGSize(width: 180, height: 140)
            case .coverFlow:
                self.storeImagePagerView.itemSize = CGSize(width: 220, height: 170)
            case .cubic:
                let transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                self.storeImagePagerView.itemSize = self.storeImagePagerView.frame.size.applying(transform)
            }
        }
    }
    

    var window: UIWindow?
    
    // 與TabBarcontroller分享的Model
    var fetchedLocations = [Location]()
    
    //Declare the location manager, current location, map view, places client, and default zoom level at the class level
    var locationManager = CLLocationManager()
    var currentLocation = CLLocation()
    var googleMapView: GMSMapView!
    var placesClient: GMSPlacesClient!
    var zoomLevel: Float = 18.0
    var filterDistance = 500.0
    var keywordText = ""
    //附近的地點 base on mylocation
    var locations: [Location] = []
    
    //建立呼叫fetchNearbyLocation使用的location 用途：避免重複互叫fetchNearbyLocationManager
    var lastLocation: CLLocation?
    
    //建立location的字典 座標是key 值是location struct  目的: 改善地點間交集的狀況
    var nearbyLocationDictionary: [String : Location ] = [:]
    
    let fetchNearbyLocationManager = FetchNearbyLocationManager()
    let fetchPlaceIdDetailManager = FetchPlaceIdDetailManager()
    let fetchLocationImageManager = FetchLocationImageManager()
    let fetchDistanceManager = FetchDistanceManager()
    var nextPageToken = ""
    var lastPageToken = ""
    var fetchPageCount = 0
    
    //給予假資料 讓下面不用解optional
    var choosedLocation = Location(latitude: 0, longitude: 0, name: "", id: "", placeId: "", types: [], priceLevel: nil, rating: nil, photoReference: "")
    
    //用來add資訊
    var ref: DatabaseReference?
    var databaseHandle: DatabaseHandle?
    
    var tabBarC = MainTabBarController()
    
    override func loadView() {
         super.loadView()
        
        //設置初始點
        let camera = GMSCameraPosition.camera(withLatitude: 25.042476,
                                              longitude: 121.564882,
                                              zoom: 20)
        
        googleMapView = GMSMapView.map(withFrame: mapView.bounds,
                                       camera: camera)
        
        googleMapView.settings.myLocationButton = true
        
        googleMapView.autoresizingMask = [.flexibleWidth,
                                          .flexibleHeight]
        googleMapView.isMyLocationEnabled = true
        
        // Add the map to the view, hide it until we've got a location update.
        mapView.addSubview(googleMapView)
        
        googleMapView.isHidden = true
        
        mapView.isHidden = true
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarC = self.tabBarController as? MainTabBarController ?? MainTabBarController()
        tabBarC.fetchedLocations = self.locations
        tabBarC.delegate = self
        tabBarC.nearbyViewController = self

        // 配置 locationManager
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
        locationManager.startUpdatingLocation()
        locationManager.delegate = self
        placesClient = GMSPlacesClient.shared()
        
        // set up pagerview delegate

        self.storeImagePagerView.delegate = self
        self.storeImagePagerView.dataSource = self
        
        fetchNearbyLocationManager.delegate = self
        fetchPlaceIdDetailManager.delegate = self
        fetchDistanceManager.delegate = self
        fetchLocationImageManager.delegate = self

        ref = Database.database().reference()
        
        //layout
        addToListButton.addTarget(self, action: #selector(addToList), for: .touchUpInside)
        
        
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
        
        tabBarC.fetchedLocations = self.locations
        tabBarC.delegate = self
        
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {

        tabBarC.fetchedLocations = self.locations
        
    }
    
    public func numberOfItems(in pagerView: FSPagerView) -> Int {
        
        return locations.count
        
    }
    
    public func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "cell", at: index)
        
        let location = locations[index]
        
        if location.photo == nil {
            
            cell.imageView?.image = UIImage(named: "noImage")
            cell.imageView?.contentMode = .scaleAspectFill
            self.loadingNVAView.startAnimating()
            cell.imageView?.isHidden = true
            
            
        } else {
            self.loadingNVAView.stopAnimating()
            self.loadingNVAView.isHidden = true
            cell.imageView?.isHidden = false
            
            guard let storeImage = location.photo else {
                return FSPagerViewCell()
            }
            
            cell.imageView?.image = storeImage
            cell.imageView?.contentMode = .scaleAspectFill
            
        }
        
        storeDistanceLabel.text = location.distanceText
        storeDurationTimeLabel.text = location.durationText
        storeNameLabel.text = location.name
        
        choosedLocation = location
        
        var ifInTheList = false
        
        for locationInList in tabBarC.addLocations {
            
            if locationInList.name == choosedLocation.name {
                
                ifInTheList = true
                
            }
           
        }
        
        if ifInTheList == true {
            
            addToListButton.tintColor = UIColor.red
            
        } else {
            
            addToListButton.tintColor = UIColor.asiSeaBlue
            
        }
        return cell

    }
    
    
//    
//    
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        
//        guard let cell = tableView.dequeueReusableCell(withIdentifier: "mapTableViewCell", for: indexPath) as? NearbyMapTableViewCell else {
//            return UITableViewCell()
//        }
//        
//        let location = locations[indexPath.row]
//        
//        cell.mapTextLabel.text = location.name
//        
//        if location.photo == nil {
//            
//            cell.storePhotoView.startAnimating()
//            cell.storePhotoImageView.isHidden = true
//            
//        } else {
//            
//            cell.storePhotoView.isHidden = true
//            cell.storePhotoImageView.isHidden = false
//            cell.storePhotoView.stopAnimating()
//            
//            guard let storeImage = location.photo else {
//                return UITableViewCell()
//            }
//            
//            cell.storePhotoImageView.image = storeImage
//            cell.storePhotoImageView.contentMode = .scaleToFill
//            
//        }
//        
//        cell.showStoreDetailButton.tag = indexPath.row
//        cell.showStoreDetailButton.addTarget(self, action: #selector(showStoreDetail(_:)), for: .touchUpInside)
//        
//        cell.addToList.tintColor = UIColor.gray
//        
//        for location in tabBarC.addLocations {
//            if location.name == self.locations[indexPath.row].name {
//                cell.addToList.tintColor = UIColor.red
//            }
//        }  
//        cell.addToList.tag = indexPath.row
//        cell.addToList.addTarget(self, action: #selector(addToList), for: .touchUpInside)
//        
//        cell.distanceText.text = location.distanceText
//        cell.durationText.text = location.durationText
//    
//        return cell
//    }
//
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        
//        return self.mapTableView.frame.size.height/5
//        
//    }
//
//    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
//        
//        if section == tableView.numberOfSections - 1 {
//            return 1
//        } else {
//            return 0
//        }
//        
//    }
    
    
    
    
    
    
    func addToList(_ sender: UIButton) {
        
        if sender.tintColor != UIColor.red {
            
            sender.tintColor = UIColor.red
            
            tabBarC.addLocations.append(choosedLocation)

        } else {
            
            sender.tintColor = UIColor.asiSeaBlue
            
            var nowAt = 0
            
            for location in tabBarC.addLocations {
                
                if location.name == choosedLocation.name {
                    tabBarC.addLocations.remove(at: nowAt)
                }
                nowAt += 1
            }
        }
        
    }
    
    /*
    func addStoreDetail(_ sender: UIButton) {
        
        let appearance = SCLAlertView.SCLAppearance(
            kTitleFont: UIFont(name: "HelveticaNeue", size: 15)!,
            kTextFont: UIFont(name: "HelveticaNeue", size: 10)!,
            kButtonFont: UIFont(name: "HelveticaNeue-Bold", size: 14)!,
            showCloseButton: false
        )
        
        // Initialize SCLAlertView using custom Appearance
        let alert = SCLAlertView(appearance: appearance)
        let subTextField = UITextField(frame: CGRect(x: 0, y: 0, width: 216, height: 70))
        let x = (subTextField.frame.width - 180) / 2
        
        let addCommentTextField = UITextField(frame: CGRect(x: x, y: 10, width: 180, height: 50))
        
        addCommentTextField.layer.borderColor = UIColor.blue.cgColor
        addCommentTextField.layer.borderWidth = 1.5
        addCommentTextField.layer.cornerRadius = 5
        addCommentTextField.placeholder = " 施工中"
        subTextField.addSubview(addCommentTextField)
        alert.customSubview = subTextField
        
        alert.addButton("OK") {
            
            let text = addCommentTextField.text
            
            let autoId = self.ref?.childByAutoId()
            
            guard let key = autoId?.key else {
                return
            }
            
            self.ref?.child("Place Detail").child("\(self.locations[sender.tag].placeId)").child("Comments").child(key).setValue(key)
            
            self.ref?.child("Comments").child("\(self.locations[sender.tag].placeId)").child(key).child("Creater").setValue(userId)
            
            self.ref?.child("Comments").child("\(self.locations[sender.tag].placeId)").child(key).child("Comment").setValue(text)
            
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.showTitle("評論\(self.locations[sender.tag].name)", subTitle: "", style: .success)
        
    }
    */
    func showStoreDetail(_ sender: UIButton) {
        
        self.fetchPlaceIdDetailManager.requestPlaceIdDetail(locationsWithoutDetail: self.locations[sender.tag], senderTag: sender.tag)
        
    }

    @IBAction func changTableViewAndMap(_ sender: UIButton) {
        if storeImagePagerView.isHidden == true {
            storeImagePagerView.isHidden = false
            storeImagePagerView.reloadData()
            mapView.isHidden = true
            sender.setTitle("Map", for: .normal)
        } else {
            mapView.isHidden = false
            storeImagePagerView.isHidden = true
            self.storeImagePagerView.isHidden = true
            sender.setTitle("Table", for: .normal)
        }
        
    }

    @IBAction func logout(_ sender: UIButton) {
        // 消去 UserDefaults內使用者的帳號資訊
        UserDefaults.standard.setValue(nil, forKey: "UserLoginEmail")
        UserDefaults.standard.setValue(nil, forKey: "UserLoginPassword")
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.makeKeyAndVisible()
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let nextVC = storyBoard.instantiateViewController(withIdentifier: "LoginViewController")
        self.window?.rootViewController = nextVC
    }

//    @IBAction func chaneDistance(_ sender: Any) {
//        
//        locationManager.stopUpdatingLocation()
//        
//        // 建立一個提示框
//        let alertController = UIAlertController(
//            title: "切換距離",
//            message: "請輸入您要的距離",
//            preferredStyle: .alert)
//        
//        // 建立一個輸入框
//        alertController.addTextField { (textField: UITextField!) -> Void in
//            textField.placeholder = "距離"
//        }
//        
//        // 建立[取消]按鈕
//        let cancelAction = UIAlertAction(
//            title: "取消",
//            style: .cancel,
//            handler: nil)
//        alertController.addAction(cancelAction)
//
//        // 建立[登入]按鈕
//        let okAction = UIAlertAction(
//            title: "確認",
//            style: UIAlertActionStyle.default) { (_: UIAlertAction!) -> Void in
//                
//                self.filterDistance = Double((alertController.textFields?.first?.text)!)!
//                self.currentLocation = CLLocation()
//                self.lastLocation = nil
//                self.locations = []
//                self.nearbyLocationDictionary = [:]
//                DispatchQueue.main.async {
//                    self.googleMapView.clear()
//                    self.mapTableView.reloadData()
//                    self.locationManager.startUpdatingLocation()
//                }
//                
//        }
//        alertController.addAction(okAction)
//        self.present(
//            alertController,
//            animated: true,
//            completion: nil)
//        
//    }
   
//    @IBAction func textFilter(_ sender: Any) {
//        
//        locationManager.stopUpdatingLocation()
//        
//        // 建立一個提示框
//        let alertController = UIAlertController(
//            title: "輸入關鍵字",
//            message: "請輸入您的關鍵字",
//            preferredStyle: .alert)
//        
//        // 建立一個輸入框
//        alertController.addTextField { (textField: UITextField!) -> Void in
//            textField.placeholder = "Key word"
//        }
//        
//        // 建立[取消]按鈕
//        let cancelAction = UIAlertAction(
//            title: "取消",
//            style: .cancel,
//            handler: nil)
//        alertController.addAction(cancelAction)
//        
//        // 建立[登入]按鈕
//        let okAction = UIAlertAction(
//            title: "確認",
//            style: UIAlertActionStyle.default) { (_: UIAlertAction!) -> Void in
//                
//                self.keywordText = (alertController.textFields?.first?.text)!
//                self.currentLocation = CLLocation()
//                self.lastLocation = nil
//                self.locations = []
//                self.nearbyLocationDictionary = [:]
//                DispatchQueue.main.async {
//                    self.googleMapView.clear()
//                    self.mapTableView.reloadData()
//                    self.locationManager.startUpdatingLocation()
//                }
//                
//        }
//        alertController.addAction(okAction)
//        self.present(
//            alertController,
//            animated: true,
//            completion: nil)
//        
//    }
    
}
