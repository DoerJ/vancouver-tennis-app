import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class GoogleAuthService: NSObject {
    private var currentSession: ASWebAuthenticationSession?

    func signIn() async throws -> GoogleAuthSession {
        let pkce = try PKCEChallenge()
        let state = UUID().uuidString
        let redirectURI = GoogleOAuthConfiguration.redirectURI
        let authURL = try GoogleOAuthConfiguration.authorizationURL(
            codeChallenge: pkce.codeChallenge,
            state: state,
            redirectURI: redirectURI
        )

        let callbackURL: URL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: GoogleOAuthConfiguration.callbackScheme
            ) { [weak self] callbackURL, error in
                self?.currentSession = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard callbackURL != nil else {
                    continuation.resume(throwing: GoogleAuthError.missingCallbackURL)
                    return
                }

                continuation.resume(returning: callbackURL!)
            }

            session.presentationContextProvider = AuthenticationPresentationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = true
            currentSession = session
            session.start()
        }

        let callback = try GoogleOAuthCallback(url: callbackURL, expectedState: state)

        return try await GoogleOAuthTokenExchanger.exchangeCode(
            callback.code,
            codeVerifier: pkce.codeVerifier,
            redirectURI: redirectURI
        )
    }
}

struct GoogleAuthSession {
    let accessToken: String
    let idToken: String?
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
}

enum GoogleAuthError: LocalizedError {
    case missingClientID
    case missingCallbackURL
    case invalidCallback
    case invalidState
    case missingAuthorizationCode
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Add your Google iOS client ID before signing in."
        case .missingCallbackURL:
            return "Google did not return an authentication callback."
        case .invalidCallback:
            return "Google returned an invalid authentication callback."
        case .invalidState:
            return "The Google sign in response could not be verified."
        case .missingAuthorizationCode:
            return "Google did not return an authorization code."
        case .tokenExchangeFailed:
            return "Google sign in failed while exchanging the authorization code."
        }
    }
}

enum GoogleOAuthConfiguration {
    static let clientID = "YOUR_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com"
    static let reversedClientID = "com.googleusercontent.apps.YOUR_GOOGLE_IOS_CLIENT_ID"
    static let callbackScheme = reversedClientID
    static let redirectURI = "\(callbackScheme):/oauthredirect"

    static func authorizationURL(codeChallenge: String, state: String, redirectURI: String) throws -> URL {
        guard !clientID.hasPrefix("YOUR_") else {
            throw GoogleAuthError.missingClientID
        }

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]

        return components.url!
    }
}

private struct GoogleOAuthCallback {
    let code: String

    init(url: URL, expectedState: String) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GoogleAuthError.invalidCallback
        }

        let items = components.queryItems ?? []
        let returnedState = items.first { $0.name == "state" }?.value

        guard returnedState == expectedState else {
            throw GoogleAuthError.invalidState
        }

        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw GoogleAuthError.missingAuthorizationCode
        }

        self.code = code
    }
}

private enum GoogleOAuthTokenExchanger {
    static func exchangeCode(
        _ code: String,
        codeVerifier: String,
        redirectURI: String
    ) async throws -> GoogleAuthSession {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "client_id": GoogleOAuthConfiguration.clientID,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw GoogleAuthError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)

        return GoogleAuthSession(
            accessToken: tokenResponse.accessToken,
            idToken: tokenResponse.idToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: tokenResponse.expiresIn,
            tokenType: tokenResponse.tokenType
        )
    }

    private static func formBody(_ values: [String: String]) -> Data {
        let body = values
            .map { key, value in
                "\(key.urlFormEncoded)=\(value.urlFormEncoded)"
            }
            .joined(separator: "&")

        return Data(body.utf8)
    }
}

private struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let idToken: String?
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

private struct PKCEChallenge {
    let codeVerifier: String
    let codeChallenge: String

    init() throws {
        codeVerifier = try Self.makeCodeVerifier()
        let digest = SHA256.hash(data: Data(codeVerifier.utf8))
        codeChallenge = Data(digest).base64URLEncodedString()
    }

    private static func makeCodeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            throw GoogleAuthError.tokenExchangeFailed
        }

        return Data(bytes).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var urlFormEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")

        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

private final class AuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthenticationPresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap(\.windows).first { $0.isKeyWindow }

        return keyWindow ?? ASPresentationAnchor()
    }
}
