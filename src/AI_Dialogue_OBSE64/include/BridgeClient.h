#pragma once

#include <filesystem>
#include <string>

#include "ConversationManager.h"

struct AIResponse {
    bool success = false;
    std::string text;
    std::string error;
};

class BridgeClient final {
public:
    bool Initialize(const std::filesystem::path& bridgePath);
    void Shutdown();

    AIResponse SendConversation(const ConversationSession& session) const;

private:
    std::filesystem::path bridgePath_;
};
