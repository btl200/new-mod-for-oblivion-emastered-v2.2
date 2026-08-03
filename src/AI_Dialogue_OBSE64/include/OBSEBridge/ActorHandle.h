#pragma once

#include <cstdint>

namespace OBSEBridge {

// Opaque game actor reference. The concrete OBSE type is kept behind this
// boundary so runtime-version changes do not leak into gameplay systems.
class ActorHandle final {
public:
    ActorHandle() = default;
    explicit ActorHandle(void* reference) : reference_(reference) {}

    bool IsValid() const { return reference_ != nullptr; }
    void* Raw() const { return reference_; }

private:
    void* reference_ = nullptr;
};

struct FormIdentifier {
    std::uint32_t id = 0;

    bool IsValid() const { return id != 0; }
};

}
