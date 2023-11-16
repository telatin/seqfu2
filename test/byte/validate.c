/*
   Description:
   This program reads a FASTQ file (compressed with zlib) and validates its format.
   It checks that the file follows the FASTQ format rules, such as having the '@' character
   at the beginning of the sequence identifier lines, containing only valid DNA characters,
   and optionally checking the quality scores for valid ASCII values.

   Usage:
   ./fastq_validator [-s] [-o offset] filename

   Parameters:
   -s            : Validate quality (optional).
   -o OFFSET     : The offset for quality score (optional, default: 33).
   filename      : The name of the file to be processed (optional, default: stdin)
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>  // Include zlib header

#define MAX_LINE_LENGTH 4096
#define QSCORE_OFFSET 33

int main(int argc, char *argv[]) {
    gzFile fp;  // Use gzFile instead of FILE*

    int opt_offset = QSCORE_OFFSET;
    int opt_strict = 0;
    int opt_help   = 0;
    int opt_verbose = 0;
    char *filename = NULL;  // Initialize to NULL

 
    // Parse command-line arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-s") == 0) {
            opt_strict = 1;
        } else if (i < argc - 1 && strcmp(argv[i], "-o") == 0 ) {
            opt_offset = atol(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "-v") == 0) {
            opt_verbose = 1;
        } else if (strcmp(argv[i], "-h") == 0) {
            opt_help = 1;
        } else {
            filename = argv[i];
            
        }
    }

    // Check for the correct number of command-line arguments
    if (opt_help) {
        // create a string that is the program's basename
        char *program_name = strrchr(argv[0], '/');
        if (program_name != NULL) {
            program_name++;
        } else {
            program_name = argv[0];
        }
        printf("Usage: %s [-s] [-o offset] filename\n", program_name);
        printf("\nParameters:\n");
        printf(" -s            : Validate quality (optional).\n");
        printf(" -o OFFSET     : The offset for quality score (optional, default: 33).\n");
        printf(" filename      : The name of the file to be processed (optional, default: stdin)\n");
        return 1;
    }

    // if defined filename open it else use stdin
    if (filename != NULL) {
        // print to stderr if verbose
        if (opt_verbose) {
            fprintf(stderr, "Opening file %s\n", filename);
        }

        fp = gzopen(filename, "r");  // Use gzopen instead of fopen

        if (fp == NULL) {
            fprintf(stderr, "Error opening file %s\n", filename);
            return 1;
        }
    } else {
        // print to stderr if verbose
        if (opt_verbose) {
            fprintf(stderr, "Reading from stdin\n");
        }
        fp = gzdopen(fileno(stdin), "r");  // Use gzdopen to wrap stdin
    }
    char first_seq[MAX_LINE_LENGTH];
    char last_seq[MAX_LINE_LENGTH];
    char line[MAX_LINE_LENGTH];
    int line_count = 0;
    int seq_count  = 0;
    int seq_len    = 0;
    int valid      = 1;

    char first_char;
    // read the first character
    if (gzread(fp, &first_char, 1) != 1) {
        fprintf(stderr, "ERROR: File is empty\n");
        return 1;
    }

    if (first_char == '>') {
        while (gzgets(fp, line, sizeof(line))) {
            line_count++;
            if (line_count == 1 || line[0] == '>') {
                // header
                seq_count++;
                line[strcspn(line, "\n")] = 0;
                char *seq_name = strtok(line, " ");
                if (seq_count == 1) {
                    strcpy(first_seq, seq_name);
                }
                strcpy(last_seq, seq_name+1);
            } else {
                // sequence
                line[strcspn(line, "\n")] = 0;
                seq_len = strlen(line);

                // Check if the line is only composed by A, C, G, T and N
                for (int i = 0; i < seq_len; i++) {
                    if (line[i] != 'A' && line[i] != 'C' && line[i] != 'G' && line[i] != 'T' && line[i] != 'N') {
                        // print to stderr the error
                        
                        fprintf(stderr,"ERROR: Line %d in sequence %d contains an invalid character: %c\n", line_count, seq_count, line[i]);
                        valid = 0;
                        break;
                    }
                }
            }
        }

    } else if (first_char == '@') {
        while (gzgets(fp, line, sizeof(line))) {  // Use gzgets instead of fgets
        line_count++;
        
        if (line_count % 4 == 1) {
            // Remove the trailing newline character
            line[strcspn(line, "\n")] = 0;

            // seq name: remove first character and split to the first space
        
            char *seq_name = strtok(line+1, " ");
            
            if (seq_count == 0) {
                strcpy(first_seq, seq_name);
            }
            strcpy(last_seq, seq_name);

            // check if first character is '@'
            if (line_count != 1 && line[0] != '@') {
                printf("ERROR: Line %d in sequence %d does not start with '@'\n", line_count, seq_count);
                valid = 0;
                break;
            }
        }  else if (line_count % 4 == 2) {
            // Remove the trailing newline character
            line[strcspn(line, "\n")] = 0;
            seq_len = strlen(line);

            // Check if the line is only composed by A, C, G, T and N
            for (int i = 0; i < seq_len; i++) {
                if (line[i] != 'A' && line[i] != 'C' && line[i] != 'G' && line[i] != 'T' && line[i] != 'N') {
                    // print to stderr the error
                    
                    fprintf(stderr,"ERROR: Line %d in sequence %d contains an invalid character: %c\n", line_count, seq_count, line[i]);
                    valid = 0;
                    break;
                }
            }
        } else if (line_count % 4 == 3) {
            if (line[0] != '+') {
                fprintf(stderr,"ERROR: Line %d in sequence %d does not start with '+'\n", line_count, seq_count);
                valid = 0;
                break;
            }
        } else if (line_count % 4 == 0) {
            line[strcspn(line, "\n")] = 0;
            if (seq_len != strlen(line)) {
                fprintf(stderr, "ERROR: Line %d in sequence %d has a different length than the sequence: %ld vs %d\n", line_count, seq_count, (long)(line != NULL ? strlen(line) : 0), seq_len);
                valid = 0;
                break;
            } 
            // Check if the quality line is composed by ASCII values from 0 to 60
            if (opt_strict) {
                int qscore_int = 0;
                for (int i = 0; i < seq_len; i++) {
                    qscore_int = (int) line[i] - opt_offset;
                    if (qscore_int < 0 || qscore_int > 60) {
                        fprintf(stderr,"ERROR: Line %d in sequence %d contains an invalid quality score: %c = %d\n", line_count, seq_count, line[i], qscore_int);
                        valid = 0;
                        break;
                    }
                }
            }

            seq_count++;
        }
        

    }

    }
    
    
    // create status_string
    char status[4];
    if (valid) {
        strcpy(status, "OK");
    } else {
        strcpy(status, "ERR");
    }
    printf("%s\t%d\t%s\t%s\n", status, seq_count, first_seq, last_seq);

 
    if (fp != gzdopen(fileno(stdin), "r")) {  // Check against gzdopen(fileno(stdin), "r") instead of stdin
        gzclose(fp);  // Use gzclose instead of fclose
    }

    return 0;
}