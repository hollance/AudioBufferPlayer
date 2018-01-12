//
//  MHAudioBufferPlayer.swift
//  Demo-Swift
//
//  Created by Kelvin Lau on 2018-01-11.
//  Copyright © 2018 Kelvin Lau. All rights reserved.
//

import AudioToolbox
import AVFoundation

typealias MHAudioBufferPlayerBlock = (_ buffer: AudioQueueBufferRef, _ audioFormat: AudioStreamBasicDescription) -> Void
let NumberOfAudioDataBuffers = 3

func InterruptionListenerCallback(inUserData: UnsafeRawPointer, interruptionState: UInt32) {
  let player = Unmanaged<MHAudioBufferPlayer>.fromOpaque(inUserData).takeUnretainedValue()
  if interruptionState == kAudioSessionBeginInterruption {
    player.tearDownAudio()
  } else if interruptionState == kAudioSessionEndInterruption {
    player.setUpAudio()
    player.start()
  }
}

func PlayCallback(_ inUserData: UnsafeMutableRawPointer!, _ inAudioQueue: AudioQueueRef, _ inBuffer: AudioQueueBufferRef) {
  let player = Unmanaged<MHAudioBufferPlayer>.fromOpaque(inUserData).takeUnretainedValue()
  if player.playing && player.block != nil {
    player.block!(inBuffer, player.audioFormat)
    AudioQueueEnqueueBuffer(inAudioQueue, inBuffer, 0, nil)
  }
}

class MHAudioBufferPlayer {
  
  var block: MHAudioBufferPlayerBlock?
  private(set) var playing: Bool
  var gain: Float32
  var audioFormat: AudioStreamBasicDescription
  
  var _playQueue: AudioQueueRef?
  var _playQueueBuffers: [AudioQueueBufferRef?] = .init(repeating: nil, count: NumberOfAudioDataBuffers)
  var _packetsPerBuffer: UInt32
  var _bytesPerBuffer: UInt32
  
  convenience init(sampleRate: Float64, channels: UInt32, bitsPerChannel: UInt32, secondsPerBuffer: Float64) {
    self.init(sampleRate: sampleRate, channels: channels, bitsPerChannel: bitsPerChannel, packetsPerBuffer: UInt32(secondsPerBuffer * sampleRate))
  }
  
  init(sampleRate: Float64, channels: UInt32, bitsPerChannel: UInt32, packetsPerBuffer: UInt32) {
    playing = false
    _playQueue = nil
    gain = 1.0
    
    audioFormat = AudioStreamBasicDescription()
    
    audioFormat.mFormatID = kAudioFormatLinearPCM
    audioFormat.mSampleRate = sampleRate
    audioFormat.mChannelsPerFrame = channels
    audioFormat.mBitsPerChannel = bitsPerChannel
    audioFormat.mFramesPerPacket = 1 // uncompressed audio
    audioFormat.mBytesPerFrame = audioFormat.mChannelsPerFrame * audioFormat.mBitsPerChannel / 8
    audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
    
    _packetsPerBuffer = packetsPerBuffer
    _bytesPerBuffer = _packetsPerBuffer * audioFormat.mBytesPerPacket
    
    setUpAudio()
  }
  
  deinit {
    tearDownAudio()
  }
  
  func setUpAudio() {
    if _playQueue == nil {
      setUpAudioSession()
      setUpPlayQueue()
      setUpPlayQueueBuffers()
    }
  }
  
  func tearDownAudio() {
    if _playQueue != nil {
      stop()
      tearDownPlayQueue()
      tearDownAudioSession()
    }
  }
  
  func setUpAudioSession() {
    
    // TODO: - Verify that `AudioQueueInitialize` is not necessary.
    
    do {
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Audio session setup failed: \(error)")
    }
  }
  
  func tearDownAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setActive(false)
    } catch {
      print("Audio session teardown failed: \(error)")
    }
  }
  
  func setUpPlayQueue() {
    AudioQueueNewOutput(
      &audioFormat,
      PlayCallback,
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
      nil,
      (CFRunLoopMode.commonModes as! CFString),
      0,
      &_playQueue)
    
    gain = 1.0
  }
  
  func tearDownPlayQueue() {
    AudioQueueDispose(_playQueue!, true)
    _playQueue = nil
  }
  
  func setUpPlayQueueBuffers() {
    for t in stride(from: 0, to: NumberOfAudioDataBuffers, by: 1) {
      AudioQueueAllocateBuffer(_playQueue!, _bytesPerBuffer, &_playQueueBuffers[t])
    }
  }
  
  func primePlayQueueBuffers() {
    for t in stride(from: 0, to: NumberOfAudioDataBuffers, by: 1) {
      PlayCallback(Unmanaged<MHAudioBufferPlayer>.passUnretained(self).toOpaque(), _playQueue!, _playQueueBuffers[t]!)
    }
  }
  
  func start() {
    if !playing {
      playing = true
      primePlayQueueBuffers()
      AudioQueueStart(_playQueue!, nil)
    }
  }
  
  func stop() {
    if playing {
      AudioQueueStop(_playQueue!, true)
      playing = false
    }
  }
  
  func set(gain: Float32) {
    self.gain = gain
    AudioQueueSetParameter(_playQueue!, kAudioQueueParam_Volume, gain)
  }
}


