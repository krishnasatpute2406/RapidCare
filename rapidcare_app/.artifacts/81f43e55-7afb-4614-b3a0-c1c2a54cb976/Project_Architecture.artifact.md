# RapidCare Project Architecture & Overview

RapidCare is a comprehensive emergency response Flutter application designed to bridge the gap between patients, ambulances, and hospitals. The app features two primary user experiences: **Patient** and **Driver**.

## Project Structure

The codebase is organized into a clean, modular structure:

- **`lib/main.dart`**: The application entry point and central routing configuration.
- **`lib/screens/`**: Contains the UI for all 24+ screens, separated by feature area.
- **`lib/widgets/`**: Reusable UI components like the custom SOS button.
- **`lib/models/`**: Data classes defining the core entities (`Hospital`, `Ambulance`, `EmergencyRequest`).
- **`lib/data/`**: Mock data providers (`DummyData`) for prototyping and simulation.
- **`lib/theme/`**: Centralized styling via `AppTheme` (Colors, Typography, Button styles).

## Core User Flows

### 1. The Emergency Patient Flow
This is the "critical path" for users needing immediate medical assistance.

| Step | Screen | Action/Animation | Redirection |
| :--- | :--- | :--- | :--- |
| **Start** | `SplashScreen` | Logo fade-in animation | `/` -> `/dashboard` |
| **Trigger** | `DashboardScreen` | Pulse animation on SOS Button | `SOS Button` -> `/emergency-sos` |
| **Detect** | `EmergencySosScreen` | Pulse icon + Scale animation | Auto-redirect to `/location-confirm` |
| **Confirm** | `LocationScreen` | Map simulation + Pulsing blue dot | `Confirm` -> `/emergency-type` |
| **Select** | `EmergencyTypeScreen` | Grid of categorized emergencies | `Tap Category` -> `/emergency-processing` |
| **Match** | `EmergencyProcessingScreen` | Progress simulation | Auto-redirect to `/hospital-recommendation` |
| **Decide** | `HospitalRecommendationScreen` | Sorted list with Recommendation Scores | `Tap Card` -> `/hospital-details` |
| **Request** | `HospitalDetailsScreen` | Detailed facility breakdown | `Request Ambulance` -> `/request-ambulance` |
| **Assign** | `RequestAmbulanceScreen` | "Assigning" loading state | Auto-assign -> `Track` -> `/ambulance-status` |
| **Track** | `AmbulanceStatusScreen` | **Live Tracking Animation** (Ambulance moves from Hospital to You) | Live status updates |

### 2. The Professional Driver Flow
Designed for ambulance personnel to manage and execute emergency trips.

| Step | Screen | Action/Animation | Redirection |
| :--- | :--- | :--- | :--- |
| **Auth** | `DriverLoginScreen` | Badge ID authentication | `/driver-login` -> `/driver-dashboard` |
| **Status** | `DriverDashboardScreen` | Online/Offline toggle | `Go Online` -> View Active Requests |
| **Accept** | `DriverDashboardScreen` | Swipe/Tap to accept emergency | `Accept` -> `/trip-status` |
| **Execute** | `TripStatusScreen` | Multi-step progress stepper | `Update Status` -> Progress trip |
| **Finish** | `TripStatusScreen` | Completed state | `Finish` -> `/driver-dashboard` |

## Advanced Systems

### Animation Systems
The app uses explicit animations to create a high-quality, professional feel:
- **`AnimationController` & `AnimatedBuilder`**: Used in `AmbulanceStatusScreen` to interpolate coordinates between the Hospital and the Patient.
- **Pulse Effects**: Used in the SOS button and Location marker to indicate active "searching" states.
- **Transitions**: Smooth route transitions defined in the Material design system.

### Navigation Logic
- **Route Arguments**: The app heavily uses arguments to pass complex objects (like `Hospital` or `Ambulance`) between screens.
- **Main Shell**: `MainShell` acts as a container for logged-in users, managing bottom navigation across Dashboard, History, and Profile.

### Recommendation Engine (Simulated)
Hospitals are scored based on:
- **ETA**: Minutes to arrival.
- **Beds**: Current availability.
- **Specialization**: Matching the patient's emergency type.

---
> [!TIP]
> All screens are designed using **Material 3** principles, ensuring a modern look and consistent behavior across Android and iOS devices.
