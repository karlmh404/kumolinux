#include <algorithm>
#include <array>
#include <cerrno>
#include <cctype>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <limits>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <tuple>
#include <ctime>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>
#include <vector>
#include <curl/curl.h>
#include <openssl/evp.h>
#include <openssl/pem.h>

namespace fs = std::filesystem;

namespace {

constexpr const char *kVersion = "0.3.0";
constexpr int kFormatVersion = 1;
const std::string kArchitecture = "x86_64";

struct TomlDoc {
    std::map<std::string, std::string> values;
    std::vector<std::map<std::string, std::string>> records;
    std::vector<std::string> tables;
};

struct Package {
    std::string name;
    std::string version;
    int release = 0;
    std::string architecture;
    std::string description;
    std::string source_url;
    std::string source_hash;
    std::string filename;
    std::string archive_hash;
    std::uint64_t archive_size = 0;
    std::vector<std::string> dependencies;
    fs::path repo_path;
    std::string repository_url;
    bool remote = false;
    std::string metadata_text;
};

struct ManifestEntry {
    char type = 0;
    unsigned mode = 0;
    std::uint64_t size = 0;
    std::string hash;
    std::string path;
    std::string target;
};

struct Repository {
    std::string name;
    std::string configured_path;
    std::string url;
    std::string trust = "local";
    std::string key_id;
    std::string channel = "stable";
    fs::path path;
    bool remote = false;
    bool enabled = true;
};

struct TarEntry {
    std::string name;
    char type = 0;
    unsigned mode = 0;
    std::uint64_t size = 0;
    std::string link;
    std::uint64_t data_offset = 0;
};

fs::path g_root = "/";
fs::path g_config;
fs::path g_database;
fs::path g_transactions;
fs::path g_cache;

std::string trim(const std::string &value) {
    const auto first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return {};
    const auto last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
}

std::string unquote(const std::string &value) {
    std::string text = trim(value);
    if (text.size() < 2 || text.front() != '"' || text.back() != '"')
        throw std::runtime_error("expected a quoted TOML string");
    std::string result;
    for (std::size_t i = 1; i + 1 < text.size(); ++i) {
        if (text[i] == '\\') {
            if (++i + 1 > text.size()) throw std::runtime_error("invalid TOML escape");
            switch (text[i]) {
            case 'n': result.push_back('\n'); break;
            case 'r': result.push_back('\r'); break;
            case 't': result.push_back('\t'); break;
            case '"': result.push_back('"'); break;
            case '\\': result.push_back('\\'); break;
            default: throw std::runtime_error("unsupported TOML escape");
            }
        } else {
            result.push_back(text[i]);
        }
    }
    return result;
}

std::vector<std::string> parse_array(const std::string &value) {
    std::string text = trim(value);
    if (text.size() < 2 || text.front() != '[' || text.back() != ']')
        throw std::runtime_error("expected a TOML array");
    std::vector<std::string> result;
    std::size_t start = 1;
    bool quoted = false;
    bool escaped = false;
    for (std::size_t i = 1; i < text.size() - 1; ++i) {
        const char ch = text[i];
        if (escaped) { escaped = false; continue; }
        if (quoted && ch == '\\') { escaped = true; continue; }
        if (ch == '"') { quoted = !quoted; continue; }
        if (ch == ',' && !quoted) {
            const std::string item = trim(text.substr(start, i - start));
            if (!item.empty()) result.push_back(unquote(item));
            start = i + 1;
        }
    }
    const std::string item = trim(text.substr(start, text.size() - 1 - start));
    if (!item.empty()) result.push_back(unquote(item));
    return result;
}

TomlDoc parse_toml(const std::string &text) {
    TomlDoc doc;
    std::string section;
    std::map<std::string, std::string> *record = nullptr;
    std::istringstream input(text);
    std::string line;
    unsigned line_number = 0;
    while (std::getline(input, line)) {
        ++line_number;
        line = trim(line);
        if (line.empty() || line[0] == '#') continue;
        if (line == "[[package]]" || line == "[[repository]]" || line == "[[file]]") {
            doc.tables.push_back(line);
            section = line.substr(2, line.size() - 4);
            doc.records.emplace_back();
            record = &doc.records.back();
            continue;
        }
        if (line.front() == '[' && line.back() == ']') {
            doc.tables.push_back(line);
            section = line.substr(1, line.size() - 2);
            record = nullptr;
            continue;
        }
        bool quoted = false;
        std::size_t equals = std::string::npos;
        for (std::size_t i = 0; i < line.size(); ++i) {
            if (line[i] == '"') quoted = !quoted;
            else if (line[i] == '=' && !quoted) { equals = i; break; }
        }
        if (equals == std::string::npos)
            throw std::runtime_error("invalid TOML at line " + std::to_string(line_number));
        const std::string key = trim(line.substr(0, equals));
        const std::string value = trim(line.substr(equals + 1));
        const std::string full_key = section.empty() ? key : section + "." + key;
        auto &values = record ? *record : doc.values;
        if (!values.emplace(record ? key : full_key, value).second)
            throw std::runtime_error("duplicate TOML key at line " + std::to_string(line_number));
    }
    return doc;
}

std::string read_text(const fs::path &path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) throw std::runtime_error("cannot read " + path.string());
    std::ostringstream content;
    content << input.rdbuf();
    return content.str();
}

std::string toml_string(const TomlDoc &doc, const std::string &key,
                        const std::string &fallback = {}) {
    const auto it = doc.values.find(key);
    return it == doc.values.end() ? fallback : unquote(it->second);
}

std::uint64_t parse_integer(const std::string &value, const std::string &field) {
    if (value.empty() || !std::all_of(value.begin(), value.end(), [](unsigned char ch) {
            return ch >= '0' && ch <= '9';
        }))
        throw std::runtime_error("invalid integer for " + field);
    std::size_t parsed = 0;
    const auto result = std::stoull(value, &parsed);
    if (parsed != value.size()) throw std::runtime_error("invalid integer for " + field);
    return result;
}

std::uint64_t toml_integer(const TomlDoc &doc, const std::string &key,
                           std::uint64_t fallback = 0) {
    const auto it = doc.values.find(key);
    return it == doc.values.end() ? fallback : parse_integer(it->second, key);
}

std::vector<std::string> toml_array(const TomlDoc &doc, const std::string &key) {
    const auto it = doc.values.find(key);
    return it == doc.values.end() ? std::vector<std::string>{} : parse_array(it->second);
}

Package package_from_metadata(const std::string &text) {
    const TomlDoc doc = parse_toml(text);
    if (toml_integer(doc, "kpkg_version") != kFormatVersion)
        throw std::runtime_error("unsupported .kpkg format version");
    Package package;
    package.name = toml_string(doc, "package.name");
    package.version = toml_string(doc, "package.version");
    package.release = static_cast<int>(toml_integer(doc, "package.release"));
    package.architecture = toml_string(doc, "package.architecture");
    package.description = toml_string(doc, "package.description");
    package.source_url = toml_string(doc, "source.url");
    package.source_hash = toml_string(doc, "source.sha256");
    package.dependencies = toml_array(doc, "dependencies.runtime");
    if (package.name.empty() || package.version.empty() || package.release < 1)
        throw std::runtime_error("incomplete package metadata");
    return package;
}

std::string sha256(const fs::path &path) {
    static constexpr std::array<std::uint32_t, 64> k = {
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,
        0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,
        0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,
        0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,
        0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,
        0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,
        0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,
        0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,
        0xc67178f2
    };
    std::ifstream input(path, std::ios::binary);
    if (!input) throw std::runtime_error("cannot hash " + path.string());
    std::vector<unsigned char> data((std::istreambuf_iterator<char>(input)), {});
    const std::uint64_t bits = static_cast<std::uint64_t>(data.size()) * 8;
    data.push_back(0x80);
    while (data.size() % 64 != 56) data.push_back(0);
    for (int i = 7; i >= 0; --i) data.push_back(static_cast<unsigned char>(bits >> (i * 8)));
    std::array<std::uint32_t, 8> h = {
        0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
        0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19
    };
    auto rotate = [](std::uint32_t x, unsigned n) { return (x >> n) | (x << (32 - n)); };
    for (std::size_t offset = 0; offset < data.size(); offset += 64) {
        std::array<std::uint32_t, 64> w{};
        for (unsigned i = 0; i < 16; ++i) {
            const std::size_t p = offset + i * 4;
            w[i] = (std::uint32_t(data[p]) << 24) | (std::uint32_t(data[p+1]) << 16)
                 | (std::uint32_t(data[p+2]) << 8) | data[p+3];
        }
        for (unsigned i = 16; i < 64; ++i) {
            const auto s0 = rotate(w[i-15],7) ^ rotate(w[i-15],18) ^ (w[i-15] >> 3);
            const auto s1 = rotate(w[i-2],17) ^ rotate(w[i-2],19) ^ (w[i-2] >> 10);
            w[i] = w[i-16] + s0 + w[i-7] + s1;
        }
        auto [a,b,c,d,e,f,g,hh] = h;
        for (unsigned i = 0; i < 64; ++i) {
            const auto s1 = rotate(e,6) ^ rotate(e,11) ^ rotate(e,25);
            const auto choice = (e & f) ^ (~e & g);
            const auto t1 = hh + s1 + choice + k[i] + w[i];
            const auto s0 = rotate(a,2) ^ rotate(a,13) ^ rotate(a,22);
            const auto majority = (a & b) ^ (a & c) ^ (b & c);
            const auto t2 = s0 + majority;
            hh=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2;
        }
        h[0]+=a; h[1]+=b; h[2]+=c; h[3]+=d;
        h[4]+=e; h[5]+=f; h[6]+=g; h[7]+=hh;
    }
    std::ostringstream result;
    result << std::hex << std::setfill('0');
    for (auto value : h) result << std::setw(8) << value;
    return result.str();
}

std::string normalize_https_url(const std::string &value) {
    if (value.rfind("https://", 0) != 0)
        throw std::runtime_error("repository URL must use HTTPS");
    const auto authority_end = value.find_first_of("/?#", 8);
    const std::string authority = value.substr(8, authority_end == std::string::npos
        ? std::string::npos : authority_end - 8);
    if (authority.empty() || authority.find('@') != std::string::npos
        || value.find_first_of("?#") != std::string::npos
        || std::any_of(value.begin(), value.end(), [](unsigned char ch) {
            return std::isspace(ch) || ch < 0x20;
        }))
        throw std::runtime_error("invalid HTTPS repository URL");
    std::string result = value;
    while (result.size() > 8 && result.back() == '/') result.pop_back();
    return result;
}

struct CurlOutput {
    std::ofstream *stream = nullptr;
    std::uint64_t limit = 0;
    std::uint64_t received = 0;
};

std::size_t curl_write(void *data, std::size_t size, std::size_t count, void *context) {
    auto *output = static_cast<CurlOutput *>(context);
    if (size != 0 && count > std::numeric_limits<std::size_t>::max() / size) return 0;
    const std::size_t bytes = size * count;
    if (output->received > output->limit || bytes > output->limit - output->received) return 0;
    output->stream->write(static_cast<const char *>(data), static_cast<std::streamsize>(bytes));
    if (!*output->stream) return 0;
    output->received += bytes;
    return bytes;
}

void download_https(const std::string &url, const fs::path &destination,
                    const std::uint64_t maximum_size) {
    static const bool curl_ready = curl_global_init(CURL_GLOBAL_DEFAULT) == CURLE_OK;
    if (!curl_ready) throw std::runtime_error("cannot initialize HTTPS transport");
    if (maximum_size == 0) throw std::runtime_error("invalid download size limit");
    fs::create_directories(destination.parent_path());
    std::ofstream output(destination, std::ios::binary | std::ios::trunc);
    if (!output) throw std::runtime_error("cannot create download file " + destination.string());
    CURL *handle = curl_easy_init();
    if (!handle) {
        output.close();
        fs::remove(destination);
        throw std::runtime_error("cannot initialize HTTPS request");
    }
    CurlOutput context{&output, maximum_size, 0};
    char error_buffer[CURL_ERROR_SIZE] = {};
    CURLcode result = CURLE_OK;
    auto set_option = [&](CURLoption option, auto value) {
        if (result == CURLE_OK) result = curl_easy_setopt(handle, option, value);
    };
    set_option(CURLOPT_URL, url.c_str());
    set_option(CURLOPT_PROTOCOLS_STR, "https");
    set_option(CURLOPT_REDIR_PROTOCOLS_STR, "https");
    set_option(CURLOPT_FOLLOWLOCATION, 1L);
    set_option(CURLOPT_MAXREDIRS, 5L);
    set_option(CURLOPT_CONNECTTIMEOUT, 15L);
    set_option(CURLOPT_TIMEOUT, 120L);
    set_option(CURLOPT_NOSIGNAL, 1L);
    set_option(CURLOPT_FAILONERROR, 1L);
    set_option(CURLOPT_SSL_VERIFYPEER, 1L);
    set_option(CURLOPT_SSL_VERIFYHOST, 2L);
    set_option(CURLOPT_USERAGENT, "kpm/0.3.0");
    set_option(CURLOPT_ERRORBUFFER, error_buffer);
    set_option(CURLOPT_WRITEFUNCTION, curl_write);
    set_option(CURLOPT_WRITEDATA, &context);
    if (result == CURLE_OK) result = curl_easy_perform(handle);
    long response = 0;
    curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &response);
    curl_easy_cleanup(handle);
    output.close();
    if (result != CURLE_OK || response < 200 || response >= 300 || !output) {
        fs::remove(destination);
        std::string message = error_buffer[0] ? error_buffer : curl_easy_strerror(result);
        if (result == CURLE_OK) message = "HTTP status " + std::to_string(response);
        throw std::runtime_error("HTTPS download failed for " + url + ": " + message);
    }
}

std::vector<std::string> split_tabs(const std::string &line) {
    std::vector<std::string> fields;
    std::size_t start = 0;
    while (true) {
        const auto end = line.find('\t', start);
        fields.push_back(line.substr(start, end == std::string::npos ? end : end - start));
        if (end == std::string::npos) break;
        start = end + 1;
    }
    return fields;
}

bool safe_relative(const std::string &value) {
    if (value.empty() || value.front() == '/' || value.find('\0') != std::string::npos)
        return false;
    const fs::path path(value);
    for (const auto &part : path)
        if (part == "." || part == ".." || part.empty()) return false;
    return path.lexically_normal().generic_string() == value;
}

bool safe_link_target(const std::string &path, const std::string &target) {
    if (target.empty() || target.find('\0') != std::string::npos) return false;
    fs::path resolved = target.front() == '/' ? fs::path(target).relative_path()
                                               : (fs::path(path).parent_path() / target);
    int depth = 0;
    for (const auto &part : resolved) {
        if (part == "." || part.empty()) continue;
        if (part == "..") {
            if (--depth < 0) return false;
        } else {
            ++depth;
        }
    }
    return true;
}

std::vector<ManifestEntry> parse_manifest(const std::string &text) {
    std::vector<ManifestEntry> entries;
    std::istringstream input(text);
    std::string line;
    std::set<std::string> paths;
    while (std::getline(input, line)) {
        if (line.empty()) continue;
        const auto fields = split_tabs(line);
        if (fields.size() < 5 || fields.size() > 6 || fields[0].size() != 1)
            throw std::runtime_error("invalid package manifest line");
        ManifestEntry entry;
        entry.type = fields[0][0];
        entry.mode = static_cast<unsigned>(std::stoul(fields[1], nullptr, 8));
        entry.size = std::stoull(fields[2]);
        entry.hash = fields[3];
        entry.path = fields[4];
        if (fields.size() == 6) entry.target = fields[5];
        if (!safe_relative(entry.path) || !paths.insert(entry.path).second)
            throw std::runtime_error("unsafe or duplicate path in package manifest");
        if (entry.type != 'f' && entry.type != 'd' && entry.type != 'l')
            throw std::runtime_error("unsupported package manifest entry type");
        if ((entry.type == 'f' && (entry.hash.size() != 64 || fields.size() != 5))
            || (entry.type == 'd' && (entry.size != 0 || fields.size() != 5))
            || (entry.type == 'l' && (fields.size() != 6 || !safe_link_target(entry.path, entry.target))))
            throw std::runtime_error("invalid package manifest entry");
        entries.push_back(entry);
    }
    return entries;
}

std::uint64_t parse_octal(const unsigned char *field, std::size_t length) {
    std::size_t i = 0;
    while (i < length && (field[i] == ' ' || field[i] == '\0')) ++i;
    std::uint64_t value = 0;
    for (; i < length && field[i] != '\0' && field[i] != ' '; ++i) {
        if (field[i] < '0' || field[i] > '7')
            throw std::runtime_error("invalid tar header numeric field");
        value = value * 8 + (field[i] - '0');
    }
    return value;
}

std::string tar_field(const unsigned char *data, std::size_t length) {
    std::size_t size = 0;
    while (size < length && data[size]) ++size;
    return std::string(reinterpret_cast<const char *>(data), size);
}

std::string capture_command(const char *command, const fs::path &input) {
    int descriptors[2];
    if (pipe(descriptors) != 0) throw std::runtime_error("cannot create command pipe");
    const pid_t child = fork();
    if (child < 0) throw std::runtime_error("cannot fork package utility");
    if (child == 0) {
        close(descriptors[0]);
        dup2(descriptors[1], STDOUT_FILENO);
        close(descriptors[1]);
        execlp(command, command, "-q", "-d", "-c", input.c_str(), static_cast<char *>(nullptr));
        _exit(127);
    }
    close(descriptors[1]);
    std::string result;
    char buffer[8192];
    ssize_t count;
    while ((count = read(descriptors[0], buffer, sizeof(buffer))) > 0)
        result.append(buffer, static_cast<std::size_t>(count));
    close(descriptors[0]);
    int status = 0;
    if (waitpid(child, &status, 0) < 0 || !WIFEXITED(status) || WEXITSTATUS(status) != 0)
        throw std::runtime_error(std::string("cannot decompress package with ") + command);
    return result;
}

std::vector<TarEntry> parse_tar(const std::string &archive, std::string &metadata,
                                std::string &manifest) {
    std::vector<TarEntry> entries;
    std::set<std::string> names;
    std::size_t offset = 0;
    bool have_metadata = false, have_manifest = false, have_root = false;
    while (offset + 512 <= archive.size()) {
        const auto *header = reinterpret_cast<const unsigned char *>(archive.data() + offset);
        bool zero = true;
        for (std::size_t i = 0; i < 512; ++i) if (header[i]) { zero = false; break; }
        if (zero) break;
        const std::uint64_t expected_checksum = parse_octal(header + 148, 8);
        std::uint64_t actual_checksum = 0;
        for (std::size_t i = 0; i < 512; ++i)
            actual_checksum += (i >= 148 && i < 156) ? ' ' : header[i];
        if (expected_checksum != actual_checksum)
            throw std::runtime_error("invalid tar header checksum");
        const std::string name = tar_field(header, 100);
        const std::string prefix = tar_field(header + 345, 155);
        std::string full_name = prefix.empty() ? name : prefix + "/" + name;
        char type = static_cast<char>(header[156]);
        if (type == '\0') type = '0';
        if (type != '0' && type != '5' && type != '2')
            throw std::runtime_error("unsupported tar entry type");
        const std::uint64_t size = parse_octal(header + 124, 12);
        const unsigned mode = static_cast<unsigned>(parse_octal(header + 100, 8) & 07777);
        const std::string link = tar_field(header + 157, 100);
        if (full_name.empty() || full_name.front() == '/' || full_name.find("../") != std::string::npos
            || full_name == ".." || full_name.find("/..") != std::string::npos)
            throw std::runtime_error("unsafe path in package archive");
        while (!full_name.empty() && full_name.back() == '/') full_name.pop_back();
        if (!names.insert(full_name).second) throw std::runtime_error("duplicate path in package archive");
        const std::uint64_t data_offset = offset + 512;
        if (size > archive.size() - data_offset)
            throw std::runtime_error("truncated package archive");
        if (type == '2' && !safe_link_target(full_name.rfind("root/", 0) == 0 ? full_name.substr(5) : full_name, link))
            throw std::runtime_error("unsafe symlink target in package archive");
        if (full_name == "metadata.toml" && type == '0') {
            metadata.assign(archive.data() + data_offset, static_cast<std::size_t>(size));
            have_metadata = true;
        } else if (full_name == "manifest.txt" && type == '0') {
            manifest.assign(archive.data() + data_offset, static_cast<std::size_t>(size));
            have_manifest = true;
        } else if (full_name == "root" && type == '5') {
            have_root = true;
        } else if (full_name != "metadata.toml" && full_name != "manifest.txt"
                   && full_name != "root" && full_name.rfind("root/", 0) != 0) {
            throw std::runtime_error("unexpected top-level path in package archive");
        }
        entries.push_back({full_name, type, mode, size, link, data_offset});
        offset = static_cast<std::size_t>(data_offset + ((size + 511) / 512) * 512);
    }
    if (!have_metadata || !have_manifest || !have_root)
        throw std::runtime_error("package archive is missing required members");
    return entries;
}

void write_from_tar(const std::string &archive, const TarEntry &entry, const fs::path &destination) {
    std::ofstream output(destination, std::ios::binary | std::ios::trunc);
    if (!output) throw std::runtime_error("cannot stage " + destination.string());
    output.write(archive.data() + entry.data_offset, static_cast<std::streamsize>(entry.size));
    if (!output) throw std::runtime_error("cannot write staged file " + destination.string());
    output.close();
    fs::permissions(destination, static_cast<fs::perms>(entry.mode), fs::perm_options::replace);
}

struct StagedPackage {
    Package package;
    std::string metadata;
    std::vector<ManifestEntry> manifest;
    fs::path root;
};

StagedPackage stage_package(const Package &expected, const fs::path &archive,
                            const fs::path &transaction) {
    if (sha256(archive) != expected.archive_hash)
        throw std::runtime_error(expected.name + ": archive SHA-256 mismatch");
    const std::string tar = capture_command("zstd", archive);
    std::string metadata_text, manifest_text;
    const auto tar_entries = parse_tar(tar, metadata_text, manifest_text);
    Package actual = package_from_metadata(metadata_text);
    if (actual.name != expected.name || actual.version != expected.version
        || actual.release != expected.release || actual.architecture != expected.architecture
        || actual.dependencies != expected.dependencies)
        throw std::runtime_error("repository index and package metadata disagree");
    if (actual.architecture != kArchitecture)
        throw std::runtime_error(actual.name + ": incompatible architecture " + actual.architecture);
    auto manifest = parse_manifest(manifest_text);
    std::map<std::string, char> archived;
    for (const auto &entry : tar_entries) {
        if (entry.name == "root") continue;
        if (entry.name.rfind("root/", 0) == 0)
            archived.emplace(entry.name.substr(5), entry.type);
    }
    if (archived.size() != manifest.size())
        throw std::runtime_error(actual.name + ": archive and manifest path sets differ");
    for (const auto &entry : manifest) {
        const auto found = archived.find(entry.path);
        const char expected_type = entry.type == 'f' ? '0' : entry.type == 'd' ? '5' : '2';
        if (found == archived.end() || found->second != expected_type)
            throw std::runtime_error(actual.name + ": archive does not match manifest at " + entry.path);
    }

    fs::path stage_root = transaction / "stage" / actual.name / "root";
    fs::create_directories(stage_root);
    for (const auto &entry : manifest) {
        if (entry.type == 'd') fs::create_directories(stage_root / entry.path);
    }
    for (const auto &entry : tar_entries) {
        if (entry.name.rfind("root/", 0) != 0) continue;
        const std::string relative = entry.name.substr(5);
        if (relative.empty()) continue;
        const fs::path destination = stage_root / relative;
        if (entry.type == '5') {
            fs::create_directories(destination);
            fs::permissions(destination, static_cast<fs::perms>(entry.mode), fs::perm_options::replace);
        } else if (entry.type == '0') {
            fs::create_directories(destination.parent_path());
            write_from_tar(tar, entry, destination);
        } else if (entry.type == '2') {
            fs::create_directories(destination.parent_path());
            fs::create_symlink(entry.link, destination);
        }
    }
    for (const auto &entry : manifest) {
        const fs::path path = stage_root / entry.path;
        if (entry.type == 'f') {
            if (!fs::is_regular_file(path) || fs::file_size(path) != entry.size || sha256(path) != entry.hash)
                throw std::runtime_error(actual.name + ": staged file does not match manifest: " + entry.path);
        } else if (entry.type == 'd') {
            if (!fs::is_directory(path)) throw std::runtime_error(actual.name + ": staged directory missing");
        } else if (!fs::is_symlink(path) || fs::read_symlink(path).string() != entry.target) {
            throw std::runtime_error(actual.name + ": staged symlink mismatch: " + entry.path);
        }
    }
    actual.filename = expected.filename;
    actual.archive_hash = expected.archive_hash;
    actual.archive_size = expected.archive_size;
    actual.repo_path = expected.repo_path;
    actual.metadata_text = metadata_text;
    return {actual, metadata_text, manifest, stage_root};
}

std::string hex_mode(unsigned mode) {
    std::ostringstream output;
    output << std::oct << std::setfill('0') << std::setw(4) << mode;
    return output.str();
}

std::string manifest_text(const std::vector<ManifestEntry> &entries) {
    std::string result;
    for (const auto &entry : entries) {
        result += entry.type;
        result += '\t' + hex_mode(entry.mode) + '\t' + std::to_string(entry.size) + '\t'
               + (entry.hash.empty() ? "-" : entry.hash) + '\t' + entry.path;
        if (entry.type == 'l') result += '\t' + entry.target;
        result += '\n';
    }
    return result;
}

std::string toml_quote(const std::string &value) {
    std::string result = "\"";
    for (char ch : value) {
        if (ch == '\\' || ch == '"') result.push_back('\\');
        if (ch == '\n') result += "\\n";
        else if (ch == '\r') result += "\\r";
        else if (ch == '\t') result += "\\t";
        else result.push_back(ch);
    }
    result.push_back('"');
    return result;
}

fs::path target_path(const fs::path &absolute) {
    if (!absolute.is_absolute()) throw std::runtime_error("expected an absolute target path");
    if (g_root == "/") return absolute;
    return g_root / absolute.relative_path();
}

std::vector<ManifestEntry> load_manifest(const fs::path &path) {
    return parse_manifest(read_text(path));
}

bool valid_repo_name(const std::string &name) {
    return !name.empty() && std::all_of(name.begin(), name.end(), [](unsigned char ch) {
        return std::isalnum(ch) || ch == '-' || ch == '_';
    });
}

bool valid_key_id(const std::string &key_id);

std::vector<Repository> load_repositories() {
    std::vector<Repository> repositories;
    if (!fs::exists(g_config)) return repositories;
    TomlDoc doc = parse_toml(read_text(g_config));
    const auto arch = toml_string(doc, "architecture");
    if (!arch.empty() && arch != kArchitecture)
        throw std::runtime_error("kpm configuration architecture mismatch");
    for (const auto &record : doc.records) {
        if (!record.count("name"))
            throw std::runtime_error("repository configuration is missing a name");
        Repository repository;
        repository.name = unquote(record.at("name"));
        if (!valid_repo_name(repository.name))
            throw std::runtime_error("invalid repository name: " + repository.name);
        const bool has_path = record.count("path") != 0;
        const bool has_url = record.count("url") != 0;
        if (has_path == has_url)
            throw std::runtime_error(repository.name + ": configure exactly one of path or url");
        if (has_url) {
            repository.remote = true;
            repository.url = normalize_https_url(unquote(record.at("url")));
            repository.trust = record.count("trust") ? unquote(record.at("trust")) : "";
            repository.key_id = record.count("key_id") ? unquote(record.at("key_id")) : "";
            repository.channel = record.count("channel") ? unquote(record.at("channel")) : "";
            if (repository.trust != "ed25519" || !valid_key_id(repository.key_id)
                || (repository.channel != "stable" && repository.channel != "testing"))
                throw std::runtime_error(repository.name
                    + ": HTTPS repositories require trust = \"ed25519\", an authorized key_id, and channel");
            repository.path = g_cache / "repositories" / repository.name / "current";
        } else {
            if (record.count("trust") && unquote(record.at("trust")) != "local")
                throw std::runtime_error(repository.name + ": filesystem repositories must use local trust");
            repository.configured_path = unquote(record.at("path"));
            const fs::path configured(repository.configured_path);
            if (!configured.is_absolute())
                throw std::runtime_error(repository.name + ": repository path must be absolute");
            repository.path = target_path(configured);
        }
        if (record.count("enabled")) {
            const std::string enabled = trim(record.at("enabled"));
            if (enabled != "true" && enabled != "false")
                throw std::runtime_error(repository.name + ": enabled must be true or false");
            repository.enabled = enabled == "true";
        }
        repositories.push_back(repository);
    }
    return repositories;
}

std::vector<Package> parse_repo_index(const std::string &text, const Repository &repository) {
    const TomlDoc doc = parse_toml(text);
    if (toml_integer(doc, "format_version") != 1)
        throw std::runtime_error("unsupported repository index format: " + repository.name);
    if (toml_string(doc, "architecture") != kArchitecture)
        throw std::runtime_error("repository architecture mismatch: " + repository.name);
    const auto count = doc.values.find("package_count");
    if (count != doc.values.end() && toml_integer(doc, "package_count") != doc.records.size())
        throw std::runtime_error("repository package count mismatch: " + repository.name);

    std::vector<Package> packages;
    std::set<std::tuple<std::string, std::string, int>> seen;
    for (const auto &record : doc.records) {
        Package package;
        auto get = [&](const std::string &key, const std::string &fallback = {}) {
            const auto it = record.find(key);
            if (it == record.end()) return fallback;
            const std::string value = trim(it->second);
            return !value.empty() && value.front() == '"' ? unquote(value) : value;
        };
        package.name = get("name");
        package.version = get("version");
        const auto release = parse_integer(get("release", "0"), "package.release");
        if (release > static_cast<std::uint64_t>(std::numeric_limits<int>::max()))
            throw std::runtime_error("package release is out of range in " + repository.name);
        package.release = static_cast<int>(release);
        package.architecture = get("architecture");
        package.description = get("description");
        package.filename = get("filename");
        package.archive_hash = get("sha256");
        package.archive_size = parse_integer(get("size", "0"), "package.size");
        const auto deps = record.find("runtime_dependencies");
        if (deps != record.end()) package.dependencies = parse_array(deps->second);
        const std::string expected_filename = package.name + "-" + package.version + "-"
            + std::to_string(package.release) + "-" + kArchitecture + ".kpkg";
        const bool valid_hash = package.archive_hash.size() == 64
            && std::all_of(package.archive_hash.begin(), package.archive_hash.end(), [](unsigned char ch) {
                return (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f');
            });
        if (!valid_repo_name(package.name) || package.version.empty() || package.release < 1
            || package.architecture != kArchitecture || package.filename != expected_filename
            || !valid_hash || package.archive_size == 0
            || package.archive_size > 2ULL * 1024 * 1024 * 1024
            || !seen.emplace(package.name, package.version, package.release).second)
            throw std::runtime_error("invalid or duplicate package record in repository " + repository.name);
        package.remote = repository.remote;
        package.repository_url = repository.url;
        package.repo_path = repository.remote ? g_cache / "packages" : repository.path / "packages";
        packages.push_back(std::move(package));
    }
    return packages;
}

std::uint64_t validate_repository_metadata(const std::string &text, const Repository &repository) {
    const TomlDoc doc = parse_toml(text);
    if (toml_integer(doc, "repository_format") != 1)
        throw std::runtime_error("unsupported repository format: " + repository.name);
    const std::string channel = toml_string(doc, "repository.channel");
    if (channel != repository.channel)
        throw std::runtime_error("repository channel mismatch: " + repository.name);
    if (toml_string(doc, "repository.architecture") != kArchitecture)
        throw std::runtime_error("repository architecture mismatch: " + repository.name);
    if (toml_string(doc, "repository.name").empty())
        throw std::runtime_error("repository metadata has no name: " + repository.name);
    return toml_integer(doc, "repository.package_count");
}

bool valid_key_id(const std::string &key_id) {
    return key_id.size() == 71 && key_id.compare(0, 7, "sha256:") == 0
        && std::all_of(key_id.begin() + 7, key_id.end(), [](unsigned char ch) {
            return (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f');
        });
}

bool valid_sha256(const std::string &hash) {
    return hash.size() == 64 && std::all_of(hash.begin(), hash.end(), [](unsigned char ch) {
        return (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f');
    });
}

std::string sha256_bytes(const std::string &data) {
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int length = 0;
    if (EVP_Digest(data.data(), data.size(), digest, &length, EVP_sha256(), nullptr) != 1
        || length != 32)
        throw std::runtime_error("cannot calculate SHA-256 digest");
    std::ostringstream result;
    result << std::hex << std::setfill('0');
    for (unsigned int i = 0; i < length; ++i) result << std::setw(2) << static_cast<unsigned>(digest[i]);
    return result.str();
}

std::time_t parse_utc_time(const std::string &text, const std::string &field) {
    std::tm parsed{};
    char *end = strptime(text.c_str(), "%Y-%m-%dT%H:%M:%SZ", &parsed);
    if (!end || *end != '\0')
        throw std::runtime_error("invalid UTC timestamp in " + field);
    const std::time_t timestamp = timegm(&parsed);
    std::tm normalized{};
    char formatted[32];
    if (!gmtime_r(&timestamp, &normalized)
        || std::strftime(formatted, sizeof(formatted), "%Y-%m-%dT%H:%M:%SZ", &normalized) == 0
        || text != formatted)
        throw std::runtime_error("invalid UTC timestamp in " + field);
    return timestamp;
}

struct SignedSnapshot {
    std::uint64_t sequence = 0;
    std::string channel;
    std::time_t expires = 0;
    std::map<std::string, std::pair<std::uint64_t, std::string>> files;
};

SignedSnapshot parse_signed_snapshot(const std::string &text, const Repository &repository) {
    const TomlDoc doc = parse_toml(text);
    if (doc.values.size() != 5 || doc.records.size() != 2
        || doc.tables != std::vector<std::string>{"[[file]]", "[[file]]"}
        || !doc.values.count("format_version") || !doc.values.count("channel")
        || !doc.values.count("architecture") || !doc.values.count("sequence")
        || !doc.values.count("expires") || toml_integer(doc, "format_version") != 1)
        throw std::runtime_error("invalid or unsupported signed repository snapshot");
    SignedSnapshot snapshot;
    snapshot.sequence = toml_integer(doc, "sequence");
    snapshot.channel = toml_string(doc, "channel");
    if (snapshot.sequence == 0 || snapshot.channel != repository.channel
        || toml_string(doc, "architecture") != kArchitecture)
        throw std::runtime_error("signed repository snapshot channel or architecture mismatch");
    snapshot.expires = parse_utc_time(toml_string(doc, "expires"), "snapshot.expires");
    const std::time_t now = std::time(nullptr);
    if (now < 1577836800)
        throw std::runtime_error("system clock is unset; cannot verify repository expiration");
    if (snapshot.expires <= now)
        throw std::runtime_error("signed repository snapshot has expired");
    if (snapshot.expires > now + 366 * 24 * 60 * 60)
        throw std::runtime_error("signed repository snapshot expiration exceeds 366 days");

    for (const auto &record : doc.records) {
        if (record.size() != 3 || !record.count("path") || !record.count("size")
            || !record.count("sha256"))
            throw std::runtime_error("invalid signed repository snapshot file record");
        const std::string path = unquote(record.at("path"));
        const std::string hash = unquote(record.at("sha256"));
        const std::uint64_t size = parse_integer(record.at("size"), "snapshot file size");
        if ((path != "repo.toml" && path != "index.toml") || size == 0
            || size > 4 * 1024 * 1024 || !valid_sha256(hash)
            || !snapshot.files.emplace(path, std::make_pair(size, hash)).second)
            throw std::runtime_error("invalid or duplicate signed repository metadata path");
    }
    if (snapshot.files.size() != 2 || !snapshot.files.count("repo.toml")
        || !snapshot.files.count("index.toml"))
        throw std::runtime_error("signed snapshot must bind repo.toml and index.toml");
    return snapshot;
}

fs::path trusted_key_path(const std::string &key_id) {
    if (!valid_key_id(key_id)) throw std::runtime_error("invalid repository signing key ID");
    return target_path("/usr/share/kumo/keys/" + key_id.substr(7) + ".pub");
}

void verify_detached_signature(const std::string &snapshot_text, const std::string &signature_text,
                               const Repository &repository) {
    const TomlDoc signature_doc = parse_toml(signature_text);
    if (signature_doc.values.size() != 4 || !signature_doc.records.empty()
        || !signature_doc.tables.empty()
        || !signature_doc.values.count("format_version") || !signature_doc.values.count("algorithm")
        || !signature_doc.values.count("key_id") || !signature_doc.values.count("signature")
        || toml_integer(signature_doc, "format_version") != 1
        || toml_string(signature_doc, "algorithm") != "Ed25519")
        throw std::runtime_error("invalid or unsupported detached repository signature");
    const std::string signature_key_id = toml_string(signature_doc, "key_id");
    if (!valid_key_id(signature_key_id) || signature_key_id != repository.key_id)
        throw std::runtime_error("repository signature key is not authorized by KPM configuration");

    std::string encoded = toml_string(signature_doc, "signature");
    if (encoded.size() != 88 || encoded.substr(86) != "==")
        throw std::runtime_error("invalid Ed25519 signature encoding");
    unsigned char decoded[66];
    const int decoded_length = EVP_DecodeBlock(decoded,
        reinterpret_cast<const unsigned char *>(encoded.data()), static_cast<int>(encoded.size()));
    if (decoded_length != 66) throw std::runtime_error("invalid base64 repository signature");
    unsigned char canonical[89];
    const int canonical_length = EVP_EncodeBlock(canonical, decoded, 64);
    if (canonical_length != 88 || encoded != reinterpret_cast<const char *>(canonical))
        throw std::runtime_error("non-canonical base64 repository signature");

    const fs::path key_path = trusted_key_path(repository.key_id);
    BIO *bio = BIO_new_file(key_path.c_str(), "rb");
    if (!bio) throw std::runtime_error("cannot open authorized repository key: " + key_path.string());
    EVP_PKEY *raw_key = PEM_read_bio_PUBKEY(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);
    if (!raw_key) throw std::runtime_error("cannot parse authorized repository public key");
    std::unique_ptr<EVP_PKEY, decltype(&EVP_PKEY_free)> key(raw_key, EVP_PKEY_free);
    if (EVP_PKEY_base_id(key.get()) != EVP_PKEY_ED25519)
        throw std::runtime_error("authorized repository key is not Ed25519");
    unsigned char raw_public[32];
    std::size_t public_length = sizeof(raw_public);
    if (EVP_PKEY_get_raw_public_key(key.get(), raw_public, &public_length) != 1
        || public_length != sizeof(raw_public)
        || "sha256:" + sha256_bytes(std::string(reinterpret_cast<char *>(raw_public), public_length))
            != repository.key_id)
        throw std::runtime_error("authorized repository key ID does not match its public key");

    EVP_MD_CTX *raw_context = EVP_MD_CTX_new();
    if (!raw_context) throw std::runtime_error("cannot allocate signature verification context");
    std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)> context(raw_context, EVP_MD_CTX_free);
    if (EVP_DigestVerifyInit(context.get(), nullptr, nullptr, nullptr, key.get()) != 1
        || EVP_DigestVerify(context.get(), decoded, 64,
                            reinterpret_cast<const unsigned char *>(snapshot_text.data()),
                            snapshot_text.size()) != 1)
        throw std::runtime_error("repository snapshot Ed25519 signature verification failed");
}

SignedSnapshot verify_signed_snapshot(const Repository &repository, const fs::path &directory) {
    const std::string snapshot_text = read_text(directory / "snapshot.toml");
    const std::string signature_text = read_text(directory / "snapshot.toml.sig");
    const SignedSnapshot snapshot = parse_signed_snapshot(snapshot_text, repository);
    verify_detached_signature(snapshot_text, signature_text, repository);
    return snapshot;
}

void verify_snapshot_files(const SignedSnapshot &snapshot, const fs::path &directory) {
    for (const auto &file : snapshot.files) {
        const std::string contents = read_text(directory / file.first);
        if (contents.size() != file.second.first || sha256_bytes(contents) != file.second.second)
            throw std::runtime_error("signed repository metadata hash or size mismatch: " + file.first);
    }
}

std::uint64_t cached_sequence(const fs::path &current, std::string *snapshot_text = nullptr) {
    const fs::path path = current / "snapshot.toml";
    const std::string contents = read_text(path);
    const TomlDoc doc = parse_toml(contents);
    if (toml_integer(doc, "format_version") != 1 || toml_integer(doc, "sequence") == 0)
        throw std::runtime_error("cached signed repository snapshot is invalid");
    if (snapshot_text) *snapshot_text = contents;
    return toml_integer(doc, "sequence");
}

void require_root_owned_directory(const fs::path &path) {
    struct stat status{};
    if (lstat(path.c_str(), &status) != 0 || !S_ISDIR(status.st_mode)
        || status.st_uid != 0 || (status.st_mode & (S_IWGRP | S_IWOTH)) != 0)
        throw std::runtime_error("signed repository cache must be a protected root-owned directory: "
                                 + path.string());
}

void require_root_owned_chain(const std::vector<fs::path> &paths) {
    for (const auto &path : paths) require_root_owned_directory(path);
}

void sync_path(const fs::path &path, const int extra_flags = 0) {
    const int descriptor = open(path.c_str(), O_RDONLY | O_CLOEXEC | extra_flags);
    if (descriptor < 0)
        throw std::runtime_error("cannot open for durable repository state: " + path.string()
                                 + ": " + std::strerror(errno));
    if (fsync(descriptor) != 0) {
        const int error = errno;
        close(descriptor);
        throw std::runtime_error("cannot sync repository state: " + path.string()
                                 + ": " + std::strerror(error));
    }
    if (close(descriptor) != 0)
        throw std::runtime_error("cannot close repository state: " + path.string()
                                 + ": " + std::strerror(errno));
}

struct TrustedState {
    std::uint64_t sequence = 0;
    std::string snapshot_hash;
};

fs::path trusted_state_directory() {
    return target_path("/var/lib/kumo/kpm/trust");
}

fs::path trusted_state_path(const Repository &repository) {
    return trusted_state_directory() / (repository.name + ".toml");
}

void write_atomic(const fs::path &path, const std::string &content);

TrustedState load_trusted_state(const Repository &repository) {
    const fs::path directory = trusted_state_directory();
    struct stat directory_status{};
    if (lstat(directory.c_str(), &directory_status) != 0) {
        if (errno == ENOENT) return {};
        throw std::runtime_error("cannot inspect KPM trust state directory");
    }
    require_root_owned_chain({
        target_path("/var/lib"), target_path("/var/lib/kumo"),
        target_path("/var/lib/kumo/kpm"), directory,
    });
    const fs::path path = trusted_state_path(repository);
    struct stat file_status{};
    if (lstat(path.c_str(), &file_status) != 0) {
        if (errno == ENOENT) return {};
        throw std::runtime_error("cannot inspect repository trust state: " + repository.name);
    }
    if (!S_ISREG(file_status.st_mode) || file_status.st_uid != 0
        || (file_status.st_mode & (S_IWGRP | S_IWOTH)) != 0)
        throw std::runtime_error("repository trust state is not protected root-owned data: "
                                 + repository.name);
    const TomlDoc doc = parse_toml(read_text(path));
    if (doc.values.size() != 3 || !doc.records.empty() || !doc.tables.empty()
        || !doc.values.count("format_version") || !doc.values.count("sequence")
        || !doc.values.count("snapshot_sha256") || toml_integer(doc, "format_version") != 1)
        throw std::runtime_error("repository trust state is invalid: " + repository.name);
    TrustedState state;
    state.sequence = toml_integer(doc, "sequence");
    state.snapshot_hash = toml_string(doc, "snapshot_sha256");
    if (state.sequence == 0 || !valid_sha256(state.snapshot_hash))
        throw std::runtime_error("repository trust state is invalid: " + repository.name);
    return state;
}

void save_trusted_state(const Repository &repository, const std::uint64_t sequence,
                        const std::string &snapshot_hash) {
    const fs::path directory = trusted_state_directory();
    fs::create_directories(directory);
    require_root_owned_chain({
        target_path("/var/lib"), target_path("/var/lib/kumo"),
        target_path("/var/lib/kumo/kpm"), directory,
    });
    fs::permissions(directory, fs::perms::owner_all | fs::perms::group_read
        | fs::perms::group_exec | fs::perms::others_read | fs::perms::others_exec,
        fs::perm_options::replace);
    require_root_owned_directory(directory);
    const std::string contents = "format_version = 1\n"
        "sequence = " + std::to_string(sequence) + "\n"
        "snapshot_sha256 = " + toml_quote(snapshot_hash) + "\n";
    write_atomic(trusted_state_path(repository), contents);
    fs::permissions(trusted_state_path(repository), fs::perms::owner_read | fs::perms::owner_write
        | fs::perms::group_read | fs::perms::others_read, fs::perm_options::replace);
    const fs::path path = trusted_state_path(repository);
    struct stat status{};
    if (lstat(path.c_str(), &status) != 0 || !S_ISREG(status.st_mode) || status.st_uid != 0
        || (status.st_mode & (S_IWGRP | S_IWOTH)) != 0)
        throw std::runtime_error("cannot protect repository trust state: " + repository.name);
    sync_path(path);
    sync_path(directory, O_DIRECTORY);
    sync_path(directory.parent_path(), O_DIRECTORY);
    sync_path(directory.parent_path().parent_path(), O_DIRECTORY);
    sync_path(directory.parent_path().parent_path().parent_path(), O_DIRECTORY);
}

void verify_repository_cache(const Repository &repository);

std::uint64_t highest_trusted_sequence(const Repository &repository) {
    const TrustedState state = load_trusted_state(repository);
    const fs::path current = g_cache / "repositories" / repository.name / "current";
    if (!fs::exists(current) && !fs::is_symlink(current)) return state.sequence;
    verify_repository_cache(repository);
    return std::max(state.sequence, cached_sequence(current));
}

void verify_repository_cache(const Repository &repository) {
    const fs::path cache = g_cache / "repositories" / repository.name;
    const fs::path snapshots = cache / "snapshots";
    struct stat cache_status{};
    if (lstat(cache.c_str(), &cache_status) != 0) {
        if (errno == ENOENT) return;
        throw std::runtime_error("cannot inspect signed repository cache: " + repository.name);
    }
    require_root_owned_chain({
        target_path("/var/cache"), target_path("/var/cache/kumo"),
        target_path("/var/cache/kumo/kpm"), target_path("/var/cache/kumo/kpm/repositories"),
        cache, snapshots,
    });
    const fs::path current = cache / "current";
    struct stat link_status{};
    if (lstat(current.c_str(), &link_status) != 0) {
        if (errno == ENOENT) return;
        throw std::runtime_error("cannot inspect signed repository cache pointer: " + repository.name);
    }
    if (!S_ISLNK(link_status.st_mode))
        throw std::runtime_error("signed repository cache pointer is not a symlink: " + repository.name);
    require_root_owned_directory(fs::canonical(current));
    const fs::path snapshot_file = current / "snapshot.toml";
    struct stat file_status{};
    if (stat(snapshot_file.c_str(), &file_status) != 0 || !S_ISREG(file_status.st_mode)
        || file_status.st_uid != 0 || (file_status.st_mode & (S_IWGRP | S_IWOTH)) != 0)
        throw std::runtime_error("cached signed snapshot is not protected root-owned state: "
                                 + repository.name);
}

std::vector<Package> load_repo_packages(const bool enabled_only = true) {
    std::vector<Package> packages;
    for (const auto &repository : load_repositories()) {
        if (enabled_only && !repository.enabled) continue;
        const fs::path index = repository.path / "index.toml";
        if (repository.remote) verify_repository_cache(repository);
        if (!fs::is_regular_file(index))
            throw std::runtime_error(repository.remote
                ? "repository has not been refreshed: " + repository.name
                : "repository index missing: " + index.string());
        if (repository.remote) {
            const fs::path metadata = repository.path / "repo.toml";
            if (!fs::is_regular_file(metadata))
                throw std::runtime_error("repository metadata missing from cache: " + repository.name);
            const SignedSnapshot snapshot = verify_signed_snapshot(repository, repository.path);
            verify_snapshot_files(snapshot, repository.path);
            if (snapshot.sequence < load_trusted_state(repository).sequence)
                throw std::runtime_error("cached signed repository snapshot is older than trust state: "
                                         + repository.name);
            const auto expected_count = validate_repository_metadata(read_text(metadata), repository);
            auto records = parse_repo_index(read_text(index), repository);
            if (records.size() != expected_count)
                throw std::runtime_error("repository metadata package count mismatch: " + repository.name);
            packages.insert(packages.end(), records.begin(), records.end());
            continue;
        }
        auto records = parse_repo_index(read_text(index), repository);
        packages.insert(packages.end(), records.begin(), records.end());
    }
    return packages;
}

std::size_t refresh_remote_repository(const Repository &repository) {
    const fs::path cache = g_cache / "repositories" / repository.name;
    const fs::path snapshots = cache / "snapshots";
    fs::create_directories(cache);
    require_root_owned_directory(cache);
    fs::create_directories(snapshots);
    require_root_owned_directory(snapshots);
    fs::permissions(cache, fs::perms::owner_all | fs::perms::group_read
        | fs::perms::group_exec | fs::perms::others_read | fs::perms::others_exec,
        fs::perm_options::replace);
    verify_repository_cache(repository);
    const auto nonce = std::chrono::steady_clock::now().time_since_epoch().count();
    const std::string unique = std::to_string(getpid()) + "-" + std::to_string(nonce);
    const fs::path staging = snapshots / (".refresh-" + unique);
    const fs::path snapshot = snapshots / ("snapshot-" + unique);
    fs::create_directory(staging);
    try {
        download_https(repository.url + "/snapshot.toml", staging / "snapshot.toml", 64 * 1024);
        download_https(repository.url + "/snapshot.toml.sig", staging / "snapshot.toml.sig", 64 * 1024);
        const SignedSnapshot signed_snapshot = verify_signed_snapshot(repository, staging);

        const fs::path current = cache / "current";
        std::string current_snapshot;
        const TrustedState persisted_state = load_trusted_state(repository);
        std::uint64_t current_sequence = 0;
        if (fs::exists(current) || fs::is_symlink(current)) {
            if (!fs::is_symlink(current))
                throw std::runtime_error("trusted repository cache pointer is not a symlink: " + repository.name);
            verify_repository_cache(repository);
            current_sequence = cached_sequence(current, &current_snapshot);
        }
        const std::string new_snapshot = read_text(staging / "snapshot.toml");
        const std::uint64_t highest_sequence = std::max(persisted_state.sequence, current_sequence);
        if (signed_snapshot.sequence < highest_sequence)
            throw std::runtime_error("signed repository rollback detected: " + repository.name);
        if (signed_snapshot.sequence == highest_sequence && highest_sequence != 0
            && !((current_sequence == highest_sequence && new_snapshot == current_snapshot)
                || (persisted_state.sequence == highest_sequence
                    && sha256_bytes(new_snapshot) == persisted_state.snapshot_hash)))
            throw std::runtime_error("signed repository sequence was reused with different metadata: "
                                     + repository.name);

        download_https(repository.url + "/repo.toml", staging / "repo.toml", 4 * 1024 * 1024);
        download_https(repository.url + "/index.toml", staging / "index.toml", 4 * 1024 * 1024);
        verify_snapshot_files(signed_snapshot, staging);
        const auto expected_count = validate_repository_metadata(read_text(staging / "repo.toml"), repository);
        const auto packages = parse_repo_index(read_text(staging / "index.toml"), repository);
        if (packages.size() != expected_count)
            throw std::runtime_error("repository metadata package count mismatch: " + repository.name);
        for (const std::string &filename : {"snapshot.toml", "snapshot.toml.sig", "repo.toml", "index.toml"})
            sync_path(staging / filename);
        sync_path(staging, O_DIRECTORY);
        fs::rename(staging, snapshot);
        sync_path(snapshots, O_DIRECTORY);

        const fs::path temporary_link = cache / ("current.tmp-" + unique);
        fs::create_symlink(fs::path("snapshots") / snapshot.filename(), temporary_link);
        fs::rename(temporary_link, current);
        sync_path(cache, O_DIRECTORY);
        for (const fs::path &directory : {
                 cache.parent_path(), cache.parent_path().parent_path(),
                 cache.parent_path().parent_path().parent_path(),
                 cache.parent_path().parent_path().parent_path().parent_path(),
             })
            sync_path(directory, O_DIRECTORY);
        save_trusted_state(repository, signed_snapshot.sequence, sha256_bytes(new_snapshot));

        std::error_code error;
        const auto active = fs::read_symlink(current).filename();
        for (const auto &entry : fs::directory_iterator(snapshots)) {
            if (entry.path().filename() == active) continue;
            fs::remove_all(entry.path(), error);
            if (error) {
                std::cerr << "kpm: warning: cannot remove stale repository cache "
                          << entry.path() << ": " << error.message() << "\n";
                error.clear();
            }
        }
        return packages.size();
    } catch (...) {
        std::error_code error;
        fs::remove_all(staging, error);
        throw;
    }
}

fs::path package_archive(const Package &package) {
    const fs::path archive = package.repo_path / package.filename;
    if (!package.remote) return archive;
    if (fs::is_regular_file(archive) && fs::file_size(archive) == package.archive_size
        && sha256(archive) == package.archive_hash)
        return archive;

    fs::create_directories(archive.parent_path());
    const fs::path temporary = archive.string() + ".part-" + std::to_string(getpid());
    std::error_code error;
    fs::remove(temporary, error);
    const std::string url = package.repository_url + "/packages/" + package.filename;
    std::cout << "Downloading " << package.filename << " from " << package.repository_url << "\n";
    try {
        download_https(url, temporary, package.archive_size);
        if (fs::file_size(temporary) != package.archive_size) {
            fs::remove(temporary);
            throw std::runtime_error(package.name + ": package archive size mismatch");
        }
        if (sha256(temporary) != package.archive_hash) {
            fs::remove(temporary);
            throw std::runtime_error(package.name + ": package archive SHA-256 mismatch");
        }
        fs::rename(temporary, archive);
        const std::string prefix = package.name + "-";
        for (const auto &entry : fs::directory_iterator(archive.parent_path())) {
            const std::string filename = entry.path().filename().string();
            if (entry.path() == archive || filename.rfind(prefix, 0) != 0
                || entry.path().extension() != ".kpkg")
                continue;
            fs::remove(entry.path(), error);
            if (error) {
                std::cerr << "kpm: warning: cannot remove stale package cache "
                          << entry.path() << ": " << error.message() << "\n";
                error.clear();
            }
        }
    } catch (...) {
        fs::remove(temporary, error);
        throw;
    }
    return archive;
}

int compare_versions(const std::string &left, const std::string &right);

std::map<std::string, Package> latest_packages() {
    std::map<std::string, Package> latest;
    for (const auto &package : load_repo_packages()) {
        auto found = latest.find(package.name);
        if (found == latest.end() || compare_versions(package.version, found->second.version) > 0
            || (package.version == found->second.version && package.release > found->second.release))
            latest[package.name] = package;
    }
    return latest;
}

std::vector<Package> installed_packages() {
    std::vector<Package> result;
    if (!fs::is_directory(g_database)) return result;
    for (const auto &item : fs::directory_iterator(g_database)) {
        if (!item.is_directory()) continue;
        const fs::path metadata = item.path() / "metadata.toml";
        if (!fs::is_regular_file(metadata)) continue;
        Package package = package_from_metadata(read_text(metadata));
        package.metadata_text = read_text(metadata);
        result.push_back(package);
    }
    std::sort(result.begin(), result.end(), [](const auto &a, const auto &b) { return a.name < b.name; });
    return result;
}

bool is_installed(const std::string &name) {
    return fs::is_regular_file(g_database / name / "metadata.toml");
}

Package installed_package(const std::string &name) {
    const fs::path metadata = g_database / name / "metadata.toml";
    if (!fs::is_regular_file(metadata)) throw std::runtime_error("package is not installed: " + name);
    Package package = package_from_metadata(read_text(metadata));
    package.metadata_text = read_text(metadata);
    return package;
}

int compare_versions(const std::string &left, const std::string &right) {
    std::size_t a = 0, b = 0;
    while (a < left.size() || b < right.size()) {
        if (a < left.size() && b < right.size()
            && std::isdigit(static_cast<unsigned char>(left[a]))
            && std::isdigit(static_cast<unsigned char>(right[b]))) {
            std::size_t ae = a, be = b;
            while (ae < left.size() && std::isdigit(static_cast<unsigned char>(left[ae]))) ++ae;
            while (be < right.size() && std::isdigit(static_cast<unsigned char>(right[be]))) ++be;
            const std::string an = left.substr(a, ae - a), bn = right.substr(b, be - b);
            const auto az = an.find_first_not_of('0'), bz = bn.find_first_not_of('0');
            const std::string av = az == std::string::npos ? "0" : an.substr(az);
            const std::string bv = bz == std::string::npos ? "0" : bn.substr(bz);
            if (av.size() != bv.size()) return av.size() < bv.size() ? -1 : 1;
            if (av != bv) return av < bv ? -1 : 1;
            a = ae; b = be;
        } else {
            const char ac = a < left.size() ? left[a] : '\0';
            const char bc = b < right.size() ? right[b] : '\0';
            if (ac != bc) return ac < bc ? -1 : 1;
            if (a < left.size()) ++a;
            if (b < right.size()) ++b;
        }
    }
    return 0;
}

struct Dependency {
    std::string name;
    std::string operation;
    std::string version;
};

Dependency parse_dependency(const std::string &text) {
    for (const std::string op : {">=", "="}) {
        const auto position = text.find(op);
        if (position != std::string::npos)
            return {trim(text.substr(0, position)), op, trim(text.substr(position + op.size()))};
    }
    return {trim(text), {}, {}};
}

bool satisfies(const Package &package, const Dependency &dependency) {
    if (dependency.operation.empty()) return true;
    const int comparison = compare_versions(package.version, dependency.version);
    return dependency.operation == ">=" ? comparison >= 0 : comparison == 0;
}

void initialize_paths() {
    const char *prefix = std::getenv("KPM_ROOT");
    g_root = prefix && *prefix ? fs::absolute(prefix).lexically_normal() : fs::path("/");
    g_config = target_path("/etc/kumo/kpm.toml");
    g_database = target_path("/var/lib/kumo/packages");
    g_transactions = target_path("/var/lib/kumo/transactions");
    g_cache = target_path("/var/cache/kumo/kpm");
}

int acquire_lock() {
    const fs::path lock_path = target_path("/run/kumo/kpm.lock");
    fs::create_directories(lock_path.parent_path());
    const int descriptor = open(lock_path.c_str(), O_CREAT | O_RDWR, 0600);
    if (descriptor < 0 || flock(descriptor, LOCK_EX) != 0)
        throw std::runtime_error("cannot acquire package database lock");
    return descriptor;
}

std::map<std::string, std::vector<std::pair<std::string, ManifestEntry>>> file_owners() {
    std::map<std::string, std::vector<std::pair<std::string, ManifestEntry>>> owners;
    for (const auto &package : installed_packages()) {
        const fs::path manifest = g_database / package.name / "manifest.txt";
        if (!fs::is_regular_file(manifest)) continue;
        for (const auto &entry : load_manifest(manifest))
            owners[entry.path].push_back({package.name, entry});
    }
    return owners;
}

std::string plan_version(const Package &package) {
    return package.version + "-" + std::to_string(package.release);
}

bool prompt_yes(const bool yes) {
    if (yes) return true;
    std::cout << "Proceed? [y/N] " << std::flush;
    std::string answer;
    std::getline(std::cin, answer);
    return answer == "y" || answer == "Y" || answer == "yes" || answer == "YES";
}

struct Plan {
    std::vector<Package> packages;
    std::set<std::string> upgrades;
};

Plan resolve_plan(const std::vector<std::pair<std::string, std::string>> &requests,
                  const std::set<std::string> &force_upgrade) {
    const auto available = load_repo_packages();
    std::map<std::string, std::vector<Package>> by_name;
    for (const auto &package : available) {
        if (package.architecture != kArchitecture)
            throw std::runtime_error(package.name + ": incompatible repository architecture");
        by_name[package.name].push_back(package);
    }
    for (auto &entry : by_name) {
        std::sort(entry.second.begin(), entry.second.end(), [](const Package &a, const Package &b) {
            const int cmp = compare_versions(a.version, b.version);
            return cmp == 0 ? a.release < b.release : cmp < 0;
        });
    }
    std::map<std::string, Package> selected;
    std::set<std::string> visiting, visited;
    std::vector<Package> ordered;
    std::function<void(const std::string &, const std::string &)> visit =
        [&](const std::string &name, const std::string &requirement) {
            const Dependency requested = parse_dependency(requirement.empty() ? name : requirement);
            const std::string package_name = requested.name.empty() ? name : requested.name;
            if (visiting.count(package_name))
                throw std::runtime_error("dependency cycle involving " + package_name);
            if (visited.count(package_name)) {
                const auto chosen = selected.find(package_name);
                if (chosen != selected.end() && !satisfies(chosen->second, requested))
                    throw std::runtime_error("conflicting version requirements for " + package_name);
                if (chosen == selected.end() && is_installed(package_name)
                    && !satisfies(installed_package(package_name), requested))
                    throw std::runtime_error("conflicting version requirements for " + package_name);
                return;
            }
            if (is_installed(package_name) && !force_upgrade.count(package_name)) {
                const Package current = installed_package(package_name);
                if (satisfies(current, requested)) { visited.insert(package_name); return; }
            }
            const auto candidates = by_name.find(package_name);
            if (candidates == by_name.end())
                throw std::runtime_error("missing repository dependency: " + package_name);
            const Package *choice = nullptr;
            for (const auto &candidate : candidates->second)
                if (satisfies(candidate, requested)) choice = &candidate;
            if (!choice) throw std::runtime_error("unsatisfied version requirement: " + requirement);
            visiting.insert(package_name);
            for (const auto &dependency : choice->dependencies)
                visit(parse_dependency(dependency).name, dependency);
            visiting.erase(package_name);
            visited.insert(package_name);
            selected[package_name] = *choice;
            ordered.push_back(*choice);
        };
    for (const auto &request : requests) visit(request.first, request.second);
    Plan plan;
    plan.packages = std::move(ordered);
    for (const auto &package : plan.packages)
        if (is_installed(package.name)) plan.upgrades.insert(package.name);
    return plan;
}

bool is_config_path(const std::string &path) {
    return path == "etc" || path.rfind("etc/", 0) == 0;
}

bool path_matches(const fs::path &path, const ManifestEntry &entry) {
    if (entry.type == 'f')
        return fs::is_regular_file(path) && fs::file_size(path) == entry.size && sha256(path) == entry.hash;
    if (entry.type == 'l')
        return fs::is_symlink(path) && fs::read_symlink(path).string() == entry.target;
    return fs::is_directory(path);
}

void write_atomic(const fs::path &path, const std::string &content) {
    fs::create_directories(path.parent_path());
    const fs::path temporary = path.string() + ".tmp." + std::to_string(getpid());
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output) throw std::runtime_error("cannot write " + temporary.string());
        output << content;
        if (!output) throw std::runtime_error("write failed for " + temporary.string());
    }
    fs::rename(temporary, path);
}

void copy_staged(const fs::path &source, const fs::path &destination,
                 const ManifestEntry &entry) {
    fs::create_directories(destination.parent_path());
    if (entry.type == 'l') {
        fs::create_symlink(fs::read_symlink(source), destination);
        return;
    }
    fs::copy_file(source, destination, fs::copy_options::overwrite_existing);
    fs::permissions(destination, static_cast<fs::perms>(entry.mode), fs::perm_options::replace);
}

bool prompt_remove(const bool yes) { return prompt_yes(yes); }

void commit_install(Plan plan, const bool yes) {
    if (plan.packages.empty()) {
        std::cout << "Nothing to do.\n";
        return;
    }
    std::cout << "Transaction plan:\n";
    for (const auto &package : plan.packages) {
        const bool update = is_installed(package.name);
        std::cout << (update ? "  Upgrade: " : "  Install: ") << package.name << " "
                  << (update ? plan_version(installed_package(package.name)) + " -> " : "")
                  << plan_version(package) << "\n";
    }
    if (!prompt_yes(yes)) { std::cout << "Cancelled.\n"; return; }

    const int lock = acquire_lock();
    const fs::path transaction = g_transactions / std::to_string(getpid());
    if (fs::exists(transaction)) fs::remove_all(transaction);
    fs::create_directories(transaction);
    write_atomic(transaction / "plan.txt", "Step 3 package transaction\n");

    std::vector<StagedPackage> staged;
    for (const auto &package : plan.packages) {
        const fs::path archive = package_archive(package);
        if (!fs::is_regular_file(archive) || fs::file_size(archive) != package.archive_size)
            throw std::runtime_error(package.name + ": repository package archive missing or wrong size");
        staged.push_back(stage_package(package, archive, transaction));
    }

    const auto owners = file_owners();
    std::map<std::string, std::pair<std::string, ManifestEntry>> planned_paths;
    for (const auto &item : staged) {
        const auto old = is_installed(item.package.name)
            ? load_manifest(g_database / item.package.name / "manifest.txt")
            : std::vector<ManifestEntry>{};
        for (const auto &entry : item.manifest) {
            auto existing_plan = planned_paths.find(entry.path);
            if (existing_plan != planned_paths.end()) {
                const auto &previous = existing_plan->second.second;
                if (entry.type != 'd' || previous.type != 'd')
                    throw std::runtime_error("package file collision between " + existing_plan->second.first
                                             + " and " + item.package.name + ": " + entry.path);
            } else {
                planned_paths[entry.path] = {item.package.name, entry};
            }
            const auto found = owners.find(entry.path);
            if (found != owners.end()) {
                for (const auto &owner : found->second) {
                    if (owner.first != item.package.name && entry.type != 'd')
                        throw std::runtime_error("file collision: " + entry.path + " is owned by " + owner.first);
                }
            }
            const fs::path destination = target_path("/" + entry.path);
            if (fs::exists(destination) || fs::is_symlink(destination)) {
                const bool owned_by_package = std::any_of(old.begin(), old.end(), [&](const auto &old_entry) {
                    return old_entry.path == entry.path;
                });
                if (!owned_by_package && entry.type != 'd' && !path_matches(destination, entry))
                    throw std::runtime_error("refusing to overwrite unmanaged path: /" + entry.path);
            }
        }
    }

    std::vector<std::pair<fs::path, fs::path>> backups;
    std::vector<fs::path> created;
    std::vector<std::pair<fs::path, fs::path>> db_backups;
    try {
        for (auto &item : staged) {
            std::vector<ManifestEntry> installed_entries;
            std::vector<ManifestEntry> old;
            if (is_installed(item.package.name))
                old = load_manifest(g_database / item.package.name / "manifest.txt");

            for (const auto &package_entry : item.manifest) {
                ManifestEntry entry = package_entry;
                fs::path source = item.root / entry.path;
                fs::path destination = target_path("/" + entry.path);
                auto old_entry = std::find_if(old.begin(), old.end(), [&](const auto &candidate) {
                    return candidate.path == entry.path;
                });
                if (entry.type == 'f' && is_config_path(entry.path)
                    && old_entry != old.end() && fs::exists(destination)
                    && !path_matches(destination, *old_entry)) {
                    ManifestEntry preserved = *old_entry;
                    if (fs::is_regular_file(destination)) {
                        preserved.type = 'f';
                        preserved.size = fs::file_size(destination);
                        preserved.mode = static_cast<unsigned>(fs::status(destination).permissions()) & 07777;
                        preserved.hash = sha256(destination);
                    }
                    installed_entries.push_back(preserved);
                    ManifestEntry replacement = package_entry;
                    replacement.path += ".kumo-new";
                    source = item.root / preserved.path;
                    destination = target_path("/" + replacement.path);
                    installed_entries.push_back(replacement);
                    entry = replacement;
                } else {
                    installed_entries.push_back(entry);
                }
                if (entry.type == 'd') {
                    if (!fs::exists(destination)) {
                        fs::create_directories(destination);
                        created.push_back(destination);
                        fs::permissions(destination, static_cast<fs::perms>(entry.mode), fs::perm_options::replace);
                    }
                    continue;
                }
                if ((fs::exists(destination) || fs::is_symlink(destination))
                    && !path_matches(destination, entry)) {
                    const fs::path backup = transaction / "backup" / entry.path;
                    fs::create_directories(backup.parent_path());
                    if (fs::is_symlink(destination)) fs::create_symlink(fs::read_symlink(destination), backup);
                    else fs::copy_file(destination, backup);
                    backups.push_back({destination, backup});
                    fs::remove(destination);
                } else if (!fs::exists(destination) && !fs::is_symlink(destination)) {
                    created.push_back(destination);
                } else {
                    continue;
                }
                copy_staged(source, destination, entry);
            }

            std::set<std::string> new_paths;
            for (const auto &entry : installed_entries) new_paths.insert(entry.path);
            for (const auto &old_entry : old) {
                if (new_paths.count(old_entry.path) || is_config_path(old_entry.path)) continue;
                const fs::path path = target_path("/" + old_entry.path);
                if (fs::exists(path) || fs::is_symlink(path)) {
                    const fs::path backup = transaction / "backup" / old_entry.path;
                    fs::create_directories(backup.parent_path());
                    if (fs::is_symlink(path)) fs::create_symlink(fs::read_symlink(path), backup);
                    else if (fs::is_regular_file(path)) fs::copy_file(path, backup);
                    backups.push_back({path, backup});
                    fs::remove(path);
                }
            }

            const fs::path record = transaction / "records" / item.package.name;
            fs::create_directories(record);
            write_atomic(record / "metadata.toml", item.metadata);
            write_atomic(record / "manifest.txt", manifest_text(installed_entries));
        }
        for (const auto &item : staged) {
            fs::create_directories(g_database);
            const fs::path destination = g_database / item.package.name;
            if (fs::exists(destination)) {
                const fs::path backup = transaction / "db-backup" / item.package.name;
                fs::create_directories(backup.parent_path());
                fs::rename(destination, backup);
                db_backups.push_back({destination, backup});
            }
            fs::rename(transaction / "records" / item.package.name, destination);
        }
    } catch (...) {
        for (auto it = db_backups.rbegin(); it != db_backups.rend(); ++it) {
            if (fs::exists(it->first)) fs::remove_all(it->first);
            if (fs::exists(it->second)) fs::rename(it->second, it->first);
        }
        for (auto it = backups.rbegin(); it != backups.rend(); ++it) {
            if (fs::exists(it->first) || fs::is_symlink(it->first)) fs::remove(it->first);
            fs::create_directories(it->first.parent_path());
            if (fs::is_symlink(it->second)) fs::create_symlink(fs::read_symlink(it->second), it->first);
            else if (fs::exists(it->second)) fs::copy_file(it->second, it->first);
        }
        for (auto it = created.rbegin(); it != created.rend(); ++it) {
            if (fs::exists(*it) || fs::is_symlink(*it)) fs::remove(*it);
        }
        close(lock);
        fs::remove_all(transaction);
        throw;
    }
    close(lock);
    fs::remove_all(transaction);
    std::cout << "Transaction completed.\n";
}

void remove_package(const std::string &name, const bool yes) {
    if (!is_installed(name)) throw std::runtime_error("package is not installed: " + name);
    const Package target = installed_package(name);
    for (const auto &package : installed_packages()) {
        if (package.name == name) continue;
        for (const auto &requirement : package.dependencies) {
            if (parse_dependency(requirement).name == name)
                throw std::runtime_error("cannot remove " + name + ": " + package.name + " depends on it");
        }
    }
    std::cout << "Transaction plan:\n  Remove: " << name << " " << plan_version(target) << "\n";
    if (!prompt_remove(yes)) { std::cout << "Cancelled.\n"; return; }
    const int lock = acquire_lock();
    const auto owners = file_owners();
    const auto manifest = load_manifest(g_database / name / "manifest.txt");
    for (auto it = manifest.rbegin(); it != manifest.rend(); ++it) {
        const auto found = owners.find(it->path);
        if (found != owners.end() && found->second.size() > 1) continue;
        const fs::path path = target_path("/" + it->path);
        if (it->type == 'd') {
            std::error_code error;
            fs::remove(path, error);
            continue;
        }
        if (is_config_path(it->path) && (fs::exists(path) || fs::is_symlink(path))
            && !path_matches(path, *it)) {
            std::cout << "Preserving modified configuration: /" << it->path << "\n";
            continue;
        }
        std::error_code error;
        fs::remove(path, error);
        if (error) {
            close(lock);
            throw std::runtime_error("cannot remove /" + it->path + ": " + error.message());
        }
    }
    fs::remove_all(g_database / name);
    close(lock);
    std::cout << "Removed " << name << ".\n";
}

void command_repo_list() {
    for (const auto &repository : load_repositories()) {
        std::cout << repository.name << "\t"
                  << (repository.remote ? repository.url : repository.configured_path)
                  << "\t" << (repository.enabled ? "enabled" : "disabled")
                  << "\t" << (repository.remote ? "ed25519 " + repository.key_id : "local");
        if (repository.remote) {
            const std::uint64_t sequence = highest_trusted_sequence(repository);
            std::cout << "\tsequence=" << (sequence ? std::to_string(sequence) : "not-refreshed");
        }
        std::cout << "\n";
    }
}

std::string repository_config(const std::vector<Repository> &repositories) {
    std::string config = "architecture = \"x86_64\"\n\n";
    for (const auto &repository : repositories) {
        config += "[[repository]]\nname = " + toml_quote(repository.name) + "\n";
        if (repository.remote)
            config += "url = " + toml_quote(repository.url) + "\n";
        else
            config += "path = " + toml_quote(repository.configured_path) + "\n";
        if (repository.remote) {
            config += "trust = " + toml_quote(repository.trust) + "\n";
            config += "key_id = " + toml_quote(repository.key_id) + "\n";
            config += "channel = " + toml_quote(repository.channel) + "\n";
        } else {
            config += "trust = \"local\"\n";
        }
        config += std::string("enabled = ") + (repository.enabled ? "true\n\n" : "false\n\n");
    }
    return config;
}

void command_repo_add(const std::string &name, const std::string &location,
                      const std::string &key_id = {}) {
    if (!valid_repo_name(name))
        throw std::runtime_error("invalid repository name");
    Repository added;
    added.name = name;
    if (location.rfind("https://", 0) == 0) {
        added.remote = true;
        added.url = normalize_https_url(location);
        added.trust = "ed25519";
        added.key_id = key_id;
        if (!valid_key_id(added.key_id))
            throw std::runtime_error("HTTPS repository requires an authorized sha256:<key fingerprint>");
        if (!fs::is_regular_file(trusted_key_path(added.key_id)))
            throw std::runtime_error("repository signing key is not installed: " + added.key_id);
    } else {
        if (!key_id.empty()) throw std::runtime_error("a key ID is only valid for an HTTPS repository");
        const fs::path absolute(location);
        if (!absolute.is_absolute()) throw std::runtime_error("repository path must be absolute");
        added.configured_path = absolute.string();
        added.path = target_path(absolute);
        if (!fs::is_regular_file(added.path / "index.toml"))
            throw std::runtime_error("repository index is missing: " + added.path.string());
    }
    auto repositories = load_repositories();
    if (std::any_of(repositories.begin(), repositories.end(), [&](const auto &item) { return item.name == name; }))
        throw std::runtime_error("repository already exists: " + name);
    repositories.push_back(std::move(added));
    write_atomic(g_config, repository_config(repositories));
    std::cout << "Added repository " << name << ".\n";
}

void command_repo_remove(const std::string &name) {
    auto repositories = load_repositories();
    const auto old_size = repositories.size();
    repositories.erase(std::remove_if(repositories.begin(), repositories.end(),
        [&](const auto &repository) { return repository.name == name; }), repositories.end());
    if (repositories.size() == old_size) throw std::runtime_error("repository not found: " + name);
    write_atomic(g_config, repository_config(repositories));
    std::cout << "Removed repository " << name << ".\n";
}

void command_repo_refresh() {
    std::size_t count = 0;
    for (const auto &repository : load_repositories()) {
        if (!repository.enabled) continue;
        if (repository.remote) {
            count += refresh_remote_repository(repository);
            continue;
        }
        for (const auto &package : parse_repo_index(
                 read_text(repository.path / "index.toml"), repository)) {
            const fs::path archive = package.repo_path / package.filename;
            if (!fs::is_regular_file(archive) || fs::file_size(archive) != package.archive_size
                || sha256(archive) != package.archive_hash)
                throw std::runtime_error("repository archive failed validation: " + package.filename);
            ++count;
        }
    }
    std::cout << "Refreshed " << count << " package records.\n";
}

void command_list() {
    for (const auto &package : installed_packages())
        std::cout << package.name << "\t" << plan_version(package) << "\t"
                  << package.architecture << "\n";
}

Package find_package(const std::string &name) {
    if (is_installed(name)) return installed_package(name);
    const auto available = load_repo_packages();
    const Package *best = nullptr;
    for (const auto &package : available) {
        if (package.name != name) continue;
        if (!best || compare_versions(package.version, best->version) > 0
            || (package.version == best->version && package.release > best->release))
            best = &package;
    }
    if (!best) throw std::runtime_error("package not found: " + name);
    return *best;
}

void command_info(const std::string &name) {
    const Package package = find_package(name);
    std::cout << package.name << " " << plan_version(package) << " (" << package.architecture << ")\n"
              << package.description << "\n";
    std::cout << "Runtime dependencies:";
    for (const auto &dependency : package.dependencies) std::cout << " " << dependency;
    std::cout << "\n";
}

void command_files(const std::string &name) {
    const fs::path manifest = g_database / name / "manifest.txt";
    if (!fs::is_regular_file(manifest)) throw std::runtime_error("package is not installed: " + name);
    for (const auto &entry : load_manifest(manifest)) std::cout << "/" << entry.path << "\n";
}

void command_search(const std::string &query) {
    std::string needle = query;
    std::transform(needle.begin(), needle.end(), needle.begin(), [](unsigned char ch) { return std::tolower(ch); });
    std::vector<Package> packages = load_repo_packages();
    std::sort(packages.begin(), packages.end(), [](const auto &a, const auto &b) {
        if (a.name != b.name) return a.name < b.name;
        const int cmp = compare_versions(a.version, b.version);
        return cmp == 0 ? a.release > b.release : cmp > 0;
    });
    std::set<std::string> printed;
    for (const auto &package : packages) {
        std::string haystack = package.name + " " + package.description;
        std::transform(haystack.begin(), haystack.end(), haystack.begin(),
                       [](unsigned char ch) { return std::tolower(ch); });
        if (haystack.find(needle) != std::string::npos && printed.insert(package.name).second)
            std::cout << package.name << "\t" << plan_version(package) << "\t" << package.description << "\n";
    }
}

void command_owns(const std::string &path) {
    fs::path absolute(path);
    if (!absolute.is_absolute()) throw std::runtime_error("kpm owns expects an absolute path");
    std::string relative = absolute.lexically_normal().relative_path().generic_string();
    const auto owners = file_owners();
    const auto found = owners.find(relative);
    if (found == owners.end()) throw std::runtime_error("no package owns " + path);
    std::set<std::string> names;
    for (const auto &owner : found->second) names.insert(owner.first);
    for (const auto &name : names) std::cout << name << "\n";
}

void command_verify(const std::string &name) {
    const fs::path manifest_path = g_database / name / "manifest.txt";
    if (!fs::is_regular_file(manifest_path)) throw std::runtime_error("package is not installed: " + name);
    bool okay = true;
    const auto owners = file_owners();
    for (const auto &entry : load_manifest(manifest_path)) {
        const fs::path path = target_path("/" + entry.path);
        if (!fs::exists(path) && !fs::is_symlink(path)) {
            std::cout << "missing: /" << entry.path << "\n";
            okay = false;
            continue;
        }
        if (!path_matches(path, entry)) {
            std::cout << "modified: /" << entry.path << "\n";
            okay = false;
        }
        const auto found = owners.find(entry.path);
        if (found != owners.end() && entry.type != 'd' && found->second.size() > 1) {
            std::cout << "ownership conflict: /" << entry.path << "\n";
            okay = false;
        }
    }
    if (okay) std::cout << "OK\n";
    else throw std::runtime_error("verification failed for " + name);
}

void usage() {
    std::cout << "kpm " << kVersion << " - Kumo Package Manager\n"
              << "Usage: kpm [--version] list|info|files|search|repo|install|remove|upgrade|verify|owns ...\n";
}

bool remove_yes(std::vector<std::string> &args) {
    auto it = std::find(args.begin(), args.end(), "--yes");
    if (it == args.end()) return false;
    args.erase(it);
    return true;
}

int main_impl(int argc, char **argv) {
    initialize_paths();
    std::vector<std::string> args(argv + 1, argv + argc);
    if (args.empty() || args[0] == "--help" || args[0] == "-h") { usage(); return 0; }
    if (args[0] == "--version" || args[0] == "-V") {
        std::cout << "kpm " << kVersion << " (kpkg format " << kFormatVersion << ")\n";
        return 0;
    }
    const bool yes = remove_yes(args);
    const std::string command = args[0];
    if (command == "list" && args.size() == 1) { command_list(); return 0; }
    if (command == "info" && args.size() == 2) { command_info(args[1]); return 0; }
    if (command == "files" && args.size() == 2) { command_files(args[1]); return 0; }
    if (command == "search" && args.size() == 2) { command_search(args[1]); return 0; }
    if (command == "owns" && args.size() == 2) { command_owns(args[1]); return 0; }
    if (command == "verify" && args.size() == 2) { command_verify(args[1]); return 0; }
    if (command == "repo" && args.size() >= 2) {
        if (args[1] == "list" && args.size() == 2) command_repo_list();
        else if (args[1] == "add" && (args.size() == 4 || args.size() == 5))
            command_repo_add(args[2], args[3], args.size() == 5 ? args[4] : "");
        else if (args[1] == "remove" && args.size() == 3) command_repo_remove(args[2]);
        else if (args[1] == "refresh" && args.size() == 2) command_repo_refresh();
        else throw std::runtime_error("usage: kpm repo list|add <name> <path>|add <name> <https-url> <key-id>|remove <name>|refresh");
        return 0;
    }
    if (command == "install" && args.size() == 2) {
        commit_install(resolve_plan({{args[1], args[1]}}, {}), yes);
        return 0;
    }
    if (command == "remove" && args.size() == 2) {
        remove_package(args[1], yes);
        return 0;
    }
    if (command == "upgrade" && args.size() == 2 && args[1] == "--all") {
        const auto latest = latest_packages();
        std::vector<std::pair<std::string, std::string>> requests;
        std::set<std::string> force;
        for (const auto &installed : installed_packages()) {
            const auto found = latest.find(installed.name);
            if (found != latest.end() && (compare_versions(found->second.version, installed.version) > 0
                || (found->second.version == installed.version && found->second.release > installed.release))) {
                requests.push_back({installed.name, installed.name});
                force.insert(installed.name);
            }
        }
        commit_install(resolve_plan(requests, force), yes);
        return 0;
    }
    if (command == "upgrade" && args.size() == 2) {
        const std::string name = args[1];
        if (!is_installed(name)) throw std::runtime_error("package is not installed: " + name);
        const Package current = installed_package(name);
        const auto available = latest_packages();
        const auto found = available.find(name);
        if (found == available.end()) throw std::runtime_error("package not found: " + name);
        const Package latest = found->second;
        if (compare_versions(latest.version, current.version) < 0
            || (latest.version == current.version && latest.release <= current.release)) {
            std::cout << name << " is already up to date.\n";
            return 0;
        }
        commit_install(resolve_plan({{name, name}}, {name}), yes);
        return 0;
    }
    usage();
    throw std::runtime_error("invalid command arguments");
}

} // namespace

int main(int argc, char **argv) {
    try {
        return main_impl(argc, argv);
    } catch (const std::exception &error) {
        std::cerr << "kpm: error: " << error.what() << "\n";
        return 1;
    }
}
