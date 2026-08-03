#pragma once

#include <atomic>
#include <filesystem>
#include <thread>

class InteractionManager final {
public:
    InteractionManager() = default;
    ~InteractionManager();

    InteractionManager(const InteractionManager&) = delete;
    InteractionManager& operator=(const InteractionManager&) = delete;

    bool Start(const std::filesystem::path& modDirectory);
    void Stop();
    bool LaunchInteraction();

private:
    void HotkeyThreadMain();

    std::filesystem::path modDirectory_;
    std::filesystem::path interactionScript_;
    std::thread hotkeyThread_;
    std::atomic<unsigned long> threadId_{0};
    std::atomic<bool> running_{false};
    std::atomic<bool> interactionOpen_{false};
};
