//
//  ViewController.swift
//  Plank
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
  @IBOutlet private weak var cameraImageView: UIView!
  @IBOutlet private weak var startButton: UIButton!
  @IBOutlet private weak var descriptionLabel: UILabel!
  @IBOutlet private weak var countdownLabel: UILabel!
  @IBOutlet private weak var timeLabel: UILabel!
  
  private let captureSession = AVCaptureSession()
  private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
  private let videoDataOutput = AVCaptureVideoDataOutput()
  private var drawings: [CAShapeLayer] = []
  
  private var countdownTime = 0
  private var isRunning = false
  private var startTime: TimeInterval?
  
  private var timer: Timer?
  
  private var hasFaces: Bool = false {
    didSet {
      updateFaceState()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    countdownLabel.isHidden = true
    timeLabel.isHidden = true
    
    self.addCameraInput()
    self.showPreview()
    self.processFrames()
    self.captureSession.startRunning()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.previewLayer.frame = self.view.frame
  }
  
  @IBAction func start(_ sender: Any) {
    descriptionLabel.isHidden = true
    countdownTime = 3
    countdownLabel.isHidden = false
    countdownLabel.text = "\(countdownTime)"
    timeLabel.text = "0 сек."
    startButton.isHidden = true
    
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
      self?.countdownTime -= 1
      if (self?.countdownTime ?? -1) < 0 {
        self?.startTime = Date().timeIntervalSince1970
        self?.isRunning = true
        self?.countdownLabel.isHidden = true
        self?.timeLabel.isHidden = false
        self?.startTimer()
        timer.invalidate()
      } else {
        self?.countdownLabel.text = "\(self?.countdownTime ?? 0)"
      }
    }
  }
  
  private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      let diff = Int(floor((Date().timeIntervalSince1970 - (self.startTime ?? 0))))
      self.timeLabel.text = "\(diff) сек."
    }
  }
  
  private func addCameraInput() {
    guard let device = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
      mediaType: .video,
      position: .front).devices.first else {
        return
      }
    let cameraInput = try! AVCaptureDeviceInput(device: device)
    self.captureSession.addInput(cameraInput)
  }
  
  private func showPreview() {
    self.previewLayer.videoGravity = .resizeAspectFill
    self.cameraImageView.layer.addSublayer(self.previewLayer)
    self.previewLayer.frame = self.view.frame
  }
  
  private func processFrames() {
    self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
    self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "frame_processing_queue"))
    self.captureSession.addOutput(self.videoDataOutput)
    guard let connection = self.videoDataOutput.connection(with: AVMediaType.video),
          connection.isVideoOrientationSupported else { return }
    connection.videoOrientation = .portrait
  }
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    self.detectFace(in: frame)
  }
  
  private func detectFace(in image: CVPixelBuffer) {
    let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
      DispatchQueue.main.async {
        if let results = request.results as? [VNFaceObservation], results.count > 0 {
          self.hasFaces = true
          self.handleFaceDetectionResults(results)
        } else {
          self.hasFaces = false
          self.clearDrawings()
        }
      }
    })
    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
    try? imageRequestHandler.perform([faceDetectionRequest])
  }
  
  private func handleFaceDetectionResults(_ observedFaces: [VNFaceObservation]) {
    self.clearDrawings()
    let facesBoundingBoxes: [CAShapeLayer] = observedFaces.map({ (observedFace: VNFaceObservation) -> CAShapeLayer in
      let faceBoundingBoxOnScreen = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
      let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
      let faceBoundingBoxShape = CAShapeLayer()
      faceBoundingBoxShape.path = faceBoundingBoxPath
      faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
      faceBoundingBoxShape.strokeColor = UIColor.green.cgColor
      return faceBoundingBoxShape
    })
    facesBoundingBoxes.forEach({ faceBoundingBox in self.cameraImageView.layer.addSublayer(faceBoundingBox) })
    self.drawings = facesBoundingBoxes
  }
  private func clearDrawings() {
    self.drawings.forEach({ drawing in drawing.removeFromSuperlayer() })
  }
  
  private func updateFaceState() {
    startButton.isEnabled = hasFaces
    startButton.alpha = hasFaces ? 1 : 0.5
    
    if isRunning, !hasFaces {
      timer?.invalidate()
      timer = nil
      finish()
    }
  }
  
  private func finish() {
    isRunning = false
    timeLabel.isHidden = true
    startButton.isHidden = false
    descriptionLabel.isHidden = false
    
    
    
    let diff = Int(floor(Date().timeIntervalSince1970 - (startTime ?? 0)))
    saveTraining(time: diff)
    
    let alert = UIAlertController(title: "Отлично!", message: "Вы простояли в планке \(diff) секунд", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "История тренировок", style: .default, handler: { [weak self] _ in
      self?.performSegue(withIdentifier: "historySeg", sender: nil)
    }))
    alert.addAction(UIAlertAction(title: "Продолжить", style: .default, handler: nil))
    
    present(alert, animated: true)
  }
  
  private func saveTraining(time: Int) {
    let data = UserDefaults.standard.data(forKey: "history") ?? Data()
    var history: [Training] = (try? JSONDecoder().decode([Training].self, from: data)) ?? []
    history.append(Training(date: Date(), time: time))
    if let data = try? JSONEncoder().encode(history) {
      UserDefaults.standard.set(data, forKey: "history")
    }
  }
}

