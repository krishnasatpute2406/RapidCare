# Walkthrough - RapidCare Project Architecture

I have completed a comprehensive audit of the RapidCare application and documented its entire architecture, navigation flows, and animation systems.

## Documentation Summary

### [Project Architecture](file:///C:/Users/Krishna/Documents/Final%20year%20project/Rapidcare/rapidcare_app/.artifacts/81f43e55-7afb-4614-b3a0-c1c2a54cb976/Project_Architecture.artifact.md)
This new document provides a high-level view of:
- **Navigation Map**: A step-by-step guide for both the Patient and Driver experiences.
- **Component Breakdown**: How the `screens`, `widgets`, and `models` work together.
- **Animation Details**: A technical look at how we implemented the live tracking and SOS pulses.
- **Feature Flow**: Clear tables showing how buttons redirect users throughout the app.

## Key Insights Found

- **Multi-Role Support**: The app handles both Patient and Driver roles with distinct logic, including a shared `MainShell` for the patient navigation.
- **Animation Sophistication**: The use of `AnimatedBuilder` in the `AmbulanceStatusScreen` provides a realistic simulation of movement between geographic coordinates (simulated as screen offsets).
- **Data-Driven UI**: The app uses a robust set of models (`Hospital`, `Ambulance`, `EmergencyRequest`) to ensure type-safety and consistency when passing data across the 24+ routes.

> [!TIP]
> You can use this document as a "Source of Truth" when explaining the project to others or when planning new features, as it maps out every major button and redirection in the system.
