# MCSC (Mission Control Shortcuts)

MCSC is a lightweight, high-performance macOS background utility designed to enhance window management and system navigation through custom global keyboard shortcuts. By bypassing heavy frameworks like SwiftUI in favor of direct AppKit/Core Foundation integration, MCSC maintains an exceptionally low memory footprint (<15MB).

## Key Features

- **Global Event Taps:** Uses low-level `CGEventTap` hooks to listen for system-wide key presses, ensuring immediate response without introducing input lag.
- **Accessibility API Integration:** Communicates directly with `AXUIElement` to query and manipulate open windows, even those owned by other applications.
- **Mission Control Management:** Includes dedicated monitoring for Mission Control and Expose states, with automated fix sequences to resolve UI stuck states.
- **Launch at Login:** Fully integrated with `SMAppService` to allow the utility to start automatically with macOS.
- **High Efficiency:** Architected for performance with minimal CPU usage and a small memory footprint, ideal for always-on background tasks.
- **Configurable Shortcuts:** Support for toggling the following global keyboard shortcuts:
    - `Cmd + W`: Close active window
    - `Cmd + Q`: Quit active application
    - `Cmd + M`: Minimize active window
    - `Cmd + H`: Hide active application
    - `Cmd + F`: Maximize/Fullscreen active window
    - `Cmd + Space`: Mission Control UI fix


## Performance Characteristics

Performance analysis conducted on macOS confirms the application's lightweight architecture:

- **CPU Usage:** Consistently near 0.0% during idle periods, ensuring minimal impact on battery life and system responsiveness.
- **Memory Footprint:** Maintains a steady memory usage profile, typically occupying ~14MB of resident set size (RSS).
- **Battery Impact:** Due to the low CPU usage and efficient event-driven model, the application has negligible impact on battery drain.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/MCSC.git
   cd MCSC
   ```
2. Open the project in Xcode:
   ```bash
   open MCSC.xcodeproj
   ```
3. Build the application using the `MCSC` scheme.

## Usage

1. Launch `MCSC.app` from your Applications folder or via Xcode.
2. Upon first launch, you will be prompted to grant **Accessibility Permissions** in **System Settings > Privacy & Security > Accessibility**. This is required for the application to control windows and listen for global events.
3. Once granted, MCSC will run in the background. Keyboard shortcuts can be configured or updated in the application settings.

## Code Signing with Sentinel

To ensure the application runs correctly on macOS, it must be signed with a valid developer certificate. If you are using **Sentinel** to manage your signing process:

1. Ensure your Sentinel environment is configured with your Apple Developer credentials.
2. Navigate to your project directory.
3. Use the Sentinel CLI to apply signing to the application bundle:
   ```bash
   sentinel sign --app MCSC.app --identity "Developer ID Application: Your Name (TeamID)"
   ```
4. Verify the signature:
   ```bash
   codesign -dv --verbose=4 MCSC.app
   ```

## Technical Architecture

MCSC is built using the Model-View-ViewModel (MVVM) pattern to manage system events as "views."

- **Services:** Low-level workhorses handling specific macOS system APIs (`EventTapService`, `AccessibilityService`, `MissionControlService`, `LaunchAtLoginService`).
- **Models:** Encapsulate functional actions, such as window management commands.
- **ViewModels:** Coordinate between user inputs and model actions.

The application leverages advanced Swift techniques, including `Unmanaged` memory management for Core Foundation objects and explicit resource teardown, ensuring maximum stability and performance.
