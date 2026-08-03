#include "InteractionManager.h"

#include "Logger.h"

#include <shellapi.h>
#include <string>
#include <windows.h>

namespace {
constexpr int kInteractionHotkeyId = 0xA1D1;
constexpr UINT kInteractionVirtualKey = VK_F8;

std::wstring Quote(const std::filesystem::path& value) {
    std::wstring result = L"\"";
    result += value.wstring();
    result += L"\"";
    return result;
}
}

InteractionManager::~InteractionManager() {
    Stop();
}

bool InteractionManager::Start(const std::filesystem::path& modDirectory) {
    if (running_.exchange(true)) {
        Logger::Info("Interaction manager was already running.");
        return true;
    }

    modDirectory_ = modDirectory;
    interactionScript_ = modDirectory_ / "Interaction" / "AI_Dialogue_Interaction.ps1";

    if (!std::filesystem::is_regular_file(interactionScript_)) {
        running_ = false;
        Logger::Error("Interaction script was not found. Native trigger was not started.");
        return false;
    }

    try {
        hotkeyThread_ = std::thread(&InteractionManager::HotkeyThreadMain, this);
    } catch (...) {
        running_ = false;
        Logger::Error("Could not create the native interaction hotkey thread.");
        return false;
    }

    Logger::Info("Native interaction manager started; F8 trigger requested.");
    return true;
}

void InteractionManager::Stop() {
    if (!running_.exchange(false)) {
        return;
    }

    const DWORD threadId = static_cast<DWORD>(threadId_.load());
    if (threadId != 0) {
        PostThreadMessageW(threadId, WM_QUIT, 0, 0);
    }

    if (hotkeyThread_.joinable()) {
        hotkeyThread_.join();
    }

    threadId_ = 0;
    Logger::Info("Native interaction manager stopped.");
}

bool InteractionManager::LaunchInteraction() {
    if (interactionOpen_.exchange(true)) {
        Logger::Info("Ignored interaction request because a window is already open.");
        return false;
    }

    const std::wstring parameters =
        L"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " + Quote(interactionScript_);

    SHELLEXECUTEINFOW executeInfo{};
    executeInfo.cbSize = sizeof(executeInfo);
    executeInfo.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_NOASYNC;
    executeInfo.lpVerb = L"open";
    executeInfo.lpFile = L"powershell.exe";
    executeInfo.lpParameters = parameters.c_str();
    executeInfo.lpDirectory = modDirectory_.c_str();
    executeInfo.nShow = SW_HIDE;

    if (!ShellExecuteExW(&executeInfo)) {
        interactionOpen_ = false;
        Logger::Error("Failed to start the native interaction host.");
        return false;
    }

    Logger::Info("Native interaction host launched.");

    const HANDLE processHandle = executeInfo.hProcess;
    std::thread([this, processHandle]() {
        if (processHandle != nullptr) {
            WaitForSingleObject(processHandle, INFINITE);
            CloseHandle(processHandle);
        }
        interactionOpen_ = false;
        Logger::Info("Native interaction host closed.");
    }).detach();

    return true;
}

void InteractionManager::HotkeyThreadMain() {
    threadId_ = GetCurrentThreadId();

    MSG message{};
    PeekMessageW(&message, nullptr, WM_USER, WM_USER, PM_NOREMOVE);

    if (!RegisterHotKey(nullptr, kInteractionHotkeyId, MOD_NOREPEAT, kInteractionVirtualKey)) {
        Logger::Error("Could not register F8. Another application or mod may already own that hotkey.");
        running_ = false;
        threadId_ = 0;
        return;
    }

    Logger::Info("Native F8 hotkey registered successfully.");

    while (running_) {
        const BOOL result = GetMessageW(&message, nullptr, 0, 0);
        if (result <= 0) {
            break;
        }

        if (message.message == WM_HOTKEY && message.wParam == kInteractionHotkeyId) {
            LaunchInteraction();
        }
    }

    UnregisterHotKey(nullptr, kInteractionHotkeyId);
    threadId_ = 0;
}
