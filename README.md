# TrueNorth - Spatial Audio Compass

An iOS app that uses AirPods Pro head tracking and spatial audio to create a sound that always appears to come from North, regardless of your orientation.

## Features

- Real-time compass heading using device magnetometer
- AirPods Pro/Max head tracking integration
- 3D spatial audio positioning
- Visual compass display
- Combined device + head orientation tracking

## Requirements

- iOS 15.0+
- iPhone with compass support
- AirPods Pro or AirPods Max (for head tracking)
- Xcode 15.0+

## Setup

1. Open `TrueNorth.xcodeproj` in Xcode
2. Select your development team in the project settings
3. Connect your iPhone (compass doesn't work in simulator)
4. Build and run the project

## Usage

1. Connect your AirPods Pro or AirPods Max
2. Launch the app and grant necessary permissions:
   - Location (for true north calculation)
   - Motion (for head tracking)
3. Hold your device flat and rotate to calibrate the compass
4. Press "Start North Tone" to begin hearing the directional audio
5. Turn your head and device - the sound will always come from North

## Architecture

- **OrientationManager**: Handles compass and head tracking data
- **SpatialAudioEngine**: Manages 3D audio positioning
- **CompassView**: Visual compass display
- **ContentView**: Main UI and coordination

## Tips

- Works best outdoors away from magnetic interference
- Keep device flat for accurate compass readings
- The app uses a modulated tone that pulses to make direction easier to perceive
- Green AirPods icon indicates active head tracking