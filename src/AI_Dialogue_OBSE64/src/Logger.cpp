#include "Logger.h"

#include <chrono>
#include <fstream>
#include <iomanip>
#include <sstream>

std::filesystem::path Logger::logFile_;
std::mutex Logger::mutex_;
bool Logger::initialized_ = false;

bool Logger::Initialize(const std::filesystem::path& logFile) {
    std::lock_guard<std::mutex> lock(mutex_);

    logFile_ = logFile.empty()
        ? std::filesystem::current_path() / "AI_Dialogue.log"
        : logFile;

    std::error_code error;
    if (logFile_.has_parent_path()) {
        std::filesystem::create_directories(logFile_.parent_path(), error);
    }

    std::ofstream stream(logFile_, std::ios::app);
    initialized_ = stream.good();
    return initialized_;
}

void Logger::Shutdown() {
    std::lock_guard<std::mutex> lock(mutex_);
    initialized_ = false;
    logFile_.clear();
}

void Logger::Info(const std::string& message) {
    Write("INFO", message);
}

void Logger::Error(const std::string& message) {
    Write("ERROR", message);
}

void Logger::Write(const char* level, const std::string& message) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!initialized_) {
        return;
    }

    const auto now = std::chrono::system_clock::now();
    const std::time_t nowTime = std::chrono::system_clock::to_time_t(now);

    std::tm localTime{};
#ifdef _WIN32
    localtime_s(&localTime, &nowTime);
#else
    localtime_r(&nowTime, &localTime);
#endif

    std::ofstream stream(logFile_, std::ios::app);
    if (!stream) {
        return;
    }

    stream << '[' << std::put_time(&localTime, "%Y-%m-%d %H:%M:%S") << "] "
           << '[' << level << "] " << message << '\n';
}
