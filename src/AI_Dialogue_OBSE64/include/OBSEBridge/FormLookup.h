#pragma once

#include "ActorHandle.h"

#include <string>

namespace OBSEBridge {

class FormLookup final {
public:
    static std::string GetName(const ActorHandle& actor);
    static FormIdentifier GetFormId(const ActorHandle& actor);
    static std::string GetEditorId(const ActorHandle& actor);
};

}
