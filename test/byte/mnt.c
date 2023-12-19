#include <stdio.h>
#include <string.h>
#include <zlib.h> // Required for gzipped files

// Function to process a regular file
void processRegularFile(FILE *file) {
    // Variables to keep count of sequences and total length
    unsigned long sequenceCount = 0;
    unsigned long totalLength = 0;
    char line[100024]; // Assuming each line will not be longer than 1024 characters

    while (fgets(line, sizeof(line), file)) {
        if (line[0] == '@') { // Sequence identifier line
            sequenceCount++;
            if (fgets(line, sizeof(line), file)) { // Sequence line
                totalLength += strlen(line) - 1; // -1 to remove newline character
                
                
            }
        }
    }

    printf("Number of sequences: %lu\n", sequenceCount);
    printf("Total length: %lu\n", totalLength);
}

void processGzippedFile(gzFile file) {
    unsigned long sequenceCount = 0;
    unsigned long totalLength = 0;
    char line[1024]; // Buffer for each line

    while (gzgets(file, line, sizeof(line))) {
        //printf("Debug: Read line: %s", line); // Debugging line
        if (line[0] == '@') {
            sequenceCount++;
            if (gzgets(file, line, sizeof(line))) {
                totalLength += strlen(line) - 1; // -1 to remove newline character

                
            }
            // discard next two lines
            gzgets(file, line, sizeof(line));
            gzgets(file, line, sizeof(line));
        }
    }

    printf("Number of sequences: %lu\n", sequenceCount);
    printf("Total length: %lu\n", totalLength);
}


int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <fastq_file>\n", argv[0]);
        return 1;
    }

    FILE *file;
    gzFile gzfile;

    // Check if the file is gzipped or not
    if (strstr(argv[1], ".gz")) {
        gzfile = gzopen(argv[1], "r");
        if (!gzfile) {
            fprintf(stderr, "Could not open gzipped file: %s\n", argv[1]);
            return 1;
        }
        processGzippedFile(gzfile);
        gzclose(gzfile);
    } else {
        file = fopen(argv[1], "r");
        if (!file) {
            fprintf(stderr, "Could not open file: %s\n", argv[1]);
            return 1;
        }
        processRegularFile(file);
        fclose(file);
    }

    return 0;
}
