//
//  VideoSessionController.swift
//  vs-metal
//
//  Created by SATOSHI NAKAJIMA on 6/20/17.
//  Copyright © 2017 SATOSHI NAKAJIMA. All rights reserved.
//

import UIKit
import AVFoundation
import Metal

class VideoSessionController: UIViewController {
  // Public properties
  var useFronCamera = false
  var fps:Int?
 
  // Calculated properties
  var cameraPosition:AVCaptureDevicePosition {
    return useFronCamera ? AVCaptureDevicePosition.front : AVCaptureDevicePosition.back
  }
  
  // Dynamic properties
  private var session:AVCaptureSession?
  private var camera:AVCaptureDevice?

  // Metal properties
  let device = MTLCreateSystemDefaultDevice()!
  let metalLayer:CAMetalLayer = {
    let layer = CAMetalLayer()
    layer.pixelFormat = .bgra8Unorm
    layer.framebufferOnly = true
    return layer
  }()
  var vertexBuffer:MTLBuffer?
  
  // Debug only for Metal
  let vertexData:[Float] = [ 0.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0, -1.0, 0.0 ]
  var pipelineState: MTLRenderPipelineState?
  var commandQueue: MTLCommandQueue?
  var timer: CADisplayLink?

  override func viewDidLoad() {
    super.viewDidLoad()

    metalLayer.device = self.device
    view.layer.addSublayer(metalLayer)
    
    // Debug
    let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
    vertexBuffer = device.makeBuffer(bytes:vertexData, length:dataSize, options:[])
    // 1
    let defaultLibrary = device.newDefaultLibrary()!
    let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
    let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")
    // 2
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexFunction = vertexProgram
    pipelineStateDescriptor.fragmentFunction = fragmentProgram
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    
    // 3
    pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    commandQueue = device.makeCommandQueue()
    timer = CADisplayLink(target: self, selector: #selector(VideoSessionController.gameloop))
    timer?.add(to: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
    
    startVideoCaptureSession()
  }
  
  func render() {
    guard let drawable = metalLayer.nextDrawable(),
          let pipelineState = self.pipelineState,
          let commandBuffer = commandQueue?.makeCommandBuffer() else {
      return
    }
    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 104.0/255.0, blue: 5.0/255.0, alpha: 1.0)
    
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
    renderEncoder.endEncoding()
    
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  
  func gameloop() {
    autoreleasepool {
      self.render()
    }
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    metalLayer.frame = view.layer.frame
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  

  /*
  // MARK: - Navigation

  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
      // Get the new view controller using segue.destinationViewController.
      // Pass the selected object to the new view controller.
  }
  */
  
  private func addCamera(session:AVCaptureSession) throws {
    self.camera = nil
    let s = AVCaptureDeviceDiscoverySession(deviceTypes: [AVCaptureDeviceType.builtInWideAngleCamera],
                                            mediaType: AVMediaTypeVideo, position: self.cameraPosition)
    if let device = s?.devices[0] {
      self.camera = device
      let preset = AVCaptureSessionPreset1280x720
      if device.supportsAVCaptureSessionPreset(preset) {
        session.sessionPreset = preset
      }
      let cameraInput = try AVCaptureDeviceInput(device: device)
      session.addInput(cameraInput)
      
      if let fps = self.fps {
        try device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTimeMake(1, Int32(fps))
        device.unlockForConfiguration()
      }
    }
  }

  private func startVideoCaptureSession() {
    let session = AVCaptureSession()
    self.session = nil
    do {
      if let microphone = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio) {
        let audioInput = try AVCaptureDeviceInput(device: microphone)
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: .main)
        session.addInput(audioInput)
        session.addOutput(audioOutput)
      }
      try addCamera(session:session)
      if let _ = self.camera {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as AnyHashable: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: .main)
        session.addOutput(videoOutput)
        
        let imageOutput = AVCapturePhotoOutput()
        session.addOutput(imageOutput)
        
        self.session = session
        session.startRunning()
        print("session started")
      } else {
        print("no camera")
      }
    } catch {
      print("error")
    }
  }
}

extension VideoSessionController : AVCaptureAudioDataOutputSampleBufferDelegate,
                                   AVCaptureVideoDataOutputSampleBufferDelegate {
  public func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
    // to be implemented
    print("capture", captureOutput)
  }
}

