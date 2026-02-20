import Testing
@testable import scrobble

@Suite("CryptoUtils Tests")
struct CryptoUtilsTests {

    @Test("MD5 of empty string")
    func md5EmptyString() {
        let result = md5("")
        #expect(result == "d41d8cd98f00b204e9800998ecf8427e")
    }

    @Test("MD5 of 'hello'")
    func md5Hello() {
        let result = md5("hello")
        #expect(result == "5d41402abc4b2a76b9719d911017c592")
    }

    @Test("MD5 of 'Hello World'")
    func md5HelloWorld() {
        let result = md5("Hello World")
        #expect(result == "b10a8db164e0754105b7a99be72e3fe5")
    }

    @Test("createLastFmSignature with known parameters")
    func signatureGeneration() {
        let params: [String: Any] = [
            "method": "auth.getToken",
            "api_key": "testkey123"
        ]
        let signature = createLastFmSignature(parameters: params, secret: "testsecret")
        // Signature = MD5("api_keytestkey123methodauth.getTokentestsecret")
        let expected = md5("api_keytestkey123methodauth.getTokentestsecret")
        #expect(signature == expected)
    }

    @Test("createLastFmSignature sorts parameters alphabetically")
    func signatureAlphabeticalSorting() {
        let params1: [String: Any] = [
            "z_param": "last",
            "a_param": "first",
            "m_param": "middle"
        ]
        let params2: [String: Any] = [
            "a_param": "first",
            "m_param": "middle",
            "z_param": "last"
        ]
        let sig1 = createLastFmSignature(parameters: params1, secret: "secret")
        let sig2 = createLastFmSignature(parameters: params2, secret: "secret")
        #expect(sig1 == sig2)
    }

    @Test("MD5 produces 32-character hex string")
    func md5Length() {
        let result = md5("test string")
        #expect(result.count == 32)
        #expect(result.allSatisfy { $0.isHexDigit })
    }
}
