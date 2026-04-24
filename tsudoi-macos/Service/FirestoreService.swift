//
//  FirestoreService.swift
//  tsudoi-macos
//

import FirebaseFirestore
import Foundation

/// Minimal payload the app needs from each incoming comment document.
struct IncomingComment {
    let text: String
    let colorHex: String
}

enum FirestoreService {
    /// Subscribes to comments created AFTER this call. The caller must retain
    /// the returned registration and invoke `.remove()` to tear the listener
    /// down when projection stops.
    static func listenForNewComments(
        eventId: String,
        onAdded: @escaping (IncomingComment) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerRegistration {
        let db = Firestore.firestore()
        let startTime = Timestamp(date: Date())
        return db.collection("events").document(eventId)
            .collection("comments")
            .whereField("createdAt", isGreaterThan: startTime)
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                guard let snapshot else { return }
                for change in snapshot.documentChanges where change.type == .added {
                    let data = change.document.data()
                    guard let text = data["text"] as? String else { continue }
                    if data["hidden"] as? Bool == true { continue }
                    let colorHex = data["color"] as? String ?? "#FFFFFF"
                    onAdded(IncomingComment(text: text, colorHex: colorHex))
                }
            }
    }
}
