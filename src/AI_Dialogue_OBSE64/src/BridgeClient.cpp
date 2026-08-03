#include "BridgeClient.h"

#include "Logger.h"

#include <fstream>
#include <sstream>

namespace {
std::string EscapeText(const std::string& value) {
    std::string result;
    result.reserve(value.size());

    for (char character : value) {
        switch (character) {
        case '\\': result += "\\\\"; break;
        case '"': result += "\\\""; break;
        case '\n': result += "\\n"; break;
        case '\r': result += "\\r"; break;
        default: result += character; break;
        }
    }

    return result;
}

std::string BuildPayload(const ConversationSession& session) {
    std::ostringstream json;

    json << "{\n";
    json << "  \"npc\": {\n";
    json << "    \"name\": \"" << EscapeText(session.npc.name) << "\",\n";
    json << "    \"editorId\": \"" << EscapeText(session.npc.editorId) << "\",\n";
    json << "    \"location\": \"" << EscapeText(session.npc.location) << "\"\n";
    json << "  },\n";
    json << "  \"messages\": [\n";

    for (size_t index = 0; index < session.history.size(); ++index) {
        const auto& message = session.history[index];
        json << "    {\"speaker\": \"" << EscapeText(message.speaker)
             << "\", \"text\": \"" << EscapeText(message.text) << "\"}";

        if (index + 1 < session.history.size()) {
            json << ',';
        }
        json << '\n';
    }

    json << "  ]\n";
    json << "}\n";

    return json.str();
}
}

bool BridgeClient::Initialize(const std::filesystem::path& bridgePath) {
    bridgePath_ = bridgePath;

    if (!std::filesystem::is_regular_file(bridgePath_)) {
        Logger::Error("AI bridge executable was not found.");
        return false;
    }

    Logger::Info("Bridge client initialized.");
    return true;
}

void BridgeClient::Shutdown() {
    bridgePath_.clear();
}

AIResponse BridgeClient::SendConversation(const ConversationSession& session) const {
    AIResponse response;

    if (bridgePath_.empty()) {
        response.error = "Bridge client is not initialized.";
        return response;
    }

    // Placeholder implementation: the existing prototype uses the external
    // bridge process. This class owns the transition point so the transport
    // can later move to named pipes without changing gameplay systems.
    const std::string payload = BuildPayload(session);

    Logger::Info("Prepared AI conversation payload.");
    Logger::Info(payload);

    response.success = false;
    response.error = "Bridge process transport is pending integration.";
    return response;
}
