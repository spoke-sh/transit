/* Compile-time checks of upstream declarations/constants, not runtime logic. */
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/x509v3.h>
_Static_assert(MBSTRING_UTF8 == 0x1000, "certificate text encoding");
_Static_assert(SSL_CTRL_GET_CHAIN_CERTS == 115 && X509_PURPOSE_SSL_SERVER == 2 && X509_CHECK_FLAG_NEVER_CHECK_SUBJECT == 0x20, "local certificate verification");
_Static_assert(OPENSSL_VERSION_NUMBER == 0x30600040L, "review OpenSSL upgrade");
_Static_assert(SSL_CTRL_SET_MIN_PROTO_VERSION == 123 && SSL_CTRL_SET_MAX_PROTO_VERSION == 124, "protocol controls");
_Static_assert(SSL_CTRL_SET_SESS_CACHE_MODE == 44 && SSL_SESS_CACHE_OFF == 0, "session controls");
_Static_assert(TLS1_2_VERSION == 0x0303 && TLS1_3_VERSION == 0x0304, "TLS versions");
_Static_assert(SSL_OP_NO_COMPRESSION == (UINT64_C(1) << 17) && SSL_OP_NO_RENEGOTIATION == (UINT64_C(1) << 30), "TLS options");
_Static_assert(SSL_FILETYPE_PEM == 1 && SSL_ERROR_WANT_READ == 2 && SSL_ERROR_ZERO_RETURN == 6, "TLS results");
