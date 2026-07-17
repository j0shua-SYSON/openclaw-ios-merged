#pragma once

#include <cstddef>
#include <string>
#include <string_view>
#include <vector>

namespace recovered {

struct RecoveredFunction {
    const char* module;
    const char* address;
    const char* symbol;
    const char* pseudocode;
    const char* source_file;
    std::size_t first_line;
    std::size_t last_line;
};

struct RecoveredChunk {
    const RecoveredFunction* functions;
    std::size_t count;
};

struct ModuleSummary {
    std::string module;
    std::size_t function_count;
};

struct CallResult {
    bool executed;
    std::string module;
    std::string address;
    std::string symbol;
    std::string explanation;
};

std::size_t function_count();
const RecoveredFunction& function_at(std::size_t index);
std::vector<ModuleSummary> module_summaries();
std::vector<const RecoveredFunction*> search(
    std::string_view query,
    std::size_t limit = 100
);
const RecoveredFunction* find(std::string_view module, std::string_view address);
CallResult invoke_adapter(const RecoveredFunction& function);

namespace generated {
const RecoveredChunk* chunks(std::size_t& count);
}

}  // namespace recovered
