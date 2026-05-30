# Health Advisor

A SwiftUI iOS app that reads selected Apple Health data and turns the latest daily values into simple, visual health insights.

## Features

- **Step & Activity Tracking** — Daily steps, active energy, exercise minutes
- **Heart Rate** — Resting and average heart rate with trend indicators
- **Sleep Analysis** — Sleep duration and quality overview
- **Health Insights** — Simple daily summaries generated from your Health data
- **Charts & Trends** — Visual charts powered by Swift Charts

## Requirements

- iOS 17+
- A physical iPhone (HealthKit is not available in the simulator)
- An Apple Developer account for signing

## Getting Started

1. Clone the repository on macOS.
2. Open `HealthAdvisor.xcodeproj` in Xcode.
3. Select the `HealthAdvisor` scheme and a physical iPhone target.
4. In **Signing & Capabilities**, select your Apple Developer team.
5. Build and run — grant Health access when iOS asks.

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI Framework | SwiftUI |
| Health Data | HealthKit |
| Charts | Swift Charts |
| Platform | iOS 17+ |

## Privacy & Security

- All health data stays on-device — nothing is sent to external servers.
- HealthKit permissions are requested at runtime and can be revoked anytime in the Health app.
- This repository does not include any personal health data.

## License

No license selected yet.
