#!/usr/bin/env python3
"""Generate Umbra.xcodeproj/project.pbxproj for the Umbra app.

Hand-writing pbxproj UUIDs is error-prone, so this generator scans the source
tree and emits a valid Xcode 15 (objectVersion 56) project with an app target
and a unit-test target. Re-run after adding/removing source files:

    python3 scripts/generate_project.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_NAME = "Umbra"
TEST_NAME = "UmbraTests"
BUNDLE_ID = "com.localfirst.umbra"
DEPLOYMENT_TARGET = "17.0"

_counter = [0]
def uid():
    _counter[0] += 1
    return "SL00" + format(_counter[0], "020X")

def swift_files(rel_dir):
    out = []
    base = os.path.join(ROOT, rel_dir)
    for dirpath, _dirs, files in os.walk(base):
        for f in sorted(files):
            if f.endswith(".swift"):
                full = os.path.join(dirpath, f)
                out.append(os.path.relpath(full, ROOT))
    return sorted(out)

app_sources = swift_files(APP_NAME)
test_sources = swift_files(TEST_NAME)

# Assets + Info.plist + privacy manifest
assets_rel = os.path.join(APP_NAME, "Assets.xcassets")
info_rel = os.path.join(APP_NAME, "Resources", "Info.plist")
privacy_rel = os.path.join(APP_NAME, "PrivacyInfo.xcprivacy")

# --- Allocate IDs -----------------------------------------------------------
file_ref = {}       # rel path -> file reference id
build_file = {}     # (rel path, target) -> build file id

for p in app_sources + test_sources + [assets_rel, privacy_rel]:
    file_ref[p] = uid()

assets_build = uid()
privacy_build = uid()
for p in app_sources:
    build_file[(p, "app")] = uid()
build_file[(assets_rel, "app")] = assets_build
build_file[(privacy_rel, "app")] = privacy_build
for p in test_sources:
    build_file[(p, "test")] = uid()

# Product references
app_product = uid()
test_product = uid()

# Groups
grp_main = uid()
grp_app = uid()
grp_tests = uid()
grp_products = uid()
grp_frameworks = uid()

# Targets / phases / configs
app_target = uid()
test_target = uid()
project_obj = uid()
app_src_phase = uid()
app_res_phase = uid()
app_fw_phase = uid()
test_src_phase = uid()
test_fw_phase = uid()
proj_cfg_list = uid()
app_cfg_list = uid()
test_cfg_list = uid()
proj_debug = uid()
proj_release = uid()
app_debug = uid()
app_release = uid()
test_debug = uid()
test_release = uid()
dep_proxy = uid()
target_dep = uid()

# --- Build pbxproj text -----------------------------------------------------
L = []
def w(s=""):
    L.append(s)

w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {")
w("\t};")
w("\tobjectVersion = 56;")
w("\tobjects = {")

# PBXBuildFile
w("\n/* Begin PBXBuildFile section */")
for p in app_sources:
    bid = build_file[(p, "app")]
    w(f"\t\t{bid} /* {os.path.basename(p)} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref[p]} /* {os.path.basename(p)} */; }};")
w(f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ref[assets_rel]} /* Assets.xcassets */; }};")
w(f"\t\t{privacy_build} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ref[privacy_rel]} /* PrivacyInfo.xcprivacy */; }};")
for p in test_sources:
    bid = build_file[(p, "test")]
    w(f"\t\t{bid} /* {os.path.basename(p)} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref[p]} /* {os.path.basename(p)} */; }};")
w("/* End PBXBuildFile section */")

# PBXContainerItemProxy
w("\n/* Begin PBXContainerItemProxy section */")
w(f"\t\t{dep_proxy} /* PBXContainerItemProxy */ = {{")
w("\t\t\tisa = PBXContainerItemProxy;")
w(f"\t\t\tcontainerPortal = {project_obj} /* Project object */;")
w("\t\t\tproxyType = 1;")
w(f"\t\t\tremoteGlobalIDString = {app_target};")
w(f"\t\t\tremoteInfo = {APP_NAME};")
w("\t\t};")
w("/* End PBXContainerItemProxy section */")

# PBXFileReference
# Each Swift file's PBXFileReference lives under the app/test group whose
# `path` is the target name (Umbra / UmbraTests). To let Xcode resolve files
# that live in subdirectories on disk, the reference `path` must be relative to
# that group, i.e. the portion after "Umbra/" (e.g. "Views/RootView.swift").
def group_relative_path(p):
    # p is relative to ROOT, e.g. "Umbra/Views/RootView.swift".
    # Strip the leading target-name component so the path is relative to the
    # group (whose own `path` is the target name).
    parts = p.split(os.sep)
    return os.path.join(*parts[1:]) if len(parts) > 1 else p

w("\n/* Begin PBXFileReference section */")
for p in app_sources + test_sources:
    name = os.path.basename(p)
    rel = group_relative_path(p)
    w(f"\t\t{file_ref[p]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {rel}; sourceTree = \"<group>\"; }};")
w(f"\t\t{file_ref[assets_rel]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
w(f"\t\t{file_ref[privacy_rel]} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; }};")
w(f"\t\t{uid()} /* Info.plist placeholder */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
w(f"\t\t{app_product} /* {APP_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
w(f"\t\t{test_product} /* {TEST_NAME}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {TEST_NAME}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
w("/* End PBXFileReference section */")

# PBXFrameworksBuildPhase
w("\n/* Begin PBXFrameworksBuildPhase section */")
w(f"\t\t{app_fw_phase} /* Frameworks */ = {{")
w("\t\t\tisa = PBXFrameworksBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (\n\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w(f"\t\t{test_fw_phase} /* Frameworks */ = {{")
w("\t\t\tisa = PBXFrameworksBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (\n\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXFrameworksBuildPhase section */")

# PBXGroup
def group_children_app():
    ids = [file_ref[p] for p in app_sources]
    ids.append(file_ref[assets_rel])
    ids.append(file_ref[privacy_rel])
    return ids

w("\n/* Begin PBXGroup section */")
# main group
w(f"\t\t{grp_main} = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{grp_app} /* {APP_NAME} */,")
w(f"\t\t\t\t{grp_tests} /* {TEST_NAME} */,")
w(f"\t\t\t\t{grp_products} /* Products */,")
w(f"\t\t\t\t{grp_frameworks} /* Frameworks */,")
w("\t\t\t);")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
# app group
w(f"\t\t{grp_app} /* {APP_NAME} */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for cid in group_children_app():
    w(f"\t\t\t\t{cid},")
w("\t\t\t);")
w(f"\t\t\tpath = {APP_NAME};")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
# tests group
w(f"\t\t{grp_tests} /* {TEST_NAME} */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for p in test_sources:
    w(f"\t\t\t\t{file_ref[p]},")
w("\t\t\t);")
w(f"\t\t\tpath = {TEST_NAME};")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
# products group
w(f"\t\t{grp_products} /* Products */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{app_product} /* {APP_NAME}.app */,")
w(f"\t\t\t\t{test_product} /* {TEST_NAME}.xctest */,")
w("\t\t\t);")
w("\t\t\tname = Products;")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
# frameworks group
w(f"\t\t{grp_frameworks} /* Frameworks */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (\n\t\t\t);")
w("\t\t\tname = Frameworks;")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w("/* End PBXGroup section */")

# PBXNativeTarget
w("\n/* Begin PBXNativeTarget section */")
w(f"\t\t{app_target} /* {APP_NAME} */ = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {app_cfg_list} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */;")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{app_src_phase} /* Sources */,")
w(f"\t\t\t\t{app_fw_phase} /* Frameworks */,")
w(f"\t\t\t\t{app_res_phase} /* Resources */,")
w("\t\t\t);")
w("\t\t\tbuildRules = (\n\t\t\t);")
w("\t\t\tdependencies = (\n\t\t\t);")
w(f"\t\t\tname = {APP_NAME};")
w(f"\t\t\tproductName = {APP_NAME};")
w(f"\t\t\tproductReference = {app_product} /* {APP_NAME}.app */;")
w("\t\t\tproductType = \"com.apple.product-type.application\";")
w("\t\t};")
w(f"\t\t{test_target} /* {TEST_NAME} */ = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {test_cfg_list} /* Build configuration list for PBXNativeTarget \"{TEST_NAME}\" */;")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{test_src_phase} /* Sources */,")
w(f"\t\t\t\t{test_fw_phase} /* Frameworks */,")
w("\t\t\t);")
w("\t\t\tbuildRules = (\n\t\t\t);")
w("\t\t\tdependencies = (")
w(f"\t\t\t\t{target_dep} /* PBXTargetDependency */,")
w("\t\t\t);")
w(f"\t\t\tname = {TEST_NAME};")
w(f"\t\t\tproductName = {TEST_NAME};")
w(f"\t\t\tproductReference = {test_product} /* {TEST_NAME}.xctest */;")
w("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
w("\t\t};")
w("/* End PBXNativeTarget section */")

# PBXProject
w("\n/* Begin PBXProject section */")
w(f"\t\t{project_obj} /* Project object */ = {{")
w("\t\t\tisa = PBXProject;")
w("\t\t\tattributes = {")
w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
w("\t\t\t\tLastSwiftUpdateCheck = 1500;")
w("\t\t\t\tLastUpgradeCheck = 1500;")
w("\t\t\t\tTargetAttributes = {")
w(f"\t\t\t\t\t{app_target} = {{")
w("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
w("\t\t\t\t\t};")
w(f"\t\t\t\t\t{test_target} = {{")
w("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
w(f"\t\t\t\t\t\tTestTargetID = {app_target};")
w("\t\t\t\t\t};")
w("\t\t\t\t};")
w("\t\t\t};")
w(f"\t\t\tbuildConfigurationList = {proj_cfg_list} /* Build configuration list for PBXProject \"{APP_NAME}\" */;")
w("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
w("\t\t\tdevelopmentRegion = en;")
w("\t\t\thasScannedForEncodings = 0;")
w("\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);")
w(f"\t\t\tmainGroup = {grp_main};")
w(f"\t\t\tproductRefGroup = {grp_products} /* Products */;")
w("\t\t\tprojectDirPath = \"\";")
w("\t\t\tprojectRoot = \"\";")
w("\t\t\ttargets = (")
w(f"\t\t\t\t{app_target} /* {APP_NAME} */,")
w(f"\t\t\t\t{test_target} /* {TEST_NAME} */,")
w("\t\t\t);")
w("\t\t};")
w("/* End PBXProject section */")

# PBXResourcesBuildPhase
w("\n/* Begin PBXResourcesBuildPhase section */")
w(f"\t\t{app_res_phase} /* Resources */ = {{")
w("\t\t\tisa = PBXResourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
w(f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,")
w(f"\t\t\t\t{privacy_build} /* PrivacyInfo.xcprivacy in Resources */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXResourcesBuildPhase section */")

# PBXSourcesBuildPhase
w("\n/* Begin PBXSourcesBuildPhase section */")
w(f"\t\t{app_src_phase} /* Sources */ = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for p in app_sources:
    w(f"\t\t\t\t{build_file[(p, 'app')]} /* {os.path.basename(p)} in Sources */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w(f"\t\t{test_src_phase} /* Sources */ = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for p in test_sources:
    w(f"\t\t\t\t{build_file[(p, 'test')]} /* {os.path.basename(p)} in Sources */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXSourcesBuildPhase section */")

# PBXTargetDependency
w("\n/* Begin PBXTargetDependency section */")
w(f"\t\t{target_dep} /* PBXTargetDependency */ = {{")
w("\t\t\tisa = PBXTargetDependency;")
w(f"\t\t\ttarget = {app_target} /* {APP_NAME} */;")
w(f"\t\t\ttargetProxy = {dep_proxy} /* PBXContainerItemProxy */;")
w("\t\t};")
w("/* End PBXTargetDependency section */")

# XCBuildConfiguration
def common_build_settings():
    return [
        "ALWAYS_SEARCH_USER_PATHS = NO;",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;",
        "CLANG_ANALYZER_NONNULL = YES;",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;",
        "CLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";",
        "CLANG_ENABLE_MODULES = YES;",
        "CLANG_ENABLE_OBJC_ARC = YES;",
        "CLANG_ENABLE_OBJC_WEAK = YES;",
        "CLANG_WARN_BOOL_CONVERSION = YES;",
        "CLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
        "CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;",
        "COPY_PHASE_STRIP = NO;",
        "ENABLE_STRICT_OBJC_MSGSEND = YES;",
        "ENABLE_USER_SCRIPT_SANDBOXING = YES;",
        "GCC_C_LANGUAGE_STANDARD = gnu17;",
        "GCC_NO_COMMON_BLOCKS = YES;",
        "GCC_WARN_64_TO_32_BIT_CONVERSION = YES;",
        "GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;",
        "GCC_WARN_UNDECLARED_SELECTOR = YES;",
        "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
        "GCC_WARN_UNUSED_FUNCTION = YES;",
        "GCC_WARN_UNUSED_VARIABLE = YES;",
        f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};",
        "MTL_FAST_MATH = YES;",
        "SDKROOT = iphoneos;",
        "SWIFT_EMIT_LOC_STRINGS = YES;",
    ]

w("\n/* Begin XCBuildConfiguration section */")
# Project Debug
w(f"\t\t{proj_debug} /* Debug */ = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
for s in common_build_settings():
    w(f"\t\t\t\t{s}")
w("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
w("\t\t\t\tENABLE_TESTABILITY = YES;")
w("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
w("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
w("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (\n\t\t\t\t\t\"DEBUG=1\",\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t);")
w("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
w("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
w("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
w("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
w("\t\t\t};")
w("\t\t\tname = Debug;")
w("\t\t};")
# Project Release
w(f"\t\t{proj_release} /* Release */ = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
for s in common_build_settings():
    w(f"\t\t\t\t{s}")
w("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
w("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
w("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
w("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
w("\t\t\t\tVALIDATE_PRODUCT = YES;")
w("\t\t\t};")
w("\t\t\tname = Release;")
w("\t\t};")

def app_settings(debug):
    s = [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
        "CODE_SIGN_STYLE = Automatic;",
        "CURRENT_PROJECT_VERSION = 1;",
        "DEVELOPMENT_ASSET_PATHS = \"\";",
        "ENABLE_PREVIEWS = YES;",
        "GENERATE_INFOPLIST_FILE = NO;",
        f"INFOPLIST_FILE = {info_rel};",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;",
        "LD_RUNPATH_SEARCH_PATHS = (\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t\t\"@executable_path/Frameworks\",\n\t\t\t\t);",
        "MARKETING_VERSION = 1.0;",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
        "PRODUCT_NAME = \"$(TARGET_NAME)\";",
        "SWIFT_EMIT_LOC_STRINGS = YES;",
        "SWIFT_VERSION = 5.0;",
        "TARGETED_DEVICE_FAMILY = \"1,2\";",
    ]
    return s

w(f"\t\t{app_debug} /* Debug */ = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
for s in app_settings(True):
    w(f"\t\t\t\t{s}")
w("\t\t\t};")
w("\t\t\tname = Debug;")
w("\t\t};")
w(f"\t\t{app_release} /* Release */ = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
for s in app_settings(False):
    w(f"\t\t\t\t{s}")
w("\t\t\t};")
w("\t\t\tname = Release;")
w("\t\t};")

def test_settings():
    return [
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES;",
        "BUNDLE_LOADER = \"$(TEST_HOST)\";",
        "CODE_SIGN_STYLE = Automatic;",
        "CURRENT_PROJECT_VERSION = 1;",
        "GENERATE_INFOPLIST_FILE = YES;",
        f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};",
        "MARKETING_VERSION = 1.0;",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.tests;",
        "PRODUCT_NAME = \"$(TARGET_NAME)\";",
        "SWIFT_EMIT_LOC_STRINGS = NO;",
        "SWIFT_VERSION = 5.0;",
        "TARGETED_DEVICE_FAMILY = \"1,2\";",
        f"TEST_HOST = \"$(BUILT_PRODUCTS_DIR)/{APP_NAME}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{APP_NAME}\";",
    ]

w(f"\t\t{test_debug} /* Debug */ = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
for s in test_settings():
    w(f"\t\t\t\t{s}")
w("\t\t\t};")
w("\t\t\tname = Debug;")
w("\t\t};")
w(f"\t\t{test_release} /* Release */ = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
for s in test_settings():
    w(f"\t\t\t\t{s}")
w("\t\t\t};")
w("\t\t\tname = Release;")
w("\t\t};")
w("/* End XCBuildConfiguration section */")

# XCConfigurationList
w("\n/* Begin XCConfigurationList section */")
def cfg_list(cid, name, kind, debug_id, release_id):
    w(f"\t\t{cid} /* Build configuration list for {kind} \"{name}\" */ = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{debug_id} /* Debug */,")
    w(f"\t\t\t\t{release_id} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
cfg_list(proj_cfg_list, APP_NAME, "PBXProject", proj_debug, proj_release)
cfg_list(app_cfg_list, APP_NAME, "PBXNativeTarget", app_debug, app_release)
cfg_list(test_cfg_list, TEST_NAME, "PBXNativeTarget", test_debug, test_release)
w("/* End XCConfigurationList section */")

w("\t};")
w(f"\trootObject = {project_obj} /* Project object */;")
w("}")

proj_dir = os.path.join(ROOT, f"{APP_NAME}.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)
with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
    f.write("\n".join(L) + "\n")

print(f"Wrote {proj_dir}/project.pbxproj")
print(f"  app sources : {len(app_sources)}")
print(f"  test sources: {len(test_sources)}")

# --- Shared scheme ----------------------------------------------------------
scheme_dir = os.path.join(proj_dir, "xcshareddata", "xcschemes")
os.makedirs(scheme_dir, exist_ok=True)
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target}"
               BuildableName = "{APP_NAME}.app"
               BlueprintName = "{APP_NAME}"
               ReferencedContainer = "container:{APP_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target}"
               BuildableName = "{TEST_NAME}.xctest"
               BlueprintName = "{TEST_NAME}"
               ReferencedContainer = "container:{APP_NAME}.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "{APP_NAME}.app"
            BlueprintName = "{APP_NAME}"
            ReferencedContainer = "container:{APP_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "{APP_NAME}.app"
            BlueprintName = "{APP_NAME}"
            ReferencedContainer = "container:{APP_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
with open(os.path.join(scheme_dir, f"{APP_NAME}.xcscheme"), "w") as f:
    f.write(scheme)
print(f"Wrote shared scheme {APP_NAME}.xcscheme")
