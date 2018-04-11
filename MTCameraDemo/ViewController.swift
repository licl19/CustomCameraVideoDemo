//
//  ViewController.swift
//  MTCameraDemo
//
//  Created by zj-db1180 on 2018/4/10.
//  Copyright © 2018年 zj-db1180. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        MTCamera.shared.setupCamera()
        
        let time: TimeInterval = 1.0
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + time) {
            let videoPreviewLayer = MTCamera.shared.videoPreviewLayer
            videoPreviewLayer?.bounds = UIScreen.main.bounds
            UIApplication.shared.delegate?.window??.layer.addSublayer(videoPreviewLayer!)
        }
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    override func viewWillAppear(_ animated: Bool) {
        MTCamera.shared.startRunningSession()
        super.viewWillAppear(animated)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        MTCamera.shared.takePhoto()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

