#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

uint32_t tic_tool_zip(void *dest, int32_t destSize, const void *source,
                      int32_t size) {
  unsigned long destSizeLong = destSize;
  return compress2(dest, &destSizeLong, source, size, Z_BEST_COMPRESSION) ==
                 Z_OK
             ? destSizeLong
             : 0;
}
uint32_t tic_tool_unzip(void *dest, int32_t destSize, const void *source,
                        int32_t size) {
  unsigned long destSizeLong = destSize;
  return uncompress(dest, &destSizeLong, source, size) == Z_OK ? destSizeLong
                                                               : 0;
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "expected file to compress");
    return 1;
  }
  FILE *f = fopen(argv[1], "rb");
  if (!f) {
    perror("opening file");
    return 1;
  }
  const size_t cart_size = 1445320;
  printf("cart size is %zu\n", cart_size);
  void *data = calloc(cart_size, 1);
  if (!data) {
    fclose(f);
    return 1;
  }
  void *zip_data = malloc(cart_size);
  if (!zip_data) {
    fclose(f);
    return 1;
  }
  size_t read_size = fread(data, 1, cart_size, f);
  if (feof(f)) {
    printf("end of file\n");
  } else {
    printf("error: %d, %s\n", ferror(f), strerror(ferror(f)));
    fclose(f);
    return 1;
  }
  printf("cart %s is %zu bytes\n", argv[1], read_size);
  fclose(f);

  if (argc > 2) {
    size_t zip_size =
        (size_t)tic_tool_unzip(zip_data, cart_size, data, read_size);

    f = fopen(argv[2], "wb");
    if (!f) {
      perror("opening file");
      return 1;
    }

    size_t wrote = fwrite(zip_data, 1, zip_size, f);
    printf("wrote %zu bytes\n", wrote);
  } else {

    size_t zip_size =
        (size_t)tic_tool_zip(zip_data, cart_size, data, read_size);

    f = fopen("src/lola.tic.gz", "wb");
    if (!f) {
      perror("opening file");
      return 1;
    }

    size_t wrote = fwrite(zip_data, 1, zip_size, f);
    printf("wrote %zu bytes\n", wrote);
  }

  fclose(f);

  return 0;
}