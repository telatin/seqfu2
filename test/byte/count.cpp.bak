#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <zlib.h>

int main(int argc, char* argv[]) {
    std::istream* input_stream = nullptr;
    gzFile gz_input_stream = nullptr;
    std::ifstream file;

    bool use_gzip = false;
    bool use_verbose = false;
    bool use_stdin = true;
    char *input_filename = nullptr;



    // Check if -z flag is present
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "-z") == 0) {
            use_gzip = true;
        } else if (strcmp(argv[i], "-v") == 0) {
            use_verbose = true;
             
        } else {
            input_filename = argv[i];
            use_stdin = false;
            // check if filename ends with .gz
            int len = strlen(input_filename);
            if (len > 3 && strcmp(input_filename + len - 3, ".gz") == 0) {
                use_gzip = true;
            }  
        }
    }

    // Verbose
    if (use_verbose) {
        std::cout << "use_gzip:       " << use_gzip << std::endl;
        std::cout << "use_stdin:      " << use_stdin << std::endl;
        std::cout << "input_filename: " << input_filename << std::endl;
    }
    if ( ! use_stdin ) {
        if (use_gzip) {
            gz_input_stream = gzopen(input_filename, "rb");
            if (!gz_input_stream) {
                std::cerr << "Error opening gzipped file: " << input_filename << std::endl;
                return 1;
            }
        } else {
            file.open(input_filename);
            if (!file) {
                std::cerr << "Error opening file: " << input_filename << std::endl;
                return 1;
            }
            input_stream = &file;
        }
    } else {
        input_stream = &std::cin;
        if (use_gzip) {
            gz_input_stream = gzdopen(0, "rb"); // 0 is the file descriptor for stdin
        }
    }

    char first_char;
    if (use_gzip) {
        gzread(gz_input_stream, &first_char, 1);
    } else {
        first_char = input_stream->get();
    }

    int greater_than_count = 0;
    int newline_count = 0;
    const int chunk_size = 1024;
    std::vector<char> buffer(chunk_size);

    if (use_gzip) {
        int bytes_read;
        while ((bytes_read = gzread(gz_input_stream, buffer.data(), chunk_size)) > 0) {
            for (int i = 0; i < bytes_read; i++) {
                if (buffer[i] == '>') {
                    greater_than_count++;
                } else if (buffer[i] == '\n') {
                    newline_count++;
                }
            }
        }
    } else {
        while (input_stream->read(buffer.data(), chunk_size)) {
            for (int i = 0; i < chunk_size; i++) {
                if (buffer[i] == '>') {
                    greater_than_count++;
                } else if (buffer[i] == '\n') {
                    newline_count++;
                }
            }
        }

        // Handle the remaining characters (less than chunk_size)
        int remaining = input_stream->gcount();
        for (int i = 0; i < remaining; i++) {
            if (buffer[i] == '>') {
                greater_than_count++;
            } else if (buffer[i] == '\n') {
                newline_count++;
            }
        }
    }

    if (file.is_open()) {
        file.close();
    }
    if (gz_input_stream) {
        gzclose(gz_input_stream);
    }

    if (first_char == '>') {
        std::cout << greater_than_count + 1 << "\tFASTA" << std::endl;
    } else if (first_char == '@') {
        int approx =  newline_count / 4;
        std::cout << approx << "\tFASTQ" << std::endl;
    } else {
        std::cerr << "Error: first character is not '>' or '@'" << std::endl;
        if (use_stdin) {
            std::cerr << "If the stream is gzipped try adding -z" << std::endl;
        }
        return 1;
    }

    return 0;
}
