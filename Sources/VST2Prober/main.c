// Standalone helper, run as a subprocess (with an external timeout) by
// PluginManager, that loads a VST2 plugin's entry point far enough to read
// AEffect.flags (specifically effFlagsIsSynth) — the only place VST2 records
// instrument-vs-effect.
//
// This runs real vendor code (the plugin's VSTPluginMain and whatever it does
// before returning), which is exactly why it's an isolated subprocess with a
// caller-enforced timeout: some plugins crash here, some hang. Either way,
// only this helper is affected — the parent just sees a non-zero exit, a
// timeout kill, or no output, and treats the plugin as undetermined.
//
// Prints "instrument" or "effect" to stdout and exits 0 on success.

#include <stdio.h>
#include <stdint.h>
#include <dlfcn.h>

typedef struct AEffect AEffect;

typedef intptr_t (*audioMasterCallback)(AEffect *effect, int32_t opcode, int32_t index,
                                         intptr_t value, void *ptr, float opt);

// Layout from the VST 2.4 SDK's aeffect.h — only the fields up to and
// including `flags` are actually read, but the struct must match layout so
// the `flags` offset is correct.
struct AEffect {
    int32_t magic;
    intptr_t (*dispatcher)(AEffect *effect, int32_t opcode, int32_t index, intptr_t value, void *ptr, float opt);
    void (*process)(AEffect *effect, float **inputs, float **outputs, int32_t sampleFrames);
    void (*setParameter)(AEffect *effect, int32_t index, float parameter);
    float (*getParameter)(AEffect *effect, int32_t index);
    int32_t numPrograms;
    int32_t numParams;
    int32_t numInputs;
    int32_t numOutputs;
    int32_t flags;
    intptr_t resvd1;
    intptr_t resvd2;
    int32_t initialDelay;
    int32_t realQualities;
    int32_t offQualities;
    float ioRatio;
    void *object;
    void *user;
    int32_t uniqueID;
    int32_t version;
    void (*processReplacing)(AEffect *effect, float **inputs, float **outputs, int32_t sampleFrames);
    void (*processDoubleReplacing)(AEffect *effect, double **inputs, double **outputs, int32_t sampleFrames);
    char future[56];
};

typedef AEffect *(*VSTPluginMainFunc)(audioMasterCallback audioMaster);

#define effFlagsIsSynth (1 << 8)

// Minimal no-op host callback. Some plugins query audioMasterVersion (opcode 1)
// during construction and behave more conservatively if it looks like an old
// host; report a modern version. Everything else: just say "unsupported" (0).
static intptr_t hostCallback(AEffect *effect, int32_t opcode, int32_t index,
                              intptr_t value, void *ptr, float opt) {
    if (opcode == 1) return 2400; // audioMasterVersion -> VST 2.4
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: VST2Prober <path-to-plugin-executable>\n");
        return 2;
    }

    void *handle = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
    if (!handle) {
        fprintf(stderr, "dlopen failed: %s\n", dlerror());
        return 3;
    }

    VSTPluginMainFunc entry = (VSTPluginMainFunc)dlsym(handle, "VSTPluginMain");
    if (!entry) {
        entry = (VSTPluginMainFunc)dlsym(handle, "main_macho");
    }
    if (!entry) {
        fprintf(stderr, "no VST2 entry point found\n");
        dlclose(handle);
        return 4;
    }

    AEffect *effect = entry(hostCallback);
    if (!effect) {
        fprintf(stderr, "entry point returned null\n");
        dlclose(handle);
        return 5;
    }

    int isSynth = (effect->flags & effFlagsIsSynth) != 0;
    printf("%s\n", isSynth ? "instrument" : "effect");
    return 0;
}
