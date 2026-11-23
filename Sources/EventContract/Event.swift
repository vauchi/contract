// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let event = try Event(json)

import Foundation

/// A hardware event reported by the frontend back to core.
///
/// These are the results of previously issued [`Command`]s or asynchronous hardware
/// notifications (e.g., BLE discovery, NFC tap).
public enum Event: Codable {
    case enumeration(EventEnum)
    case eventClass(EventClass)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(EventEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(EventClass.self) {
            self = .eventClass(x)
            return
        }
        throw DecodingError.typeMismatch(Event.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Event"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .enumeration(let x):
            try container.encode(x)
        case .eventClass(let x):
            try container.encode(x)
        }
    }
}

/// The user scanned a QR code containing `data`.
///
/// Per-frame scan progress from the camera viewfinder.
///
/// Frontends send this periodically (e.g., every 200-500 ms) while the QR scanner is active.
/// Core uses the rolling detection rate to compute a [`ScanQuality`] indicator for the
/// viewfinder frame color.
///
/// - `detected`: whether a QR code was found in this frame - `confidence`: optional
/// platform-specific confidence score (0-100) - `frame_skipped`: true if the scanner skipped
/// this frame (e.g., sharpness gating). Skipped frames are excluded from the quality
/// calculation — they indicate camera settling, not wrong pointing.
///
/// Where this device is reachable on the network it just joined, or `None` when it left one
/// (ADR-070).
///
/// An observation about the platform, like every other variant here: the shell enumerates
/// its interfaces — core cannot, for the same reason it cannot browse for peers
/// (ADR-030/031) — and core decides what to do with it. Shells report on network change and
/// pass `None` when leaving, so a stale address is never advertised to a joiner that cannot
/// reach it.
///
/// What the current network costs: unmetered (Wi-Fi, Ethernet), metered, or unknown. Shells
/// report it on every network change; core decides what to run on it, such as "Wi-Fi only"
/// content updates (vauchi/private#733 D6).
///
/// Raw UUIDs observed by the native BLE scanner. Core decodes any protocol token; hardware
/// adapters never interpret UUID payloads.
///
/// Compatibility observation carrying an already decoded advertisement token. New scanners
/// report `BleAdvertisementObserved` instead.
///
/// Successfully connected to a BLE device. `direction` reports whether this device dialed
/// out (GATT central → [`BleLinkDirection::Outbound`]) or was connected to (GATT peripheral
/// → [`BleLinkDirection::Inbound`]); the handshake role is derived from it, not from the
/// token tiebreak.
///
/// Data read from a BLE characteristic (response to `BleReadCharacteristic`).
///
/// `device_id` names the link the data arrived on so core can reject events from a
/// stale/losing link under glare instead of feeding them into the surviving session.
///
/// BLE characteristic notification received (unsolicited push from peripheral). `device_id`
/// names the link the notification arrived on (see [`Event::BleCharacteristicRead`]).
///
/// One BLE link was lost or closed. `device_id` + `direction` identify exactly which link,
/// so dropping a losing glare link is distinguishable from losing the surviving session's
/// link.
///
/// NFC data received from a tap exchange (legacy shape: readers pass `data || SW1 SW2`, the
/// HCE responder passes the bare payload).
///
/// Raw bytes off the NFC wire, decoded by core: a response APDU on the reader side, a
/// command APDU on the HCE side.
///
/// The OS NFC session failed (tag lost, session invalidated, transceive error). `reason` is
/// the OS description; core decides what it means for the exchange.
///
/// Raw PCM samples from a microphone listen.
///
/// Core decodes the FSK signal internally — the frontend ships whatever it captured at its
/// native rate. Mono float PCM.
///
/// A hardware operation failed.
///
/// The requested hardware is not available on this platform.
///
/// The user denied the required permission for this hardware.
///
/// Distinct from `HardwareUnavailable` (hardware absent) — the hardware exists but the OS
/// permission was denied. Frontends should send this when a runtime permission prompt is
/// rejected (camera, BLE, microphone).
///
/// The device's current location, in reply to [`Command::LocationRequest`] (ADR-051 contact
/// annotations). Coordinates are decimal degrees; `accuracy_meters` is the provider's
/// reported horizontal accuracy, if any.
///
/// Accelerometer sample from the device.
///
/// Acceleration is reported in milli-g (thousandths of standard gravity) to avoid `f32` and
/// keep the type `Eq`-compatible across FFI boundaries.
///
/// Impact detected by the device accelerometer.
///
/// Relay escrow gate has reached required deposit count.
///
/// Relay escrow deposit/retrieve failed or gate expired.
///
/// Link was opened by peer, providing their public key.
///
/// Blob retrieved from relay escrow gate (response to `RelayEscrowRetrieve`).
///
/// The peer's bytes received over a direct transport.
///
/// Sent by the frontend after completing the TCP swap requested by [`Command::DirectSend`].
/// Core decides from the exchange phase whether the bytes are the peer's key payload or its
/// encrypted card; the shell forwards them unchanged (ADR-066).
///
/// Image data received from photo library, camera, or file picker.
///
/// The frontend sends raw image bytes (PNG, JPEG, etc.) — core handles format detection and
/// normalization to WebP.
///
/// File data received from a [`Command::FilePickFromUser`] request.
///
/// `bytes` is the entire file payload (no decoding — decoding lives in core). `filename` is
/// the OS-reported display name; some platforms do not expose it, in which case the frontend
/// reports an empty string.
///
/// MTU negotiated for the active BLE connection. `mtu` is the raw value reported by the GATT
/// stack (Android `MTU_CHANGED` callback, CoreBluetooth `maximumWriteValueLength + 3`). Core
/// subtracts the 3-byte ATT header internally before chunking via `BleChunker::new(data, mtu
/// - 3)`.
///
/// Decoupled from `BleConnected` so a re-negotiation mid-session (Android `requestMtu` after
/// connect) has a home, and so platforms whose connection completes before MTU resolves
/// don't have to delay `BleConnected` waiting for it. Frontends that don't programmatically
/// observe MTU (desktop Bluetooth stacks) simply never emit this event — the chunker stays
/// at `BLE_DEFAULT_USABLE` (20 bytes per ATT minimum).
///
/// Per `_private/docs/designs/2026-05-28-slice-32m-phase-0-event-command-mapping-design.md`
/// §3.2.
///
/// Retired card-leg event, still accepted for one release and handled exactly like
/// [`Event::DirectPayloadReceived`]. Remove it together with `Command::DirectSendCard` once
/// every shell reports the card leg as `DirectPayloadReceived`.
///
/// A Core-minted interaction on a presented surface was activated.
///
/// Available presentation facts changed for the current window.
///
/// A visible surface became the target of user interaction.
///
/// Native or contextual Back was requested for a surface.
///
/// A presented overlay was dismissed without activating an item.
///
/// A raw value changed for an opaque binding on the current surface.
///
/// The user signalled completion on an opaque binding — the platform's own "done" affordance
/// (Return, IME action, Enter).
///
/// An observation, not an intent: the shell reports that the gesture happened and Core
/// decides what it means. A shell that has no such affordance simply never sends it.
///
/// An opaque binding lost input focus without the user submitting.
///
/// Paired with `InputSubmitted` so Core can tell "finished typing and confirmed" from
/// "typed, then went elsewhere" — the two need different treatment when text is still
/// uncommitted.
///
/// The operating system delivered an opaque application deep link.
///
/// The user made the platform's refresh gesture (pull to refresh, a refresh key) on
/// `surface_id`. An observation only: Core validates the surface as for
/// [`Event::BackRequested`], decides what to refresh and presents the outcome, so the shell
/// never reads a sync result (vauchi/private#762).
///
/// The OS allows this app `runs` background executions per `window_secs` (Android's App
/// Standby bucket); `runs` 0 means no known limit. An observation only: Core draws the
/// background schedule within it.
///
/// The GATT link to `device_id` is ready to carry payload: services discovered,
/// characteristics resolved, and the peer's notification subscription confirmed.
///
/// Decoupled from [`Event::BleConnected`] for the same reason as
/// [`Event::BleMtuNegotiated`]: platforms reach "connected" and "usable" at different
/// moments, and delaying `BleConnected` until both hold would lose the connection signal the
/// chrome needs.
///
/// It exists because treating "connected" as "ready" is what breaks the BLE modes. iOS
/// reports connection before subscriptions resolve and applies no write backpressure, so a
/// card write can reach the peer ahead of its KeyAck — which
/// `orchestrator::ble_handshake_machine` treats as terminal, dropping the late KeyAck and
/// killing the exchange. Android already waits for the same conditions internally, so it can
/// report this immediately after its existing wait.
///
/// Optional: a platform that never emits it leaves Core exactly as it was, so this cannot
/// regress the shells that do not send it.
///
/// Phase C of
/// `_private/docs/planning/todo/2026-07-20-exchange-modes-regression-safe-completion-plan.md`.
///
/// The operating system confirmed the user and the shell sealed a fresh secret, answering
/// [`Command::CreateUserPresenceSecret`].
///
/// The operating system confirmed the user and the shell unsealed the secret, answering
/// [`Command::RevealUserPresenceSecret`].
///
/// Whether this window can render prepared native application menus.
///
/// Whether this window can show a native status item (system tray).
///
/// Support for PickFile, CancelFilePick and correlated typed outcomes.
///
/// The OS's hardware shell reports what the device can do (ADR-077). Its report attaches it:
/// Core then delivers hardware commands to the hardware shell instead of the display shell.
///
/// The hardware shell needs the person's OS permission for `transport` before it can run a
/// command (ADR-077); Core has the display shell ask.
///
/// The person granted the permission a [`Command::RequestPermission`] asked for.
// MARK: - EventClass
public struct EventClass: Codable {
    public let qrScanned: QrScanned?
    public let qrScanProgress: QrScanProgress?
    public let localNetworkAddressChanged: LocalNetworkAddressChanged?
    public let networkCostChanged: NetworkCostChanged?
    public let bleAdvertisementObserved: BleAdvertisementObservation?
    public let bleDeviceDiscovered: BleDeviceDiscovered?
    public let bleConnected: BleConnected?
    public let bleCharacteristicRead: BleCharacteristicRead?
    public let bleCharacteristicNotified: BleCharacteristicNotified?
    public let bleDisconnected: BleDisconnected?
    public let nfcDataReceived: NFCDataReceived?
    public let nfcApduReceived: NFCApduReceived?
    public let nfcFailed: NFCFailed?
    public let audioSamplesRecorded: AudioSamplesRecorded?
    public let hardwareError: HardwareError?
    public let hardwareUnavailable: HardwareUnavailable?
    public let permissionDenied: PermissionDenied?
    public let locationResult: LocationResult?
    public let accelerometerData: AccelerometerData?
    public let impactDetected: ImpactDetected?
    public let relayEscrowReady: RelayEscrowReady?
    public let relayEscrowFailed: RelayEscrowFailed?
    public let linkOpened: LinkOpened?
    public let relayEscrowBlobReceived: RelayEscrowBlobReceived?
    public let directPayloadReceived: DirectPayloadReceived?
    public let imageReceived: ImageReceived?
    public let filePickedFromUser: FilePickedFromUser?
    public let bleMTUNegotiated: BleMTUNegotiated?
    public let directCardReceived: DirectCardReceived?
    public let actionActivated: ActionActivated?
    public let presentationEnvironmentChanged: PresentationEnvironmentChanged?
    public let surfaceActivated: SurfaceActivated?
    public let backRequested: BackRequested?
    public let overlayDismissed: OverlayDismissed?
    public let valueChanged: ValueChanged?
    public let inputSubmitted: InputSubmitted?
    public let inputFocusEnded: InputFocusEnded?
    public let deepLinkOpened: DeepLinkOpened?
    public let refreshRequested: RefreshRequested?
    public let backgroundBudgetObserved: BackgroundBudgetObserved?
    public let bleGattReady: BleGattReady?
    public let userPresenceSecretCreated: UserPresenceSecretCreated?
    public let userPresenceSecretRevealed: UserPresenceSecretRevealed?
    public let applicationMenuAvailabilityChanged: ApplicationMenuAvailabilityChanged?
    public let statusItemAvailabilityChanged: StatusItemAvailabilityChanged?
    public let filePickerCapabilitiesChanged: FilePickerCapabilitiesChanged?
    public let filePickCompleted: FilePickCompleted?
    public let hardwareCapabilitiesReported: HardwareCapabilitiesReported?
    public let permissionRequired: PermissionRequired?
    public let permissionGranted: PermissionGranted?

    public enum CodingKeys: String, CodingKey {
        case qrScanned = "QrScanned"
        case qrScanProgress = "QrScanProgress"
        case localNetworkAddressChanged = "LocalNetworkAddressChanged"
        case networkCostChanged = "NetworkCostChanged"
        case bleAdvertisementObserved = "BleAdvertisementObserved"
        case bleDeviceDiscovered = "BleDeviceDiscovered"
        case bleConnected = "BleConnected"
        case bleCharacteristicRead = "BleCharacteristicRead"
        case bleCharacteristicNotified = "BleCharacteristicNotified"
        case bleDisconnected = "BleDisconnected"
        case nfcDataReceived = "NfcDataReceived"
        case nfcApduReceived = "NfcApduReceived"
        case nfcFailed = "NfcFailed"
        case audioSamplesRecorded = "AudioSamplesRecorded"
        case hardwareError = "HardwareError"
        case hardwareUnavailable = "HardwareUnavailable"
        case permissionDenied = "PermissionDenied"
        case locationResult = "LocationResult"
        case accelerometerData = "AccelerometerData"
        case impactDetected = "ImpactDetected"
        case relayEscrowReady = "RelayEscrowReady"
        case relayEscrowFailed = "RelayEscrowFailed"
        case linkOpened = "LinkOpened"
        case relayEscrowBlobReceived = "RelayEscrowBlobReceived"
        case directPayloadReceived = "DirectPayloadReceived"
        case imageReceived = "ImageReceived"
        case filePickedFromUser = "FilePickedFromUser"
        case bleMTUNegotiated = "BleMtuNegotiated"
        case directCardReceived = "DirectCardReceived"
        case actionActivated = "ActionActivated"
        case presentationEnvironmentChanged = "PresentationEnvironmentChanged"
        case surfaceActivated = "SurfaceActivated"
        case backRequested = "BackRequested"
        case overlayDismissed = "OverlayDismissed"
        case valueChanged = "ValueChanged"
        case inputSubmitted = "InputSubmitted"
        case inputFocusEnded = "InputFocusEnded"
        case deepLinkOpened = "DeepLinkOpened"
        case refreshRequested = "RefreshRequested"
        case backgroundBudgetObserved = "BackgroundBudgetObserved"
        case bleGattReady = "BleGattReady"
        case userPresenceSecretCreated = "UserPresenceSecretCreated"
        case userPresenceSecretRevealed = "UserPresenceSecretRevealed"
        case applicationMenuAvailabilityChanged = "ApplicationMenuAvailabilityChanged"
        case statusItemAvailabilityChanged = "StatusItemAvailabilityChanged"
        case filePickerCapabilitiesChanged = "FilePickerCapabilitiesChanged"
        case filePickCompleted = "FilePickCompleted"
        case hardwareCapabilitiesReported = "HardwareCapabilitiesReported"
        case permissionRequired = "PermissionRequired"
        case permissionGranted = "PermissionGranted"
    }

    public init(qrScanned: QrScanned?, qrScanProgress: QrScanProgress?, localNetworkAddressChanged: LocalNetworkAddressChanged?, networkCostChanged: NetworkCostChanged?, bleAdvertisementObserved: BleAdvertisementObservation?, bleDeviceDiscovered: BleDeviceDiscovered?, bleConnected: BleConnected?, bleCharacteristicRead: BleCharacteristicRead?, bleCharacteristicNotified: BleCharacteristicNotified?, bleDisconnected: BleDisconnected?, nfcDataReceived: NFCDataReceived?, nfcApduReceived: NFCApduReceived?, nfcFailed: NFCFailed?, audioSamplesRecorded: AudioSamplesRecorded?, hardwareError: HardwareError?, hardwareUnavailable: HardwareUnavailable?, permissionDenied: PermissionDenied?, locationResult: LocationResult?, accelerometerData: AccelerometerData?, impactDetected: ImpactDetected?, relayEscrowReady: RelayEscrowReady?, relayEscrowFailed: RelayEscrowFailed?, linkOpened: LinkOpened?, relayEscrowBlobReceived: RelayEscrowBlobReceived?, directPayloadReceived: DirectPayloadReceived?, imageReceived: ImageReceived?, filePickedFromUser: FilePickedFromUser?, bleMTUNegotiated: BleMTUNegotiated?, directCardReceived: DirectCardReceived?, actionActivated: ActionActivated?, presentationEnvironmentChanged: PresentationEnvironmentChanged?, surfaceActivated: SurfaceActivated?, backRequested: BackRequested?, overlayDismissed: OverlayDismissed?, valueChanged: ValueChanged?, inputSubmitted: InputSubmitted?, inputFocusEnded: InputFocusEnded?, deepLinkOpened: DeepLinkOpened?, refreshRequested: RefreshRequested?, backgroundBudgetObserved: BackgroundBudgetObserved?, bleGattReady: BleGattReady?, userPresenceSecretCreated: UserPresenceSecretCreated?, userPresenceSecretRevealed: UserPresenceSecretRevealed?, applicationMenuAvailabilityChanged: ApplicationMenuAvailabilityChanged?, statusItemAvailabilityChanged: StatusItemAvailabilityChanged?, filePickerCapabilitiesChanged: FilePickerCapabilitiesChanged?, filePickCompleted: FilePickCompleted?, hardwareCapabilitiesReported: HardwareCapabilitiesReported?, permissionRequired: PermissionRequired?, permissionGranted: PermissionGranted?) {
        self.qrScanned = qrScanned
        self.qrScanProgress = qrScanProgress
        self.localNetworkAddressChanged = localNetworkAddressChanged
        self.networkCostChanged = networkCostChanged
        self.bleAdvertisementObserved = bleAdvertisementObserved
        self.bleDeviceDiscovered = bleDeviceDiscovered
        self.bleConnected = bleConnected
        self.bleCharacteristicRead = bleCharacteristicRead
        self.bleCharacteristicNotified = bleCharacteristicNotified
        self.bleDisconnected = bleDisconnected
        self.nfcDataReceived = nfcDataReceived
        self.nfcApduReceived = nfcApduReceived
        self.nfcFailed = nfcFailed
        self.audioSamplesRecorded = audioSamplesRecorded
        self.hardwareError = hardwareError
        self.hardwareUnavailable = hardwareUnavailable
        self.permissionDenied = permissionDenied
        self.locationResult = locationResult
        self.accelerometerData = accelerometerData
        self.impactDetected = impactDetected
        self.relayEscrowReady = relayEscrowReady
        self.relayEscrowFailed = relayEscrowFailed
        self.linkOpened = linkOpened
        self.relayEscrowBlobReceived = relayEscrowBlobReceived
        self.directPayloadReceived = directPayloadReceived
        self.imageReceived = imageReceived
        self.filePickedFromUser = filePickedFromUser
        self.bleMTUNegotiated = bleMTUNegotiated
        self.directCardReceived = directCardReceived
        self.actionActivated = actionActivated
        self.presentationEnvironmentChanged = presentationEnvironmentChanged
        self.surfaceActivated = surfaceActivated
        self.backRequested = backRequested
        self.overlayDismissed = overlayDismissed
        self.valueChanged = valueChanged
        self.inputSubmitted = inputSubmitted
        self.inputFocusEnded = inputFocusEnded
        self.deepLinkOpened = deepLinkOpened
        self.refreshRequested = refreshRequested
        self.backgroundBudgetObserved = backgroundBudgetObserved
        self.bleGattReady = bleGattReady
        self.userPresenceSecretCreated = userPresenceSecretCreated
        self.userPresenceSecretRevealed = userPresenceSecretRevealed
        self.applicationMenuAvailabilityChanged = applicationMenuAvailabilityChanged
        self.statusItemAvailabilityChanged = statusItemAvailabilityChanged
        self.filePickerCapabilitiesChanged = filePickerCapabilitiesChanged
        self.filePickCompleted = filePickCompleted
        self.hardwareCapabilitiesReported = hardwareCapabilitiesReported
        self.permissionRequired = permissionRequired
        self.permissionGranted = permissionGranted
    }
}

// MARK: EventClass convenience initializers and mutators

public extension EventClass {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(EventClass.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        qrScanned: QrScanned?? = nil,
        qrScanProgress: QrScanProgress?? = nil,
        localNetworkAddressChanged: LocalNetworkAddressChanged?? = nil,
        networkCostChanged: NetworkCostChanged?? = nil,
        bleAdvertisementObserved: BleAdvertisementObservation?? = nil,
        bleDeviceDiscovered: BleDeviceDiscovered?? = nil,
        bleConnected: BleConnected?? = nil,
        bleCharacteristicRead: BleCharacteristicRead?? = nil,
        bleCharacteristicNotified: BleCharacteristicNotified?? = nil,
        bleDisconnected: BleDisconnected?? = nil,
        nfcDataReceived: NFCDataReceived?? = nil,
        nfcApduReceived: NFCApduReceived?? = nil,
        nfcFailed: NFCFailed?? = nil,
        audioSamplesRecorded: AudioSamplesRecorded?? = nil,
        hardwareError: HardwareError?? = nil,
        hardwareUnavailable: HardwareUnavailable?? = nil,
        permissionDenied: PermissionDenied?? = nil,
        locationResult: LocationResult?? = nil,
        accelerometerData: AccelerometerData?? = nil,
        impactDetected: ImpactDetected?? = nil,
        relayEscrowReady: RelayEscrowReady?? = nil,
        relayEscrowFailed: RelayEscrowFailed?? = nil,
        linkOpened: LinkOpened?? = nil,
        relayEscrowBlobReceived: RelayEscrowBlobReceived?? = nil,
        directPayloadReceived: DirectPayloadReceived?? = nil,
        imageReceived: ImageReceived?? = nil,
        filePickedFromUser: FilePickedFromUser?? = nil,
        bleMTUNegotiated: BleMTUNegotiated?? = nil,
        directCardReceived: DirectCardReceived?? = nil,
        actionActivated: ActionActivated?? = nil,
        presentationEnvironmentChanged: PresentationEnvironmentChanged?? = nil,
        surfaceActivated: SurfaceActivated?? = nil,
        backRequested: BackRequested?? = nil,
        overlayDismissed: OverlayDismissed?? = nil,
        valueChanged: ValueChanged?? = nil,
        inputSubmitted: InputSubmitted?? = nil,
        inputFocusEnded: InputFocusEnded?? = nil,
        deepLinkOpened: DeepLinkOpened?? = nil,
        refreshRequested: RefreshRequested?? = nil,
        backgroundBudgetObserved: BackgroundBudgetObserved?? = nil,
        bleGattReady: BleGattReady?? = nil,
        userPresenceSecretCreated: UserPresenceSecretCreated?? = nil,
        userPresenceSecretRevealed: UserPresenceSecretRevealed?? = nil,
        applicationMenuAvailabilityChanged: ApplicationMenuAvailabilityChanged?? = nil,
        statusItemAvailabilityChanged: StatusItemAvailabilityChanged?? = nil,
        filePickerCapabilitiesChanged: FilePickerCapabilitiesChanged?? = nil,
        filePickCompleted: FilePickCompleted?? = nil,
        hardwareCapabilitiesReported: HardwareCapabilitiesReported?? = nil,
        permissionRequired: PermissionRequired?? = nil,
        permissionGranted: PermissionGranted?? = nil
    ) -> EventClass {
        return EventClass(
            qrScanned: qrScanned ?? self.qrScanned,
            qrScanProgress: qrScanProgress ?? self.qrScanProgress,
            localNetworkAddressChanged: localNetworkAddressChanged ?? self.localNetworkAddressChanged,
            networkCostChanged: networkCostChanged ?? self.networkCostChanged,
            bleAdvertisementObserved: bleAdvertisementObserved ?? self.bleAdvertisementObserved,
            bleDeviceDiscovered: bleDeviceDiscovered ?? self.bleDeviceDiscovered,
            bleConnected: bleConnected ?? self.bleConnected,
            bleCharacteristicRead: bleCharacteristicRead ?? self.bleCharacteristicRead,
            bleCharacteristicNotified: bleCharacteristicNotified ?? self.bleCharacteristicNotified,
            bleDisconnected: bleDisconnected ?? self.bleDisconnected,
            nfcDataReceived: nfcDataReceived ?? self.nfcDataReceived,
            nfcApduReceived: nfcApduReceived ?? self.nfcApduReceived,
            nfcFailed: nfcFailed ?? self.nfcFailed,
            audioSamplesRecorded: audioSamplesRecorded ?? self.audioSamplesRecorded,
            hardwareError: hardwareError ?? self.hardwareError,
            hardwareUnavailable: hardwareUnavailable ?? self.hardwareUnavailable,
            permissionDenied: permissionDenied ?? self.permissionDenied,
            locationResult: locationResult ?? self.locationResult,
            accelerometerData: accelerometerData ?? self.accelerometerData,
            impactDetected: impactDetected ?? self.impactDetected,
            relayEscrowReady: relayEscrowReady ?? self.relayEscrowReady,
            relayEscrowFailed: relayEscrowFailed ?? self.relayEscrowFailed,
            linkOpened: linkOpened ?? self.linkOpened,
            relayEscrowBlobReceived: relayEscrowBlobReceived ?? self.relayEscrowBlobReceived,
            directPayloadReceived: directPayloadReceived ?? self.directPayloadReceived,
            imageReceived: imageReceived ?? self.imageReceived,
            filePickedFromUser: filePickedFromUser ?? self.filePickedFromUser,
            bleMTUNegotiated: bleMTUNegotiated ?? self.bleMTUNegotiated,
            directCardReceived: directCardReceived ?? self.directCardReceived,
            actionActivated: actionActivated ?? self.actionActivated,
            presentationEnvironmentChanged: presentationEnvironmentChanged ?? self.presentationEnvironmentChanged,
            surfaceActivated: surfaceActivated ?? self.surfaceActivated,
            backRequested: backRequested ?? self.backRequested,
            overlayDismissed: overlayDismissed ?? self.overlayDismissed,
            valueChanged: valueChanged ?? self.valueChanged,
            inputSubmitted: inputSubmitted ?? self.inputSubmitted,
            inputFocusEnded: inputFocusEnded ?? self.inputFocusEnded,
            deepLinkOpened: deepLinkOpened ?? self.deepLinkOpened,
            refreshRequested: refreshRequested ?? self.refreshRequested,
            backgroundBudgetObserved: backgroundBudgetObserved ?? self.backgroundBudgetObserved,
            bleGattReady: bleGattReady ?? self.bleGattReady,
            userPresenceSecretCreated: userPresenceSecretCreated ?? self.userPresenceSecretCreated,
            userPresenceSecretRevealed: userPresenceSecretRevealed ?? self.userPresenceSecretRevealed,
            applicationMenuAvailabilityChanged: applicationMenuAvailabilityChanged ?? self.applicationMenuAvailabilityChanged,
            statusItemAvailabilityChanged: statusItemAvailabilityChanged ?? self.statusItemAvailabilityChanged,
            filePickerCapabilitiesChanged: filePickerCapabilitiesChanged ?? self.filePickerCapabilitiesChanged,
            filePickCompleted: filePickCompleted ?? self.filePickCompleted,
            hardwareCapabilitiesReported: hardwareCapabilitiesReported ?? self.hardwareCapabilitiesReported,
            permissionRequired: permissionRequired ?? self.permissionRequired,
            permissionGranted: permissionGranted ?? self.permissionGranted
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - AccelerometerData
public struct AccelerometerData: Codable {
    public let timestampMS: Int
    public let xMilliG: Int
    public let yMilliG: Int
    public let zMilliG: Int

    public enum CodingKeys: String, CodingKey {
        case timestampMS = "timestamp_ms"
        case xMilliG = "x_milli_g"
        case yMilliG = "y_milli_g"
        case zMilliG = "z_milli_g"
    }

    public init(timestampMS: Int, xMilliG: Int, yMilliG: Int, zMilliG: Int) {
        self.timestampMS = timestampMS
        self.xMilliG = xMilliG
        self.yMilliG = yMilliG
        self.zMilliG = zMilliG
    }
}

// MARK: AccelerometerData convenience initializers and mutators

public extension AccelerometerData {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(AccelerometerData.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        timestampMS: Int? = nil,
        xMilliG: Int? = nil,
        yMilliG: Int? = nil,
        zMilliG: Int? = nil
    ) -> AccelerometerData {
        return AccelerometerData(
            timestampMS: timestampMS ?? self.timestampMS,
            xMilliG: xMilliG ?? self.xMilliG,
            yMilliG: yMilliG ?? self.yMilliG,
            zMilliG: zMilliG ?? self.zMilliG
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ActionActivated
public struct ActionActivated: Codable {
    public let interactionID: String
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case interactionID = "interaction_id"
        case surfaceID = "surface_id"
    }

    public init(interactionID: String, surfaceID: String) {
        self.interactionID = interactionID
        self.surfaceID = surfaceID
    }
}

// MARK: ActionActivated convenience initializers and mutators

public extension ActionActivated {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ActionActivated.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        interactionID: String? = nil,
        surfaceID: String? = nil
    ) -> ActionActivated {
        return ActionActivated(
            interactionID: interactionID ?? self.interactionID,
            surfaceID: surfaceID ?? self.surfaceID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ApplicationMenuAvailabilityChanged
public struct ApplicationMenuAvailabilityChanged: Codable {
    public let available: Bool

    public enum CodingKeys: String, CodingKey {
        case available = "available"
    }

    public init(available: Bool) {
        self.available = available
    }
}

// MARK: ApplicationMenuAvailabilityChanged convenience initializers and mutators

public extension ApplicationMenuAvailabilityChanged {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ApplicationMenuAvailabilityChanged.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        available: Bool? = nil
    ) -> ApplicationMenuAvailabilityChanged {
        return ApplicationMenuAvailabilityChanged(
            available: available ?? self.available
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - AudioSamplesRecorded
public struct AudioSamplesRecorded: Codable {
    public let sampleRate: Int
    public let samples: [Double]

    public enum CodingKeys: String, CodingKey {
        case sampleRate = "sample_rate"
        case samples = "samples"
    }

    public init(sampleRate: Int, samples: [Double]) {
        self.sampleRate = sampleRate
        self.samples = samples
    }
}

// MARK: AudioSamplesRecorded convenience initializers and mutators

public extension AudioSamplesRecorded {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(AudioSamplesRecorded.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        sampleRate: Int? = nil,
        samples: [Double]? = nil
    ) -> AudioSamplesRecorded {
        return AudioSamplesRecorded(
            sampleRate: sampleRate ?? self.sampleRate,
            samples: samples ?? self.samples
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BackRequested
public struct BackRequested: Codable {
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
    }

    public init(surfaceID: String) {
        self.surfaceID = surfaceID
    }
}

// MARK: BackRequested convenience initializers and mutators

public extension BackRequested {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BackRequested.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        surfaceID: String? = nil
    ) -> BackRequested {
        return BackRequested(
            surfaceID: surfaceID ?? self.surfaceID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BackgroundBudgetObserved
public struct BackgroundBudgetObserved: Codable {
    public let runs: Int
    public let windowSecs: Int

    public enum CodingKeys: String, CodingKey {
        case runs = "runs"
        case windowSecs = "window_secs"
    }

    public init(runs: Int, windowSecs: Int) {
        self.runs = runs
        self.windowSecs = windowSecs
    }
}

// MARK: BackgroundBudgetObserved convenience initializers and mutators

public extension BackgroundBudgetObserved {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BackgroundBudgetObserved.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        runs: Int? = nil,
        windowSecs: Int? = nil
    ) -> BackgroundBudgetObserved {
        return BackgroundBudgetObserved(
            runs: runs ?? self.runs,
            windowSecs: windowSecs ?? self.windowSecs
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Bounded native observations, without decoded exchange state. UUID bytes use network order
/// (the order in the conventional hexadecimal UUID).
// MARK: - BleAdvertisementObservation
public struct BleAdvertisementObservation: Codable {
    public let id: String
    public let rssi: Int
    public let serviceUuids: [BleServiceUUID]

    public enum CodingKeys: String, CodingKey {
        case id = "id"
        case rssi = "rssi"
        case serviceUuids = "service_uuids"
    }

    public init(id: String, rssi: Int, serviceUuids: [BleServiceUUID]) {
        self.id = id
        self.rssi = rssi
        self.serviceUuids = serviceUuids
    }
}

// MARK: BleAdvertisementObservation convenience initializers and mutators

public extension BleAdvertisementObservation {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleAdvertisementObservation.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        id: String? = nil,
        rssi: Int? = nil,
        serviceUuids: [BleServiceUUID]? = nil
    ) -> BleAdvertisementObservation {
        return BleAdvertisementObservation(
            id: id ?? self.id,
            rssi: rssi ?? self.rssi,
            serviceUuids: serviceUuids ?? self.serviceUuids
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Preserve the native UUID width where the OS exposes it. `Normalized` explicitly records
/// that the OS expanded a UUID and lost its wire width.
// MARK: - BleServiceUUID
public struct BleServiceUUID: Codable {
    public let uuid16: [Int]?
    public let uuid32: [Int]?
    public let uuid128: [Int]?
    public let normalized: [Int]?

    public enum CodingKeys: String, CodingKey {
        case uuid16 = "Uuid16"
        case uuid32 = "Uuid32"
        case uuid128 = "Uuid128"
        case normalized = "Normalized"
    }

    public init(uuid16: [Int]?, uuid32: [Int]?, uuid128: [Int]?, normalized: [Int]?) {
        self.uuid16 = uuid16
        self.uuid32 = uuid32
        self.uuid128 = uuid128
        self.normalized = normalized
    }
}

// MARK: BleServiceUUID convenience initializers and mutators

public extension BleServiceUUID {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleServiceUUID.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        uuid16: [Int]?? = nil,
        uuid32: [Int]?? = nil,
        uuid128: [Int]?? = nil,
        normalized: [Int]?? = nil
    ) -> BleServiceUUID {
        return BleServiceUUID(
            uuid16: uuid16 ?? self.uuid16,
            uuid32: uuid32 ?? self.uuid32,
            uuid128: uuid128 ?? self.uuid128,
            normalized: normalized ?? self.normalized
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BleCharacteristicNotified
public struct BleCharacteristicNotified: Codable {
    public let data: [Int]
    public let deviceID: String
    public let direction: BleLinkDirection
    public let uuid: String

    public enum CodingKeys: String, CodingKey {
        case data = "data"
        case deviceID = "device_id"
        case direction = "direction"
        case uuid = "uuid"
    }

    public init(data: [Int], deviceID: String, direction: BleLinkDirection, uuid: String) {
        self.data = data
        self.deviceID = deviceID
        self.direction = direction
        self.uuid = uuid
    }
}

// MARK: BleCharacteristicNotified convenience initializers and mutators

public extension BleCharacteristicNotified {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleCharacteristicNotified.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        data: [Int]? = nil,
        deviceID: String? = nil,
        direction: BleLinkDirection? = nil,
        uuid: String? = nil
    ) -> BleCharacteristicNotified {
        return BleCharacteristicNotified(
            data: data ?? self.data,
            deviceID: deviceID ?? self.deviceID,
            direction: direction ?? self.direction,
            uuid: uuid ?? self.uuid
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Which physical direction a BLE link was established in, reported by the shell on
/// [`Event::BleConnected`]. This is the ground truth for the exchange protocol role: the
/// GATT **central** (it dialed out) drives the handshake as initiator; the GATT
/// **peripheral** (it was connected to) responds. Deriving the role from the physical link —
/// not the pre-connection token tiebreak — is what lets asymmetric BLE discovery self-heal:
/// whichever side actually connects becomes the initiator, even if the token said otherwise
/// (`_private/docs/designs/2026-07-22-role-tiebreak-and-glare-design.md`).
///
/// This device is the GATT central — it dialed out to the peer's peripheral.
///
/// This device is the GATT peripheral — the peer connected to it.
public enum BleLinkDirection: String, Codable {
    case inbound = "Inbound"
    case outbound = "Outbound"
}

// MARK: - BleCharacteristicRead
public struct BleCharacteristicRead: Codable {
    public let data: [Int]
    public let deviceID: String
    public let direction: BleLinkDirection
    public let uuid: String

    public enum CodingKeys: String, CodingKey {
        case data = "data"
        case deviceID = "device_id"
        case direction = "direction"
        case uuid = "uuid"
    }

    public init(data: [Int], deviceID: String, direction: BleLinkDirection, uuid: String) {
        self.data = data
        self.deviceID = deviceID
        self.direction = direction
        self.uuid = uuid
    }
}

// MARK: BleCharacteristicRead convenience initializers and mutators

public extension BleCharacteristicRead {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleCharacteristicRead.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        data: [Int]? = nil,
        deviceID: String? = nil,
        direction: BleLinkDirection? = nil,
        uuid: String? = nil
    ) -> BleCharacteristicRead {
        return BleCharacteristicRead(
            data: data ?? self.data,
            deviceID: deviceID ?? self.deviceID,
            direction: direction ?? self.direction,
            uuid: uuid ?? self.uuid
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BleConnected
public struct BleConnected: Codable {
    public let deviceID: String
    public let direction: BleLinkDirection

    public enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case direction = "direction"
    }

    public init(deviceID: String, direction: BleLinkDirection) {
        self.deviceID = deviceID
        self.direction = direction
    }
}

// MARK: BleConnected convenience initializers and mutators

public extension BleConnected {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleConnected.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        deviceID: String? = nil,
        direction: BleLinkDirection? = nil
    ) -> BleConnected {
        return BleConnected(
            deviceID: deviceID ?? self.deviceID,
            direction: direction ?? self.direction
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BleDeviceDiscovered
public struct BleDeviceDiscovered: Codable {
    public let advData: [Int]
    public let id: String
    public let rssi: Int

    public enum CodingKeys: String, CodingKey {
        case advData = "adv_data"
        case id = "id"
        case rssi = "rssi"
    }

    public init(advData: [Int], id: String, rssi: Int) {
        self.advData = advData
        self.id = id
        self.rssi = rssi
    }
}

// MARK: BleDeviceDiscovered convenience initializers and mutators

public extension BleDeviceDiscovered {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleDeviceDiscovered.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        advData: [Int]? = nil,
        id: String? = nil,
        rssi: Int? = nil
    ) -> BleDeviceDiscovered {
        return BleDeviceDiscovered(
            advData: advData ?? self.advData,
            id: id ?? self.id,
            rssi: rssi ?? self.rssi
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BleDisconnected
public struct BleDisconnected: Codable {
    public let deviceID: String
    public let direction: BleLinkDirection
    public let reason: String

    public enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case direction = "direction"
        case reason = "reason"
    }

    public init(deviceID: String, direction: BleLinkDirection, reason: String) {
        self.deviceID = deviceID
        self.direction = direction
        self.reason = reason
    }
}

// MARK: BleDisconnected convenience initializers and mutators

public extension BleDisconnected {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleDisconnected.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        deviceID: String? = nil,
        direction: BleLinkDirection? = nil,
        reason: String? = nil
    ) -> BleDisconnected {
        return BleDisconnected(
            deviceID: deviceID ?? self.deviceID,
            direction: direction ?? self.direction,
            reason: reason ?? self.reason
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BleGattReady
public struct BleGattReady: Codable {
    public let deviceID: String

    public enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
    }

    public init(deviceID: String) {
        self.deviceID = deviceID
    }
}

// MARK: BleGattReady convenience initializers and mutators

public extension BleGattReady {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleGattReady.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        deviceID: String? = nil
    ) -> BleGattReady {
        return BleGattReady(
            deviceID: deviceID ?? self.deviceID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BleMTUNegotiated
public struct BleMTUNegotiated: Codable {
    public let deviceID: String
    public let mtu: Int

    public enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case mtu = "mtu"
    }

    public init(deviceID: String, mtu: Int) {
        self.deviceID = deviceID
        self.mtu = mtu
    }
}

// MARK: BleMTUNegotiated convenience initializers and mutators

public extension BleMTUNegotiated {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleMTUNegotiated.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        deviceID: String? = nil,
        mtu: Int? = nil
    ) -> BleMTUNegotiated {
        return BleMTUNegotiated(
            deviceID: deviceID ?? self.deviceID,
            mtu: mtu ?? self.mtu
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - DeepLinkOpened
public struct DeepLinkOpened: Codable {
    public let uri: String

    public enum CodingKeys: String, CodingKey {
        case uri = "uri"
    }

    public init(uri: String) {
        self.uri = uri
    }
}

// MARK: DeepLinkOpened convenience initializers and mutators

public extension DeepLinkOpened {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DeepLinkOpened.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        uri: String? = nil
    ) -> DeepLinkOpened {
        return DeepLinkOpened(
            uri: uri ?? self.uri
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - DirectCardReceived
public struct DirectCardReceived: Codable {
    public let ciphertext: [Int]

    public enum CodingKeys: String, CodingKey {
        case ciphertext = "ciphertext"
    }

    public init(ciphertext: [Int]) {
        self.ciphertext = ciphertext
    }
}

// MARK: DirectCardReceived convenience initializers and mutators

public extension DirectCardReceived {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DirectCardReceived.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        ciphertext: [Int]? = nil
    ) -> DirectCardReceived {
        return DirectCardReceived(
            ciphertext: ciphertext ?? self.ciphertext
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - DirectPayloadReceived
public struct DirectPayloadReceived: Codable {
    public let data: [Int]

    public enum CodingKeys: String, CodingKey {
        case data = "data"
    }

    public init(data: [Int]) {
        self.data = data
    }
}

// MARK: DirectPayloadReceived convenience initializers and mutators

public extension DirectPayloadReceived {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DirectPayloadReceived.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        data: [Int]? = nil
    ) -> DirectPayloadReceived {
        return DirectPayloadReceived(
            data: data ?? self.data
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - FilePickCompleted
public struct FilePickCompleted: Codable {
    public let outcome: FilePickOutcome
    public let requestID: String

    public enum CodingKeys: String, CodingKey {
        case outcome = "outcome"
        case requestID = "request_id"
    }

    public init(outcome: FilePickOutcome, requestID: String) {
        self.outcome = outcome
        self.requestID = requestID
    }
}

// MARK: FilePickCompleted convenience initializers and mutators

public extension FilePickCompleted {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FilePickCompleted.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        outcome: FilePickOutcome? = nil,
        requestID: String? = nil
    ) -> FilePickCompleted {
        return FilePickCompleted(
            outcome: outcome ?? self.outcome,
            requestID: requestID ?? self.requestID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum FilePickOutcome: Codable {
    case enumeration(FilePickOutcomeEnum)
    case filePickOutcomeClass(FilePickOutcomeClass)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(FilePickOutcomeEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(FilePickOutcomeClass.self) {
            self = .filePickOutcomeClass(x)
            return
        }
        throw DecodingError.typeMismatch(FilePickOutcome.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for FilePickOutcome"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .enumeration(let x):
            try container.encode(x)
        case .filePickOutcomeClass(let x):
            try container.encode(x)
        }
    }
}

// MARK: - FilePickOutcomeClass
public struct FilePickOutcomeClass: Codable {
    public let selected: Selected?
    public let failed: Failed?

    public enum CodingKeys: String, CodingKey {
        case selected = "selected"
        case failed = "failed"
    }

    public init(selected: Selected?, failed: Failed?) {
        self.selected = selected
        self.failed = failed
    }
}

// MARK: FilePickOutcomeClass convenience initializers and mutators

public extension FilePickOutcomeClass {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FilePickOutcomeClass.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        selected: Selected?? = nil,
        failed: Failed?? = nil
    ) -> FilePickOutcomeClass {
        return FilePickOutcomeClass(
            selected: selected ?? self.selected,
            failed: failed ?? self.failed
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Failed
public struct Failed: Codable {
    public let code: FilePickFailure

    public enum CodingKeys: String, CodingKey {
        case code = "code"
    }

    public init(code: FilePickFailure) {
        self.code = code
    }
}

// MARK: Failed convenience initializers and mutators

public extension Failed {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Failed.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        code: FilePickFailure? = nil
    ) -> Failed {
        return Failed(
            code: code ?? self.code
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum FilePickFailure: String, Codable {
    case invalidRequest = "invalid_request"
    case readFailed = "read_failed"
    case tooLarge = "too_large"
    case unsupportedFile = "unsupported_file"
}

// MARK: - Selected
public struct Selected: Codable {
    public let bytes: [Int]
    public let filename: String

    public enum CodingKeys: String, CodingKey {
        case bytes = "bytes"
        case filename = "filename"
    }

    public init(bytes: [Int], filename: String) {
        self.bytes = bytes
        self.filename = filename
    }
}

// MARK: Selected convenience initializers and mutators

public extension Selected {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Selected.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        bytes: [Int]? = nil,
        filename: String? = nil
    ) -> Selected {
        return Selected(
            bytes: bytes ?? self.bytes,
            filename: filename ?? self.filename
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum FilePickOutcomeEnum: String, Codable {
    case cancelled = "cancelled"
}

// MARK: - FilePickedFromUser
public struct FilePickedFromUser: Codable {
    public let bytes: [Int]
    public let filename: String

    public enum CodingKeys: String, CodingKey {
        case bytes = "bytes"
        case filename = "filename"
    }

    public init(bytes: [Int], filename: String) {
        self.bytes = bytes
        self.filename = filename
    }
}

// MARK: FilePickedFromUser convenience initializers and mutators

public extension FilePickedFromUser {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FilePickedFromUser.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        bytes: [Int]? = nil,
        filename: String? = nil
    ) -> FilePickedFromUser {
        return FilePickedFromUser(
            bytes: bytes ?? self.bytes,
            filename: filename ?? self.filename
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - FilePickerCapabilitiesChanged
public struct FilePickerCapabilitiesChanged: Codable {
    public let correlatedResults: Bool

    public enum CodingKeys: String, CodingKey {
        case correlatedResults = "correlated_results"
    }

    public init(correlatedResults: Bool) {
        self.correlatedResults = correlatedResults
    }
}

// MARK: FilePickerCapabilitiesChanged convenience initializers and mutators

public extension FilePickerCapabilitiesChanged {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FilePickerCapabilitiesChanged.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        correlatedResults: Bool? = nil
    ) -> FilePickerCapabilitiesChanged {
        return FilePickerCapabilitiesChanged(
            correlatedResults: correlatedResults ?? self.correlatedResults
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - HardwareCapabilitiesReported
public struct HardwareCapabilitiesReported: Codable {
    public let capabilities: DeviceCapabilities

    public enum CodingKeys: String, CodingKey {
        case capabilities = "capabilities"
    }

    public init(capabilities: DeviceCapabilities) {
        self.capabilities = capabilities
    }
}

// MARK: HardwareCapabilitiesReported convenience initializers and mutators

public extension HardwareCapabilitiesReported {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(HardwareCapabilitiesReported.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        capabilities: DeviceCapabilities? = nil
    ) -> HardwareCapabilitiesReported {
        return HardwareCapabilitiesReported(
            capabilities: capabilities ?? self.capabilities
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Static description of device hardware capabilities.
///
/// Populated once at app startup by the platform layer (iOS/Android/Desktop). All fields use
/// `#[serde(default)]` for backward compatibility when deserializing from older versions
/// that may not include newer fields.
// MARK: - DeviceCapabilities
public struct DeviceCapabilities: Codable {
    /// Device audio capabilities (for ultrasonic proximity verification).
    public let audio: AudioCapability?
    /// Type of biometric hardware, if available.
    public let biometricType: BiometricType?
    /// How many cameras the device can capture from, when the shell counts them. Core offers a
    /// switch between cameras only when this says there is more than one; a shell that does not
    /// count leaves it out, and Core keeps offering the switch (private#772).
    public let cameraCount: Int?
    /// The shell can seal a secret behind the operating system's own user-presence check
    /// (biometric or device credential) and answers `Command::CreateUserPresenceSecret` /
    /// `RevealUserPresenceSecret` (#712). Off until a shell implements them.
    public let canSealUserPresence: Bool?
    /// Human-readable device model name reported by the platform, used as the default name when
    /// joining an existing identity from this device.
    public let deviceName: String?
    /// Device has an accelerometer (for Bump/Shake proximity).
    public let hasAccelerometer: Bool?
    /// Device supports biometric authentication.
    public let hasBiometrics: Bool?
    /// Device has Bluetooth Low Energy hardware.
    public let hasBle: Bool?
    /// Device has a camera (for QR code scanning).
    public let hasCamera: Bool?
    /// Device has internet connectivity (for relay/Link/Web modes).
    public let hasInternet: Bool?
    /// Device has NFC hardware (for NFC Active exchange).
    public let hasNFC: Bool?
    /// Device has a secure enclave / hardware security module.
    public let hasSecureEnclave: Bool?
    /// Device has a USB port capable of data transfer (for Cable exchange).
    public let hasUSBPort: Bool?
    /// Platform identifier.
    public let platform: Platform?

    public enum CodingKeys: String, CodingKey {
        case audio = "audio"
        case biometricType = "biometric_type"
        case cameraCount = "camera_count"
        case canSealUserPresence = "can_seal_user_presence"
        case deviceName = "device_name"
        case hasAccelerometer = "has_accelerometer"
        case hasBiometrics = "has_biometrics"
        case hasBle = "has_ble"
        case hasCamera = "has_camera"
        case hasInternet = "has_internet"
        case hasNFC = "has_nfc"
        case hasSecureEnclave = "has_secure_enclave"
        case hasUSBPort = "has_usb_port"
        case platform = "platform"
    }

    public init(audio: AudioCapability?, biometricType: BiometricType?, cameraCount: Int?, canSealUserPresence: Bool?, deviceName: String?, hasAccelerometer: Bool?, hasBiometrics: Bool?, hasBle: Bool?, hasCamera: Bool?, hasInternet: Bool?, hasNFC: Bool?, hasSecureEnclave: Bool?, hasUSBPort: Bool?, platform: Platform?) {
        self.audio = audio
        self.biometricType = biometricType
        self.cameraCount = cameraCount
        self.canSealUserPresence = canSealUserPresence
        self.deviceName = deviceName
        self.hasAccelerometer = hasAccelerometer
        self.hasBiometrics = hasBiometrics
        self.hasBle = hasBle
        self.hasCamera = hasCamera
        self.hasInternet = hasInternet
        self.hasNFC = hasNFC
        self.hasSecureEnclave = hasSecureEnclave
        self.hasUSBPort = hasUSBPort
        self.platform = platform
    }
}

// MARK: DeviceCapabilities convenience initializers and mutators

public extension DeviceCapabilities {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DeviceCapabilities.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        audio: AudioCapability?? = nil,
        biometricType: BiometricType?? = nil,
        cameraCount: Int?? = nil,
        canSealUserPresence: Bool?? = nil,
        deviceName: String?? = nil,
        hasAccelerometer: Bool?? = nil,
        hasBiometrics: Bool?? = nil,
        hasBle: Bool?? = nil,
        hasCamera: Bool?? = nil,
        hasInternet: Bool?? = nil,
        hasNFC: Bool?? = nil,
        hasSecureEnclave: Bool?? = nil,
        hasUSBPort: Bool?? = nil,
        platform: Platform?? = nil
    ) -> DeviceCapabilities {
        return DeviceCapabilities(
            audio: audio ?? self.audio,
            biometricType: biometricType ?? self.biometricType,
            cameraCount: cameraCount ?? self.cameraCount,
            canSealUserPresence: canSealUserPresence ?? self.canSealUserPresence,
            deviceName: deviceName ?? self.deviceName,
            hasAccelerometer: hasAccelerometer ?? self.hasAccelerometer,
            hasBiometrics: hasBiometrics ?? self.hasBiometrics,
            hasBle: hasBle ?? self.hasBle,
            hasCamera: hasCamera ?? self.hasCamera,
            hasInternet: hasInternet ?? self.hasInternet,
            hasNFC: hasNFC ?? self.hasNFC,
            hasSecureEnclave: hasSecureEnclave ?? self.hasSecureEnclave,
            hasUSBPort: hasUSBPort ?? self.hasUSBPort,
            platform: platform ?? self.platform
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Device audio capabilities (for ultrasonic proximity verification).
///
/// Represents device audio capabilities.
///
/// Device supports full ultrasonic audio (speaker + microphone)
///
/// Device can only emit ultrasonic audio (no microphone)
///
/// Device can only receive ultrasonic audio (no speaker)
///
/// Device does not support ultrasonic audio
public enum AudioCapability: String, Codable {
    case emitOnly = "EmitOnly"
    case full = "Full"
    case none = "None"
    case receiveOnly = "ReceiveOnly"
}

/// Fingerprint sensor (Touch ID, Android fingerprint).
///
/// Face recognition (Face ID, Android face unlock).
///
/// Iris scanner.
public enum BiometricType: String, Codable {
    case faceID = "FaceId"
    case fingerprint = "Fingerprint"
    case iris = "Iris"
}

/// Platform identifier.
///
/// Platform the app is running on.
public enum Platform: String, Codable {
    case android = "Android"
    case desktop = "Desktop"
    case ios = "Ios"
    case unknown = "Unknown"
    case web = "Web"
}

// MARK: - HardwareError
public struct HardwareError: Codable {
    public let error: String
    public let transport: String

    public enum CodingKeys: String, CodingKey {
        case error = "error"
        case transport = "transport"
    }

    public init(error: String, transport: String) {
        self.error = error
        self.transport = transport
    }
}

// MARK: HardwareError convenience initializers and mutators

public extension HardwareError {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(HardwareError.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        error: String? = nil,
        transport: String? = nil
    ) -> HardwareError {
        return HardwareError(
            error: error ?? self.error,
            transport: transport ?? self.transport
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - HardwareUnavailable
public struct HardwareUnavailable: Codable {
    public let transport: String

    public enum CodingKeys: String, CodingKey {
        case transport = "transport"
    }

    public init(transport: String) {
        self.transport = transport
    }
}

// MARK: HardwareUnavailable convenience initializers and mutators

public extension HardwareUnavailable {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(HardwareUnavailable.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        transport: String? = nil
    ) -> HardwareUnavailable {
        return HardwareUnavailable(
            transport: transport ?? self.transport
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ImageReceived
public struct ImageReceived: Codable {
    public let data: [Int]

    public enum CodingKeys: String, CodingKey {
        case data = "data"
    }

    public init(data: [Int]) {
        self.data = data
    }
}

// MARK: ImageReceived convenience initializers and mutators

public extension ImageReceived {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ImageReceived.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        data: [Int]? = nil
    ) -> ImageReceived {
        return ImageReceived(
            data: data ?? self.data
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ImpactDetected
public struct ImpactDetected: Codable {
    public let magnitudeMilliG: Int
    public let timestampMS: Int

    public enum CodingKeys: String, CodingKey {
        case magnitudeMilliG = "magnitude_milli_g"
        case timestampMS = "timestamp_ms"
    }

    public init(magnitudeMilliG: Int, timestampMS: Int) {
        self.magnitudeMilliG = magnitudeMilliG
        self.timestampMS = timestampMS
    }
}

// MARK: ImpactDetected convenience initializers and mutators

public extension ImpactDetected {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ImpactDetected.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        magnitudeMilliG: Int? = nil,
        timestampMS: Int? = nil
    ) -> ImpactDetected {
        return ImpactDetected(
            magnitudeMilliG: magnitudeMilliG ?? self.magnitudeMilliG,
            timestampMS: timestampMS ?? self.timestampMS
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - InputFocusEnded
public struct InputFocusEnded: Codable {
    public let bindingID: String
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case bindingID = "binding_id"
        case surfaceID = "surface_id"
    }

    public init(bindingID: String, surfaceID: String) {
        self.bindingID = bindingID
        self.surfaceID = surfaceID
    }
}

// MARK: InputFocusEnded convenience initializers and mutators

public extension InputFocusEnded {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(InputFocusEnded.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        bindingID: String? = nil,
        surfaceID: String? = nil
    ) -> InputFocusEnded {
        return InputFocusEnded(
            bindingID: bindingID ?? self.bindingID,
            surfaceID: surfaceID ?? self.surfaceID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - InputSubmitted
public struct InputSubmitted: Codable {
    public let bindingID: String
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case bindingID = "binding_id"
        case surfaceID = "surface_id"
    }

    public init(bindingID: String, surfaceID: String) {
        self.bindingID = bindingID
        self.surfaceID = surfaceID
    }
}

// MARK: InputSubmitted convenience initializers and mutators

public extension InputSubmitted {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(InputSubmitted.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        bindingID: String? = nil,
        surfaceID: String? = nil
    ) -> InputSubmitted {
        return InputSubmitted(
            bindingID: bindingID ?? self.bindingID,
            surfaceID: surfaceID ?? self.surfaceID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - LinkOpened
public struct LinkOpened: Codable {
    public let peerPublicKey: [Int]

    public enum CodingKeys: String, CodingKey {
        case peerPublicKey = "peer_public_key"
    }

    public init(peerPublicKey: [Int]) {
        self.peerPublicKey = peerPublicKey
    }
}

// MARK: LinkOpened convenience initializers and mutators

public extension LinkOpened {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(LinkOpened.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        peerPublicKey: [Int]? = nil
    ) -> LinkOpened {
        return LinkOpened(
            peerPublicKey: peerPublicKey ?? self.peerPublicKey
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - LocalNetworkAddressChanged
public struct LocalNetworkAddressChanged: Codable {
    public let address: String?

    public enum CodingKeys: String, CodingKey {
        case address = "address"
    }

    public init(address: String?) {
        self.address = address
    }
}

// MARK: LocalNetworkAddressChanged convenience initializers and mutators

public extension LocalNetworkAddressChanged {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(LocalNetworkAddressChanged.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        address: String?? = nil
    ) -> LocalNetworkAddressChanged {
        return LocalNetworkAddressChanged(
            address: address ?? self.address
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - LocationResult
public struct LocationResult: Codable {
    public let accuracyMeters: Double?
    public let latitude: Double
    public let longitude: Double

    public enum CodingKeys: String, CodingKey {
        case accuracyMeters = "accuracy_meters"
        case latitude = "latitude"
        case longitude = "longitude"
    }

    public init(accuracyMeters: Double?, latitude: Double, longitude: Double) {
        self.accuracyMeters = accuracyMeters
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: LocationResult convenience initializers and mutators

public extension LocationResult {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(LocationResult.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        accuracyMeters: Double?? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> LocationResult {
        return LocationResult(
            accuracyMeters: accuracyMeters ?? self.accuracyMeters,
            latitude: latitude ?? self.latitude,
            longitude: longitude ?? self.longitude
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - NetworkCostChanged
public struct NetworkCostChanged: Codable {
    public let cost: NetworkCost

    public enum CodingKeys: String, CodingKey {
        case cost = "cost"
    }

    public init(cost: NetworkCost) {
        self.cost = cost
    }
}

// MARK: NetworkCostChanged convenience initializers and mutators

public extension NetworkCostChanged {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NetworkCostChanged.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        cost: NetworkCost? = nil
    ) -> NetworkCostChanged {
        return NetworkCostChanged(
            cost: cost ?? self.cost
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// What the current network costs, as the shell reports it.
public enum NetworkCost: String, Codable {
    case metered = "metered"
    case unknown = "unknown"
    case unmetered = "unmetered"
}

// MARK: - NFCApduReceived
public struct NFCApduReceived: Codable {
    public let bytes: [Int]

    public enum CodingKeys: String, CodingKey {
        case bytes = "bytes"
    }

    public init(bytes: [Int]) {
        self.bytes = bytes
    }
}

// MARK: NFCApduReceived convenience initializers and mutators

public extension NFCApduReceived {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NFCApduReceived.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        bytes: [Int]? = nil
    ) -> NFCApduReceived {
        return NFCApduReceived(
            bytes: bytes ?? self.bytes
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - NFCDataReceived
public struct NFCDataReceived: Codable {
    public let data: [Int]

    public enum CodingKeys: String, CodingKey {
        case data = "data"
    }

    public init(data: [Int]) {
        self.data = data
    }
}

// MARK: NFCDataReceived convenience initializers and mutators

public extension NFCDataReceived {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NFCDataReceived.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        data: [Int]? = nil
    ) -> NFCDataReceived {
        return NFCDataReceived(
            data: data ?? self.data
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - NFCFailed
public struct NFCFailed: Codable {
    public let reason: String

    public enum CodingKeys: String, CodingKey {
        case reason = "reason"
    }

    public init(reason: String) {
        self.reason = reason
    }
}

// MARK: NFCFailed convenience initializers and mutators

public extension NFCFailed {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NFCFailed.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        reason: String? = nil
    ) -> NFCFailed {
        return NFCFailed(
            reason: reason ?? self.reason
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - OverlayDismissed
public struct OverlayDismissed: Codable {
    public let kind: OverlayKind
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case kind = "kind"
        case surfaceID = "surface_id"
    }

    public init(kind: OverlayKind, surfaceID: String) {
        self.kind = kind
        self.surfaceID = surfaceID
    }
}

// MARK: OverlayDismissed convenience initializers and mutators

public extension OverlayDismissed {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(OverlayDismissed.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        kind: OverlayKind? = nil,
        surfaceID: String? = nil
    ) -> OverlayDismissed {
        return OverlayDismissed(
            kind: kind ?? self.kind,
            surfaceID: surfaceID ?? self.surfaceID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Text about the surface, no actions beyond dismissing it.
public enum OverlayKind: String, Codable {
    case actionMenu = "action_menu"
    case information = "information"
    case navigation = "navigation"
}

// MARK: - PermissionDenied
public struct PermissionDenied: Codable {
    public let transport: String

    public enum CodingKeys: String, CodingKey {
        case transport = "transport"
    }

    public init(transport: String) {
        self.transport = transport
    }
}

// MARK: PermissionDenied convenience initializers and mutators

public extension PermissionDenied {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PermissionDenied.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        transport: String? = nil
    ) -> PermissionDenied {
        return PermissionDenied(
            transport: transport ?? self.transport
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PermissionGranted
public struct PermissionGranted: Codable {
    public let transport: String

    public enum CodingKeys: String, CodingKey {
        case transport = "transport"
    }

    public init(transport: String) {
        self.transport = transport
    }
}

// MARK: PermissionGranted convenience initializers and mutators

public extension PermissionGranted {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PermissionGranted.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        transport: String? = nil
    ) -> PermissionGranted {
        return PermissionGranted(
            transport: transport ?? self.transport
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PermissionRequired
public struct PermissionRequired: Codable {
    public let transport: String

    public enum CodingKeys: String, CodingKey {
        case transport = "transport"
    }

    public init(transport: String) {
        self.transport = transport
    }
}

// MARK: PermissionRequired convenience initializers and mutators

public extension PermissionRequired {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PermissionRequired.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        transport: String? = nil
    ) -> PermissionRequired {
        return PermissionRequired(
            transport: transport ?? self.transport
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PresentationEnvironmentChanged
public struct PresentationEnvironmentChanged: Codable {
    public let availableHeight: Int
    public let availableWidth: Int
    /// `None` from a shell that does not report it; Core then paints the dark default
    /// (vauchi/private#814).
    public let colorScheme: ColorScheme?
    public let inputModes: [InputMode]
    public let motion: MotionPreference
    /// The shell keeps `ContextBar::pinned` in view. False from a shell that does not report it;
    /// Core then leaves those actions in the surface's content (vauchi/private#1304).
    public let pinnedActions: Bool?

    public enum CodingKeys: String, CodingKey {
        case availableHeight = "available_height"
        case availableWidth = "available_width"
        case colorScheme = "color_scheme"
        case inputModes = "input_modes"
        case motion = "motion"
        case pinnedActions = "pinned_actions"
    }

    public init(availableHeight: Int, availableWidth: Int, colorScheme: ColorScheme?, inputModes: [InputMode], motion: MotionPreference, pinnedActions: Bool?) {
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
        self.colorScheme = colorScheme
        self.inputModes = inputModes
        self.motion = motion
        self.pinnedActions = pinnedActions
    }
}

// MARK: PresentationEnvironmentChanged convenience initializers and mutators

public extension PresentationEnvironmentChanged {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentationEnvironmentChanged.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        availableHeight: Int? = nil,
        availableWidth: Int? = nil,
        colorScheme: ColorScheme?? = nil,
        inputModes: [InputMode]? = nil,
        motion: MotionPreference? = nil,
        pinnedActions: Bool?? = nil
    ) -> PresentationEnvironmentChanged {
        return PresentationEnvironmentChanged(
            availableHeight: availableHeight ?? self.availableHeight,
            availableWidth: availableWidth ?? self.availableWidth,
            colorScheme: colorScheme ?? self.colorScheme,
            inputModes: inputModes ?? self.inputModes,
            motion: motion ?? self.motion,
            pinnedActions: pinnedActions ?? self.pinnedActions
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// The operating system's light or dark appearance setting.
public enum ColorScheme: String, Codable {
    case dark = "dark"
    case light = "light"
}

public enum InputMode: String, Codable {
    case keyboard = "keyboard"
    case pointer = "pointer"
    case touch = "touch"
}

public enum MotionPreference: String, Codable {
    case full = "full"
    case reduced = "reduced"
}

// MARK: - QrScanProgress
public struct QrScanProgress: Codable {
    public let confidence: Int?
    public let detected: Bool
    public let frameSkipped: Bool?

    public enum CodingKeys: String, CodingKey {
        case confidence = "confidence"
        case detected = "detected"
        case frameSkipped = "frame_skipped"
    }

    public init(confidence: Int?, detected: Bool, frameSkipped: Bool?) {
        self.confidence = confidence
        self.detected = detected
        self.frameSkipped = frameSkipped
    }
}

// MARK: QrScanProgress convenience initializers and mutators

public extension QrScanProgress {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(QrScanProgress.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        confidence: Int?? = nil,
        detected: Bool? = nil,
        frameSkipped: Bool?? = nil
    ) -> QrScanProgress {
        return QrScanProgress(
            confidence: confidence ?? self.confidence,
            detected: detected ?? self.detected,
            frameSkipped: frameSkipped ?? self.frameSkipped
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - QrScanned
public struct QrScanned: Codable {
    public let data: String

    public enum CodingKeys: String, CodingKey {
        case data = "data"
    }

    public init(data: String) {
        self.data = data
    }
}

// MARK: QrScanned convenience initializers and mutators

public extension QrScanned {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(QrScanned.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        data: String? = nil
    ) -> QrScanned {
        return QrScanned(
            data: data ?? self.data
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - RefreshRequested
public struct RefreshRequested: Codable {
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
    }

    public init(surfaceID: String) {
        self.surfaceID = surfaceID
    }
}

// MARK: RefreshRequested convenience initializers and mutators

public extension RefreshRequested {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RefreshRequested.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        surfaceID: String? = nil
    ) -> RefreshRequested {
        return RefreshRequested(
            surfaceID: surfaceID ?? self.surfaceID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - RelayEscrowBlobReceived
public struct RelayEscrowBlobReceived: Codable {
    public let blob: [Int]
    public let gateHash: [Int]

    public enum CodingKeys: String, CodingKey {
        case blob = "blob"
        case gateHash = "gate_hash"
    }

    public init(blob: [Int], gateHash: [Int]) {
        self.blob = blob
        self.gateHash = gateHash
    }
}

// MARK: RelayEscrowBlobReceived convenience initializers and mutators

public extension RelayEscrowBlobReceived {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RelayEscrowBlobReceived.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        blob: [Int]? = nil,
        gateHash: [Int]? = nil
    ) -> RelayEscrowBlobReceived {
        return RelayEscrowBlobReceived(
            blob: blob ?? self.blob,
            gateHash: gateHash ?? self.gateHash
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - RelayEscrowFailed
public struct RelayEscrowFailed: Codable {
    public let gateHash: [Int]
    public let reason: String

    public enum CodingKeys: String, CodingKey {
        case gateHash = "gate_hash"
        case reason = "reason"
    }

    public init(gateHash: [Int], reason: String) {
        self.gateHash = gateHash
        self.reason = reason
    }
}

// MARK: RelayEscrowFailed convenience initializers and mutators

public extension RelayEscrowFailed {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RelayEscrowFailed.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        gateHash: [Int]? = nil,
        reason: String? = nil
    ) -> RelayEscrowFailed {
        return RelayEscrowFailed(
            gateHash: gateHash ?? self.gateHash,
            reason: reason ?? self.reason
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - RelayEscrowReady
public struct RelayEscrowReady: Codable {
    public let gateHash: [Int]

    public enum CodingKeys: String, CodingKey {
        case gateHash = "gate_hash"
    }

    public init(gateHash: [Int]) {
        self.gateHash = gateHash
    }
}

// MARK: RelayEscrowReady convenience initializers and mutators

public extension RelayEscrowReady {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RelayEscrowReady.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        gateHash: [Int]? = nil
    ) -> RelayEscrowReady {
        return RelayEscrowReady(
            gateHash: gateHash ?? self.gateHash
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - StatusItemAvailabilityChanged
public struct StatusItemAvailabilityChanged: Codable {
    public let available: Bool

    public enum CodingKeys: String, CodingKey {
        case available = "available"
    }

    public init(available: Bool) {
        self.available = available
    }
}

// MARK: StatusItemAvailabilityChanged convenience initializers and mutators

public extension StatusItemAvailabilityChanged {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(StatusItemAvailabilityChanged.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        available: Bool? = nil
    ) -> StatusItemAvailabilityChanged {
        return StatusItemAvailabilityChanged(
            available: available ?? self.available
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - SurfaceActivated
public struct SurfaceActivated: Codable {
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
    }

    public init(surfaceID: String) {
        self.surfaceID = surfaceID
    }
}

// MARK: SurfaceActivated convenience initializers and mutators

public extension SurfaceActivated {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SurfaceActivated.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        surfaceID: String? = nil
    ) -> SurfaceActivated {
        return SurfaceActivated(
            surfaceID: surfaceID ?? self.surfaceID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - UserPresenceSecretCreated
public struct UserPresenceSecretCreated: Codable {
    public let secret: [Int]

    public enum CodingKeys: String, CodingKey {
        case secret = "secret"
    }

    public init(secret: [Int]) {
        self.secret = secret
    }
}

// MARK: UserPresenceSecretCreated convenience initializers and mutators

public extension UserPresenceSecretCreated {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(UserPresenceSecretCreated.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        secret: [Int]? = nil
    ) -> UserPresenceSecretCreated {
        return UserPresenceSecretCreated(
            secret: secret ?? self.secret
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - UserPresenceSecretRevealed
public struct UserPresenceSecretRevealed: Codable {
    public let secret: [Int]

    public enum CodingKeys: String, CodingKey {
        case secret = "secret"
    }

    public init(secret: [Int]) {
        self.secret = secret
    }
}

// MARK: UserPresenceSecretRevealed convenience initializers and mutators

public extension UserPresenceSecretRevealed {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(UserPresenceSecretRevealed.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        secret: [Int]? = nil
    ) -> UserPresenceSecretRevealed {
        return UserPresenceSecretRevealed(
            secret: secret ?? self.secret
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ValueChanged
public struct ValueChanged: Codable {
    public let bindingID: String
    public let surfaceID: String
    public let value: InputValue

    public enum CodingKeys: String, CodingKey {
        case bindingID = "binding_id"
        case surfaceID = "surface_id"
        case value = "value"
    }

    public init(bindingID: String, surfaceID: String, value: InputValue) {
        self.bindingID = bindingID
        self.surfaceID = surfaceID
        self.value = value
    }
}

// MARK: ValueChanged convenience initializers and mutators

public extension ValueChanged {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ValueChanged.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        bindingID: String? = nil,
        surfaceID: String? = nil,
        value: InputValue? = nil
    ) -> ValueChanged {
        return ValueChanged(
            bindingID: bindingID ?? self.bindingID,
            surfaceID: surfaceID ?? self.surfaceID,
            value: value ?? self.value
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - InputValue
public struct InputValue: Codable {
    public let text: String?
    public let boolean: Bool?
    public let choice: String?
    public let number: Double?

    public enum CodingKeys: String, CodingKey {
        case text = "text"
        case boolean = "boolean"
        case choice = "choice"
        case number = "number"
    }

    public init(text: String?, boolean: Bool?, choice: String?, number: Double?) {
        self.text = text
        self.boolean = boolean
        self.choice = choice
        self.number = number
    }
}

// MARK: InputValue convenience initializers and mutators

public extension InputValue {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(InputValue.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        text: String?? = nil,
        boolean: Bool?? = nil,
        choice: String?? = nil,
        number: Double?? = nil
    ) -> InputValue {
        return InputValue(
            text: text ?? self.text,
            boolean: boolean ?? self.boolean,
            choice: choice ?? self.choice,
            number: number ?? self.number
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// User shared the link via share sheet.
///
/// The user cancelled the image picker / camera without selecting.
///
/// The user dismissed the file picker without selecting a file.
///
/// Platform biometric authentication (LAContext on iOS, BiometricPrompt on Android)
/// succeeded. Core consults its duress-PIN state to decide the next step; the result rides
/// back to the frontend as `ActionResult::BiometricUnlockOutcome`.
///
/// The application moved to the background or lost its active session.
///
/// Core reported that background state changed outside an interaction.
///
/// Shells receive only a parameter-free wake signal, then return this canonical event. Core
/// owns cache invalidation and emits the complete replacement command batch; no screen
/// identifiers cross the boundary.
///
/// The user dismissed the operating system's user-presence check.
///
/// The sealed secret is gone, answering [`Command::RevealUserPresenceSecret`]: the enrolment
/// changed or the keystore lost the item, unlike [`Event::HardwareUnavailable`], which says
/// this device cannot run the check at all (#778).
///
/// A timer armed by [`Command::ScheduleWakeup`] fired. May also be sent once at startup to
/// bootstrap scheduling. Core runs due work and returns prepared effects, including
/// notifications and the next timer, through the canonical command batch. Callers must
/// execute [`Command::PostNotification`] before adopting this event instead of the legacy
/// wakeup API; notification handoff is at most once.
public enum EventEnum: String, Codable {
    case appBackgrounded = "AppBackgrounded"
    case biometricUnlockSucceeded = "BiometricUnlockSucceeded"
    case filePickCancelledByUser = "FilePickCancelledByUser"
    case imagePickCancelled = "ImagePickCancelled"
    case linkShared = "LinkShared"
    case presentationInvalidated = "PresentationInvalidated"
    case userPresenceCheckCancelled = "UserPresenceCheckCancelled"
    case userPresenceSecretMissing = "UserPresenceSecretMissing"
    case wakeupFired = "WakeupFired"
}

// MARK: - Helper functions for creating encoders and decoders

func newJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        decoder.dateDecodingStrategy = .iso8601
    }
    return decoder
}

func newJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    if #available(iOS 10.0, OSX 10.12, tvOS 10.0, watchOS 3.0, *) {
        encoder.dateEncodingStrategy = .iso8601
    }
    return encoder
}
