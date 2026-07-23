import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class AppleAuthService {
    private var currentDelegate: AppleAuthorizationDelegate?

    func signIn() async throws -> AppleAuthSession {
        let rawNonce = try AppleNonce.make()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleNonce.sha256(rawNonce)

        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleAuthorizationDelegate { [weak self] result in
                self?.currentDelegate = nil

                switch result {
                case .success(let credential):
                    guard let identityTokenData = credential.identityToken,
                          let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                        continuation.resume(throwing: AppleAuthError.missingIdentityToken)
                        return
                    }

                    continuation.resume(
                        returning: AppleAuthSession(
                            idToken: identityToken,
                            nonce: rawNonce,
                            email: credential.email,
                            fullName: credential.fullName
                        )
                    )
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            currentDelegate = delegate
            controller.performRequests()
        }
    }
}

struct AppleAuthSession {
    let idToken: String
    let nonce: String
    let email: String?
    let fullName: PersonNameComponents?
}

enum AppleAuthError: LocalizedError {
    case cancelled
    case missingIdentityToken
    case nonceGenerationFailed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .missingIdentityToken:
            return AppContent.string("auth.login.missingAppleIDToken")
        case .nonceGenerationFailed:
            return AppContent.string("auth.login.appleSignInFailed")
        }
    }
}

private final class AppleAuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void

    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(AppleAuthError.missingIdentityToken))
            return
        }

        completion(.success(credential))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            completion(.failure(AppleAuthError.cancelled))
            return
        }

        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain
            && nsError.code == ASAuthorizationError.Code.canceled.rawValue {
            completion(.failure(AppleAuthError.cancelled))
            return
        }

        completion(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap(\.windows).first { $0.isKeyWindow }

        return keyWindow ?? ASPresentationAnchor()
    }
}

private enum AppleNonce {
    private static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    static func make(length: Int = 32) throws -> String {
        precondition(length > 0)

        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

            guard status == errSecSuccess else {
                throw AppleAuthError.nonceGenerationFailed
            }

            randomBytes.forEach { randomByte in
                guard remainingLength > 0,
                      Int(randomByte) < charset.count else {
                    return
                }

                result.append(charset[Int(randomByte)])
                remainingLength -= 1
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)

        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}
