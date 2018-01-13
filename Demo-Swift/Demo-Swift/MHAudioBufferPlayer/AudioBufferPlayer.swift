//
//  AudioBufferPlayer.swift
//  Demo-Swift
//
//  Created by Kelvin Lau on 2018-01-12.
//  Copyright © 2018 Kelvin Lau. All rights reserved.
//

import AudioToolbox
import AVFoundation

func playCallback(_ inUserData: UnsafeMutableRawPointer!, _ inAudioQueue: AudioQueueRef, _ inBuffer: AudioQueueBufferRef) {
  let player = Unmanaged<AudioBufferPlayer>.fromOpaque(inUserData).takeUnretainedValue()
  if player.isPlaying && player.bufferBlock != nil {
    player.bufferBlock!(inBuffer, player.audioFormat)
    AudioQueueEnqueueBuffer(inAudioQueue, inBuffer, 0, nil)
  }
}

final class AudioBufferPlayer {
  private static let bufferCount = 3
  typealias BufferBlock = (_ buffer: AudioQueueBufferRef, _ audioFormat: AudioStreamBasicDescription) -> Void
  
  
  var bufferBlock: BufferBlock?
  var isPlaying = false
  var gain: Float = 1.0
  var audioFormat = AudioStreamBasicDescription()
  
  var playQueue: AudioQueueRef?
  var playQueueBuffers: [UnsafeMutablePointer<AudioQueueBuffer>?] = .init(repeating: nil, count: bufferCount)
  var packetsPerBuffer: UInt32
  var bytesPerBuffer: UInt32
  
  init(sampleRate: Double, channels: UInt32, bitsPerChannel: UInt32, packetsPerBuffer: UInt32) {
    audioFormat.mFormatID = kAudioFormatLinearPCM
    audioFormat.mSampleRate = sampleRate
    audioFormat.mChannelsPerFrame = channels
    audioFormat.mBitsPerChannel = bitsPerChannel
    audioFormat.mFramesPerPacket = 1
    audioFormat.mBytesPerFrame = audioFormat.mChannelsPerFrame * audioFormat.mBitsPerChannel / 8
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket
    audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
    
    self.packetsPerBuffer = packetsPerBuffer
    self.bytesPerBuffer = packetsPerBuffer * audioFormat.mBytesPerPacket
    
    setUpAudio()
  }
  
  deinit {
    tearDownAudio()
  }

  func setUpAudio() {
    guard playQueue == nil else { return }
    setUpAudioSession()
    setUpPlayQueue()
    setUpPlayQueueBuffers()
  }
  
  func tearDownAudio() {
    guard playQueue == nil else { return }
    stop()
    tearDownPlayQueue()
    tearDownAudioSession()
  }
  
  func setUpAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try! session.setActive(true)
  }
  
  func tearDownAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try! session.setActive(false)
  }
  
  func setUpPlayQueue() {
    AudioQueueNewOutput(&audioFormat, playCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), nil, CFRunLoopMode.commonModes.rawValue, 0, &playQueue)
  }
  
  func tearDownPlayQueue() {
    AudioQueueDispose(playQueue!, true)
    playQueue = nil
  }
  
  func setUpPlayQueueBuffers() {
    for index in playQueueBuffers.indices {
      AudioQueueAllocateBuffer(playQueue!, bytesPerBuffer, &playQueueBuffers[index])
    }
  }
  
  func primePlayQueueBuffers() {
    for index in playQueueBuffers.indices {
      playCallback(Unmanaged<AudioBufferPlayer>.passUnretained(self).toOpaque(), playQueue!, playQueueBuffers[index]!)
    }
  }
  
  func start() {
    guard !isPlaying else { return }
    isPlaying = true
    primePlayQueueBuffers()
    AudioQueueStart(playQueue!, nil)
  }
  
  func stop() {
    guard !isPlaying else { return }
    AudioQueueStop(playQueue!, true)
    isPlaying = false
  }
  
  func set(gain: Float) {
    self.gain = gain
    AudioQueueSetParameter(playQueue!, kAudioQueueParam_Volume, gain)
  }
}
