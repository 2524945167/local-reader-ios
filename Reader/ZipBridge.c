#include "ZipBridge.h"
#include <zlib.h>
#include <limits.h>
int reader_inflate(const uint8_t *in, size_t n, uint8_t *out, size_t m) {
    if(n > UINT_MAX || m > UINT_MAX) return -1;
    z_stream z = {0}; z.next_in=(Bytef*)in; z.avail_in=(uInt)n;
    z.next_out=out; z.avail_out=(uInt)m;
    if(inflateInit2(&z,-MAX_WBITS)!=Z_OK) return -2;
    int ret=inflate(&z,Z_FINISH);
    int ok=ret==Z_STREAM_END && z.total_out==m && z.total_in==n;
    inflateEnd(&z); return ok ? 0 : -3;
}
uint32_t reader_crc32(const uint8_t *p,size_t n) {
    return (uint32_t)crc32(0L,p,(uInt)n);
}
