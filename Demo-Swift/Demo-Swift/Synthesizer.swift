//
//  Synthesizer.swift
//  Demo-Swift
//
//  Created by Kelvin Lau on 2018-01-12.
//  Copyright © 2018 Kelvin Lau. All rights reserved.
//

import Darwin

class Synthesizer {
  private static let maxToneEvents = 3
  private static let attackTime: Float = 0.0005
  private static let releaseTime: Float = 0.5
  
  enum State {
    case inactive, pressed, released
  }
  
  struct ToneEvent {
    var state: State = .inactive
    var midiNote: Float = 0
    var phase: Float = 0
    var fadeOut: Float = 0
    var envStep: Float = 0
    var envDelta: Float = 0
  }
  
  var sampleRate: Float
  var gain: Float = 0.3
  
  var sine: [Float] = []
  var sineLength = 0
  
  var envelope: [Float] = []
  var envLength: Int = 0
  
  var tones: [ToneEvent] = .init(repeating: ToneEvent(), count: maxToneEvents)
  
  var pitches: [Float] = .init(repeating: 0, count: 128)
  
  init(sampleRate: Float) {
    self.sampleRate = sampleRate
    
    equalTemperament()
    buildSineTable()
    buildEnvelope()
  }
  
  func equalTemperament() {
    for index in pitches.indices {
      pitches[index] = Float(440.0) * powf(2, Float(index - 69) / Float(12.0))
    }
  }
  
  func buildSineTable() {
    sineLength = Int(sampleRate)
    
    for i in stride(from: 0, to: sineLength, by: 1) {
      sine.append(sinf(Float(i * 2) * Float.pi / Float(sineLength)))
    }
  }
  
  func buildEnvelope() {
    envLength = Int(sampleRate * 2)
    
    let attackLength = Int(Synthesizer.attackTime * sampleRate)
    for i in stride(from: 0, to: attackLength, by: 1) {
      envelope.append(Float(i) / Float(attackLength))
    }
    
    for i in stride(from: attackLength, to: envLength, by: 1) {
      let x = Float(i - attackLength) / sampleRate
      envelope.append(expf(-x * 3))
    }
  }
  
  func playNote(_ midiNote: Int) {
    for index in tones.indices {
      if tones[index].state == .inactive {
        tones[index].state = .pressed
        tones[index].midiNote = Float(midiNote)
        tones[index].phase = 0.0
        tones[index].envStep = 0.0
        tones[index].envDelta = Float(midiNote) / 64.0
        tones[index].fadeOut = 1.0
        return
      }
    }
  }
  
  func releaseNote(midiNote: Int) {
    for index in tones.indices {
      if tones[index].midiNote == Float(midiNote) && tones[index].state != .inactive {
        tones[index].state = .released
      }
    }
  }
  
  func fill(buffer: UnsafeMutableRawPointer!, frames: Int) -> Int {
    let p = buffer.assumingMemoryBound(to: Int16.self)
    
    for f in stride(from: 0, to: frames, by: 1) {
      var m: Float = 0.0
      
      for n in stride(from: 0, to: Synthesizer.maxToneEvents, by: 1) {
        if tones[n].state == .inactive {
          continue
        }
        
        var a = Int(tones[n].envStep)
        var b = tones[n].envStep - 1
        var c = a + 1
        if c >= envLength {
          c = 1
        }
        let envValue = (Float(1) - b) * envelope[a] + b * envelope[c]
        
        tones[n].envStep += tones[n].envDelta
        if Int(tones[n].envStep) >= envLength {
          tones[n].state = .inactive
          continue
        }
        
        a = Int(tones[n].phase)
        b = tones[n].phase - Float(a)
        c = a + 1
        if c >= sineLength {
          c -= sineLength
        }
        let sineValue = (Float(1.0) - b) * sine[a] + b * sine[c]
        
        tones[n].phase += pitches[Int(tones[n].midiNote)]
        if Int(tones[n].phase) >= sineLength {
          tones[n].phase = Float(sineLength)
        }
        
        if tones[n].state == .released {
          tones[n].fadeOut -= 1.0 / (ReleaseTime * sampleRate)
          if tones[n].fadeOut <= 0.0 {
            tones[n].state = .inactive
            continue
          }
        }
        
        var s = sineValue * envValue * gain * tones[n].fadeOut
        
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












