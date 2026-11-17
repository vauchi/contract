// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let command = try Command(json)

import Foundation

/// A command from core to the frontend requesting a hardware action.
///
/// Frontends match on these and dispatch to platform-specific APIs (camera, BLE stack, NFC
/// reader, audio subsystem). Commands that the platform cannot fulfil should be answered
/// with [`Event::HardwareUnavailable`].
public enum Command: Codable {
    case commandClass(CommandClass)
    case enumeration(CommandEnum)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(CommandEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(CommandClass.self) {
            self = .commandClass(x)
            return
        }
        throw DecodingError.typeMismatch(Command.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Command"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .commandClass(let x):
            try container.encode(x)
        case .enumeration(let x):
            try container.encode(x)
        }
    }
}

/// Display a QR code containing `data`.
///
/// Core-computed wakeup schedule (ADR-030/031 command + ADR-044 Am2a: generic timer *data*,
/// not a per-feature flag). Core stays the single authority on *when* the app-level
/// heartbeat is due; the humble shell translates this into its platform wakeup — a desktop
/// in-process interval/thread, iOS `BGAppRefreshTask`, Android `WorkManager` — and, when it
/// fires, reports [`Event::WakeupFired`], which runs due work and emits the *next*
/// `ScheduleWakeup`. All fields are relative seconds from now (the OS APIs take intervals,
/// and it frees the shell from reading core's clock). Every interval is a *hint*: the OS may
/// fire late, coalesce, or skip — wakeup work is elapsed-based and idempotent, so a missed
/// or doubled wake is safe.
///
/// Start advertising the vauchi BLE service with the given payload.
///
/// Start scanning for vauchi BLE peripherals.
///
/// Connect to a discovered BLE device.
///
/// Write data to a BLE characteristic on the link to `device_id`.
///
/// `device_id` addresses the target link so shells holding more than one live link (glare)
/// route the write to the right peer instead of an implicit "current" connection
/// (`_private/docs/designs/2026-07-22-role-tiebreak-and-glare-design.md`).
///
/// Read data from a BLE characteristic on the link to `device_id`.
///
/// Disconnect one specific BLE link, addressed by peer and direction.
///
/// Targeted (not "disconnect everything") so glare resolution can drop exactly the losing
/// link while the surviving link keeps carrying the handshake.
///
/// Activate the NFC interface and prepare to exchange `payload`.
///
/// `apdus` is the same payload already framed by core (`exchange::nfc_apdu::frame_command`:
/// SELECT, then the EXCHANGE chain). A reader shell transmits each frame verbatim and
/// reports every response as [`Event::NfcApduReceived`]; a responder gets an empty list
/// because it only listens. `payload` stays for shells that still frame on their own.
///
/// Send a continuation APDU on the already-active NFC session. Used by the multi-phase
/// handshake after the initial `NfcActivate`: the frontend keeps the tag connection alive
/// and transmits `data` opaquely, then surfaces the peer's response as
/// `Event::NfcDataReceived`.
///
/// `apdus` carries the frames core already built: the EXCHANGE chain on the reader side, the
/// complete response APDU (`data || SW`) on the HCE side. Shells that forward raw bytes use
/// it and ignore `data`.
///
/// Emit ultrasonic PCM samples encoding a challenge.
///
/// Core has already FSK-encoded the challenge bytes; the frontend just plays the samples
/// through the device speaker. Mono float PCM at `sample_rate`.
///
/// Listen for an ultrasonic response within `timeout_ms`.
///
/// `sample_rate` is the suggested capture rate; if the device's preferred rate differs, the
/// frontend reports its actual rate in [`Event::AudioSamplesRecorded`].
///
/// Deposit encrypted card into relay escrow gate.
///
/// Check relay escrow gate readiness (poll until ready).
///
/// Frontends should poll at `suggested_interval_ms` with exponential backoff (cap at 5 min).
/// Report `RelayEscrowReady` when gate has ≥2 deposits, or `RelayEscrowFailed` on
/// error/timeout.
///
/// Retrieve blob from relay escrow gate.
///
/// Show system share sheet with a URL.
///
/// Swap opaque bytes with the peer over a direct transport (USB cable / local TCP). The
/// wired exchange issues this command once per leg (key payload, then encrypted card); the
/// bytes carry no leg discriminator and the shell must not need one (ADR-066).
///
/// The frontend should: 1. Send `payload` to the peer over a fresh TCP connection 2. Receive
/// the peer's bytes from the same connection 3. Report them via
/// [`Event::DirectPayloadReceived`]
///
/// The `is_initiator` flag determines send/recv ordering to avoid deadlock (initiator sends
/// first, responder receives first).
///
/// `endpoint` is where and how long to look for the peer; the shell executes it and decides
/// none of it (#764).
///
/// Switch the active camera between front- and rear-facing.
///
/// Used by the multi-stage face-to-face exchange screen so the user can flip the scanner
/// orientation without the frontend owning the preference. `use_front == true` selects the
/// front camera.
///
/// Request the frontend to open a file picker.
///
/// `accepted_mime_types` is advisory — frontends may default to a coarser superset on
/// platforms where the OS picker doesn't filter by MIME (e.g., older Android versions).
/// `accepted_extensions` carries the same filter as lowercase, dot-less extensions for
/// pickers that filter by extension or UTType instead (WinUI, iOS); an empty list means "any
/// file". Both lists are derived from `purpose` (see
/// [`FilePickPurpose::accepted_extensions`]), so shells never need a MIME table (ADR-066).
/// `purpose` lets the frontend label the picker dialog without hardcoding strings; label
/// text comes from core's locale store via `t(key)`.
///
/// Frontend should return [`Event::FilePickedFromUser`] with the selected file's bytes, or
/// [`Event::FilePickCancelledByUser`] if the user dismisses the picker.
///
/// Distinct from [`Command::ImagePickFromFile`]: that variant returns
/// [`Event::ImageReceived`] which is shaped for avatar normalization. File picking returns
/// raw bytes plus filename for arbitrary payloads (vCard, encrypted backup blob, future key
/// bundles, etc.).
///
/// Set the device screen brightness, optionally restoring the platform default when `level`
/// is `None`.
///
/// Used by screens that need a specific brightness for their hardware to function (e.g., the
/// multi-stage face-to-face exchange uses 65% brightness so the front camera is not
/// over-exposed when scanning a peer's QR). The frontend is responsible for snapshotting the
/// prior value on the *first* `Some(level)` after a `None` (or app start) so the subsequent
/// `None` correctly restores it.
///
/// Frontends that have no programmatic brightness control (e.g., desktop, where the OS owns
/// it) answer with [`Event::HardwareUnavailable { transport: "screen_brightness" }`] — core
/// should treat that as "request honoured at platform default" and not retry.
///
/// Per `2026-05-01-screen-id-metadata-in-core` cousin
/// `2026-05-04-exchange-command-screen-presentation`, ADR-031 §Hardware. Phase 1 of the
/// FaceToFaceExchangeView retirement.
///
/// Disable or re-enable the platform's idle / auto-lock timer.
///
/// `disabled = true` keeps the screen awake (used by the multi-stage exchange so a
/// longer-than-30s handshake doesn't trigger the device's auto-lock). `disabled = false`
/// restores the platform default on screen exit. Idempotent — frontends MAY ignore a
/// redundant set/clear.
///
/// Frontends that have no programmatic idle-timer control answer with
/// [`Event::HardwareUnavailable { transport: "idle_timer" }`].
///
/// Phase 1 of the FaceToFaceExchangeView retirement (companion to
/// [`Command::SetScreenBrightness`]).
///
/// Lock or unlock the device's screen orientation.
///
/// `Some(orientation)` pins the screen to the requested orientation (e.g., `Portrait` so the
/// multi-stage face-to-face exchange QR / camera layout stays stable while the user is
/// moving the device); `None` restores the platform default (typically follows the device's
/// physical rotation).
///
/// Frontends that don't programmatically own orientation (`linux-gtk`, `linux-qt`,
/// `windows`, desktop `macos` — windowed apps don't lock device rotation) answer with
/// [`Event::HardwareUnavailable { transport: "orientation_lock" }`].
///
/// Phase 2c of `2026-05-04-exchange-command-screen-presentation` — retires the orientation
/// `DisposableEffect` in
/// `android/app/src/main/kotlin/app/vauchi/ui/FaceToFaceExchangeScreen.kt`.
///
/// Retired card-leg command. Core never emits it any more: the encrypted card rides
/// [`Command::DirectSend`] like the key payload. The variant stays for one release so shells
/// built against the split contract still compile; remove it (and
/// `Event::DirectCardReceived`) in the release after every shell handles the card leg as a
/// plain `DirectSend`.
///
/// Request the device's current location (ADR-051 contact annotations): used at an in-person
/// exchange to record *where we met*. The frontend resolves permission and replies with
/// [`Event::LocationResult`], or [`Event::PermissionDenied { transport: "location" }`] if
/// the user declines, or [`Event::HardwareUnavailable`] if there is no location provider.
/// `timeout_ms` bounds how long the frontend waits for a fix.
///
/// Render the exchange-success ceremony: a celebratory haptic + sound + animation
/// (`designs/2026-06-06-exchange-ceremony-design.md`). The tokens are closed intent enums
/// looked up against a static per-platform table (Wire-Humble kind rule) — core never sends
/// assets or frequencies. Frontends skip any axis they can't render; the others still play.
/// Emitted exactly once per validated exchange success, never on failure, and byte-identical
/// regardless of auth mode (ADR-032 duress parity).
///
/// Atomically replace the contextual controls associated with a surface.
///
/// Atomically replace the persistent navigation surface (bottom bar on phone, sidebar on
/// desktop) for a surface, including which destination is currently selected. Emitted
/// alongside [`Command::SetContextBar`] so shells that render a persistent bar need not open
/// the navigation overlay to discover destinations; a shell that ignores this command keeps
/// working off the overlay. Empty `navigation.items` (e.g. a locked app) means the bar has
/// nothing to show.
///
/// Present navigation or secondary actions for a surface.
///
/// Dismiss an overlay Core previously presented for a surface.
///
/// Core emits this when the affordance that opened an overlay is activated again, so the
/// context-bar buttons toggle. A shell that has already dismissed the overlay natively — and
/// said so with [`Event::OverlayDismissed`] — treats this as a no-op; dismissal is
/// idempotent so the two paths cannot race into an inconsistent view.
///
/// Apply Core's structural composition for the current window.
///
/// Atomically replace one named surface with fully prepared, domain-free presentation
/// primitives.
///
/// Present a prepared native alert.
///
/// Present transient informational feedback.
///
/// Open a prepared URL using the platform default handler.
///
/// Offer prepared bytes through the platform save/share mechanism.
///
/// Write a Core-prepared machine-readable document to the shell's primary output, unread.
///
/// End a one-shot invocation with a generic outcome.
///
/// Post a fully prepared operating-system notification.
///
/// Delete the secret the shell handed over under `handle`: Core now holds what it protected
/// in secure storage (vauchi/private#580). The handle is the shell's own opaque name, echoed
/// back unchanged.
///
/// Make 32 random bytes and seal them in the platform keystore so that reading them back
/// needs the operating system's own user-presence check, of the kind `binding` names, every
/// time; run that check now, with `prompt` as its reason, and answer
/// [`Event::UserPresenceSecretCreated`]. A shell that cannot answers
/// [`Event::HardwareUnavailable`] (#712, #778).
///
/// Run the operating system's user-presence check with `prompt` as its reason, unseal the
/// secret from [`Command::CreateUserPresenceSecret`] and answer
/// [`Event::UserPresenceSecretRevealed`], or [`Event::UserPresenceSecretMissing`] when the
/// sealed item is gone (#712, #778).
///
/// Keep `state` in the platform's per-device app storage, outside Core's storage, in place
/// of what was kept before; hand it back unchanged as `restorable_state` in every
/// render-context push, before storage opens too. Only Core reads it (vauchi/private#814).
///
/// Replace Core's native menu contributions. Sent only after the shell reports
/// application-menu availability. Native Quit remains shell-owned.
///
/// Show, replace or (`item: None`) remove the native status item. Sent only after the shell
/// reports status-item availability.
///
/// A bounded operation for executors advertising correlated file results. Echo `request_id`
/// unchanged in one `FilePickCompleted` event.
///
/// Dismiss the picker and discard work for this opaque operation id.
///
/// Ask the person for the OS permission `transport` needs (ADR-077): the hardware shell
/// reported [`Event::PermissionRequired`], and a prompt is display work. Answer
/// [`Event::PermissionGranted`] or [`Event::PermissionDenied`].
///
/// Show the hardware shell's live camera preview for `preview_id` in the camera area of the
/// current surface (ADR-077).
///
/// Start the camera for `purpose`, previewing into the display shell's
/// [`Command::CameraViewport`] with the same `preview_id`.
///
/// Stop the capture `preview_id` and release the camera.
// MARK: - CommandClass
public struct CommandClass: Codable {
    public let qrDisplay: QrDisplay?
    public let scheduleWakeup: ScheduleWakeup?
    public let bleStartAdvertising: BleStartAdvertising?
    public let bleStartScanning: BleStartScanning?
    public let bleConnect: BleConnect?
    public let bleWriteCharacteristic: BleWriteCharacteristic?
    public let bleReadCharacteristic: BleReadCharacteristic?
    public let bleDisconnect: BleDisconnect?
    public let nfcActivate: NFCActivate?
    public let nfcSendApdu: NFCSendApdu?
    public let audioEmitChallenge: AudioEmitChallenge?
    public let audioListenForResponse: AudioListenForResponse?
    public let relayEscrowDeposit: RelayEscrowDeposit?
    public let relayEscrowCheck: RelayEscrowCheck?
    public let relayEscrowRetrieve: RelayEscrowRetrieve?
    public let showShareSheet: ShowShareSheet?
    public let directSend: DirectSend?
    public let switchCamera: SwitchCamera?
    public let filePickFromUser: FilePickFromUser?
    public let setScreenBrightness: SetScreenBrightness?
    public let setIdleTimerDisabled: SetIdleTimerDisabled?
    public let setOrientationLock: SetOrientationLock?
    public let directSendCard: DirectSendCard?
    public let locationRequest: LocationRequest?
    public let celebrate: Celebrate?
    public let setContextBar: SetContextBar?
    public let setNavigation: SetNavigation?
    public let presentOverlay: PresentOverlay?
    public let dismissOverlay: DismissOverlay?
    public let setPresentationProfile: SetPresentationProfile?
    public let replaceSurface: ReplaceSurface?
    public let presentAlert: PresentAlert?
    public let showToast: ShowToast?
    public let openExternalURL: OpenExternalURL?
    public let exportFile: ExportFile?
    public let emitDocument: EmitDocument?
    public let finishInvocation: FinishInvocation?
    public let postNotification: PostNotification?
    public let forgetStoredSecret: ForgetStoredSecret?
    public let createUserPresenceSecret: CreateUserPresenceSecret?
    public let revealUserPresenceSecret: RevealUserPresenceSecret?
    public let saveRestorableState: SaveRestorableState?
    public let setApplicationMenu: SetApplicationMenu?
    public let setStatusItem: SetStatusItem?
    public let pickFile: PickFile?
    public let cancelFilePick: CancelFilePick?
    public let requestPermission: RequestPermission?
    public let cameraViewport: CameraViewport?
    public let cameraCapture: CameraCapture?
    public let cameraStop: CameraStop?

    public enum CodingKeys: String, CodingKey {
        case qrDisplay = "QrDisplay"
        case scheduleWakeup = "ScheduleWakeup"
        case bleStartAdvertising = "BleStartAdvertising"
        case bleStartScanning = "BleStartScanning"
        case bleConnect = "BleConnect"
        case bleWriteCharacteristic = "BleWriteCharacteristic"
        case bleReadCharacteristic = "BleReadCharacteristic"
        case bleDisconnect = "BleDisconnect"
        case nfcActivate = "NfcActivate"
        case nfcSendApdu = "NfcSendApdu"
        case audioEmitChallenge = "AudioEmitChallenge"
        case audioListenForResponse = "AudioListenForResponse"
        case relayEscrowDeposit = "RelayEscrowDeposit"
        case relayEscrowCheck = "RelayEscrowCheck"
        case relayEscrowRetrieve = "RelayEscrowRetrieve"
        case showShareSheet = "ShowShareSheet"
        case directSend = "DirectSend"
        case switchCamera = "SwitchCamera"
        case filePickFromUser = "FilePickFromUser"
        case setScreenBrightness = "SetScreenBrightness"
        case setIdleTimerDisabled = "SetIdleTimerDisabled"
        case setOrientationLock = "SetOrientationLock"
        case directSendCard = "DirectSendCard"
        case locationRequest = "LocationRequest"
        case celebrate = "Celebrate"
        case setContextBar = "SetContextBar"
        case setNavigation = "SetNavigation"
        case presentOverlay = "PresentOverlay"
        case dismissOverlay = "DismissOverlay"
        case setPresentationProfile = "SetPresentationProfile"
        case replaceSurface = "ReplaceSurface"
        case presentAlert = "PresentAlert"
        case showToast = "ShowToast"
        case openExternalURL = "OpenExternalUrl"
        case exportFile = "ExportFile"
        case emitDocument = "EmitDocument"
        case finishInvocation = "FinishInvocation"
        case postNotification = "PostNotification"
        case forgetStoredSecret = "ForgetStoredSecret"
        case createUserPresenceSecret = "CreateUserPresenceSecret"
        case revealUserPresenceSecret = "RevealUserPresenceSecret"
        case saveRestorableState = "SaveRestorableState"
        case setApplicationMenu = "SetApplicationMenu"
        case setStatusItem = "SetStatusItem"
        case pickFile = "PickFile"
        case cancelFilePick = "CancelFilePick"
        case requestPermission = "RequestPermission"
        case cameraViewport = "CameraViewport"
        case cameraCapture = "CameraCapture"
        case cameraStop = "CameraStop"
    }

    public init(qrDisplay: QrDisplay?, scheduleWakeup: ScheduleWakeup?, bleStartAdvertising: BleStartAdvertising?, bleStartScanning: BleStartScanning?, bleConnect: BleConnect?, bleWriteCharacteristic: BleWriteCharacteristic?, bleReadCharacteristic: BleReadCharacteristic?, bleDisconnect: BleDisconnect?, nfcActivate: NFCActivate?, nfcSendApdu: NFCSendApdu?, audioEmitChallenge: AudioEmitChallenge?, audioListenForResponse: AudioListenForResponse?, relayEscrowDeposit: RelayEscrowDeposit?, relayEscrowCheck: RelayEscrowCheck?, relayEscrowRetrieve: RelayEscrowRetrieve?, showShareSheet: ShowShareSheet?, directSend: DirectSend?, switchCamera: SwitchCamera?, filePickFromUser: FilePickFromUser?, setScreenBrightness: SetScreenBrightness?, setIdleTimerDisabled: SetIdleTimerDisabled?, setOrientationLock: SetOrientationLock?, directSendCard: DirectSendCard?, locationRequest: LocationRequest?, celebrate: Celebrate?, setContextBar: SetContextBar?, setNavigation: SetNavigation?, presentOverlay: PresentOverlay?, dismissOverlay: DismissOverlay?, setPresentationProfile: SetPresentationProfile?, replaceSurface: ReplaceSurface?, presentAlert: PresentAlert?, showToast: ShowToast?, openExternalURL: OpenExternalURL?, exportFile: ExportFile?, emitDocument: EmitDocument?, finishInvocation: FinishInvocation?, postNotification: PostNotification?, forgetStoredSecret: ForgetStoredSecret?, createUserPresenceSecret: CreateUserPresenceSecret?, revealUserPresenceSecret: RevealUserPresenceSecret?, saveRestorableState: SaveRestorableState?, setApplicationMenu: SetApplicationMenu?, setStatusItem: SetStatusItem?, pickFile: PickFile?, cancelFilePick: CancelFilePick?, requestPermission: RequestPermission?, cameraViewport: CameraViewport?, cameraCapture: CameraCapture?, cameraStop: CameraStop?) {
        self.qrDisplay = qrDisplay
        self.scheduleWakeup = scheduleWakeup
        self.bleStartAdvertising = bleStartAdvertising
        self.bleStartScanning = bleStartScanning
        self.bleConnect = bleConnect
        self.bleWriteCharacteristic = bleWriteCharacteristic
        self.bleReadCharacteristic = bleReadCharacteristic
        self.bleDisconnect = bleDisconnect
        self.nfcActivate = nfcActivate
        self.nfcSendApdu = nfcSendApdu
        self.audioEmitChallenge = audioEmitChallenge
        self.audioListenForResponse = audioListenForResponse
        self.relayEscrowDeposit = relayEscrowDeposit
        self.relayEscrowCheck = relayEscrowCheck
        self.relayEscrowRetrieve = relayEscrowRetrieve
        self.showShareSheet = showShareSheet
        self.directSend = directSend
        self.switchCamera = switchCamera
        self.filePickFromUser = filePickFromUser
        self.setScreenBrightness = setScreenBrightness
        self.setIdleTimerDisabled = setIdleTimerDisabled
        self.setOrientationLock = setOrientationLock
        self.directSendCard = directSendCard
        self.locationRequest = locationRequest
        self.celebrate = celebrate
        self.setContextBar = setContextBar
        self.setNavigation = setNavigation
        self.presentOverlay = presentOverlay
        self.dismissOverlay = dismissOverlay
        self.setPresentationProfile = setPresentationProfile
        self.replaceSurface = replaceSurface
        self.presentAlert = presentAlert
        self.showToast = showToast
        self.openExternalURL = openExternalURL
        self.exportFile = exportFile
        self.emitDocument = emitDocument
        self.finishInvocation = finishInvocation
        self.postNotification = postNotification
        self.forgetStoredSecret = forgetStoredSecret
        self.createUserPresenceSecret = createUserPresenceSecret
        self.revealUserPresenceSecret = revealUserPresenceSecret
        self.saveRestorableState = saveRestorableState
        self.setApplicationMenu = setApplicationMenu
        self.setStatusItem = setStatusItem
        self.pickFile = pickFile
        self.cancelFilePick = cancelFilePick
        self.requestPermission = requestPermission
        self.cameraViewport = cameraViewport
        self.cameraCapture = cameraCapture
        self.cameraStop = cameraStop
    }
}

// MARK: CommandClass convenience initializers and mutators

public extension CommandClass {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(CommandClass.self, from: data)
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
        qrDisplay: QrDisplay?? = nil,
        scheduleWakeup: ScheduleWakeup?? = nil,
        bleStartAdvertising: BleStartAdvertising?? = nil,
        bleStartScanning: BleStartScanning?? = nil,
        bleConnect: BleConnect?? = nil,
        bleWriteCharacteristic: BleWriteCharacteristic?? = nil,
        bleReadCharacteristic: BleReadCharacteristic?? = nil,
        bleDisconnect: BleDisconnect?? = nil,
        nfcActivate: NFCActivate?? = nil,
        nfcSendApdu: NFCSendApdu?? = nil,
        audioEmitChallenge: AudioEmitChallenge?? = nil,
        audioListenForResponse: AudioListenForResponse?? = nil,
        relayEscrowDeposit: RelayEscrowDeposit?? = nil,
        relayEscrowCheck: RelayEscrowCheck?? = nil,
        relayEscrowRetrieve: RelayEscrowRetrieve?? = nil,
        showShareSheet: ShowShareSheet?? = nil,
        directSend: DirectSend?? = nil,
        switchCamera: SwitchCamera?? = nil,
        filePickFromUser: FilePickFromUser?? = nil,
        setScreenBrightness: SetScreenBrightness?? = nil,
        setIdleTimerDisabled: SetIdleTimerDisabled?? = nil,
        setOrientationLock: SetOrientationLock?? = nil,
        directSendCard: DirectSendCard?? = nil,
        locationRequest: LocationRequest?? = nil,
        celebrate: Celebrate?? = nil,
        setContextBar: SetContextBar?? = nil,
        setNavigation: SetNavigation?? = nil,
        presentOverlay: PresentOverlay?? = nil,
        dismissOverlay: DismissOverlay?? = nil,
        setPresentationProfile: SetPresentationProfile?? = nil,
        replaceSurface: ReplaceSurface?? = nil,
        presentAlert: PresentAlert?? = nil,
        showToast: ShowToast?? = nil,
        openExternalURL: OpenExternalURL?? = nil,
        exportFile: ExportFile?? = nil,
        emitDocument: EmitDocument?? = nil,
        finishInvocation: FinishInvocation?? = nil,
        postNotification: PostNotification?? = nil,
        forgetStoredSecret: ForgetStoredSecret?? = nil,
        createUserPresenceSecret: CreateUserPresenceSecret?? = nil,
        revealUserPresenceSecret: RevealUserPresenceSecret?? = nil,
        saveRestorableState: SaveRestorableState?? = nil,
        setApplicationMenu: SetApplicationMenu?? = nil,
        setStatusItem: SetStatusItem?? = nil,
        pickFile: PickFile?? = nil,
        cancelFilePick: CancelFilePick?? = nil,
        requestPermission: RequestPermission?? = nil,
        cameraViewport: CameraViewport?? = nil,
        cameraCapture: CameraCapture?? = nil,
        cameraStop: CameraStop?? = nil
    ) -> CommandClass {
        return CommandClass(
            qrDisplay: qrDisplay ?? self.qrDisplay,
            scheduleWakeup: scheduleWakeup ?? self.scheduleWakeup,
            bleStartAdvertising: bleStartAdvertising ?? self.bleStartAdvertising,
            bleStartScanning: bleStartScanning ?? self.bleStartScanning,
            bleConnect: bleConnect ?? self.bleConnect,
            bleWriteCharacteristic: bleWriteCharacteristic ?? self.bleWriteCharacteristic,
            bleReadCharacteristic: bleReadCharacteristic ?? self.bleReadCharacteristic,
            bleDisconnect: bleDisconnect ?? self.bleDisconnect,
            nfcActivate: nfcActivate ?? self.nfcActivate,
            nfcSendApdu: nfcSendApdu ?? self.nfcSendApdu,
            audioEmitChallenge: audioEmitChallenge ?? self.audioEmitChallenge,
            audioListenForResponse: audioListenForResponse ?? self.audioListenForResponse,
            relayEscrowDeposit: relayEscrowDeposit ?? self.relayEscrowDeposit,
            relayEscrowCheck: relayEscrowCheck ?? self.relayEscrowCheck,
            relayEscrowRetrieve: relayEscrowRetrieve ?? self.relayEscrowRetrieve,
            showShareSheet: showShareSheet ?? self.showShareSheet,
            directSend: directSend ?? self.directSend,
            switchCamera: switchCamera ?? self.switchCamera,
            filePickFromUser: filePickFromUser ?? self.filePickFromUser,
            setScreenBrightness: setScreenBrightness ?? self.setScreenBrightness,
            setIdleTimerDisabled: setIdleTimerDisabled ?? self.setIdleTimerDisabled,
            setOrientationLock: setOrientationLock ?? self.setOrientationLock,
            directSendCard: directSendCard ?? self.directSendCard,
            locationRequest: locationRequest ?? self.locationRequest,
            celebrate: celebrate ?? self.celebrate,
            setContextBar: setContextBar ?? self.setContextBar,
            setNavigation: setNavigation ?? self.setNavigation,
            presentOverlay: presentOverlay ?? self.presentOverlay,
            dismissOverlay: dismissOverlay ?? self.dismissOverlay,
            setPresentationProfile: setPresentationProfile ?? self.setPresentationProfile,
            replaceSurface: replaceSurface ?? self.replaceSurface,
            presentAlert: presentAlert ?? self.presentAlert,
            showToast: showToast ?? self.showToast,
            openExternalURL: openExternalURL ?? self.openExternalURL,
            exportFile: exportFile ?? self.exportFile,
            emitDocument: emitDocument ?? self.emitDocument,
            finishInvocation: finishInvocation ?? self.finishInvocation,
            postNotification: postNotification ?? self.postNotification,
            forgetStoredSecret: forgetStoredSecret ?? self.forgetStoredSecret,
            createUserPresenceSecret: createUserPresenceSecret ?? self.createUserPresenceSecret,
            revealUserPresenceSecret: revealUserPresenceSecret ?? self.revealUserPresenceSecret,
            saveRestorableState: saveRestorableState ?? self.saveRestorableState,
            setApplicationMenu: setApplicationMenu ?? self.setApplicationMenu,
            setStatusItem: setStatusItem ?? self.setStatusItem,
            pickFile: pickFile ?? self.pickFile,
            cancelFilePick: cancelFilePick ?? self.cancelFilePick,
            requestPermission: requestPermission ?? self.requestPermission,
            cameraViewport: cameraViewport ?? self.cameraViewport,
            cameraCapture: cameraCapture ?? self.cameraCapture,
            cameraStop: cameraStop ?? self.cameraStop
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - AudioEmitChallenge
public struct AudioEmitChallenge: Codable {
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

// MARK: AudioEmitChallenge convenience initializers and mutators

public extension AudioEmitChallenge {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(AudioEmitChallenge.self, from: data)
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
    ) -> AudioEmitChallenge {
        return AudioEmitChallenge(
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

// MARK: - AudioListenForResponse
public struct AudioListenForResponse: Codable {
    public let sampleRate: Int
    public let timeoutMS: Int

    public enum CodingKeys: String, CodingKey {
        case sampleRate = "sample_rate"
        case timeoutMS = "timeout_ms"
    }

    public init(sampleRate: Int, timeoutMS: Int) {
        self.sampleRate = sampleRate
        self.timeoutMS = timeoutMS
    }
}

// MARK: AudioListenForResponse convenience initializers and mutators

public extension AudioListenForResponse {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(AudioListenForResponse.self, from: data)
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
        timeoutMS: Int? = nil
    ) -> AudioListenForResponse {
        return AudioListenForResponse(
            sampleRate: sampleRate ?? self.sampleRate,
            timeoutMS: timeoutMS ?? self.timeoutMS
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BleConnect
public struct BleConnect: Codable {
    public let deviceID: String

    public enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
    }

    public init(deviceID: String) {
        self.deviceID = deviceID
    }
}

// MARK: BleConnect convenience initializers and mutators

public extension BleConnect {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleConnect.self, from: data)
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
    ) -> BleConnect {
        return BleConnect(
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

// MARK: - BleDisconnect
public struct BleDisconnect: Codable {
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

// MARK: BleDisconnect convenience initializers and mutators

public extension BleDisconnect {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleDisconnect.self, from: data)
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
    ) -> BleDisconnect {
        return BleDisconnect(
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

// MARK: - BleReadCharacteristic
public struct BleReadCharacteristic: Codable {
    public let deviceID: String
    public let direction: BleLinkDirection
    public let uuid: String

    public enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case direction = "direction"
        case uuid = "uuid"
    }

    public init(deviceID: String, direction: BleLinkDirection, uuid: String) {
        self.deviceID = deviceID
        self.direction = direction
        self.uuid = uuid
    }
}

// MARK: BleReadCharacteristic convenience initializers and mutators

public extension BleReadCharacteristic {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleReadCharacteristic.self, from: data)
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
        uuid: String? = nil
    ) -> BleReadCharacteristic {
        return BleReadCharacteristic(
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

// MARK: - BleStartAdvertising
public struct BleStartAdvertising: Codable {
    public let payload: [Int]
    public let serviceUUID: String

    public enum CodingKeys: String, CodingKey {
        case payload = "payload"
        case serviceUUID = "service_uuid"
    }

    public init(payload: [Int], serviceUUID: String) {
        self.payload = payload
        self.serviceUUID = serviceUUID
    }
}

// MARK: BleStartAdvertising convenience initializers and mutators

public extension BleStartAdvertising {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleStartAdvertising.self, from: data)
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
        payload: [Int]? = nil,
        serviceUUID: String? = nil
    ) -> BleStartAdvertising {
        return BleStartAdvertising(
            payload: payload ?? self.payload,
            serviceUUID: serviceUUID ?? self.serviceUUID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BleStartScanning
public struct BleStartScanning: Codable {
    public let serviceUUID: String

    public enum CodingKeys: String, CodingKey {
        case serviceUUID = "service_uuid"
    }

    public init(serviceUUID: String) {
        self.serviceUUID = serviceUUID
    }
}

// MARK: BleStartScanning convenience initializers and mutators

public extension BleStartScanning {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleStartScanning.self, from: data)
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
        serviceUUID: String? = nil
    ) -> BleStartScanning {
        return BleStartScanning(
            serviceUUID: serviceUUID ?? self.serviceUUID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - BleWriteCharacteristic
public struct BleWriteCharacteristic: Codable {
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

// MARK: BleWriteCharacteristic convenience initializers and mutators

public extension BleWriteCharacteristic {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BleWriteCharacteristic.self, from: data)
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
    ) -> BleWriteCharacteristic {
        return BleWriteCharacteristic(
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

// MARK: - CameraCapture
public struct CameraCapture: Codable {
    public let previewID: String
    public let purpose: CameraPurpose

    public enum CodingKeys: String, CodingKey {
        case previewID = "preview_id"
        case purpose = "purpose"
    }

    public init(previewID: String, purpose: CameraPurpose) {
        self.previewID = previewID
        self.purpose = purpose
    }
}

// MARK: CameraCapture convenience initializers and mutators

public extension CameraCapture {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(CameraCapture.self, from: data)
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
        previewID: String? = nil,
        purpose: CameraPurpose? = nil
    ) -> CameraCapture {
        return CameraCapture(
            previewID: previewID ?? self.previewID,
            purpose: purpose ?? self.purpose
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// What a [`super::Command::CameraCapture`] produces.
///
/// Decode QR codes until stopped, reporting each as `Event::QrScanned`.
///
/// Take one photo, reported as `Event::ImageReceived`.
public enum CameraPurpose: String, Codable {
    case photo = "photo"
    case qrScan = "qr_scan"
}

// MARK: - CameraStop
public struct CameraStop: Codable {
    public let previewID: String

    public enum CodingKeys: String, CodingKey {
        case previewID = "preview_id"
    }

    public init(previewID: String) {
        self.previewID = previewID
    }
}

// MARK: CameraStop convenience initializers and mutators

public extension CameraStop {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(CameraStop.self, from: data)
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
        previewID: String? = nil
    ) -> CameraStop {
        return CameraStop(
            previewID: previewID ?? self.previewID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - CameraViewport
public struct CameraViewport: Codable {
    public let previewID: String

    public enum CodingKeys: String, CodingKey {
        case previewID = "preview_id"
    }

    public init(previewID: String) {
        self.previewID = previewID
    }
}

// MARK: CameraViewport convenience initializers and mutators

public extension CameraViewport {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(CameraViewport.self, from: data)
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
        previewID: String? = nil
    ) -> CameraViewport {
        return CameraViewport(
            previewID: previewID ?? self.previewID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - CancelFilePick
public struct CancelFilePick: Codable {
    public let requestID: String

    public enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
    }

    public init(requestID: String) {
        self.requestID = requestID
    }
}

// MARK: CancelFilePick convenience initializers and mutators

public extension CancelFilePick {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(CancelFilePick.self, from: data)
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
        requestID: String? = nil
    ) -> CancelFilePick {
        return CancelFilePick(
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

// MARK: - Celebrate
public struct Celebrate: Codable {
    public let animation: AnimationToken
    public let haptic: HapticPattern
    public let sound: SoundToken

    public enum CodingKeys: String, CodingKey {
        case animation = "animation"
        case haptic = "haptic"
        case sound = "sound"
    }

    public init(animation: AnimationToken, haptic: HapticPattern, sound: SoundToken) {
        self.animation = animation
        self.haptic = haptic
        self.sound = sound
    }
}

// MARK: Celebrate convenience initializers and mutators

public extension Celebrate {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Celebrate.self, from: data)
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
        animation: AnimationToken? = nil,
        haptic: HapticPattern? = nil,
        sound: SoundToken? = nil
    ) -> Celebrate {
        return Celebrate(
            animation: animation ?? self.animation,
            haptic: haptic ?? self.haptic,
            sound: sound ?? self.sound
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Animation intent for [`Command::Celebrate`]. Closed enum — platforms map to a native
/// one-beat animation, respecting reduce-motion.
///
/// The two cards meet — the exchange-success beat (~600 ms, then still).
///
/// No animation.
public enum AnimationToken: String, Codable {
    case cardsMeet = "cards_meet"
    case none = "none"
}

/// Haptic intent for [`Command::Celebrate`]. Closed enum — platforms map to native patterns
/// (e.g. `UINotificationFeedbackGenerator.success`).
///
/// The platform's "success" notification haptic.
///
/// A single light tap.
///
/// No haptic.
public enum HapticPattern: String, Codable {
    case light = "light"
    case none = "none"
    case success = "success"
}

/// Sound intent for [`Command::Celebrate`]. Closed enum — platforms map to a bundled asset;
/// respecting the ringer is the frontend's call.
///
/// The short exchange chime ("clinking glasses").
///
/// No sound.
public enum SoundToken: String, Codable {
    case exchangeChime = "exchange_chime"
    case none = "none"
}

// MARK: - CreateUserPresenceSecret
public struct CreateUserPresenceSecret: Codable {
    public let binding: UserPresenceBinding
    public let prompt: String

    public enum CodingKeys: String, CodingKey {
        case binding = "binding"
        case prompt = "prompt"
    }

    public init(binding: UserPresenceBinding, prompt: String) {
        self.binding = binding
        self.prompt = prompt
    }
}

// MARK: CreateUserPresenceSecret convenience initializers and mutators

public extension CreateUserPresenceSecret {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(CreateUserPresenceSecret.self, from: data)
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
        binding: UserPresenceBinding? = nil,
        prompt: String? = nil
    ) -> CreateUserPresenceSecret {
        return CreateUserPresenceSecret(
            binding: binding ?? self.binding,
            prompt: prompt ?? self.prompt
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Which operating-system check guards a secret sealed for
/// [`Command::CreateUserPresenceSecret`]. A biometric seal stops opening when the enrolled
/// fingers or faces change, so a new enrolment, which needs only the device password, cannot
/// read it (#778).
///
/// Only the biometrics enrolled when the secret was sealed.
///
/// The device credential (passcode or login password), or biometrics.
public enum UserPresenceBinding: String, Codable {
    case biometry = "biometry"
    case deviceCredential = "device_credential"
}

// MARK: - DirectSend
public struct DirectSend: Codable {
    public let endpoint: DirectEndpoint?
    public let isInitiator: Bool
    public let payload: [Int]

    public enum CodingKeys: String, CodingKey {
        case endpoint = "endpoint"
        case isInitiator = "is_initiator"
        case payload = "payload"
    }

    public init(endpoint: DirectEndpoint?, isInitiator: Bool, payload: [Int]) {
        self.endpoint = endpoint
        self.isInitiator = isInitiator
        self.payload = payload
    }
}

// MARK: DirectSend convenience initializers and mutators

public extension DirectSend {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DirectSend.self, from: data)
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
        endpoint: DirectEndpoint?? = nil,
        isInitiator: Bool? = nil,
        payload: [Int]? = nil
    ) -> DirectSend {
        return DirectSend(
            endpoint: endpoint ?? self.endpoint,
            isInitiator: isInitiator ?? self.isInitiator,
            payload: payload ?? self.payload
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Where a shell finds the peer of a direct (USB cable / local TCP) swap, and how long it
/// may take. Core's policy, executed by every shell (#764).
// MARK: - DirectEndpoint
public struct DirectEndpoint: Codable {
    /// How long to browse before falling back; one browse per swap.
    public let browseTimeoutMS: Int
    /// Host to reach the peer on when the browse finds nothing: the phone's USB-forwarded
    /// listener on this machine.
    public let fallbackHost: String
    /// Deadline for connecting and for each read and write.
    public let ioTimeoutMS: Int
    /// TCP port to reach the peer on when the browse finds nothing.
    public let port: Int
    /// DNS-SD service type to browse for the peer's address.
    public let serviceType: String

    public enum CodingKeys: String, CodingKey {
        case browseTimeoutMS = "browse_timeout_ms"
        case fallbackHost = "fallback_host"
        case ioTimeoutMS = "io_timeout_ms"
        case port = "port"
        case serviceType = "service_type"
    }

    public init(browseTimeoutMS: Int, fallbackHost: String, ioTimeoutMS: Int, port: Int, serviceType: String) {
        self.browseTimeoutMS = browseTimeoutMS
        self.fallbackHost = fallbackHost
        self.ioTimeoutMS = ioTimeoutMS
        self.port = port
        self.serviceType = serviceType
    }
}

// MARK: DirectEndpoint convenience initializers and mutators

public extension DirectEndpoint {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DirectEndpoint.self, from: data)
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
        browseTimeoutMS: Int? = nil,
        fallbackHost: String? = nil,
        ioTimeoutMS: Int? = nil,
        port: Int? = nil,
        serviceType: String? = nil
    ) -> DirectEndpoint {
        return DirectEndpoint(
            browseTimeoutMS: browseTimeoutMS ?? self.browseTimeoutMS,
            fallbackHost: fallbackHost ?? self.fallbackHost,
            ioTimeoutMS: ioTimeoutMS ?? self.ioTimeoutMS,
            port: port ?? self.port,
            serviceType: serviceType ?? self.serviceType
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - DirectSendCard
public struct DirectSendCard: Codable {
    public let ciphertext: [Int]
    public let isInitiator: Bool

    public enum CodingKeys: String, CodingKey {
        case ciphertext = "ciphertext"
        case isInitiator = "is_initiator"
    }

    public init(ciphertext: [Int], isInitiator: Bool) {
        self.ciphertext = ciphertext
        self.isInitiator = isInitiator
    }
}

// MARK: DirectSendCard convenience initializers and mutators

public extension DirectSendCard {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DirectSendCard.self, from: data)
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
        ciphertext: [Int]? = nil,
        isInitiator: Bool? = nil
    ) -> DirectSendCard {
        return DirectSendCard(
            ciphertext: ciphertext ?? self.ciphertext,
            isInitiator: isInitiator ?? self.isInitiator
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - DismissOverlay
public struct DismissOverlay: Codable {
    public let kind: OverlayKind
    public let revision: UInt64
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case kind = "kind"
        case revision = "revision"
        case surfaceID = "surface_id"
    }

    public init(kind: OverlayKind, revision: UInt64, surfaceID: String) {
        self.kind = kind
        self.revision = revision
        self.surfaceID = surfaceID
    }
}

// MARK: DismissOverlay convenience initializers and mutators

public extension DismissOverlay {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DismissOverlay.self, from: data)
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
        revision: UInt64? = nil,
        surfaceID: String? = nil
    ) -> DismissOverlay {
        return DismissOverlay(
            kind: kind ?? self.kind,
            revision: revision ?? self.revision,
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

// MARK: - EmitDocument
public struct EmitDocument: Codable {
    public let document: DocumentSpec

    public enum CodingKeys: String, CodingKey {
        case document = "document"
    }

    public init(document: DocumentSpec) {
        self.document = document
    }
}

// MARK: EmitDocument convenience initializers and mutators

public extension EmitDocument {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(EmitDocument.self, from: data)
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
        document: DocumentSpec? = nil
    ) -> EmitDocument {
        return EmitDocument(
            document: document ?? self.document
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// A machine-readable document Core prepared for a shell that asked for one. The shell
/// writes `data` out unread; `schema` is a Core-owned, versioned identifier (ADR-066
/// Amendment 2026-09-26 (b)).
// MARK: - DocumentSpec
public struct DocumentSpec: Codable {
    public let data: [Int]
    public let mediaType: String
    public let schema: String

    public enum CodingKeys: String, CodingKey {
        case data = "data"
        case mediaType = "media_type"
        case schema = "schema"
    }

    public init(data: [Int], mediaType: String, schema: String) {
        self.data = data
        self.mediaType = mediaType
        self.schema = schema
    }
}

// MARK: DocumentSpec convenience initializers and mutators

public extension DocumentSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(DocumentSpec.self, from: data)
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
        mediaType: String? = nil,
        schema: String? = nil
    ) -> DocumentSpec {
        return DocumentSpec(
            data: data ?? self.data,
            mediaType: mediaType ?? self.mediaType,
            schema: schema ?? self.schema
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ExportFile
public struct ExportFile: Codable {
    public let file: ExportFileSpec

    public enum CodingKeys: String, CodingKey {
        case file = "file"
    }

    public init(file: ExportFileSpec) {
        self.file = file
    }
}

// MARK: ExportFile convenience initializers and mutators

public extension ExportFile {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ExportFile.self, from: data)
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
        file: ExportFileSpec? = nil
    ) -> ExportFile {
        return ExportFile(
            file: file ?? self.file
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ExportFileSpec
public struct ExportFileSpec: Codable {
    public let data: [Int]
    public let mimeType: String
    public let suggestedName: String

    public enum CodingKeys: String, CodingKey {
        case data = "data"
        case mimeType = "mime_type"
        case suggestedName = "suggested_name"
    }

    public init(data: [Int], mimeType: String, suggestedName: String) {
        self.data = data
        self.mimeType = mimeType
        self.suggestedName = suggestedName
    }
}

// MARK: ExportFileSpec convenience initializers and mutators

public extension ExportFileSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ExportFileSpec.self, from: data)
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
        mimeType: String? = nil,
        suggestedName: String? = nil
    ) -> ExportFileSpec {
        return ExportFileSpec(
            data: data ?? self.data,
            mimeType: mimeType ?? self.mimeType,
            suggestedName: suggestedName ?? self.suggestedName
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - FilePickFromUser
public struct FilePickFromUser: Codable {
    public let acceptedExtensions: [String]?
    public let acceptedMIMETypes: [String]
    public let maxBytes: UInt64?
    public let purpose: FilePickPurpose

    public enum CodingKeys: String, CodingKey {
        case acceptedExtensions = "accepted_extensions"
        case acceptedMIMETypes = "accepted_mime_types"
        case maxBytes = "max_bytes"
        case purpose = "purpose"
    }

    public init(acceptedExtensions: [String]?, acceptedMIMETypes: [String], maxBytes: UInt64?, purpose: FilePickPurpose) {
        self.acceptedExtensions = acceptedExtensions
        self.acceptedMIMETypes = acceptedMIMETypes
        self.maxBytes = maxBytes
        self.purpose = purpose
    }
}

// MARK: FilePickFromUser convenience initializers and mutators

public extension FilePickFromUser {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FilePickFromUser.self, from: data)
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
        acceptedExtensions: [String]?? = nil,
        acceptedMIMETypes: [String]? = nil,
        maxBytes: UInt64?? = nil,
        purpose: FilePickPurpose? = nil
    ) -> FilePickFromUser {
        return FilePickFromUser(
            acceptedExtensions: acceptedExtensions ?? self.acceptedExtensions,
            acceptedMIMETypes: acceptedMIMETypes ?? self.acceptedMIMETypes,
            maxBytes: maxBytes ?? self.maxBytes,
            purpose: purpose ?? self.purpose
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Why a file picker is being opened — lets frontends label the dialog (e.g., "Import
/// Contacts" vs "Import Backup") without hardcoded strings.
///
/// Variants map 1:1 to a label key in the locale store. `Other` covers future imports (e.g.,
/// key-bundle import) without forcing every consumer to update for a new well-known purpose.
public enum FilePickPurpose: Codable {
    case enumeration(FilePickPurposeEnum)
    case filePickPurposeClass(FilePickPurposeClass)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(FilePickPurposeEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(FilePickPurposeClass.self) {
            self = .filePickPurposeClass(x)
            return
        }
        throw DecodingError.typeMismatch(FilePickPurpose.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for FilePickPurpose"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .enumeration(let x):
            try container.encode(x)
        case .filePickPurposeClass(let x):
            try container.encode(x)
        }
    }
}

/// Reserved for future imports — frontends look up `label_key` in the locale store.
// MARK: - FilePickPurposeClass
public struct FilePickPurposeClass: Codable {
    public let other: Other

    public enum CodingKeys: String, CodingKey {
        case other = "Other"
    }

    public init(other: Other) {
        self.other = other
    }
}

// MARK: FilePickPurposeClass convenience initializers and mutators

public extension FilePickPurposeClass {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FilePickPurposeClass.self, from: data)
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
        other: Other? = nil
    ) -> FilePickPurposeClass {
        return FilePickPurposeClass(
            other: other ?? self.other
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Other
public struct Other: Codable {
    public let labelKey: String

    public enum CodingKeys: String, CodingKey {
        case labelKey = "label_key"
    }

    public init(labelKey: String) {
        self.labelKey = labelKey
    }
}

// MARK: Other convenience initializers and mutators

public extension Other {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Other.self, from: data)
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
        labelKey: String? = nil
    ) -> Other {
        return Other(
            labelKey: labelKey ?? self.labelKey
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// vCard / VCF import on top of the contacts engine.
///
/// Encrypted vauchi backup blob.
public enum FilePickPurposeEnum: String, Codable {
    case importBackup = "ImportBackup"
    case importContacts = "ImportContacts"
}

// MARK: - FinishInvocation
public struct FinishInvocation: Codable {
    public let outcome: InvocationOutcome

    public enum CodingKeys: String, CodingKey {
        case outcome = "outcome"
    }

    public init(outcome: InvocationOutcome) {
        self.outcome = outcome
    }
}

// MARK: FinishInvocation convenience initializers and mutators

public extension FinishInvocation {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FinishInvocation.self, from: data)
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
        outcome: InvocationOutcome? = nil
    ) -> FinishInvocation {
        return FinishInvocation(
            outcome: outcome ?? self.outcome
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// How a one-shot invocation ended. Deliberately generic: shells map it to their own status
/// convention (the CLI to exit codes) without learning why.
public enum InvocationOutcome: String, Codable {
    case denied = "denied"
    case failed = "failed"
    case invalidInput = "invalid_input"
    case succeeded = "succeeded"
    case unavailable = "unavailable"
}

// MARK: - ForgetStoredSecret
public struct ForgetStoredSecret: Codable {
    public let handle: String

    public enum CodingKeys: String, CodingKey {
        case handle = "handle"
    }

    public init(handle: String) {
        self.handle = handle
    }
}

// MARK: ForgetStoredSecret convenience initializers and mutators

public extension ForgetStoredSecret {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ForgetStoredSecret.self, from: data)
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
        handle: String? = nil
    ) -> ForgetStoredSecret {
        return ForgetStoredSecret(
            handle: handle ?? self.handle
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - LocationRequest
public struct LocationRequest: Codable {
    public let timeoutMS: Int

    public enum CodingKeys: String, CodingKey {
        case timeoutMS = "timeout_ms"
    }

    public init(timeoutMS: Int) {
        self.timeoutMS = timeoutMS
    }
}

// MARK: LocationRequest convenience initializers and mutators

public extension LocationRequest {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(LocationRequest.self, from: data)
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
        timeoutMS: Int? = nil
    ) -> LocationRequest {
        return LocationRequest(
            timeoutMS: timeoutMS ?? self.timeoutMS
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - NFCActivate
public struct NFCActivate: Codable {
    public let apdus: [[Int]]?
    public let payload: [Int]

    public enum CodingKeys: String, CodingKey {
        case apdus = "apdus"
        case payload = "payload"
    }

    public init(apdus: [[Int]]?, payload: [Int]) {
        self.apdus = apdus
        self.payload = payload
    }
}

// MARK: NFCActivate convenience initializers and mutators

public extension NFCActivate {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NFCActivate.self, from: data)
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
        apdus: [[Int]]?? = nil,
        payload: [Int]? = nil
    ) -> NFCActivate {
        return NFCActivate(
            apdus: apdus ?? self.apdus,
            payload: payload ?? self.payload
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - NFCSendApdu
public struct NFCSendApdu: Codable {
    public let apdus: [[Int]]?
    public let data: [Int]

    public enum CodingKeys: String, CodingKey {
        case apdus = "apdus"
        case data = "data"
    }

    public init(apdus: [[Int]]?, data: [Int]) {
        self.apdus = apdus
        self.data = data
    }
}

// MARK: NFCSendApdu convenience initializers and mutators

public extension NFCSendApdu {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NFCSendApdu.self, from: data)
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
        apdus: [[Int]]?? = nil,
        data: [Int]? = nil
    ) -> NFCSendApdu {
        return NFCSendApdu(
            apdus: apdus ?? self.apdus,
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

// MARK: - OpenExternalURL
public struct OpenExternalURL: Codable {
    public let url: String

    public enum CodingKeys: String, CodingKey {
        case url = "url"
    }

    public init(url: String) {
        self.url = url
    }
}

// MARK: OpenExternalURL convenience initializers and mutators

public extension OpenExternalURL {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(OpenExternalURL.self, from: data)
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
        url: String? = nil
    ) -> OpenExternalURL {
        return OpenExternalURL(
            url: url ?? self.url
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PickFile
public struct PickFile: Codable {
    public let acceptedExtensions: [String]
    public let acceptedMIMETypes: [String]
    public let maxBytes: UInt64
    public let requestID: String
    public let title: String

    public enum CodingKeys: String, CodingKey {
        case acceptedExtensions = "accepted_extensions"
        case acceptedMIMETypes = "accepted_mime_types"
        case maxBytes = "max_bytes"
        case requestID = "request_id"
        case title = "title"
    }

    public init(acceptedExtensions: [String], acceptedMIMETypes: [String], maxBytes: UInt64, requestID: String, title: String) {
        self.acceptedExtensions = acceptedExtensions
        self.acceptedMIMETypes = acceptedMIMETypes
        self.maxBytes = maxBytes
        self.requestID = requestID
        self.title = title
    }
}

// MARK: PickFile convenience initializers and mutators

public extension PickFile {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PickFile.self, from: data)
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
        acceptedExtensions: [String]? = nil,
        acceptedMIMETypes: [String]? = nil,
        maxBytes: UInt64? = nil,
        requestID: String? = nil,
        title: String? = nil
    ) -> PickFile {
        return PickFile(
            acceptedExtensions: acceptedExtensions ?? self.acceptedExtensions,
            acceptedMIMETypes: acceptedMIMETypes ?? self.acceptedMIMETypes,
            maxBytes: maxBytes ?? self.maxBytes,
            requestID: requestID ?? self.requestID,
            title: title ?? self.title
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PostNotification
public struct PostNotification: Codable {
    public let notification: NotificationSpec

    public enum CodingKeys: String, CodingKey {
        case notification = "notification"
    }

    public init(notification: NotificationSpec) {
        self.notification = notification
    }
}

// MARK: PostNotification convenience initializers and mutators

public extension PostNotification {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PostNotification.self, from: data)
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
        notification: NotificationSpec? = nil
    ) -> PostNotification {
        return PostNotification(
            notification: notification ?? self.notification
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - NotificationSpec
public struct NotificationSpec: Codable {
    public let body: String
    public let categoryID: String
    public let categoryOptions: [String]
    public let channelID: String
    public let deepLinkURI: String?
    /// Opaque OS replacement identity. Forward unchanged; never parse it. Absent only for older
    /// command producers that posted anonymously.
    public let notificationID: String?
    public let title: String
    public let urgency: NotificationUrgency

    public enum CodingKeys: String, CodingKey {
        case body = "body"
        case categoryID = "category_id"
        case categoryOptions = "category_options"
        case channelID = "channel_id"
        case deepLinkURI = "deep_link_uri"
        case notificationID = "notification_id"
        case title = "title"
        case urgency = "urgency"
    }

    public init(body: String, categoryID: String, categoryOptions: [String], channelID: String, deepLinkURI: String?, notificationID: String?, title: String, urgency: NotificationUrgency) {
        self.body = body
        self.categoryID = categoryID
        self.categoryOptions = categoryOptions
        self.channelID = channelID
        self.deepLinkURI = deepLinkURI
        self.notificationID = notificationID
        self.title = title
        self.urgency = urgency
    }
}

// MARK: NotificationSpec convenience initializers and mutators

public extension NotificationSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NotificationSpec.self, from: data)
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
        body: String? = nil,
        categoryID: String? = nil,
        categoryOptions: [String]? = nil,
        channelID: String? = nil,
        deepLinkURI: String?? = nil,
        notificationID: String?? = nil,
        title: String? = nil,
        urgency: NotificationUrgency? = nil
    ) -> NotificationSpec {
        return NotificationSpec(
            body: body ?? self.body,
            categoryID: categoryID ?? self.categoryID,
            categoryOptions: categoryOptions ?? self.categoryOptions,
            channelID: channelID ?? self.channelID,
            deepLinkURI: deepLinkURI ?? self.deepLinkURI,
            notificationID: notificationID ?? self.notificationID,
            title: title ?? self.title,
            urgency: urgency ?? self.urgency
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum NotificationUrgency: String, Codable {
    case high = "high"
    case notificationUrgencyDefault = "default"
    case urgent = "urgent"
}

// MARK: - PresentAlert
public struct PresentAlert: Codable {
    public let alert: AlertSpec

    public enum CodingKeys: String, CodingKey {
        case alert = "alert"
    }

    public init(alert: AlertSpec) {
        self.alert = alert
    }
}

// MARK: PresentAlert convenience initializers and mutators

public extension PresentAlert {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentAlert.self, from: data)
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
        alert: AlertSpec? = nil
    ) -> PresentAlert {
        return PresentAlert(
            alert: alert ?? self.alert
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - AlertSpec
public struct AlertSpec: Codable {
    public let message: String
    public let title: String

    public enum CodingKeys: String, CodingKey {
        case message = "message"
        case title = "title"
    }

    public init(message: String, title: String) {
        self.message = message
        self.title = title
    }
}

// MARK: AlertSpec convenience initializers and mutators

public extension AlertSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(AlertSpec.self, from: data)
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
        message: String? = nil,
        title: String? = nil
    ) -> AlertSpec {
        return AlertSpec(
            message: message ?? self.message,
            title: title ?? self.title
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PresentOverlay
public struct PresentOverlay: Codable {
    public let overlay: OverlaySpec
    public let revision: UInt64
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case overlay = "overlay"
        case revision = "revision"
        case surfaceID = "surface_id"
    }

    public init(overlay: OverlaySpec, revision: UInt64, surfaceID: String) {
        self.overlay = overlay
        self.revision = revision
        self.surfaceID = surfaceID
    }
}

// MARK: PresentOverlay convenience initializers and mutators

public extension PresentOverlay {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentOverlay.self, from: data)
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
        overlay: OverlaySpec? = nil,
        revision: UInt64? = nil,
        surfaceID: String? = nil
    ) -> PresentOverlay {
        return PresentOverlay(
            overlay: overlay ?? self.overlay,
            revision: revision ?? self.revision,
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

// MARK: - OverlaySpec
public struct OverlaySpec: Codable {
    /// Prose for an `Information` overlay; omitted on the wire otherwise.
    public let body: String?
    /// The visible and spoken label of the overlay's way out. A shell that draws a Close uses
    /// it; dismissing still reports `OverlayDismissed`. Core fills it for every overlay; a shell
    /// that gets none draws an icon-only close named by the overlay's `title`, when there is
    /// one, and chooses no word of its own (ADR-066). Optional on the wire because minors are
    /// additive (ADR-078 item 8).
    public let closeLabel: String?
    public let items: [ActionSpec]
    public let kind: OverlayKind
    public let title: String?

    public enum CodingKeys: String, CodingKey {
        case body = "body"
        case closeLabel = "close_label"
        case items = "items"
        case kind = "kind"
        case title = "title"
    }

    public init(body: String?, closeLabel: String?, items: [ActionSpec], kind: OverlayKind, title: String?) {
        self.body = body
        self.closeLabel = closeLabel
        self.items = items
        self.kind = kind
        self.title = title
    }
}

// MARK: OverlaySpec convenience initializers and mutators

public extension OverlaySpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(OverlaySpec.self, from: data)
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
        body: String?? = nil,
        closeLabel: String?? = nil,
        items: [ActionSpec]? = nil,
        kind: OverlayKind? = nil,
        title: String?? = nil
    ) -> OverlaySpec {
        return OverlaySpec(
            body: body ?? self.body,
            closeLabel: closeLabel ?? self.closeLabel,
            items: items ?? self.items,
            kind: kind ?? self.kind,
            title: title ?? self.title
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ActionSpec
public struct ActionSpec: Codable {
    public let accessibilityLabel: String
    public let enabled: Bool
    public let iconToken: String?
    public let interactionID: String
    public let label: String
    public let shortcut: StandardShortcut?
    public let tone: ActionTone?

    public enum CodingKeys: String, CodingKey {
        case accessibilityLabel = "accessibility_label"
        case enabled = "enabled"
        case iconToken = "icon_token"
        case interactionID = "interaction_id"
        case label = "label"
        case shortcut = "shortcut"
        case tone = "tone"
    }

    public init(accessibilityLabel: String, enabled: Bool, iconToken: String?, interactionID: String, label: String, shortcut: StandardShortcut?, tone: ActionTone?) {
        self.accessibilityLabel = accessibilityLabel
        self.enabled = enabled
        self.iconToken = iconToken
        self.interactionID = interactionID
        self.label = label
        self.shortcut = shortcut
        self.tone = tone
    }
}

// MARK: ActionSpec convenience initializers and mutators

public extension ActionSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ActionSpec.self, from: data)
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
        accessibilityLabel: String? = nil,
        enabled: Bool? = nil,
        iconToken: String?? = nil,
        interactionID: String? = nil,
        label: String? = nil,
        shortcut: StandardShortcut?? = nil,
        tone: ActionTone?? = nil
    ) -> ActionSpec {
        return ActionSpec(
            accessibilityLabel: accessibilityLabel ?? self.accessibilityLabel,
            enabled: enabled ?? self.enabled,
            iconToken: iconToken ?? self.iconToken,
            interactionID: interactionID ?? self.interactionID,
            label: label ?? self.label,
            shortcut: shortcut ?? self.shortcut,
            tone: tone ?? self.tone
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum StandardShortcut: String, Codable {
    case activatePrimary = "activate_primary"
    case back = "back"
    case standardShortcutImport = "import"
    case undo = "undo"
}

/// Consequential but reversible or protective (verify a fingerprint, schedule a deletion,
/// start recovery): shells draw it with the warning colour as an outline, never as the
/// filled primary and never in the destructive style.
public enum ActionTone: String, Codable {
    case destructive = "destructive"
    case serious = "serious"
    case standard = "standard"
}

// MARK: - QrDisplay
public struct QrDisplay: Codable {
    public let data: String

    public enum CodingKeys: String, CodingKey {
        case data = "data"
    }

    public init(data: String) {
        self.data = data
    }
}

// MARK: QrDisplay convenience initializers and mutators

public extension QrDisplay {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(QrDisplay.self, from: data)
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
    ) -> QrDisplay {
        return QrDisplay(
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

// MARK: - RelayEscrowCheck
public struct RelayEscrowCheck: Codable {
    public let gateHash: [Int]
    /// Suggested initial polling interval in milliseconds.
    public let suggestedIntervalMS: Int

    public enum CodingKeys: String, CodingKey {
        case gateHash = "gate_hash"
        case suggestedIntervalMS = "suggested_interval_ms"
    }

    public init(gateHash: [Int], suggestedIntervalMS: Int) {
        self.gateHash = gateHash
        self.suggestedIntervalMS = suggestedIntervalMS
    }
}

// MARK: RelayEscrowCheck convenience initializers and mutators

public extension RelayEscrowCheck {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RelayEscrowCheck.self, from: data)
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
        suggestedIntervalMS: Int? = nil
    ) -> RelayEscrowCheck {
        return RelayEscrowCheck(
            gateHash: gateHash ?? self.gateHash,
            suggestedIntervalMS: suggestedIntervalMS ?? self.suggestedIntervalMS
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - RelayEscrowDeposit
public struct RelayEscrowDeposit: Codable {
    public let encryptedCard: [Int]
    public let gateHash: [Int]
    public let slotHash: [Int]
    public let ttlSeconds: Int

    public enum CodingKeys: String, CodingKey {
        case encryptedCard = "encrypted_card"
        case gateHash = "gate_hash"
        case slotHash = "slot_hash"
        case ttlSeconds = "ttl_seconds"
    }

    public init(encryptedCard: [Int], gateHash: [Int], slotHash: [Int], ttlSeconds: Int) {
        self.encryptedCard = encryptedCard
        self.gateHash = gateHash
        self.slotHash = slotHash
        self.ttlSeconds = ttlSeconds
    }
}

// MARK: RelayEscrowDeposit convenience initializers and mutators

public extension RelayEscrowDeposit {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RelayEscrowDeposit.self, from: data)
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
        encryptedCard: [Int]? = nil,
        gateHash: [Int]? = nil,
        slotHash: [Int]? = nil,
        ttlSeconds: Int? = nil
    ) -> RelayEscrowDeposit {
        return RelayEscrowDeposit(
            encryptedCard: encryptedCard ?? self.encryptedCard,
            gateHash: gateHash ?? self.gateHash,
            slotHash: slotHash ?? self.slotHash,
            ttlSeconds: ttlSeconds ?? self.ttlSeconds
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - RelayEscrowRetrieve
public struct RelayEscrowRetrieve: Codable {
    public let gateHash: [Int]
    public let slotHash: [Int]

    public enum CodingKeys: String, CodingKey {
        case gateHash = "gate_hash"
        case slotHash = "slot_hash"
    }

    public init(gateHash: [Int], slotHash: [Int]) {
        self.gateHash = gateHash
        self.slotHash = slotHash
    }
}

// MARK: RelayEscrowRetrieve convenience initializers and mutators

public extension RelayEscrowRetrieve {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RelayEscrowRetrieve.self, from: data)
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
        slotHash: [Int]? = nil
    ) -> RelayEscrowRetrieve {
        return RelayEscrowRetrieve(
            gateHash: gateHash ?? self.gateHash,
            slotHash: slotHash ?? self.slotHash
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ReplaceSurface
public struct ReplaceSurface: Codable {
    public let surface: SurfaceSpec

    public enum CodingKeys: String, CodingKey {
        case surface = "surface"
    }

    public init(surface: SurfaceSpec) {
        self.surface = surface
    }
}

// MARK: ReplaceSurface convenience initializers and mutators

public extension ReplaceSurface {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ReplaceSurface.self, from: data)
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
        surface: SurfaceSpec? = nil
    ) -> ReplaceSurface {
        return ReplaceSurface(
            surface: surface ?? self.surface
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - SurfaceSpec
public struct SurfaceSpec: Codable {
    public let accessibilityLabel: String
    public let layout: SurfaceLayout
    public let nodes: [PresentationNode]
    /// Monotonic Core-owned replacement generation for this surface.
    ///
    /// A replacement with the same `surface_id` and `revision` as the one a shell shows keeps
    /// that surface's structure: the same nodes in the same order, with the same ids and
    /// bindings, each binding meaning what it meant. Only values, labels, enabled state and
    /// validation text change, so a shell may update the widgets it shows in place instead of
    /// rebuilding them. A new revision may change anything. Core holds itself to this in
    /// `vauchi-app`'s `same_revision_replacement_tests` (vauchi/private#1062).
    public let revision: UInt64
    public let subtitle: String?
    public let surfaceID: String
    public let title: String
    public let tokens: PresentationTokens

    public enum CodingKeys: String, CodingKey {
        case accessibilityLabel = "accessibility_label"
        case layout = "layout"
        case nodes = "nodes"
        case revision = "revision"
        case subtitle = "subtitle"
        case surfaceID = "surface_id"
        case title = "title"
        case tokens = "tokens"
    }

    public init(accessibilityLabel: String, layout: SurfaceLayout, nodes: [PresentationNode], revision: UInt64, subtitle: String?, surfaceID: String, title: String, tokens: PresentationTokens) {
        self.accessibilityLabel = accessibilityLabel
        self.layout = layout
        self.nodes = nodes
        self.revision = revision
        self.subtitle = subtitle
        self.surfaceID = surfaceID
        self.title = title
        self.tokens = tokens
    }
}

// MARK: SurfaceSpec convenience initializers and mutators

public extension SurfaceSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SurfaceSpec.self, from: data)
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
        accessibilityLabel: String? = nil,
        layout: SurfaceLayout? = nil,
        nodes: [PresentationNode]? = nil,
        revision: UInt64? = nil,
        subtitle: String?? = nil,
        surfaceID: String? = nil,
        title: String? = nil,
        tokens: PresentationTokens? = nil
    ) -> SurfaceSpec {
        return SurfaceSpec(
            accessibilityLabel: accessibilityLabel ?? self.accessibilityLabel,
            layout: layout ?? self.layout,
            nodes: nodes ?? self.nodes,
            revision: revision ?? self.revision,
            subtitle: subtitle ?? self.subtitle,
            surfaceID: surfaceID ?? self.surfaceID,
            title: title ?? self.title,
            tokens: tokens ?? self.tokens
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum SurfaceLayout: String, Codable {
    case fixed = "fixed"
    case pinned = "pinned"
    case scroll = "scroll"
}

// MARK: - PresentationRow
public struct PresentationRow: Codable {
    public let accessibility: AccessibilitySpec
    public let activation: ActionSpec?
    public let controls: [PresentationNode]
    public let detail: String?
    public let enabled: Bool
    public let fallbackText: String?
    public let iconToken: String?
    public let imageData: [Int]?
    /// Explains the row's item: opens an `OverlayKind::Information` overlay with text for it
    /// (vauchi/private#479). Absent where Core has no text or the person turned help off;
    /// omitted on the wire so older shells see the row they know.
    public let info: ActionSpec?
    public let secondaryActions: [ActionSpec]
    public let selected: Bool
    public let subtitle: String?
    public let title: String

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case activation = "activation"
        case controls = "controls"
        case detail = "detail"
        case enabled = "enabled"
        case fallbackText = "fallback_text"
        case iconToken = "icon_token"
        case imageData = "image_data"
        case info = "info"
        case secondaryActions = "secondary_actions"
        case selected = "selected"
        case subtitle = "subtitle"
        case title = "title"
    }

    public init(accessibility: AccessibilitySpec, activation: ActionSpec?, controls: [PresentationNode], detail: String?, enabled: Bool, fallbackText: String?, iconToken: String?, imageData: [Int]?, info: ActionSpec?, secondaryActions: [ActionSpec], selected: Bool, subtitle: String?, title: String) {
        self.accessibility = accessibility
        self.activation = activation
        self.controls = controls
        self.detail = detail
        self.enabled = enabled
        self.fallbackText = fallbackText
        self.iconToken = iconToken
        self.imageData = imageData
        self.info = info
        self.secondaryActions = secondaryActions
        self.selected = selected
        self.subtitle = subtitle
        self.title = title
    }
}

// MARK: PresentationRow convenience initializers and mutators

public extension PresentationRow {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentationRow.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        activation: ActionSpec?? = nil,
        controls: [PresentationNode]? = nil,
        detail: String?? = nil,
        enabled: Bool? = nil,
        fallbackText: String?? = nil,
        iconToken: String?? = nil,
        imageData: [Int]?? = nil,
        info: ActionSpec?? = nil,
        secondaryActions: [ActionSpec]? = nil,
        selected: Bool? = nil,
        subtitle: String?? = nil,
        title: String? = nil
    ) -> PresentationRow {
        return PresentationRow(
            accessibility: accessibility ?? self.accessibility,
            activation: activation ?? self.activation,
            controls: controls ?? self.controls,
            detail: detail ?? self.detail,
            enabled: enabled ?? self.enabled,
            fallbackText: fallbackText ?? self.fallbackText,
            iconToken: iconToken ?? self.iconToken,
            imageData: imageData ?? self.imageData,
            info: info ?? self.info,
            secondaryActions: secondaryActions ?? self.secondaryActions,
            selected: selected ?? self.selected,
            subtitle: subtitle ?? self.subtitle,
            title: title ?? self.title
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - List
public struct List: Codable {
    public let accessibility: AccessibilitySpec
    public let id: String
    public let label: String?
    public let paging: PresentationPaging?
    public let rows: [PresentationRow]
    /// The search field's placeholder when `searchable`, prepared by Core. Omitted on the wire
    /// when absent; the field then shows none.
    public let searchPlaceholder: String?
    public let searchable: Bool
    /// Omitted on the wire when `Rows`, so every existing fixture and shell keeps working
    /// unchanged.
    public let style: PresentationListStyle?

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case id = "id"
        case label = "label"
        case paging = "paging"
        case rows = "rows"
        case searchPlaceholder = "search_placeholder"
        case searchable = "searchable"
        case style = "style"
    }

    public init(accessibility: AccessibilitySpec, id: String, label: String?, paging: PresentationPaging?, rows: [PresentationRow], searchPlaceholder: String?, searchable: Bool, style: PresentationListStyle?) {
        self.accessibility = accessibility
        self.id = id
        self.label = label
        self.paging = paging
        self.rows = rows
        self.searchPlaceholder = searchPlaceholder
        self.searchable = searchable
        self.style = style
    }
}

// MARK: List convenience initializers and mutators

public extension List {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(List.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        id: String? = nil,
        label: String?? = nil,
        paging: PresentationPaging?? = nil,
        rows: [PresentationRow]? = nil,
        searchPlaceholder: String?? = nil,
        searchable: Bool? = nil,
        style: PresentationListStyle?? = nil
    ) -> List {
        return List(
            accessibility: accessibility ?? self.accessibility,
            id: id ?? self.id,
            label: label ?? self.label,
            paging: paging ?? self.paging,
            rows: rows ?? self.rows,
            searchPlaceholder: searchPlaceholder ?? self.searchPlaceholder,
            searchable: searchable ?? self.searchable,
            style: style ?? self.style
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Group
public struct Group: Codable {
    public let accessibility: AccessibilitySpec
    public let axis: PresentationAxis
    public let children: [PresentationNode]
    public let id: String?
    public let label: String?

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case axis = "axis"
        case children = "children"
        case id = "id"
        case label = "label"
    }

    public init(accessibility: AccessibilitySpec, axis: PresentationAxis, children: [PresentationNode], id: String?, label: String?) {
        self.accessibility = accessibility
        self.axis = axis
        self.children = children
        self.id = id
        self.label = label
    }
}

// MARK: Group convenience initializers and mutators

public extension Group {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Group.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        axis: PresentationAxis? = nil,
        children: [PresentationNode]? = nil,
        id: String?? = nil,
        label: String?? = nil
    ) -> Group {
        return Group(
            accessibility: accessibility ?? self.accessibility,
            axis: axis ?? self.axis,
            children: children ?? self.children,
            id: id ?? self.id,
            label: label ?? self.label
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PresentationNodeClass
public struct PresentationNodeClass: Codable {
    public let text: Text?
    public let input: Input?
    public let toggle: Toggle?
    public let choice: Choice?
    public let group: Group?
    public let list: List?
    public let image: Image?
    public let status: Status?
    public let qr: Qr?
    public let confirmation: Confirmation?
    public let slider: Slider?
    public let progress: Progress?

    public enum CodingKeys: String, CodingKey {
        case text = "Text"
        case input = "Input"
        case toggle = "Toggle"
        case choice = "Choice"
        case group = "Group"
        case list = "List"
        case image = "Image"
        case status = "Status"
        case qr = "Qr"
        case confirmation = "Confirmation"
        case slider = "Slider"
        case progress = "Progress"
    }

    public init(text: Text?, input: Input?, toggle: Toggle?, choice: Choice?, group: Group?, list: List?, image: Image?, status: Status?, qr: Qr?, confirmation: Confirmation?, slider: Slider?, progress: Progress?) {
        self.text = text
        self.input = input
        self.toggle = toggle
        self.choice = choice
        self.group = group
        self.list = list
        self.image = image
        self.status = status
        self.qr = qr
        self.confirmation = confirmation
        self.slider = slider
        self.progress = progress
    }
}

// MARK: PresentationNodeClass convenience initializers and mutators

public extension PresentationNodeClass {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentationNodeClass.self, from: data)
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
        text: Text?? = nil,
        input: Input?? = nil,
        toggle: Toggle?? = nil,
        choice: Choice?? = nil,
        group: Group?? = nil,
        list: List?? = nil,
        image: Image?? = nil,
        status: Status?? = nil,
        qr: Qr?? = nil,
        confirmation: Confirmation?? = nil,
        slider: Slider?? = nil,
        progress: Progress?? = nil
    ) -> PresentationNodeClass {
        return PresentationNodeClass(
            text: text ?? self.text,
            input: input ?? self.input,
            toggle: toggle ?? self.toggle,
            choice: choice ?? self.choice,
            group: group ?? self.group,
            list: list ?? self.list,
            image: image ?? self.image,
            status: status ?? self.status,
            qr: qr ?? self.qr,
            confirmation: confirmation ?? self.confirmation,
            slider: slider ?? self.slider,
            progress: progress ?? self.progress
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum PresentationNode: Codable {
    case enumeration(PresentationNodeEnum)
    case presentationNodeClass(PresentationNodeClass)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(PresentationNodeEnum.self) {
            self = .enumeration(x)
            return
        }
        if let x = try? container.decode(PresentationNodeClass.self) {
            self = .presentationNodeClass(x)
            return
        }
        throw DecodingError.typeMismatch(PresentationNode.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for PresentationNode"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .enumeration(let x):
            try container.encode(x)
        case .presentationNodeClass(let x):
            try container.encode(x)
        }
    }
}

// MARK: - AccessibilitySpec
public struct AccessibilitySpec: Codable {
    public let description: String?
    public let label: String

    public enum CodingKeys: String, CodingKey {
        case description = "description"
        case label = "label"
    }

    public init(description: String?, label: String) {
        self.description = description
        self.label = label
    }
}

// MARK: AccessibilitySpec convenience initializers and mutators

public extension AccessibilitySpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(AccessibilitySpec.self, from: data)
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
        description: String?? = nil,
        label: String? = nil
    ) -> AccessibilitySpec {
        return AccessibilitySpec(
            description: description ?? self.description,
            label: label ?? self.label
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PresentationPaging
public struct PresentationPaging: Codable {
    public let offset: Int
    public let totalCount: Int
    public let window: Int

    public enum CodingKeys: String, CodingKey {
        case offset = "offset"
        case totalCount = "total_count"
        case window = "window"
    }

    public init(offset: Int, totalCount: Int, window: Int) {
        self.offset = offset
        self.totalCount = totalCount
        self.window = window
    }
}

// MARK: PresentationPaging convenience initializers and mutators

public extension PresentationPaging {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentationPaging.self, from: data)
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
        offset: Int? = nil,
        totalCount: Int? = nil,
        window: Int? = nil
    ) -> PresentationPaging {
        return PresentationPaging(
            offset: offset ?? self.offset,
            totalCount: totalCount ?? self.totalCount,
            window: window ?? self.window
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Omitted on the wire when `Rows`, so every existing fixture and shell keeps working
/// unchanged.
///
/// How a shell draws a `List`'s rows. `Rows` is the ordinary list; `Buttons` draws each
/// activatable row as a native button, for a short set of commands that must read as
/// tappable at a glance (the exchange screen's switch-camera and cancel beside the camera
/// preview).
public enum PresentationListStyle: String, Codable {
    case buttons = "buttons"
    case rows = "rows"
}

public enum PresentationAxis: String, Codable {
    case horizontal = "horizontal"
    case vertical = "vertical"
}

// MARK: - Choice
public struct Choice: Codable {
    public let accessibility: AccessibilitySpec
    public let bindingID: String
    public let enabled: Bool
    public let label: String
    public let options: [ChoiceOption]
    public let selected: String?

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case bindingID = "binding_id"
        case enabled = "enabled"
        case label = "label"
        case options = "options"
        case selected = "selected"
    }

    public init(accessibility: AccessibilitySpec, bindingID: String, enabled: Bool, label: String, options: [ChoiceOption], selected: String?) {
        self.accessibility = accessibility
        self.bindingID = bindingID
        self.enabled = enabled
        self.label = label
        self.options = options
        self.selected = selected
    }
}

// MARK: Choice convenience initializers and mutators

public extension Choice {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Choice.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        bindingID: String? = nil,
        enabled: Bool? = nil,
        label: String? = nil,
        options: [ChoiceOption]? = nil,
        selected: String?? = nil
    ) -> Choice {
        return Choice(
            accessibility: accessibility ?? self.accessibility,
            bindingID: bindingID ?? self.bindingID,
            enabled: enabled ?? self.enabled,
            label: label ?? self.label,
            options: options ?? self.options,
            selected: selected ?? self.selected
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ChoiceOption
public struct ChoiceOption: Codable {
    public let id: String
    public let label: String

    public enum CodingKeys: String, CodingKey {
        case id = "id"
        case label = "label"
    }

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

// MARK: ChoiceOption convenience initializers and mutators

public extension ChoiceOption {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ChoiceOption.self, from: data)
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
        label: String? = nil
    ) -> ChoiceOption {
        return ChoiceOption(
            id: id ?? self.id,
            label: label ?? self.label
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Confirmation
public struct Confirmation: Codable {
    public let accessibility: AccessibilitySpec
    public let cancel: ActionSpec
    public let confirm: ActionSpec
    public let id: String
    public let warning: String

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case cancel = "cancel"
        case confirm = "confirm"
        case id = "id"
        case warning = "warning"
    }

    public init(accessibility: AccessibilitySpec, cancel: ActionSpec, confirm: ActionSpec, id: String, warning: String) {
        self.accessibility = accessibility
        self.cancel = cancel
        self.confirm = confirm
        self.id = id
        self.warning = warning
    }
}

// MARK: Confirmation convenience initializers and mutators

public extension Confirmation {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Confirmation.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        cancel: ActionSpec? = nil,
        confirm: ActionSpec? = nil,
        id: String? = nil,
        warning: String? = nil
    ) -> Confirmation {
        return Confirmation(
            accessibility: accessibility ?? self.accessibility,
            cancel: cancel ?? self.cancel,
            confirm: confirm ?? self.confirm,
            id: id ?? self.id,
            warning: warning ?? self.warning
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - Image
public struct Image: Codable {
    public let accessibility: AccessibilitySpec
    public let activation: ActionSpec?
    public let brightness: Double
    public let data: [Int]?
    public let fallbackText: String?
    public let id: String?
    public let shape: PresentationImageShape
    /// Square, in logical units, the picture is fitted into with its aspect kept and never wider
    /// than the space it is given. `None` leaves the shell's own sizing (avatars size from the
    /// touch target). Absent on the wire when `None`, so shells that predate it keep decoding.
    public let size: Int?

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case activation = "activation"
        case brightness = "brightness"
        case data = "data"
        case fallbackText = "fallback_text"
        case id = "id"
        case shape = "shape"
        case size = "size"
    }

    public init(accessibility: AccessibilitySpec, activation: ActionSpec?, brightness: Double, data: [Int]?, fallbackText: String?, id: String?, shape: PresentationImageShape, size: Int?) {
        self.accessibility = accessibility
        self.activation = activation
        self.brightness = brightness
        self.data = data
        self.fallbackText = fallbackText
        self.id = id
        self.shape = shape
        self.size = size
    }
}

// MARK: Image convenience initializers and mutators

public extension Image {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Image.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        activation: ActionSpec?? = nil,
        brightness: Double? = nil,
        data: [Int]?? = nil,
        fallbackText: String?? = nil,
        id: String?? = nil,
        shape: PresentationImageShape? = nil,
        size: Int?? = nil
    ) -> Image {
        return Image(
            accessibility: accessibility ?? self.accessibility,
            activation: activation ?? self.activation,
            brightness: brightness ?? self.brightness,
            data: data ?? self.data,
            fallbackText: fallbackText ?? self.fallbackText,
            id: id ?? self.id,
            shape: shape ?? self.shape,
            size: size ?? self.size
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum PresentationImageShape: String, Codable {
    case circle = "circle"
    case natural = "natural"
}

// MARK: - Input
public struct Input: Codable {
    public let accessibility: AccessibilitySpec
    public let bindingID: String
    public let enabled: Bool
    public let inputKind: PresentationInputKind
    public let label: String
    public let maxLength: Int?
    public let placeholder: String?
    public let validationError: String?
    public let value: String

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case bindingID = "binding_id"
        case enabled = "enabled"
        case inputKind = "input_kind"
        case label = "label"
        case maxLength = "max_length"
        case placeholder = "placeholder"
        case validationError = "validation_error"
        case value = "value"
    }

    public init(accessibility: AccessibilitySpec, bindingID: String, enabled: Bool, inputKind: PresentationInputKind, label: String, maxLength: Int?, placeholder: String?, validationError: String?, value: String) {
        self.accessibility = accessibility
        self.bindingID = bindingID
        self.enabled = enabled
        self.inputKind = inputKind
        self.label = label
        self.maxLength = maxLength
        self.placeholder = placeholder
        self.validationError = validationError
        self.value = value
    }
}

// MARK: Input convenience initializers and mutators

public extension Input {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Input.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        bindingID: String? = nil,
        enabled: Bool? = nil,
        inputKind: PresentationInputKind? = nil,
        label: String? = nil,
        maxLength: Int?? = nil,
        placeholder: String?? = nil,
        validationError: String?? = nil,
        value: String? = nil
    ) -> Input {
        return Input(
            accessibility: accessibility ?? self.accessibility,
            bindingID: bindingID ?? self.bindingID,
            enabled: enabled ?? self.enabled,
            inputKind: inputKind ?? self.inputKind,
            label: label ?? self.label,
            maxLength: maxLength ?? self.maxLength,
            placeholder: placeholder ?? self.placeholder,
            validationError: validationError ?? self.validationError,
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

public enum PresentationInputKind: String, Codable {
    case email = "email"
    case number = "number"
    case password = "password"
    case phone = "phone"
    case pin = "pin"
    case search = "search"
    case text = "text"
    case url = "url"
}

// MARK: - Progress
public struct Progress: Codable {
    public let accessibility: AccessibilitySpec
    public let label: String?
    public let value: Double?

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case label = "label"
        case value = "value"
    }

    public init(accessibility: AccessibilitySpec, label: String?, value: Double?) {
        self.accessibility = accessibility
        self.label = label
        self.value = value
    }
}

// MARK: Progress convenience initializers and mutators

public extension Progress {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Progress.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        label: String?? = nil,
        value: Double?? = nil
    ) -> Progress {
        return Progress(
            accessibility: accessibility ?? self.accessibility,
            label: label ?? self.label,
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

// MARK: - Qr
public struct Qr: Codable {
    public let accessibility: AccessibilitySpec
    /// A capture's text field placeholder, prepared by Core. Omitted on the wire when absent;
    /// the field then shows none.
    public let capturePlaceholder: String?
    /// A capture's submit button label, prepared by Core. Omitted on the wire when absent; the
    /// button is then named by `accessibility`.
    public let captureSubmitLabel: String?
    /// The error-correction level to draw a display code at. Absent leaves it to the shell,
    /// which draws at medium.
    public let errorCorrection: PresentationQrErrorCorrection?
    public let id: String
    public let label: String?
    public let payloads: [String]
    /// Where in the node's square to draw a display code. Absent means the full square, centred.
    public let placement: QrPlacement?
    public let purpose: PresentationQrPurpose
    /// The size of a display code's square. Absent means standard.
    public let size: PresentationQrSize?

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case capturePlaceholder = "capture_placeholder"
        case captureSubmitLabel = "capture_submit_label"
        case errorCorrection = "error_correction"
        case id = "id"
        case label = "label"
        case payloads = "payloads"
        case placement = "placement"
        case purpose = "purpose"
        case size = "size"
    }

    public init(accessibility: AccessibilitySpec, capturePlaceholder: String?, captureSubmitLabel: String?, errorCorrection: PresentationQrErrorCorrection?, id: String, label: String?, payloads: [String], placement: QrPlacement?, purpose: PresentationQrPurpose, size: PresentationQrSize?) {
        self.accessibility = accessibility
        self.capturePlaceholder = capturePlaceholder
        self.captureSubmitLabel = captureSubmitLabel
        self.errorCorrection = errorCorrection
        self.id = id
        self.label = label
        self.payloads = payloads
        self.placement = placement
        self.purpose = purpose
        self.size = size
    }
}

// MARK: Qr convenience initializers and mutators

public extension Qr {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Qr.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        capturePlaceholder: String?? = nil,
        captureSubmitLabel: String?? = nil,
        errorCorrection: PresentationQrErrorCorrection?? = nil,
        id: String? = nil,
        label: String?? = nil,
        payloads: [String]? = nil,
        placement: QrPlacement?? = nil,
        purpose: PresentationQrPurpose? = nil,
        size: PresentationQrSize?? = nil
    ) -> Qr {
        return Qr(
            accessibility: accessibility ?? self.accessibility,
            capturePlaceholder: capturePlaceholder ?? self.capturePlaceholder,
            captureSubmitLabel: captureSubmitLabel ?? self.captureSubmitLabel,
            errorCorrection: errorCorrection ?? self.errorCorrection,
            id: id ?? self.id,
            label: label ?? self.label,
            payloads: payloads ?? self.payloads,
            placement: placement ?? self.placement,
            purpose: purpose ?? self.purpose,
            size: size ?? self.size
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// How much of a display code is redundancy. Lower levels fit the same payload in fewer,
/// larger modules, which a camera resolves from closer or through more blur; higher levels
/// survive more damage.
public enum PresentationQrErrorCorrection: String, Codable {
    case low = "low"
    case medium = "medium"
}

/// Where inside its square a display code is drawn: the code's side and the offset of its
/// top-left corner, in permille of the square's side.
///
/// Built only through [`Self::new`] and deserialisation, both of which keep the code inside
/// the square and at least half its side, so a held value never asks a shell to draw outside
/// its node.
// MARK: - QrPlacement
public struct QrPlacement: Codable {
    public let size: Int
    public let x: Int
    public let y: Int

    public enum CodingKeys: String, CodingKey {
        case size = "size"
        case x = "x"
        case y = "y"
    }

    public init(size: Int, x: Int, y: Int) {
        self.size = size
        self.x = x
        self.y = y
    }
}

// MARK: QrPlacement convenience initializers and mutators

public extension QrPlacement {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(QrPlacement.self, from: data)
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
        size: Int? = nil,
        x: Int? = nil,
        y: Int? = nil
    ) -> QrPlacement {
        return QrPlacement(
            size: size ?? self.size,
            x: x ?? self.x,
            y: y ?? self.y
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum PresentationQrPurpose: String, Codable {
    case capture = "capture"
    case display = "display"
}

/// How large a shell draws a display code's square. `Compact` is for a short window, where
/// the standard square would leave the camera beside it no room; each shell maps it to its
/// own smaller size.
public enum PresentationQrSize: String, Codable {
    case compact = "compact"
    case standard = "standard"
}

// MARK: - Slider
public struct Slider: Codable {
    public let accessibility: AccessibilitySpec
    public let bindingID: String
    public let label: String
    public let maximum: Double
    public let maximumIcon: String?
    public let minimum: Double
    public let minimumIcon: String?
    public let step: Double?
    public let value: Double

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case bindingID = "binding_id"
        case label = "label"
        case maximum = "maximum"
        case maximumIcon = "maximum_icon"
        case minimum = "minimum"
        case minimumIcon = "minimum_icon"
        case step = "step"
        case value = "value"
    }

    public init(accessibility: AccessibilitySpec, bindingID: String, label: String, maximum: Double, maximumIcon: String?, minimum: Double, minimumIcon: String?, step: Double?, value: Double) {
        self.accessibility = accessibility
        self.bindingID = bindingID
        self.label = label
        self.maximum = maximum
        self.maximumIcon = maximumIcon
        self.minimum = minimum
        self.minimumIcon = minimumIcon
        self.step = step
        self.value = value
    }
}

// MARK: Slider convenience initializers and mutators

public extension Slider {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Slider.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        bindingID: String? = nil,
        label: String? = nil,
        maximum: Double? = nil,
        maximumIcon: String?? = nil,
        minimum: Double? = nil,
        minimumIcon: String?? = nil,
        step: Double?? = nil,
        value: Double? = nil
    ) -> Slider {
        return Slider(
            accessibility: accessibility ?? self.accessibility,
            bindingID: bindingID ?? self.bindingID,
            label: label ?? self.label,
            maximum: maximum ?? self.maximum,
            maximumIcon: maximumIcon ?? self.maximumIcon,
            minimum: minimum ?? self.minimum,
            minimumIcon: minimumIcon ?? self.minimumIcon,
            step: step ?? self.step,
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

// MARK: - Status
public struct Status: Codable {
    public let accessibility: AccessibilitySpec
    public let activation: ActionSpec?
    public let badge: String?
    public let detail: String?
    public let iconToken: String?
    public let id: String?
    public let title: String
    public let tone: PresentationTone

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case activation = "activation"
        case badge = "badge"
        case detail = "detail"
        case iconToken = "icon_token"
        case id = "id"
        case title = "title"
        case tone = "tone"
    }

    public init(accessibility: AccessibilitySpec, activation: ActionSpec?, badge: String?, detail: String?, iconToken: String?, id: String?, title: String, tone: PresentationTone) {
        self.accessibility = accessibility
        self.activation = activation
        self.badge = badge
        self.detail = detail
        self.iconToken = iconToken
        self.id = id
        self.title = title
        self.tone = tone
    }
}

// MARK: Status convenience initializers and mutators

public extension Status {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Status.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        activation: ActionSpec?? = nil,
        badge: String?? = nil,
        detail: String?? = nil,
        iconToken: String?? = nil,
        id: String?? = nil,
        title: String? = nil,
        tone: PresentationTone? = nil
    ) -> Status {
        return Status(
            accessibility: accessibility ?? self.accessibility,
            activation: activation ?? self.activation,
            badge: badge ?? self.badge,
            detail: detail ?? self.detail,
            iconToken: iconToken ?? self.iconToken,
            id: id ?? self.id,
            title: title ?? self.title,
            tone: tone ?? self.tone
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum PresentationTone: String, Codable {
    case accent = "accent"
    case error = "error"
    case neutral = "neutral"
    case success = "success"
    case warning = "warning"
}

// MARK: - Text
public struct Text: Codable {
    public let accessibility: AccessibilitySpec
    public let content: String
    public let id: String?
    public let style: PresentationTextStyle

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case content = "content"
        case id = "id"
        case style = "style"
    }

    public init(accessibility: AccessibilitySpec, content: String, id: String?, style: PresentationTextStyle) {
        self.accessibility = accessibility
        self.content = content
        self.id = id
        self.style = style
    }
}

// MARK: Text convenience initializers and mutators

public extension Text {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Text.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        content: String? = nil,
        id: String?? = nil,
        style: PresentationTextStyle? = nil
    ) -> Text {
        return Text(
            accessibility: accessibility ?? self.accessibility,
            content: content ?? self.content,
            id: id ?? self.id,
            style: style ?? self.style
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum PresentationTextStyle: String, Codable {
    case body = "body"
    case caption = "caption"
    case heading = "heading"
    case monospace = "monospace"
    case muted = "muted"
}

// MARK: - Toggle
public struct Toggle: Codable {
    public let accessibility: AccessibilitySpec
    public let bindingID: String
    public let enabled: Bool
    public let label: String
    public let value: Bool

    public enum CodingKeys: String, CodingKey {
        case accessibility = "accessibility"
        case bindingID = "binding_id"
        case enabled = "enabled"
        case label = "label"
        case value = "value"
    }

    public init(accessibility: AccessibilitySpec, bindingID: String, enabled: Bool, label: String, value: Bool) {
        self.accessibility = accessibility
        self.bindingID = bindingID
        self.enabled = enabled
        self.label = label
        self.value = value
    }
}

// MARK: Toggle convenience initializers and mutators

public extension Toggle {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Toggle.self, from: data)
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
        accessibility: AccessibilitySpec? = nil,
        bindingID: String? = nil,
        enabled: Bool? = nil,
        label: String? = nil,
        value: Bool? = nil
    ) -> Toggle {
        return Toggle(
            accessibility: accessibility ?? self.accessibility,
            bindingID: bindingID ?? self.bindingID,
            enabled: enabled ?? self.enabled,
            label: label ?? self.label,
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

public enum PresentationNodeEnum: String, Codable {
    case divider = "Divider"
}

// MARK: - PresentationTokens
public struct PresentationTokens: Codable {
    public let colors: PresentationColors
    public let cornerRadius: Int
    /// The theme's font families, so a display shell renders them from the batch (ADR-078 step
    /// 4c). Absent from a Core that predates it; a shell then keeps its bundled families.
    public let fonts: PresentationFonts?
    public let minimumTargetSize: Int
    public let spacingLarge: Int
    public let spacingMedium: Int
    public let spacingSmall: Int

    public enum CodingKeys: String, CodingKey {
        case colors = "colors"
        case cornerRadius = "corner_radius"
        case fonts = "fonts"
        case minimumTargetSize = "minimum_target_size"
        case spacingLarge = "spacing_large"
        case spacingMedium = "spacing_medium"
        case spacingSmall = "spacing_small"
    }

    public init(colors: PresentationColors, cornerRadius: Int, fonts: PresentationFonts?, minimumTargetSize: Int, spacingLarge: Int, spacingMedium: Int, spacingSmall: Int) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.fonts = fonts
        self.minimumTargetSize = minimumTargetSize
        self.spacingLarge = spacingLarge
        self.spacingMedium = spacingMedium
        self.spacingSmall = spacingSmall
    }
}

// MARK: PresentationTokens convenience initializers and mutators

public extension PresentationTokens {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentationTokens.self, from: data)
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
        colors: PresentationColors? = nil,
        cornerRadius: Int? = nil,
        fonts: PresentationFonts?? = nil,
        minimumTargetSize: Int? = nil,
        spacingLarge: Int? = nil,
        spacingMedium: Int? = nil,
        spacingSmall: Int? = nil
    ) -> PresentationTokens {
        return PresentationTokens(
            colors: colors ?? self.colors,
            cornerRadius: cornerRadius ?? self.cornerRadius,
            fonts: fonts ?? self.fonts,
            minimumTargetSize: minimumTargetSize ?? self.minimumTargetSize,
            spacingLarge: spacingLarge ?? self.spacingLarge,
            spacingMedium: spacingMedium ?? self.spacingMedium,
            spacingSmall: spacingSmall ?? self.spacingSmall
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// The active theme's colours by role, as `#rrggbb`. A `None` role is one the theme leaves
/// out; the shell paints its nearest required role.
// MARK: - PresentationColors
public struct PresentationColors: Codable {
    public let accent: String
    public let background: String
    public let border: String
    public let error: String
    public let focusRing: String?
    public let success: String
    public let surface: String
    public let surfaceElevated: String?
    public let surfaceInput: String?
    public let surfaceMuted: String?
    public let text: String
    public let textMuted: String
    public let textOnAccent: String?
    public let warning: String

    public enum CodingKeys: String, CodingKey {
        case accent = "accent"
        case background = "background"
        case border = "border"
        case error = "error"
        case focusRing = "focus_ring"
        case success = "success"
        case surface = "surface"
        case surfaceElevated = "surface_elevated"
        case surfaceInput = "surface_input"
        case surfaceMuted = "surface_muted"
        case text = "text"
        case textMuted = "text_muted"
        case textOnAccent = "text_on_accent"
        case warning = "warning"
    }

    public init(accent: String, background: String, border: String, error: String, focusRing: String?, success: String, surface: String, surfaceElevated: String?, surfaceInput: String?, surfaceMuted: String?, text: String, textMuted: String, textOnAccent: String?, warning: String) {
        self.accent = accent
        self.background = background
        self.border = border
        self.error = error
        self.focusRing = focusRing
        self.success = success
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.surfaceInput = surfaceInput
        self.surfaceMuted = surfaceMuted
        self.text = text
        self.textMuted = textMuted
        self.textOnAccent = textOnAccent
        self.warning = warning
    }
}

// MARK: PresentationColors convenience initializers and mutators

public extension PresentationColors {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentationColors.self, from: data)
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
        accent: String? = nil,
        background: String? = nil,
        border: String? = nil,
        error: String? = nil,
        focusRing: String?? = nil,
        success: String? = nil,
        surface: String? = nil,
        surfaceElevated: String?? = nil,
        surfaceInput: String?? = nil,
        surfaceMuted: String?? = nil,
        text: String? = nil,
        textMuted: String? = nil,
        textOnAccent: String?? = nil,
        warning: String? = nil
    ) -> PresentationColors {
        return PresentationColors(
            accent: accent ?? self.accent,
            background: background ?? self.background,
            border: border ?? self.border,
            error: error ?? self.error,
            focusRing: focusRing ?? self.focusRing,
            success: success ?? self.success,
            surface: surface ?? self.surface,
            surfaceElevated: surfaceElevated ?? self.surfaceElevated,
            surfaceInput: surfaceInput ?? self.surfaceInput,
            surfaceMuted: surfaceMuted ?? self.surfaceMuted,
            text: text ?? self.text,
            textMuted: textMuted ?? self.textMuted,
            textOnAccent: textOnAccent ?? self.textOnAccent,
            warning: warning ?? self.warning
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// The three font families a theme names: display for titles, body for text, mono for codes
/// and identifiers.
// MARK: - PresentationFonts
public struct PresentationFonts: Codable {
    public let body: String
    public let display: String
    public let mono: String

    public enum CodingKeys: String, CodingKey {
        case body = "body"
        case display = "display"
        case mono = "mono"
    }

    public init(body: String, display: String, mono: String) {
        self.body = body
        self.display = display
        self.mono = mono
    }
}

// MARK: PresentationFonts convenience initializers and mutators

public extension PresentationFonts {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentationFonts.self, from: data)
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
        body: String? = nil,
        display: String? = nil,
        mono: String? = nil
    ) -> PresentationFonts {
        return PresentationFonts(
            body: body ?? self.body,
            display: display ?? self.display,
            mono: mono ?? self.mono
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - RequestPermission
public struct RequestPermission: Codable {
    public let transport: String

    public enum CodingKeys: String, CodingKey {
        case transport = "transport"
    }

    public init(transport: String) {
        self.transport = transport
    }
}

// MARK: RequestPermission convenience initializers and mutators

public extension RequestPermission {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RequestPermission.self, from: data)
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
    ) -> RequestPermission {
        return RequestPermission(
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

// MARK: - RevealUserPresenceSecret
public struct RevealUserPresenceSecret: Codable {
    public let prompt: String

    public enum CodingKeys: String, CodingKey {
        case prompt = "prompt"
    }

    public init(prompt: String) {
        self.prompt = prompt
    }
}

// MARK: RevealUserPresenceSecret convenience initializers and mutators

public extension RevealUserPresenceSecret {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RevealUserPresenceSecret.self, from: data)
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
        prompt: String? = nil
    ) -> RevealUserPresenceSecret {
        return RevealUserPresenceSecret(
            prompt: prompt ?? self.prompt
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - SaveRestorableState
public struct SaveRestorableState: Codable {
    public let state: String

    public enum CodingKeys: String, CodingKey {
        case state = "state"
    }

    public init(state: String) {
        self.state = state
    }
}

// MARK: SaveRestorableState convenience initializers and mutators

public extension SaveRestorableState {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SaveRestorableState.self, from: data)
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
        state: String? = nil
    ) -> SaveRestorableState {
        return SaveRestorableState(
            state: state ?? self.state
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ScheduleWakeup
public struct ScheduleWakeup: Codable {
    /// Latest the work should ideally run by; the shell picks a higher-fidelity mechanism if
    /// this is tight.
    public let deadlineSecs: Int
    /// How long the shell waits before reporting [`Event::WakeupFired`], in milliseconds:
    /// `earliest_millis`, else `earliest_secs`, never past `deadline_secs`. Core computes it so
    /// shells stop deriving it from the fields above, which they did three different ways
    /// (vauchi/private#548). Set only through `Command::schedule_wakeup`.
    public let delayMillis: Int
    /// Sub-second override for `earliest_secs`, when the work being driven is finer-grained than
    /// a second. A shell that cannot schedule below a second ignores this and uses
    /// `earliest_secs`, so it is additive.
    ///
    /// Exists because a live QR exchange advances its display from this heartbeat: whole seconds
    /// pinned it at one frame per second against a ~300 ms design, and the peer's camera decodes
    /// ~30 frames per second (device-measured 2026-08-19).
    public let earliestMillis: Int?
    /// Earliest the shell should wake core (never earlier — battery floor).
    public let earliestSecs: Int
    /// Minimum spacing between wakes the shell should honor (coalesce).
    public let minIntervalSecs: Int

    public enum CodingKeys: String, CodingKey {
        case deadlineSecs = "deadline_secs"
        case delayMillis = "delay_millis"
        case earliestMillis = "earliest_millis"
        case earliestSecs = "earliest_secs"
        case minIntervalSecs = "min_interval_secs"
    }

    public init(deadlineSecs: Int, delayMillis: Int, earliestMillis: Int?, earliestSecs: Int, minIntervalSecs: Int) {
        self.deadlineSecs = deadlineSecs
        self.delayMillis = delayMillis
        self.earliestMillis = earliestMillis
        self.earliestSecs = earliestSecs
        self.minIntervalSecs = minIntervalSecs
    }
}

// MARK: ScheduleWakeup convenience initializers and mutators

public extension ScheduleWakeup {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ScheduleWakeup.self, from: data)
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
        deadlineSecs: Int? = nil,
        delayMillis: Int? = nil,
        earliestMillis: Int?? = nil,
        earliestSecs: Int? = nil,
        minIntervalSecs: Int? = nil
    ) -> ScheduleWakeup {
        return ScheduleWakeup(
            deadlineSecs: deadlineSecs ?? self.deadlineSecs,
            delayMillis: delayMillis ?? self.delayMillis,
            earliestMillis: earliestMillis ?? self.earliestMillis,
            earliestSecs: earliestSecs ?? self.earliestSecs,
            minIntervalSecs: minIntervalSecs ?? self.minIntervalSecs
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - SetApplicationMenu
public struct SetApplicationMenu: Codable {
    public let menus: [ApplicationMenuSpec]
    public let revision: UInt64
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case menus = "menus"
        case revision = "revision"
        case surfaceID = "surface_id"
    }

    public init(menus: [ApplicationMenuSpec], revision: UInt64, surfaceID: String) {
        self.menus = menus
        self.revision = revision
        self.surfaceID = surfaceID
    }
}

// MARK: SetApplicationMenu convenience initializers and mutators

public extension SetApplicationMenu {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SetApplicationMenu.self, from: data)
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
        menus: [ApplicationMenuSpec]? = nil,
        revision: UInt64? = nil,
        surfaceID: String? = nil
    ) -> SetApplicationMenu {
        return SetApplicationMenu(
            menus: menus ?? self.menus,
            revision: revision ?? self.revision,
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

// MARK: - ApplicationMenuSpec
public struct ApplicationMenuSpec: Codable {
    public let items: [ActionSpec]
    public let label: String
    public let role: ApplicationMenuRole

    public enum CodingKeys: String, CodingKey {
        case items = "items"
        case label = "label"
        case role = "role"
    }

    public init(items: [ActionSpec], label: String, role: ApplicationMenuRole) {
        self.items = items
        self.label = label
        self.role = role
    }
}

// MARK: ApplicationMenuSpec convenience initializers and mutators

public extension ApplicationMenuSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ApplicationMenuSpec.self, from: data)
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
        items: [ActionSpec]? = nil,
        label: String? = nil,
        role: ApplicationMenuRole? = nil
    ) -> ApplicationMenuSpec {
        return ApplicationMenuSpec(
            items: items ?? self.items,
            label: label ?? self.label,
            role: role ?? self.role
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Native placement hints; action meaning remains in Core's opaque bindings.
public enum ApplicationMenuRole: String, Codable {
    case file = "file"
    case other = "other"
}

// MARK: - SetContextBar
public struct SetContextBar: Codable {
    public let bar: ContextBar
    public let revision: UInt64
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case bar = "bar"
        case revision = "revision"
        case surfaceID = "surface_id"
    }

    public init(bar: ContextBar, revision: UInt64, surfaceID: String) {
        self.bar = bar
        self.revision = revision
        self.surfaceID = surfaceID
    }
}

// MARK: SetContextBar convenience initializers and mutators

public extension SetContextBar {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SetContextBar.self, from: data)
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
        bar: ContextBar? = nil,
        revision: UInt64? = nil,
        surfaceID: String? = nil
    ) -> SetContextBar {
        return SetContextBar(
            bar: bar ?? self.bar,
            revision: revision ?? self.revision,
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

// MARK: - ContextBar
public struct ContextBar: Codable {
    public let back: ActionSpec?
    /// Explains the surface: opens an `OverlayKind::Information` overlay. Absent where Core has
    /// no text for the surface or the person turned help off; omitted on the wire so older
    /// shells see the four slots.
    public let info: ActionSpec?
    public let navigation: ActionSpec?
    public let primary: ActionSpec?
    public let secondary: ActionSpec?

    public enum CodingKeys: String, CodingKey {
        case back = "back"
        case info = "info"
        case navigation = "navigation"
        case primary = "primary"
        case secondary = "secondary"
    }

    public init(back: ActionSpec?, info: ActionSpec?, navigation: ActionSpec?, primary: ActionSpec?, secondary: ActionSpec?) {
        self.back = back
        self.info = info
        self.navigation = navigation
        self.primary = primary
        self.secondary = secondary
    }
}

// MARK: ContextBar convenience initializers and mutators

public extension ContextBar {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ContextBar.self, from: data)
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
        back: ActionSpec?? = nil,
        info: ActionSpec?? = nil,
        navigation: ActionSpec?? = nil,
        primary: ActionSpec?? = nil,
        secondary: ActionSpec?? = nil
    ) -> ContextBar {
        return ContextBar(
            back: back ?? self.back,
            info: info ?? self.info,
            navigation: navigation ?? self.navigation,
            primary: primary ?? self.primary,
            secondary: secondary ?? self.secondary
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - SetIdleTimerDisabled
public struct SetIdleTimerDisabled: Codable {
    public let disabled: Bool

    public enum CodingKeys: String, CodingKey {
        case disabled = "disabled"
    }

    public init(disabled: Bool) {
        self.disabled = disabled
    }
}

// MARK: SetIdleTimerDisabled convenience initializers and mutators

public extension SetIdleTimerDisabled {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SetIdleTimerDisabled.self, from: data)
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
        disabled: Bool? = nil
    ) -> SetIdleTimerDisabled {
        return SetIdleTimerDisabled(
            disabled: disabled ?? self.disabled
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - SetNavigation
public struct SetNavigation: Codable {
    public let navigation: NavigationSpec
    public let revision: UInt64
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case navigation = "navigation"
        case revision = "revision"
        case surfaceID = "surface_id"
    }

    public init(navigation: NavigationSpec, revision: UInt64, surfaceID: String) {
        self.navigation = navigation
        self.revision = revision
        self.surfaceID = surfaceID
    }
}

// MARK: SetNavigation convenience initializers and mutators

public extension SetNavigation {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SetNavigation.self, from: data)
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
        navigation: NavigationSpec? = nil,
        revision: UInt64? = nil,
        surfaceID: String? = nil
    ) -> SetNavigation {
        return SetNavigation(
            navigation: navigation ?? self.navigation,
            revision: revision ?? self.revision,
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

/// The complete set of persistent navigation destinations for a surface. Empty when the
/// surface offers no destinations (e.g. a locked app), so a shell hides the bar rather than
/// rendering it with nothing in it.
// MARK: - NavigationSpec
public struct NavigationSpec: Codable {
    public let items: [NavigationItem]

    public enum CodingKeys: String, CodingKey {
        case items = "items"
    }

    public init(items: [NavigationItem]) {
        self.items = items
    }
}

// MARK: NavigationSpec convenience initializers and mutators

public extension NavigationSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NavigationSpec.self, from: data)
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
        items: [NavigationItem]? = nil
    ) -> NavigationSpec {
        return NavigationSpec(
            items: items ?? self.items
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// One destination in the persistent navigation surface (bottom bar on phone, sidebar on
/// desktop). Reuses the same opaque `interaction_id` an equivalent overlay item would use,
/// so a tap routes identically whether the shell renders it persistently or inside
/// `PresentOverlay`.
// MARK: - NavigationItem
public struct NavigationItem: Codable {
    public let accessibilityLabel: String
    public let badgeCount: Int
    public let iconToken: String?
    public let interactionID: String
    public let label: String
    public let selected: Bool

    public enum CodingKeys: String, CodingKey {
        case accessibilityLabel = "accessibility_label"
        case badgeCount = "badge_count"
        case iconToken = "icon_token"
        case interactionID = "interaction_id"
        case label = "label"
        case selected = "selected"
    }

    public init(accessibilityLabel: String, badgeCount: Int, iconToken: String?, interactionID: String, label: String, selected: Bool) {
        self.accessibilityLabel = accessibilityLabel
        self.badgeCount = badgeCount
        self.iconToken = iconToken
        self.interactionID = interactionID
        self.label = label
        self.selected = selected
    }
}

// MARK: NavigationItem convenience initializers and mutators

public extension NavigationItem {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(NavigationItem.self, from: data)
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
        accessibilityLabel: String? = nil,
        badgeCount: Int? = nil,
        iconToken: String?? = nil,
        interactionID: String? = nil,
        label: String? = nil,
        selected: Bool? = nil
    ) -> NavigationItem {
        return NavigationItem(
            accessibilityLabel: accessibilityLabel ?? self.accessibilityLabel,
            badgeCount: badgeCount ?? self.badgeCount,
            iconToken: iconToken ?? self.iconToken,
            interactionID: interactionID ?? self.interactionID,
            label: label ?? self.label,
            selected: selected ?? self.selected
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - SetOrientationLock
public struct SetOrientationLock: Codable {
    public let orientation: Orientation?

    public enum CodingKeys: String, CodingKey {
        case orientation = "orientation"
    }

    public init(orientation: Orientation?) {
        self.orientation = orientation
    }
}

// MARK: SetOrientationLock convenience initializers and mutators

public extension SetOrientationLock {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SetOrientationLock.self, from: data)
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
        orientation: Orientation?? = nil
    ) -> SetOrientationLock {
        return SetOrientationLock(
            orientation: orientation ?? self.orientation
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Portrait, top of the device pointing up.
///
/// Landscape, with no preference for left or right rotation. Most platforms map this to
/// "user-rotatable landscape" (the device can rotate between left and right freely while
/// staying landscape-locked).
public enum Orientation: String, Codable {
    case landscape = "Landscape"
    case portrait = "Portrait"
}

// MARK: - SetPresentationProfile
public struct SetPresentationProfile: Codable {
    public let profile: PresentationProfile

    public enum CodingKeys: String, CodingKey {
        case profile = "profile"
    }

    public init(profile: PresentationProfile) {
        self.profile = profile
    }
}

// MARK: SetPresentationProfile convenience initializers and mutators

public extension SetPresentationProfile {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SetPresentationProfile.self, from: data)
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
        profile: PresentationProfile? = nil
    ) -> SetPresentationProfile {
        return SetPresentationProfile(
            profile: profile ?? self.profile
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - PresentationProfile
public struct PresentationProfile: Codable {
    public let activeSurface: String
    public let detailSurface: String?
    public let paneLayout: PaneLayout
    public let primarySurface: String
    public let windowClass: WindowClass
    /// The window's title, prepared by Core so the shell picks no copy of its own (ADR-066).
    /// Omitted on the wire when absent; a shell then leaves the title it has.
    public let windowTitle: String?

    public enum CodingKeys: String, CodingKey {
        case activeSurface = "active_surface"
        case detailSurface = "detail_surface"
        case paneLayout = "pane_layout"
        case primarySurface = "primary_surface"
        case windowClass = "window_class"
        case windowTitle = "window_title"
    }

    public init(activeSurface: String, detailSurface: String?, paneLayout: PaneLayout, primarySurface: String, windowClass: WindowClass, windowTitle: String?) {
        self.activeSurface = activeSurface
        self.detailSurface = detailSurface
        self.paneLayout = paneLayout
        self.primarySurface = primarySurface
        self.windowClass = windowClass
        self.windowTitle = windowTitle
    }
}

// MARK: PresentationProfile convenience initializers and mutators

public extension PresentationProfile {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PresentationProfile.self, from: data)
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
        activeSurface: String? = nil,
        detailSurface: String?? = nil,
        paneLayout: PaneLayout? = nil,
        primarySurface: String? = nil,
        windowClass: WindowClass? = nil,
        windowTitle: String?? = nil
    ) -> PresentationProfile {
        return PresentationProfile(
            activeSurface: activeSurface ?? self.activeSurface,
            detailSurface: detailSurface ?? self.detailSurface,
            paneLayout: paneLayout ?? self.paneLayout,
            primarySurface: primarySurface ?? self.primarySurface,
            windowClass: windowClass ?? self.windowClass,
            windowTitle: windowTitle ?? self.windowTitle
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum PaneLayout: String, Codable {
    case single = "single"
    case split = "split"
}

public enum WindowClass: String, Codable {
    case compact = "compact"
    case expanded = "expanded"
    case medium = "medium"
}

// MARK: - SetScreenBrightness
public struct SetScreenBrightness: Codable {
    public let level: Double?

    public enum CodingKeys: String, CodingKey {
        case level = "level"
    }

    public init(level: Double?) {
        self.level = level
    }
}

// MARK: SetScreenBrightness convenience initializers and mutators

public extension SetScreenBrightness {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SetScreenBrightness.self, from: data)
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
        level: Double?? = nil
    ) -> SetScreenBrightness {
        return SetScreenBrightness(
            level: level ?? self.level
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - SetStatusItem
public struct SetStatusItem: Codable {
    public let item: StatusItemSpec?
    public let revision: UInt64
    public let surfaceID: String

    public enum CodingKeys: String, CodingKey {
        case item = "item"
        case revision = "revision"
        case surfaceID = "surface_id"
    }

    public init(item: StatusItemSpec?, revision: UInt64, surfaceID: String) {
        self.item = item
        self.revision = revision
        self.surfaceID = surfaceID
    }
}

// MARK: SetStatusItem convenience initializers and mutators

public extension SetStatusItem {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SetStatusItem.self, from: data)
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
        item: StatusItemSpec?? = nil,
        revision: UInt64? = nil,
        surfaceID: String? = nil
    ) -> SetStatusItem {
        return SetStatusItem(
            item: item ?? self.item,
            revision: revision ?? self.revision,
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

/// A native status item (system tray icon) and its menu. Core prepares the copy; raising the
/// window and native Quit stay with the shell, as for the application menu.
// MARK: - StatusItemSpec
public struct StatusItemSpec: Codable {
    /// Core's own items, between the window item and native Quit.
    public let items: [ActionSpec]
    /// The label of the shell-owned item that raises the window.
    public let showWindowLabel: String
    public let tooltip: String

    public enum CodingKeys: String, CodingKey {
        case items = "items"
        case showWindowLabel = "show_window_label"
        case tooltip = "tooltip"
    }

    public init(items: [ActionSpec], showWindowLabel: String, tooltip: String) {
        self.items = items
        self.showWindowLabel = showWindowLabel
        self.tooltip = tooltip
    }
}

// MARK: StatusItemSpec convenience initializers and mutators

public extension StatusItemSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(StatusItemSpec.self, from: data)
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
        items: [ActionSpec]? = nil,
        showWindowLabel: String? = nil,
        tooltip: String? = nil
    ) -> StatusItemSpec {
        return StatusItemSpec(
            items: items ?? self.items,
            showWindowLabel: showWindowLabel ?? self.showWindowLabel,
            tooltip: tooltip ?? self.tooltip
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ShowShareSheet
public struct ShowShareSheet: Codable {
    public let url: String

    public enum CodingKeys: String, CodingKey {
        case url = "url"
    }

    public init(url: String) {
        self.url = url
    }
}

// MARK: ShowShareSheet convenience initializers and mutators

public extension ShowShareSheet {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ShowShareSheet.self, from: data)
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
        url: String? = nil
    ) -> ShowShareSheet {
        return ShowShareSheet(
            url: url ?? self.url
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ShowToast
public struct ShowToast: Codable {
    public let toast: ToastSpec

    public enum CodingKeys: String, CodingKey {
        case toast = "toast"
    }

    public init(toast: ToastSpec) {
        self.toast = toast
    }
}

// MARK: ShowToast convenience initializers and mutators

public extension ShowToast {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ShowToast.self, from: data)
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
        toast: ToastSpec? = nil
    ) -> ShowToast {
        return ShowToast(
            toast: toast ?? self.toast
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - ToastSpec
public struct ToastSpec: Codable {
    public let message: String

    public enum CodingKeys: String, CodingKey {
        case message = "message"
    }

    public init(message: String) {
        self.message = message
    }
}

// MARK: ToastSpec convenience initializers and mutators

public extension ToastSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ToastSpec.self, from: data)
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
        message: String? = nil
    ) -> ToastSpec {
        return ToastSpec(
            message: message ?? self.message
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

// MARK: - SwitchCamera
public struct SwitchCamera: Codable {
    public let useFront: Bool

    public enum CodingKeys: String, CodingKey {
        case useFront = "use_front"
    }

    public init(useFront: Bool) {
        self.useFront = useFront
    }
}

// MARK: SwitchCamera convenience initializers and mutators

public extension SwitchCamera {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(SwitchCamera.self, from: data)
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
        useFront: Bool? = nil
    ) -> SwitchCamera {
        return SwitchCamera(
            useFront: useFront ?? self.useFront
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

/// Request the frontend to open a QR scanner (camera).
///
/// Deactivate the NFC interface.
///
/// Stop all audio operations.
///
/// Start accelerometer sampling for proximity verification.
///
/// Stop accelerometer sampling.
///
/// Stop BLE scanning (saves battery after discovery completes).
///
/// Request the frontend to open the device photo library / gallery.
///
/// Frontend should return [`Event::ImageReceived`] with the selected image bytes, or
/// [`Event::ImagePickCancelled`] if the user dismisses the picker.
///
/// Request the frontend to capture an image from the device camera.
///
/// Frontend should return [`Event::ImageReceived`] with the captured image bytes, or
/// [`Event::ImagePickCancelled`] if the user cancels.
///
/// Request the frontend to open a file picker for image files.
///
/// Used on desktop platforms where a photo library may not exist. Frontend should return
/// [`Event::ImageReceived`] with the selected image bytes, or [`Event::ImagePickCancelled`]
/// if the user cancels.
///
/// Perform the platform's default back behavior.
///
/// Reset platform-owned application state after Core wiped its data.
///
/// The theme catalog changed: read the selected theme again and apply it. Shells apply
/// themes natively, so new themes otherwise wait for a restart (vauchi/private#733).
///
/// Run the platform biometric prompt (LAContext, BiometricPrompt) for the lock screen's
/// biometric unlock action. Success arrives as [`Event::BiometricUnlockSucceeded`]; a shell
/// without the hardware answers [`Event::HardwareUnavailable`].
///
/// Stop the advertising [`Command::BleStartAdvertising`] started; the hardware shell keeps
/// advertising until Core sends this (ADR-077).
public enum CommandEnum: String, Codable {
    case accelerometerStart = "AccelerometerStart"
    case accelerometerStop = "AccelerometerStop"
    case audioStop = "AudioStop"
    case bleStopAdvertising = "BleStopAdvertising"
    case bleStopScanning = "BleStopScanning"
    case imageCaptureFromCamera = "ImageCaptureFromCamera"
    case imagePickFromFile = "ImagePickFromFile"
    case imagePickFromLibrary = "ImagePickFromLibrary"
    case nfcDeactivate = "NfcDeactivate"
    case performNativeBack = "PerformNativeBack"
    case qrRequestScan = "QrRequestScan"
    case reloadTheme = "ReloadTheme"
    case requestBiometricUnlock = "RequestBiometricUnlock"
    case resetApplication = "ResetApplication"
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
