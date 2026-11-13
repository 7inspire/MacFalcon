import CryptoKit
import Foundation

let input = FileHandle.standardInput.readDataToEndOfFile()
guard let encoded = String(data: input, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
      let raw = Data(base64Encoded: encoded),
      let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw),
      let info = NSDictionary(contentsOfFile: "dist/MacFalcon.app/Contents/Info.plist"),
      let expected = info["SUPublicEDKey"] as? String,
      privateKey.publicKey.rawRepresentation.base64EncodedString() == expected else {
    fputs("Sparkle signing key does not match the application's public key.\n", stderr)
    exit(1)
}
