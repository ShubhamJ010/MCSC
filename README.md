# MCSC (Mission Control Shortcuts)

MCSC is a lightweight, high-performance macOS background utility designed to enhance window management and system navigation through custom global keyboard shortcuts. By bypassing heavy frameworks like SwiftUI in favor of direct AppKit/Core Foundation integration, MCSC maintains an exceptionally low memory footprint (<13MB).

## Key Features

- **Global Event Taps:** Uses low-level `CGEventTap` hooks to listen for system-wide key presses, ensuring immediate response without introducing input lag.
- **Accessibility API Integration:** Communicates directly with `AXUIElement` to query and manipulate open windows, even those owned by other applications.
- **Mission Control Management:** Includes dedicated monitoring for Mission Control and Expose states, with automated fix sequences to resolve UI stuck states.
- **Launch at Login:** Fully integrated with `SMAppService` to allow the utility to start automatically with macOS.
- **High Efficiency:** Architected for performance with minimal CPU usage and a small memory footprint, ideal for always-on background tasks.

## Technical Architecture

MCSC is built using the Model-View-ViewModel (MVVM) pattern to manage system events as "views."

- **Services:** Low-level workhorses handling specific macOS system APIs (`EventTapService`, `AccessibilityService`, `MissionControlService`, `LaunchAtLoginService`).
- **Models:** Encapsulate functional actions, such as window management commands.
- **ViewModels:** Coordinate between user inputs and model actions.

The application leverages advanced Swift techniques, including `Unmanaged` memory management for Core Foundation objects and explicit resource teardown, ensuring maximum stability and performance.
