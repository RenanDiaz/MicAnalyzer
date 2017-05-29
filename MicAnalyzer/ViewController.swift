//
//  ViewController.swift
//  MicAnalyzer
//
//  Created by Renán Díaz Reyes on 5/26/17.
//  Copyright © 2017 Renán Díaz Reyes. All rights reserved.
//

import UIKit
import AudioKit

class ViewController: UIViewController {
  
  @IBOutlet weak var frequencyLabel: UILabel!
  @IBOutlet weak var amplitudeLabel: UILabel!
  @IBOutlet weak var noteNameWithSharpsLabel: UILabel!
  @IBOutlet weak var noteNameWithFlatsLabel: UILabel!
  @IBOutlet var audioInputPlot: EZAudioPlot!
  @IBOutlet weak var label: UILabel!
  
  var mic: AKMicrophone!
  var tracker: AKFrequencyTracker!
  var silence: AKBooster!
  
  let noteFrequencies = [16.3516, 17.3239, 18.3540, 19.4454, 20.6017, 21.8268, 23.1247, 24.4997, 25.9565, 27.5000, 29.1352, 30.8677]
  let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
  let noteNamesWithFlats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
  var quantityPerNotes = [String: Int]()
  var totalQuantity = 0
  var scale = ""
  let majorScale = [true, false, true, false, true, true, false, true, false, true, false, true]
  let naturalMinorScale = [true, false, true, true, false, true, false, true, true, false, true, false]
  let harmonicMinorScale = [true, false, true, true, false, true, false, true, true, false, false, true]
  let melodicMinorScale = [true, false, true, true, false, true, false, true, false, true, false, true]
  
  func setupMicPlot() {
    let plot = AKNodeOutputPlot(mic, frame: audioInputPlot.bounds)
    plot.plotType = .rolling
    plot.shouldFill = true
    plot.shouldMirror = true
    plot.color = UIColor.blue
    audioInputPlot.addSubview(plot)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    AKSettings.audioInputEnabled = true
    mic = AKMicrophone()
    tracker = AKFrequencyTracker(mic)
    silence = AKBooster(tracker, gain: 0)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    AudioKit.output = silence
    AudioKit.start()
    setupMicPlot()
    Timer.scheduledTimer(timeInterval: 0.1,
                         target: self,
                         selector: #selector(ViewController.updateUI),
                         userInfo: nil,
                         repeats: true)
  }
  
  func updateUI() {
    if tracker.amplitude > 0.1 {
      frequencyLabel.text = String(format: "%0.2fHz", tracker.frequency)
      
      var frequency = Float(tracker.frequency)
      while frequency > Float(noteFrequencies[noteFrequencies.count - 1]) {
        frequency /= 2.0
      }
      while frequency < Float(noteFrequencies[0]) {
        frequency *= 2.0
      }
      
      var minDistance: Float = 10_000.0
      var index = 0
      
      for i in 0..<noteFrequencies.count {
        let distance = fabsf(Float(noteFrequencies[i]) - frequency)
        if distance < minDistance {
          index = i
          minDistance = distance
        }
      }
      if index == noteFrequencies.count - 1 {
        let distance = fabsf(Float(noteFrequencies[0]) - frequency / 2.0)
        if distance < minDistance {
          frequency /= 2.0
          index = 0
          minDistance = distance
        }
      }
      let octave = Int(log2f(Float(tracker.frequency) / frequency))
      noteNameWithSharpsLabel.text = "\(noteNamesWithSharps[index])\(octave)"
      noteNameWithFlatsLabel.text = "\(noteNamesWithFlats[index])\(octave)"
      totalQuantity += 1
      if quantityPerNotes[noteNamesWithSharps[index]] == nil {
        quantityPerNotes[noteNamesWithSharps[index]] = 1
      } else {
        quantityPerNotes[noteNamesWithSharps[index]]! += 1
      }
      if totalQuantity % 100 == 0 {
        print(quantityPerNotes)
        determineType()
      }
    }
    amplitudeLabel.text = String(format: "%0.2f", tracker.amplitude)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  @IBAction func changeFrequency(_ sender: UISlider) {
    mic.volume = sender.value * 1
  }
  
  @IBAction func micSwitch(_ sender: UISwitch) {
    if sender.isOn {
      mic.start()
    } else {
      mic.stop()
      totalQuantity = 0
      quantityPerNotes = [String: Int]()
    }
  }
  
  func determineType() {
    let descSortedArray = quantityPerNotes.sorted(by: {$0.1 > $1.1})
    print(descSortedArray)
    print("Most repeated: \(descSortedArray[0])")
    let trimmedArray = descSortedArray.prefix(7)
    var sortedStringArray = [String]()
    for note in trimmedArray {
      sortedStringArray.append(note.key)
    }
    var scaleDict = [String: Bool]()
    for noteName in noteNamesWithSharps {
      scaleDict[noteName] = sortedStringArray.contains(noteName)
    }
    var sortedScale = scaleDict.sorted(by: { $0.0 < $1.0 })
    print(sortedScale)
    var hasToContinue = true
    scale = ""
    var count = 0
    while hasToContinue {
      count += 1
      if sortedScale[0].value {
        let root = sortedScale[0].key
        var steps = [Bool]()
        for note in sortedScale {
          steps.append(note.value)
        }
        print(steps)
        var isMajor = true
        var isNaturalMinor = true
        var isHarmonicMinor = true
        var isMelodicMinor = true
        for (index, step) in steps.enumerated() {
          isMajor = isMajor ? step == majorScale[index] : false
          isNaturalMinor = isNaturalMinor ? step == naturalMinorScale[index] : false
          isHarmonicMinor = isHarmonicMinor ? step == harmonicMinorScale[index] : false
          isMelodicMinor = isMelodicMinor ? step == melodicMinorScale[index] : false
        }
        switch true {
        case isMajor:
          addScale(name: "\(root) Major")
        case isNaturalMinor:
          addScale(name: "\(root) Natural minor")
        case isHarmonicMinor:
          addScale(name: "\(root) Harmonic minor")
        case isMelodicMinor:
          addScale(name: "\(root) Melodic minor")
        default:
          addScale(name: "")
        }
      }
      if count == 12 {
        hasToContinue = false
        addScale(name: "Listening...")
      }
      sortedScale.insert(sortedScale.popLast()!, at: 0)
    }
    label.text = scale
  }
  
  func addScale(name: String) {
    if scale == "" {
      scale = name
    } else if name != "" {
      if name == "Listening..." {
        totalQuantity = 0
        quantityPerNotes = [String: Int]()
      } else {
        scale = "\(scale) or \(name)"
      }
    }
  }
}

