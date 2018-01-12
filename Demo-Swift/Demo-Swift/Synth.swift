//
//  Synth.swift
//  Demo-Swift
//
//  Created by Kelvin Lau on 2018-01-11.
//  Copyright © 2018 Kelvin Lau. All rights reserved.
//

import Darwin

let MaxToneEvents = 16
let AttackTime: Float = 0.005
let ReleaseTime: Float = 0.5

enum ToneEventState: Int {
  case inactive
  case pressed
  case released
}

struct ToneEvent {
  var state: ToneEventState = .inactive
  var midiNote: Float = 0
  var phase: Float = 0
  var fadeOut: Float = 0
  var envStep: Float = 0
  var envDelta: Float = 0
}

class Synth {
  
  var _sampleRate: Float
  var _gain: Float
  
  var _sine: UnsafeMutableBufferPointer<Float>?
  var _sineLength: Int
  
  var _envelope: UnsafeMutableBufferPointer<Float>?
  var _envLength: Int
  
  var _tones: [ToneEvent] = .init(repeating: ToneEvent(), count: MaxToneEvents)
  
  var _pitches: [Float] = .init(repeating: 0, count: 128)
  
  init(sampleRate: Float) {
    _sampleRate = sampleRate
    _sine = nil
    _sineLength = 0
    _envelope = nil
    _envLength = 0
    _gain = 0.3
    
    for n in stride(from: 0, to: MaxToneEvents, by: 1) {
      _tones[n].state = .inactive
    }
    
    equalTemperament()
    buildSineTable()
    buildEnvelope()
  }
  
  deinit {
//     free(_sine);
//     free(_envelope);
  }
  
  func equalTemperament() {
    for n in stride(from: 0, to: 128, by: 1) {
      _pitches[n] = Float(440.0) * powf(2, Float(n - 69) / Float(12.0))
    }
  }
  
  func buildSineTable() {
    _sineLength = Int(_sampleRate)
    _sine = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>.allocate(capacity: 1), count: _sineLength * MemoryLayout<Float>.size)
    
    for i in stride(from: 0, to: _sineLength, by: 1) {
      _sine![i] = sinf(Float(i * 2) * Float.pi / Float(_sineLength))
    }
  }
  
  func buildEnvelope() {
    _envLength = Int(_sampleRate * 2)
    _envelope = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>.allocate(capacity: 1), count: _envLength * MemoryLayout<Float>.size) 
    
    let attackLength = Int(AttackTime * _sampleRate)
    for i in stride(from: 0, to: attackLength, by: 1) {
      _envelope![i] = Float(i) / Float(attackLength)
    }
    
    for i in stride(from: attackLength, to: _envLength, by: 1) {
      let x = Float(i - attackLength) / _sampleRate
      _envelope![i] = expf(-x * 3)
    }
  }
  
  func playNote(_ midiNote: Int) {
    for n in stride(from: 0, to: MaxToneEvents, by: 1) {
      if _tones[n].state == .inactive {
        _tones[n].state = .pressed
        _tones[n].midiNote = Float(midiNote)
        _tones[n].phase = 0.0
        _tones[n].envStep = 0.0
        _tones[n].envDelta = Float(midiNote) / 64.0
        _tones[n].fadeOut = 1.0
        return
      }
    }
  }
  
  func releaseNote(midiNote: Int) {
    for n in stride(from: 0, to: MaxToneEvents, by: 1) {
      if _tones[n].midiNote == Float(midiNote) && _tones[n].state != .inactive {
        _tones[n].state = .released
      }
    }
  }
  
  func fill(buffer: UnsafeMutableRawPointer!, frames: Int) -> Int {
    var p = buffer.load(as: [Int16].self)
    
    for f in stride(from: 0, to: frames, by: 1) {
      var m: Float = 0.0
      
      for n in stride(from: 0, to: MaxToneEvents, by: 1) {
        if _tones[n].state == .inactive {
          continue
        }
        
        var a = Int(_tones[n].envStep)
        var b = _tones[n].envStep - 1
        var c = a + 1
        if c >= _envLength {
          c = 1
        }
        let envValue = (Float(1) - b) * _envelope![a] + b * _envelope![c]
        
        _tones[n].envStep += _tones[n].envDelta
        if Int(_tones[n].envStep) >= _envLength {
          _tones[n].state = .inactive
          continue
        }
        
        a = Int(_tones[n].phase)
        b = _tones[n].phase - Float(a)
        c = a + 1
        if c >= _sineLength {
          c -= _sineLength
        }
        let sineValue = (Float(1.0) - b) * _sine![a] + b * _sine![c]
        
        _tones[n].phase += _pitches[Int(_tones[n].midiNote)]
        if Int(_tones[n].phase) >= _sineLength {
          _tones[n].phase = Float(_sineLength)
        }
        
        if _tones[n].state == .released {
          _tones[n].fadeOut -= 1.0 / (ReleaseTime * _sampleRate)
          if _tones[n].fadeOut <= 0.0 {
            _tones[n].state = .inactive
            continue
          }
        }
        
        var s = sineValue * envValue * _gain * _tones[n].fadeOut
        
        if s > 1.0 {
          s = 1.0
        } else if s < -1.0 {
          s = -1.0
        }
        
        m += s
      }
      
      p[f] = (Int16)(m * 0x7FFF)
    }
    return frames
  }
}
