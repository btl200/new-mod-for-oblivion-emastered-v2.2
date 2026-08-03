#include "ConversationController.h"

#include "Logger.h"

bool ConversationController::Initialize(const std::filesystem::path& bridgePath) {
    if (!scanner_.Initialize()) {
        Logger::Error("NPC scanner failed to initialize.");
        return false;
    }

    if (!conversation_.Initialize()) {
        Logger::Error("Conversation manager failed to initialize.");
        return false;
    }

    if (!bridge_.Initialize(bridgePath)) {
        Logger::Error("Bridge client failed to initialize.");
        return false;
    }

    Logger::Info("Conversation controller initialized.");
    return true;
}

void ConversationController::Shutdown() {
    bridge_.Shutdown();
    conversation_.Shutdown();
    scanner_.Shutdown();

    Logger::Info("Conversation controller shut down.");
}

bool ConversationController::BeginForActor(void* actor) {
    const NPCContext npc = scanner_.ScanActor(actor);

    if (!conversation_.StartConversation(npc)) {
        Logger::Error("Could not start conversation session.");
        return false;
    }

    Logger::Info("Conversation session started for NPC: " + npc.name);
    return true;
}

AIResponse ConversationController::SendPlayerText(const std::string& text) {
    conversation_.AddPlayerMessage(text);
    return bridge_.SendConversation(conversation_.CurrentSession());
}

void ConversationController::End() {
    conversation_.EndConversation();
    Logger::Info("Conversation session ended.");
}
