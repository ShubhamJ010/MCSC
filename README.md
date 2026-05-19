# MCshortcut Recreation

This project recreates the MCshortcut application with a focus on efficiency, maintainability (MVVM), and high-quality macOS engineering standards.

## Project Structure
- **Models**: `ShortcutActions.swift` - Contains the logic for "Close Window" and "Force Quit".
- **Services**: 
    - `AccessibilityService.swift`: Wrapper for the macOS Accessibility API.
    - `EventTapService.swift`: Low-level global keyboard interceptor.
- **ViewModels**: `ShortcutViewModel.swift`: Connects the shortcuts to the actions.
- **Views**: `MCshortcutApp.swift`: The main application entry point and lifecycle manager.

## How to Build
1. Open **Xcode**.
2. Create a new **macOS App** project named `MCshortcut`.
3. Choose **SwiftUI** for the Interface.
4. Drag the `Source` folder into your Xcode project.
5. Replace the default `MCshortcutApp.swift` with the one in `Source/Views/`.
6. **Important Configuration**:
    - Go to your Project Target -> **Signing & Capabilities**.
    - **Disable App Sandbox** (remove it or set to NO).
    - In **Info.plist** (or target info), ensure `Privacy - Accessibility Usage Description` is added.
    - Set `Application is agent (UIElement)` to `YES` to run as a background app.
7. Use your email to sign the application in the **Signing & Capabilities** tab.
8. Build and Run.

## Usage
- **Cmd + W**: Closes the window currently under the mouse cursor.
- **Cmd + Q**: Force quits the application currently under the mouse cursor.

*Note: You will be prompted to grant Accessibility permissions on the first run.*
