import CoreAudio
import Foundation

enum SystemAudioControllerError: LocalizedError {
    case outputDeviceUnavailable
    case muteUnsupported
    case coreAudio(OSStatus)

    var errorDescription: String? {
        switch self {
        case .outputDeviceUnavailable:
            return "找不到当前系统音频输出设备。"
        case .muteUnsupported:
            return "当前音频输出设备不支持静音。"
        case .coreAudio(let status):
            return "无法修改系统音频状态（Core Audio 错误 \(status)）。"
        }
    }
}

final class SystemAudioController {
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private var volumeBeforeMute: Float32?

    func isMuted() throws -> Bool {
        let device = try defaultOutputDevice()
        if hasMuteControl(device) {
            if try readMute(device) {
                return true
            }
        }
        if hasVolumeControl(device) {
            return try readVolume(device) <= 0.001
        }
        if hasMuteControl(device) {
            return false
        }
        throw SystemAudioControllerError.muteUnsupported
    }

    @discardableResult
    func toggleMuted() throws -> Bool {
        let device = try defaultOutputDevice()
        let currentVolume = hasVolumeControl(device) ? try? readVolume(device) : nil
        let currentlyMuted: Bool
        if hasMuteControl(device) {
            currentlyMuted = try readMute(device)
        } else if hasVolumeControl(device) {
            currentlyMuted = (currentVolume ?? 0) <= 0.001
        } else {
            throw SystemAudioControllerError.muteUnsupported
        }

        if currentlyMuted {
            if hasMuteControl(device) {
                try writeMute(device, muted: false)
            }
            if hasVolumeControl(device),
               (try readVolume(device)) <= 0.001,
               let volumeBeforeMute {
                try writeVolume(device, volume: volumeBeforeMute)
            }
            return false
        }

        if let currentVolume, currentVolume > 0.001 {
            volumeBeforeMute = currentVolume
        }
        if hasMuteControl(device) {
            try writeMute(device, muted: true)
        } else if hasVolumeControl(device) {
            try writeVolume(device, volume: 0)
        } else {
            throw SystemAudioControllerError.muteUnsupported
        }
        return true
    }

    private func defaultOutputDevice() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            systemObject,
            &address,
            0,
            nil,
            &size,
            &device
        )
        guard status == noErr, device != kAudioObjectUnknown else {
            throw SystemAudioControllerError.outputDeviceUnavailable
        }
        return device
    }

    private func hasMuteControl(_ device: AudioDeviceID) -> Bool {
        var address = address(for: kAudioDevicePropertyMute)
        return AudioObjectHasProperty(device, &address)
    }

    private func hasVolumeControl(_ device: AudioDeviceID) -> Bool {
        var address = address(for: kAudioDevicePropertyVolumeScalar)
        return AudioObjectHasProperty(device, &address)
    }

    private func readMute(_ device: AudioDeviceID) throws -> Bool {
        var address = address(for: kAudioDevicePropertyMute)
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        guard status == noErr else { throw SystemAudioControllerError.coreAudio(status) }
        return value != 0
    }

    private func writeMute(_ device: AudioDeviceID, muted: Bool) throws {
        var address = address(for: kAudioDevicePropertyMute)
        var value = UInt32(muted ? 1 : 0)
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
        guard status == noErr else { throw SystemAudioControllerError.coreAudio(status) }
    }

    private func readVolume(_ device: AudioDeviceID) throws -> Float32 {
        var address = address(for: kAudioDevicePropertyVolumeScalar)
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        guard status == noErr else { throw SystemAudioControllerError.coreAudio(status) }
        return value
    }

    private func writeVolume(_ device: AudioDeviceID, volume: Float32) throws {
        var address = address(for: kAudioDevicePropertyVolumeScalar)
        var value = min(max(volume, 0), 1)
        let size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
        guard status == noErr else { throw SystemAudioControllerError.coreAudio(status) }
    }

    private func address(for selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
