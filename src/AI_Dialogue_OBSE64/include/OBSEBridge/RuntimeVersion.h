#pragma once

namespace OBSEBridge {

struct RuntimeVersion final {
    int major = 0;
    int minor = 0;
    int patch = 0;
};

// Runtime-specific address bindings will live behind this layer.
class RuntimeVersionService final {
public:
    static RuntimeVersion Detect();
};

}
