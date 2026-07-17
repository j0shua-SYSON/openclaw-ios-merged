#include "recovered_catalog.hpp"

#include <algorithm>
#include <cctype>
#include <map>
#include <stdexcept>

namespace recovered {
namespace {

std::string lowercase(std::string_view value) {
    std::string result(value);
    std::transform(
        result.begin(),
        result.end(),
        result.begin(),
        [](unsigned char character) {
            return static_cast<char>(std::tolower(character));
        }
    );
    return result;
}

const std::vector<const RecoveredFunction*>& flattened_catalog() {
    static const std::vector<const RecoveredFunction*> catalog = [] {
        std::size_t chunk_count = 0;
        const RecoveredChunk* chunks = generated::chunks(chunk_count);
        std::vector<const RecoveredFunction*> result;
        for (std::size_t chunk_index = 0; chunk_index < chunk_count; ++chunk_index) {
            const RecoveredChunk& chunk = chunks[chunk_index];
            result.reserve(result.size() + chunk.count);
            for (std::size_t index = 0; index < chunk.count; ++index) {
                result.push_back(&chunk.functions[index]);
            }
        }
        return result;
    }();
    return catalog;
}

}  // namespace

std::size_t function_count() {
    return flattened_catalog().size();
}

const RecoveredFunction& function_at(std::size_t index) {
    const auto& catalog = flattened_catalog();
    if (index >= catalog.size()) {
        throw std::out_of_range("Recovered function index is out of range");
    }
    return *catalog[index];
}

std::vector<ModuleSummary> module_summaries() {
    std::map<std::string, std::size_t> counts;
    for (const RecoveredFunction* function : flattened_catalog()) {
        ++counts[function->module];
    }

    std::vector<ModuleSummary> summaries;
    summaries.reserve(counts.size());
    for (const auto& [module, count] : counts) {
        summaries.push_back({module, count});
    }
    return summaries;
}

std::vector<const RecoveredFunction*> search(
    std::string_view query,
    std::size_t limit
) {
    const std::string needle = lowercase(query);
    std::vector<const RecoveredFunction*> results;
    if (limit == 0) {
        return results;
    }

    for (const RecoveredFunction* function : flattened_catalog()) {
        const bool matches =
            needle.empty() ||
            lowercase(function->module).find(needle) != std::string::npos ||
            lowercase(function->address).find(needle) != std::string::npos ||
            lowercase(function->symbol).find(needle) != std::string::npos;
        if (matches) {
            results.push_back(function);
            if (results.size() == limit) {
                break;
            }
        }
    }
    return results;
}

const RecoveredFunction* find(
    std::string_view module,
    std::string_view address
) {
    for (const RecoveredFunction* function : flattened_catalog()) {
        if (function->module == module && function->address == address) {
            return function;
        }
    }
    return nullptr;
}

CallResult invoke_adapter(const RecoveredFunction& function) {
    return {
        false,
        function.module,
        function.address,
        function.symbol,
        "This adapter is buildable and callable, but semantic execution is "
        "disabled. The optimized binary does not preserve the Swift/Objective-C "
        "ABI types, runtime state, imports, or object layouts required to execute "
        "Ghidra C-like pseudocode safely."
    };
}

}  // namespace recovered
