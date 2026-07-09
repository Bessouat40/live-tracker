# Live Tracker

Live tracker is a Qt-based application that handles two real-time inputs:

- A live video stream
- GPS information

The objective is to provide a Qt application that:

- Displays the live video stream
- Displays an interactive map

A YOLO model runs continuously on the host machine to make inferences on the incoming video stream. When a specific target label is detected, a screenshot is automatically saved and associated with the current geographic location provided by the GPS. This location is then dynamically pinned and displayed on the map.

---

## Hardware Architecture

To ensure performance and keep the mobile vehicle lightweight, the system relies on a distributed architecture:

### 1. Edge Node (Mobile Unit)

This unit is embedded on the vehicle (drone, RC car) and is strictly dedicated to data acquisition and streaming.

- **Processing:** A lightweight Single Board Computer (SBC)
- **Vision:** A compatible camera module
- **Positioning:** A standard GPS receiver
- **Connectivity:** A wireless network interface (Wi-Fi hotspot or Cellular) to stream data to the base station
- **Power:** A battery pack coupled with a voltage converter (BEC)

### 2. Base Station (Host PC)

This is the machine running the Qt application, acting as the brain of the project.

- **Processing:** A standard PC with sufficient CPU/GPU capabilities to run YOLO inferences smoothly
- **Connectivity:** Connected to the same network as the Edge Node to receive the RTSP/UDP video stream and GPS telemetry
