#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#define BUFFER_SIZE 1024

// Function to check if the file is gzipped
int is_gzipped(const char *filename) {
    int len = strlen(filename);
    return len > 3 && strcmp(filename + len - 3, ".gz") == 0;
}

// Function to open the file appropriately based on its type
FILE *open_file(const char *filename) {
    if (is_gzipped(filename)) {
        return (FILE *)gzopen(filename, "rb");
    } else {
        return fopen(filename, "r");
    }
}

// Function to read a line from the file
char *read_line(FILE *file, char *buffer, int gzipped) {
    if (gzipped) {
        return gzgets((gzFile)file, buffer, BUFFER_SIZE);
    } else {
        return fgets(buffer, BUFFER_SIZE, file);
    }
}

// Function to check if the file is FASTQ
int is_fastq(const char *filename) {
    return strstr(filename, ".fq") != NULL || strstr(filename, ".fastq") != NULL;
}

// Main function for parsing the FASTQ or FASTA file
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <filename>\n", argv[0]);
        return 1;
    }

    const char *filename = argv[1];
    int gzipped = is_gzipped(filename);
    FILE *file = open_file(filename);
    if (!file) {
        fprintf(stderr, "Error opening file: %s\n", filename);
        return 1;
    }

    char buffer[BUFFER_SIZE];
    unsigned long total_length = 0;
    int total_sequences = 0;
    int isFasta = !is_fastq(filename);
    int line_number = 0;

    while (read_line(file, buffer, gzipped) != NULL) {
        if (isFasta) {
            if (buffer[0] == '>') { // Header line in FASTA
                if (line_number > 0) total_sequences++;
            } else {
                total_length += strlen(buffer) - 1; // -1 to exclude the newline character
            }
            line_number++;
        } else {
            line_number++;
            if (line_number % 4 == 2) { // Sequence line in FASTQ
                total_length += strlen(buffer) - 1; // -1 to exclude the newline character
                total_sequences++;
            }
        }
    }

    // Adjust sequence count for the last sequence in FASTA
    if (isFasta && line_number > 0) total_sequences++;

    if (gzipped) {
        gzclose((gzFile)file);
    } else {
        fclose(file);
    }

    printf("Total number of sequences: %d\n", total_sequences);
    printf("Total length of sequences: %lu\n", total_length);

    return 0;
}