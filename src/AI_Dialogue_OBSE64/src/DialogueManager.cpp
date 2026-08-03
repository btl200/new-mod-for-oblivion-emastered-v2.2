#include "DialogueManager.h"

#include "Logger.h"

bool DialogueManager::Initialize() {
    currentActor_ = nullptr;
    currentNpcName_.clear();
    Logger::Info("Dialogue manager initialized.");
    return true;
}

void DialogueManager::Shutdown() {
    currentActor_ = nullptr;
    currentNpcName_.clear();
    Logger::Info("Dialogue manager shut down.");
}

void DialogueManager::OnDialogueOpened(void* actor) {
    currentActor_ = actor;

    // Placeholder until the OBSE64 actor lookup layer is wired in.
    // Keeping this isolated means NPC extraction can change without touching
    // the interaction layer.
    currentNpcName_ = "Unknown NPC";

    Logger::Info("Dialogue opened.");
}

void DialogueManager::OnDialogueClosed() {
    currentActor_ = nullptr;
    currentNpcName_.clear();
    Logger::Info("Dialogue closed.");
}
