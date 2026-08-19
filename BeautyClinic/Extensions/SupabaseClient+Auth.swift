import Foundation

extensionsupabaseClient {
    func signOut() throws {
        try auth.signOut()
    }
}