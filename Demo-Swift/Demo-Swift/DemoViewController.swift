//
//  DemoViewController.swift
//  Demo-Swift
//
//  Created by Kelvin Lau on 2018-01-12.
//  Copyright © 2018 Kelvin Lau. All rights reserved.
//

import UIKit

final class DemoViewController: UIViewController {
  
  /// Factory method for creating this view controller.
  ///
  /// - Returns: Returns an instance of this view controller.
  class func instantiate() -> DemoViewController {
    let storyboard = UIStoryboard(name: String(describing: DemoViewController.self), bundle: nil)
    let vc = storyboard.instantiateInitialViewController() as! DemoViewController
    return vc
  }
  
  var _player: MHAudioBufferPlayer!
  var _synth: Synth!
  var _synthLock: NSLock!
  

  @IBAction func keyDown(_ sender: UIButton) {
    _synthLock.lock()
    let midiNote = sender.tag
    _synth.playNote(midiNote)
    _synthLock.unlock()
  }
}

// MARK: - Life Cycle
extension DemoViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
//    setUpAudioBufferPlayer()
  }
  
  func setUpAudioBufferPlayer() {
    _synthLock = NSLock()
    let sampleRate: Float = 16000.0
    _synth = Synth(sampleRate: sampleRate)
    _player = MHAudioBufferPlayer(sampleRate: Double(sampleRate), channels: 1, bitsPerChannel: 16, packetsPerBuffer: 1024)
    _player.gain = 0.9
    
    _player.block = { [weak self] buffer, audioFormat in
      guard let strongSelf = self else { return }
      strongSelf._synthLock.lock()
      
      var audioBufferRef = buffer.pointee
    
      let packetsPerBuffer = audioBufferRef.mAudioDataBytesCapacity / audioFormat.mBytesPerPacket
      let packetsWritten = strongSelf._synth.fill(buffer: audioBufferRef.mAudioData, frames: Int(packetsPerBuffer))
      audioBufferRef.mAudioDataByteSize = UInt32(packetsWritten) * audioFormat.mBytesPerPacket
      strongSelf._synthLock.unlock()
    }
    
    _player.start()
  }
  

  
  @IBAction func keyUp(sender: UIButton) {
    _synthLock.lock()
    _synth.releaseNote(midiNote: sender.tag)
    _synthLock.unlock()
  }
}
