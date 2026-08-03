#pragma once

#include "BridgeClient.h"
#include "ConversationManager.h"
#include "NPCScanner.h"

class ConversationController final {
public:
    bool Initialize(const std::filesystem::path& bridgePath);
    void Shutdown();

    bool BeginForActor(void* actor);
    AIResponse SendPlayerText(const std::string& text);
    void End();

private:
    NPCScanner scanner_;
    ConversationManager conversation_;
    BridgeClient bridge_;
};
