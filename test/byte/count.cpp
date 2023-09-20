/*
    A simple program to count the number of sequences in a FASTA or FASTQ file.
    This program is not meant to be a replacement for the more robust seqfu stats.

    Not to be used for production. This is just a test program.
*/
#include <iostream>
#include <fstream>
#include <vector>

int main(int argc, char* argv[]) {
    std::istream* input_stream = nullptr;
    std::ifstream file;

    if (argc > 1) {
        file.open(argv[1]);
        if (!file) {
            std::cerr << "Error opening file: " << argv[1] << std::endl;
            return 1;
        }
        input_stream = &file;
    } else {
        input_stream = &std::cin;
    }
    char first_char = input_stream->get();
    int greater_than_count = 0;
    int newline_count = 0;
    const int chunk_size = 1024; // Adjust the chunk size as needed
    std::vector<char> buffer(chunk_size);

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

    if (file.is_open()) {
        file.close(); // Close the file if it was opened
    }

    
    if (first_char == '>') {
        std::cout << greater_than_count + 1 << "\tFASTA" << std::endl; 
    } else if (first_char == '@') {
        int approx =  newline_count / 4;
        std::cout << approx << "\tFASTQ" << std::endl; 
    } else {
        std::cerr << "Error: first character is not '>' or '@'" << std::endl;
        return 1;
    }
    return 0;
}
