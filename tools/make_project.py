"""Writes FindersKeepers.xcodeproj. The app folder is a 'synchronized' group,
so every file under FindersKeepers/ is part of the app automatically."""
import pathlib

ID = {k: f"F1ND000000000000000000{i:02X}" for i, k in enumerate([
    "project", "mainGroup", "productsGroup", "appRef", "syncGroup", "target",
    "sources", "frameworks", "resources", "projConfigs", "projDebug", "projRelease",
    "tgtConfigs", "tgtDebug", "tgtRelease"], start=1)}

PHOTOS = "Finders Keepers reads your screenshots on this iPhone so you can sort them and clear them out. Nothing is uploaded."

def settings(d, indent="\t\t\t\t"):
    out = []
    for k in sorted(d):
        v = d[k]
        if isinstance(v, list):
            out.append(f"{indent}{k} = (\n" + "".join(f'{indent}\t"{x}",\n' for x in v) + f"{indent});")
        else:
            out.append(f'{indent}{k} = "{v}";')
    return "\n".join(out)

COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO", "ENABLE_STRICT_OBJC_MSGSEND": "YES", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_NO_COMMON_BLOCKS": "YES", "IPHONEOS_DEPLOYMENT_TARGET": "26.0", "SDKROOT": "iphoneos",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES", "MTL_FAST_MATH": "YES",
}
PROJ_DEBUG = dict(COMMON, DEBUG_INFORMATION_FORMAT="dwarf", ENABLE_TESTABILITY="YES", GCC_OPTIMIZATION_LEVEL="0",
                  ONLY_ACTIVE_ARCH="YES", SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG $(inherited)",
                  SWIFT_OPTIMIZATION_LEVEL="-Onone", GCC_PREPROCESSOR_DEFINITIONS=["DEBUG=1", "$(inherited)"])
PROJ_RELEASE = dict(COMMON, DEBUG_INFORMATION_FORMAT="dwarf-with-dsym", ENABLE_NS_ASSERTIONS="NO",
                    SWIFT_COMPILATION_MODE="wholemodule", VALIDATE_PRODUCT="YES")
TARGET = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "DEVELOPMENT_TEAM": "",
    "ENABLE_PREVIEWS": "YES", "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "Finders Keepers",
    "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO",
    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.productivity",
    "INFOPLIST_KEY_NSPhotoLibraryUsageDescription": PHOTOS,
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "MARKETING_VERSION": "1.0", "PRODUCT_BUNDLE_IDENTIFIER": "com.kendo316.finderskeepers",
    "PRODUCT_NAME": "$(TARGET_NAME)", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    "SUPPORTS_MACCATALYST": "NO", "SWIFT_EMIT_LOC_STRINGS": "YES", "SWIFT_VERSION": "5.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "TARGETED_DEVICE_FAMILY": "1",
}

def config(key, name, d):
    return f"""\t\t{ID[key]} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{settings(d)}
\t\t\t}};
\t\t\tname = {name};
\t\t}};
"""

def config_list(key, a, b):
    return f"""\t\t{ID[key]} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ID[a]} /* Debug */,
\t\t\t\t{ID[b]} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""

def phase(key, isa):
    return f"""\t\t{ID[key]} = {{
\t\t\tisa = {isa};
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""

pbx = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 77;
\tobjects = {{
\t\t{ID['appRef']} /* FindersKeepers.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FindersKeepers.app; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{ID['syncGroup']} /* FindersKeepers */ = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = FindersKeepers;
\t\t\tsourceTree = "<group>";
\t\t}};
{phase('frameworks', 'PBXFrameworksBuildPhase')}\t\t{ID['mainGroup']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ID['syncGroup']} /* FindersKeepers */,
\t\t\t\t{ID['productsGroup']} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ID['productsGroup']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ID['appRef']} /* FindersKeepers.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ID['target']} /* FindersKeepers */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ID['tgtConfigs']};
\t\t\tbuildPhases = (
\t\t\t\t{ID['sources']} /* Sources */,
\t\t\t\t{ID['frameworks']} /* Frameworks */,
\t\t\t\t{ID['resources']} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{ID['syncGroup']} /* FindersKeepers */,
\t\t\t);
\t\t\tname = FindersKeepers;
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = FindersKeepers;
\t\t\tproductReference = {ID['appRef']} /* FindersKeepers.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
\t\t{ID['project']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 2600;
\t\t\t\tLastUpgradeCheck = 2600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{ID['target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {ID['projConfigs']};
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {ID['mainGroup']};
\t\t\tminimizedProjectReferenceProxies = 1;
\t\t\tpreferredProjectObjectVersion = 77;
\t\t\tproductRefGroup = {ID['productsGroup']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{ID['target']} /* FindersKeepers */,
\t\t\t);
\t\t}};
{phase('resources', 'PBXResourcesBuildPhase')}{phase('sources', 'PBXSourcesBuildPhase')}{config('projDebug', 'Debug', PROJ_DEBUG)}{config('projRelease', 'Release', PROJ_RELEASE)}{config('tgtDebug', 'Debug', TARGET)}{config('tgtRelease', 'Release', TARGET)}{config_list('projConfigs', 'projDebug', 'projRelease')}{config_list('tgtConfigs', 'tgtDebug', 'tgtRelease')}\t}};
\trootObject = {ID['project']} /* Project object */;
}}
"""

scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{ID['target']}" BuildableName = "FindersKeepers.app" BlueprintName = "FindersKeepers" ReferencedContainer = "container:FindersKeepers.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{ID['target']}" BuildableName = "FindersKeepers.app" BlueprintName = "FindersKeepers" ReferencedContainer = "container:FindersKeepers.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{ID['target']}" BuildableName = "FindersKeepers.app" BlueprintName = "FindersKeepers" ReferencedContainer = "container:FindersKeepers.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
root = pathlib.Path(__file__).resolve().parent.parent
(root / "FindersKeepers.xcodeproj/project.pbxproj").write_text(pbx)
(root / "FindersKeepers.xcodeproj/xcshareddata/xcschemes/FindersKeepers.xcscheme").write_text(scheme)
print("project written")
