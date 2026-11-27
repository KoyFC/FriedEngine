#pragma once

// A compressed asset is "FRLZ" followed by an LZ10 stream, the one the DS's BIOS reads: a 0x10 byte and the unpacked size in three bytes, then groups of eight literals or back references.
extern "C"
{
    // The size the data unpacks to, or -1 when it is not a compressed asset.
    int fried_lz10_unpacked_size(const unsigned char *data, int size);
    // Unpacks into a destination of exactly that size. Returns 1, or 0 when the data is damaged.
    int fried_lz10_unpack(const unsigned char *data, int size, unsigned char *destination, int destinationSize);
}

// Replaces a buffer made with new[] that holds a compressed asset by one that holds what it unpacks to. A buffer that is not compressed is left alone. Returns false when the data is damaged or the memory is short, leaving the buffer as it was.
bool fried_unpack_asset(unsigned char *&contents, int &size);
