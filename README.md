# CellGuard

<img src="CellGuardAppSwift/Icons/CellFileTypeIcon.png" alt="CellGuard Logo" width="200">

CellGuard is a research project that analyzes how cellular networks are operated and possibly surveilled. 
The CellGuard app for iOS can uncover cellular attacks targeting your iPhone. 
It observes baseband packets and analyzes them for suspicious activities, hinting at rogue base stations. 
Let's catch them all!

Read more about CellGuard & download the app at [our website](https://cellguard.seemoo.de).

## Contributing

You can contribute to the app's development by 
* Testing CellGuard on own iPhone with [TestFlight](https://cellguard.seemoo.de/docs/install/)
* Providing feedback using [Discussions](https://github.com/seemoo-lab/CellGuard/discussions)
* Reporting issues & crashes using [TestFlight](https://cellguard.seemoo.de/docs/report-issues/) or [Issues](https://github.com/seemoo-lab/CellGuard)
* Submitting new features & bug fixes using [Pull Requests](https://github.com/seemoo-lab/CellGuard/pulls)

## Structure

The repository consists of six directories:
- [AnalyzeCells](./AnalyzeCells): A Python script to evaluate datasets exported from CellGuard
- [CaptureCellsTweak](./CaptureCellsTweak): A tweak injected into iOS collecting cells an iPhone connects to
- [CapturePacketsTweak](./CapturePacketsTweak): A tweak injected into iOS collecting binary QMI and ARI packets
- [CellGuardAppRust](./CellGuardAppRust): The Rust extension for the CellGuard iOS app
- [CellGuardAppSwift](./CellGuardAppSwift): The CellGuard iOS app written in Swift
