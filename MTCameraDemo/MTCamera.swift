//
//  MTCamera.swift
//  MTCameraDemo
//
//  Created by zj-db1180 on 2018/4/10.
//  Copyright © 2018年 zj-db1180. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class MTCamera: NSObject {
    // MARK: 单例
    static let shared = MTCamera()
    private override init() {
    }
    
    // MARK: 授权状态
    fileprivate enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    // MARK: 相机类型
    fileprivate enum CaptureMode: Int {
        case photo = 0
        case movie = 1
    }
    // MARK: live photo 类型
    fileprivate enum LivePhotoMode {
        case on
        case off
    }
    // MARK: depth data 类型
    fileprivate enum DepthDataDeliveryMode {
        case on
        case off
    }
    
    fileprivate var sessionSetupResult : SessionSetupResult = .success
    fileprivate var captureMode : CaptureMode = .photo
    fileprivate var livePhotoMode : LivePhotoMode = .on
    fileprivate var depthDataDeliveryMode : DepthDataDeliveryMode = .on
    fileprivate var isSessionRunning = false
    
    // MARK: 会话
    fileprivate let session = AVCaptureSession()
    // MARK: 预览视图
    internal var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    // MARK: 队列
    fileprivate let sessionQueue = DispatchQueue(label: "session queue")
    private let photoOutput = AVCapturePhotoOutput()
    // MARK: 摄像头输入
    fileprivate var videoDeviceInput: AVCaptureDeviceInput!
    
    // MARK: 相机初始化 viewDidLoad
    internal func setupCamera() {
        // MARK: 授权
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionSetupResult = .success
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.sessionSetupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            sessionSetupResult = .notAuthorized
        }
        sessionQueue.async {
            self.configureSession()
        }
    }
    // MARK: 初始化，添加视频，音频输入，图片输出
    fileprivate func configureSession() {
        if sessionSetupResult != .success {
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer.init(session: self.session)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                DispatchQueue.main.async {
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = AVCaptureVideoOrientation(rawValue: statusBarOrientation.rawValue) {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    self.videoPreviewLayer?.connection?.videoOrientation = initialVideoOrientation
                }
            } else {
                print("Could not add video device input to the session")
                sessionSetupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Could not create video device input: \(error)")
            sessionSetupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add audio input.
        do {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("Could not add audio device input to the session")
            }
        } catch {
            print("Could not create audio device input: \(error)")
        }
        
        // Add photo output.
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            livePhotoMode = photoOutput.isLivePhotoCaptureSupported ? .on : .off
            depthDataDeliveryMode = photoOutput.isDepthDataDeliverySupported ? .on : .off
        } else {
            print("Could not add photo output to the session")
            sessionSetupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.commitConfiguration()
    }
    
    // MARK: 开始会话，添加观察者  viewWillAppear
    internal func startRunningSession() {
        sessionQueue.async {
            switch self.sessionSetupResult {
            case .success:
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                    }))
                    UIApplication.shared.windows.first?.rootViewController?.present(alertController, animated: true, completion: nil)
                }
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    UIApplication.shared.windows.first?.rootViewController?.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    // MARK: 停止运行会话，移除观察者 viewWillDisappear
    internal func stopRunningSession() {
        sessionQueue.async {
            if self.sessionSetupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
    // MARK: 配置拍照的session 能使用live，depthData
    func setupSessionPhoto() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            if self.photoOutput.isLivePhotoCaptureSupported {
                self.photoOutput.isLivePhotoCaptureEnabled = true
            }
            if self.photoOutput.isDepthDataDeliverySupported {
                self.photoOutput.isDepthDataDeliveryEnabled = true
            }
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            
            self.session.commitConfiguration()
        }
    }
    // MARK: 拍照
    func takePhoto() {
        let videoPreviewLayerOrientation = videoPreviewLayer?.connection?.videoOrientation
        
        sessionQueue.async {
            // Update the photo output's connection to match the video orientation of the video preview layer.
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
            }
            
            var photoSettings = AVCapturePhotoSettings()
            // Capture HEIF photo when supported, with flash set to auto and high resolution photo enabled.
            if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                
            }
            
            if self.videoDeviceInput.device.isFlashAvailable {
                photoSettings.flashMode = .auto
            }
            
            photoSettings.isHighResolutionPhotoEnabled = true
            if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
            }
//            if self.livePhotoMode == .on && self.photoOutput.isLivePhotoCaptureSupported { // Live Photo capture is not supported in movie mode.
//                let livePhotoMovieFileName = NSUUID().uuidString
//                let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
//                photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
//            }
            
            if self.depthDataDeliveryMode == .on && self.photoOutput.isDepthDataDeliverySupported {
                photoSettings.isDepthDataDeliveryEnabled = true
            } else {
                photoSettings.isDepthDataDeliveryEnabled = false
            }
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}
extension MTCamera : AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let ciImage = CIImage.init(cvPixelBuffer: photo.previewPixelBuffer!)
        let ciContext = CIContext.init(options: nil)
        let videoImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width :CVPixelBufferGetWidth(photo.previewPixelBuffer!), height :CVPixelBufferGetHeight(photo.previewPixelBuffer!)))
        let imageResult = UIImage.init(cgImage: videoImage!, scale: 1.0, orientation: UIImageOrientation.leftMirrored)
        print(imageResult)
        UIImageWriteToSavedPhotosAlbum(imageResult, self, #selector(self.imageDidFinishSavingWithError(image:error:contextInfo:)), nil)
    }
    @objc dynamic fileprivate func imageDidFinishSavingWithError(image: UIImage, error: NSError, contextInfo: UnsafeMutableRawPointer) {
        if error != nil {
            print(error)
        }
        if image != nil {
            print(image)
        }
    }
}
