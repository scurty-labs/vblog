module main

import crypto.argon2
import crypto.hmac
import crypto.sha256
import encoding.hex

// Admin credentials are never stored exactly as typed:
//
//   admin_password   an Argon2id PHC string: salted, deliberately slow, and not
//                    reversible from the file even if the file leaks
//   admin_username   a keyed SHA-256 digest
//   admin_email      the same digest, of the trimmed, lowercased address
//
// The key for the two digests is client_secret. It lives in the same file, so the
// digests keep the account's name and address out of backups, screen shares and
// casual greps rather than protecting them from somebody who can already read
// config.json. The password does not depend on that key: Argon2id carries its own
// salt and cannot be reversed.
const identity_prefix = 'hmac-sha256:'
const password_prefix = r'$argon2'

// hash_password returns the Argon2id PHC string to store in config.json. The
// default parameters (64 MiB, 3 passes, 4 lanes) take roughly a tenth of a second
// per sign-in, which is what makes guessing slow.
fn hash_password(password string) !string {
	return argon2.generate_from_password(password.bytes())
}

// verify_password checks a typed password against a stored Argon2id hash.
fn verify_password(stored string, password string) bool {
	if !stored.starts_with(password_prefix) {
		return false
	}
	argon2.compare_hash_and_password(password.bytes(), stored.bytes()) or { return false }
	return true
}

// hash_identity turns the username into a digest that can be compared later. A
// stray space at either end is ignored.
fn hash_identity(value string, secret string) string {
	mac := hmac.new(secret.bytes(), value.trim_space().bytes(), sha256.sum, sha256.block_size)
	return identity_prefix + hex.encode(mac)
}

// hash_email is hash_identity for addresses, which are case-insensitive.
fn hash_email(value string, secret string) string {
	return hash_identity(value.trim_space().to_lower(), secret)
}

// identity_matches compares a stored digest with a freshly computed one in
// constant time.
fn identity_matches(stored string, computed string) bool {
	if stored.len == 0 || computed.len == 0 {
		return false
	}
	return hmac.equal(stored.bytes(), computed.bytes())
}

// session_token is the cookie value that keeps a browser signed in. It is keyed
// by client_secret and built from the stored hashes, so changing the password
// changes the token and signs every existing cookie out.
fn session_token(conf Config) string {
	payload := '${conf.client_salt}${conf.admin_password}${conf.admin_username}${conf.admin_email}'
	mac := hmac.new(conf.client_secret.bytes(), payload.bytes(), sha256.sum, sha256.block_size)
	return hex.encode(mac)
}

// token_matches compares a cookie token with the one this config produces.
fn token_matches(expected string, given string) bool {
	if expected.len == 0 || given.len == 0 {
		return false
	}
	return hmac.equal(expected.bytes(), given.bytes())
}
