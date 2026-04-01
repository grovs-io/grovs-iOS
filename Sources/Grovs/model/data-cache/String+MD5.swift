import Foundation
import CryptoKit

extension String {
    var md5: String {
        guard let data = self.data(using: .utf8) else { return self }
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
