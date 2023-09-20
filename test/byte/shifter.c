#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define START_BYTE_DEFAULT 128
#define BYTE_STEP_DEFAULT 64
#define MAX_BYTE_CAP_DEFAULT 256000

/*
   This C program allows for the manipulation of binary data within a file.
   It provides a versatile method to modify specific bytes within the file based on user-defined criteria.
   Users can choose to either increment or decrement selected bytes in the file.

   Usage:
   - To modify the file: Run the program with the desired input file as the argument.
   - To revert modifications: Include the '-u' option followed by the input file.

   The program offers flexibility by specifying the starting byte position, step size,
   and maximum byte cap for byte manipulation within the file.

   Usage:
   ./program_name [-u] [-s start_byte] [-j step_size] [-m max_byte] filename

   Options:
   -u          : Reverts modifications made to the file (optional).
   -s start_byte: The starting byte position for byte manipulation (optional, default: 128).
   -j step_size : The step size for byte manipulation (optional, default: 64).
   -m max_byte  : The maximum byte cap for file size (optional, default: 256000).
   filename    : The name of the file to be processed.


   Andrea Telatin, QIB, 2021
*/
int main(int argc, char *argv[]) {
    int unscramble = 0;
    long substitutions = 0;
    long start_byte = START_BYTE_DEFAULT;
    long byte_step = BYTE_STEP_DEFAULT;
    long max_byte_cap = MAX_BYTE_CAP_DEFAULT;
    char *filename;

    // Parse command-line arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-u") == 0) {
            unscramble = 1;
        } else if (strcmp(argv[i], "-s") == 0 && i < argc - 1) {
            start_byte = atol(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "-j") == 0 && i < argc - 1) {
            byte_step = atol(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "-m") == 0 && i < argc - 1) {
            max_byte_cap = atol(argv[i + 1]);
            i++;
        } else {
            filename = argv[i];
        }
    }

    // Check for the correct number of command-line arguments
    if (argc < 2 || filename == NULL) {
        // create a string that is the program's basename
        char *program_name = strrchr(argv[0], '/');
        if (program_name != NULL) {
            program_name++;
        } else {
            program_name = argv[0];
        }
        printf("Usage: %s [-u] [-s start_byte] [-j step_size] [-m max_byte] filename\n", program_name);
        printf("\nParameters:\n");
        printf(" -u            : Reverts modifications made to the file (optional).\n");
        printf(" -s START_BYTE : The starting byte position for byte manipulation (optional, default: 128).\n");
        printf(" -j STEP_SIZE  : The step size for byte manipulation (optional, default: 64).\n");
        printf(" -m MAX_BYTE   : The maximum byte cap for file size (optional, default: 256000).\n");
        printf(" filename      : The name of the file to be processed.\n");
        return 1;
    }

    FILE *file = fopen(filename, "rb+");
    if (file == NULL) {
        fprintf(stderr, "ERROR: Error opening file: %s\n", filename);
        return 1;
    }

    // Get the file size
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    // Cap the file_size if it exceeds max_byte_cap
    if (file_size > max_byte_cap) {
        fprintf(stderr, "INFO:\tCapping file size to %ld bytes\n", max_byte_cap);
        file_size = max_byte_cap;
    }

    // Allocate memory for reading/writing
    unsigned char *buffer = malloc(file_size);
    if (buffer == NULL) {
        perror("ERROR: Memory allocation error");
        fclose(file);
        return 1;
    }

    // Read the file into the buffer
    if (fread(buffer, 1, file_size, file) != file_size) {
        perror("ERROR: Error reading file");
        fclose(file);
        free(buffer);
        return 1;
    }

    if (unscramble) {
        // Unscramble the file by reverting every byte_step-th byte starting from start_byte
        for (long i = start_byte; i < file_size; i += byte_step) {
            if (buffer[i] == 0) {
                buffer[i] = 255; // Wrap around to the maximum value
            } else {
                buffer[i] -= 1;
            }
            substitutions++;
        }
    } else {
        // Scramble the file by changing every byte_step-th byte to its following, starting from start_byte
        for (long i = start_byte; i < file_size; i += byte_step) {
            if (buffer[i] == 255) {
                buffer[i] = 0; // Wrap around to 0 when reaching the maximum
            } else {
                buffer[i] += 1;
            }
            substitutions++;
        }
    }

    // Rewind the file and write the modified buffer back to it
    rewind(file);
    if (fwrite(buffer, 1, file_size, file) != file_size) {
        perror("Error writing to file");
        fclose(file);
        free(buffer);
        return 1;
    }

    fclose(file);
    free(buffer);

    // Print the number of substitutions
    printf("INFO:\tSubstitutions: %ld\n", substitutions);
    return 0;
}