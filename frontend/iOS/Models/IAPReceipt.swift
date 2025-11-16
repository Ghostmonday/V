import Foundation

struct IAPReceipt: Codable {
    let transactionId: String
    let productId: String
    let expirationDate: Date?
}

