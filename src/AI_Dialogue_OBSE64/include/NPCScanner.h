#pragma once

#include <string>

struct NPCContext {
    std::string name;
    std::string editorId;
    std::string formId;
    std::string race;
    std::string faction;
    std::string location;
    int disposition = 0;
};

class NPCScanner final {
public:
    bool Initialize();
    void Shutdown();

    // The actor pointer will be replaced with the final OBSE actor type once
    // the runtime bindings are wired in.
    NPCContext ScanActor(void* actor) const;
};
