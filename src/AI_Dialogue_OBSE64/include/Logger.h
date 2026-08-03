#pragma once

#include <filesystem>
#include <mutex>
#include <string>

class Logger final {
public:
    static bool Initialize(const std::filesystem::path& logFile = {});
    static void Shutdown();

    static void Info(const std::string& message);
    static void Error(const std::string& message);

private:
    static void Write(const char* level, const std::string& message);

    static std::filesystem::path logFile_;
    static std::mutex mutex_;
    static bool initialized_;
};
