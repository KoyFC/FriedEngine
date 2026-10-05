#pragma once

// libctru implements no pthread keys: pthread_key_create() and the rest are
// newlib stubs that fail and read back null, so hxcpp's default TLS loses the
// GC's per-thread context on the first lookup. Every libctru thread does get
// native TLS, so this is hxcpp's own WinRT shape, on thread_local.
#define DECLARE_TLS_DATA(TYPE, NAME) thread_local TYPE *NAME = nullptr;
#define DECLARE_FAST_TLS_DATA(TYPE, NAME) thread_local TYPE *NAME = nullptr;
#define EXTERN_TLS_DATA(TYPE, NAME) extern thread_local TYPE *NAME;
#define EXTERN_FAST_TLS_DATA(TYPE, NAME) extern thread_local TYPE *NAME;
