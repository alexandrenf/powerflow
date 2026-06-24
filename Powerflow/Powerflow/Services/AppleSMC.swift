import Foundation
import IOKit

final class AppleSMC {
    private var connection: io_connect_t = 0
    private var keyInfoCache: [UInt32: (dataSize: UInt32, dataType: UInt32, dataAttributes: UInt8)] = [:]

    private static let kernelIndexSMC: UInt32 = 2
    private static let cmdReadBytes: UInt8 = 5
    private static let cmdReadKeyInfo: UInt8 = 9
    private static let structSize = 80

    private static let sensorKeys = [
        "PPBR", "PDTR", "PSTR", "PHPC", "PDBR",
        "B0FC", "SBAR", "CHCC", "B0TE", "B0TF", "TB0T",
    ]

    init() throws {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleSMC")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { throw SMCError.ioError(kr) }
        defer { IOObjectRelease(iterator) }

        let device = IOIteratorNext(iterator)
        guard device != 0 else { throw SMCError.serviceNotFound }
        defer { IOObjectRelease(device) }

        let openResult = IOServiceOpen(device, mach_task_self_, 0, &connection)
        guard openResult == KERN_SUCCESS else { throw SMCError.ioError(openResult) }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func readPowerData() -> SMCPowerData {
        var data = SMCPowerData()
        for key in Self.sensorKeys {
            guard let value = try? readKey(key) else { continue }
            switch key {
            case "PPBR": data.batteryRate = value
            case "PDTR": data.deliveryRate = value
            case "PSTR": data.systemTotal = value
            case "PHPC": data.heatpipe = value
            case "PDBR": data.brightness = value
            case "B0FC": data.fullChargeCapacity = value
            case "SBAR": data.currentCapacity = value
            case "CHCC": data.chargingStatus = value
            case "B0TE": data.timeToEmpty = value
            case "B0TF": data.timeToFull = value
            case "TB0T": data.temperature = value
            default: break
            }
        }
        return data
    }

    private func readKey(_ key: String) throws -> Float {
        let keyInt = Self.strToU32(key)
        let keyInfo = try getKeyInfo(keyInt)

        var input = SMCKeyDataBuffer.zeroed()
        input.setKey(keyInt)
        input.setData8(Self.cmdReadBytes)
        input.setKeyInfo(dataSize: keyInfo.dataSize, dataType: keyInfo.dataType, dataAttributes: keyInfo.dataAttributes)

        let output = try call(index: Self.kernelIndexSMC, input: input)
        return try decodeValue(
            bytes: output.bytes,
            dataSize: keyInfo.dataSize,
            dataType: keyInfo.dataType
        )
    }

    private func getKeyInfo(_ key: UInt32) throws -> (dataSize: UInt32, dataType: UInt32, dataAttributes: UInt8) {
        if let cached = keyInfoCache[key] { return cached }

        var input = SMCKeyDataBuffer.zeroed()
        input.setKey(key)
        input.setData8(Self.cmdReadKeyInfo)

        let output = try call(index: Self.kernelIndexSMC, input: input)
        let info = output.keyInfo()
        keyInfoCache[key] = info
        return info
    }

    private func call(index: UInt32, input: SMCKeyDataBuffer) throws -> SMCKeyDataBuffer {
        var output = SMCKeyDataBuffer.zeroed()
        var outputSize = Self.structSize

        let result = input.withUnsafeBytes { inputPtr in
            output.withUnsafeMutableBytes { outputPtr in
                IOConnectCallStructMethod(
                    connection,
                    index,
                    inputPtr,
                    Self.structSize,
                    outputPtr,
                    &outputSize
                )
            }
        }

        guard result == KERN_SUCCESS else { throw SMCError.ioError(result) }
        return output
    }

    private func decodeValue(bytes: [UInt8], dataSize: UInt32, dataType: UInt32) throws -> Float {
        let typeString = Self.u32ToString(dataType).trimmingCharacters(in: .whitespaces)

        switch typeString {
        case "flt ":
            return bytes.withUnsafeBytes { $0.load(as: Float.self) }
        case "ui8 ":
            return Float(bytes[0])
        case "ui16":
            return Float(bytes.withUnsafeBytes { $0.load(as: UInt16.self) })
        case "ui32":
            return Float(bytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        case "ioft", "sp78", "sp87", "sp96", "fpe2", "fp88", "fp4c", "fp5b", "sp4b", "sp5a", "sp69":
            return Self.decodeFixedPoint(typeString: typeString, bytes: bytes)
        default:
            let fallback = Self.decodeFixedPoint(typeString: typeString, bytes: bytes)
            if fallback != 0 { return fallback }
            throw SMCError.unsupportedType(typeString)
        }
    }

    private static func decodeFixedPoint(typeString: String, bytes: [UInt8]) -> Float {
        let table: [String: (Float, Bool)] = [
            "fp1f": (32768, false), "fp2e": (16384, false), "fp3d": (8192, false),
            "fp4c": (4096, false), "fp5b": (2048, false), "fp6a": (1024, false),
            "fp79": (512, false), "fp88": (256, false), "fpa6": (64, false),
            "fpc4": (16, false), "fpe2": (4, false),
            "sp1e": (16384, true), "sp2d": (8192, true), "sp3c": (4096, true),
            "sp4b": (2048, true), "sp5a": (1024, true), "sp69": (512, true),
            "sp78": (256, true), "sp87": (128, true), "sp96": (64, true),
            "spa5": (32, true), "spb4": (16, true), "spf0": (1, true),
            // IOFT power keys on Apple Silicon often use sp78 encoding
            "ioft": (256, true),
        ]

        guard let (divisor, signed) = table[typeString] else { return 0 }
        let raw = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        if signed {
            return Float(Int16(bitPattern: raw)) / divisor
        }
        return Float(raw) / divisor
    }

    private static func strToU32(_ string: String) -> UInt32 {
        let bytes = Array(string.utf8.prefix(4))
        var value: UInt32 = 0
        for byte in bytes { value = (value << 8) | UInt32(byte) }
        return value
    }

    private static func u32ToString(_ value: UInt32) -> String {
        let chars: [UInt8] = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ]
        return String(bytes: chars, encoding: .ascii) ?? ""
    }
}

enum SMCError: Error {
    case serviceNotFound
    case ioError(kern_return_t)
    case unsupportedType(String)
}

/// 80-byte SMCKeyData layout matching Apple's kernel struct (repr C).
private struct SMCKeyDataBuffer {
    private var storage: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                          UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    static func zeroed() -> SMCKeyDataBuffer {
        SMCKeyDataBuffer(storage: (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ))
    }

    var bytes: [UInt8] {
        withUnsafePointer(to: storage) { ptr in
            let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self)
            return (48..<80).map { base[$0] }
        }
    }

    mutating func setKey(_ key: UInt32) {
        writeUInt32(key, at: 0)
    }

    mutating func setData8(_ value: UInt8) {
        writeUInt8(value, at: 42)
    }

    mutating func setKeyInfo(dataSize: UInt32, dataType: UInt32, dataAttributes: UInt8) {
        writeUInt32(dataSize, at: 28)
        writeUInt32(dataType, at: 32)
        writeUInt8(dataAttributes, at: 36)
    }

    func keyInfo() -> (dataSize: UInt32, dataType: UInt32, dataAttributes: UInt8) {
        (
            readUInt32(at: 28),
            readUInt32(at: 32),
            readUInt8(at: 36)
        )
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawPointer) -> R) -> R {
        withUnsafePointer(to: storage) { ptr in
            body(UnsafeRawPointer(ptr))
        }
    }

    mutating func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawPointer) -> R) -> R {
        withUnsafeMutablePointer(to: &storage) { ptr in
            body(UnsafeMutableRawPointer(ptr))
        }
    }

    private mutating func writeUInt32(_ value: UInt32, at offset: Int) {
        withUnsafeMutablePointer(to: &storage) { ptr in
            let base = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: UInt8.self)
            base[offset] = UInt8(value >> 24)
            base[offset + 1] = UInt8((value >> 16) & 0xFF)
            base[offset + 2] = UInt8((value >> 8) & 0xFF)
            base[offset + 3] = UInt8(value & 0xFF)
        }
    }

    private mutating func writeUInt8(_ value: UInt8, at offset: Int) {
        withUnsafeMutablePointer(to: &storage) { ptr in
            UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: UInt8.self)[offset] = value
        }
    }

    private func readUInt32(at offset: Int) -> UInt32 {
        withUnsafePointer(to: storage) { ptr in
            let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self)
            return (UInt32(base[offset]) << 24)
                | (UInt32(base[offset + 1]) << 16)
                | (UInt32(base[offset + 2]) << 8)
                | UInt32(base[offset + 3])
        }
    }

    private func readUInt8(at offset: Int) -> UInt8 {
        withUnsafePointer(to: storage) { ptr in
            UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self)[offset]
        }
    }
}

#if DEBUG
enum SMCDebug {
    static func dumpKeys() {
        guard let smc = try? AppleSMC() else {
            print("SMC: failed to open")
            return
        }
        let data = smc.readPowerData()
        print("SMC deliveryRate=\(data.deliveryRate) systemTotal=\(data.systemTotal) brightness=\(data.brightness) charging=\(data.chargingStatus)")
    }
}
#endif
