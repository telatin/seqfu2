#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#define BLOCK_SIZE (1 << 20)
#define MAX_PATH_LEN 4096

int is_gzipped(const char *filename) {
    size_t len = strnlen(filename, MAX_PATH_LEN);
    return len > 3 && strcmp(filename + len - 3, ".gz") == 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <filename>\n", argv[0]);
        return 1;
    }

    const char *filename = argv[1];
    int gzipped = is_gzipped(filename);

    unsigned long total_length = 0;
    unsigned long total_sequences = 0;
    int record_pos = 0;
    int in_sequence = 0;

    char *buffer = malloc(BLOCK_SIZE);
    if (!buffer) {
        fprintf(stderr, "Memory allocation failed\n");
        return 1;
    }

    void *handle = NULL;
    if (gzipped) {
        handle = gzopen(filename, "rb");
        if (handle) gzbuffer((gzFile)handle, 1 << 18);
    } else {
        handle = fopen(filename, "r");
    }

    if (!handle) {
        fprintf(stderr, "Error opening file: %s\n", filename);
        free(buffer);
        return 1;
    }

    int bytes_read;
    while (1) {
        if (gzipped) {
            bytes_read = gzread((gzFile)handle, buffer, BLOCK_SIZE);
        } else {
            bytes_read = (int)fread(buffer, 1, BLOCK_SIZE, (FILE *)handle);
        }
        if (bytes_read <= 0) break;

        int pos = 0;
        while (pos < bytes_read) {
            char *nl = memchr(buffer + pos, '\n', bytes_read - pos);
            if (!nl) {
                if (in_sequence) {
                    total_length += (bytes_read - pos);
                }
                break;
            }
            int nl_pos = (int)(nl - buffer);

            if (in_sequence) {
                total_length += (nl_pos - pos);
                in_sequence = 0;
                total_sequences++;
            }

            record_pos = (record_pos + 1) & 3;
            if (record_pos == 1) {
                in_sequence = 1;
            }

            pos = nl_pos + 1;
        }
    }

    if (gzipped) {
        gzclose((gzFile)handle);
    } else {
        fclose((FILE *)handle);
    }

    free(buffer);

    printf("Total number of sequences: %lu\n", total_sequences);
    printf("Total length of sequences: %lu\n", total_length);

    return 0;
}
