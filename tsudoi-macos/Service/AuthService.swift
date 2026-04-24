//
//  AuthService.swift
//  tsudoi-macos
//

import AppKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

enum AuthServiceError: LocalizedError {
    case noResult
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .noResult: return "Sign-in returned no result."
        case .missingIDToken: return "Missing Google ID token."
        }
    }
}

/// Thin wrapper around Firebase Auth + Google Sign-In so the AppDelegate
/// doesn't have to know the library APIs directly.
enum AuthService {
    static func configure() {
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    static func handle(url: URL) {
        _ = GIDSignIn.sharedInstance.handle(url)
    }

    static func addAuthStateListener(
        _ callback: @escaping (User?) -> Void
    ) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in
            callback(user)
        }
    }

    static func signInWithGoogle(
        presenting window: NSWindow,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        GIDSignIn.sharedInstance.signIn(withPresenting: window) { result, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let result else {
                completion(.failure(AuthServiceError.noResult))
                return
            }
            let gUser = result.user
            guard let idToken = gUser.idToken?.tokenString else {
                completion(.failure(AuthServiceError.missingIDToken))
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: gUser.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { _, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    static func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }
}
