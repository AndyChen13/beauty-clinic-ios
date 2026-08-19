#!/usr/bin/env python3
import os, uuid

PROJECT_DIR = "/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic"
XCODEPROJ = os.path.join(PROJECT_DIR, "BeautyClinic.xcodeproj")
PBXPROJ = os.path.join(XCODEPROJ, "project.pbxproj")

def gid():
    return str(uuid.uuid4()).upper().replace("-", "")[:24]

# Collect source files
swift_files = []
for root, dirs, files in os.walk(PROJECT_DIR):
    dirs.sort()
    for f in sorted(files):
        if f.endswith(".swift"):
            full = os.path.join(root, f)
            rel = os.path.relpath(full, PROJECT_DIR)
            swift_files.append(rel.replace(os.sep, "/"))

print(f"Found {len(swift_files)} Swift files")

# UUIDs
uids = {k: gid() for k in [
    "project","mainGroup","productsGroup","targetGroup","target",
    "debug","release","projectCfgList","targetCfgList",
    "sourcesPhase","frameworksPhase","resourcesPhase",
    "productRef","supabasePkg","supabaseProduct","supabaseBuildFile"
]}

fileRefs = {f: gid() for f in swift_files}
buildFiles = {f: gid() for f in swift_files}

objects = []

# Build files
for f in swift_files:
    objects.append(f'{buildFiles[f]} /* {os.path.basename(f)} in Sources */ = {{isa = PBXBuildFile; fileRef = {fileRefs[f]} /* {os.path.basename(f)} */; }};')

# Supabase build file
objects.append(f'{uids["supabaseBuildFile"]} /* Supabase in Frameworks */ = {{isa = PBXBuildFile; productRef = {uids["supabaseProduct"]} /* Supabase */; }};')

# File references
for f in swift_files:
    objects.append(f'{fileRefs[f]} /* {os.path.basename(f)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {os.path.basename(f)}; sourceTree = "<group>"; }};')

# Product
objects.append(f'{uids["productRef"]} /* BeautyClinic.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = BeautyClinic.app; sourceTree = BUILT_PRODUCTS_DIR; }};')

# Frameworks build phase
objects.append(f'''{uids["frameworksPhase"]} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{uids["supabaseBuildFile"]} /* Supabase in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};''')

# Groups
child_refs = " ".join(f'{fileRefs[f]} /* {os.path.basename(f)} */,' for f in swift_files)
objects.append(f'''{uids["mainGroup"]} = {{
			isa = PBXGroup;
			children = (
				{uids["targetGroup"]} /* BeautyClinic */,
				{uids["productsGroup"]} /* Products */,
			);
			sourceTree = "<group>";
		}};''')

objects.append(f'''{uids["productsGroup"]} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{uids["productRef"]} /* BeautyClinic.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};''')

objects.append(f'''{uids["targetGroup"]} /* BeautyClinic */ = {{
			isa = PBXGroup;
			children = (
				{child_refs}
			);
			path = BeautyClinic;
			sourceTree = "<group>";
		}};''')

# Native target
src_files = " ".join(f'{buildFiles[f]} /* {os.path.basename(f)} in Sources */,' for f in swift_files)
objects.append(f'''{uids["target"]} /* BeautyClinic */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {uids["targetCfgList"]} /* Build configuration list for PBXNativeTarget "BeautyClinic" */;
			buildPhases = (
				{uids["sourcesPhase"]} /* Sources */,
				{uids["frameworksPhase"]} /* Frameworks */,
				{uids["resourcesPhase"]} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = BeautyClinic;
			packageProductDependencies = (
				{uids["supabaseProduct"]} /* Supabase */,
			);
			productName = BeautyClinic;
			productReference = {uids["productRef"]} /* BeautyClinic.app */;
			productType = "com.apple.product-type.application";
		}};''')

# Project
objects.append(f'''{uids["project"]} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastUpgradeCheck = 1540;
				ORGANIZATIONNAME = "Andy Chen";
				TargetAttributes = {{
					{uids["target"]} = {{
						CreatedOnToolsVersion = 15.4;
					}};
				}};
			}};
			buildConfigurationList = {uids["projectCfgList"]} /* Build configuration list for PBXProject "BeautyClinic" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {uids["mainGroup"]};
			packageReferences = (
				{uids["supabasePkg"]} /* XCRemoteSwiftPackageReference "supabase-swift" */,
			);
			productRefGroup = {uids["productsGroup"]} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{uids["target"]} /* BeautyClinic */,
			);
		}};''')

# Resources phase
objects.append(f'''{uids["resourcesPhase"]} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};''')

# Sources phase
objects.append(f'''{uids["sourcesPhase"]} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{src_files}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};''')

# Debug config
objects.append(f'''{uids["debug"]} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.andychen.BeautyClinic;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			}};
			name = Debug;
		}};''')

# Release config
rel = gid()
objects.append(f'''{rel} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.andychen.BeautyClinic;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};''')

# Project configs
proj_debug = gid()
proj_release = gid()
objects.append(f'''{proj_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
			}};
			name = Debug;
		}};''')

objects.append(f'''{proj_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
			}};
			name = Release;
		}};''')

# Config lists
objects.append(f'''{uids["projectCfgList"]} /* Build configuration list for PBXProject "BeautyClinic" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{proj_debug} /* Debug */,
				{proj_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};''')

objects.append(f'''{uids["targetCfgList"]} /* Build configuration list for PBXNativeTarget "BeautyClinic" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{uids["debug"]} /* Debug */,
				{rel} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};''')

# Supabase package reference
objects.append(f'''{uids["supabasePkg"]} /* XCRemoteSwiftPackageReference "supabase-swift" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/supabase/supabase-swift.git";
			requirement = {{
				kind = upToNextMajorVersion;
				minimumVersion = 2.0.0;
			}};
		}};''')

# Supabase product dependency
objects.append(f'''{uids["supabaseProduct"]} /* Supabase */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {uids["supabasePkg"]} /* XCRemoteSwiftPackageReference "supabase-swift" */;
			productName = Supabase;
		}};''')

# Write project.pbxproj
os.makedirs(XCODEPROJ, exist_ok=True)

content = f'''// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(objects[:len(swift_files)+1])}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(objects[len(swift_files)+1:len(swift_files)*2+2])}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
{objects[len(swift_files)*2+2]}
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{chr(10).join(objects[len(swift_files)*2+3:len(swift_files)*2+7])}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
{objects[len(swift_files)*2+7]}
/* End PBXNativeTarget section */

/* Begin PBXProject section */
{objects[len(swift_files)*2+8]}
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{objects[len(swift_files)*2+9]}
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{objects[len(swift_files)*2+10]}
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
{chr(10).join(objects[len(swift_files)*2+11:len(swift_files)*2+15])}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{chr(10).join(objects[len(swift_files)*2+15:len(swift_files)*2+17])}
/* End XCConfigurationList section */

/* Begin XCRemoteSwiftPackageReference section */
{objects[len(swift_files)*2+17]}
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
{objects[len(swift_files)*2+18]}
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {uids["project"]} /* Project object */;
}}
'''

with open(PBXPROJ, "w") as f:
    f.write(content)

# Also write workspace settings for SPM
xcshareddata = os.path.join(XCODEPROJ, "project.xcworkspace", "xcshareddata")
os.makedirs(xcshareddata, exist_ok=True)

with open(os.path.join(xcshareddata, "WorkspaceSettings.xcsettings"), "w") as f:
    f.write('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PreviewsEnabled</key>
	<false/>
</dict>
</plist>
''')

print(f"\n✅ Xcode project generated at: {XCODEPROJ}")
print(f"   Source files: {len(swift_files)}")
print(f"   Supabase SPM: configured")
