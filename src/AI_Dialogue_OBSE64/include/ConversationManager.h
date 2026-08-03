#pragma once

#include <string>
#include <vector>

#include "NPCScanner.h"

struct ConversationMessage {
    std::string speaker;
    std::string text;
};

struct ConversationSession {
    NPCContext npc;
    std::vector<ConversationMessage> history;
    bool active = false;
};

class ConversationManager final {
public:
    bool Initialize();
    void Shutdown();

    bool StartConversation(const NPCContext& npc);
    void EndConversation();

    void AddPlayerMessage(const std::string& message);
    const ConversationSession& CurrentSession() const { return session_; }

private:
    ConversationSession session_;
};
