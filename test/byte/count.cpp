#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <zlib.h>
#include <pthread.h>
#include <atomic>
#include <algorithm>
#include <string>
#include <thread>

struct ThreadJob {
    const char* buffer;
    size_t size;
    long long gt_count;
    long long nl_count;
};

struct FileResult {
    std::string filename;
    long long count;
    std::string format;
};

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

static long long count_char(const char* buf, size_t len, char c) {
    long long n = 0;
    const char* end = buf + len;
    const char* p = buf;
    while ((p = (const char*)memchr(p, c, end - p)) != nullptr) {
        n++;
        p++;
    }
    return n;
}

void* count_characters(void* arg) {
    ThreadJob* job = static_cast<ThreadJob*>(arg);
    job->gt_count = count_char(job->buffer, job->size, '>');
    job->nl_count = count_char(job->buffer, job->size, '\n');
    return nullptr;
}

FileResult process_file(const char* filename, bool use_gzip, bool use_verbose) {
    gzFile gz_input_stream = nullptr;
    FILE* raw_file = nullptr;
    bool use_stdin = (strcmp(filename, "-") == 0);
    FileResult result;

    result.filename = use_stdin ? "stdin" : filename;

    if (!use_gzip && !use_stdin) {
        constexpr size_t MAX_PATH_LEN = 4096;
        size_t len = strnlen(filename, MAX_PATH_LEN);
        if (len > 3 && strcmp(filename + len - 3, ".gz") == 0) {
            use_gzip = true;
        }
    }

    if (use_verbose) {
        std::cout << "Processing file: " << (use_stdin ? "stdin" : filename) << std::endl;
        std::cout << "use_gzip:       " << use_gzip << std::endl;
    }

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
            gzbuffer(gz_input_stream, 1 << 18);
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
            gzbuffer(gz_input_stream, 1 << 18);
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

    char first_char = 0;
    if (use_gzip) {
        gzread(gz_input_stream, &first_char, 1);
    } else {
        first_char = fgetc(raw_file);
    }

    unsigned int num_threads = std::thread::hardware_concurrency();
    if (num_threads == 0) num_threads = 4;

    const size_t chunk_size = 1024 * 1024;

    long long total_gt = 0;
    long long total_nl = 0;

    if (use_gzip) {
        std::vector<char> buffer(chunk_size);
        int bytes_read;

        while ((bytes_read = gzread(gz_input_stream, buffer.data(), chunk_size)) > 0) {
            ThreadJob job = { buffer.data(), static_cast<size_t>(bytes_read), 0, 0 };
            count_characters(&job);
            total_gt += job.gt_count;
            total_nl += job.nl_count;
        }
    } else {
        std::vector<char*> buffers(num_threads);
        std::vector<ThreadJob> jobs(num_threads);
        std::vector<pthread_t> threads(num_threads);

        for (unsigned int i = 0; i < num_threads; i++) {
            buffers[i] = new char[chunk_size];
        }

        bool done = false;
        while (!done) {
            unsigned int active = 0;

            for (unsigned int i = 0; i < num_threads; i++) {
                size_t bytes_read = fread(buffers[i], 1, chunk_size, raw_file);
                if (bytes_read == 0) {
                    done = true;
                    break;
                }
                jobs[i] = { buffers[i], bytes_read, 0, 0 };
                active++;
            }

            if (active == 0) break;

            if (active == 1) {
                count_characters(&jobs[0]);
                total_gt += jobs[0].gt_count;
                total_nl += jobs[0].nl_count;
            } else {
                for (unsigned int i = 0; i < active; i++) {
                    pthread_create(&threads[i], nullptr, count_characters, &jobs[i]);
                }
                for (unsigned int i = 0; i < active; i++) {
                    pthread_join(threads[i], nullptr);
                    total_gt += jobs[i].gt_count;
                    total_nl += jobs[i].nl_count;
                }
            }
        }

        for (unsigned int i = 0; i < num_threads; i++) {
            delete[] buffers[i];
        }
    }

    if (gz_input_stream) {
        gzclose(gz_input_stream);
    }
    if (raw_file && raw_file != stdin) {
        fclose(raw_file);
    }

    if (first_char == '>') {
        result.count = total_gt + 1;
        result.format = "FASTA";
    } else if (first_char == '@') {
        result.count = total_nl / 4;
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

    if (filenames.empty()) {
        filenames.push_back("-");
    }

    std::vector<FileResult> results;
    for (const char* filename : filenames) {
        FileResult result = process_file(filename, use_gzip, use_verbose);
        results.push_back(result);
    }

    for (const FileResult& result : results) {
        std::cout << result.filename << "\t" << result.count << "\t" << result.format << std::endl;
    }

    for (const FileResult& result : results) {
        if (result.count < 0) {
            return 1;
        }
    }

    return 0;
}
