#pragma once

#include <string>

class DialogueManager final {
public:
    bool Initialize();
    void Shutdown();

    // Future OBSE event hook entry points.
    void OnDialogueOpened(void* actor);
    void OnDialogueClosed();

    bool IsInDialogue() const { return currentActor_ != nullptr; }
    const std::string& CurrentNpcName() const { return currentNpcName_; }

private:
    void* currentActor_ = nullptr;
    std::string currentNpcName_;
};
