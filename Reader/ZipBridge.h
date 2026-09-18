#include <stddef.h>
#include <stdint.h>
int reader_inflate(const uint8_t *input, size_t input_size, uint8_t *output, size_t output_size);
uint32_t reader_crc32(const uint8_t *input, size_t size);
