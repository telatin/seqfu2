#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <zlib.h>
#include <pthread.h>
#include <atomic>
#include <algorithm>
#include <string>

// Thread job structure
struct ThreadJob {
    const char* buffer;
    size_t size;
    std::atomic<int>* greater_than_count;
    std::atomic<int>* newline_count;
};

// Structure to hold file analysis results
struct FileResult {
    std::string filename;
    int count;
    std::string format;
};

// Print program usage
void print_usage(const char* prog_name) {
    std::cerr << "Usage: " << prog_name << " [opts] FILE..." << std::endl;
    std::cerr << "Identify and count sequences in FASTA/FASTQ files." << std::endl;
    std::cerr << std::endl;
    std::cerr << "Options:" << std::endl;
    std::cerr << "  -z             Force gzip decompression" << std::endl;
    std::cerr << "  -v             Verbose mode" << std::endl;
    std::cerr << "  -h, --help     Display this help message" << std::endl;
    std::cerr << std::endl;
    std::cerr << "If FILE is '-', read from standard input." << std::endl;
    std::cerr << "Files ending with .gz are automatically treated as gzipped unless -z is specified." << std::endl;
}

// Worker thread function to count characters
void* count_characters(void* arg) {
    ThreadJob* job = static_cast<ThreadJob*>(arg);
    
    int local_gt_count = 0;
    int local_nl_count = 0;
    
    // Process chunk locally
    for (size_t i = 0; i < job->size; i++) {
        if (job->buffer[i] == '>') {
            local_gt_count++;
        } else if (job->buffer[i] == '\n') {
            local_nl_count++;
        }
    }
    
    // Update atomic counters
    job->greater_than_count->fetch_add(local_gt_count, std::memory_order_relaxed);
    job->newline_count->fetch_add(local_nl_count, std::memory_order_relaxed);
    
    return nullptr;
}

// Process a single file or stdin and return the result
FileResult process_file(const char* filename, bool use_gzip, bool use_verbose) {
    gzFile gz_input_stream = nullptr;
    FILE* raw_file = nullptr;
    bool use_stdin = (strcmp(filename, "-") == 0);
    FileResult result;
    
    // Set the filename for result
    result.filename = use_stdin ? "stdin" : filename;
    
    // Check if file has .gz extension
    if (!use_gzip && !use_stdin) {
        constexpr size_t MAX_PATH_LEN = 4096;
        size_t len = strnlen(filename, MAX_PATH_LEN);
        if (len > 3 && strcmp(filename + len - 3, ".gz") == 0) {
            use_gzip = true;
        }
    }
    
    // Display verbose information if requested
    if (use_verbose) {
        std::cout << "Processing file: " << (use_stdin ? "stdin" : filename) << std::endl;
        std::cout << "use_gzip:       " << use_gzip << std::endl;
    }
    
    // Open the appropriate input stream
    if (use_stdin) {
        raw_file = stdin;
        if (use_gzip) {
            gz_input_stream = gzdopen(fileno(stdin), "rb");
            if (!gz_input_stream) {
                std::cerr << "Error opening gzipped stdin" << std::endl;
                result.count = -1;
                result.format = "ERROR";
                return result;
            }
        }
    } else {
        if (use_gzip) {
            gz_input_stream = gzopen(filename, "rb");
            if (!gz_input_stream) {
                std::cerr << "Error opening gzipped file: " << filename << std::endl;
                result.count = -1;
                result.format = "ERROR";
                return result;
            }
        } else {
            raw_file = fopen(filename, "rb");
            if (!raw_file) {
                std::cerr << "Error opening file: " << filename << std::endl;
                result.count = -1;
                result.format = "ERROR";
                return result;
            }
        }
    }
    
    // Read first character to determine file type
    char first_char = 0;
    if (use_gzip) {
        gzread(gz_input_stream, &first_char, 1);
    } else {
        first_char = fgetc(raw_file);
        ungetc(first_char, raw_file);  // Put it back
    }
    
    // Fixed number of threads for C++11 compatibility
    unsigned int num_threads = 4;
    
    // Atomic counters for thread-safe updating
    std::atomic<int> greater_than_count(0);
    std::atomic<int> newline_count(0);
    
    // Larger chunk size for better efficiency
    const size_t chunk_size = 1024 * 1024;  // 1MB chunks
    
    if (use_gzip) {
        // Process gzipped input
        std::vector<char> buffer(chunk_size);
        int bytes_read;
        
        while ((bytes_read = gzread(gz_input_stream, buffer.data(), chunk_size)) > 0) {
            // Create a copy of the buffer for thread safety
            char* thread_buffer = new char[bytes_read];
            memcpy(thread_buffer, buffer.data(), bytes_read);
            
            // Set up thread job
            ThreadJob job = {
                thread_buffer,
                static_cast<size_t>(bytes_read),
                &greater_than_count,
                &newline_count
            };
            
            // Use a single thread for small chunks
            if (bytes_read < 10000) {
                count_characters(&job);
            } else {
                // Create and run thread
                pthread_t thread;
                pthread_create(&thread, nullptr, count_characters, &job);
                pthread_join(thread, nullptr);  // Wait for thread to complete
            }
            
            // Clean up
            delete[] thread_buffer;
        }
    } else {
        // Process regular file/stdin
        std::vector<char*> buffers;
        std::vector<ThreadJob> jobs;
        std::vector<pthread_t> threads;
        
        // Read file in chunks
        while (!feof(raw_file)) {
            char* buffer = new char[chunk_size];
            size_t bytes_read = fread(buffer, 1, chunk_size, raw_file);
            
            if (bytes_read > 0) {
                // Store buffer and prepare job
                ThreadJob job = {
                    buffer,
                    bytes_read,
                    &greater_than_count,
                    &newline_count
                };
                
                jobs.push_back(job);
                buffers.push_back(buffer);
            } else {
                // No bytes read, free the buffer
                delete[] buffer;
            }
        }
        
        // Process chunks in parallel if we have multiple chunks
        if (jobs.size() > 1) {
            threads.resize(std::min(jobs.size(), static_cast<size_t>(num_threads)));
            
            for (size_t i = 0; i < jobs.size(); i++) {
                size_t thread_idx = i % threads.size();
                
                // Create new thread or wait for previous job to complete
                if (i < threads.size()) {
                    pthread_create(&threads[thread_idx], nullptr, count_characters, &jobs[i]);
                } else {
                    pthread_join(threads[thread_idx], nullptr);
                    pthread_create(&threads[thread_idx], nullptr, count_characters, &jobs[i]);
                }
            }
            
            // Wait for remaining threads
            for (size_t i = 0; i < std::min(jobs.size(), threads.size()); i++) {
                pthread_join(threads[i], nullptr);
            }
        } else if (jobs.size() == 1) {
            // Just one chunk, process directly
            count_characters(&jobs[0]);
        }
        
        // Clean up buffers
        for (size_t i = 0; i < buffers.size(); i++) {
            delete[] buffers[i];
        }
    }
    
    // Clean up resources
    if (gz_input_stream) {
        gzclose(gz_input_stream);
    }
    if (raw_file && raw_file != stdin) {
        fclose(raw_file);
    }
    
    // Determine results
    if (first_char == '>') {
        // FASTA format - each > character indicates a sequence
        result.count = greater_than_count + 1;
        result.format = "FASTA";
    } else if (first_char == '@') {
        // FASTQ format - has 4 lines per sequence
        result.count = newline_count / 4;
        result.format = "FASTQ";
    } else {
        std::cerr << "Error: first character is not '>' or '@' in " << result.filename << std::endl;
        if (use_stdin) {
            std::cerr << "If the stream is gzipped try adding -z" << std::endl;
        }
        result.count = -1;
        result.format = "ERROR";
    }
    
    return result;
}

int main(int argc, char* argv[]) {
    bool use_gzip = false;
    bool use_verbose = false;
    std::vector<const char*> filenames;
    
    // Parse command line arguments
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "-z") == 0) {
            use_gzip = true;
        } else if (strcmp(argv[i], "-v") == 0) {
            use_verbose = true;
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        } else {
            filenames.push_back(argv[i]);
        }
    }
    
    // Check if any files were specified
    if (filenames.empty()) {
        // No files specified, use stdin
        filenames.push_back("-");
    }
    
    // Process each file
    std::vector<FileResult> results;
    for (const char* filename : filenames) {
        FileResult result = process_file(filename, use_gzip, use_verbose);
        results.push_back(result);
    }
    
    // Print results in tabular format
    // Format: Filename  Count  Format
    for (const FileResult& result : results) {
        std::cout << result.filename << "\t" << result.count << "\t" << result.format << std::endl;
    }
    
    // Return non-zero if any file had an error
    for (const FileResult& result : results) {
        if (result.count < 0) {
            return 1;
        }
    }
    
    return 0;
}
