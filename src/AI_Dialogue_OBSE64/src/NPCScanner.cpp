#include "NPCScanner.h"

#include "Logger.h"

bool NPCScanner::Initialize() {
    Logger::Info("NPC scanner initialized.");
    return true;
}

void NPCScanner::Shutdown() {
    Logger::Info("NPC scanner shutdown.");
}

NPCContext NPCScanner::ScanActor(void* actor) const {
    NPCContext context;

    // Placeholder values until the OBSE64 runtime bindings are connected.
    // Keeping this as a separate layer allows actor lookup changes without
    // rewriting dialogue, relationship, or AI systems.
    if (actor == nullptr) {
        context.name = "No active NPC";
        return context;
    }

    context.name = "Unknown NPC";
    context.editorId = "Unknown";
    context.formId = "Unknown";
    context.location = "Unknown";

    return context;
}
